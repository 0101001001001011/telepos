import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/payment/payment_entity.dart';

void main() {
  group('PaymentEntity', () {
    final payment = PaymentEntity(
      id: 1,
      userId: 5,
      receiptNo: 10,
      posId: 100,
      payeeAccountId: 200,
      amount: Decimal.parse('1500.000'),
      time: 1700000000,
      state: 1,
    );

    test('creates with required fields', () {
      expect(payment.id, 1);
      expect(payment.userId, 5);
      expect(payment.payeeAccountId, 200);
      expect(payment.amount, Decimal.parse('1500.000'));
      expect(payment.time, 1700000000);
    });

    test('isForSale', () {
      expect(payment.isForSale, true);
      expect(payment.isForRefund, false);
    });

    test('isForRefund', () {
      final refundPayment = PaymentEntity(
        userId: 5,
        refundLocalId: 42,
        payeeAccountId: 200,
        amount: Decimal.parse('500.000'),
        time: 1700000000,
      );
      expect(refundPayment.isForRefund, true);
      expect(refundPayment.isForSale, false);
    });

    test('copyWith preserves values', () {
      final copy = payment.copyWith(amount: Decimal.parse('2000.000'));
      expect(copy.amount, Decimal.parse('2000.000'));
      expect(copy.userId, 5);
      expect(copy.receiptNo, 10);
      expect(copy.posId, 100);
    });

    test('copyWith clearRefundLocalId', () {
      final withRefund = payment.copyWith(refundLocalId: 42);
      expect(withRefund.refundLocalId, 42);

      final cleared = withRefund.copyWith(clearRefundLocalId: true);
      expect(cleared.refundLocalId, isNull);
    });

    test('Decimal precision P18,S3', () {
      final precise = PaymentEntity(
        userId: 1,
        payeeAccountId: 1,
        amount: Decimal.parse('123456789.123'),
        time: 0,
      );
      expect(precise.amount.toString(), '123456789.123');
    });
  });
}
