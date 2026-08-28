import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/agent_mapper.dart';
import 'package:telepos/domain/entities/agent/agent_entity.dart';

void main() {
  group('AgentMapper', () {
    test('fromDrift converts all fields', () {
      final driftAgent = Agent(
        localId: 1,
        serverId: 100,
        type: 1,
        storeId: 10,
        name: 'Иванов Иван',
        phone: 77771234567,
        bin: '123456789012',
        isDeleted: false,
        supportsOnlineOrder: false,
      );

      final entity = AgentMapper.fromDrift(driftAgent);

      expect(entity.localId, 1);
      expect(entity.serverId, 100);
      expect(entity.type, 1);
      expect(entity.storeId, 10);
      expect(entity.name, 'Иванов Иван');
      expect(entity.phone, 77771234567);
      expect(entity.bin, '123456789012');
      expect(entity.isDeleted, false);
      expect(entity.isCustomer, true);
    });

    test('toDrift creates companion', () {
      final entity = AgentEntity(type: 0, name: 'ОптТорг', phone: 77779876543);

      final companion = AgentMapper.toDrift(entity);

      expect(companion.type.value, 0);
      expect(companion.name.value, 'ОптТорг');
      expect(companion.phone.value, 77779876543);
    });

    test('fromDriftList maps multiple', () {
      final agents = [
        Agent(
          localId: 1,
          name: 'Agent 1',
          isDeleted: false,
          supportsOnlineOrder: false,
        ),
        Agent(
          localId: 2,
          name: 'Agent 2',
          isDeleted: false,
          supportsOnlineOrder: false,
        ),
      ];

      final entities = AgentMapper.fromDriftList(agents);
      expect(entities.length, 2);
      expect(entities[0].localId, 1);
      expect(entities[1].localId, 2);
    });

    test('round-trip preserves data', () {
      final original = AgentEntity(
        localId: 3,
        serverId: 300,
        type: 1,
        storeId: 10,
        name: 'ОптТорг',
        phone: 77779876543,
        bin: '987654321098',
        isDeleted: false,
        supportsOnlineOrder: true,
        minOrderAmount: Decimal.parse('5000.000'),
        deliveryDays: 3,
      );

      final companion = AgentMapper.toDrift(original);

      final driftAgent = Agent(
        localId: companion.localId.value,
        serverId: companion.serverId.value,
        type: companion.type.value,
        storeId: companion.storeId.value,
        name: companion.name.value,
        phone: companion.phone.value,
        bin: companion.bin.value,
        isDeleted: companion.isDeleted.value,
        supportsOnlineOrder: companion.supportsOnlineOrder.value,
        minOrderAmount: companion.minOrderAmount.value,
        deliveryDays: companion.deliveryDays.value,
      );

      final restored = AgentMapper.fromDrift(driftAgent);

      expect(restored.localId, original.localId);
      expect(restored.serverId, original.serverId);
      expect(restored.type, original.type);
      expect(restored.storeId, original.storeId);
      expect(restored.name, original.name);
      expect(restored.phone, original.phone);
      expect(restored.bin, original.bin);
      expect(restored.isDeleted, original.isDeleted);
      expect(restored.supportsOnlineOrder, original.supportsOnlineOrder);
      expect(restored.minOrderAmount, original.minOrderAmount);
      expect(restored.deliveryDays, original.deliveryDays);
    });
  });
}
