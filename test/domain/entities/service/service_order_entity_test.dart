import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';

void main() {
  group('ServiceOrderEntity', () {
    ServiceOrderEntity createOrder({
      ServiceOrderStatus status = ServiceOrderStatus.intake,
      int? receiptNo,
      int? posId,
      String? clientName,
      String? clientPhone,
      int? clientAgentId,
    }) {
      return ServiceOrderEntity(
        id: 1,
        orderNumber: 'SO-001',
        receiptNo: receiptNo,
        posId: posId,
        status: status,
        userId: 10,
        clientAgentId: clientAgentId,
        clientName: clientName,
        clientPhone: clientPhone,
        intakeTime: 1700000000,
      );
    }

    test('creation with defaults has status=intake', () {
      final order = createOrder();

      expect(order.id, 1);
      expect(order.orderNumber, 'SO-001');
      expect(order.status, ServiceOrderStatus.intake);
      expect(order.userId, 10);
      expect(order.intakeTime, 1700000000);
      expect(order.assigneeId, isNull);
      expect(order.clientNote, isNull);
      expect(order.deviceDescription, isNull);
      expect(order.serialNumber, isNull);
      expect(order.complaint, isNull);
      expect(order.estimatedCompletionTime, isNull);
      expect(order.estimatedAmount, isNull);
      expect(order.prepaymentAmount, isNull);
      expect(order.finalAmount, isNull);
    });

    test('isIntake is true for intake status', () {
      final order = createOrder(status: ServiceOrderStatus.intake);

      expect(order.isIntake, true);
      expect(order.isInProgress, false);
      expect(order.isCompleted, false);
      expect(order.isClosed, false);
      expect(order.isCancelled, false);
    });

    test('isInProgress is true for inProgress status', () {
      final order = createOrder(status: ServiceOrderStatus.inProgress);

      expect(order.isInProgress, true);
      expect(order.isIntake, false);
    });

    test('isCompleted is true for completed status', () {
      final order = createOrder(status: ServiceOrderStatus.completed);

      expect(order.isCompleted, true);
      expect(order.isIntake, false);
    });

    test('isClosed is true for closed status', () {
      final order = createOrder(status: ServiceOrderStatus.closed);

      expect(order.isClosed, true);
      expect(order.isActive, false);
    });

    test('isCancelled is true for cancelled status', () {
      final order = createOrder(status: ServiceOrderStatus.cancelled);

      expect(order.isCancelled, true);
      expect(order.isActive, false);
    });

    test('isActive is true for non-terminal statuses', () {
      expect(createOrder(status: ServiceOrderStatus.intake).isActive, true);
      expect(createOrder(status: ServiceOrderStatus.inProgress).isActive, true);
      expect(createOrder(status: ServiceOrderStatus.completed).isActive, true);
      expect(createOrder(status: ServiceOrderStatus.closed).isActive, false);
      expect(createOrder(status: ServiceOrderStatus.cancelled).isActive, false);
    });

    test('canProgress is true for non-terminal statuses', () {
      expect(createOrder(status: ServiceOrderStatus.intake).canProgress, true);
      expect(
        createOrder(status: ServiceOrderStatus.inProgress).canProgress,
        true,
      );
      expect(
        createOrder(status: ServiceOrderStatus.completed).canProgress,
        true,
      );
      expect(createOrder(status: ServiceOrderStatus.closed).canProgress, false);
      expect(
        createOrder(status: ServiceOrderStatus.cancelled).canProgress,
        false,
      );
    });

    test(
      'nextStatus follows state machine: intake -> inProgress -> completed -> closed',
      () {
        expect(
          createOrder(status: ServiceOrderStatus.intake).nextStatus,
          ServiceOrderStatus.inProgress,
        );
        expect(
          createOrder(status: ServiceOrderStatus.inProgress).nextStatus,
          ServiceOrderStatus.completed,
        );
        expect(
          createOrder(status: ServiceOrderStatus.completed).nextStatus,
          ServiceOrderStatus.closed,
        );
      },
    );

    test('nextStatus returns null for terminal statuses', () {
      expect(createOrder(status: ServiceOrderStatus.closed).nextStatus, isNull);
      expect(
        createOrder(status: ServiceOrderStatus.cancelled).nextStatus,
        isNull,
      );
    });

    test('clientDisplayName returns clientName when available', () {
      final order = createOrder(
        clientName: 'John Doe',
        clientPhone: '+77001234567',
      );

      expect(order.clientDisplayName, 'John Doe');
    });

    test('clientDisplayName falls back to clientPhone when name is empty', () {
      final order = createOrder(clientName: '', clientPhone: '+77001234567');

      expect(order.clientDisplayName, '+77001234567');
    });

    test('clientDisplayName falls back to clientPhone when name is null', () {
      final order = createOrder(clientPhone: '+77001234567');

      expect(order.clientDisplayName, '+77001234567');
    });

    test('clientDisplayName falls back to agent id placeholder', () {
      final order = createOrder(clientAgentId: 99);

      expect(order.clientDisplayName, 'Клиент #99');
    });

    test('clientDisplayName falls back to order id when no client info', () {
      final order = createOrder();

      expect(order.clientDisplayName, 'Клиент #1');
    });

    test('isLinkedToSale requires both receiptNo and posId', () {
      expect(createOrder(receiptNo: 100, posId: 5).isLinkedToSale, true);
      expect(createOrder(receiptNo: 100).isLinkedToSale, false);
      expect(createOrder(posId: 5).isLinkedToSale, false);
      expect(createOrder().isLinkedToSale, false);
    });

    test('copyWith changes status while preserving other fields', () {
      final original = ServiceOrderEntity(
        id: 1,
        orderNumber: 'SO-001',
        userId: 10,
        intakeTime: 1700000000,
        estimatedAmount: Decimal.parse('15000.000'),
      );

      final updated = original.copyWith(status: ServiceOrderStatus.inProgress);

      expect(updated.status, ServiceOrderStatus.inProgress);
      expect(updated.id, 1);
      expect(updated.orderNumber, 'SO-001');
      expect(updated.estimatedAmount, Decimal.parse('15000.000'));
    });
  });
}
