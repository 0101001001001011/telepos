import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

/// Миграция v35→v36 (задача 4 плана «знакомство терминала с кассой», шаг 2
/// спеки): `Terminals.secretFingerprint` — единственное изменение схемы.
///
/// Образец — `test/unit/data/this_pos_migration_test.dart`: фикстура строится
/// не руками, а `ALTER TABLE ... DROP COLUMN` над настоящей текущей таблицей
/// (сегодня уже несущей `secret_fingerprint`), чтобы получить настоящий вид
/// v35 — тем же инструментом (`sqlite3` 3.35+ `DROP COLUMN`), которым
/// `_safeDropColumn` пользуется в продукте, и который уже проверен смоук-тестом
/// `device_migration_test.dart._readV26Shape` как безопасный для этой сборки
/// sqlite3.
///
/// **Пункт брифа: тест на то, что миграция сделала, а не на номер версии.**
/// Проверяется: (1) фикстура v35 действительно не содержит колонку — иначе
/// тест ниже прошёл бы и без миграции вовсе; (2) после подъёма колонка
/// появляется; (3) старые строки — заведённые до миграции — получают
/// `secret_fingerprint IS NULL`, а не пустую строку и не выдуманное значение;
/// (4) остальное содержимое строки (`name`/`isSelf`/`pointMode`/`createdAt`)
/// цело.
Future<String> _readV35TerminalsCreateSql() async {
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

/// `users`/`user_permissions` не менялись между v32 и v36 — тот же приём и
/// тот же довод, что и в `permission_migration_test.dart`/
/// `security_journal_migration_test.dart`: читаются с текущей базы, нужны
/// здесь только чтобы фикстура пережила более поздние миграции по дороге
/// до `schemaVersion`, не как предмет проверки.
Future<(String usersSql, String permsSql)> _readUsersAndPermsSql() async {
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

/// Открывает базу, выглядящую как схема 35: `terminals` — фикстура без
/// секрета, `users`/`user_permissions` — с текущей базы, `user_version`
/// принудительно 35. Открытие через [AppDatabase] запускает ровно ветку
/// `if (from < 36)`, идущую последней в `onUpgrade`.
AppDatabase _openAsIfMigratingFromV35(
  String terminalsSql,
  String usersSql,
  String permsSql, {
  required void Function(sqlite3.Database raw) seed,
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(terminalsSql);
        raw.execute(usersSql);
        raw.execute(permsSql);
        raw.execute('PRAGMA user_version = 35');
        seed(raw);
      },
    ),
  );
}

Future<Set<String>> _columnsOf(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test(
    'фикстура v35 действительно не содержит secret_fingerprint — иначе тест '
    'ниже прошёл бы и без миграции',
    () async {
      final terminalsSql = await _readV35TerminalsCreateSql();
      expect(terminalsSql, isNot(contains('secret_fingerprint')));

      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.dispose);
      raw.execute(terminalsSql);
      final columns = raw
          .select('PRAGMA table_info(terminals)')
          .map((row) => row['name'] as String)
          .toSet();
      expect(columns, isNot(contains('secret_fingerprint')));
      expect(
        columns,
        containsAll(['id', 'name', 'is_self', 'point_mode', 'created_at']),
        reason: 'соседние колонки на месте — иначе проверка выше проходила '
            'бы и на пустом наборе имён',
      );
    },
  );

  test('свежая база: secret_fingerprint есть с самого начала', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final columns = await _columnsOf(db, db.terminals.actualTableName);
    expect(columns, contains('secret_fingerprint'));
  });

  test(
    'подъём с v35: secret_fingerprint появляется, строки, заведённые до '
    'миграции, остаются NULL — секрета у них нет и придумывать его миграция '
    'не имеет права',
    () async {
      final terminalsSql = await _readV35TerminalsCreateSql();
      final (usersSql, permsSql) = await _readUsersAndPermsSql();
      const oldTerminalId = 1;
      const oldTerminalName = 'Касса «Ысык-Көл» №2';
      const createdAt = 1_700_000_000;

      final db = _openAsIfMigratingFromV35(
        terminalsSql,
        usersSql,
        permsSql,
        seed: (raw) {
          // Непустые, настоящие значения — чтобы «остальная строка цела»
          // проверялось содержимым, а не фактом существования строки.
          raw.execute(
            'INSERT INTO terminals (id, name, is_self, point_mode, '
            'created_at) VALUES ($oldTerminalId, ?, 1, ?, $createdAt)',
            [oldTerminalName, 'cashier'],
          );
        },
      );
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(36),
        reason: 'эта правка добавила миграцию v35→v36',
      );

      final columns = await _columnsOf(db, db.terminals.actualTableName);
      expect(
        columns,
        contains('secret_fingerprint'),
        reason: 'миграция обязана дописать колонку, а не только поднять '
            'user_version',
      );

      final row = await db.terminalDao.findById(oldTerminalId);
      expect(row, isNotNull, reason: 'строка не должна пропасть вместе с миграцией');
      expect(
        row!.secretFingerprint,
        isNull,
        reason:
            'строка заведена ДО появления секрета — придумать ей секрет '
            'задним числом значило бы либо соврать о том, что терминал его '
            'получал, либо разослать секрет терминалу, который его не '
            'просил; правильный ответ — отсутствие, не пустая строка и не '
            'сгенерированное значение',
      );
      // Остальная строка цела — не только «не упала», а именно те же
      // значения, что были засеяны.
      expect(row.name, oldTerminalName);
      expect(row.isSelf, isTrue);
      expect(row.pointMode, 'cashier');
      expect(row.createdAt, createdAt);
    },
  );

  test(
    'повторная миграция на уже добавленной колонке не падает',
    () async {
      // `_safeAddColumn` глотает «duplicate column name» намеренно:
      // установка, прошедшая v36 и открытая заново (или откатившаяся к
      // прежней сборке и поднятая снова), придёт сюда второй раз.
      final probe = AppDatabase(NativeDatabase.memory());
      final row = await probe
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [
              Variable.withString(probe.terminals.actualTableName),
            ],
          )
          .getSingle();
      final currentTerminalsSql = row.read<String>('sql');
      final (usersSql, permsSql) = await _readUsersAndPermsSql();
      await probe.close();

      final db = _openAsIfMigratingFromV35(
        currentTerminalsSql,
        usersSql,
        permsSql,
        seed: (_) {},
      );
      addTearDown(db.close);

      final columns = await _columnsOf(db, db.terminals.actualTableName);
      expect(columns, contains('secret_fingerprint'));
      expect(columns, contains('name'));
    },
  );
}
