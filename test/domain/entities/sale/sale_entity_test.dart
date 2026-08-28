import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';

void main() {
  group('SaleEntity', () {
    final sale = SaleEntity(
      receiptNo: 1,
      posId: 100,
      userId: 5,
      amount: Decimal.parse('1500.000'),
      change: Decimal.parse('500.000'),
      time: 1700000000,
      state: 0,
    );

    test('creates with required fields', () {
      expect(sale.receiptNo, 1);
      expect(sale.posId, 100);
      expect(sale.userId, 5);
      expect(sale.amount, Decimal.parse('1500.000'));
      expect(sale.time, 1700000000);
    });

    test('defaults', () {
      expect(sale.isOfd, false);
      expect(sale.isWholesale, false);
      expect(sale.saleId, isNull);
      expect(sale.storeId, isNull);
      expect(sale.customerLocalId, isNull);
    });

    test('computed properties', () {
      expect(sale.isInProgress, true);
      expect(sale.isDeferred, false);
      expect(sale.isSynced, false);
      expect(sale.hasCustomer, false);
    });

    test('copyWith preserves values', () {
      final copy = sale.copyWith(amount: Decimal.parse('2000.000'));
      expect(copy.amount, Decimal.parse('2000.000'));
      expect(copy.receiptNo, 1);
      expect(copy.posId, 100);
      expect(copy.userId, 5);
      expect(copy.time, 1700000000);
    });

    test('copyWith clearChange', () {
      expect(sale.change, isNotNull);
      final copy = sale.copyWith(clearChange: true);
      expect(copy.change, isNull);
    });

    test('copyWith clearCustomerLocalId', () {
      final withCustomer = sale.copyWith(customerLocalId: 42);
      expect(withCustomer.customerLocalId, 42);
      expect(withCustomer.hasCustomer, true);

      final cleared = withCustomer.copyWith(clearCustomerLocalId: true);
      expect(cleared.customerLocalId, isNull);
      expect(cleared.hasCustomer, false);
    });

    test('state machine', () {
      final deferred = sale.copyWith(state: 3);
      expect(deferred.isDeferred, true);
      expect(deferred.isInProgress, false);

      final synced = sale.copyWith(state: 4);
      expect(synced.isSynced, true);
    });

    test('Decimal precision P18,S3', () {
      final precise = SaleEntity(
        receiptNo: 1,
        posId: 1,
        userId: 1,
        amount: Decimal.parse('999999999999999.999'),
        time: 0,
      );
      expect(precise.amount.toString(), '999999999999999.999');
    });
  });

  group('SaleProductEntity', () {
    final product = SaleProductEntity(
      ucode: 12345,
      quantity: Decimal.parse('3.000'),
      price: Decimal.parse('500.000'),
      priceBefore: Decimal.parse('600.000'),
    );

    test('creates with required fields', () {
      expect(product.ucode, 12345);
      expect(product.quantity, Decimal.parse('3.000'));
      expect(product.price, Decimal.parse('500.000'));
      expect(product.priceBefore, Decimal.parse('600.000'));
    });

    test('total calculation', () {
      expect(product.total, Decimal.parse('1500.000'));
    });

    test('discount calculation', () {
      expect(product.hasDiscount, true);
      expect(product.discountAmount, Decimal.parse('300.000'));
    });

    test('no discount when price equals priceBefore', () {
      final noDiscount = product.copyWith(
        priceBefore: Decimal.parse('500.000'),
      );
      expect(noDiscount.hasDiscount, false);
      expect(noDiscount.discountAmount, Decimal.zero);
    });

    test('copyWith', () {
      final copy = product.copyWith(quantity: Decimal.parse('5.000'));
      expect(copy.quantity, Decimal.parse('5.000'));
      expect(copy.ucode, 12345);
      expect(copy.price, Decimal.parse('500.000'));
    });
  });
}
