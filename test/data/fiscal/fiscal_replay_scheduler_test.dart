/// Повтор очереди **не только при старте кассы** — через эмулятор на сокете.
///
/// До этой пробы повтор звался один раз, из `configureDependencies`: строка,
/// легшая в очередь после подъёма, ждала перезапуска кассы.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/fiscal/fiscal_replay_scheduler.dart';

import 'support/webkassa_rig.dart';

void main() {
  late WebKassaRig rig;
  late FiscalReplayScheduler scheduler;
  var shiftOpen = true;

  /// Ждёт условие, которое читается из базы (а не из журнала эмулятора).
  ///
  /// Приём документа эмулятором и **вычёркивание строки из очереди** — два
  /// разных события: строку касса убирает уже после ответа провайдера.
  /// Утверждать про очередь сразу после `acceptedKeys` значит спорить с
  /// гонкой: проба падала 2 раза из 5 в одиночку.
  Future<void> untilAsync(Future<bool> Function() done, {int ms = 3000}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: ms));
    while (!await done()) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> until(bool Function() done, {int ms = 3000}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: ms));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> build({Duration interval = const Duration(milliseconds: 150)}) async {
    late FiscalReplayScheduler s;
    rig = await startWebKassaRig(onOperatorReached: () => s.kick());
    await rig.warm();
    s = FiscalReplayScheduler(
      resolve: () async => rig.queued,
      isShiftOpen: () async => shiftOpen,
      interval: interval,
    );
    scheduler = s;
  }

  setUp(() => shiftOpen = true);

  tearDown(() async {
    scheduler.stop();
    await rig.stop();
  });

  test('строка, легшая после старта кассы, уезжает без перезапуска', () async {
    await build();
    scheduler.start();
    // Старт прошёл по пустой очереди — ровно то, что было у кассы утром.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await rig.store.enqueue(rigSaleRow(rigSale('after-start')));
    await until(() => rig.acceptedKeys().contains('after-start'));
    await untilAsync(() async => await rig.store.pendingCount() == 0);

    expect(rig.acceptedKeys(), ['after-start']);
    // Ожидание ограничено: строка, оставшаяся в очереди, по-прежнему красит
    // пробу — ждём только вычёркивания, а не «пока не позеленеет».
    expect(await rig.store.pendingCount(), 0);
  });

  test('при закрытой смене круг не везёт; открыли — везёт', () async {
    await build();
    shiftOpen = false;
    await rig.store.enqueue(rigSaleRow(rigSale('night')));
    scheduler.start();

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(
      rig.sentKeys(),
      isEmpty,
      reason: 'документ при закрытой смене открыл бы смену оператора неявно',
    );
    expect(await rig.store.pendingCount(), 1);

    shiftOpen = true;
    await until(() => rig.acceptedKeys().contains('night'));
    expect(rig.acceptedKeys(), ['night']);
  });

  test('живой чек дошёл до оператора — повтор не ждёт круга', () async {
    await build(interval: const Duration(hours: 1));
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await rig.store.enqueue(rigSaleRow(rigSale('waiting')));

    final live = await rig.queued.fiscalizeSale(rigSale('live'));
    expect(live.success, isTrue);
    expect(live.queued, isFalse);

    await until(() => rig.acceptedKeys().contains('waiting'));
    expect(rig.acceptedKeys(), ['live', 'waiting']);
  });

  test('до start() толчок ничего не заводит', () async {
    await build(interval: const Duration(hours: 1));
    await rig.store.enqueue(rigSaleRow(rigSale('not-started')));

    await rig.queued.fiscalizeSale(rigSale('live-2'));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(scheduler.isStarted, isFalse);
    expect(rig.sentKeys(), ['live-2']);
  });

  test('круг, толчок и ручной проход разом — строка уходит один раз', () async {
    await build(interval: const Duration(milliseconds: 50));
    await rig.store.enqueue(rigSaleRow(rigSale('once')));
    await rig.console('/_emul/latency', {'ms': 200});
    scheduler.start();
    await Future.wait([
      scheduler.runOnce(),
      scheduler.runOnce(),
      Future<void>.delayed(const Duration(milliseconds: 120)),
    ]);
    await until(() => rig.acceptedKeys().contains('once'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await rig.console('/_emul/latency', {'ms': 0});

    expect(rig.sentKeys().where((k) => k == 'once'), hasLength(1));
  });
}
