import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/agent/agent_entity.dart';

void main() {
  group('AgentEntity', () {
    final agent = AgentEntity(
      localId: 1,
      serverId: 100,
      type: 1,
      name: 'Иванов Иван',
      phone: 77771234567,
    );

    test('creates with fields', () {
      expect(agent.localId, 1);
      expect(agent.serverId, 100);
      expect(agent.type, 1);
      expect(agent.name, 'Иванов Иван');
      expect(agent.phone, 77771234567);
    });

    test('type checks', () {
      expect(agent.isCustomer, true);
      expect(agent.isSupplier, false);
      expect(agent.isOwner, false);

      final supplier = agent.copyWith(type: 0);
      expect(supplier.isSupplier, true);

      final owner = agent.copyWith(type: 2);
      expect(owner.isOwner, true);
    });

    test('displayName', () {
      expect(agent.displayName, 'Иванов Иван');

      final noName = AgentEntity(localId: 5);
      expect(noName.displayName, 'Agent #5');
    });

    test('defaults', () {
      expect(agent.isDeleted, false);
      expect(agent.supportsOnlineOrder, false);
      expect(agent.bin, isNull);
      expect(agent.mainAccountId, isNull);
    });

    test('copyWith preserves values', () {
      final copy = agent.copyWith(name: 'Петров Пётр');
      expect(copy.name, 'Петров Пётр');
      expect(copy.localId, 1);
      expect(copy.serverId, 100);
      expect(copy.type, 1);
    });
  });
}
