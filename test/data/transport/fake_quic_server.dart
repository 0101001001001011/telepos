/// Подставной `QuicServer` для тестов провода.
///
/// Настоящий в наборе не поднимается намеренно: нативной библиотеки под
/// `flutter test` нет вовсе, и набор, краснеющий из-за её отсутствия, ничего не
/// говорит о проверяемом коде. Здесь подставляется ровно то, чем `TillWire`
/// пользуется, — поток событий и две записи, — а всё остальное отвечает
/// [RkQuicStatus.unsupported], чтобы случайное обращение было видно, а не
/// принято за успех.
library;

import 'dart:async';

import 'package:rk_quic/rk_quic.dart';

class FakeQuicServer implements QuicServer {
  final _events = StreamController<QuicEvent>.broadcast();

  /// Пары (сессия, поток), в которые уходила запись, — по одной на кадр.
  final List<(int, int)> sentOn = [];

  /// Сами кадры, в порядке отправки.
  final List<String> sentFrames = [];

  /// Пары, для которых звали [closeStream].
  final List<(int, int)> closedStreams = [];

  /// Очередь ответов на ближайшие записи. Пусто — запись удаётся.
  final List<RkQuicStatus> _plannedFailures = [];

  /// Следующая запись ответит [status] и **не** попадёт в [sentFrames]:
  /// отказавшая запись ничего не отправила, и делать вид, что отправила,
  /// значило бы прятать ровно тот случай, ради которого это заведено.
  void failNextSendWith(RkQuicStatus status) => _plannedFailures.add(status);

  void emitStreamOpened({required int sessionId, required int streamId}) =>
      _events.add(StreamOpened(sessionId: sessionId, streamId: streamId));

  void emitStreamData({
    required int sessionId,
    required int streamId,
    required String message,
  }) => _events.add(
    StreamData(sessionId: sessionId, streamId: streamId, message: message),
  );

  /// Приходит сразу за запросом — так устроен приём, а не так придуман тест.
  void emitStreamClosed({required int sessionId, required int streamId}) =>
      _events.add(StreamClosed(sessionId: sessionId, streamId: streamId));

  void emitSessionClosed({required int sessionId, String reason = 'closed'}) =>
      _events.add(SessionClosed(sessionId: sessionId, reason: reason));

  Future<void> dispose() => _events.close();

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
    if (_plannedFailures.isNotEmpty) return _plannedFailures.removeAt(0);
    sentOn.add((sessionId, streamId));
    sentFrames.add(message);
    return RkQuicStatus.ok;
  }

  @override
  Future<RkQuicStatus> closeStream(int sessionId, int streamId) async {
    closedStreams.add((sessionId, streamId));
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
}
