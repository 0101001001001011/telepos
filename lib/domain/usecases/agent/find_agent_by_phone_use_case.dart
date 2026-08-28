import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';

abstract class FindAgentByPhoneUseCase {
  Future<AgentInfo?> find(int phone);

  Future<AgentInfo?> findByType(int phone, int type);

  Future<AgentInfo?> findByServerId(int serverId);

  Future<AgentInfo?> findByLocalId(int localId);
}
