abstract class AgentSyncRepository {
  Future<List<Map<String, dynamic>>> getModifiedAgents(DateTime? since);

  Future<void> saveAgents(List<Map<String, dynamic>> agents);

  Future<void> updateAgentBalance(int agentId, num balance);
}
