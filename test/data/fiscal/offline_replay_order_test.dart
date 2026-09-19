/// Повтор очереди: **одна строка не загораживает остальные, но зависимый
/// документ не обгоняет того, от кого зависит** — через эмулятор на сокете.
///
/// # Правило
///
/// Документы делятся на два рода.
///
/// * **Независимые** — продажа и внесение. Они только прибавляют деньги в
///   ящик и не ссылаются ни на один прежний документ; оператор не может
///   отвергнуть их из-за того, что прежний документ ещё не пришёл. Им можно
///   идти мимо застрявшей строки.
/// * **Зависимые** — возврат продажи и возврат покупки (ссылаются на
///   документ-основание), покупка и изъятие (забирают из ящика деньги,
///   положенные прежними документами: код 8 «недостаточно денег»). Пока в
///   проходе есть застрявшая строка, такие документы **не отправляются** —
///   возврат, ушедший раньше своей продажи, оператор отвергнет, и отказ
///   ляжет в `failed` не по делу.
///
/// Связи «этот возврат — от той продажи» в документе нет (основание несёт
/// признак, а у застрявшей продажи признака ещё нет), поэтому правило
/// осторожное: застряла любая — держатся все зависимые.
///
/// То же правило действует и на **новый** документ: зависимый не обходит
/// очередь, если в ней есть ожидающие строки, а встаёт за ними.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';

import 'support/webkassa_rig.dart';

void main() {
  late WebKassaRig rig;

  setUp(() async {
    rig = await startWebKassaRig();
    await rig.warm();
  });

  tearDown(() async => rig.stop());

  final t0 = DateTime.now().subtract(const Duration(minutes: 10));

  test('обрыв на первой строке не хоронит проход: следующая продажа уходит', () async {
    await rig.store.enqueue(rigSaleRow(rigSale('A', at: t0)));
    await rig.store.enqueue(
      rigSaleRow(rigSale('B', at: t0.add(const Duration(minutes: 1)))),
    );
    await rig.console('/_emul/kill', {'count': 1});

    final report = await rig.queued.replay();
    // ignore: avoid_print
    print(
      'replay: fiscalized=${report.fiscalized} failed=${report.failed} '
      'remaining=${report.remaining} stopped=${report.stoppedOnNetwork} '
      'sent=${rig.sentKeys()} accepted=${rig.acceptedKeys()}',
    );

    expect(rig.acceptedKeys(), ['B'], reason: 'B не зависит от A');
    expect(report.fiscalized, 1);
    final pending = await rig.store.pending();
    expect(pending.map((e) => e.idempotencyKey), ['A']);
    expect(
      pending.single.attempts,
      1,
      reason: 'попытка сосчитана — иначе строка вечна и безымянна',
    );
    expect(pending.single.lastError, isNotNull);
  });

  test('возврат не обгоняет застрявшую продажу; независимая продажа — да', () async {
    await rig.store.enqueue(rigSaleRow(rigSale('A', at: t0)));
    await rig.store.enqueue(
      rigRefundRow(rigRefund('R', at: t0.add(const Duration(minutes: 1)))),
    );
    await rig.store.enqueue(
      rigSaleRow(rigSale('B', at: t0.add(const Duration(minutes: 2)))),
    );
    await rig.console('/_emul/kill', {'count': 1});

    await rig.queued.replay();

    expect(rig.sentKeys(), isNot(contains('R')), reason: 'возврат держится');
    expect(rig.acceptedKeys(), ['B']);
    final pending = await rig.store.pending();
    expect(pending.map((e) => e.idempotencyKey), ['A', 'R']);

    // Связь вернулась — следующий проход везёт в прежнем порядке.
    final second = await rig.queued.replay();
    expect(second.fiscalized, 2);
    expect(rig.acceptedKeys(), ['B', 'A', 'R']);
    expect(await rig.store.pendingCount(), 0);
  });

  test('новый возврат при ожидающей продаже встаёт в очередь, а не уходит вперёд', () async {
    await rig.store.enqueue(rigSaleRow(rigSale('A', at: t0)));

    final r = await rig.queued.fiscalizeRefund(rigRefund('R-new'));

    expect(r.queued, isTrue);
    expect(rig.sentKeys(), isEmpty);
    expect(
      (await rig.store.pending()).map((e) => e.idempotencyKey),
      ['A', 'R-new'],
    );
  });

  test('новая продажа при ожидающей очереди идёт сразу — она ни от кого не зависит', () async {
    await rig.store.enqueue(rigSaleRow(rigSale('A', at: t0)));

    final r = await rig.queued.fiscalizeSale(rigSale('S-new'));

    expect(r.success, isTrue);
    expect(r.queued, isFalse);
    expect(rig.acceptedKeys(), contains('S-new'));
  });

  test('два прохода разом не отправляют строку дважды', () async {
    await rig.store.enqueue(rigSaleRow(rigSale('A', at: t0)));
    await rig.console('/_emul/latency', {'ms': 300});

    final reports = await Future.wait([
      rig.queued.replay(),
      rig.queued.replay(),
    ]);
    await rig.console('/_emul/latency', {'ms': 0});

    // ignore: avoid_print
    print('два прохода: sent=${rig.sentKeys()}');
    expect(
      rig.sentKeys().where((k) => k == 'A'),
      hasLength(1),
      reason: 'второй проход обязан присоединиться к первому, а не повторить его',
    );
    expect(reports.map((r) => r.fiscalized).reduce((a, b) => a + b), 1);
    expect(await rig.store.pendingCount(), 0);
  });

  test('два экземпляра провайдера над одним хранилищем — тоже один раз', () async {
    // Реестр строит провайдер заново на каждый `resolve`
    // (`service_locator.dart`): замок, живущий в экземпляре, двух
    // экземпляров не разведёт. Общее у них — хранилище.
    await rig.store.enqueue(rigSaleRow(rigSale('A', at: t0)));
    await rig.console('/_emul/latency', {'ms': 300});
    final twin = OfflineQueueingProvider(
      inner: rig.provider,
      store: rig.store,
      isReachable: () async => true,
    );

    await Future.wait([rig.queued.replay(), twin.replay()]);
    await rig.console('/_emul/latency', {'ms': 0});
    expect(rig.sentKeys().where((k) => k == 'A'), hasLength(1));
    expect(await rig.store.pendingCount(), 0);
  });
}
