import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

/// Миграция v36→v37 (задача 2 плана «продажа с браузерного терминала»):
/// у чека в работе (`state = 0`) появляется владелец (`terminal_id`),
/// версия снимка корзины (`cart_version`) и ключ последней применённой
/// команды (`last_command_key`). Зачем нужны все три, а не одна, — в
/// докстрингах самих колонок (`lib/data/database/tables/sale_tables.dart`).
///
/// Образец — `test/unit/data/terminal_secret_migration_test.dart`: фикстура
/// v36 строится не руками, а `ALTER TABLE ... DROP COLUMN` над настоящей
/// текущей таблицей `sales` (уже несущей все три новые колонки), чтобы
/// получить настоящий вид v36 тем же инструментом (`sqlite3` 3.35+
/// `DROP COLUMN`), которым `_safeDropColumn` пользуется в продукте.
Future<String> _readV36SalesCreateSql() async {
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
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(probe.sales.actualTableName)],
      )
      .getSingle();
  final sql = row.read<String>('sql');
  await probe.close();
  return sql;
}

/// `terminals` не менялась между v36 и v37 — читается с текущей базы, нужна
/// здесь только чтобы подзапрос миграции (`... FROM terminals WHERE
/// is_self = 1`) было над чем выполнять.
Future<String> _readTerminalsSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
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

/// Открывает базу, выглядящую как схема 36: `sales` — фикстура без трёх
/// новых колонок, `terminals` — с текущей базы, `user_version` принудительно
/// 36. Открытие через [AppDatabase] запускает ровно ветку `if (from < 37)`,
/// идущую последней в `onUpgrade`.
AppDatabase _openAsIfMigratingFromV36(
  String salesSql,
  String terminalsSql, {
  required void Function(sqlite3.Database raw) seed,
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(salesSql);
        raw.execute(terminalsSql);
        raw.execute('PRAGMA user_version = 36');
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
    'фикстура v36 действительно не содержит новые колонки — иначе тест ниже '
    'прошёл бы и без миграции',
    () async {
      final salesSql = await _readV36SalesCreateSql();
      expect(salesSql, isNot(contains('terminal_id')));
      expect(salesSql, isNot(contains('cart_version')));
      expect(salesSql, isNot(contains('last_command_key')));

      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.dispose);
      raw.execute(salesSql);
      final columns = raw
          .select('PRAGMA table_info(sales)')
          .map((row) => row['name'] as String)
          .toSet();
      expect(
        columns,
        allOf(
          isNot(contains('terminal_id')),
          isNot(contains('cart_version')),
          isNot(contains('last_command_key')),
        ),
      );
      expect(
        columns,
        containsAll(['receipt_no', 'pos_id', 'user_id', 'amount', 'time', 'state']),
        reason: 'соседние колонки на месте — иначе проверка выше проходила '
            'бы и на пустом наборе имён',
      );
    },
  );

  test(
    'свежая база: все три колонки есть с самого начала, версия схемы — '
    'текущая',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Число двигается с каждой следующей миграцией (здесь 38 —
      // `allowed_payment_types`, задача 15): проверяется, что база
      // поднялась до текущей версии, а не остановилась на v36.
      final columns = await _columnsOf(db, db.sales.actualTableName);
      expect(
        columns,
        containsAll(['terminal_id', 'cart_version', 'last_command_key']),
      );

      // По умолчанию: свежая строка без явного cart_version получает 0, а
      // не NULL — колонка объявлена `withDefault(Constant(0))`, не
      // `nullable()`.
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 1,
              userId: 1,
              amount: Decimal.zero,
              time: 1_700_000_000,
            ),
          );
      final row = await db.saleDao.findByKey(1, 1);
      expect(row!.cartVersion, 0);
      expect(row.terminalId, isNull);
      expect(row.lastCommandKey, isNull);
    },
  );

  test(
    'подъём с v36: чек в работе (state = 0) получает терминалом кассы '
    'единственный терминал с is_self = 1 — до этой версии рабочее место '
    'было одно, и это оно',
    () async {
      final salesSql = await _readV36SalesCreateSql();
      final terminalsSql = await _readTerminalsSql();
      const selfTerminalId = 5;
      const inProgressReceiptNo = 10;
      const otherPosId = 1;
      const completedReceiptNo = 11;
      const amount = 1234.56;

      final db = _openAsIfMigratingFromV36(
        salesSql,
        terminalsSql,
        seed: (raw) {
          raw.execute(
            'INSERT INTO terminals (id, name, is_self, point_mode, '
            'created_at) VALUES ($selfTerminalId, ?, 1, ?, ?)',
            ['Касса №1', 'cashier', 1_700_000_000],
          );
          // Чужой (не self) терминал в базе не должен повлиять на выбор —
          // владельцем обязан стать именно is_self, а не первый попавшийся.
          raw.execute(
            'INSERT INTO terminals (id, name, is_self, point_mode, '
            'created_at) VALUES (99, ?, 0, ?, ?)',
            ['Браузерный терминал', 'cashier', 1_700_000_001],
          );
          // Живой чек — должен получить владельца.
          raw.execute(
            'INSERT INTO sales (receipt_no, pos_id, user_id, amount, time, '
            'state) VALUES ($inProgressReceiptNo, $otherPosId, 1, $amount, '
            '1700000100, 0)',
          );
          // Завершённый чек — принадлежит смене и кассе, владельца нести не
          // должен: миграция обязана его не тронуть.
          raw.execute(
            'INSERT INTO sales (receipt_no, pos_id, user_id, amount, time, '
            'state) VALUES ($completedReceiptNo, $otherPosId, 1, $amount, '
            '1700000200, 3)',
          );
        },
      );
      addTearDown(db.close);

      // Число двигается с каждой следующей миграцией (здесь 38 —
      // `allowed_payment_types`, задача 15): проверяется, что база
      // поднялась до текущей версии, а не остановилась на v36.

      final inProgress = await db.saleDao.findByKey(
        inProgressReceiptNo,
        otherPosId,
      );
      expect(
        inProgress!.terminalId,
        selfTerminalId,
        reason: 'живой чек до этой версии принадлежал единственному рабочему '
            'месту кассы — is_self=1, а не первому терминалу по id',
      );
      expect(
        inProgress.cartVersion,
        0,
        reason: 'у старой строки версии снимка ещё не было — новая колонка '
            'обязана дать умолчание, а не NULL',
      );
      expect(inProgress.lastCommandKey, isNull);
      // Деньги — не забота этой миграции: остаются как были.
      expect(inProgress.amount.toDouble(), amount);

      final completed = await db.saleDao.findByKey(
        completedReceiptNo,
        otherPosId,
      );
      expect(
        completed!.terminalId,
        isNull,
        reason: 'завершённый чек принадлежит смене и кассе — владельца из '
            'этой миграции получать не должен (докстринг terminalId)',
      );
    },
  );

  test(
    'подъём с v36: если ни у одного терминала is_self не проставлен, чек в '
    'работе остаётся без владельца — миграция обязана не падать',
    () async {
      final salesSql = await _readV36SalesCreateSql();
      final terminalsSql = await _readTerminalsSql();

      final db = _openAsIfMigratingFromV36(
        salesSql,
        terminalsSql,
        seed: (raw) {
          // Терминал есть, но is_self у него не проставлен ни у одной
          // строки — ровно случай, для которого правка брифа требует не
          // падать.
          raw.execute(
            'INSERT INTO terminals (id, name, is_self, point_mode, '
            'created_at) VALUES (1, ?, 0, ?, ?)',
            ['Касса №1', 'cashier', 1700000000],
          );
          raw.execute(
            'INSERT INTO sales (receipt_no, pos_id, user_id, amount, time, '
            'state) VALUES (1, 1, 1, 100.0, 1700000100, 0)',
          );
        },
      );
      addTearDown(db.close);

      // Число двигается с каждой следующей миграцией (здесь 38 —
      // `allowed_payment_types`, задача 15): проверяется, что база
      // поднялась до текущей версии, а не остановилась на v36.
      final row = await db.saleDao.findByKey(1, 1);
      expect(row, isNotNull, reason: 'строка не должна пропасть из-за миграции');
      expect(row!.terminalId, isNull);
    },
  );

  test(
    'повторная миграция на уже добавленных колонках не падает',
    () async {
      // `_safeAddColumn` глотает «duplicate column name» намеренно:
      // установка, прошедшая v37 и открытая заново (или откатившаяся к
      // прежней сборке и поднятая снова), придёт сюда второй раз.
      final probe = AppDatabase(NativeDatabase.memory());
      final row = await probe
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable.withString(probe.sales.actualTableName)],
          )
          .getSingle();
      final currentSalesSql = row.read<String>('sql');
      final terminalsSql = await _readTerminalsSql();
      await probe.close();

      final db = _openAsIfMigratingFromV36(
        currentSalesSql,
        terminalsSql,
        seed: (_) {},
      );
      addTearDown(db.close);

      final columns = await _columnsOf(db, db.sales.actualTableName);
      expect(
        columns,
        containsAll(['terminal_id', 'cart_version', 'last_command_key']),
      );
      expect(columns, contains('amount'));
    },
  );
}
