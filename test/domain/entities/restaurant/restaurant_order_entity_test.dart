import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';

void main() {
  group('RestaurantOrderEntity', () {
    test('creation with defaults uses partySize=1, orderType=dineIn', () {
      final order = RestaurantOrderEntity(id: 1, openTime: 1700000000);

      expect(order.id, 1);
      expect(order.partySize, 1);
      expect(order.orderType, OrderType.dineIn);
      expect(order.openTime, 1700000000);
      expect(order.closeTime, isNull);
      expect(order.tableId, isNull);
      expect(order.receiptNo, isNull);
      expect(order.posId, isNull);
      expect(order.waiterId, isNull);
      expect(order.tips, isNull);
      expect(order.deliveryAddress, isNull);
      expect(order.deliveryPhone, isNull);
      expect(order.note, isNull);
    });

    test('isOpen is true when closeTime is null, isClosed is false', () {
      final order = RestaurantOrderEntity(id: 1, openTime: 1700000000);

      expect(order.isOpen, true);
      expect(order.isClosed, false);
    });

    test('isClosed is true when closeTime is set, isOpen is false', () {
      final order = RestaurantOrderEntity(
        id: 1,
        openTime: 1700000000,
        closeTime: 1700003600,
      );

      expect(order.isClosed, true);
      expect(order.isOpen, false);
    });

    test('isDineIn returns true for dineIn order type', () {
      final order = RestaurantOrderEntity(
        id: 1,
        openTime: 1700000000,
        orderType: OrderType.dineIn,
      );

      expect(order.isDineIn, true);
      expect(order.isTakeout, false);
      expect(order.isDelivery, false);
    });

    test('isTakeout returns true for takeout order type', () {
      final order = RestaurantOrderEntity(
        id: 1,
        openTime: 1700000000,
        orderType: OrderType.takeout,
      );

      expect(order.isTakeout, true);
      expect(order.isDineIn, false);
      expect(order.isDelivery, false);
    });

    test('isDelivery returns true for delivery order type', () {
      final order = RestaurantOrderEntity(
        id: 1,
        openTime: 1700000000,
        orderType: OrderType.delivery,
        deliveryAddress: '123 Main St',
        deliveryPhone: '+77001234567',
      );

      expect(order.isDelivery, true);
      expect(order.isDineIn, false);
      expect(order.isTakeout, false);
      expect(order.deliveryAddress, '123 Main St');
      expect(order.deliveryPhone, '+77001234567');
    });

    test(
      'isLinkedToSale is true only when both receiptNo and posId are set',
      () {
        final linked = RestaurantOrderEntity(
          id: 1,
          openTime: 1700000000,
          receiptNo: 100,
          posId: 5,
        );
        final notLinked = RestaurantOrderEntity(
          id: 2,
          openTime: 1700000000,
          receiptNo: 100,
        );
        final alsoNotLinked = RestaurantOrderEntity(
          id: 3,
          openTime: 1700000000,
          posId: 5,
        );

        expect(linked.isLinkedToSale, true);
        expect(notLinked.isLinkedToSale, false);
        expect(alsoNotLinked.isLinkedToSale, false);
      },
    );

    test('copyWith with clearCloseTime sets closeTime to null', () {
      final order = RestaurantOrderEntity(
        id: 1,
        openTime: 1700000000,
        closeTime: 1700003600,
      );

      expect(order.isClosed, true);

      final reopened = order.copyWith(clearCloseTime: true);

      expect(reopened.closeTime, isNull);
      expect(reopened.isOpen, true);
      expect(reopened.id, 1);
      expect(reopened.openTime, 1700000000);
    });

    test('copyWith preserves tips as Decimal', () {
      final order = RestaurantOrderEntity(
        id: 1,
        openTime: 1700000000,
        tips: Decimal.parse('500.50'),
      );

      final updated = order.copyWith(partySize: 3);

      expect(updated.tips, Decimal.parse('500.50'));
      expect(updated.partySize, 3);
    });
  });
}
