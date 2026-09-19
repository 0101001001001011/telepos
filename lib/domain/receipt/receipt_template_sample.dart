/// Образцовый чек экрана шаблонов — то, на чём видно раскладку.
///
/// # Почему файл переехал из `lib/presentation/`
///
/// Он жил в `lib/presentation/screens/settings/receipt/` с того дня, когда
/// образец собирал сам экран. С 2026-09-18 его собирает касса
/// (`LocalReceiptTemplateSetup`), потому что предпросмотр стал методом
/// доменного порта, — а `lib/data/`, импортирующий `lib/presentation/`,
/// это слой наизнанку.
///
/// Переезд ничего не стоил и ничего не изменил: здесь нет ни виджета, ни
/// `BuildContext`, ни локализации — чистый Dart над доменными типами
/// (`SaleReceiptData`, `Decimal`, `VatCalculator`). Место ему в домене было
/// и до переезда.
library;

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/fiscal/vat_calculator.dart';

SaleReceiptData sampleSaleReceiptData({
  required String storeName,
  required String posName,
  String? binIin,
  String? address,
  bool isVatPayer = true,
  String currencySymbol = '₸',
}) {
  final total = Decimal.parse('3300.00');
  return SaleReceiptData(
    receiptNo: 1024,
    posId: 1,
    posName: posName,
    storeName: storeName.isEmpty ? 'ТОО «Образец»' : storeName,
    dateTime: DateTime.now(),
    cashierName: 'Иванов И.',
    products: [
      ReceiptProductLine(
        name: 'Хлеб «Бородинский»',
        quantity: Decimal.parse('2.000'),
        price: Decimal.parse('250.00'),
        total: Decimal.parse('500.00'),
      ),
      ReceiptProductLine(
        name: 'Молоко 3.2% 1л',
        quantity: Decimal.parse('3.000'),
        price: Decimal.parse('450.00'),
        total: Decimal.parse('1300.00'),
        discountAmount: Decimal.parse('50.00'),
      ),
      ReceiptProductLine(
        name: 'Кофе зерновой 250г',
        quantity: Decimal.parse('1.000'),
        price: Decimal.parse('1500.00'),
        total: Decimal.parse('1500.00'),
      ),
    ],
    payments: [
      ReceiptPaymentLine(
        name: 'Наличные',
        amount: Decimal.parse('4000.00'),
        isCash: true,
      ),
    ],
    totalAmount: total,
    change: Decimal.parse('700.00'),
    customerName: null,
    seller: ReceiptSellerInfo(
      binIin: (binIin?.isNotEmpty ?? false) ? binIin : '012345678901',
      address: (address?.isNotEmpty ?? false)
          ? address
          : 'г. Алматы, ул. Абая, 10',
    ),
    fiscal: const ReceiptFiscalInfo(
      fiscalNumber: '123456789012',
      fiscalSign: '987654321',
      rnm: 'KZ00000123456',
      znm: 'SWK00012345',
      ofdName: 'АО «ИНФОРМАЦИОННО-УЧЁТНЫЙ ЦЕНТР»',
      ticketUrl: 'https://consumer.oofd.kz/ticket/abc123',
    ),
    isVatPayer: isVatPayer,
    vatAmount: isVatPayer ? VatCalculator.extractVatFromGross(total) : null,
    vatRatePercent: VatCalculator.standardRatePercent,
    currencySymbol: currencySymbol,
  );
}
