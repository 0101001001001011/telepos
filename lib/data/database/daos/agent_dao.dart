import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';

part 'agent_dao.g.dart';

@DriftAccessor(tables: [Agents])
class AgentDao extends DatabaseAccessor<AppDatabase> with _$AgentDaoMixin {
  AgentDao(super.db);

  Future<Agent?> findCreated() =>
      (select(agents)
            ..where((a) => a.serverId.isNull())
            ..limit(1))
          .getSingleOrNull();

  Future<int?> findLastLocalId() {
    final expr = agents.localId.max();
    return (selectOnly(
      agents,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  Future<List<Agent>> findChanged({int limit = 100}) =>
      (select(agents)
            ..where((a) => a.serverId.isNotNull() & a.state.equals(3).not())
            ..limit(limit))
          .get();

  Future<int?> findLastEditTime() {
    final expr = agents.serverEditTime.max();
    return (selectOnly(
      agents,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  Future<int?> findLastServerId() => customSelect(
    'SELECT MAX(server_id) AS val FROM agents WHERE server_edit_time = (SELECT MAX(server_edit_time) FROM agents)',
    readsFrom: {agents},
  ).get().then((rows) => rows.isEmpty ? null : rows.first.read<int?>('val'));

  Future<List<Agent>> findByNamePart(
    String name,
    int type, {
    int limit = 100,
  }) =>
      (select(agents)
            ..where(
              (a) =>
                  a.name.like(name) &
                  a.type.equals(type) &
                  a.isDeleted.equals(false),
            )
            ..orderBy([(a) => OrderingTerm.desc(a.editTime)])
            ..limit(limit))
          .get();

  Future<Agent?> findByServerId(int serverId) => (select(
    agents,
  )..where((a) => a.serverId.equals(serverId))).getSingleOrNull();

  Future<List<Agent>> findWithType(int type) =>
      (select(agents)
            ..where((a) => a.type.equals(type) & a.isDeleted.equals(false))
            ..orderBy([(a) => OrderingTerm.desc(a.editTime)]))
          .get();

  Future<List<Agent>> findByPhonePart(String phone, int type) =>
      (select(agents)
            ..where(
              (a) =>
                  a.phone.cast<String>().like(phone) &
                  a.type.equals(type) &
                  a.isDeleted.equals(false),
            )
            ..orderBy([(a) => OrderingTerm.desc(a.editTime)]))
          .get();

  Future<List<Agent>> findByNameOrPhonePart(String nameOrPhone, int type) =>
      (select(agents)..where(
            (a) =>
                a.type.equals(type) &
                a.isDeleted.equals(false) &
                (a.phone.cast<String>().like(nameOrPhone) |
                    a.name.like(nameOrPhone)),
          ))
          .get();

  Future<Agent?> findByPhone(int phone) =>
      (select(agents)..where((a) => a.phone.equals(phone))).getSingleOrNull();

  Future<Agent?> findByPhoneAndType(int phone, int type) =>
      (select(agents)
            ..where((a) => a.phone.equals(phone) & a.type.equals(type)))
          .getSingleOrNull();

  Future<int> countUnSyncedCustomers() {
    final expr = agents.localId.count();
    return (selectOnly(agents)
          ..addColumns([expr])
          ..where(agents.state.equals(3).not() & agents.type.equals(1)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countWithNameAndType(String name, int type) {
    final expr = agents.localId.count();
    return (selectOnly(agents)
          ..addColumns([expr])
          ..where(agents.name.like(name) & agents.type.equals(type)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countCreated() {
    final expr = agents.localId.count();
    return (selectOnly(agents)
          ..addColumns([expr])
          ..where(agents.serverId.isNull()))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<Agent?> findLast() =>
      (select(agents)
            ..where((a) => a.serverId.isNotNull())
            ..orderBy([
              (a) => OrderingTerm.desc(a.serverEditTime),
              (a) => OrderingTerm.desc(a.serverId),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<void> markAsSynced(List<int> agentServerIds) => customStatement(
    'UPDATE agents SET state = 3 WHERE server_id IN (${agentServerIds.map((_) => '?').join(',')})',
    agentServerIds,
  );

  Future<void> markAsSyncedByLocalId(List<int> localIds) {
    if (localIds.isEmpty) return Future.value();
    return customStatement(
      'UPDATE agents SET state = 3 WHERE local_id IN (${localIds.map((_) => '?').join(',')})',
      localIds,
    );
  }

  Future<Agent?> findByLocalId(int localId) => (select(
    agents,
  )..where((a) => a.localId.equals(localId))).getSingleOrNull();

  Future<int> restoreAgent(int localId) =>
      (update(agents)..where((a) => a.localId.equals(localId))).write(
        const AgentsCompanion(isDeleted: Value(false)),
      );

  Future<Agent?> findById(int id) => findByLocalId(id);

  Future<List<Agent>> findByType(int type, {String? search, int limit = 100}) {
    if (search != null && search.isNotEmpty) {
      return (select(agents)
            ..where(
              (a) =>
                  a.type.equals(type) &
                  a.isDeleted.equals(false) &
                  a.name.like('%$search%'),
            )
            ..orderBy([(a) => OrderingTerm.desc(a.editTime)])
            ..limit(limit))
          .get();
    }
    return (select(agents)
          ..where((a) => a.type.equals(type) & a.isDeleted.equals(false))
          ..orderBy([(a) => OrderingTerm.desc(a.editTime)])
          ..limit(limit))
        .get();
  }

  Future<int> softDelete(int localId) =>
      (update(agents)..where((a) => a.localId.equals(localId))).write(
        const AgentsCompanion(isDeleted: Value(true)),
      );

  Future<int> count() {
    final expr = agents.localId.count();
    return (selectOnly(agents)
          ..addColumns([expr])
          ..where(agents.isDeleted.equals(false)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countByType(int type) {
    final expr = agents.localId.count();
    return (selectOnly(agents)
          ..addColumns([expr])
          ..where(agents.type.equals(type) & agents.isDeleted.equals(false)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countSuppliers() => countByType(0);

  Future<int> countCustomers() => countByType(1);

  Future<bool> hasAny() async {
    final c = await count();
    return c > 0;
  }

  Future<List<Agent>> findOnlineOrderSuppliers() =>
      (select(agents)
            ..where(
              (a) =>
                  a.type.equals(0) &
                  a.isDeleted.equals(false) &
                  a.supportsOnlineOrder.equals(true),
            )
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .get();

  Future<int> updateOnlineOrderSettings({
    required int localId,
    required bool supportsOnlineOrder,
    String? apiUrl,
    String? apiKey,
    String? orderEmail,
  }) => (update(agents)..where((a) => a.localId.equals(localId))).write(
    AgentsCompanion(
      supportsOnlineOrder: Value(supportsOnlineOrder),
      onlineOrderApiUrl: Value(apiUrl),
      onlineOrderApiKey: Value(apiKey),
      orderEmail: Value(orderEmail),
    ),
  );

  Future<Decimal> postLedgerAdjustment(int agentLocalId, Decimal delta) async {
    final accountDao = attachedDatabase.accountDao;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final agent = await findByLocalId(agentLocalId);
    if (agent == null) {
      throw StateError(
        'AgentDao.postLedgerAdjustment: agent $agentLocalId not found',
      );
    }

    int? mainAccountId = agent.mainAccountId;

    if (mainAccountId == null) {
      mainAccountId = await accountDao.getNextId();
      await accountDao.insertAccount(
        AccountsCompanion(
          id: Value(mainAccountId),
          type: const Value(AccountType.agentMain),
          agentId: Value(agentLocalId),
          name: Value(agent.name),
          value: Value(Decimal.zero),
          visibleToPos: const Value(false),
          updateTime: Value(now),
        ),
      );
      await (update(
        agents,
      )..where((a) => a.localId.equals(agentLocalId))).write(
        AgentsCompanion(
          mainAccountId: Value(mainAccountId),
          editTime: Value(now),
        ),
      );
    }

    final account = await accountDao.findById(mainAccountId);
    final currentBalance = account?.value ?? Decimal.zero;
    final newBalance = currentBalance + delta;

    await accountDao.updateBalance(mainAccountId, newBalance);
    await (update(agents)..where((a) => a.localId.equals(agentLocalId))).write(
      AgentsCompanion(editTime: Value(now)),
    );

    return newBalance;
  }
}
