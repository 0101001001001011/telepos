import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_table_entity.dart';

void main() {
  group('RestaurantTableEntity', () {
    test(
      'creation with defaults uses capacity=4, status=free, isActive=true, sortOrder=0',
      () {
        const table = RestaurantTableEntity(id: 1, name: 'Table 1');

        expect(table.id, 1);
        expect(table.name, 'Table 1');
        expect(table.capacity, 4);
        expect(table.status, TableStatus.free);
        expect(table.zone, isNull);
        expect(table.positionX, isNull);
        expect(table.positionY, isNull);
        expect(table.isActive, true);
        expect(table.sortOrder, 0);
      },
    );

    test('creation with all fields', () {
      const table = RestaurantTableEntity(
        id: 5,
        name: 'VIP-1',
        capacity: 8,
        status: TableStatus.occupied,
        zone: 'VIP',
        positionX: 10.5,
        positionY: 20.3,
        isActive: false,
        sortOrder: 3,
      );

      expect(table.id, 5);
      expect(table.name, 'VIP-1');
      expect(table.capacity, 8);
      expect(table.status, TableStatus.occupied);
      expect(table.zone, 'VIP');
      expect(table.positionX, 10.5);
      expect(table.positionY, 20.3);
      expect(table.isActive, false);
      expect(table.sortOrder, 3);
    });

    test('copyWith changes status while preserving other fields', () {
      const original = RestaurantTableEntity(
        id: 1,
        name: 'Table 1',
        capacity: 6,
        zone: 'Main Hall',
      );

      final updated = original.copyWith(status: TableStatus.occupied);

      expect(updated.status, TableStatus.occupied);
      expect(updated.id, 1);
      expect(updated.name, 'Table 1');
      expect(updated.capacity, 6);
      expect(updated.zone, 'Main Hall');
    });

    test('isFree returns true only when status is free', () {
      const free = RestaurantTableEntity(
        id: 1,
        name: 'T1',
        status: TableStatus.free,
      );
      const occupied = RestaurantTableEntity(
        id: 2,
        name: 'T2',
        status: TableStatus.occupied,
      );

      expect(free.isFree, true);
      expect(occupied.isFree, false);
    });

    test('isOccupied returns true only when status is occupied', () {
      const occupied = RestaurantTableEntity(
        id: 1,
        name: 'T1',
        status: TableStatus.occupied,
      );
      const free = RestaurantTableEntity(
        id: 2,
        name: 'T2',
        status: TableStatus.free,
      );

      expect(occupied.isOccupied, true);
      expect(free.isOccupied, false);
    });

    test('isReserved returns true only when status is reserved', () {
      const reserved = RestaurantTableEntity(
        id: 1,
        name: 'T1',
        status: TableStatus.reserved,
      );
      const free = RestaurantTableEntity(
        id: 2,
        name: 'T2',
        status: TableStatus.free,
      );

      expect(reserved.isReserved, true);
      expect(free.isReserved, false);
    });

    test('isDirty returns true only when status is dirty', () {
      const dirty = RestaurantTableEntity(
        id: 1,
        name: 'T1',
        status: TableStatus.dirty,
      );
      const occupied = RestaurantTableEntity(
        id: 2,
        name: 'T2',
        status: TableStatus.occupied,
      );

      expect(dirty.isDirty, true);
      expect(occupied.isDirty, false);
    });
  });
}
