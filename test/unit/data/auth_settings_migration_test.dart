import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

/// Миграция v31→v32: `ThisPosEntries` получает `walk_up_enabled` и
/// `session_idle_minutes` — обе настройки входа переезжают в базу, а не в
/// SharedPreferences, потому что это свойства точки, а не машины (см.
/// `app_database.dart`, блок `if (from < 32)`).
///
/// Фикстура читается с настоящей базы, а не набирается руками — тем же
/// приёмом, что и в `this_pos_migration_test.dart`, но в обратную сторону:
/// там колонки добавлялись обратно (они убирались миграцией), здесь они
/// убираются из текущей CREATE TABLE, чтобы получить форму, какая была у
/// таблицы до этой миграции.
const _walkUpEnabledColumn = 'walk_up_enabled';
const _sessionIdleMinutesColumn = 'session_idle_minutes';

Future<String> _readV31ThisPosCreateSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'DROP COLUMN $_walkUpEnabledColumn',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'DROP COLUMN $_sessionIdleMinutesColumn',
  );
  final row = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(probe.thisPosEntries.actualTableName)],
      )
      .getSingle();
  final sql = row.read<String>('sql');
  await probe.close();
  return sql;
}

/// Схема поднимается до 33 (задача 15/16), а не до 32 — открытие с
/// `user_version = 31` теперь проходит и блок `if (from < 33)`
/// (`UserPermissionDao` — задача 15), который читает `users` через
/// `userDao.findAll()`. Фикстуры этого файла никогда не заводили эту
/// таблицу — им она была не нужна ни для чего, кроме прохождения более
/// поздней, добавленной позже миграции. Без неё открытие роняется на
/// `no such table: users`, хотя настоящая база апгрейда всегда её имела
/// (`users` существовала до всех миграций, которые здесь фикстурятся).
Future<String> _readUsersCreateSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  final row = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'users'",
      )
      .getSingle();
  final sql = row.read<String>('sql');
  await probe.close();
  return sql;
}

/// `terminals` без `secret_fingerprint` — задача 4 плана «знакомство
/// терминала с кассой» добавила его миграцией v35→v36, которая трогает
/// существующую таблицу и требует, чтобы она уже была: без неё подъём этой
/// фикстуры выше v35 падает на `no such table: terminals`, хотя настоящая
/// база апгрейда таблицу имеет с v27. Тот же приём, что `_readUsersCreateSql`
/// выше, только `DROP COLUMN` вместо чтения как есть — тем же приёмом, что
/// `this_pos_migration_test.dart`.
Future<String> _readTerminalsCreateSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  await probe.customStatement(
    'ALTER TABLE ${probe.terminals.actualTableName} DROP COLUMN '
    'secret_fingerprint',
  );
  final row = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'terminals'",
      )
      .getSingle();
  final sql = row.read<String>('sql');
  await probe.close();
  return sql;
}

/// `sales` без `terminal_id`/`cart_version`/`last_command_key` — задача 2
/// плана «продажа с браузерного терминала» добавила их миграцией v36→v37,
/// которая трогает существующую таблицу и требует, чтобы она уже была: без
/// неё подъём этой фикстуры выше v36 падает на `no such table: sales`, хотя
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

/// Открывает базу, выглядящую как схема 31: таблица создана сырым SQL до
/// того, как drift возьмётся за миграции, `user_version` принудительно 31.
/// Открытие через [AppDatabase] запускает ветки `if (from < 32)` и
/// `if (from < 33)` — до итогового `schemaVersion`, не только «свою».
AppDatabase _openAsIfMigratingFromV31(
  String thisPosCreateSql,
  String usersCreateSql,
  String terminalsCreateSql,
  String salesCreateSql, {
  void Function(sqlite3.Database raw)? seed,
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(thisPosCreateSql);
        raw.execute(usersCreateSql);
        raw.execute(terminalsCreateSql);
        raw.execute(salesCreateSql);
        raw.execute('PRAGMA user_version = 31');
        if (seed != null) seed(raw);
      },
    ),
  );
}

Future<Set<String>> _columnsOf(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('фикстура v31 действительно не содержит новых колонок входа', () async {
    // Без этой проверки тест миграции ниже прошёл бы и на фикстуре, где
    // колонки были с самого начала, — то есть доказывал бы, что миграция не
    // нужна.
    final sql = await _readV31ThisPosCreateSql();
    expect(sql, isNot(contains(_walkUpEnabledColumn)));
    expect(sql, isNot(contains(_sessionIdleMinutesColumn)));
  });

  test('свежая база отдаёт настройки входа по умолчанию', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.thisPosDao.insertInitialConfig(
      companyName: 'ЖШС «Тест»',
      iinbin: null,
      cashBoxName: 'test-pos',
      countryCode: null,
      currencyCode: null,
      currencySymbol: null,
      currencyNameShort: null,
      paperWidth: null,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );

    final settings = await db.thisPosDao.authSettings();

    // Умолчание обязано быть тем, которое ничего не открывает: walk-up
    // выключен на новой установке (раздел 16 — новая установка не открывает
    // наружу ничего).
    expect(settings.walkUpEnabled, isFalse);
    expect(settings.sessionIdleMinutes, 30);
  });

  test('настройки сохраняются и читаются обратно', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.thisPosDao.insertInitialConfig(
      companyName: 'ЖШС «Тест»',
      iinbin: null,
      cashBoxName: 'test-pos',
      countryCode: null,
      currencyCode: null,
      currencySymbol: null,
      currencyNameShort: null,
      paperWidth: null,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );
    await db.thisPosDao.saveAuthSettings(
      walkUpEnabled: true,
      sessionIdleMinutes: 15,
    );

    final settings = await db.thisPosDao.authSettings();
    expect(settings.walkUpEnabled, isTrue);
    expect(settings.sessionIdleMinutes, 15);
  });

  test('схема поднялась минимум до 34 (walk-up/срок сеанса уже в схеме)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, greaterThanOrEqualTo(34));
  });

  test(
    'миграция v31→v32: обе колонки появляются с умолчаниями, старая строка цела',
    () async {
      final sql = await _readV31ThisPosCreateSql();
      final usersSql = await _readUsersCreateSql();
      final terminalsSql = await _readTerminalsCreateSql();
      final salesSql = await _readSalesCreateSql();
      final db = _openAsIfMigratingFromV31(
        sql,
        usersSql,
        terminalsSql,
        salesSql,
        seed: (raw) {
          // Строка засеяна непустыми значениями соседних полей: убрать бы
          // умела и сломанная миграция, если бы перестраивала таблицу — здесь
          // проверяется, что она этого не делает.
          raw.execute(
            'INSERT INTO this_pos_entries (r_id, cash_box_name, company_name) '
            "VALUES (1, 'Дүкен «Ысык-Көл» №2', 'ЖШС «Кассаүй»')",
          );
        },
      );
      addTearDown(db.close);

      final columns = await _columnsOf(db, db.thisPosEntries.actualTableName);
      expect(
        columns,
        contains(_walkUpEnabledColumn),
        reason: 'миграция обязана добавить колонку, а не промолчать',
      );
      expect(columns, contains(_sessionIdleMinutesColumn));

      // Умолчания легли на существующую строку без единого вопроса — это то,
      // что не даёт установке открыться настежь молча (walk-up выключен) и не
      // роняет её на отсутствующем значении (30 минут вместо NULL).
      final settings = await db.thisPosDao.authSettings();
      expect(settings.walkUpEnabled, isFalse);
      expect(settings.sessionIdleMinutes, 30);

      // Остальная строка цела — миграция не должна была задеть соседей.
      final pos = await db.thisPosDao.get();
      expect(pos, isNotNull);
      expect(pos!.cashBoxName, 'Дүкен «Ысык-Көл» №2');
      expect(pos.companyName, 'ЖШС «Кассаүй»');
    },
  );
}
