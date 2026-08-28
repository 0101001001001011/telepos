import 'package:decimal/decimal.dart';

abstract class AgentBalanceService {
  Future<Decimal> get(int agentLocalId);

  Future<Decimal> getByServerId(int agentServerId);

  Future<Decimal> getCalculated(int agentLocalId);

  Future<Decimal> add(int agentLocalId, Decimal amount);

  Future<Decimal> subtract(int agentLocalId, Decimal amount);

  Future<void> set(int agentLocalId, Decimal balance);

  Future<void> coupleWith(Map<int, Decimal> balances);

  Future<Decimal> getCashback(int agentLocalId);

  Future<Decimal> addCashback(int agentLocalId, Decimal amount);
}
