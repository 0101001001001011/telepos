/// Строки сертификатов X/Z-отчёта **на бумаге**, а не в возвращённом объекте.
///
/// # Почему проба через эмулятор, а не через предпросмотр
///
/// Потому что предпросмотр — это второй путь, и он однажды уже расходился с
/// бумагой (`receipt_template_wire_test.dart`). Здесь задание уходит в
/// **настоящий сокет** эмулятора ESC/POS через ту же очередь печати, какой
/// пользуется касса, и утверждения делаются о строках, которые эмулятор
/// разобрал из потока байт. Отдельным случаем проверяется, что предпросмотр
/// даёт **те же строки**: если однажды разойдутся — покраснеет.
///
/// # Ширина берётся у привязки принтера
///
/// Стенд сохраняет ширину тем же репозиторием, каким её сохраняет экран
/// «Настройки принтера», и ни одна проба здесь не называет 32 или 48 сама.
/// Отчёты уже однажды печатались зашитыми 32 колонками — сторож
/// `receipt_paper_width_wire_test.dart`.
///
/// # Чего эти пробы НЕ доказывают
///
/// Не доказывают, что числа верные: откуда они берутся и почему сходятся со
/// счётом обязательства — `test/data/payment/certificate_shift_totals_test
/// .dart`. Здесь доказывается только то, что посчитанное доходит до бумаги и
/// подписано так, что кассир не сложит его с выручкой.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

import 'support/receipt_wire_stand.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  Future<PrintSubmitOutcome> printX(
    ReceiptPrintService service, {
    required Decimal issued,
    required Decimal redeemed,
  }) => service.printXReport(
    storeName: 'ТОО ТестПОС',
    posName: 'Касса 1',
    cashierName: 'Иванова А.',
    dateTime: DateTime(2026, 9, 19, 13),
    saleCount: 3,
    saleTotal: d('1500.00'),
    refundCount: 1,
    refundTotal: d('250.00'),
    cashInDrawer: d('1250.00'),
    certificatesIssued: issued,
    certificatesRedeemed: redeemed,
  );

  Future<PrintSubmitOutcome> printZ(
    ReceiptPrintService service, {
    required Decimal issued,
    required Decimal redeemed,
  }) => service.printZReport(
    storeName: 'ТОО ТестПОС',
    posName: 'Касса 1',
    cashierName: 'Иванова А.',
    shiftStart: DateTime(2026, 9, 19, 9),
    shiftEnd: DateTime(2026, 9, 19, 21),
    saleCount: 3,
    saleTotal: d('1500.00'),
    refundCount: 1,
    refundTotal: d('250.00'),
    cashStart: Decimal.zero,
    cashEnd: d('1250.00'),
    cashIncome: Decimal.zero,
    cashExpense: Decimal.zero,
    certificatesIssued: issued,
    certificatesRedeemed: redeemed,
  );

  List<String> textsOf(List<PaperEntry> paper) => [
    for (final e in paper)
      if (e.isLine) e.text,
  ];

  /// Строка отчёта «подпись … число»: подпись слева, число справа, добито
  /// пробелами до полной ширины.
  Matcher rowWith(String label, String value) => predicate<String>(
    (line) => line.trimRight().startsWith(label) && line.endsWith(value),
    'строка «$label … $value»',
  );

  for (final mm in const [58, 80]) {
    final columns = ReceiptPaperWidth.fromMm(mm).charWidth;

    group('лента $mm мм ($columns колонок)', () {
      late ReceiptWireStand stand;
      late ReceiptPrintService service;

      setUp(() async {
        stand = await ReceiptWireStand.boot(paperWidthMm: mm);
        service = ReceiptPrintServiceImpl();
      });

      test('X-отчёт: обязательство и отданный товар — двумя строками',
          () async {
        final paper = paperOf(
          await stand.nextJob(
            () => printX(service, issued: d('5000.00'), redeemed: d('1200.50')),
          ),
        );
        final lines = textsOf(paper);

        expect(
          lines,
          contains(startsWith('СЕРТИФИКАТЫ (НЕ ВЫРУЧКА)')),
          reason: 'без заголовка кассир сложит обязательство с выручкой',
        );
        expect(
          lines,
          contains(rowWith('Выпущено (долг кассы):', '5000.00')),
        );
        expect(
          lines,
          contains(rowWith('Погашено (товаром):', '1200.50')),
        );

        // **Итог смены их не трогает.** Строка «ИТОГО В КАССЕ» осталась
        // ровно тем, чем была: сколько денег в ящике, а не «выручка минус
        // сертификаты».
        expect(lines, contains(rowWith('ИТОГО В КАССЕ:', '1250.00')));

        // # Ни одного «?» — знак, которого нет в кодовой странице
        //
        // Измерено, а не предположено: первая редакция писала «СЕРТИФИКАТЫ
        // — НЕ ВЫРУЧКА», и длинное тире вышло на ленту как «?». Ошибки при
        // этом не было нигде: ни в очереди, ни в принтере, ни в наборе.
        // Поэтому утверждение стоит о **бумаге**, а не об исходнике.
        for (final line in lines.where(
          (l) =>
              l.startsWith('СЕРТИФИКАТЫ') ||
              l.trimRight().startsWith('Выпущено') ||
              l.trimRight().startsWith('Погашено'),
        )) {
          expect(
            line,
            isNot(contains('?')),
            reason: 'знак вне кодовой страницы вышел на ленту как «?»: $line',
          );
        }
      });

      test('Z-отчёт: те же две строки, до денежных операций', () async {
        final paper = paperOf(
          await stand.nextJob(
            () => printZ(service, issued: d('5000.00'), redeemed: d('1200.50')),
          ),
        );
        final lines = textsOf(paper);

        final certAt = lines.indexWhere(
          (l) => l.startsWith('СЕРТИФИКАТЫ (НЕ ВЫРУЧКА)'),
        );
        final cashAt = lines.indexWhere(
          (l) => l.startsWith('ДЕНЕЖНЫЕ ОПЕРАЦИИ'),
        );
        expect(certAt, greaterThan(0), reason: 'блока сертификатов нет');
        expect(
          certAt,
          lessThan(cashAt),
          reason: 'обязательство читается вместе с выручкой, а не среди '
              'внесений и изъятий',
        );
        expect(lines, contains(rowWith('Выпущено (долг кассы):', '5000.00')));
        expect(lines, contains(rowWith('Погашено (товаром):', '1200.50')));
      });

      test('ширина строк сертификатов — от привязки принтера', () async {
        final job = await stand.nextJob(
          () => printX(service, issued: d('5000.00'), redeemed: d('1200.50')),
        );
        expect(
          printedColumns(job),
          columns,
          reason: 'отчёт собран в ${printedColumns(job)} колонок вместо '
              '$columns — ширину снова взяли не у привязки',
        );
        // Подпись не съедена усечением на узкой ленте: `addRow` режет левую
        // часть под число, и слишком длинная подпись молча стала бы
        // «Выпущено (долг кас».
        expect(
          textsOf(paperOf(job)),
          contains(rowWith('Выпущено (долг кассы):', '5000.00')),
        );
      });

      test('сертификатов не было — блока нет вовсе', () async {
        final lines = textsOf(
          paperOf(
            await stand.nextJob(
              () => printX(
                service,
                issued: Decimal.zero,
                redeemed: Decimal.zero,
              ),
            ),
          ),
        );
        expect(
          lines.where((l) => l.startsWith('СЕРТИФИКАТЫ')),
          isEmpty,
          reason: 'магазин без сертификатов не обязан читать про них два '
              'нуля на каждом отчёте',
        );
        // Слом в обратную сторону: остальной отчёт на месте, а не пуст.
        expect(lines, contains(rowWith('ИТОГО В КАССЕ:', '1250.00')));
      });

      test('одно из двух ненулевое — блок печатается целиком', () async {
        // Смена, в которую только гасили: выпущено ноль. Строка «Выпущено:
        // 0.00» здесь **нужна** — иначе читатель не отличит «не выпускали»
        // от «строку забыли напечатать».
        final lines = textsOf(
          paperOf(
            await stand.nextJob(
              () => printX(
                service,
                issued: Decimal.zero,
                redeemed: d('700.00'),
              ),
            ),
          ),
        );
        expect(lines, contains(rowWith('Выпущено (долг кассы):', '0.00')));
        expect(lines, contains(rowWith('Погашено (товаром):', '700.00')));
      });

      test('предпросмотр и бумага говорят одно и то же', () async {
        final paper = textsOf(
          paperOf(
            await stand.nextJob(
              () =>
                  printZ(service, issued: d('5000.00'), redeemed: d('1200.50')),
            ),
          ),
        );
        final preview = service.renderZReportPreview(
          paperWidth: ReceiptPaperWidth.fromMm(mm),
          storeName: 'ТОО ТестПОС',
          posName: 'Касса 1',
          cashierName: 'Иванова А.',
          shiftStart: DateTime(2026, 9, 19, 9),
          shiftEnd: DateTime(2026, 9, 19, 21),
          saleCount: 3,
          saleTotal: d('1500.00'),
          refundCount: 1,
          refundTotal: d('250.00'),
          cashStart: Decimal.zero,
          cashEnd: d('1250.00'),
          cashIncome: Decimal.zero,
          cashExpense: Decimal.zero,
          certificatesIssued: d('5000.00'),
          certificatesRedeemed: d('1200.50'),
        );

        for (final line in paper.where(
          (l) =>
              l.startsWith('СЕРТИФИКАТЫ') ||
              l.trimRight().startsWith('Выпущено') ||
              l.trimRight().startsWith('Погашено'),
        )) {
          expect(
            preview,
            contains(line.trimRight()),
            reason: 'предпросмотр разошёлся с бумагой на строке «$line»',
          );
        }
      });
    });
  }
}
