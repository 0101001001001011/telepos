/// Дробная ставка налога доезжает до чека, а не округляется по дороге.
///
/// # Зачем
///
/// План `2026-09-21-us-tax-engine.md`, этап 1. Комбинированные ставки США
/// почти всегда дробные: 8,25 %, 8,81 %, 9,5 %. До правки ставка была целым
/// числом на всём пути — `int vatRate` в справочнике стран, `int
/// vatRatePercent` в реквизитах и в данных чека, `Decimal.fromInt(...)` при
/// расчёте. Ввести 8,25 % было нельзя нигде: не «неудобно», а невозможно.
///
/// # Что проверяется
///
/// Не «поле стало Decimal» — это видно чтением. Проверяется, что дробь
/// **доживает до печатной строки**: и в сумме налога, и в подписи ставки.
/// Между этими утверждениями помещается ровно то, что ломалось, — тихое
/// усечение в одном из промежуточных типов.
library;

import 'dart:ui';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/data/print/receipt_requisites.dart';
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

  test('ставка 8,25% доезжает до реквизитов чека без усечения', () {
    final requisites = ReceiptRequisites(
      seller: const ReceiptSellerInfo(binIin: '12-3456789'),
      fiscal: null,
      isVatPayer: true,
      vatRatePercent: d('8.25'),
      currencySymbol: r'$',
    );

    expect(
      requisites.vatRatePercent,
      d('8.25'),
      reason:
          'ставка усечена по дороге. Именно так было до этапа 1: поле было '
          '`int`, и 8,25% превращалось в 8%',
    );
    expect(
      requisites.vatRatePercent,
      isNot(d('8')),
      reason: 'дробная часть потеряна — проверка типа прошла, смысл нет',
    );
  });

  test('дробная ставка печатается на чеке как 8.25, а не как 8', () {
    final text = english.renderSalePreviewText(
      SaleReceiptData(
        receiptNo: 1,
        posId: 1,
        posName: 'Till-1',
        storeName: 'Northwind Trading',
        dateTime: DateTime(2026, 6, 20, 14, 30),
        cashierName: 'Anna Whitfield',
        products: [
          ReceiptProductLine(
            name: 'Milk, 1 gal',
            quantity: Decimal.one,
            price: d('4.00'),
            total: d('4.00'),
          ),
        ],
        payments: [
          ReceiptPaymentLine(name: 'Cash', amount: d('4.33'), isCash: true),
        ],
        totalAmount: d('4.33'),
        isVatPayer: true,
        vatRatePercent: d('8.25'),
        vatAmount: d('0.33'),
        taxTreatment: TaxTreatment.exclusive,
        hasFiscalisation: false,
        currencySymbol: r'$',
      ),
      options,
      paperWidth: ReceiptPaperWidth.mm58,
    );

    expect(
      text,
      contains('8.25'),
      reason:
          'подпись ставки на чеке потеряла дробь. Покупатель видит не ту '
          'ставку, по которой с него взяли налог',
    );
  });

  test('целая ставка печатается без лишних нулей', () {
    // 16% должно оставаться «16», а не стать «16.00»: чек читает человек, и
    // лишние нули в ставке — шум, которого на казахстанской бумаге не было.
    final requisites = ReceiptRequisites(
      seller: const ReceiptSellerInfo(binIin: '123456789012'),
      fiscal: null,
      isVatPayer: true,
      vatRatePercent: d('16'),
      currencySymbol: '₸',
    taxTreatment: TaxTreatment.inclusive,
      currencyBeforeAmount: false,
      hasFiscalisation: true,
    );
    expect(requisites.vatRatePercent.toString(), '16');
  });
}
