/// A5: виды оплаты, исключённые протоколом ОФД 2.0.2, на пути в WebKassa.
///
/// `WebKassaProvider._paymentType` отображал `FiscalPaymentKind.credit` в
/// `PaymentType` 2 и `tare` в 3. Протокол ОФД 2.0.2 эти типы исключил. Что с
/// ними делает настоящий `/api/v4/check`, не измерено (вопрос к поддержке
/// WebKassa в отчёте дорожки D), и молча отправлять их нельзя: оператор
/// отвергнет документ кодом, который касса разберёт как «данные не сходятся»,
/// или примет и посчитает не так. Решение — **отказ названным кодом до
/// отправки**, и чек ложится на экран нефискализованных чеков с причиной.
///
/// # Достижимость
///
/// Из продажи сегодня эти виды до провайдера не доходят: вёдра конверта
/// (`LocalPaymentService`, ветки `FiscalTreatment.credit/tare`) их
/// отбрасывают, а `FiscalServiceImpl._buildPayments` строит только наличные и
/// карту. Провайдер — последняя граница перед оператором, и сторож стоит на
/// ней: конверт меняется (дорожка A), граница — нет.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';

import 'support/webkassa_rig.dart';

void main() {
  late WebKassaRig rig;

  setUp(() async {
    rig = await startWebKassaRig();
    await rig.warm();
  });

  tearDown(() async => rig.stop());

  FiscalSaleRequest saleWith(String key, List<FiscalPayment> payments) {
    final base = rigSale(key);
    return FiscalSaleRequest(
      idempotencyKey: key,
      localOperationId: base.localOperationId,
      positions: base.positions,
      payments: payments,
      totalDiscount: Decimal.zero,
      totalMarkup: Decimal.zero,
      occurredAt: base.occurredAt,
    );
  }

  for (final kind in [FiscalPaymentKind.credit, FiscalPaymentKind.tare]) {
    test('${kind.name} — отказ названным кодом до отправки, не очередь', () async {
      final r = await rig.queued.fiscalizeSale(
        saleWith('removed-${kind.name}', [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: rigD('50')),
          FiscalPayment(kind: kind, amount: rigD('50')),
        ]),
      );
      // ignore: avoid_print
      print(
        '${kind.name}: success=${r.success} queued=${r.queued} '
        '${r.errorCode.name} sent=${rig.sentKeys()}',
      );

      expect(r.success, isFalse);
      expect(r.queued, isFalse);
      expect(r.errorCode.name, 'paymentTypeNotAccepted');
      expect(
        rig.sentKeys(),
        isEmpty,
        reason: 'документ с исключённым видом оплаты до оператора не едет',
      );
      expect(await rig.store.pendingCount(), 0);
    });
  }

  test('наличные, карта и мобильный уходят типами 0, 1 и 4', () async {
    final r = await rig.queued.fiscalizeSale(
      saleWith('allowed-kinds', [
        FiscalPayment(kind: FiscalPaymentKind.cash, amount: rigD('40')),
        FiscalPayment(kind: FiscalPaymentKind.card, amount: rigD('30')),
        FiscalPayment(kind: FiscalPaymentKind.mobile, amount: rigD('30')),
      ]),
    );
    expect(r.success, isTrue, reason: '${r.errorCode.name} ${r.errorMessage}');

    final check = rig.state.journal.singleWhere(
      (e) => e.path == '/api/v4/check' && e.outcome == 'ok',
    );
    final types = [
      for (final p in check.request['Payments'] as List)
        (p as Map)['PaymentType'],
    ]..sort();
    expect(types, [0, 1, 4]);
  });
}
