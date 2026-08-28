import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';

void main() {
  group('SupplyEntity', () {
    final supply = SupplyEntity(
      id: 1,
      supplierId: 10,
      amount: Decimal.parse('50000.000'),
      paymentType: 0,
      accountId: 200,
    );

    test('creates with fields', () {
      expect(supply.id, 1);
      expect(supply.supplierId, 10);
      expect(supply.amount, Decimal.parse('50000.000'));
    });

    test('payment type checks', () {
      expect(supply.isFullSupply, true);
      expect(supply.isConsignment, false);

      final consignment = supply.copyWith(paymentType: 1);
      expect(consignment.isConsignment, true);
      expect(consignment.isFullSupply, false);
    });

    test('copyWith', () {
      final copy = supply.copyWith(amount: Decimal.parse('75000.000'));
      expect(copy.amount, Decimal.parse('75000.000'));
      expect(copy.supplierId, 10);
    });
  });

  group('SupplyProductEntity', () {
    final product = SupplyProductEntity(
      supplyId: 1,
      ucode: 12345,
      quantity: Decimal.parse('10.000'),
      price: Decimal.parse('500.000'),
      amount: Decimal.parse('5000.000'),
    );

    test('creates with required fields', () {
      expect(product.supplyId, 1);
      expect(product.ucode, 12345);
      expect(product.quantity, Decimal.parse('10.000'));
      expect(product.price, Decimal.parse('500.000'));
      expect(product.amount, Decimal.parse('5000.000'));
    });

    test('copyWith', () {
      final copy = product.copyWith(quantity: Decimal.parse('20.000'));
      expect(copy.quantity, Decimal.parse('20.000'));
      expect(copy.supplyId, 1);
      expect(copy.ucode, 12345);
    });
  });
}
