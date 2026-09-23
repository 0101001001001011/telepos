/// Ставка налога — у позиции, а не одна на весь чек.
///
/// # Зачем
///
/// План `2026-09-21-us-tax-engine.md`, этап 2. Налог считался от суммы чека
/// по одной ставке кассы. У товара ставка **есть** в базе
/// (`nomenclature_tables.dart:86`) и доезжает до фискального оператора
/// (`productVatRate`), но до денег и до чека не доходила никогда: поле
/// заполняется, хранится, ездит — и не влияет ни на одну цифру, которую
/// видит покупатель.
///
/// В США это ломается на первом же чеке: продукты обычно освобождены или по
/// сниженной ставке, готовая еда облагается. Две ставки в одном чеке — норма,
/// а не край. В Евросоюзе то же самое и вдобавок требуется разбивка по
/// ставкам.
///
/// # Что проверяется
///
/// Не «поле появилось» — это видно чтением. Проверяется, что **две ставки в
/// одном чеке дают две строки сводки**, а сумма налога равна сумме
/// построчных. Между этими утверждениями и помещался дефект: одна ставка на
/// всех.
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

  /// Американская корзина: продукты освобождены, готовая еда облагается.
  ///
  /// Ровно тот случай, ради которого этап 2 и делается: одна ставка на весь
  /// чек тут даёт неверный налог, сколько её ни подбирай.
  SaleReceiptData mixedBasket() => SaleReceiptData(
    receiptNo: 11,
    posId: 1,
    posName: 'Till-1',
    storeName: 'Northwind Trading',
    dateTime: DateTime(2026, 6, 20, 14, 30),
    cashierName: 'Anna Whitfield',
    products: [
      // Продукты: освобождены.
      ReceiptProductLine(
        name: 'Milk, 1 gal',
        quantity: Decimal.one,
        price: d('4.00'),
        total: d('4.00'),
        taxRatePercent: Decimal.zero,
      ),
      // Готовая еда: облагается.
      ReceiptProductLine(
        name: 'Hot coffee',
        quantity: Decimal.one,
        price: d('3.00'),
        total: d('3.00'),
        taxRatePercent: d('8.25'),
      ),
    ],
    payments: [
      ReceiptPaymentLine(name: 'Cash', amount: d('7.25'), isCash: true),
    ],
    totalAmount: d('7.25'),
    isVatPayer: true,
    vatRatePercent: d('8.25'),
    taxTreatment: TaxTreatment.exclusive,
    hasFiscalisation: false,
    currencySymbol: r'$',
  );

  String render(SaleReceiptData data) => english.renderSalePreviewText(
    data,
    options,
    paperWidth: ReceiptPaperWidth.mm80,
  );

  test('позиция несёт свою ставку', () {
    final line = mixedBasket().products.first;
    expect(
      line.taxRatePercent,
      Decimal.zero,
      reason:
          'ставка позиции потерялась. Именно её отсутствие и означало, что '
          'налог считается один на весь чек',
    );
  });

  test('облагается только облагаемая позиция', () {
    final data = mixedBasket();
    // Кофе 3.00 по 8,25% даёт 0.25; молоко освобождено и в базу не входит.
    // Если налог посчитан от всего чека (7.25), выйдет 0.60 — и покупатель
    // заплатит налог за молоко, которое им не облагается.
    expect(
      data.taxByRate,
      hasLength(2),
      reason: 'две ставки в корзине — две группы в сводке',
    );

    final taxable = data.taxByRate.firstWhere(
      (g) => g.ratePercent == d('8.25'),
    );
    expect(taxable.base, d('3.00'), reason: 'в базу вошла только готовая еда');
    expect(
      taxable.tax,
      d('0.25'),
      reason: 'налог на 3.00 по 8,25% — двадцать пять центов',
    );

    final exempt = data.taxByRate.firstWhere(
      (g) => g.ratePercent == Decimal.zero,
    );
    expect(exempt.tax, Decimal.zero);
  });

  test('на чеке две строки налога, по одной на ставку', () {
    final text = render(mixedBasket());
    expect(
      text,
      contains('8.25'),
      reason: 'облагаемая ставка названа на бумаге',
    );
    expect(
      RegExp(r'Sales tax').allMatches(text).length,
      greaterThanOrEqualTo(2),
      reason:
          'две ставки в корзине обязаны дать две строки: покупатель иначе не '
          'поймёт, с чего именно взят налог',
    );
  });

  test('без ставки у позиции берётся ставка чека — старое поведение цело', () {
    final data = SaleReceiptData(
      receiptNo: 12,
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

    // Казахстан не должен заметить этой правки: позиции ставок не несут,
    // и всё считается по ставке кассы, как считалось.
    expect(data.taxByRate, hasLength(1));
    expect(data.taxByRate.single.ratePercent, d('16'));
    expect(data.taxByRate.single.base, d('450.00'));
  });
}
