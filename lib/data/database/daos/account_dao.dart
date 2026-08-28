import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';

part 'account_dao.g.dart';

abstract class AccountType {
  static const int pos = 0;
  static const int customBank = 1;
  static const int customCash = 2;
  static const int agentMain = 3;
  static const int agentCashback = 4;
  static const int teleposMain = 5;
  static const int teleposBonus = 6;
  static const int cashback = 7;
}

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<Account?> findById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<List<Account>> findAll() => select(accounts).get();

  Future<List<Account>> findByTypeAndVisibility(int type, bool visibleToPos) =>
      customSelect(
        'SELECT * FROM accounts a WHERE a.type = ? AND a.visible_to_pos = ? '
        'AND (a.acquirer_id IS NULL OR a.id = (SELECT p.acquiring_account_id FROM this_pos_entries p LIMIT 1))',
        variables: [Variable.withInt(type), Variable.withBool(visibleToPos)],
        readsFrom: {accounts},
      ).get().then(
        (_) =>
            (select(accounts)..where(
                  (a) =>
                      a.type.equals(type) & a.visibleToPos.equals(visibleToPos),
                ))
                .get(),
      );

  Future<List<Account>> findByType(int type) =>
      (select(accounts)..where((a) => a.type.equals(type))).get();

  Future<Account?> findLastPosAccount() =>
      (select(accounts)
            ..where((a) => a.type.isIn([0, 1, 7]))
            ..orderBy([
              (a) => OrderingTerm.desc(a.updateTime),
              (a) => OrderingTerm.desc(a.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<int> updateBalance(int id, Decimal newBalance) =>
      (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(value: Value(newBalance)),
      );

  Future<Account?> findInkassaciyaDestination({int? excludeId}) async {
    for (final type in const [AccountType.customBank, AccountType.customCash]) {
      final candidates = await (select(
        accounts,
      )..where((a) => a.type.equals(type))).get();
      for (final acc in candidates) {
        if (acc.id != excludeId) return acc;
      }
    }
    return null;
  }

  Future<void> transfer({
    required int fromId,
    required int toId,
    required Decimal amount,
  }) async {
    final from = await findById(fromId);
    if (from == null) {
      throw Exception('Счёт-источник не найден: $fromId');
    }
    final to = await findById(toId);
    if (to == null) {
      throw Exception('Счёт-назначение не найден: $toId');
    }

    final fromBalance = from.value ?? Decimal.zero;
    if (fromBalance < amount) {
      throw Exception(
        'Недостаточно средств для перевода. Баланс: $fromBalance, запрошено: $amount',
      );
    }
    final toBalance = to.value ?? Decimal.zero;

    await updateBalance(fromId, fromBalance - amount);
    await updateBalance(toId, toBalance + amount);
  }

  Future<int> getNextId() async {
    final expr = accounts.id.max();
    final maxId = await (selectOnly(
      accounts,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
    return (maxId ?? 0) + 1;
  }

  Future<int> insertAccount(AccountsCompanion account) =>
      into(accounts).insert(account);

  Future<int> createPosAccount({required String name}) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: const Value(AccountType.pos),
        name: Value(name),
        value: Value(Decimal.zero),
        visibleToPos: const Value(true),
        updateTime: Value(now),
      ),
    );

    return id;
  }

  Future<int> createTeleposMainAccount({required String name}) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: const Value(AccountType.teleposMain),
        name: Value(name),
        value: Value(Decimal.zero),
        visibleToPos: const Value(true),
        updateTime: Value(now),
      ),
    );

    return id;
  }

  Future<int> createAcquiringAccount({
    required String name,
    required int acquirerId,
  }) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: const Value(AccountType.customBank),
        acquirerId: Value(acquirerId),
        name: Value(name),
        value: Value(Decimal.zero),
        visibleToPos: const Value(true),
        updateTime: Value(now),
      ),
    );

    return id;
  }

  Future<int> count() {
    final expr = accounts.id.count();
    return (selectOnly(
      accounts,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<int> countByType(int type) {
    final expr = accounts.id.count();
    return (selectOnly(accounts)
          ..addColumns([expr])
          ..where(accounts.type.equals(type)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countPosAccounts() {
    final expr = accounts.id.count();
    return (selectOnly(accounts)
          ..addColumns([expr])
          ..where(
            accounts.type.isIn([
              AccountType.pos,
              AccountType.customBank,
              AccountType.customCash,
              AccountType.cashback,
            ]),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countVisibleToPos() {
    final expr = accounts.id.count();
    return (selectOnly(accounts)
          ..addColumns([expr])
          ..where(accounts.visibleToPos.equals(true)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<bool> hasAny() async {
    final c = await count();
    return c > 0;
  }

  Future<bool> hasPosAccount() async {
    final c = await countByType(AccountType.pos);
    return c > 0;
  }

  Future<AccountStats> getStats() async {
    final total = await count();
    final pos = await countByType(AccountType.pos);
    final bank = await countByType(AccountType.customBank);
    final cash = await countByType(AccountType.customCash);
    final agentMain = await countByType(AccountType.agentMain);
    final agentCashback = await countByType(AccountType.agentCashback);
    final teleposMain = await countByType(AccountType.teleposMain);
    final visible = await countVisibleToPos();

    return AccountStats(
      total: total,
      posAccounts: pos,
      bankAccounts: bank,
      cashAccounts: cash,
      agentMainAccounts: agentMain,
      agentCashbackAccounts: agentCashback,
      teleposMainAccounts: teleposMain,
      visibleToPos: visible,
    );
  }
}

class AccountStats {
  final int total;
  final int posAccounts;
  final int bankAccounts;
  final int cashAccounts;
  final int agentMainAccounts;
  final int agentCashbackAccounts;
  final int teleposMainAccounts;
  final int visibleToPos;

  const AccountStats({
    required this.total,
    required this.posAccounts,
    required this.bankAccounts,
    required this.cashAccounts,
    required this.agentMainAccounts,
    required this.agentCashbackAccounts,
    required this.teleposMainAccounts,
    required this.visibleToPos,
  });

  @override
  String toString() =>
      'total=$total (POS=$posAccounts, bank=$bankAccounts, cash=$cashAccounts, '
      'agentMain=$agentMainAccounts, agentCB=$agentCashbackAccounts, '
      'teleposMain=$teleposMainAccounts), visible=$visibleToPos';
}
