/// Американский чек целиком: доллар, налог сверху, стек юрисдикций,
/// освобождённые продукты.
///
/// # Зачем
///
/// План `2026-09-21-us-tax-engine.md`, этап 5. Четыре предыдущих этапа
/// чинили по одной дыре и проверялись порознь. Здесь они сходятся в один
/// документ — тот самый, который увидит зритель ролика.
///
/// Заказчик просил взять самый сложный штат, чтобы поймать больше дыр.
/// Колорадо — общепризнанно худший случай: города с самоуправлением
/// администрируют свою часть налога сами, и на чеке стоит стек из четырёх
/// юрисдикций.
///
/// # Откуда числа
///
/// Денвер, 2026: штат 2,90 % + город 5,15 % + RTD 1,00 % + SCFD 0,10 % =
/// **9,15 %**. Сверено по двум источникам, включая собственное налоговое
/// руководство Денвера (Topic No. 70, 2026), которое называет городские
/// 5,15 %. Первичная публикация DR 1002 недоступна для чтения машиной
/// (403), поэтому числа помечены как сверяемые перед съёмкой: ставки
/// Колорадо меняются дважды в год, 1 января и 1 июля.
///
/// **Облагаемость — данные демонстрации, а не утверждение о праве
/// Колорадо.** Что именно освобождено в конкретном городе с
/// самоуправлением, надо брать из источника; здесь показан механизм, и
/// корзина собрана по общему образцу США: продукты для дома освобождены,
/// готовая еда облагается.
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
  const options = ReceiptOptions(
    footer: ReceiptTextBlock(text: 'Thank you for shopping with us!'),
  );
  Decimal d(String v) => Decimal.parse(v);

  /// Денверская корзина: молоко освобождено, кофе облагается.
  SaleReceiptData denverBasket() => SaleReceiptData(
    receiptNo: 1042,
    posId: 1,
    posName: 'Till-1',
    storeName: 'Northwind Trading',
    dateTime: DateTime(2026, 9, 21, 12, 30),
    cashierName: 'Anna Whitfield',
    products: [
      ReceiptProductLine(
        name: 'Milk, 1 gal',
        quantity: Decimal.one,
        price: d('4.29'),
        total: d('4.29'),
        isTaxExempt: true,
      ),
      ReceiptProductLine(
        name: 'Hot coffee, large',
        quantity: Decimal.fromInt(2),
        price: d('3.50'),
        total: d('7.00'),
        taxRatePercent: d('9.15'),
      ),
    ],
    payments: [
      ReceiptPaymentLine(name: 'Card', amount: d('11.93'), isCash: false),
    ],
    // 4.29 освобождено + 7.00 облагаемых + 0.64 налога.
    totalAmount: d('11.93'),
    isVatPayer: true,
    vatRatePercent: d('9.15'),
    taxTreatment: TaxTreatment.exclusive,
    hasFiscalisation: false,
    currencySymbol: r'$',
    currencyBeforeAmount: true,
    seller: const ReceiptSellerInfo(
      binIin: '84-1234567',
      address: '1600 Blake Street, Denver, CO 80202',
    ),
    taxJurisdictions: [
      TaxJurisdiction(name: 'CO State', ratePercent: d('2.90')),
      TaxJurisdiction(name: 'Denver', ratePercent: d('5.15')),
      TaxJurisdiction(name: 'RTD', ratePercent: d('1.00')),
      TaxJurisdiction(name: 'SCFD', ratePercent: d('0.10')),
    ],
  );

  String render() => english.renderSalePreviewText(
    denverBasket(),
    options,
    paperWidth: ReceiptPaperWidth.mm80,
  );

  test('налог начислен только на облагаемое', () {
    final data = denverBasket();
    final taxable = data.taxByRate.single;

    expect(taxable.base, d('7.00'), reason: 'молоко освобождено и вне базы');
    expect(
      taxable.tax,
      d('0.64'),
      reason:
          'семь долларов по 9,15% — шестьдесят четыре цента. Посчитай налог '
          'от всего чека (11.29), вышло бы 1.03, и покупатель заплатил бы '
          'налог за молоко',
    );
  });

  test('стек юрисдикций сходится в объявленную ставку', () {
    final sum = denverBasket().taxJurisdictions.fold<Decimal>(
      Decimal.zero,
      (a, j) => a + j.ratePercent,
    );
    expect(sum, d('9.15'));
  });

  test('чек по-американски: доллар, подытог, налог, стек, освобождение', () {
    final text = render();

    expect(text, contains(r'$'), reason: 'валюта — доллар, не тенге');
    expect(text, contains('Subtotal'), reason: 'подытог без налога');
    expect(text, contains('Sales tax'), reason: 'налог с продаж, не НДС');
    expect(text, contains('9.15'), reason: 'комбинированная ставка названа');
    expect(text, contains('Denver'), reason: 'город в разбивке');
    expect(text, contains('RTD'), reason: 'спецрайон в разбивке');
    expect(text, contains('Exempt'), reason: 'освобождённое названо');
    expect(
      text,
      isNot(contains('FISCAL')),
      reason: 'фискализации в США нет, и отметок о ней быть не должно',
    );
    expect(
      text,
      isNot(contains('VAT')),
      reason: 'налог сверху не извлекается из брутто вторым разом',
    );
  });

  test('в документе нет ни одного русского слова', () {
    final cyrillic = RegExp('[Ѐ-ӿ]');
    final offenders = render().split('\n').where(cyrillic.hasMatch).toList();
    expect(
      offenders,
      isEmpty,
      reason: 'русское слово в американском чеке:\n${offenders.join('\n')}',
    );
  });
}
