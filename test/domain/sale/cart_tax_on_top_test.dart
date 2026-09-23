/// Налог сверх цены входит в сумму к оплате.
///
/// # Что измерено 2026-09-21 на дубле урока 1.3
///
/// Корзина из молока ($4.29) и кофе ($3.50) на американской кассе с
/// настроенным Денвером напечатала «TOTAL: $7.79» и не начислила **ни
/// цента** налога. Касса взяла с покупателя цену без налога.
///
/// Дыра лежала не в печати, а здесь: `CartView.total` был подытогом.
/// Печать считает подытог как «итог минус налог» — то есть ждёт, что налог
/// в итоге уже есть.
///
/// # Почему проба именно на корзине
///
/// Это единственное место, где сумма к оплате рождается. Проверять её на
/// чеке значило бы проверять последствие: чек печатает то, что ему дали.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/domain/sale/cart_view.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  CartLine line(
    String id,
    String price, {
    String? rate,
    bool exempt = false,
  }) => CartLine(
    id: id,
    productId: int.parse(id),
    name: 'line $id',
    quantity: Decimal.one,
    price: d(price),
    discounts: const [],
    taxRatePercent: rate == null ? null : d(rate),
    isTaxExempt: exempt,
  );

  CartView cart(List<CartLine> lines, TaxTreatment treatment) => CartView(
    posId: 1,
    terminalId: 1,
    version: 1,
    lines: lines,
    wholesale: false,
    taxTreatment: treatment,
  );

  group('налог сверх цены (США)', () {
    test('покупатель платит цену ПЛЮС налог', () {
      // Тот самый дубль: молоко по 6,25 % (штат освободил еду для дома,
      // город — нет) и кофе по 9,15 %.
      final view = cart([
        line('1', '4.29', rate: '6.25'),
        line('2', '3.50', rate: '9.15'),
      ], TaxTreatment.exclusive);

      expect(view.netTotal, d('7.79'));
      expect(
        view.taxOnTop,
        d('0.59'),
        reason: '4.29×6.25% = 0.27, 3.50×9.15% = 0.32',
      );
      expect(
        view.total,
        d('8.38'),
        reason:
            'на дубле касса взяла 7,79 и напечатала это как итог — то есть '
            'не взяла налог вовсе',
      );
    });

    test('освобождённая строка налога не добавляет', () {
      final view = cart([
        line('1', '4.29', rate: '6.25', exempt: true),
        line('2', '3.50', rate: '9.15'),
      ], TaxTreatment.exclusive);

      expect(view.taxOnTop, d('0.32'));
      expect(view.total, d('8.11'));
    });

    test('ненастроенный налог ничего не добавляет', () {
      final view = cart([line('1', '4.29')], TaxTreatment.exclusive);
      expect(view.taxOnTop, Decimal.zero);
      expect(view.total, d('4.29'));
    });

    test('скидка уменьшает и налог тоже', () {
      final view = cart([
        CartLine(
          id: '1',
          productId: 1,
          name: 'discounted',
          quantity: Decimal.one,
          price: d('10.00'),
          discounts: [CartDiscount.manual(d('2.00'))],
          taxRatePercent: d('10'),
        ),
      ], TaxTreatment.exclusive);

      expect(
        view.taxOnTop,
        d('0.80'),
        reason:
            'налог берётся с того, что покупатель платит, а не с ценника: '
            'иначе скидка доставалась бы государству, а не покупателю',
      );
      expect(view.total, d('8.80'));
    });
  });

  group('налог в цене (СНГ, ЕС)', () {
    test('итог не меняется — налог уже внутри цен', () {
      final view = cart([
        line('1', '450', rate: '16'),
        line('2', '150', rate: '16'),
      ], TaxTreatment.inclusive);

      expect(
        view.taxOnTop,
        Decimal.zero,
        reason:
            'прибавить его здесь значило бы взять с покупателя дважды — '
            'и сменить сумму на КАЖДОЙ работающей кассе СНГ',
      );
      expect(view.total, d('600'));
    });

    test('умолчание — «налог в цене»', () {
      const view = CartView(
        posId: 1,
        terminalId: 1,
        version: 1,
        lines: [],
        wholesale: false,
      );
      expect(
        view.taxTreatment,
        TaxTreatment.inclusive,
        reason:
            'касса, которую не перенастраивали, обязана считать как прежде',
      );
    });
  });
}
