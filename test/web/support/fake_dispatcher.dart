/// Подставной провод для проверки браузерных репозиториев без кассы.
///
/// Общий для каждого `lib/web/*_repository.dart`: все они собираются поверх
/// одного и того же `WtDispatcher`, и заводить фальшивку заново в каждом
/// тестовом файле значило бы держать несколько копий одного и того же, которые
/// могут разойтись молча. Взят из `wt_repositories_test.dart`, где жил как
/// приватный код до того, как понадобился второму файлу.
library;

import 'dart:async';

import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Диспетчер над сессией, которой нет: любой обмен отвечает `no_session`.
WtDispatcher dispatcherThatRefuses() => WtDispatcher(DeadStreams());

/// Диспетчер, отвечающий заданными кадрами по порядку на единственный
/// открытый поток. Кадры — уже закодированная строка (см. `WireFrame.encode`),
/// как их видел бы настоящий провод.
WtDispatcher answering(
  String frame, [
  String? second,
  String? third,
  String? fourth,
]) => WtDispatcher(
  ScriptedStreams([frame, second, third, fourth].whereType<String>().toList()),
);

/// Подделка хранилища сеансовых токенов: токен известен заранее, `write`/
/// `clear`/`readExpiresAt` тестам, которые ей пользуются, не нужны.
class FakeTokens implements SessionTokenStorage {
  FakeTokens(this._token);

  final String? _token;

  @override
  String? read() => _token;

  @override
  DateTime? readExpiresAt() => throw UnimplementedError();

  @override
  void write(String token, DateTime expiresAt) => throw UnimplementedError();

  @override
  void clear() => throw UnimplementedError();
}

class DeadStreams implements WtStreams {
  @override
  Future<WtStream> openStream() async =>
      throw const WtProtocolError('no_session', 'касса не отвечает');

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<void> close() async {}
}

/// Касса, которая **приняла запрос и не ответила**.
///
/// Поток открывается, кадр уходит, и дальше — тишина: ни ответа, ни закрытия
/// потока. Это не выдумка теста, а измеренная форма отказа провода: у обмена
/// с кассой нет ни таймаута, ни отмены (докстринг `LoginNotifier.logout`), и
/// вызывающий висит вечно. Живой прогон 2026-09-07 показал ровно эту картину
/// на кнопке денег — ни успеха, ни отказа, ни строки в журнале.
class SilentStreams implements WtStreams {
  /// Кадры, ушедшие на кассу: запрос **уходит**, молчит ответ.
  final sent = <String>[];

  @override
  Future<WtStream> openStream() async => SilentStream(sent);

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<void> close() async {}
}

class SilentStream implements WtStream {
  SilentStream(this._sent);

  final List<String> _sent;
  final _controller = StreamController<String>();

  @override
  Stream<String> get frames => _controller.stream;

  @override
  Future<void> send(String frame) async => _sent.add(frame);

  @override
  Future<void> finishSending() async {}

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

class ScriptedStreams implements WtStreams {
  ScriptedStreams(this._script);

  final List<String> _script;

  /// Кадры, ушедшие на кассу, — в порядке отправки.
  ///
  /// Заведено задачей 20: там проверяется не только то, что ответ разобран,
  /// но и **что именно уехало** — имя операции (иначе касса выберет другой
  /// обработчик) и вид, в котором уехали деньги (строкой, И159). Без записи
  /// отправленного проверить это нечем: `send` раньше молча выбрасывал кадр,
  /// и подделка «уехало не то» выглядела бы точно так же, как исправный
  /// обмен.
  final sent = <String>[];

  @override
  Future<WtStream> openStream() async => ScriptedStream(_script, sent);

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<void> close() async {}
}

class ScriptedStream implements WtStream {
  ScriptedStream(this._script, [List<String>? sent]) : _sent = sent ?? [] {
    _controller = StreamController<String>(
      onListen: () {
        for (final frame in _script) {
          _controller.add(frame);
        }
        // Поток закрывается после сценария: так выглядит и законченный обмен,
        // и оборванный посреди работы — разницу делает содержание кадров, а не
        // транспорт.
        _controller.close();
      },
    );
  }

  final List<String> _script;
  final List<String> _sent;
  late final StreamController<String> _controller;

  @override
  Stream<String> get frames => _controller.stream;

  @override
  Future<void> send(String frame) async => _sent.add(frame);

  @override
  Future<void> finishSending() async {}

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}
