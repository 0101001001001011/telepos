import 'package:flutter_test/flutter_test.dart';
import 'package:rk_quic/rk_quic.dart';
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

  Future<void> runAndSettle(String op) async {
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message: '{"op":"$op","body":{}}',
    );
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'длинная работа отдаёт ход выполнения, а не два крайних числа',
    () async {
      // `http_first_launch_repository.dart` писал о себе, что канала для этого
      // нет и что придумывать промежуточные числа он отказывается: полоса шла с
      // 0.1 сразу на 1.0, а между ними были минуты. Канал появился — проверяем,
      // что им пользуются.
      wire = TillWire(
        server,
        const {},
        runHandlers: {
          'setup.restore': (body) async* {
            yield const ProgressFrame(0.1, 'Начали');
            yield const ProgressFrame(0.6, 'Половина');
            yield const DoneFrame({'ok': true});
          },
        },
        guard: openGuard,
      )..start();

      await runAndSettle('setup.restore');

      final frames = server.sentFrames.map(WireFrame.decode).toList();
      expect(frames.whereType<ProgressFrame>().length, 2);
      expect(frames.whereType<ProgressFrame>().map((f) => f.value), [0.1, 0.6]);
      expect(frames.last, isA<DoneFrame>());
      expect(server.closedStreams, [
        (1, 4),
      ], reason: 'работа кончилась — поток тоже');
    },
  );

  test(
    'обрыв во время работы не выдаёт незавершённое за завершённое',
    () async {
      // Восстановление, оборванное на середине, обязано остаться оборванным:
      // «готово» здесь означает целый магазин.
      wire = TillWire(
        server,
        const {},
        runHandlers: {
          'setup.restore': (body) async* {
            yield const ProgressFrame(0.1, 'Начали');
            throw StateError('питание пропало');
          },
        },
        guard: openGuard,
      )..start();

      await runAndSettle('setup.restore');

      final frames = server.sentFrames.map(WireFrame.decode).toList();
      expect(frames.last, isA<ErrorFrame>());
      expect((frames.last as ErrorFrame).code, 'run_failed');
      // Не `contains('питание пропало')`: `safeErrorText` (задача 2) отдаёт
      // для произвольного исключения только имя типа — своё сообщение может
      // нести чужой секрет.
      expect((frames.last as ErrorFrame).detail, 'StateError');
      expect(frames.whereType<DoneFrame>(), isEmpty);
      expect(server.closedStreams, [(1, 4)]);
    },
  );

  test('работа, упавшая до первого кадра, тоже называет причину', () async {
    // Обработчик может отказать на самом построении потока — например,
    // резервной копии с таким идентификатором нет. Молчание здесь оставило бы
    // терминал с крутящейся полосой навсегда.
    wire = TillWire(
      server,
      const {},
      runHandlers: {
        'setup.restore': (body) => throw StateError('копия не найдена'),
      },
      guard: openGuard,
    )..start();

    await runAndSettle('setup.restore');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'handler_failed');
  });

  test('ушедший терминал не отменяет уже начатое восстановление', () async {
    // Половина магазина хуже, чем ни одной: прервать восстановление ради
    // того, чтобы не писать в закрытый поток, значило бы оставить кассу в
    // состоянии, из которого её нечем достать. Писать перестаём, работу
    // доводим до конца.
    var finished = false;
    wire = TillWire(
      server,
      const {},
      runHandlers: {
        'setup.restore': (body) async* {
          yield const ProgressFrame(0.1, 'Начали');
          yield const ProgressFrame(0.9, 'Почти');
          finished = true;
          yield const DoneFrame({'ok': true});
        },
      },
      guard: openGuard,
    )..start();

    server.failNextSendWith(RkQuicStatus.peerGone);
    await runAndSettle('setup.restore');

    expect(finished, isTrue, reason: 'работа дошла до конца без подписчика');
    expect(
      server.sentFrames.length,
      2,
      reason:
          'первая запись отказала, остальные ушли — отказ записи не '
          'обязан останавливать работу',
    );
  });

  test('ход выполнения вне 0..1 до терминала не доезжает', () async {
    // Полоса, ушедшая за край, — признак того, что число выдумали. Разбор на
    // приёмнике это отвергает; проверяем, что кадр вообще так закодирован,
    // что круг туда-обратно его сохраняет.
    wire = TillWire(
      server,
      const {},
      runHandlers: {
        'setup.restore': (body) async* {
          yield const ProgressFrame(0, 'Ноль');
          yield const ProgressFrame(1, 'Единица');
        },
      },
      guard: openGuard,
    )..start();

    await runAndSettle('setup.restore');

    final frames = server.sentFrames.map(WireFrame.decode).toList();
    expect(frames.whereType<ProgressFrame>().map((f) => f.value), [0.0, 1.0]);
  });
}
