abstract class PersistAgentUseCase {
  Future<bool> persist(int localId);

  Future<void> createAccountsForAgent(int localId);
}

class AgentAccountType {
  AgentAccountType._();

  static const int main = 3;

  static const int cashback = 4;
}
