/// «Куда уйдут деньги» по проводу — задача 26.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/wire/refund_codec.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

Matcher badRequest(String field) => throwsA(
  isA<WireRefusal>()
      .having((r) => r.code, 'code', 'bad_request')
      .having((r) => r.message, 'message', contains(field)),
);

void main() {
  final view = RefundView(
    posId: 1,
    terminalId: 7,
    version: 3,
    draftNo: 2,
    saleReceiptNo: 11,
    salePosId: 1,
    lines: [
      RefundLine(
        id: '5',
        productId: 100,
        name: 'Кофе',
        quantity: Decimal.one,
        price: Decimal.parse('1000'),
        maxQuantity: Decimal.one,
      ),
    ],
    destinations: [
      RefundDestination(
        route: RefundRoute.certificate,
        amount: Decimal.parse('600.005'),
        kindId: 5,
        kindName: 'Сертификат',
        detail: 'C-600',
      ),
      RefundDestination(
        route: RefundRoute.drawer,
        amount: Decimal.parse('399.995'),
      ),
    ],
  );

  test('строки доезжают до терминала значением, до тысячной', () {
    final wire = refundViewToWireJson(view);
    expect(refundViewFromWireJson(wire), view);
    final raw = (wire['destinations']! as List).first as Map;
    expect(raw['amount'], '600.005', reason: 'деньги — строкой (I159)');
    expect(raw['route'], 'certificate');
  });

  test('незнакомый получатель — отказ, а не наличные по умолчанию', () {
    final wire = refundViewToWireJson(view);
    final raw = [
      for (final d in wire['destinations']! as List)
        {...(d as Map).cast<String, Object?>()},
    ];
    raw.first['route'] = 'cash';
    expect(
      () => refundViewFromWireJson({...wire, 'destinations': raw}),
      badRequest('route'),
    );
  });

  test('сумма числом — отказ', () {
    final wire = refundViewToWireJson(view);
    final raw = [
      for (final d in wire['destinations']! as List)
        {...(d as Map).cast<String, Object?>()},
    ];
    raw.first['amount'] = 600.005;
    expect(
      () => refundViewFromWireJson({...wire, 'destinations': raw}),
      badRequest('amount'),
    );
  });

  test('мусор вместо списка — отказ; пропуск — пустой список', () {
    final wire = refundViewToWireJson(view);
    expect(
      () => refundViewFromWireJson({...wire, 'destinations': 'нет'}),
      badRequest('destinations'),
    );
    expect(
      refundViewFromWireJson({...wire}..remove('destinations')).destinations,
      isEmpty,
    );
  });
}
