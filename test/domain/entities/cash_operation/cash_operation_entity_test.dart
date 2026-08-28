import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_entity.dart';

void main() {
  group('CashOperationEntity', () {
    final investment = CashOperationEntity(
      id: 1,
      amount: Decimal.parse('10000.000'),
      type: 0,
      userId: 5,
      note: 'Внесение в начале смены',
      docTime: 1700000000,
    );

    test('creates with required fields', () {
      expect(investment.id, 1);
      expect(investment.amount, Decimal.parse('10000.000'));
      expect(investment.type, 0);
      expect(investment.userId, 5);
    });

    test('type checks', () {
      expect(investment.isInvestment, true);
      expect(investment.isExpense, false);
      expect(investment.isDividend, false);

      final expense = investment.copyWith(type: 1);
      expect(expense.isExpense, true);

      final dividend = investment.copyWith(type: 2);
      expect(dividend.isDividend, true);
    });

    test('copyWith preserves values', () {
      final copy = investment.copyWith(amount: Decimal.parse('20000.000'));
      expect(copy.amount, Decimal.parse('20000.000'));
      expect(copy.type, 0);
      expect(copy.userId, 5);
      expect(copy.note, 'Внесение в начале смены');
    });
  });
}
