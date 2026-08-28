import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/supply_mapper.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';

void main() {
  group('SupplyMapper', () {
    test('fromDrift converts all fields', () {
      final driftSupply = Supply(
        id: 1,
        operationType: 0,
        userId: 5,
        supplierId: 42,
        editTime: 1700000000,
        amount: Decimal.parse('50000.500'),
        paymentType: 0,
        accountId: 10,
        comment: 'Поставка молочных продуктов',
        payment: Decimal.parse('50000.500'),
        consignmentAmount: Decimal.zero,
        paidAmount: Decimal.parse('50000.500'),
        state: 1,
        status: 0,
        msg: 'OK',
      );

      final entity = SupplyMapper.fromDrift(driftSupply);

      expect(entity.id, 1);
      expect(entity.operationType, 0);
      expect(entity.userId, 5);
      expect(entity.supplierId, 42);
      expect(entity.editTime, 1700000000);
      expect(entity.amount, Decimal.parse('50000.500'));
      expect(entity.paymentType, 0);
      expect(entity.accountId, 10);
      expect(entity.comment, 'Поставка молочных продуктов');
      expect(entity.payment, Decimal.parse('50000.500'));
      expect(entity.consignmentAmount, Decimal.zero);
      expect(entity.paidAmount, Decimal.parse('50000.500'));
      expect(entity.state, 1);
      expect(entity.status, 0);
      expect(entity.msg, 'OK');
    });

    test('fromDrift with nullable fields null', () {
      final driftSupply = Supply(id: 1);

      final entity = SupplyMapper.fromDrift(driftSupply);

      expect(entity.id, 1);
      expect(entity.operationType, isNull);
      expect(entity.userId, isNull);
      expect(entity.supplierId, isNull);
      expect(entity.amount, isNull);
      expect(entity.comment, isNull);
      expect(entity.msg, isNull);
    });

    test('toDrift creates companion', () {
      final entity = SupplyEntity(
        id: 1,
        operationType: 0,
        supplierId: 42,
        amount: Decimal.parse('50000.500'),
        paymentType: 0,
        accountId: 10,
      );

      final companion = SupplyMapper.toDrift(entity);

      expect(companion.id.value, 1);
      expect(companion.operationType.value, 0);
      expect(companion.supplierId.value, 42);
      expect(companion.amount.value, Decimal.parse('50000.500'));
      expect(companion.paymentType.value, 0);
      expect(companion.accountId.value, 10);
    });

    test('round-trip preserves data', () {
      final original = SupplyEntity(
        id: 3,
        operationType: 0,
        userId: 10,
        supplierId: 42,
        editTime: 1700000000,
        amount: Decimal.parse('75000.250'),
        paymentType: 1,
        accountId: 10,
        comment: 'Консигнация',
        payment: Decimal.parse('25000.000'),
        consignmentAmount: Decimal.parse('50000.250'),
        paidAmount: Decimal.parse('25000.000'),
        state: 0,
        status: 1,
        msg: 'Partial',
      );

      final companion = SupplyMapper.toDrift(original);

      final driftSupply = Supply(
        id: companion.id.value,
        operationType: companion.operationType.value,
        userId: companion.userId.value,
        supplierId: companion.supplierId.value,
        editTime: companion.editTime.value,
        amount: companion.amount.value,
        paymentType: companion.paymentType.value,
        accountId: companion.accountId.value,
        comment: companion.comment.value,
        payment: companion.payment.value,
        consignmentAmount: companion.consignmentAmount.value,
        paidAmount: companion.paidAmount.value,
        state: companion.state.value,
        status: companion.status.value,
        msg: companion.msg.value,
      );

      final restored = SupplyMapper.fromDrift(driftSupply);

      expect(restored.id, original.id);
      expect(restored.operationType, original.operationType);
      expect(restored.userId, original.userId);
      expect(restored.supplierId, original.supplierId);
      expect(restored.editTime, original.editTime);
      expect(restored.amount, original.amount);
      expect(restored.paymentType, original.paymentType);
      expect(restored.accountId, original.accountId);
      expect(restored.comment, original.comment);
      expect(restored.payment, original.payment);
      expect(restored.consignmentAmount, original.consignmentAmount);
      expect(restored.paidAmount, original.paidAmount);
      expect(restored.state, original.state);
      expect(restored.status, original.status);
      expect(restored.msg, original.msg);
    });

    test('fromDriftList maps multiple', () {
      final supplies = [
        Supply(id: 1, amount: Decimal.parse('10000.000')),
        Supply(id: 2, amount: Decimal.parse('20000.000')),
      ];

      final entities = SupplyMapper.fromDriftList(supplies);
      expect(entities.length, 2);
      expect(entities[0].id, 1);
      expect(entities[1].amount, Decimal.parse('20000.000'));
    });
  });

  group('SupplyProductMapper', () {
    test('fromDrift converts all fields', () {
      final driftProduct = SupplyProduct(
        id: 1,
        supplyId: 10,
        ucode: 5001,
        quantity: Decimal.parse('100.000'),
        price: Decimal.parse('250.500'),
        amount: Decimal.parse('25050.000'),
      );

      final entity = SupplyProductMapper.fromDrift(driftProduct);

      expect(entity.id, 1);
      expect(entity.supplyId, 10);
      expect(entity.ucode, 5001);
      expect(entity.quantity, Decimal.parse('100.000'));
      expect(entity.price, Decimal.parse('250.500'));
      expect(entity.amount, Decimal.parse('25050.000'));
    });

    test('toDrift creates companion', () {
      final entity = SupplyProductEntity(
        supplyId: 10,
        ucode: 5001,
        quantity: Decimal.parse('100.000'),
        price: Decimal.parse('250.500'),
        amount: Decimal.parse('25050.000'),
      );

      final companion = SupplyProductMapper.toDrift(entity);

      expect(companion.supplyId.value, 10);
      expect(companion.ucode.value, 5001);
      expect(companion.quantity.value, Decimal.parse('100.000'));
      expect(companion.price.value, Decimal.parse('250.500'));
      expect(companion.amount.value, Decimal.parse('25050.000'));
    });

    test('round-trip preserves data', () {
      final original = SupplyProductEntity(
        id: 5,
        supplyId: 10,
        ucode: 5001,
        quantity: Decimal.parse('100.000'),
        price: Decimal.parse('250.500'),
        amount: Decimal.parse('25050.000'),
      );

      final companion = SupplyProductMapper.toDrift(original);

      final driftProduct = SupplyProduct(
        id: companion.id.value,
        supplyId: companion.supplyId.value,
        ucode: companion.ucode.value,
        quantity: companion.quantity.value,
        price: companion.price.value,
        amount: companion.amount.value,
      );

      final restored = SupplyProductMapper.fromDrift(driftProduct);

      expect(restored.id, original.id);
      expect(restored.supplyId, original.supplyId);
      expect(restored.ucode, original.ucode);
      expect(restored.quantity, original.quantity);
      expect(restored.price, original.price);
      expect(restored.amount, original.amount);
    });

    test('fromDriftList maps multiple', () {
      final products = [
        SupplyProduct(
          id: 1,
          supplyId: 10,
          ucode: 5001,
          quantity: Decimal.one,
          price: Decimal.parse('100.000'),
          amount: Decimal.parse('100.000'),
        ),
        SupplyProduct(
          id: 2,
          supplyId: 10,
          ucode: 5002,
          quantity: Decimal.parse('5.000'),
          price: Decimal.parse('200.000'),
          amount: Decimal.parse('1000.000'),
        ),
      ];

      final entities = SupplyProductMapper.fromDriftList(products);
      expect(entities.length, 2);
      expect(entities[0].ucode, 5001);
      expect(entities[1].amount, Decimal.parse('1000.000'));
    });
  });
}
