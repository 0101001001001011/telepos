import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/agent/agent_entity.dart';

class AgentMapper {
  AgentMapper._();

  static AgentEntity fromDrift(Agent agent) {
    return AgentEntity(
      localId: agent.localId,
      serverId: agent.serverId,
      type: agent.type,
      storeId: agent.storeId,
      name: agent.name,
      phone: agent.phone,
      bin: agent.bin,
      legalType: agent.legalType,
      legalAddress: agent.legalAddress,
      actualAddress: agent.actualAddress,
      note: agent.note,
      legalName: agent.legalName,
      isDeleted: agent.isDeleted,
      editTime: agent.editTime,
      serverEditTime: agent.serverEditTime,
      mainAccountId: agent.mainAccountId,
      cashbackAccountId: agent.cashbackAccountId,
      state: agent.state,
      supportsOnlineOrder: agent.supportsOnlineOrder,
      onlineOrderApiUrl: agent.onlineOrderApiUrl,
      onlineOrderApiKey: agent.onlineOrderApiKey,
      orderEmail: agent.orderEmail,
      minOrderAmount: agent.minOrderAmount,
      deliveryDays: agent.deliveryDays,
    );
  }

  static AgentsCompanion toDrift(AgentEntity entity) {
    return AgentsCompanion(
      localId: entity.localId != null
          ? Value(entity.localId!)
          : const Value.absent(),
      serverId: Value(entity.serverId),
      type: Value(entity.type),
      storeId: Value(entity.storeId),
      name: Value(entity.name),
      phone: Value(entity.phone),
      bin: Value(entity.bin),
      legalType: Value(entity.legalType),
      legalAddress: Value(entity.legalAddress),
      actualAddress: Value(entity.actualAddress),
      note: Value(entity.note),
      legalName: Value(entity.legalName),
      isDeleted: Value(entity.isDeleted),
      editTime: Value(entity.editTime),
      serverEditTime: Value(entity.serverEditTime),
      mainAccountId: Value(entity.mainAccountId),
      cashbackAccountId: Value(entity.cashbackAccountId),
      state: Value(entity.state),
      supportsOnlineOrder: Value(entity.supportsOnlineOrder),
      onlineOrderApiUrl: Value(entity.onlineOrderApiUrl),
      onlineOrderApiKey: Value(entity.onlineOrderApiKey),
      orderEmail: Value(entity.orderEmail),
      minOrderAmount: Value(entity.minOrderAmount),
      deliveryDays: Value(entity.deliveryDays),
    );
  }

  static List<AgentEntity> fromDriftList(List<Agent> agents) {
    return agents.map(fromDrift).toList();
  }
}
