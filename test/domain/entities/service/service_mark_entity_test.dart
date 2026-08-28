import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/service/service_mark_entity.dart';

void main() {
  group('ServiceMarkEntity', () {
    test('creation with defaults has markType=4', () {
      final mark = ServiceMarkEntity(
        serviceOrderId: 10,
        description: 'General check',
        userId: 5,
        createdAt: 1700000000,
      );

      expect(mark.id, isNull);
      expect(mark.serviceOrderId, 10);
      expect(mark.description, 'General check');
      expect(mark.markType, 4);
      expect(mark.userId, 5);
      expect(mark.cost, isNull);
      expect(mark.createdAt, 1700000000);
      expect(mark.note, isNull);
    });

    test('markTypeLabel returns Диагностика for type 0', () {
      final mark = ServiceMarkEntity(
        serviceOrderId: 1,
        description: 'Initial diagnosis',
        markType: 0,
        userId: 1,
        createdAt: 1700000000,
      );

      expect(mark.markTypeLabel, 'Диагностика');
    });

    test('markTypeLabel returns Замена детали for type 1', () {
      final mark = ServiceMarkEntity(
        serviceOrderId: 1,
        description: 'Replace screen',
        markType: 1,
        userId: 1,
        createdAt: 1700000000,
      );

      expect(mark.markTypeLabel, 'Замена детали');
    });

    test('markTypeLabel returns Ремонт for type 2', () {
      final mark = ServiceMarkEntity(
        serviceOrderId: 1,
        description: 'Fix motherboard',
        markType: 2,
        userId: 1,
        createdAt: 1700000000,
      );

      expect(mark.markTypeLabel, 'Ремонт');
    });

    test('markTypeLabel returns Тестирование for type 3', () {
      final mark = ServiceMarkEntity(
        serviceOrderId: 1,
        description: 'Final testing',
        markType: 3,
        userId: 1,
        createdAt: 1700000000,
      );

      expect(mark.markTypeLabel, 'Тестирование');
    });

    test(
      'markTypeLabel returns Прочее for default type 4 and unknown types',
      () {
        final defaultMark = ServiceMarkEntity(
          serviceOrderId: 1,
          description: 'Other work',
          userId: 1,
          createdAt: 1700000000,
        );
        final unknownMark = ServiceMarkEntity(
          serviceOrderId: 1,
          description: 'Unknown',
          markType: 99,
          userId: 1,
          createdAt: 1700000000,
        );

        expect(defaultMark.markTypeLabel, 'Прочее');
        expect(unknownMark.markTypeLabel, 'Прочее');
      },
    );

    test('cost stores Decimal value correctly', () {
      final mark = ServiceMarkEntity(
        serviceOrderId: 1,
        description: 'Screen replacement',
        markType: 1,
        userId: 1,
        cost: Decimal.parse('12500.500'),
        createdAt: 1700000000,
      );

      expect(mark.cost, Decimal.parse('12500.500'));
    });

    test('copyWith changes description while preserving other fields', () {
      final original = ServiceMarkEntity(
        id: 7,
        serviceOrderId: 10,
        description: 'Old description',
        markType: 2,
        userId: 5,
        cost: Decimal.parse('5000.000'),
        createdAt: 1700000000,
        note: 'Some note',
      );

      final updated = original.copyWith(description: 'New description');

      expect(updated.description, 'New description');
      expect(updated.id, 7);
      expect(updated.serviceOrderId, 10);
      expect(updated.markType, 2);
      expect(updated.userId, 5);
      expect(updated.cost, Decimal.parse('5000.000'));
      expect(updated.note, 'Some note');
    });

    test('id is nullable - can be null for unsaved entities', () {
      final unsaved = ServiceMarkEntity(
        serviceOrderId: 1,
        description: 'New mark',
        userId: 1,
        createdAt: 1700000000,
      );
      final saved = ServiceMarkEntity(
        id: 42,
        serviceOrderId: 1,
        description: 'Saved mark',
        userId: 1,
        createdAt: 1700000000,
      );

      expect(unsaved.id, isNull);
      expect(saved.id, 42);
    });
  });
}
