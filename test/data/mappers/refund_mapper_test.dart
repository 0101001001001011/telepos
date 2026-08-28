import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/refund_mapper.dart';
import 'package:telepos/domain/entities/refund/refund_entity.dart';

void main() {
  group('RefundMapper', () {
    test('fromDrift converts all fields', () {
      final driftRefund = Refund(
        localId: 1,
        serverId: 100,
        saleId: 200,
        saleReceiptNo: 50,
        salePosId: 1,
        userId: 5,
        amount: Decimal.parse('1500.500'),
        cashbackAmount: Decimal.parse('50.000'),
        time: 1700000000,
        state: 1,
        customerLocalId: 42,
        customerServerId: 420,
        weightProductRoundType: 1,
        discountsRoundType: 2,
        isOfd: true,
      );

      final entity = RefundMapper.fromDrift(driftRefund);

      expect(entity.localId, 1);
      expect(entity.serverId, 100);
      expect(entity.saleId, 200);
      expect(entity.saleReceiptNo, 50);
      expect(entity.salePosId, 1);
      expect(entity.userId, 5);
      expect(entity.amount, Decimal.parse('1500.500'));
      expect(entity.cashbackAmount, Decimal.parse('50.000'));
      expect(entity.time, 1700000000);
      expect(entity.state, 1);
      expect(entity.customerLocalId, 42);
      expect(entity.customerServerId, 420);
      expect(entity.weightProductRoundType, 1);
      expect(entity.discountsRoundType, 2);
      expect(entity.isOfd, true);
    });

    test('fromDrift with nullable fields null', () {
      final driftRefund = Refund(
        localId: 1,
        userId: 5,
        amount: Decimal.parse('100.000'),
        time: 1700000000,
        isOfd: false,
      );

      final entity = RefundMapper.fromDrift(driftRefund);

      expect(entity.serverId, isNull);
      expect(entity.saleId, isNull);
      expect(entity.saleReceiptNo, isNull);
      expect(entity.salePosId, isNull);
      expect(entity.cashbackAmount, isNull);
      expect(entity.state, isNull);
      expect(entity.customerLocalId, isNull);
      expect(entity.customerServerId, isNull);
      expect(entity.weightProductRoundType, isNull);
      expect(entity.discountsRoundType, isNull);
      expect(entity.isOfd, false);
    });

    test('toDrift creates companion with all fields', () {
      final entity = RefundEntity(
        localId: 1,
        serverId: 100,
        saleReceiptNo: 50,
        salePosId: 1,
        userId: 5,
        amount: Decimal.parse('1500.500'),
        cashbackAmount: Decimal.parse('50.000'),
        time: 1700000000,
        state: 1,
        isOfd: true,
      );

      final companion = RefundMapper.toDrift(entity);

      expect(companion.localId.value, 1);
      expect(companion.serverId.value, 100);
      expect(companion.saleReceiptNo.value, 50);
      expect(companion.salePosId.value, 1);
      expect(companion.userId.value, 5);
      expect(companion.amount.value, Decimal.parse('1500.500'));
      expect(companion.cashbackAmount.value, Decimal.parse('50.000'));
      expect(companion.time.value, 1700000000);
      expect(companion.state.value, 1);
      expect(companion.isOfd.value, true);
    });

    test('round-trip preserves data', () {
      final original = RefundEntity(
        localId: 3,
        serverId: 300,
        saleId: 200,
        saleReceiptNo: 50,
        salePosId: 1,
        userId: 10,
        amount: Decimal.parse('2500.750'),
        cashbackAmount: Decimal.parse('100.000'),
        time: 1700036000,
        state: 2,
        customerLocalId: 42,
        customerServerId: 420,
        weightProductRoundType: 1,
        discountsRoundType: 2,
        isOfd: true,
      );

      final companion = RefundMapper.toDrift(original);

      final driftRefund = Refund(
        localId: companion.localId.value,
        serverId: companion.serverId.value,
        saleId: companion.saleId.value,
        saleReceiptNo: companion.saleReceiptNo.value,
        salePosId: companion.salePosId.value,
        userId: companion.userId.value,
        amount: companion.amount.value,
        cashbackAmount: companion.cashbackAmount.value,
        time: companion.time.value,
        state: companion.state.value,
        customerLocalId: companion.customerLocalId.value,
        customerServerId: companion.customerServerId.value,
        weightProductRoundType: companion.weightProductRoundType.value,
        discountsRoundType: companion.discountsRoundType.value,
        isOfd: companion.isOfd.value,
      );

      final restored = RefundMapper.fromDrift(driftRefund);

      expect(restored.localId, original.localId);
      expect(restored.serverId, original.serverId);
      expect(restored.saleId, original.saleId);
      expect(restored.saleReceiptNo, original.saleReceiptNo);
      expect(restored.salePosId, original.salePosId);
      expect(restored.userId, original.userId);
      expect(restored.amount, original.amount);
      expect(restored.cashbackAmount, original.cashbackAmount);
      expect(restored.time, original.time);
      expect(restored.state, original.state);
      expect(restored.customerLocalId, original.customerLocalId);
      expect(restored.customerServerId, original.customerServerId);
      expect(restored.weightProductRoundType, original.weightProductRoundType);
      expect(restored.discountsRoundType, original.discountsRoundType);
      expect(restored.isOfd, original.isOfd);
    });

    test('fromDriftList maps multiple', () {
      final refunds = [
        Refund(
          localId: 1,
          userId: 5,
          amount: Decimal.parse('100.000'),
          time: 1700000000,
          isOfd: false,
        ),
        Refund(
          localId: 2,
          userId: 5,
          amount: Decimal.parse('200.000'),
          time: 1700000001,
          isOfd: true,
        ),
      ];

      final entities = RefundMapper.fromDriftList(refunds);
      expect(entities.length, 2);
      expect(entities[0].localId, 1);
      expect(entities[0].amount, Decimal.parse('100.000'));
      expect(entities[1].localId, 2);
      expect(entities[1].isOfd, true);
    });
  });
}
