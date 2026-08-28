import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/restaurant/guest_split_entry.dart';

void main() {
  group('GuestSplitEntry', () {
    test('creation with all required fields', () {
      final entry = GuestSplitEntry(
        orderId: 10,
        guestNumber: 2,
        saleProductId: 55,
        shareQuantity: Decimal.parse('0.500'),
      );

      expect(entry.orderId, 10);
      expect(entry.guestNumber, 2);
      expect(entry.saleProductId, 55);
      expect(entry.shareQuantity, Decimal.parse('0.500'));
    });

    test('id is nullable and defaults to null', () {
      final entry = GuestSplitEntry(
        orderId: 1,
        guestNumber: 1,
        saleProductId: 1,
        shareQuantity: Decimal.one,
      );

      expect(entry.id, isNull);
    });

    test('creation with explicit id', () {
      final entry = GuestSplitEntry(
        id: 42,
        orderId: 1,
        guestNumber: 1,
        saleProductId: 1,
        shareQuantity: Decimal.one,
      );

      expect(entry.id, 42);
    });

    test('copyWith changes shareQuantity while preserving other fields', () {
      final original = GuestSplitEntry(
        id: 5,
        orderId: 10,
        guestNumber: 2,
        saleProductId: 55,
        shareQuantity: Decimal.parse('0.500'),
      );

      final updated = original.copyWith(shareQuantity: Decimal.parse('0.750'));

      expect(updated.shareQuantity, Decimal.parse('0.750'));
      expect(updated.id, 5);
      expect(updated.orderId, 10);
      expect(updated.guestNumber, 2);
      expect(updated.saleProductId, 55);
    });

    test('Decimal precision is preserved for fractional shares', () {
      final entry = GuestSplitEntry(
        orderId: 1,
        guestNumber: 1,
        saleProductId: 1,
        shareQuantity: Decimal.parse('0.333'),
      );

      expect(entry.shareQuantity.toString(), '0.333');
    });
  });
}
