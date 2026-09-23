/// Печатные документы говорят на языке кассы, а не всегда по-русски.
///
/// # Чем это оплачено
///
/// До 2026-09-21 каждая строка чека, X- и Z-отчёта была русским литералом в
/// слое данных. Механизма языка в печати не было вовсе — ни заготовки, ни
/// попытки: интерфейс к тому времени говорил на пяти языках, а бумага на
/// одном, у всех и всегда.
///
/// Нашлось это не проверкой, а **съёмкой**: вкладка диагностики показывает
/// чек текстом, раскодированным из байтов, ушедших в порт, и в английском
/// ролике он оказался русским. Ни одна проба не покраснела, потому что все
/// прогоны идут при русском языке, где новый код неотличим от старого.
///
/// # Что именно проверяется
///
/// Не «ключи подставлены» — это проверяется чтением. Проверяется, что в
/// СОБРАННОМ тексте документа при английском языке нет кириллицы. Между
/// этими двумя утверждениями помещается ровно тот дефект, который был:
/// литерал, которого никто не заметил.
///
/// Данные документа намеренно английские: имя кассира и название магазина —
/// данные магазина, а не интерфейс, и кириллица в них законна. Сторож,
/// краснеющий на имени «Иванова», проверял бы затравку, а не продукт.
library;

import 'dart:ui';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/hardware/paper_charset.dart';
import 'package:telepos/l10n/app_localizations.dart';

final _cyrillic = RegExp('[Ѐ-ӿ]');

/// Замены знаков, которых нет в кодовой странице принтера.
///
/// `₸` не существует ни в CP866, ни в CP1251, и `paper_charset.dart`
/// подставляет вместо него «тг» — сокращение, которым тенге подписан в
/// казахстанской рознице. Там же прямо отвергнута латинская `T` как
/// выдуманное соответствие, которое выглядит правдой. Это решение про
/// КОДОВУЮ СТРАНИЦУ, а не про язык документа, и сторож языка краснеть на
/// него не должен.
///
/// Набор берётся из самой таблицы, а не переписан рядом: список рядом
/// разошёлся бы с ней на первой же добавленной валюте.
///
/// Берутся только замены, где ИСХОДНЫЙ знак — не кириллица: `₸ → тг`,
/// `₽ → руб`, `₴ → грн`. Казахские буквы в той же таблице заменяются
/// русскими, и это замена кириллицы кириллицей — её стирать нельзя, иначе
/// сторож перестанет видеть настоящие русские слова: одиночная «г» из
/// `ғ → г` съела бы «тг» раньше, чем дело дошло бы до валюты.
///
/// Длинные замены идут первыми: сотри «г» раньше «тг», и от валюты
/// останется «т» — всё ещё кириллица, и сторож краснел бы на том, что уже
/// разрешил.
final _printerSubstitutions =
    (unsupportedReplacements.entries
            .where((e) => !_cyrillic.hasMatch(String.fromCharCode(e.key)))
            .where((e) => _cyrillic.hasMatch(e.value))
            .map((e) => e.value)
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length)))
        .toList();

/// Убирает замены кодовой страницы. Всё, что осталось кириллицей после
/// этого, пришло из слов документа, а не из таблицы знаков.
String _withoutSubstitutions(String line) {
  var out = line;
  for (final token in _printerSubstitutions) {
    out = out.replaceAll(token, '');
  }
  return out;
}

void main() {
  /// Служба, собирающая документы по-английски.
  ///
  /// Язык передаётся доводом, а не через `ReceiptLanguage.current`: глобальное
  /// состояние связало бы прогоны порядком запуска, и одна проба чинила бы
  /// или ломала соседнюю.
  final english = ReceiptPrintServiceImpl(
    strings: () => lookupAppLocalizations(const Locale('en')),
  );

  SaleReceiptData saleData() => SaleReceiptData(
    receiptNo: 42,
    posId: 1,
    posName: 'Till-1',
    storeName: 'Northwind Trading',
    dateTime: DateTime(2026, 6, 20, 14, 30),
    cashierName: 'Anna Whitfield',
    products: [
      ReceiptProductLine(
        name: 'Milk, 1 L',
        quantity: Decimal.fromInt(2),
        price: Decimal.parse('150.00'),
        total: Decimal.parse('300.00'),
      ),
    ],
    payments: [
      ReceiptPaymentLine(
        name: 'Cash',
        amount: Decimal.parse('800.00'),
        isCash: true,
      ),
    ],
    totalAmount: Decimal.parse('300.00'),
    change: Decimal.parse('200.00'),
    seller: const ReceiptSellerInfo(
      binIin: '123456789012',
      address: 'Almaty, Abay street 10',
    ),
    isVatPayer: true,
    vatRatePercent: Decimal.fromInt(16),
    vatAmount: Decimal.parse('110.34'),
  );

  /// Настройки по УМОЛЧАНИЮ — как у магазина, который ничего не правил.
  ///
  /// # Здесь стояло другое, и это было ошибкой
  ///
  /// Проба подавала чеку свой английский подвал `'Thank you!'`, а в
  /// пояснении говорилось, что умолчание — «настройка, а не продукт».
  /// Рассуждение неверное: умолчание и есть продукт. Магазин, который
  /// подвал не трогал, получал на английском чеке русское «Спасибо за
  /// покупку!» — и сторож этого не видел, потому что сам подставлял
  /// правильное значение вместо продуктового.
  ///
  /// Среда не должна быть добрее продукта. Увидел это дубль урока 1.3
  /// 2026-09-21, а не проба.
  const options = ReceiptOptions();

  test('чек продажи по-английски не содержит кириллицы', () {
    final text = english.renderSalePreviewText(
      saleData(),
      options,
      paperWidth: ReceiptPaperWidth.mm58,
    );

    final offenders = text
        .split('\n')
        .where((l) => _cyrillic.hasMatch(_withoutSubstitutions(l)))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'эти строки уедут на бумагу по-русски у человека, выбравшего '
          'английский. Заведите ключ в `assets/i18n/*.arb` и возьмите слово '
          'из `_strings()`, а не исключение здесь:\n${offenders.join('\n')}',
    );
  });

  test('английский чек всё-таки собрался — сторож смотрит не в пустоту', () {
    final text = english.renderSalePreviewText(
      saleData(),
      options,
      paperWidth: ReceiptPaperWidth.mm58,
    );

    // Без этой проверки пустая строка прошла бы первую пробу с блеском:
    // в пустоте кириллицы нет.
    expect(text, contains('SALE'), reason: 'заголовок документа по-английски');
    expect(text, contains('TOTAL'), reason: 'итог по-английски');
    expect(text, contains('Milk, 1 L'), reason: 'строка товара на месте');
    expect(
      text.split('\n').length,
      greaterThan(10),
      reason: 'документ подозрительно короткий — собралось не всё',
    );
  });

  test('русский чек не сдвинулся: та же лента, что была до правки', () {
    final russian = ReceiptPrintServiceImpl(
      strings: () => lookupAppLocalizations(const Locale('ru')),
    );
    final text = russian.renderSalePreviewText(
      saleData(),
      options,
      paperWidth: ReceiptPaperWidth.mm58,
    );

    // Локализация не должна была ничего поменять там, где язык прежний.
    expect(text, contains('ПРОДАЖА'));
    expect(text, contains('ИТОГО'));
    expect(text, contains('Кассир'));
  });

  group('уклад США: налог добавляется к подытогу, фискализации нет', () {
    /// Чек американской кассы: цены без налога, налог отдельной строкой.
    SaleReceiptData usData() => SaleReceiptData(
      receiptNo: 7,
      posId: 1,
      posName: 'Till-1',
      storeName: 'Northwind Trading',
      dateTime: DateTime(2026, 6, 20, 14, 30),
      cashierName: 'Anna Whitfield',
      products: [
        ReceiptProductLine(
          name: 'Milk, 1 gal',
          quantity: Decimal.one,
          price: Decimal.parse('4.00'),
          total: Decimal.parse('4.00'),
        ),
      ],
      payments: [
        ReceiptPaymentLine(
          name: 'Cash',
          amount: Decimal.parse('4.33'),
          isCash: true,
        ),
      ],
      totalAmount: Decimal.parse('4.33'),
      isVatPayer: true,
      vatRatePercent: Decimal.fromInt(8),
      vatAmount: Decimal.parse('0.33'),
      taxTreatment: TaxTreatment.exclusive,
      hasFiscalisation: false,
      currencySymbol: r'$',
    );

    String render() => english.renderSalePreviewText(
      usData(),
      options,
      paperWidth: ReceiptPaperWidth.mm58,
    );

    test('налог показан отдельной строкой между подытогом и итогом', () {
      final text = render();
      expect(text, contains('Subtotal'), reason: 'подытог без налога');
      expect(
        text,
        contains('Sales tax 8%'),
        reason:
            'налог США добавляется к подытогу и обязан быть на чеке: на '
            'ценнике его не было, и покупатель иначе не поймёт, за что '
            'заплатил сверх',
      );
      expect(text, contains('4.00'), reason: 'подытог = итог минус налог');
      expect(text, contains('4.33'), reason: 'итог с налогом');
    });

    test('ни слова про фискализацию — её в стране нет', () {
      final text = render();
      expect(
        text,
        isNot(contains('NON-FISCAL')),
        reason:
            'в стране без фискализации эта отметка читается покупателем как '
            '«чек недействителен», а не как справка о чужом законе',
      );
      expect(text, isNot(contains('FISCAL')));
    });

    test('налог не показан дважды', () {
      final text = render();
      expect(
        text,
        isNot(contains('VAT')),
        reason:
            'извлечение из брутто осмысленно только при налоге, включённом '
            'в цену; здесь он уже выведен строкой выше',
      );
      expect(text, isNot(contains('TAX GROUP')));
    });
  });
}
