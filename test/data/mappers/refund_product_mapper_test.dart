import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/refund_product_mapper.dart';
import 'package:telepos/domain/entities/refund/refund_product_entity.dart';

void main() {
  group('RefundProductMapper', () {
    test('fromDrift converts all fields', () {
      final driftProduct = RefundProduct(
        id: 1,
        refundLocalId: 10,
        refundServerId: 100,
        ucode: 5001,
        price: Decimal.parse('450.500'),
        quantity: Decimal.parse('2.000'),
        weightProductRoundType: 1,
        discountsRoundType: 2,
        inSaleQuantity: Decimal.parse('3.000'),
        inSalePrice: Decimal.parse('500.000'),
        inSalePriceBefore: Decimal.parse('550.000'),
      );

      final entity = RefundProductMapper.fromDrift(driftProduct);

      expect(entity.id, 1);
      expect(entity.refundLocalId, 10);
      expect(entity.refundServerId, 100);
      expect(entity.ucode, 5001);
      expect(entity.price, Decimal.parse('450.500'));
      expect(entity.quantity, Decimal.parse('2.000'));
      expect(entity.weightProductRoundType, 1);
      expect(entity.discountsRoundType, 2);
      expect(entity.inSaleQuantity, Decimal.parse('3.000'));
      expect(entity.inSalePrice, Decimal.parse('500.000'));
      expect(entity.inSalePriceBefore, Decimal.parse('550.000'));
    });

    test('fromDrift with nullable fields null', () {
      final driftProduct = RefundProduct(
        id: 1,
        ucode: 5001,
        price: Decimal.parse('100.000'),
        quantity: Decimal.one,
      );

      final entity = RefundProductMapper.fromDrift(driftProduct);

      expect(entity.refundLocalId, isNull);
      expect(entity.refundServerId, isNull);
      expect(entity.weightProductRoundType, isNull);
      expect(entity.discountsRoundType, isNull);
      expect(entity.inSaleQuantity, isNull);
      expect(entity.inSalePrice, isNull);
      expect(entity.inSalePriceBefore, isNull);
    });

    test('toDrift creates companion', () {
      final entity = RefundProductEntity(
        refundLocalId: 10,
        ucode: 5001,
        price: Decimal.parse('450.500'),
        quantity: Decimal.parse('2.000'),
        inSalePrice: Decimal.parse('500.000'),
      );

      final companion = RefundProductMapper.toDrift(entity);

      expect(companion.refundLocalId.value, 10);
      expect(companion.ucode.value, 5001);
      expect(companion.price.value, Decimal.parse('450.500'));
      expect(companion.quantity.value, Decimal.parse('2.000'));
      expect(companion.inSalePrice.value, Decimal.parse('500.000'));
    });

    test('round-trip preserves data', () {
      final original = RefundProductEntity(
        id: 5,
        refundLocalId: 10,
        refundServerId: 100,
        ucode: 5001,
        price: Decimal.parse('450.500'),
        quantity: Decimal.parse('2.000'),
        weightProductRoundType: 1,
        discountsRoundType: 2,
        inSaleQuantity: Decimal.parse('3.000'),
        inSalePrice: Decimal.parse('500.000'),
        inSalePriceBefore: Decimal.parse('550.000'),
      );

      final companion = RefundProductMapper.toDrift(original);

      final driftProduct = RefundProduct(
        id: companion.id.value,
        refundLocalId: companion.refundLocalId.value,
        refundServerId: companion.refundServerId.value,
        ucode: companion.ucode.value,
        price: companion.price.value,
        quantity: companion.quantity.value,
        weightProductRoundType: companion.weightProductRoundType.value,
        discountsRoundType: companion.discountsRoundType.value,
        inSaleQuantity: companion.inSaleQuantity.value,
        inSalePrice: companion.inSalePrice.value,
        inSalePriceBefore: companion.inSalePriceBefore.value,
      );

      final restored = RefundProductMapper.fromDrift(driftProduct);

      expect(restored.id, original.id);
      expect(restored.refundLocalId, original.refundLocalId);
      expect(restored.refundServerId, original.refundServerId);
      expect(restored.ucode, original.ucode);
      expect(restored.price, original.price);
      expect(restored.quantity, original.quantity);
      expect(restored.weightProductRoundType, original.weightProductRoundType);
      expect(restored.discountsRoundType, original.discountsRoundType);
      expect(restored.inSaleQuantity, original.inSaleQuantity);
      expect(restored.inSalePrice, original.inSalePrice);
      expect(restored.inSalePriceBefore, original.inSalePriceBefore);
    });

    test('fromDriftList maps multiple', () {
      final products = [
        RefundProduct(
          id: 1,
          ucode: 5001,
          price: Decimal.parse('100.000'),
          quantity: Decimal.one,
        ),
        RefundProduct(
          id: 2,
          ucode: 5002,
          price: Decimal.parse('200.000'),
          quantity: Decimal.parse('3.000'),
        ),
      ];

      final entities = RefundProductMapper.fromDriftList(products);
      expect(entities.length, 2);
      expect(entities[0].ucode, 5001);
      expect(entities[1].ucode, 5002);
      expect(entities[1].quantity, Decimal.parse('3.000'));
    });
  });
}
