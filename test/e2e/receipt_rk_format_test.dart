import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

void main() {
  final service = ReceiptPrintServiceImpl();

  SaleReceiptData buildData({ReceiptFiscalInfo? fiscal}) {
    return SaleReceiptData(
      receiptNo: 42,
      posId: 1,
      posName: 'Касса №1',
      storeName: 'ТОО «Новая Заря»',
      dateTime: DateTime(2026, 6, 20, 14, 30),
      cashierName: 'Иванова А.',
      products: [
        ReceiptProductLine(
          name: 'Хлеб «Бородинский»',
          quantity: Decimal.fromInt(2),
          price: Decimal.parse('150.00'),
          total: Decimal.parse('300.00'),
        ),
        ReceiptProductLine(
          name: 'Молоко 3.2%',
          quantity: Decimal.one,
          price: Decimal.parse('560.00'),
          total: Decimal.parse('500.00'),
          discountAmount: Decimal.parse('60.00'),
          originalPrice: Decimal.parse('560.00'),
        ),
      ],
      payments: [
        ReceiptPaymentLine(
          name: 'Наличные',
          amount: Decimal.parse('800.00'),
          isCash: true,
        ),
      ],
      totalAmount: Decimal.parse('800.00'),
      change: Decimal.parse('200.00'),
      seller: const ReceiptSellerInfo(
        binIin: '123456789012',
        address: 'г. Алматы, ул. Абая 10',
      ),
      isVatPayer: true,
      vatRatePercent: 16,
      vatAmount: Decimal.parse('110.34'),
      fiscal: fiscal,
    );
  }

  const fiscal = ReceiptFiscalInfo(
    fiscalNumber: '987654321',
    fiscalSign: '12345678',
    rnm: 'RNM-001122',
    znm: 'ZNM-7788',
    ofdName: 'WebKassa',
    ticketUrl: 'https://consumer.oofd.kz/ticket/abc123',
  );

  const options = ReceiptOptions();

  test('Общая часть присутствует на ОБОИХ чеках (одинаковый макет)', () {
    for (final f in [fiscal, null]) {
      final text = service.renderSalePreviewText(buildData(fiscal: f), options);
      expect(text, contains('БИН/ИИН: 123456789012'), reason: 'БИН в шапке');
      expect(text, contains('г. Алматы'), reason: 'адрес в шапке');
      expect(text, contains('Чек №'));
      expect(text, contains('Иванова А.'));
      expect(text, contains('ПРОДАЖА'));
      expect(text, contains('Хлеб «Бородинский»'));
      expect(text, contains('2.00 шт x 150.00'));
      expect(text, contains('=300.00'));
      expect(text, contains('-60.00'), reason: 'скидка из позиции не упущена');
      expect(text, contains('ИТОГО:'));
      expect(text, contains('=800.00'));
      expect(text, contains('НАЛИЧНЫМИ'));
      expect(text, contains('Сдача:'));
      expect(text, contains('ПО НАЛОГУ А:'));
      expect(text, contains('НДС-16%:'));
      expect(text, contains('=110.34'), reason: 'сумма НДС из данных');
    }
  });

  test('Фискальный чек: блок ОФД + QR + пометка ФИСКАЛЬНЫЙ ЧЕК', () {
    final text = service.renderSalePreviewText(
      buildData(fiscal: fiscal),
      options,
    );
    expect(text, contains('ОФД WebKassa'));
    expect(text, contains('ФИСК. ПРИЗНАК:'));
    expect(text, contains('12345678'));
    expect(text, contains('РНМ:'));
    expect(text, contains('RNM-001122'));
    expect(text, contains('ЗНМ:'));
    expect(text, contains('ВРЕМЯ:'));
    final flat = text.replaceAll('\n', '').replaceAll(' ', '');
    expect(
      flat,
      contains('https://consumer.oofd.kz/ticket/abc123'),
      reason: 'URL проверки не обрезан',
    );
    expect(text, contains('ФИСКАЛЬНЫЙ ЧЕК'));
    expect(text, contains('[ QR ]'), reason: 'QR только на фискальном');
    expect(text, isNot(contains('НЕФИСКАЛЬНЫЙ ЧЕК')));
  });

  test('Нефискальный чек: пометка НЕФИСКАЛЬНЫЙ, без ОФД и без QR', () {
    final text = service.renderSalePreviewText(buildData(), options);
    expect(text, contains('НЕФИСКАЛЬНЫЙ ЧЕК'));
    expect(text, isNot(contains('[ QR ]')), reason: 'нет QR на нефискальном');
    expect(text, isNot(contains('ОФД')));
    expect(text, isNot(contains('РНМ:')));
    expect(text, isNot(contains('ФИСК. ПРИЗНАК:')));
  });

  test('Невыставленные фиск.реквизиты → чек печатается как нефискальный', () {
    final data = buildData();
    expect(data.isFiscal, isFalse);
  });

  test('Касса берёт ЗНМ из фиск.реквизитов, иначе имя кассы', () {
    final fiscalText = service.renderSalePreviewText(
      buildData(fiscal: fiscal),
      options,
    );
    expect(fiscalText, contains('ZNM-7788'), reason: 'ЗНМ как идент. кассы');

    final plainText = service.renderSalePreviewText(buildData(), options);
    expect(plainText, contains('Касса №1'), reason: 'fallback на имя кассы');
  });

  test('НДС не печатается, если отключён в настройках', () {
    final text = service.renderSalePreviewText(
      buildData(fiscal: fiscal),
      options.copyWith(showVat: false),
    );
    expect(text, isNot(contains('НДС-16%:')));
  });
}
