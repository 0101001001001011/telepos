import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/sale/payment_service.dart';

/// Миграция v37→v38 (задача 15 плана «продажа с браузерного терминала»):
/// у рабочего места появляется набор разрешённых видов оплаты
/// (`allowed_payment_types`).
///
/// **Главное утверждение здесь — не «колонка добавилась», а «терминал не
/// онемел».** Пустое значение колонки означает «все виды», и именно это
/// проверяется на строке, заведённой до миграции: установка, поднявшаяся на
/// новую версию, обязана продолжать принимать деньги всеми видами, которыми
/// принимала вчера.
///
/// Образец фикстуры — `migration_v37_test.dart`: вид v37 строится не руками,
/// а `ALTER TABLE ... DROP COLUMN` над настоящей текущей таблицей.
Future<String> _readV37TerminalsSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  await probe.customStatement(
    'ALTER TABLE ${probe.terminals.actualTableName} '
    'DROP COLUMN allowed_payment_types',
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

AppDatabase _openAsIfMigratingFromV37(
  String terminalsSql, {
  required void Function(sqlite3.Database raw) seed,
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(terminalsSql);
        raw.execute('PRAGMA user_version = 37');
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
    'фикстура v37 действительно не содержит новую колонку — иначе проба ниже '
    'прошла бы и без миграции',
    () async {
      final sql = await _readV37TerminalsSql();
      expect(sql, isNot(contains('allowed_payment_types')));

      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.dispose);
      raw.execute(sql);
      final columns = raw
          .select('PRAGMA table_info(terminals)')
          .map((row) => row['name'] as String)
          .toSet();
      expect(columns, isNot(contains('allowed_payment_types')));
      expect(
        columns,
        containsAll(['id', 'name', 'is_self', 'point_mode', 'created_at']),
        reason:
            'соседние колонки на месте — иначе проверка выше проходила бы '
            'и на пустом наборе имён',
      );
    },
  );

  test('свежая база: колонка есть с самого начала, версия схемы — текущая', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      await _columnsOf(db, db.terminals.actualTableName),
      contains('allowed_payment_types'),
    );

    final row = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    expect(
      row.allowedPaymentTypes,
      '',
      reason: 'умолчание — пустая строка, а не NULL: пустое значит «все»',
    );
  });

  test('подъём с v37: заведённый раньше терминал получает пустой набор и '
      'продолжает принимать все виды оплаты', () async {
    final terminalsSql = await _readV37TerminalsSql();

    final db = _openAsIfMigratingFromV37(
      terminalsSql,
      seed: (raw) {
        raw.execute(
          'INSERT INTO terminals (id, name, is_self, point_mode, '
          'created_at) VALUES (5, ?, 1, ?, ?)',
          ['Касса №1', 'cashier', 1_700_000_000],
        );
        raw.execute(
          'INSERT INTO terminals (id, name, is_self, point_mode, '
          'created_at) VALUES (99, ?, 0, ?, ?)',
          ['Планшет в зале', 'cashier', 1_700_000_001],
        );
      },
    );
    addTearDown(db.close);

    expect(
      await _columnsOf(db, db.terminals.actualTableName),
      contains('allowed_payment_types'),
    );

    final terminals = await LocalTerminalRepository(db).list();
    expect(terminals.map((t) => t.id), containsAll([5, 99]));
    for (final terminal in terminals) {
      expect(
        terminal.allowedPaymentTypes,
        isEmpty,
        reason: 'терминал #${terminal.id}',
      );
      for (final type in PaymentType.values) {
        expect(
          terminal.allows(type),
          isTrue,
          reason: 'терминал #${terminal.id} перестал принимать ${type.name}',
        );
      }
    }
  });

  test('повторная миграция на уже добавленной колонке не падает', () async {
    // `_safeAddColumn` глотает «duplicate column name» намеренно: установка,
    // прошедшая v38 и открытая заново (или откатившаяся к прежней сборке и
    // поднятая снова), придёт сюда второй раз.
    final probe = AppDatabase(NativeDatabase.memory());
    final row = await probe
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable.withString(probe.terminals.actualTableName)],
        )
        .getSingle();
    final currentSql = row.read<String>('sql');
    await probe.close();

    final db = _openAsIfMigratingFromV37(currentSql, seed: (_) {});
    addTearDown(db.close);

    expect(
      await _columnsOf(db, db.terminals.actualTableName),
      allOf(contains('allowed_payment_types'), contains('secret_fingerprint')),
    );
  });
}
