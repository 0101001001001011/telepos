import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/user_permission_tables.dart';

part 'user_permission_dao.g.dart';

@DriftAccessor(tables: [UserPermissions])
class UserPermissionDao extends DatabaseAccessor<AppDatabase>
    with _$UserPermissionDaoMixin {
  UserPermissionDao(super.db);

  Future<List<UserPermission>> findByUserId(int userId) =>
      (select(userPermissions)..where((p) => p.userId.equals(userId))).get();

  Future<Set<String>> getAllowedKeys(int userId) async {
    final rows = await findByUserId(userId);

    final result = <String>{};
    for (final row in rows) {
      if (row.isAllowed) {
        result.add(row.permissionKey);
      }
    }
    return result;
  }

  Future<void> setPermission(int userId, String key, bool isAllowed) async {
    final existing =
        await (select(userPermissions)..where(
              (p) => p.userId.equals(userId) & p.permissionKey.equals(key),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (update(userPermissions)..where((p) => p.id.equals(existing.id)))
          .write(UserPermissionsCompanion(isAllowed: Value(isAllowed)));
    } else {
      await into(userPermissions).insert(
        UserPermissionsCompanion(
          userId: Value(userId),
          permissionKey: Value(key),
          isAllowed: Value(isAllowed),
        ),
      );
    }
  }

  Future<void> setPermissions(int userId, Map<String, bool> permissions) {
    return transaction(() async {
      for (final entry in permissions.entries) {
        await setPermission(userId, entry.key, entry.value);
      }
    });
  }

  Future<int> deleteByUserId(int userId) =>
      (delete(userPermissions)..where((p) => p.userId.equals(userId))).go();
}
