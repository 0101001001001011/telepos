import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/user_permission_tables.dart';

/// Задача 16 (план «замок кассы», фаза 5): переворот умолчания в
/// `UserPermissionDao.getAllowedKeys`. До этой задачи пустая таблица
/// читалась как «разрешено всё», а строка `isAllowed = true` не значила
/// ничего — единственным содержательным значением был запрет. После
/// переворота пустая таблица не даёт ничего, а разрешение несёт именно
/// строка `isAllowed = true`.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  const userId = 42;

  test('пустая таблица прав → пустое множество (ничего не разрешено)', () async {
    final allowed = await db.userPermissionDao.getAllowedKeys(userId);
    expect(allowed, isEmpty);
  });

  test('строка isAllowed = true даёт право; строки false не дают', () async {
    await db
        .into(db.userPermissions)
        .insert(
          UserPermissionsCompanion.insert(
            userId: userId,
            permissionKey: PermissionKeys.navSale,
            isAllowed: const Value(true),
          ),
        );
    await db
        .into(db.userPermissions)
        .insert(
          UserPermissionsCompanion.insert(
            userId: userId,
            permissionKey: PermissionKeys.opEditPrice,
            isAllowed: const Value(false),
          ),
        );

    final allowed = await db.userPermissionDao.getAllowedKeys(userId);

    expect(allowed, {PermissionKeys.navSale});
    expect(allowed.contains(PermissionKeys.opEditPrice), isFalse);
  });

  test('только запрещающие строки, ни одной разрешающей → пустое множество', () async {
    await db.userPermissionDao.setPermission(
      userId,
      PermissionKeys.opEditPrice,
      false,
    );
    await db.userPermissionDao.setPermission(
      userId,
      PermissionKeys.opCancelPayment,
      false,
    );

    final allowed = await db.userPermissionDao.getAllowedKeys(userId);

    expect(allowed, isEmpty);
  });

  test('setPermissions на полный набор ключей → getAllowedKeys возвращает '
      'ровно разрешённые', () async {
    await db.userPermissionDao.setPermissions(userId, {
      for (final key in PermissionKeys.allPermissions)
        key: key != PermissionKeys.settingsUsers,
    });

    final allowed = await db.userPermissionDao.getAllowedKeys(userId);

    expect(
      allowed,
      PermissionKeys.allPermissions.difference({PermissionKeys.settingsUsers}),
    );
  });
}
