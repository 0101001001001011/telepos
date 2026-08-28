import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/security_event_dao.dart';

/// Пункт 7 финальной волны закрытия долга безопасности (2026-08-22):
/// миграция v33→v34 (`if (from < 34)` в `app_database.dart`, заводящая
/// `security_events`) не имела теста на то, что она на самом деле делает —
/// единственное утверждение до этой правки было про номер версии на базе,
/// созданной через `onCreate` (`AppDatabase.forTesting`), а не через
/// подъём с более старой версии. Образец —
/// `test/unit/data/permission_migration_test.dart`: открыть базу, реально
/// выглядящую как более старая схема, и поднять её через `AppDatabase`,
/// чтобы прошла настоящая ветка `onUpgrade`, а не `onCreate`.
///
/// `users`/`user_permissions` читаются тем же приёмом, что и в
/// `permission_migration_test.dart` (`_readV32TableSql`): обе таблицы не
/// менялись ни одной миграцией схемы между v32 и v35, значит их `CREATE
/// TABLE` с текущей базы годится и для фикстуры v33.
Future<(String usersSql, String permsSql)> _readV33TableSql() async {
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

/// `terminals` без `secret_fingerprint` — задача 4 плана «знакомство
/// терминала с кассой» добавила его миграцией v35→v36, которая (в отличие
/// от `security_events`, v33→v34) трогает существующую таблицу и требует,
/// чтобы она уже была: без неё подъём этой фикстуры выше v35 падает на
/// `no such table: terminals`, хотя настоящая база апгрейда таблицу имеет
/// с v27.
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

void main() {
  test(
    'фикстура v33 действительно не содержит security_events — иначе тест '
    'ниже прошёл бы и без миграции',
    () async {
      final (usersSql, permsSql) = await _readV33TableSql();
      // Сырое соединение sqlite3, в обход drift/AppDatabase: миграция
      // должна не успеть отработать, чтобы проверить именно исходное
      // состояние фикстуры.
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.dispose);
      raw.execute(usersSql);
      raw.execute(permsSql);

      final tables = raw.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'security_events'",
      );
      expect(tables, isEmpty);
    },
  );

  test(
    'подъём с v33: security_events появляется миграцией и пишет строку — '
    'не только номер версии на onCreate-базе',
    () async {
      final (usersSql, permsSql) = await _readV33TableSql();
      final terminalsSql = await _readTerminalsCreateSql();
      const terminalId = 1;
      const userId = 5;

      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(usersSql);
            raw.execute(permsSql);
            raw.execute(terminalsSql);
            raw.execute(
              'INSERT INTO users (id, name, role, status, edit_time) '
              "VALUES ($userId, 'Кассир Алия', 3, 'active', 1000)",
            );
            raw.execute('PRAGMA user_version = 33');
          },
        ),
      );
      addTearDown(db.close);

      // Таблица существует после подъёма — сама миграция `if (from < 34)`
      // отработала, не только `onCreate` будущей свежей базы.
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'security_events'",
          )
          .get();
      expect(
        tables,
        hasLength(1),
        reason:
            'красный без миграции v33→v34: таблица создаётся только '
            '_safeCreateTable(m, securityEvents) в блоке if (from < 34) — '
            'на подъёме с v33 без него её не будет вовсе',
      );

      // Таблица не только существует — в неё в самом деле можно писать
      // через настоящий DAO, тем же путём, каким журнал пишется в
      // продукте, а не только структурно созданной и нечитаемой.
      final written = await db.securityEventDao.record(
        occurredAtEpochMs: 1000,
        userId: userId,
        terminalId: terminalId,
        eventType: 'auth.login',
        outcome: 'success',
        correlationId: 'test-correlation',
      );

      final rows = await db.securityEventDao.findAll();
      expect(rows, hasLength(1));
      expect(rows.single.id, written.id);
      expect(rows.single.userId, userId);
      expect(rows.single.terminalId, terminalId);
      expect(
        rows.single.previousFingerprint,
        SecurityEventDao.genesisFingerprint,
        reason: 'первая запись цепочки на свежесозданной миграцией таблице',
      );
    },
  );
}
