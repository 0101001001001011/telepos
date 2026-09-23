import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/hardware/printer/receipt_builder.dart';
import 'package:telepos/hardware/printer/receipt_text_wrap.dart';

void main() {
  group('перенос строки чека по словам', () {
    test('слова не режутся, если помещаются целиком', () {
      expect(wrapReceiptLine('Спасибо за покупку, ждём вас снова', 16), [
        'Спасибо за',
        'покупку, ждём',
        'вас снова',
      ]);
    });

    test('строка ровно в ширину — одна строка', () {
      expect(wrapReceiptLine('a' * 32, 32), ['a' * 32]);
    });

    test('слово длиннее ширины режется по колонкам', () {
      expect(wrapReceiptLine('см. https://romashka.kz/aktsii', 10), [
        'см.',
        'https://ro',
        'mashka.kz/',
        'aktsii',
      ]);
    });

    test('пустая строка — одна пустая строка, пробелы схлопываются', () {
      expect(wrapReceiptLine('', 32), ['']);
      expect(wrapReceiptLine('   ', 32), ['']);
      expect(wrapReceiptLine('а    б', 32), ['а б']);
    });
  });

  group('блок текста шаблона', () {
    test('управляющие символы вынимаются, перевод строки делит блок', () {
      const block = ReceiptTextBlock(text: 'Акция\x1Bi\r\nдня\x1D!\tТолько\x00 сегодня');
      expect(block.lines, ['Акцияi', 'дня! Только сегодня']);
    });

    test('пустые строки по краям убираются, абзацы внутри остаются', () {
      const block = ReceiptTextBlock(text: '\n  \nПервая\n\nВторая  \n \n');
      expect(block.lines, ['Первая', '', 'Вторая']);
    });

    test('блок из пробелов пуст и не даёт принтеру ни байта', () {
      const block = ReceiptTextBlock(text: ' \n\t\n ', bold: true, doubleSize: true);
      expect(block.isEmpty, isTrue);
      expect(ReceiptBuilder(charWidth: 32).addTextBlock(block).build(), isEmpty);
    });
  });

  group('шаблон чека в JSON', () {
    test('шаблон до правки читается без потерь, ширина и выключатели реквизитов — нет', () {
      final legacy = ReceiptOptions.fromJson({
        'paperWidth': 80,
        'headerText': 'ТОО Ромашка',
        'footerText': 'Спасибо!',
        'extraFooterLines': ['Возврат 14 дней', ''],
        'showQr': false,
        'showBin': false,
        'showVat': false,
        'showCashier': false,
      });
      expect(legacy.header.text, 'ТОО Ромашка');
      expect(legacy.header.align, ReceiptTextAlign.center);
      expect(legacy.footer!.lines, ['Спасибо!', 'Возврат 14 дней']);
      expect(legacy.showCashier, isFalse);
      final stored = legacy.encode();
      for (final gone in ['paperWidth', 'showQr', 'showBin', 'showVat']) {
        expect(stored, isNot(contains(gone)));
      }
    });

    test('подвал старого шаблона: «не задан» и «стёрт» — разные вещи', () {
      // Здесь стояло `expect(..., 'Спасибо за покупку!')`: русская строка
      // была зашита в разборщике и уезжала на чек любого языка. Теперь
      // незаданный подвал — `null`, а слова ставит печать, зная язык.
      expect(
        ReceiptOptions.fromJson({}).footer,
        isNull,
        reason: 'ключа не было — подвал не задан, и это не то же, что пустой',
      );
      expect(
        ReceiptOptions.fromJson({'footerText': ''}).footer?.isEmpty,
        isTrue,
        reason:
            'владелец стёр подвал нарочно; вернуть ему благодарность '
            'значило бы не услышать',
      );
    });

    test('оформление блоков переживает сохранение', () {
      const options = ReceiptOptions(
        header: ReceiptTextBlock(
          text: 'Строка 1\nСтрока 2',
          align: ReceiptTextAlign.right,
          bold: true,
          doubleSize: true,
        ),
        footer: ReceiptTextBlock(text: 'Пока', align: ReceiptTextAlign.left),
      );
      final back = ReceiptOptions.decode(options.encode());
      expect(back.header.text, 'Строка 1\nСтрока 2');
      expect(back.header.align, ReceiptTextAlign.right);
      expect(back.header.bold, isTrue);
      expect(back.header.doubleSize, isTrue);
      expect(back.footer!.align, ReceiptTextAlign.left);
      expect(back.footer!.bold, isFalse);
    });
  });
}
