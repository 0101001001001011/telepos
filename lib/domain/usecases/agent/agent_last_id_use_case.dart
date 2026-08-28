abstract class AgentLastIdUseCase {
  Future<int> getNextId();

  Future<int?> getLastId();

  Future<int> count({int? type});

  Future<int> countUnsynced();
}
