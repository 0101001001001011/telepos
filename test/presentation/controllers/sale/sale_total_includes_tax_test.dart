/// Экран продажи показывает тот же итог, что возьмёт касса.
///
/// # Что измерено 2026-09-21 на дубле урока 1.3
///
/// Касса пробила 8,38 доллара и выдала сдачу 1,62, а экран оплаты показал
/// сдачу 2,21: журнал так и записал — «terminal claimed change 2.21, till
/// computed 1.62 — принято число кассы».
///
/// Экран суммировал строки без налога сверху. Деньги в итоге взяла касса
/// правильные, но кассир видел другое число и другое сдал бы покупателю.
///
/// # Почему проба здесь, а не на экране оплаты
///
/// Экран оплаты получает готовую сумму (`saleTotalProvider`). Дыра была в
/// том, что эту сумму рождало состояние продажи.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  CartLine line(String id, String price, String rate) => CartLine(
    id: id,
    productId: int.parse(id),
    name: 'line $id',
    quantity: Decimal.one,
    price: d(price),
    discounts: const [],
    taxRatePercent: d(rate),
  );

  CartView cart(TaxTreatment treatment) => CartView(
    posId: 1,
    terminalId: 1,
    version: 1,
    wholesale: false,
    taxTreatment: treatment,
    lines: [line('1', '4.29', '6.25'), line('2', '3.50', '9.15')],
  );

  test('итог экрана равен итогу корзины при налоге сверху', () {
    final view = cart(TaxTreatment.exclusive);
    final state = SaleState.fromCart(view, previous: const SaleState());

    expect(state.netTotal, d('7.79'));
    expect(
      state.total,
      view.total,
      reason:
          'на дубле экран показал сдачу 2,21 при кассовых 1,62 — кассир '
          'видел одно число, покупатель получил другое',
    );
    expect(state.total, d('8.38'));
  });

  test('при налоге в цене итог не меняется', () {
    final view = cart(TaxTreatment.inclusive);
    final state = SaleState.fromCart(view, previous: const SaleState());

    expect(state.taxAdded, Decimal.zero);
    expect(state.total, d('7.79'));
  });

  test('обновление экранного не теряет налог', () {
    // `copyWith` меняет выбор, поиск и отказ. Потерять на нём деньги
    // значило бы показать кассиру другой итог после нажатия, которое чек
    // не трогало.
    final state = SaleState.fromCart(
      cart(TaxTreatment.exclusive),
      previous: const SaleState(),
    );

    expect(state.copyWith(searchQuery: 'молоко').total, state.total);
    expect(state.copyWith(error: 'что-то').total, state.total);
  });
}
