/// Петля между двумя концами провода — соединяет настоящий `TillWire`
/// (сторона кассы) с настоящим `WtDispatcher` (сторона браузера) без QUIC,
/// которого нет под `flutter test` (нативной библиотеки под VM не существует
/// — см. `test/data/transport/fake_quic_server.dart`).
///
/// Взят из `wt_till_speaks_first_test.dart`, где жил как приватный код до
/// того, как понадобился второму файлу (`wt_login_enrolment_test.dart`) —
/// тот же приём, каким уже устроен `support/fake_dispatcher.dart`.
library;

import 'dart:async';

import 'package:rk_quic/rk_quic.dart';
import 'package:telepos/web/wt_channel.dart';

/// Играет обе роли сразу: для кассы это [QuicServer], для браузера —
/// [WtStreams].
///
/// Номера потоков растут четвёркой — так их выдаёт QUIC для двунаправленных
/// потоков, инициированных клиентом. Значения это не меняет, но избавляет от
/// совпадений вида «поток 1 и поток 1 разных сессий».
class Loopback implements QuicServer, WtStreams {
  final _events = StreamController<QuicEvent>.broadcast();

  /// Приёмники браузерной стороны, по одному на открытый поток.
  final Map<int, StreamController<String>> _inbound = {};

  /// Всё, что браузер отправил кассе. Счётчик вопросов — и есть
  /// доказательство: после первого кадра подписки он расти не имеет права
  /// (см. `wt_till_speaks_first_test.dart`).
  final List<String> framesFromBrowser = [];

  int _nextStream = 0;

  // --- сторона кассы ---

  @override
  Stream<QuicEvent> get events => _events.stream;

  @override
  int get port => 0;

  @override
  Future<RkQuicStatus> sendOn(
    int sessionId,
    int streamId,
    String message,
  ) async {
    final target = _inbound[streamId];
    if (target == null || target.isClosed) {
      // Терминал закрыл свою половину приёма. Ровно так касса и узнаёт об
      // ушедшем подписчике — событий отписки в этом транспорте нет.
      return RkQuicStatus.peerGone;
    }
    target.add(message);
    return RkQuicStatus.ok;
  }

  @override
  Future<RkQuicStatus> closeStream(int sessionId, int streamId) async {
    final target = _inbound.remove(streamId);
    if (target == null) return RkQuicStatus.unknownHandle;
    if (!target.isClosed) await target.close();
    return RkQuicStatus.ok;
  }

  @override
  Future<RkQuicStatus> send(
    int sessionId,
    String message, {
    bool reliable = true,
  }) async => RkQuicStatus.unsupported;

  @override
  Future<RkQuicStatus> stop() async => RkQuicStatus.ok;

  // --- сторона браузера ---

  @override
  Future<WtStream> openStream() async {
    final streamId = _nextStream += 4;
    _inbound[streamId] = StreamController<String>();
    _events.add(StreamOpened(sessionId: 1, streamId: streamId));
    return LoopbackStream(this, streamId);
  }

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<void> close() async {}

  Future<void> dispose() async {
    for (final controller in _inbound.values.toList()) {
      if (!controller.isClosed) await controller.close();
    }
    _inbound.clear();
    await _events.close();
  }
}

/// Половина браузера у одного потока — с тем же порядком событий, что у
/// настоящего QUIC.
///
/// # Кадр становится событием на [finishSending], а не на [send]
///
/// До 2026-08-05 петля отдавала кадр кассе прямо из [send]. Это и есть та
/// разница между «работает у нас» и «работает вживую», ради которой писался
/// стенд: `rk_quic` читает поток целиком (`transport.rs`, `read_bi_stream`:
/// `recv.read_to_end`), прежде чем он станет событием `StreamData`, — то есть
/// **только после того, как терминал закрыл свою половину отправки**. Петля,
/// отдававшая кадр раньше, была зелёной при проводе, который в браузере
/// молчал: измерено там же, тем же кадром `startup.boot`.
class LoopbackStream implements WtStream {
  LoopbackStream(this._loop, this._streamId);

  final Loopback _loop;
  final int _streamId;

  /// Написанное, но ещё не доехавшее до кассы: она увидит это, когда терминал
  /// закончит говорить.
  final _pending = <String>[];
  var _sendingFinished = false;

  @override
  Stream<String> get frames =>
      _loop._inbound[_streamId]?.stream ?? const Stream.empty();

  @override
  Future<void> send(String frame) async {
    _loop.framesFromBrowser.add(frame);
    _pending.add(frame);
  }

  @override
  Future<void> finishSending() async {
    if (_sendingFinished) return;
    _sendingFinished = true;
    for (final frame in _pending) {
      _loop._events.add(
        StreamData(sessionId: 1, streamId: _streamId, message: frame),
      );
    }
    _pending.clear();
    // Закрытие приходит сразу за запросом — так устроен приём на кассе, и
    // подписку оно не снимает. Воспроизводится здесь, а не опускается:
    // подписка, которую сняло бы это событие, работала бы в тесте и не
    // работала бы в поле.
    _loop._events.add(StreamClosed(sessionId: 1, streamId: _streamId));
  }

  @override
  Future<void> close() async {
    final controller = _loop._inbound.remove(_streamId);
    if (controller != null && !controller.isClosed) await controller.close();
  }
}

/// Даёт отработать потокам drift, кодированию кадра, петле и разбору.
Future<void> settleLoopback() async {
  for (var i = 0; i < 24; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
