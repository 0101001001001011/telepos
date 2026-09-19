import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import 'fake_quic_server.dart';
import 'open_guard.dart';

void main() {
  late FakeQuicServer server;
  late TillWire wire;

  setUp(() => server = FakeQuicServer());
  tearDown(() async {
    await wire.stop();
    await server.dispose();
  });

  /// Один обмен целиком: терминал открыл поток, прислал вопрос и закрыл свою
  /// половину отправки. `streamClosed` идёт сразу за запросом не по прихоти
  /// теста — касса читает сообщение до конца, прежде чем оно станет событием,
  /// поэтому иначе и не бывает.
  Future<void> askAndSettle(String message) async {
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(sessionId: 1, streamId: 4, message: message);
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);
  }

  test('ответ уходит в тот же поток, из которого пришёл вопрос', () async {
    // Это всё, ради чего заводились двунаправленные потоки: соответствие
    // ответа вопросу не хранится нигде, оно и есть поток.
    wire = TillWire(server, {
      'demo.echo': (body, [_, _]) async => {'text': body['value']},
    }, guard: openGuard)..start();

    await askAndSettle('{"op":"demo.echo","body":{"value":"семь"}}');

    expect(server.sentOn, [(1, 4)]);
    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<OkFrame>());
    expect((frame as OkFrame).body, {'text': 'семь'});
    expect(server.closedStreams, [(1, 4)], reason: 'вопрос закрывает поток');
  });

  test('неизвестная операция — кадр отказа, а не молчание', () async {
    // Молчащий поток неотличим от зависшей кассы, и терминал будет ждать
    // ответа, которого не будет.
    wire = TillWire(server, const {}, guard: openGuard)..start();

    await askAndSettle('{"op":"nope","body":{}}');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'unknown_op');
    expect(frame.detail, contains('nope'));
    expect(server.closedStreams, [(1, 4)]);
  });

  test('обработчик, бросивший исключение, не роняет кассу', () async {
    // Касса, упавшая на запросе терминала, не может принять деньги (И144).
    wire = TillWire(server, {
      'demo.boom': (body, [_, _]) async => throw StateError('внутри плохо'),
    }, guard: openGuard)..start();

    await askAndSettle('{"op":"demo.boom","body":{}}');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'handler_failed');
    // Не `contains('внутри плохо')`: `safeErrorText` (задача 2 — провод
    // перестаёт нести текст исключения) отдаёт для произвольного исключения
    // только имя типа, а не его сообщение — своё сообщение может нести чужой
    // секрет, и провод не тот, кто вправе ему доверять.
    expect(frame.detail, 'StateError');
  });

  test('не-кадр получает названный отказ, а не тишину', () async {
    // Чужой сервис на порту, портал гостевого Wi-Fi, обрезанное сообщение —
    // разбор уже назвал причину, и она обязана доехать до терминала.
    wire = TillWire(server, const {}, guard: openGuard)..start();

    await askAndSettle('<!DOCTYPE html><html>404</html>');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'not_a_frame');
    expect(server.closedStreams, [(1, 4)]);
  });

  test('ответ кассы, пришедший вместо запроса, — тоже отказ', () async {
    // Кадр разбирается, но запросом не является: терминал прислал `ok`.
    // Принять его молча значило бы оставить поток открытым навсегда.
    wire = TillWire(server, const {}, guard: openGuard)..start();

    await askAndSettle('{"ok":true,"body":{}}');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'not_a_request');
  });

  test('закрытие потока само по себе ничего не отвечает', () async {
    // `StreamClosed` приходит сразу за каждым запросом. Если бы он сам по себе
    // что-то отправлял, на один вопрос уходило бы два кадра.
    wire = TillWire(server, const {}, guard: openGuard)..start();

    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);

    expect(server.sentFrames, isEmpty);
    expect(server.closedStreams, isEmpty);
  });

  test('два вопроса подряд отвечают каждый в свой поток', () async {
    // Терминал держит несколько вопросов сразу — один экран спрашивает
    // состояние, другой список терминалов. Перепутанные ответы выглядели бы
    // как испорченные данные, а не как ошибка транспорта.
    wire = TillWire(server, {
      'demo.echo': (body, [_, _]) async => {'text': body['value']},
    }, guard: openGuard)..start();

    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamOpened(sessionId: 1, streamId: 8);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message: '{"op":"demo.echo","body":{"value":"четыре"}}',
    );
    server.emitStreamData(
      sessionId: 1,
      streamId: 8,
      message: '{"op":"demo.echo","body":{"value":"восемь"}}',
    );
    await Future<void>.delayed(Duration.zero);

    final answers = {
      for (var i = 0; i < server.sentOn.length; i++)
        server.sentOn[i].$2:
            (WireFrame.decode(server.sentFrames[i]) as OkFrame).body['text'],
    };
    expect(answers, {4: 'четыре', 8: 'восемь'});
  });
}
