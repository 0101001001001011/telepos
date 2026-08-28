import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/persist_agent_use_case.dart';

class PersistAgentUseCaseImpl implements PersistAgentUseCase {
  PersistAgentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _stateSynced = 3;

  @override
  Future<bool> persist(int localId) async {
    return _db.transaction(() async {
      final agent = await (_db.select(
        _db.agents,
      )..where((a) => a.localId.equals(localId))).getSingleOrNull();

      if (agent == null) {
        _logger.warning('PersistAgent: agent localId=$localId not found');
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await (_db.update(
        _db.agents,
      )..where((a) => a.localId.equals(localId))).write(
        AgentsCompanion(state: const Value(_stateSynced), editTime: Value(now)),
      );

      await createAccountsForAgent(localId);

      _logger.info('PersistAgent: persisted localId=$localId as SYNCED');
      return true;
    });
  }

  @override
  Future<void> createAccountsForAgent(int localId) async {
    final agent = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(localId))).getSingleOrNull();

    if (agent == null) {
      _logger.warning(
        'PersistAgent: cannot create accounts, agent localId=$localId not found',
      );
      return;
    }

    if (agent.mainAccountId != null && agent.cashbackAccountId != null) {
      _logger.debug(
        'PersistAgent: accounts already exist for agent localId=$localId',
      );
      return;
    }

    final lastId = await _getLastLocalAccountId();
    var nextId = lastId - 1;

    int? mainAccountId = agent.mainAccountId;
    int? cashbackAccountId = agent.cashbackAccountId;

    if (mainAccountId == null) {
      mainAccountId = nextId--;
      await _db
          .into(_db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: Value(mainAccountId),
              type: AgentAccountType.main,
              name: Value('${agent.name} - Main'),
              value: Value(Decimal.zero),
              agentId: Value(localId),
              visibleToPos: const Value(true),
            ),
          );
      _logger.debug('PersistAgent: created main account id=$mainAccountId');
    }

    if (cashbackAccountId == null) {
      cashbackAccountId = nextId--;
      await _db
          .into(_db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: Value(cashbackAccountId),
              type: AgentAccountType.cashback,
              name: Value('${agent.name} - Cashback'),
              value: Value(Decimal.zero),
              agentId: Value(localId),
              visibleToPos: const Value(false),
            ),
          );
      _logger.debug(
        'PersistAgent: created cashback account id=$cashbackAccountId',
      );
    }

    await (_db.update(
      _db.agents,
    )..where((a) => a.localId.equals(localId))).write(
      AgentsCompanion(
        mainAccountId: Value(mainAccountId),
        cashbackAccountId: Value(cashbackAccountId),
      ),
    );
  }

  Future<int> _getLastLocalAccountId() async {
    final result = await _db
        .customSelect(
          'SELECT MIN(id) AS min_id FROM accounts WHERE id < 0',
          readsFrom: {_db.accounts},
        )
        .getSingleOrNull();

    final minId = result?.read<int?>('min_id');
    return minId ?? 0;
  }
}
