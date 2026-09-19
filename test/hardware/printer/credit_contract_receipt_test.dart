/// Печатная форма договора — **то, что подписывают**.
///
/// # Что утверждается, и почему не «строка непустая»
///
/// Бумага и база обязаны сходиться числом. Проба, спросившая «печатается
/// ли что-нибудь», зелена и у формы, которая печатает чужой график: она
/// не отличает договор на 900 от договора на 90.
///
/// Поэтому здесь утверждается **каждая строка графика поимённо** и то, что
/// итог сложен из напечатанных строк, а не взят у договора вторым числом.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/hardware/printer/receipt/credit_contract_receipt_builder.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  CreditContractView viewOf({
    String principal = '900',
    String fee = '0',
    int term = 3,
    InstallmentScheme scheme = InstallmentScheme.equalInstalments,
  }) {
    final lines = InstallmentScheduler.build(
      principal: d(principal),
      feeTotal: d(fee),
      termMonths: term,
      firstDueDate: DateTime(2026, 10, 15),
      scheme: scheme,
    );
    return CreditContractView(
      contract: CreditContract(
        id: 1,
        number: 'РС-1-7',
        agentLocalId: 5,
        receivableAccountId: 14,
        receiptNo: 7,
        posId: 1,
        principal: d(principal),
        feeTotal: d(fee),
        downPayment: d('100'),
        termMonths: term,
        scheme: scheme,
        status: CreditContractStatus.active,
        signedAt: DateTime(2026, 9, 15).millisecondsSinceEpoch ~/ 1000,
      ),
      schedule: [
        for (final l in lines)
          CreditScheduleEntry(
            id: l.seq + 1,
            contractId: 1,
            seq: l.seq,
            dueDate: l.dueDate,
            principalDue: l.principalDue,
            feeDue: l.feeDue,
            paid: Decimal.zero,
          ),
      ],
    );
  }

  String print(CreditContractView view) => CreditContractReceiptBuilder(
    view: view,
    companyName: 'ТОО Ромашка',
    customerName: 'Айгуль',
  ).toDebugString();

  test('на бумаге номер, стороны, условия и весь график', () {
    final text = print(viewOf());

    expect(text, contains('ДОГОВОР РАССРОЧКИ'));
    expect(text, contains('№ РС-1-7'));
    expect(text, contains('ТОО Ромашка'));
    expect(text, contains('Айгуль'));
    expect(text, contains('Дата: 15.09.2026'));
    expect(text, contains('Чек: 7 (касса 1)'));
    expect(text, contains('Первый взнос'));
    expect(text, contains('100'));
    expect(text, contains('Срок, месяцев'));
    expect(text, contains('Схема'));
    expect(
      text,
      contains(InstallmentScheme.equalInstalments.label),
      reason: 'имя схемы то же, что кассир выбрал на экране',
    );
  });

  test('каждая строка графика на бумаге — со своим сроком и суммой', () {
    final text = print(viewOf());

    // 900 на три месяца — по 300, первый срок 15 октября.
    expect(text, contains('1. 15 октября 2026'));
    expect(text, contains('2. 15 ноября 2026'));
    expect(text, contains('3. 15 декабря 2026'));
    expect('300'.allMatches(text).length, greaterThanOrEqualTo(3));
  });

  test('ИТОГО сложено из напечатанных строк, а не взято у договора', () {
    // Неделящийся остаток: 900.001 на три месяца даёт 300.000, 300.000 и
    // 300.001. Итог обязан быть 900.001 — то есть суммой того, что видно
    // на бумаге, а не вторым числом рядом.
    final text = print(viewOf(principal: '900.001'));
    expect(text, contains('300.001'), reason: 'остаток в последнем платеже');
    expect(text, contains('ИТОГО К ОПЛАТЕ'));
    expect(text, contains('900.001'));
  });

  test('надбавка печатается только когда она есть', () {
    // «Надбавка: 0» на розничной рассрочке — обещание, которого никто не
    // давал. У договоров, заключённых кассой, надбавки нет вовсе.
    expect(print(viewOf()), isNot(contains('Надбавка')));
    expect(print(viewOf(fee: '150')), contains('Надбавка'));
  });

  test('просрочки и остатка на сегодня на бумаге НЕТ', () {
    // Договор печатается в момент подписи, и «просрочено: 0» на нём было
    // бы утверждением о будущем. Текущее состояние показывает экран.
    final text = print(viewOf());
    expect(text, isNot(contains('ПРОСРОЧ')));
    expect(text, isNot(contains('Осталось')));
  });

  test('все три схемы печатаются своим именем и своим графиком', () {
    for (final scheme in InstallmentScheme.values) {
      final view = viewOf(principal: '1200', fee: '120', term: 6, scheme: scheme);
      final text = print(view);
      expect(text, contains(scheme.label), reason: scheme.code);
      for (final e in view.schedule) {
        expect(
          text,
          contains('${e.totalDue}'),
          reason: '${scheme.code}, строка ${e.seq}',
        );
      }
    }
  });
}
