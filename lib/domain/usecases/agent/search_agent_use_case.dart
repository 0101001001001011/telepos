import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';

abstract class SearchAgentUseCase {
  Future<List<AgentInfo>> searchByName(
    String namePart,
    int type, {
    int limit = 100,
  });

  Future<List<AgentInfo>> searchByPhone(
    String phonePart,
    int type, {
    int limit = 100,
  });

  Future<List<AgentInfo>> searchByNameOrPhone(
    String query,
    int type, {
    int limit = 100,
  });

  Future<List<AgentInfo>> findAllByType(int type);
}
