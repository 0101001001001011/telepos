import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';

void main() {
  group('OperatingMode', () {
    test('has exactly 4 values', () {
      expect(OperatingMode.values.length, 4);
    });

    test('index mapping matches expected order', () {
      expect(OperatingMode.retail.index, 0);
      expect(OperatingMode.restaurant.index, 1);
      expect(OperatingMode.service.index, 2);
      expect(OperatingMode.warehouse.index, 3);
    });

    test('fromIndex via values[] round-trips correctly', () {
      for (final mode in OperatingMode.values) {
        expect(OperatingMode.values[mode.index], mode);
      }
    });
  });

  group('TableStatus', () {
    test('has exactly 4 values', () {
      expect(TableStatus.values.length, 4);
    });

    test('index mapping matches expected order', () {
      expect(TableStatus.free.index, 0);
      expect(TableStatus.occupied.index, 1);
      expect(TableStatus.reserved.index, 2);
      expect(TableStatus.dirty.index, 3);
    });

    test('fromIndex via values[] round-trips correctly', () {
      for (final status in TableStatus.values) {
        expect(TableStatus.values[status.index], status);
      }
    });
  });

  group('OrderType', () {
    test('has exactly 3 values', () {
      expect(OrderType.values.length, 3);
    });

    test('index mapping matches expected order', () {
      expect(OrderType.dineIn.index, 0);
      expect(OrderType.takeout.index, 1);
      expect(OrderType.delivery.index, 2);
    });

    test('fromIndex via values[] round-trips correctly', () {
      for (final type in OrderType.values) {
        expect(OrderType.values[type.index], type);
      }
    });
  });

  group('ServiceOrderStatus', () {
    test('has exactly 5 values', () {
      expect(ServiceOrderStatus.values.length, 5);
    });

    test('index mapping matches expected order', () {
      expect(ServiceOrderStatus.intake.index, 0);
      expect(ServiceOrderStatus.inProgress.index, 1);
      expect(ServiceOrderStatus.completed.index, 2);
      expect(ServiceOrderStatus.closed.index, 3);
      expect(ServiceOrderStatus.cancelled.index, 4);
    });

    test('fromIndex via values[] round-trips correctly', () {
      for (final status in ServiceOrderStatus.values) {
        expect(ServiceOrderStatus.values[status.index], status);
      }
    });

    test('state machine transitions follow expected order', () {
      const transitions = [
        ServiceOrderStatus.intake,
        ServiceOrderStatus.inProgress,
        ServiceOrderStatus.completed,
        ServiceOrderStatus.closed,
      ];

      for (var i = 0; i < transitions.length - 1; i++) {
        expect(
          transitions[i].index < transitions[i + 1].index,
          isTrue,
          reason:
              '${transitions[i].name} (${transitions[i].index}) should precede '
              '${transitions[i + 1].name} (${transitions[i + 1].index})',
        );
      }
    });

    test('cancelled is a terminal status separate from the main flow', () {
      expect(ServiceOrderStatus.cancelled.index, 4);
      expect(
        ServiceOrderStatus.cancelled.index > ServiceOrderStatus.closed.index,
        isTrue,
      );
    });
  });
}
