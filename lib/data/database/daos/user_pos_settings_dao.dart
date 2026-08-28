import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';

part 'user_pos_settings_dao.g.dart';

@DriftAccessor(tables: [UserPosSettings, Users])
class UserPosSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$UserPosSettingsDaoMixin {
  UserPosSettingsDao(super.db);

  Future<UserPosSetting?> findForUser(int userId, String posKey) =>
      (select(userPosSettings)
            ..where((s) => s.userId.equals(userId) & s.posKey.equals(posKey)))
          .getSingleOrNull();

  Future<List<UserPosSetting>> findAllForPos(String posKey) =>
      (select(userPosSettings)..where((s) => s.posKey.equals(posKey))).get();

  Future<UserPosSetting?> findDefaultUser(String posKey) =>
      (select(userPosSettings)
            ..where((s) => s.posKey.equals(posKey) & s.isDefault.equals(true)))
          .getSingleOrNull();

  Future<List<UserWithPosSettings>> findUsersWithSettings(
    String posKey, {
    bool? activeOnly,
    int limit = 100,
  }) async {
    var query = select(users).join([
      leftOuterJoin(
        userPosSettings,
        userPosSettings.userId.equalsExp(users.id) &
            userPosSettings.posKey.equals(posKey),
      ),
    ]);

    if (activeOnly == true) {
      query = query..where(users.status.equals('active'));
    }

    query = query
      ..orderBy([
        OrderingTerm.desc(userPosSettings.isDefault),
        OrderingTerm.desc(userPosSettings.lastLoginAt),
        OrderingTerm.asc(users.name),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows.map((row) {
      return UserWithPosSettings(
        user: row.readTable(users),
        posSettings: row.readTableOrNull(userPosSettings),
      );
    }).toList();
  }

  Future<int> upsert(UserPosSettingsCompanion settings) async {
    final existing = await findForUser(
      settings.userId.value,
      settings.posKey.value,
    );

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (existing != null) {
      return (update(userPosSettings)..where((s) => s.id.equals(existing.id)))
          .write(settings.copyWith(updatedAt: Value(now)));
    } else {
      return into(
        userPosSettings,
      ).insert(settings.copyWith(createdAt: Value(now), updatedAt: Value(now)));
    }
  }

  Future<void> recordLogin(int userId, String posKey) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final existing = await findForUser(userId, posKey);

    if (existing != null) {
      await (update(
        userPosSettings,
      )..where((s) => s.id.equals(existing.id))).write(
        UserPosSettingsCompanion(
          lastLoginAt: Value(now),
          loginCount: Value(existing.loginCount + 1),
          updatedAt: Value(now),
        ),
      );
    } else {
      await into(userPosSettings).insert(
        UserPosSettingsCompanion(
          userId: Value(userId),
          posKey: Value(posKey),
          lastLoginAt: Value(now),
          loginCount: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> setDefaultUser(int userId, String posKey) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await (update(userPosSettings)..where((s) => s.posKey.equals(posKey)))
        .write(const UserPosSettingsCompanion(isDefault: Value(false)));

    final existing = await findForUser(userId, posKey);
    if (existing != null) {
      await (update(
        userPosSettings,
      )..where((s) => s.id.equals(existing.id))).write(
        UserPosSettingsCompanion(
          isDefault: const Value(true),
          updatedAt: Value(now),
        ),
      );
    } else {
      await into(userPosSettings).insert(
        UserPosSettingsCompanion(
          userId: Value(userId),
          posKey: Value(posKey),
          isDefault: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> blockUserOnPos(int userId, String posKey) async {
    await upsert(
      UserPosSettingsCompanion(
        userId: Value(userId),
        posKey: Value(posKey),
        isAllowedOnThisPos: const Value(false),
      ),
    );
  }

  Future<void> unblockUserOnPos(int userId, String posKey) async {
    await upsert(
      UserPosSettingsCompanion(
        userId: Value(userId),
        posKey: Value(posKey),
        isAllowedOnThisPos: const Value(true),
      ),
    );
  }

  Future<int> deleteAllForPos(String posKey) =>
      (delete(userPosSettings)..where((s) => s.posKey.equals(posKey))).go();

  Future<int> countForPos(String posKey) {
    final expr = userPosSettings.id.count();
    return (selectOnly(userPosSettings)
          ..addColumns([expr])
          ..where(userPosSettings.posKey.equals(posKey)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

class UserWithPosSettings {
  final User user;
  final UserPosSetting? posSettings;

  const UserWithPosSettings({required this.user, this.posSettings});

  int get userId => user.id;

  String? get name => user.name;

  int? get globalRole => user.role;

  int? get effectiveRole => posSettings?.localRoleOverride ?? user.role;

  bool get isOwner => effectiveRole == 0;

  bool get isAdmin => effectiveRole == 0 || effectiveRole == 1;

  bool get isCashier => effectiveRole == 3;

  bool get isActive => user.status == 'active';

  bool get isAllowedOnThisPos => posSettings?.isAllowedOnThisPos ?? true;

  bool get canLogin => isActive && isAllowedOnThisPos;

  bool get isDefault => posSettings?.isDefault ?? false;

  DateTime? get lastLoginAt => posSettings?.lastLoginAt != null
      ? DateTime.fromMillisecondsSinceEpoch(posSettings!.lastLoginAt! * 1000)
      : null;

  int get loginCount => posSettings?.loginCount ?? 0;

  bool get hasPosSettings => posSettings != null;
}
