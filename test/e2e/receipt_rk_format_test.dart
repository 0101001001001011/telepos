import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/sale/payment_service.dart' show FiscalState;
import 'package:telepos/domain/services/receipt_print_service.dart';

void main() {
  final service = ReceiptPrintServiceImpl();

  SaleReceiptData buildData({ReceiptFiscalInfo? fiscal, FiscalState? state}) {
    return SaleReceiptData(
      fiscalState: state,
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
      vatRatePercent: Decimal.fromInt(16),
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

  String preview(SaleReceiptData data, ReceiptOptions options) => service
      .renderSalePreviewText(data, options, paperWidth: ReceiptPaperWidth.mm58);

  test('Общая часть присутствует на ОБОИХ чеках (одинаковый макет)', () {
    for (final f in [fiscal, null]) {
      final text = preview(buildData(fiscal: f), options);
      expect(text, contains('БИН/ИИН: 123456789012'), reason: 'БИН в шапке');
      expect(text, contains('г. Алматы'), reason: 'адрес в шапке');
      expect(text, contains('Чек №'));
      expect(text, contains('Иванова А.'));
      expect(text, contains('ПРОДАЖА'));
      // Предпросмотр — те же байты, что на бумаге. Кавычек-«ёлочек» в CP866
      // нет; прежний предпросмотр показывал их, а принтер печатал «?».
      //
      // С единой таблицы символов (2026-09-19) на их месте стоят **прямые**
      // кавычки, а не «?»: знак препинания, который ни о чём не сообщает,
      // хуже похожего знака препинания. Это ухудшение, а не соответствие, и
      // предпросмотр показывает ровно то, что выйдет на бумаге.
      expect(text, contains('Хлеб "Бородинский"'));
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
    final text = preview(
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
    final text = preview(buildData(), options);
    expect(text, contains('НЕФИСКАЛЬНЫЙ ЧЕК'));
    expect(text, isNot(contains('[ QR ]')), reason: 'нет QR на нефискальном');
    expect(text, isNot(contains('ОФД')));
    expect(text, isNot(contains('РНМ:')));
    expect(text, isNot(contains('ФИСК. ПРИЗНАК:')));
  });

  /// Задача 5: подвал называет **причину**, а не только факт.
  ///
  /// «НЕФИСКАЛЬНЫЙ ЧЕК» одинаково стоял и на кассе без настроенного
  /// оператора, и на кассе, собранной без узла фискализации, — тот же
  /// дефект «три причины в одном значении», только на бумаге, которую
  /// покупатель уносит с собой.
  test('подвал называет причину, по которой документа нет', () {
    String render(FiscalState? state) =>
        preview(buildData(state: state), options);

    expect(
      render(FiscalState.operatorAbsent),
      contains('Фискальный оператор не настроен'),
    );
    expect(
      render(FiscalState.fiscalModuleAbsent),
      contains('Модуль фискализации недоступен'),
    );
    expect(
      render(FiscalState.failed),
      contains('Документ не оформлен'),
      reason: 'деньги взяты, документа нет — молчать об этом нельзя',
    );

    // Три причины — три разные строки, а не одна на всех.
    expect({
      render(FiscalState.operatorAbsent),
      render(FiscalState.fiscalModuleAbsent),
      render(FiscalState.failed),
    }, hasLength(3));

    // И «НЕФИСКАЛЬНЫЙ ЧЕК» никуда не делось: строка причины стоит под
    // ним, а не вместо него.
    expect(render(FiscalState.operatorAbsent), contains('НЕФИСКАЛЬНЫЙ ЧЕК'));
  });

  test('без причины подвал молчит — «не спрашивали» не повод утверждать', () {
    // Страховка от вырождения: строка печатается по причине, а не всегда.
    // `null` — дубликат из истории и всё, что собрано не оплатой;
    // `notRequired` — политика чека, о которой покупателю сказать нечего
    // сверх уже напечатанного «НЕФИСКАЛЬНЫЙ ЧЕК».
    for (final state in [null, FiscalState.notRequired]) {
      final text = preview(
        buildData(state: state),
        options,
      );
      expect(text, contains('НЕФИСКАЛЬНЫЙ ЧЕК'));
      expect(text, isNot(contains('Фискальный оператор не настроен')));
      expect(text, isNot(contains('Модуль фискализации недоступен')));
      expect(text, isNot(contains('Документ не оформлен')));
    }
  });

  test('Невыставленные фиск.реквизиты → чек печатается как нефискальный', () {
    final data = buildData();
    expect(data.isFiscal, isFalse);
  });

  test('Касса берёт ЗНМ из фиск.реквизитов, иначе имя кассы', () {
    final fiscalText = preview(
      buildData(fiscal: fiscal),
      options,
    );
    expect(fiscalText, contains('ZNM-7788'), reason: 'ЗНМ как идент. кассы');

    final plainText = preview(buildData(), options);
    expect(plainText, contains('Касса №1'), reason: 'fallback на имя кассы');
  });

  test('шаблон не может убрать НДС плательщика: строки НДС есть всегда', () {
    // До правки шаблон выключал НДС одной галочкой (`showVat`), и
    // фискальный чек плательщика выходил без обязательного реквизита.
    final text = preview(buildData(fiscal: fiscal), options);
    expect(text, contains('НДС-16%:'));
    expect(text, contains('=110.34'));
  });
}
