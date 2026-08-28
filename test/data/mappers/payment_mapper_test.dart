import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/payment_mapper.dart';
import 'package:telepos/domain/entities/payment/payment_entity.dart';

void main() {
  group('PaymentMapper', () {
    test('fromDrift converts all fields', () {
      final driftPayment = Payment(
        id: 1,
        userId: 5,
        receiptNo: 10,
        posId: 100,
        refundLocalId: null,
        customerLocalId: 42,
        payeeAccountId: 200,
        amount: Decimal.parse('1500.500'),
        time: 1700000000,
        state: 1,
      );

      final entity = PaymentMapper.fromDrift(driftPayment);

      expect(entity.id, 1);
      expect(entity.userId, 5);
      expect(entity.receiptNo, 10);
      expect(entity.posId, 100);
      expect(entity.refundLocalId, isNull);
      expect(entity.customerLocalId, 42);
      expect(entity.payeeAccountId, 200);
      expect(entity.amount, Decimal.parse('1500.500'));
      expect(entity.time, 1700000000);
      expect(entity.state, 1);
    });

    test('toDrift creates companion', () {
      final entity = PaymentEntity(
        userId: 5,
        receiptNo: 10,
        posId: 100,
        payeeAccountId: 200,
        amount: Decimal.parse('1500.500'),
        time: 1700000000,
        state: 1,
      );

      final companion = PaymentMapper.toDrift(entity);

      expect(companion.userId.value, 5);
      expect(companion.receiptNo.value, 10);
      expect(companion.posId.value, 100);
      expect(companion.payeeAccountId.value, 200);
      expect(companion.amount.value, Decimal.parse('1500.500'));
      expect(companion.time.value, 1700000000);
      expect(companion.state.value, 1);
    });

    test('fromDriftList maps multiple', () {
      final payments = [
        Payment(
          id: 1,
          userId: 5,
          payeeAccountId: 200,
          amount: Decimal.parse('100.000'),
          time: 1700000000,
        ),
        Payment(
          id: 2,
          userId: 5,
          payeeAccountId: 201,
          amount: Decimal.parse('200.000'),
          time: 1700000001,
        ),
      ];

      final entities = PaymentMapper.fromDriftList(payments);
      expect(entities.length, 2);
      expect(entities[0].amount, Decimal.parse('100.000'));
      expect(entities[1].amount, Decimal.parse('200.000'));
    });

    test('round-trip preserves data', () {
      final original = PaymentEntity(
        id: 3,
        userId: 5,
        receiptNo: 10,
        posId: 100,
        refundLocalId: 7,
        customerLocalId: 42,
        payeeAccountId: 200,
        amount: Decimal.parse('2500.750'),
        time: 1700036000,
        state: 2,
      );

      final companion = PaymentMapper.toDrift(original);

      final driftPayment = Payment(
        id: companion.id.value,
        userId: companion.userId.value,
        receiptNo: companion.receiptNo.value,
        posId: companion.posId.value,
        refundLocalId: companion.refundLocalId.value,
        customerLocalId: companion.customerLocalId.value,
        payeeAccountId: companion.payeeAccountId.value,
        amount: companion.amount.value,
        time: companion.time.value,
        state: companion.state.value,
      );

      final restored = PaymentMapper.fromDrift(driftPayment);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.receiptNo, original.receiptNo);
      expect(restored.posId, original.posId);
      expect(restored.refundLocalId, original.refundLocalId);
      expect(restored.customerLocalId, original.customerLocalId);
      expect(restored.payeeAccountId, original.payeeAccountId);
      expect(restored.amount, original.amount);
      expect(restored.time, original.time);
      expect(restored.state, original.state);
    });
  });
}
