/// Денежный блок Z-отчёта обязан СХОДИТЬСЯ на бумаге.
///
/// # Что измерено 2026-09-22
///
/// Бланк печатает четыре строки — «На начало», «Приход», «Расход»,
/// «ИТОГО В КАССЕ» — и этим утверждает равенство
/// `начало + приход − расход = итого`. Не держалось ни одно слагаемое:
///
/// * «На начало» приезжало из **прошлой** смены: сборка отчёта не
///   передавала `openingCash` вовсе, поле конструктора существовало и не
///   заполнялось, а экран прикрывал дыру подстановкой остатка предыдущего
///   закрытия;
/// * «Приход» был наличной выручкой **без возвратов** (запрос отбирает по
///   `receipt_no`, а возврат ссылается на `refund_local_id`), внесений в
///   нём не было;
/// * наличные возвраты не вычитались нигде;
/// * пересчитанный ящик ломал равенство молча — строки расхождения на
///   бланке не существовало.
///
/// Здесь проверяется сам текст бумаги, а не состояние экрана: числа могут
/// сойтись в памяти и разойтись в бланке, если строку забыли напечатать.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';

void main() {
  final service = ReceiptPrintServiceImpl();

  Decimal d(String v) => Decimal.parse(v);

  String render({
    required Decimal cashStart,
    required Decimal cashIncome,
    required Decimal cashExpense,
    required Decimal cashDiscrepancy,
    required Decimal cashEnd,
  }) => service.renderZReportPreview(
    paperWidth: ReceiptPaperWidth.mm58,
    storeName: 'Corner Store',
    posName: 'Register 1',
    cashierName: 'A. Ivanova',
    shiftStart: DateTime(2026, 9, 22, 9, 0),
    shiftEnd: DateTime(2026, 9, 22, 21, 0),
    saleCount: 1,
    saleTotal: d('3.50'),
    refundCount: 0,
    refundTotal: Decimal.zero,
    cashStart: cashStart,
    cashEnd: cashEnd,
    cashIncome: cashIncome,
    cashExpense: cashExpense,
    cashDiscrepancy: cashDiscrepancy,
    certificatesIssued: Decimal.zero,
    certificatesRedeemed: Decimal.zero,
  );

  /// Числа денежного блока, снятые С БУМАГИ.
  ///
  /// Читается именно напечатанное: сойтись в памяти и разойтись в бланке —
  /// ровно тот случай, ради которого эта проба и заведена.
  List<Decimal> moneyLines(String text) {
    final numbers = <Decimal>[];
    final rx = RegExp(r'(-?\d+\.\d{2})\s*$');
    var inBlock = false;
    for (final line in text.split('\n')) {
      if (line.contains('ДЕНЕЖНЫЕ ОПЕРАЦИИ') ||
          line.contains('CASH OPERATIONS')) {
        inBlock = true;
        continue;
      }
      if (!inBlock) continue;
      final m = rx.firstMatch(line.trimRight());
      if (m != null) numbers.add(Decimal.parse(m.group(1)!));
    }
    return numbers;
  }

  test('сошедшаяся смена: начало + приход − расход = итого', () {
    // 200 подъёмных, продажа на 3.50 наличными, ничего не изымали.
    final text = render(
      cashStart: d('200.00'),
      cashIncome: d('3.50'),
      cashExpense: Decimal.zero,
      cashDiscrepancy: Decimal.zero,
      cashEnd: d('203.50'),
    );

    final lines = moneyLines(text);
    expect(
      lines.length,
      4,
      reason: 'четыре строки блока и ни одной лишней: строки расхождения у '
          'сошедшейся смены быть не должно — «Излишек 0.00» притворялся бы '
          'находкой. Напечатано: $lines',
    );
    expect(lines[0] + lines[1] - lines[2], lines[3], reason: 'бланк: $text');
  });

  test('пересчитанный ящик: расхождение печатается и держит равенство', () {
    // Тот же день, но в ящике насчитали 198.50 — недостача 5.00.
    final text = render(
      cashStart: d('200.00'),
      cashIncome: d('3.50'),
      cashExpense: Decimal.zero,
      cashDiscrepancy: d('-5.00'),
      cashEnd: d('198.50'),
    );

    final lines = moneyLines(text);
    expect(
      lines.length,
      5,
      reason: 'строка расхождения обязана появиться. Напечатано: $lines',
    );
    expect(
      lines[0] + lines[1] - lines[2] + lines[3],
      lines[4],
      reason: 'без строки расхождения «итого» разошлось бы с суммой трёх '
          'строк, и прочитать почему было бы неоткуда. Бланк: $text',
    );
  });

  test('излишек печатается своим словом, а не минусом', () {
    final text = render(
      cashStart: d('200.00'),
      cashIncome: d('3.50'),
      cashExpense: Decimal.zero,
      cashDiscrepancy: d('7.00'),
      cashEnd: d('210.50'),
    );

    expect(text, contains('Излишек'));
    expect(text, isNot(contains('Недостача')));

    final lines = moneyLines(text);
    expect(lines[0] + lines[1] - lines[2] + lines[3], lines[4]);
  });

  test('внесение и наличный возврат стоят в блоке, а не только в продажах', () {
    // 200 подъёмных, продажа 50 наличными, наличный возврат 20, внесение
    // 100, изъятие 30. Приход = 50 + 100, расход = 20 + 30.
    final text = render(
      cashStart: d('200.00'),
      cashIncome: d('150.00'),
      cashExpense: d('50.00'),
      cashDiscrepancy: Decimal.zero,
      cashEnd: d('300.00'),
    );

    final lines = moneyLines(text);
    expect(lines[0] + lines[1] - lines[2], lines[3], reason: 'бланк: $text');
  });
}
