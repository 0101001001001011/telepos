/// Освобождение — не то же самое, что ставка ноль.
///
/// # Зачем
///
/// План `2026-09-21-us-tax-engine.md`, этап 4. До правки различить их было
/// нечем: `isVatPayer == false` гасил налоговые строки целиком, а позиция со
/// ставкой ноль печаталась как «0 %».
///
/// Это разные утверждения:
///
/// * **ставка ноль** — товар облагается, но по нулевой ставке. Он ВХОДИТ в
///   облагаемую базу, и налоговая ждёт его в отчёте;
/// * **освобождён** — товар вне обложения. В базу он не входит вовсе.
///
/// На американском чеке освобождённые позиции принято помечать, и по
/// пометке покупатель понимает, почему налог меньше, чем он прикинул.
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

  SaleReceiptData basket() => SaleReceiptData(
    receiptNo: 31,
    posId: 1,
    posName: 'Till-1',
    storeName: 'Northwind Trading',
    dateTime: DateTime(2026, 6, 20, 14, 30),
    cashierName: 'Anna Whitfield',
    products: [
      // Освобождён: вне обложения вовсе.
      ReceiptProductLine(
        name: 'Milk, 1 gal',
        quantity: Decimal.one,
        price: d('4.00'),
        total: d('4.00'),
        isTaxExempt: true,
      ),
      // Облагается по нулевой ставке: в базу входит.
      ReceiptProductLine(
        name: 'Baby formula',
        quantity: Decimal.one,
        price: d('6.00'),
        total: d('6.00'),
        taxRatePercent: Decimal.zero,
      ),
      // Облагается.
      ReceiptProductLine(
        name: 'Hot coffee',
        quantity: Decimal.one,
        price: d('10.00'),
        total: d('10.00'),
        taxRatePercent: d('8.25'),
      ),
    ],
    payments: [
      ReceiptPaymentLine(name: 'Cash', amount: d('20.83'), isCash: true),
    ],
    totalAmount: d('20.83'),
    isVatPayer: true,
    vatRatePercent: d('8.25'),
    taxTreatment: TaxTreatment.exclusive,
    hasFiscalisation: false,
    currencySymbol: r'$',
  );

  test('освобождённая позиция НЕ входит в облагаемую базу', () {
    final groups = basket().taxByRate;

    final zeroRate = groups.where((g) => g.ratePercent == Decimal.zero);
    expect(
      zeroRate,
      hasLength(1),
      reason: 'нулевая ставка — своя группа, она в базе',
    );
    expect(
      zeroRate.single.base,
      d('6.00'),
      reason:
          'в нулевую группу вошла только смесь. Молоко освобождено и в базу '
          'не входит вовсе — если оно тут, освобождение считается нулевой '
          'ставкой, а это разные вещи',
    );

    // Главная проверка этого места, и она нашлась диверсией: первая
    // редакция пробы смотрела только на нулевую группу, а освобождённое
    // молоко без своей ставки попадало в ОБЛАГАЕМУЮ по ставке чека. Снятие
    // правила не роняло пробу вовсе.
    final taxable = groups.firstWhere((g) => g.ratePercent == d('8.25'));
    expect(
      taxable.base,
      d('10.00'),
      reason:
          'в облагаемую базу вошёл только кофе. Если здесь 14.00, значит '
          'освобождённое молоко обложено по ставке чека — покупатель платит '
          'налог за то, что налогом не облагается',
    );
    expect(
      taxable.tax,
      d('0.83'),
      reason: 'налог на 10.00 по 8,25% — восемьдесят три цента',
    );
  });

  test('освобождённое видно в сводке отдельной строкой', () {
    final data = basket();
    expect(
      data.exemptTotal,
      d('4.00'),
      reason: 'сумма освобождённого названа отдельно, а не растворена',
    );
  });

  test('на чеке освобождённая позиция помечена', () {
    final text = english.renderSalePreviewText(
      basket(),
      options,
      paperWidth: ReceiptPaperWidth.mm80,
    );
    expect(
      text,
      contains('EX'),
      reason:
          'без пометки покупатель не поймёт, почему налог меньше, чем он '
          'прикинул по итогу',
    );
    expect(text, contains('Exempt'), reason: 'сводка называет освобождённое');
  });

  test('без освобождений сводка их не показывает', () {
    final data = SaleReceiptData(
      receiptNo: 32,
      posId: 1,
      posName: 'Till-1',
      storeName: 'Northwind Trading',
      dateTime: DateTime(2026, 6, 20, 14, 30),
      cashierName: 'Anna Whitfield',
      products: [
        ReceiptProductLine(
          name: 'Milk, 1 L',
          quantity: Decimal.one,
          price: d('450.00'),
          total: d('450.00'),
        ),
      ],
      payments: [
        ReceiptPaymentLine(name: 'Cash', amount: d('450.00'), isCash: true),
      ],
      totalAmount: d('450.00'),
      isVatPayer: true,
      vatRatePercent: d('16'),
      currencySymbol: '₸',
    );

    // Казахстан: освобождений нет, и строки быть не должно.
    expect(data.exemptTotal, Decimal.zero);
  });
}
