import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/sale_terms_codec.dart';

/// Кодек `sale.editTerms` — задача 44.
void main() {
  Decimal d(String v) => Decimal.parse(v);

  SaleEditTerms terms({Decimal? approvalAbove}) => SaleEditTerms(
    policy: const SalePolicy(editPrice: false, sellInDiscount: true),
    cap: DiscountCap(
      // Не круглое и с периодом при переводе в double: 14.999999 вместо 15
      // дал бы диалогу предел, на котором касса откажет.
      maxPercent: d('33.333'),
      approvalAbove: approvalAbove,
      source: 'предел роли «Кассир»',
    ),
    currencySymbol: '₸',
  );

  test('проценты предела едут строкой, а не числом (I159)', () {
    final json = saleEditTermsToWireJson(terms(approvalAbove: d('7.5')));
    expect(json['maxPercent'], '33.333');
    expect(json['approvalAbove'], '7.5');
  });

  test('туда и обратно — то же самое во всех полях', () {
    final back = SaleOps.editTerms.decode(
      saleEditTermsToWireJson(terms(approvalAbove: d('7.5'))),
    );
    expect(back.policy.editPrice, isFalse);
    expect(back.policy.sellInDiscount, isTrue);
    expect(back.cap.maxPercent, d('33.333'));
    expect(back.cap.approvalAbove, d('7.5'));
    expect(back.cap.source, 'предел роли «Кассир»');
    expect(back.currencySymbol, '₸');
  });

  test('порога подтверждения нет — ключа нет, и обратно это null', () {
    final json = saleEditTermsToWireJson(terms());
    expect(json.containsKey('approvalAbove'), isFalse);
    expect(SaleOps.editTerms.decode(json).cap.approvalAbove, isNull);
  });

  test('кадр без предела — чужая форма, а не «сто процентов»', () {
    final json = saleEditTermsToWireJson(terms())..remove('maxPercent');
    expect(() => SaleOps.editTerms.decode(json), throwsA(anything));
  });

  test('запрос без тела: полномочия касса берёт из сеанса', () {
    expect(SaleOps.editTerms.encode(null), isEmpty);
  });
}
