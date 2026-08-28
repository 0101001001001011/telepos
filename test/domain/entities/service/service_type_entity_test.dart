import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/service/service_type_entity.dart';

void main() {
  group('ServiceTypeEntity', () {
    test('creation with defaults has requiresDevice=false, isActive=true', () {
      const entity = ServiceTypeEntity(productUcode: 12345);

      expect(entity.id, isNull);
      expect(entity.productUcode, 12345);
      expect(entity.estimatedDurationMinutes, isNull);
      expect(entity.warrantyDays, isNull);
      expect(entity.requiresDevice, false);
      expect(entity.isActive, true);
    });

    test('creation with all fields', () {
      const entity = ServiceTypeEntity(
        id: 1,
        productUcode: 99001,
        estimatedDurationMinutes: 120,
        warrantyDays: 30,
        requiresDevice: true,
        isActive: false,
      );

      expect(entity.id, 1);
      expect(entity.productUcode, 99001);
      expect(entity.estimatedDurationMinutes, 120);
      expect(entity.warrantyDays, 30);
      expect(entity.requiresDevice, true);
      expect(entity.isActive, false);
    });

    test('copyWith changes isActive while preserving other fields', () {
      const original = ServiceTypeEntity(
        id: 1,
        productUcode: 12345,
        estimatedDurationMinutes: 60,
        warrantyDays: 14,
        requiresDevice: true,
        isActive: true,
      );

      final updated = original.copyWith(isActive: false);

      expect(updated.isActive, false);
      expect(updated.id, 1);
      expect(updated.productUcode, 12345);
      expect(updated.estimatedDurationMinutes, 60);
      expect(updated.warrantyDays, 14);
      expect(updated.requiresDevice, true);
    });

    test('id is nullable for unsaved entities', () {
      const unsaved = ServiceTypeEntity(productUcode: 100);
      const saved = ServiceTypeEntity(id: 10, productUcode: 100);

      expect(unsaved.id, isNull);
      expect(saved.id, 10);
    });

    test('copyWith can change requiresDevice', () {
      const original = ServiceTypeEntity(
        productUcode: 500,
        requiresDevice: false,
      );

      final updated = original.copyWith(requiresDevice: true);

      expect(updated.requiresDevice, true);
      expect(updated.productUcode, 500);
    });
  });
}
