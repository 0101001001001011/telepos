import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/printer/receipt_builder.dart';

import 'support/receipt_wire_stand.dart' show printedLines;

/// Разметка колонок и замена знаков: что раньше кого.
///
/// ## Почему это отдельная проба
///
/// Замена `₸` → `тг` длиннее исходного знака. Ширина строки чека считается по
/// `String.length` **до** кодирования (`addRow`, `_truncate`, перенос по
/// словам). Сделай замену внутри кодировщика — и строка на бумаге выйдет
/// длиннее ленты ровно на разницу длин, а колонка суммы уедет за край.
/// Проба через эмулятор этого не поймает: она читает текст, а не считает
/// колонки.
///
/// ## Чем краснеет
///
/// Верни `_paper` в `ReceiptBuilder` пустым (`(text) => text`) — замена
/// останется (её повторяет `encodePaper`), но произойдёт **после** разметки, и
/// строка с тенге станет на один знак шире ленты. Падает «ширина строки —
/// ровно лента».
///
/// ## Чего это НЕ доказывает
///
/// Ничего о том, как принтер отрисует эти байты, — только их число и порядок.
void main() {
  /// Первая непустая строка бумаги — разобранная тем же разборщиком, каким
  /// её читает эмулятор принтера, без выравнивающих пробелов предпросмотра.
  String paperLine(List<int> bytes) =>
      printedLines(bytes).firstWhere((l) => l.isNotEmpty);

  for (final width in const [32, 48]) {
    group('лента $width колонок', () {
      test('строка «подпись … сумма» со знаком тенге — ровно лента', () {
        final bytes = ReceiptBuilder(charWidth: width)
            .addRow('ИТОГО:', '=3760.00 ₸')
            .build();
        final line = paperLine(bytes);
        expect(
          line.length,
          width,
          reason: 'строка «$line» шире ленты: замена ₸→тг ушла после разметки',
        );
        expect(line, startsWith('ИТОГО:'));
        expect(line, endsWith('=3760.00 тг'));
      });

      test('строка по центру со знаком тенге не длиннее ленты', () {
        final line = paperLine(
          ReceiptBuilder(charWidth: width).addCentered('СДАЧА 240.00 ₸').build(),
        );
        expect(line.length, lessThanOrEqualTo(width), reason: line);
        expect(line, 'СДАЧА 240.00 тг');
        expect(
          line.length,
          'СДАЧА 240.00 тг'.length,
          reason: 'обрезка считалась по исходной длине, а не по бумажной',
        );
      });

      test('казахское название товара не меняет длину строки', () {
        final line = paperLine(
          ReceiptBuilder(charWidth: width).addRow('Сүт Айналайын', '480.00')
              .build(),
        );
        expect(line.length, width);
        expect(line, startsWith('Сут Айналайын'));
      });

      test('разделитель — ровно лента', () {
        expect(
          paperLine(ReceiptBuilder(charWidth: width).addLine().build()).length,
          width,
        );
      });
    });
  }

  test('знака вопроса в казахской строке не остаётся', () {
    final line = paperLine(
      ReceiptBuilder(charWidth: 48).addLeft('Сәлеметсіз бе! Рақмет ₸').build(),
    );
    expect(line, isNot(contains('?')));
    expect(line, 'Салеметсиз бе! Ракмет тг');
  });
}
