import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/agent_balance_service.dart';

class AgentBalanceServiceImpl implements AgentBalanceService {
  AgentBalanceServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<Decimal> get(int agentLocalId) async {
    final agent = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(agentLocalId))).getSingleOrNull();

    if (agent == null || agent.mainAccountId == null) {
      _logger.debug('AgentBalance: agent $agentLocalId has no main account');
      return Decimal.zero;
    }

    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(agent.mainAccountId!))).getSingleOrNull();

    if (account == null) {
      _logger.warning('AgentBalance: account ${agent.mainAccountId} not found');
      return Decimal.zero;
    }

    return account.value ?? Decimal.zero;
  }

  @override
  Future<Decimal> getByServerId(int agentServerId) async {
    final agent = await _db.agentDao.findByServerId(agentServerId);

    if (agent == null) {
      _logger.debug('AgentBalance: agent serverId=$agentServerId not found');
      return Decimal.zero;
    }

    return get(agent.localId);
  }

  @override
  Future<Decimal> getCalculated(int agentLocalId) async {
    try {
      final paymentsSum = await _db.paymentDao.sumAmountByCustomerLocalId(
        agentLocalId,
      );
      final refundsSum = await _db.refundDao.sumAmountByCustomerLocalId(
        agentLocalId,
      );
      final salesSum = await _db.saleDao.sumAmountByCustomerLocalId(
        agentLocalId,
      );

      final payments = paymentsSum != null
          ? Decimal.parse(paymentsSum.toStringAsFixed(3))
          : Decimal.zero;
      final refunds = refundsSum != null
          ? Decimal.parse(refundsSum.toStringAsFixed(3))
          : Decimal.zero;
      final sales = salesSum != null
          ? Decimal.parse(salesSum.toStringAsFixed(3))
          : Decimal.zero;

      final calculatedBalance = payments + refunds - sales;

      _logger.debug(
        'AgentBalance: calculated for agent $agentLocalId: '
        'payments=$payments + refunds=$refunds - sales=$sales = $calculatedBalance',
      );

      return calculatedBalance;
    } catch (e, st) {
      _logger.handle(e, st, 'AgentBalance: failed to calculate balance');
      return get(agentLocalId);
    }
  }

  @override
  Future<Decimal> add(int agentLocalId, Decimal amount) async {
    final currentBalance = await get(agentLocalId);
    final newBalance = currentBalance + amount;

    await set(agentLocalId, newBalance);

    _logger.info(
      'AgentBalance: added $amount to agent $agentLocalId, '
      'new balance: $newBalance',
    );

    return newBalance;
  }

  @override
  Future<Decimal> subtract(int agentLocalId, Decimal amount) async {
    final currentBalance = await get(agentLocalId);
    final newBalance = currentBalance - amount;

    await set(agentLocalId, newBalance);

    _logger.info(
      'AgentBalance: subtracted $amount from agent $agentLocalId, '
      'new balance: $newBalance',
    );

    return newBalance;
  }

  @override
  Future<void> set(int agentLocalId, Decimal balance) async {
    final agent = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(agentLocalId))).getSingleOrNull();

    if (agent == null || agent.mainAccountId == null) {
      _logger.warning(
        'AgentBalance: cannot set balance, agent $agentLocalId has no account',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await (_db.update(
      _db.accounts,
    )..where((a) => a.id.equals(agent.mainAccountId!))).write(
      AccountsCompanion(value: Value(balance), updateTime: Value(now)),
    );
  }

  @override
  Future<void> coupleWith(Map<int, Decimal> balances) async {
    for (final entry in balances.entries) {
      final agentServerId = entry.key;
      final balance = entry.value;

      final agent = await _db.agentDao.findByServerId(agentServerId);
      if (agent != null) {
        await set(agent.localId, balance);
      }
    }

    _logger.info('AgentBalance: coupled ${balances.length} balances');
  }

  @override
  Future<Decimal> getCashback(int agentLocalId) async {
    final agent = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(agentLocalId))).getSingleOrNull();

    if (agent == null || agent.cashbackAccountId == null) {
      return Decimal.zero;
    }

    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(agent.cashbackAccountId!))).getSingleOrNull();

    return account?.value ?? Decimal.zero;
  }

  @override
  Future<Decimal> addCashback(int agentLocalId, Decimal amount) async {
    final agent = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(agentLocalId))).getSingleOrNull();

    if (agent == null || agent.cashbackAccountId == null) {
      _logger.warning(
        'AgentBalance: cannot add cashback, agent $agentLocalId has no cashback account',
      );
      return Decimal.zero;
    }

    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(agent.cashbackAccountId!))).getSingleOrNull();

    final currentCashback = account?.value ?? Decimal.zero;
    final newCashback = currentCashback + amount;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await (_db.update(
      _db.accounts,
    )..where((a) => a.id.equals(agent.cashbackAccountId!))).write(
      AccountsCompanion(value: Value(newCashback), updateTime: Value(now)),
    );

    _logger.info(
      'AgentBalance: added $amount cashback to agent $agentLocalId, '
      'new cashback: $newCashback',
    );

    return newCashback;
  }
}
