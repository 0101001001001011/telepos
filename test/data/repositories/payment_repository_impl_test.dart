import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/mappers/payment_mapper.dart';
import 'package:telepos/domain/entities/payment/payment_entity.dart';

void main() {
  group('PaymentRepositoryImpl.insertPayments batch mapping', () {
    test('empty list produces no companions', () {
      final payments = <PaymentEntity>[];
      final companions = payments.map(PaymentMapper.toDrift).toList();

      expect(companions, isEmpty);
    });

    test('single payment maps correctly for batch insert', () {
      final payment = PaymentEntity(
        userId: 1,
        receiptNo: 100,
        posId: 5,
        payeeAccountId: 10,
        amount: Decimal.parse('5000.000'),
        time: 1700000000,
        state: 1,
      );

      final companion = PaymentMapper.toDrift(payment);

      expect(companion.userId.value, 1);
      expect(companion.receiptNo.value, 100);
      expect(companion.posId.value, 5);
      expect(companion.payeeAccountId.value, 10);
      expect(companion.amount.value, Decimal.parse('5000.000'));
      expect(companion.time.value, 1700000000);
      expect(companion.state.value, 1);
    });

    test('multiple payments all map correctly for batch', () {
      final payments = [
        PaymentEntity(
          userId: 1,
          payeeAccountId: 10,
          amount: Decimal.parse('1000.000'),
          time: 1700000001,
          state: 1,
        ),
        PaymentEntity(
          userId: 1,
          payeeAccountId: 20,
          amount: Decimal.parse('2500.500'),
          time: 1700000002,
          state: 1,
        ),
        PaymentEntity(
          userId: 2,
          payeeAccountId: 10,
          amount: Decimal.parse('750.250'),
          time: 1700000003,
          state: 1,
        ),
      ];

      final companions = payments.map(PaymentMapper.toDrift).toList();

      expect(companions.length, 3);
      expect(companions[0].amount.value, Decimal.parse('1000.000'));
      expect(companions[1].amount.value, Decimal.parse('2500.500'));
      expect(companions[2].amount.value, Decimal.parse('750.250'));
      expect(companions[0].payeeAccountId.value, 10);
      expect(companions[1].payeeAccountId.value, 20);
      expect(companions[2].payeeAccountId.value, 10);
    });

    test('refund payment maps refundLocalId correctly', () {
      final payment = PaymentEntity(
        userId: 1,
        payeeAccountId: 10,
        amount: Decimal.parse('500.000'),
        time: 1700000000,
        state: 1,
        refundLocalId: 42,
      );

      final companion = PaymentMapper.toDrift(payment);

      expect(companion.refundLocalId.value, 42);
    });

    test('batch with mixed sale and refund payments', () {
      final payments = [
        PaymentEntity(
          userId: 1,
          receiptNo: 100,
          posId: 5,
          payeeAccountId: 10,
          amount: Decimal.parse('3000.000'),
          time: 1700000001,
          state: 1,
        ),
        PaymentEntity(
          userId: 1,
          refundLocalId: 7,
          payeeAccountId: 10,
          amount: Decimal.parse('1500.000'),
          time: 1700000002,
          state: 1,
        ),
      ];

      final companions = payments.map(PaymentMapper.toDrift).toList();

      expect(companions.length, 2);
      expect(companions[0].receiptNo.value, 100);
      expect(companions[0].posId.value, 5);
      expect(companions[1].refundLocalId.value, 7);
    });
  });
}
