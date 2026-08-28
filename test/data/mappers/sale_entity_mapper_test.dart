import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/sale_mapper.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';

void main() {
  group('SaleMapper', () {
    test('fromDrift converts all fields', () {
      final driftSale = Sale(
        receiptNo: 1,
        posId: 100,
        saleId: 999,
        userId: 5,
        amount: Decimal.parse('1500.500'),
        change: Decimal.parse('500.000'),
        time: 1700000000,
        storeId: 10,
        customerLocalId: 42,
        customerServerId: 420,
        loyalCustomerPhone: 77771234567,
        isOfd: true,
        state: 1,
        isWholesale: true,
        weightProductRoundType: 1,
        discountsRoundType: 2,
        customerBin: '123456789012',
        orderType: 0,
        serviceCharge: Decimal.parse('150.000'),
      );

      final entity = SaleMapper.fromDrift(driftSale);

      expect(entity.receiptNo, 1);
      expect(entity.posId, 100);
      expect(entity.saleId, 999);
      expect(entity.userId, 5);
      expect(entity.amount, Decimal.parse('1500.500'));
      expect(entity.change, Decimal.parse('500.000'));
      expect(entity.time, 1700000000);
      expect(entity.storeId, 10);
      expect(entity.customerLocalId, 42);
      expect(entity.customerServerId, 420);
      expect(entity.loyalCustomerPhone, 77771234567);
      expect(entity.isOfd, true);
      expect(entity.state, 1);
      expect(entity.isWholesale, true);
      expect(entity.weightProductRoundType, 1);
      expect(entity.discountsRoundType, 2);
      expect(entity.customerBin, '123456789012');
      expect(entity.orderType, 0);
      expect(entity.serviceCharge, Decimal.parse('150.000'));
    });

    test('toDrift creates companion with all fields', () {
      final entity = SaleEntity(
        receiptNo: 1,
        posId: 100,
        userId: 5,
        amount: Decimal.parse('1500.500'),
        time: 1700000000,
        state: 0,
      );

      final companion = SaleMapper.toDrift(entity);

      expect(companion.receiptNo.value, 1);
      expect(companion.posId.value, 100);
      expect(companion.userId.value, 5);
      expect(companion.amount.value, Decimal.parse('1500.500'));
      expect(companion.time.value, 1700000000);
      expect(companion.state.value, 0);
    });

    test('fromDriftList maps multiple', () {
      final sales = [
        Sale(
          receiptNo: 1,
          posId: 100,
          userId: 5,
          amount: Decimal.parse('100.000'),
          time: 1700000000,
          isOfd: false,
          isWholesale: false,
        ),
        Sale(
          receiptNo: 2,
          posId: 100,
          userId: 5,
          amount: Decimal.parse('200.000'),
          time: 1700000001,
          isOfd: false,
          isWholesale: false,
        ),
      ];

      final entities = SaleMapper.fromDriftList(sales);
      expect(entities.length, 2);
      expect(entities[0].receiptNo, 1);
      expect(entities[1].receiptNo, 2);
    });

    test('round-trip preserves data', () {
      final original = SaleEntity(
        receiptNo: 1,
        posId: 100,
        saleId: 999,
        userId: 5,
        amount: Decimal.parse('1500.500'),
        change: Decimal.parse('500.000'),
        time: 1700000000,
        storeId: 10,
        customerLocalId: 42,
        customerServerId: 420,
        loyalCustomerPhone: 77771234567,
        isOfd: true,
        state: 1,
        isWholesale: true,
        weightProductRoundType: 1,
        discountsRoundType: 2,
        customerBin: '123456789012',
        orderType: 0,
        serviceCharge: Decimal.parse('150.000'),
      );

      final companion = SaleMapper.toDrift(original);

      final driftSale = Sale(
        receiptNo: companion.receiptNo.value,
        posId: companion.posId.value,
        saleId: companion.saleId.value,
        userId: companion.userId.value,
        amount: companion.amount.value,
        change: companion.change.value,
        time: companion.time.value,
        storeId: companion.storeId.value,
        customerLocalId: companion.customerLocalId.value,
        customerServerId: companion.customerServerId.value,
        loyalCustomerPhone: companion.loyalCustomerPhone.value,
        isOfd: companion.isOfd.value,
        state: companion.state.value,
        isWholesale: companion.isWholesale.value,
        weightProductRoundType: companion.weightProductRoundType.value,
        discountsRoundType: companion.discountsRoundType.value,
        customerBin: companion.customerBin.value,
        orderType: companion.orderType.value,
        serviceCharge: companion.serviceCharge.value,
      );

      final restored = SaleMapper.fromDrift(driftSale);

      expect(restored.receiptNo, original.receiptNo);
      expect(restored.posId, original.posId);
      expect(restored.saleId, original.saleId);
      expect(restored.userId, original.userId);
      expect(restored.amount, original.amount);
      expect(restored.change, original.change);
      expect(restored.time, original.time);
      expect(restored.storeId, original.storeId);
      expect(restored.customerLocalId, original.customerLocalId);
      expect(restored.customerServerId, original.customerServerId);
      expect(restored.loyalCustomerPhone, original.loyalCustomerPhone);
      expect(restored.isOfd, original.isOfd);
      expect(restored.state, original.state);
      expect(restored.isWholesale, original.isWholesale);
      expect(restored.weightProductRoundType, original.weightProductRoundType);
      expect(restored.discountsRoundType, original.discountsRoundType);
      expect(restored.customerBin, original.customerBin);
      expect(restored.orderType, original.orderType);
      expect(restored.serviceCharge, original.serviceCharge);
    });
  });
}
