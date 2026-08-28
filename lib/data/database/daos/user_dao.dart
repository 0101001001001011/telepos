import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  Future<User?> findById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<int?> findLatestUserUpdateTime() {
    final expr = users.editTime.max();
    return (selectOnly(
      users,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  Future<List<User>> findActiveUsers() =>
      (select(users)..where((u) => u.status.equals('active'))).get();

  /// Активные кассиры **подпиской**.
  ///
  /// Заведённый на кассе пользователь обязан появиться на терминале в момент
  /// заведения, а не когда экран догадается перечитать список: до провода
  /// именно это и было — экран входа читал список один раз в `initialize()`.
  Stream<List<User>> watchActiveUsers() =>
      (select(users)..where((u) => u.status.equals('active'))).watch();

  Future<List<User>> findAll() => select(users).get();

  Future<bool> hasUsers() async {
    final count = await (selectOnly(users)..addColumns([users.id.count()]))
        .map((row) => row.read(users.id.count()))
        .getSingle();
    return (count ?? 0) > 0;
  }

  Future<User?> findLast() =>
      (select(users)
            ..orderBy([
              (u) => OrderingTerm.desc(u.editTime),
              (u) => OrderingTerm.desc(u.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<int> getNextId() async {
    final expr = users.id.max();
    final maxId = await (selectOnly(
      users,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
    return (maxId ?? 0) + 1;
  }

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  Future<int> createOwner({
    required String name,
    required String? passwordEnc,
  }) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return insertUser(
      UsersCompanion(
        id: Value(id),
        name: Value(name),
        role: const Value(0),
        status: const Value('active'),
        editTime: Value(now),
        passwordEnc: Value(passwordEnc),
      ),
    );
  }

  Future<int> createCashier({
    required String name,
    required String? passwordEnc,
  }) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return insertUser(
      UsersCompanion(
        id: Value(id),
        name: Value(name),
        role: const Value(3),
        status: const Value('active'),
        editTime: Value(now),
        passwordEnc: Value(passwordEnc),
      ),
    );
  }

  Future<int> updateUser(int id, UsersCompanion user) =>
      (update(users)..where((u) => u.id.equals(id))).write(user);

  Future<int> updateTelegramId(int userId, int telegramId) =>
      (update(users)..where((u) => u.id.equals(userId))).write(
        UsersCompanion(telegramId: Value(telegramId)),
      );

  Future<User?> findByTelegramId(int telegramId) => (select(
    users,
  )..where((u) => u.telegramId.equals(telegramId))).getSingleOrNull();

  Future<int> unlinkTelegram(int userId) =>
      (update(users)..where((u) => u.id.equals(userId))).write(
        const UsersCompanion(telegramId: Value(null)),
      );

  Future<int> count() {
    final expr = users.id.count();
    return (selectOnly(
      users,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<int> countByRole(int role) {
    final expr = users.id.count();
    return (selectOnly(users)
          ..addColumns([expr])
          ..where(users.role.equals(role)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countActive() {
    final expr = users.id.count();
    return (selectOnly(users)
          ..addColumns([expr])
          ..where(users.status.equals('active')))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countOwners() => countByRole(0);

  Future<int> countAdmins() => countByRole(1);

  Future<int> countCashiers() => countByRole(3);

  Future<bool> hasOwner() async {
    final c = await countOwners();
    return c > 0;
  }

  Future<UserStats> getStats() async {
    final total = await count();
    final active = await countActive();
    final owners = await countOwners();
    final admins = await countAdmins();
    final cashiers = await countCashiers();
    final withTelegram = await countWithTelegram();

    return UserStats(
      total: total,
      active: active,
      owners: owners,
      admins: admins,
      cashiers: cashiers,
      withTelegram: withTelegram,
    );
  }

  Future<int> countWithTelegram() {
    final expr = users.id.count();
    return (selectOnly(users)
          ..addColumns([expr])
          ..where(users.telegramId.isNotNull()))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

class UserStats {
  final int total;
  final int active;
  final int owners;
  final int admins;
  final int cashiers;
  final int withTelegram;

  const UserStats({
    required this.total,
    required this.active,
    required this.owners,
    required this.admins,
    required this.cashiers,
    required this.withTelegram,
  });

  @override
  String toString() =>
      'total=$total (active=$active, owners=$owners, admins=$admins, '
      'cashiers=$cashiers, withTelegram=$withTelegram)';
}
