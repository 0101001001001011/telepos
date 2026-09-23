/// Ставка складывается из юрисдикций, и чек умеет показать разбивку.
///
/// # Зачем
///
/// План `2026-09-21-us-tax-engine.md`, этап 3. В США ставка — сумма:
/// штат + округ + город + спецрайоны. В Колорадо города с самоуправлением
/// администрируют свою часть сами, и разбивка на чеке там не украшение.
///
/// До правки ставка была одним скалярным числом: хранить составляющие было
/// негде, и «8,81 %» на бумаге ничего не говорило о том, из чего она
/// сложилась.
///
/// # Главное утверждение
///
/// **Сумма составляющих обязана равняться объявленной ставке.** Расхождение
/// — отказ, а не молчаливое округление: чек с разбивкой, которая не
/// сходится, врёт покупателю о налоговом документе. Лучше не собрать такой
/// чек вовсе и починить настройку, чем выдать красивую неправду.
library;

import 'dart:ui';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/l10n/app_localizations.dart';

void main() {
  final english = ReceiptPrintServiceImpl(
    strings: () => lookupAppLocalizations(const Locale('en')),
  );
  const options = ReceiptOptions(footer: ReceiptTextBlock(text: 'Thank you!'));
  Decimal d(String v) => Decimal.parse(v);

  /// Разбивка, похожая на денверскую по СТРУКТУРЕ.
  ///
  /// Числа здесь — данные пробы, а не утверждение о действующих ставках
  /// Колорадо: их берут из источника перед съёмкой. Проверяется механизм
  /// сложения, а не налоговое право.
  List<TaxJurisdiction> stack() => [
    TaxJurisdiction(name: 'State', ratePercent: d('2.90')),
    TaxJurisdiction(name: 'County', ratePercent: d('1.00')),
    TaxJurisdiction(name: 'City', ratePercent: d('4.81')),
    TaxJurisdiction(name: 'RTD', ratePercent: d('1.10')),
  ];

  SaleReceiptData withStack({List<TaxJurisdiction>? jurisdictions}) =>
      SaleReceiptData(
        receiptNo: 21,
        posId: 1,
        posName: 'Till-1',
        storeName: 'Northwind Trading',
        dateTime: DateTime(2026, 6, 20, 14, 30),
        cashierName: 'Anna Whitfield',
        products: [
          ReceiptProductLine(
            name: 'Hot coffee',
            quantity: Decimal.one,
            price: d('10.00'),
            total: d('10.00'),
          ),
        ],
        payments: [
          ReceiptPaymentLine(name: 'Cash', amount: d('10.98'), isCash: true),
        ],
        totalAmount: d('10.98'),
        isVatPayer: true,
        vatRatePercent: d('9.81'),
        taxTreatment: TaxTreatment.exclusive,
        hasFiscalisation: false,
        currencySymbol: r'$',
        taxJurisdictions: jurisdictions ?? stack(),
      );

  test('составляющие складываются в объявленную ставку', () {
    final data = withStack();
    final sum = data.taxJurisdictions.fold<Decimal>(
      Decimal.zero,
      (a, j) => a + j.ratePercent,
    );
    expect(
      sum,
      data.vatRatePercent,
      reason: 'сумма юрисдикций обязана равняться ставке чека',
    );
  });

  test('расхождение — ОТКАЗ, а не молчаливое округление', () {
    expect(
      () => withStack(
        jurisdictions: [
          TaxJurisdiction(name: 'State', ratePercent: d('2.90')),
          // Городская часть «потерялась»: сумма 4.00 против ставки 9.81.
          TaxJurisdiction(name: 'County', ratePercent: d('1.10')),
        ],
      ),
      throwsArgumentError,
      reason:
          'чек с разбивкой, которая не сходится со ставкой, врёт покупателю '
          'о налоговом документе. Лучше не собрать его вовсе и починить '
          'настройку, чем выдать красивую неправду',
    );
  });

  test('пустая разбивка законна — не везде она нужна', () {
    // Казахстан: ставка одна, юрисдикций нет. Требовать разбивку везде
    // значило бы сломать всё, что работало.
    expect(() => withStack(jurisdictions: const []), returnsNormally);
  });

  test('чек печатает разбивку по юрисдикциям', () {
    final text = english.renderSalePreviewText(
      withStack(),
      options,
      paperWidth: ReceiptPaperWidth.mm80,
    );

    for (final name in const ['State', 'County', 'City', 'RTD']) {
      expect(
        text,
        contains(name),
        reason:
            'юрисдикция «$name» не названа на чеке — покупатель не видит, '
            'из чего сложилась ставка',
      );
    }
    expect(text, contains('4.81'), reason: 'доля города названа числом');
  });
}
