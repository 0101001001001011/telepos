import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';

/// Миграция v32→v33 (план «замок кассы», фаза 5, задача 15). Схема не
/// меняется ни на одну колонку — эта миграция трогает только данные. Она
/// пишет каждому существующему пользователю ровно то, что у него действует
/// **сегодня** (полный набор ключей минус его нынешние запреты), явными
/// строками в `user_permissions`, чтобы переворот умолчания в задаче 16
/// (`UserPermissionDao.getAllowedKeys`: сегодня пустая строка = разрешено,
/// после — пустая строка = запрещено) не изменил ничьё поведение.
///
/// # Правка Б-1 закрытия долга безопасности (2026-08-22): развилка снята
///
/// До этой правки здесь была развилка «есть хотя бы одна разрешающая строка
/// → новая модель (задача 13), не трогать». Она была неверна: признак
/// `existingRows.any((row) => row.isAllowed)` молча предполагал, что раз
/// есть хоть одна разрешающая строка, набор строк ПОЛОН относительно
/// нынешнего словаря — а форма редактирования пишет строки ключей ТОГО
/// билда, в котором её открыли, так что это не гарантировано. Хуже: сама
/// причина, ради которой развилку заводили, — популяция строк по ролям
/// мастером после задачи 13 — в поле НЕ СУЩЕСТВУЕТ: мастер и форма пишут
/// строки задачи 13 в ЭТОЙ ЖЕ невыпущенной ветке, что и эта миграция, — ни
/// одна база, реально мигрирующая версией, не могла получить строки нового
/// вида. Правило теперь без развилки: для каждого не-владельца, на каждый
/// ключ словаря — если строки нет, записать «разрешено» (старое эффективное
/// значение недостающего ключа); если строка уже есть — не трогать.
///
/// `users`/`user_permissions` не менялись ни одной миграцией схемы, поэтому
/// их `CREATE TABLE` читается с текущей (= v32-и-v33-одновременно) базы без
/// обратных `ALTER TABLE ADD/DROP COLUMN`, в отличие от
/// `auth_settings_migration_test.dart`/`this_pos_migration_test.dart`, где
/// сама схема таблицы менялась.
Future<(String usersSql, String permsSql)> _readV32TableSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  final rows = await probe
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table' "
        "AND name IN ('users', 'user_permissions')",
      )
      .get();
  final byName = {
    for (final row in rows) row.read<String>('name'): row.read<String>('sql'),
  };
  await probe.close();
  return (byName['users']!, byName['user_permissions']!);
}

/// `terminals` в форме, какую оно имело между схемой v27 (семь сырых
/// колонок устройства удалены — `terminal_tables.dart`) и v35 (до задачи 4
/// плана «знакомство терминала с кассой»), — тот же диапазон, в котором
/// живут все фикстуры этого файла (v32/v34). Читается с настоящей базы через
/// `DROP COLUMN`, тем же приёмом, что `this_pos_migration_test.dart`.
///
/// Нужно этому файлу не само по себе — только чтобы фикстуры пережили
/// миграцию v35→v36 (`app_database.dart`, `if (from < 36)`), которая трогает
/// `terminals` первой из всех миграций в диапазоне между v27 и v36:
/// фикстуры этого файла никогда не заводили эту таблицу, и без неё подъём
/// падает на `no such table: terminals`, хотя настоящая база апгрейда
/// таблицу terminals имеет с v27.
Future<String> _readTerminalsCreateSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  await probe.customStatement(
    'ALTER TABLE ${probe.terminals.actualTableName} DROP COLUMN '
    'secret_fingerprint',
  );
  final row = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(probe.terminals.actualTableName)],
      )
      .getSingle();
  final sql = row.read<String>('sql');
  await probe.close();
  return sql;
}

/// `sales` без `terminal_id`/`cart_version`/`last_command_key` — задача 2
/// плана «продажа с браузерного терминала» добавила их миграцией v36→v37,
/// которая трогает существующую таблицу и требует, чтобы она уже была: без
/// неё подъём фикстур этого файла падает на `no such table: sales`, хотя
/// настоящая база апгрейда таблицу `sales` имеет с самой первой схемы. Тот
/// же приём, что `_readTerminalsCreateSql` выше.
Future<String> _readSalesCreateSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  await probe.customStatement(
    'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN terminal_id',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN cart_version',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN last_command_key',
  );
  final row = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'sales'",
      )
      .getSingle();
  final sql = row.read<String>('sql');
  await probe.close();
  return sql;
}

/// Открывает базу, выглядящую как схема 32: обе таблицы созданы сырым SQL до
/// того, как drift возьмётся за миграции, `user_version` принудительно 32.
/// Открытие через [AppDatabase] запускает ровно ветку `if (from < 33)` — и,
/// как и всё в этом файле после задачи 4 плана «знакомство терминала с
/// кассой», доходит и до `if (from < 36)`.
AppDatabase _openAsIfMigratingFromV32(
  String usersSql,
  String permsSql,
  String terminalsSql,
  String salesSql, {
  required void Function(sqlite3.Database raw) seed,
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(usersSql);
        raw.execute(permsSql);
        raw.execute(terminalsSql);
        raw.execute(salesSql);
        raw.execute('PRAGMA user_version = 32');
        seed(raw);
      },
    ),
  );
}

Future<Set<String>> _permissionKeysOf(
  AppDatabase db,
  int userId, {
  required bool allowed,
}) async {
  final rows = await db.userPermissionDao.findByUserId(userId);
  return rows
      .where((r) => r.isAllowed == allowed)
      .map((r) => r.permissionKey)
      .toSet();
}

void main() {
  test('фикстура v32 действительно не содержит строк прав', () async {
    // Без этой проверки тесты ниже прошли бы и на фикстуре, где строки были
    // с самого начала, — то есть доказывали бы, что миграция не нужна.
    final (usersSql, permsSql) = await _readV32TableSql();
    final terminalsSql = await _readTerminalsCreateSql();
    final salesSql = await _readSalesCreateSql();
    expect(usersSql, contains('CREATE TABLE'));
    expect(permsSql, contains('CREATE TABLE'));

    final db = _openAsIfMigratingFromV32(
      usersSql,
      permsSql,
      terminalsSql,
      salesSql,
      seed: (raw) {
        raw.execute('PRAGMA user_version = 33'); // не мигрировать здесь
      },
    );
    addTearDown(db.close);
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM user_permissions')
        .getSingle();
    expect(count.read<int>('c'), 0);
  });

  test('схема поднялась минимум до 35 (правка «второй порядок» добавила '
      'миграцию v34→v35)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, greaterThanOrEqualTo(35));
  });

  test('Шаг 1: пользователь без строк прав → после миграции строки на все '
      'ключи, все разрешены', () async {
    final (usersSql, permsSql) = await _readV32TableSql();
    final terminalsSql = await _readTerminalsCreateSql();
    final salesSql = await _readSalesCreateSql();
    const cashierId = 7;
    final db = _openAsIfMigratingFromV32(
      usersSql,
      permsSql,
      terminalsSql,
      salesSql,
      seed: (raw) {
        raw.execute(
          'INSERT INTO users (id, name, role, status, edit_time) '
          "VALUES ($cashierId, 'Кассир Аружан', 3, 'active', 1000)",
        );
        // Ни одной строки в user_permissions для этого пользователя —
        // старая модель, пустая таблица читалась как «разрешено всё».
      },
    );
    addTearDown(db.close);

    final rows = await db.userPermissionDao.findByUserId(cashierId);
    final byKey = {for (final r in rows) r.permissionKey: r.isAllowed};

    expect(
      byKey.keys.toSet(),
      PermissionKeys.allPermissions,
      reason: 'миграция обязана дописать строку на каждый существующий ключ',
    );
    expect(
      byKey.values.every((allowed) => allowed),
      isTrue,
      reason:
          'без единого запрета «сегодня» всё было разрешено — и должно '
          'остаться разрешено явными строками',
    );

    // Тот же результат подтверждается и через реальный путь чтения прав.
    final allowed = await db.userPermissionDao.getAllowedKeys(cashierId);
    expect(allowed, PermissionKeys.allPermissions);
  });

  test('Шаг 2: пользователь с двумя запретами → после миграции ровно те же '
      'два запрещены, остальные разрешены', () async {
    final (usersSql, permsSql) = await _readV32TableSql();
    final terminalsSql = await _readTerminalsCreateSql();
    final salesSql = await _readSalesCreateSql();
    const cashierId = 11;
    final deniedKeys = {
      PermissionKeys.opEditPrice,
      PermissionKeys.opCancelPayment,
    };
    final db = _openAsIfMigratingFromV32(
      usersSql,
      permsSql,
      terminalsSql,
      salesSql,
      seed: (raw) {
        raw.execute(
          'INSERT INTO users (id, name, role, status, edit_time) '
          "VALUES ($cashierId, 'Кассир Данияр', 3, 'active', 1000)",
        );
        for (final key in deniedKeys) {
          raw.execute(
            'INSERT INTO user_permissions (user_id, permission_key, is_allowed) '
            "VALUES ($cashierId, '$key', 0)",
          );
        }
      },
    );
    addTearDown(db.close);

    final rows = await db.userPermissionDao.findByUserId(cashierId);
    expect(
      rows.length,
      PermissionKeys.allPermissions.length,
      reason:
          'после миграции у пользователя должна быть строка на каждый '
          'ключ — ни одной недостающей, ни одной лишней',
    );

    final denied = await _permissionKeysOf(db, cashierId, allowed: false);
    final allowed = await _permissionKeysOf(db, cashierId, allowed: true);

    expect(
      denied,
      deniedKeys,
      reason:
          'ровно те же два ключа запрещены — миграция не должна была '
          'ни снять, ни добавить запрет',
    );
    expect(
      allowed,
      PermissionKeys.allPermissions.difference(deniedKeys),
      reason:
          'все ключи, кроме двух запрещённых, обязаны стать явно '
          'разрешёнными',
    );

    // И тот же результат читается обратно через реальный путь.
    final effectivelyAllowed = await db.userPermissionDao.getAllowedKeys(
      cashierId,
    );
    expect(
      effectivelyAllowed,
      PermissionKeys.allPermissions.difference(deniedKeys),
    );
  });

  test('Шаг 2б (правка Б-1): пользователь с ЧАСТИЧНЫМ набором разрешающих '
      'строк — миграция дописывает недостающие ключи как разрешённые, '
      'существующие не трогает', () async {
    final (usersSql, permsSql) = await _readV32TableSql();
    final terminalsSql = await _readTerminalsCreateSql();
    final salesSql = await _readSalesCreateSql();
    const cashierId = 13;
    // До правки Б-1 этот сценарий описывался как «заведён мастером после
    // задачи 13» и ожидал, что миграция ничего не допишет — но такой
    // пользователь не может существовать в реально мигрирующей базе (задача
    // 13 — в этой же невыпущенной ветке, см. докстринг файла и блока
    // `if (from < 33)`). Сценарий оставлен — три строки без остальных 28 —
    // потому что он честно проверяет НОВОЕ правило на частичном наборе, а не
    // потому что он всё ещё описывает мастера: старое правило («есть хотя
    // бы одна разрешающая строка — не трогать») стёрло бы недостающие 28
    // ключей молча; новое дописывает их как разрешённые, а три существующие
    // оставляет как есть.
    const preExistingKeys = {
      PermissionKeys.navSale,
      PermissionKeys.navShift,
      PermissionKeys.opSellDiscount,
    };
    final db = _openAsIfMigratingFromV32(
      usersSql,
      permsSql,
      terminalsSql,
      salesSql,
      seed: (raw) {
        raw.execute(
          'INSERT INTO users (id, name, role, status, edit_time) '
          "VALUES ($cashierId, 'Кассир Ерлан', 3, 'active', 1000)",
        );
        for (final key in preExistingKeys) {
          raw.execute(
            'INSERT INTO user_permissions (user_id, permission_key, is_allowed) '
            "VALUES ($cashierId, '$key', 1)",
          );
        }
      },
    );
    addTearDown(db.close);

    final rows = await db.userPermissionDao.findByUserId(cashierId);
    final byKey = {for (final r in rows) r.permissionKey: r.isAllowed};

    expect(
      byKey.keys.toSet(),
      PermissionKeys.allPermissions,
      reason:
          'миграция обязана дописать строку на каждый ключ, которого не '
          'было — старое правило «есть хоть одна разрешающая строка, не '
          'трогать» молча теряло бы 28 недостающих ключей',
    );
    expect(
      byKey.values.every((allowed) => allowed),
      isTrue,
      reason:
          'и дописанные, и три исходные строки — все разрешены: исходные '
          'были разрешены и до миграции, недостающие получают старое '
          'эффективное значение отсутствующей строки (разрешено)',
    );
    expect(
      rows.length,
      PermissionKeys.allPermissions.length,
      reason: 'ни одной лишней строки — ровно по одной на каждый ключ',
    );

    // И тот же результат читается обратно через реальный путь.
    final allowed = await db.userPermissionDao.getAllowedKeys(cashierId);
    expect(allowed, PermissionKeys.allPermissions);
  });

  test('Шаг 4 (правка «второй порядок», пункт 1): администратор на v34 '
      '(allow-list уже перевёрнут задачей 16) получает три новых ключа по '
      'умолчанию роли, кассир — не получает ни одного', () async {
    // В отличие от «Шаг 1–2б» выше (миграция от v32, где ещё действует
    // блок `if (from < 33)`, который пишет «разрешено» на ЛЮБОЙ недостающий
    // ключ), здесь база уже на v34 — allow-list уже действует
    // (getAllowedKeys: отсутствие строки = отказ), и ровно эта миграция
    // (`if (from < 35)`) — единственная, что вообще что-то дописывает.
    // Красный прогон для пункта 1 брифа: без блока `if (from < 35)` (см.
    // `git stash` в отчёте) администратор читал бы три новых ключа как
    // отказ, хотя `roleDefaults[administrator]` их даёт.
    final (usersSql, permsSql) = await _readV32TableSql();
    final terminalsSql = await _readTerminalsCreateSql();
    final salesSql = await _readSalesCreateSql();
    const adminId = 21;
    const cashierId = 22;

    // Старые ключи словаря (всё, кроме трёх новых этой правки) — то, что
    // уже должно быть записано строками на реальной базе v34, прошедшей
    // задачи 15/16.
    final oldKeys = PermissionKeys.allPermissions.difference({
      PermissionKeys.settingsTerminalService,
      PermissionKeys.settingsLogJournal,
      PermissionKeys.settingsAppliance,
    });

    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(usersSql);
          raw.execute(permsSql);
          raw.execute(terminalsSql);
          raw.execute(salesSql);
          raw.execute(
            'INSERT INTO users (id, name, role, status, edit_time) '
            "VALUES ($adminId, 'Администратор Гульнара', 1, 'active', 1000)",
          );
          raw.execute(
            'INSERT INTO users (id, name, role, status, edit_time) '
            "VALUES ($cashierId, 'Кассир Тимур', 3, 'active', 1000)",
          );
          for (final userId in [adminId, cashierId]) {
            for (final key in oldKeys) {
              // Администратору — все старые ключи, кроме settings.users
              // (roleDefaults уже исключает его сегодня); кассиру — только
              // его узкий набор. Точное соответствие ролям здесь не
              // проверяется — важно только, что строки на ТРИ НОВЫХ ключа
              // нет ни у кого до миграции.
              raw.execute(
                'INSERT INTO user_permissions '
                '(user_id, permission_key, is_allowed) '
                "VALUES ($userId, '$key', 1)",
              );
            }
          }
          raw.execute('PRAGMA user_version = 34');
        },
      ),
    );
    addTearDown(db.close);

    final adminAllowed = await db.userPermissionDao.getAllowedKeys(adminId);
    final cashierAllowed = await db.userPermissionDao.getAllowedKeys(
      cashierId,
    );

    expect(
      adminAllowed,
      containsAll({
        PermissionKeys.settingsTerminalService,
        PermissionKeys.settingsLogJournal,
        PermissionKeys.settingsAppliance,
      }),
      reason:
          'администратор вычисляется как allPermissions минус '
          'settings.users (PermissionKeys.roleDefaults) — три новых ключа '
          'обязаны попасть в его allow-list этой миграцией',
    );
    expect(
      cashierAllowed.intersection({
        PermissionKeys.settingsTerminalService,
        PermissionKeys.settingsLogJournal,
        PermissionKeys.settingsAppliance,
      }),
      isEmpty,
      reason:
          'кассир (UserRole.cashier) не держит ни одного settings.*-ключа '
          'в roleDefaults — миграция не обязана и не должна писать строку '
          'на ключ, которого роль не даёт: allow-list читает отсутствие '
          'строки как отказ, и это верный отказ, а не пробел',
    );
  });

  test('Шаг 3: owner после миграции не потерял ничего — его строки в '
      'user_permissions вообще не тронуты', () async {
    final (usersSql, permsSql) = await _readV32TableSql();
    final terminalsSql = await _readTerminalsCreateSql();
    final salesSql = await _readSalesCreateSql();
    const ownerId = 1;
    final db = _openAsIfMigratingFromV32(
      usersSql,
      permsSql,
      terminalsSql,
      salesSql,
      seed: (raw) {
        raw.execute(
          'INSERT INTO users (id, name, role, status, edit_time) '
          "VALUES ($ownerId, 'Владелец', 0, 'active', 1000)",
        );
        // Заведомо странная строка на владельце — если бы миграция читала
        // роль неправильно, эта строка либо исчезла бы, либо обросла бы
        // соседями. `LocalAuthRepository._issue` владельца всё равно не
        // читает эту таблицу вовсе, но миграция обязана его не трогать.
        raw.execute(
          'INSERT INTO user_permissions (user_id, permission_key, is_allowed) '
          "VALUES ($ownerId, '${PermissionKeys.opEditPrice}', 0)",
        );
      },
    );
    addTearDown(db.close);

    final rows = await db.userPermissionDao.findByUserId(ownerId);
    expect(
      rows.length,
      1,
      reason:
          'ровно та единственная строка, что была до миграции — ни '
          'одной новой, ни одной удалённой',
    );
    expect(rows.single.permissionKey, PermissionKeys.opEditPrice);
    expect(rows.single.isAllowed, isFalse);
  });
}
