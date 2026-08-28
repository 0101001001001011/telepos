import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/refund/refund_entity.dart';
import 'package:telepos/domain/entities/refund/refund_product_entity.dart';

void main() {
  group('RefundEntity', () {
    final refund = RefundEntity(
      localId: 1,
      saleReceiptNo: 10,
      salePosId: 100,
      userId: 5,
      amount: Decimal.parse('750.000'),
      time: 1700000000,
      state: 0,
    );

    test('creates with required fields', () {
      expect(refund.localId, 1);
      expect(refund.userId, 5);
      expect(refund.amount, Decimal.parse('750.000'));
      expect(refund.time, 1700000000);
    });

    test('hasSaleReference', () {
      expect(refund.hasSaleReference, true);

      final noSale = RefundEntity(userId: 5, amount: Decimal.zero, time: 0);
      expect(noSale.hasSaleReference, false);
    });

    test('state machine', () {
      expect(refund.isInProgress, true);
      expect(refund.isSynced, false);

      final synced = refund.copyWith(state: 3);
      expect(synced.isSynced, true);
      expect(synced.isInProgress, false);
    });

    test('defaults', () {
      expect(refund.isOfd, false);
      expect(refund.cashbackAmount, isNull);
      expect(refund.serverId, isNull);
    });

    test('copyWith preserves values', () {
      final copy = refund.copyWith(amount: Decimal.parse('500.000'));
      expect(copy.amount, Decimal.parse('500.000'));
      expect(copy.localId, 1);
      expect(copy.saleReceiptNo, 10);
      expect(copy.salePosId, 100);
    });

    test('copyWith clearCashbackAmount', () {
      final withCashback = refund.copyWith(
        cashbackAmount: Decimal.parse('100.000'),
      );
      expect(withCashback.cashbackAmount, Decimal.parse('100.000'));

      final cleared = withCashback.copyWith(clearCashbackAmount: true);
      expect(cleared.cashbackAmount, isNull);
    });
  });

  group('RefundProductEntity', () {
    final product = RefundProductEntity(
      id: 1,
      refundLocalId: 1,
      ucode: 12345,
      price: Decimal.parse('500.000'),
      quantity: Decimal.parse('2.000'),
      inSalePrice: Decimal.parse('500.000'),
      inSaleQuantity: Decimal.parse('5.000'),
    );

    test('creates with required fields', () {
      expect(product.ucode, 12345);
      expect(product.price, Decimal.parse('500.000'));
      expect(product.quantity, Decimal.parse('2.000'));
    });

    test('total calculation', () {
      expect(product.total, Decimal.parse('1000.000'));
    });

    test('copyWith', () {
      final copy = product.copyWith(quantity: Decimal.parse('3.000'));
      expect(copy.quantity, Decimal.parse('3.000'));
      expect(copy.ucode, 12345);
    });
  });
}
