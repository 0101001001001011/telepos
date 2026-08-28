import 'package:telepos/domain/entities/agent/agent_entity.dart';

abstract class AgentRepository {
  Future<AgentEntity?> findById(int localId);

  Future<AgentEntity?> findByPhone(int phone);

  Future<List<AgentEntity>> search(String query);

  Future<List<AgentEntity>> findByType(int type);

  Future<int> create(AgentEntity entity);

  Future<void> update(AgentEntity entity);

  Future<void> softDelete(int localId);
}
