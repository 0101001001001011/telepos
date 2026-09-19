import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

/// Миграция v29→v30: из `ThisPosEntries` убираются `reject_from_time` и
/// `reject_to_time` — окно, в которое печать была запрещена.
///
/// Почему они убираются, записано в `app_database.dart`, в блоке
/// `if (from < 30)`: у пары не было ни писателя, ни читателя, ни экрана, ни
/// инварианта; толковать её умел единственный класс из
/// `lib/hardware/printer/printer_config.dart`, который осиротел вместе с
/// удалённым планировщиком печати и удалён в этой же ветке.
///
/// Проверяется здесь именно то, что дороже всего ошибиться: колонок больше
/// нет, а **всё остальное содержимое строки цело**. `ALTER TABLE ... DROP
/// COLUMN` на старых сборках sqlite делался перестройкой таблицы, и
/// перестройка — это ровно тот случай, когда «миграция прошла» и «данные на
/// месте» расходятся молча.
const _rejectFromTimeColumn = 'reject_from_time';
const _rejectToTimeColumn = 'reject_to_time';

/// `CREATE TABLE` для `this_pos_entries` в том виде, какой он имел в схеме
/// v29 — читается с настоящей базы, а не набирается руками.
///
/// Текущая схема уже без этих двух колонок, поэтому они добавляются обратно
/// тем же `ALTER TABLE ... ADD COLUMN`, каким пользуется настоящая миграция.
/// Тип — `TEXT`: именно так drift порождал `TextColumn ... nullable()`.
Future<String> _readV29ThisPosCreateSql() async {
  final probe = AppDatabase(NativeDatabase.memory());
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'ADD COLUMN $_rejectFromTimeColumn TEXT',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'ADD COLUMN $_rejectToTimeColumn TEXT',
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

/// Схема поднимается до 33 (задача 15/16), а не до 30 — открытие с
/// `user_version = 29` теперь проходит и блок `if (from < 33)`
/// (`UserPermissionDao` — задача 15), который читает `users` через
/// `userDao.findAll()`. Эта фикстура никогда не заводила эту таблицу — она
/// не была ей нужна ни для чего, кроме прохождения более поздней,
/// добавленной позже миграции. Настоящая база апгрейда всегда имела `users`
/// (таблица существует с версии 1), поэтому это пробел фикстуры, а не
/// свойство реального апгрейда.
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
/// база апгрейда таблицу имеет с v27. `DROP COLUMN` над текущей CREATE TABLE
/// — тот же приём, каким выше строится сама фикстура `this_pos_entries`.
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
/// настоящая база апгрейда таблицу `sales` имеет с самой первой схемы.
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

/// Открывает базу, выглядящую как схема 29: таблица создана сырым SQL до
/// того, как drift возьмётся за миграции, `user_version` принудительно 29.
/// Открытие через [AppDatabase] запускает ветки `if (from < 30)` и
/// `if (from < 33)` — до итогового `schemaVersion`, не только «свою».
AppDatabase _openAsIfMigratingFromV29(
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
        raw.execute('PRAGMA user_version = 29');
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
  test('фикстура v29 действительно содержит окно запрета печати', () async {
    // Без этой проверки тест ниже прошёл бы и на фикстуре, в которой колонок
    // не было изначально, — то есть доказывал бы, что миграция не нужна.
    final sql = await _readV29ThisPosCreateSql();
    expect(sql, contains(_rejectFromTimeColumn));
    expect(sql, contains(_rejectToTimeColumn));
  });

  test('свежая база: окна запрета печати нет вовсе', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final columns = await _columnsOf(db, db.thisPosEntries.actualTableName);
    expect(columns, isNot(contains(_rejectFromTimeColumn)));
    expect(columns, isNot(contains(_rejectToTimeColumn)));
    expect(
      columns,
      contains('print_vat_on_receipt'),
      reason:
          'соседняя колонка на месте — иначе проверка выше проходила бы и на '
          'пустом наборе имён',
    );
  });

  test(
    'миграция v29→v30: окно запрета печати убрано, остальная строка цела',
    () async {
      final sql = await _readV29ThisPosCreateSql();
      final usersSql = await _readUsersCreateSql();
      final terminalsSql = await _readTerminalsCreateSql();
      final salesSql = await _readSalesCreateSql();
      final db = _openAsIfMigratingFromV29(
        sql,
        usersSql,
        terminalsSql,
        salesSql,
        seed: (raw) {
          // Колонки засеяны **непустыми** значениями: убрать пустую колонку
          // умеет и сломанная миграция. И соседи вокруг них — с национальными
          // символами и с настоящими значениями продукта (48 — количество
          // символов, а не миллиметры), чтобы «строка цела» проверялось
          // содержимым, а не фактом существования.
          raw.execute(
            'INSERT INTO this_pos_entries '
            '(r_id, cash_box_name, company_name, paper_width, printer_header, '
            'printer_footer, barcode_min_length, barcode_max_length, '
            'scanner_timeout_ms, print_vat_on_receipt, '
            '$_rejectFromTimeColumn, $_rejectToTimeColumn) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              1,
              'Дүкен «Ысык-Көл» №2',
              'ЖШС «Кассаүй»',
              48,
              'Чек №— Toshkent filiali',
              'Спасибо за покупку! Рахмет!',
              6,
              20,
              150,
              1,
              '23:00',
              '07:00',
            ],
          );
        },
      );
      addTearDown(db.close);

      final columns = await _columnsOf(db, db.thisPosEntries.actualTableName);
      expect(
        columns,
        isNot(contains(_rejectFromTimeColumn)),
        reason: 'окно запрета печати не поддержано ни одним инвариантом',
      );
      expect(columns, isNot(contains(_rejectToTimeColumn)));

      final pos = await db.thisPosDao.get();
      expect(pos, isNotNull, reason: 'строка не должна пропасть вместе с колонками');
      expect(pos!.cashBoxName, 'Дүкен «Ысык-Көл» №2');
      expect(pos.companyName, 'ЖШС «Кассаүй»');
      expect(pos.paperWidth, 48);
      expect(pos.printerHeader, 'Чек №— Toshkent filiali');
      expect(pos.printerFooter, 'Спасибо за покупку! Рахмет!');
      expect(pos.barcodeMinLength, 6);
      expect(pos.barcodeMaxLength, 20);
      expect(pos.scannerTimeoutMs, 150);
      expect(pos.printVatOnReceipt, isTrue);
    },
  );

  test('повторная миграция на уже убранных колонках не падает', () async {
    // `_safeDropColumn` глотает «no such column» намеренно: установка,
    // прошедшая v30 и откатившаяся к прежней сборке, придёт сюда второй раз.
    final probe = AppDatabase(NativeDatabase.memory());
    final currentSql = await probe
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [
            Variable.withString(probe.thisPosEntries.actualTableName),
          ],
        )
        .getSingle();
    final sqlWithoutRejectWindow = currentSql.read<String>('sql');
    final usersRow = await probe
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'users'",
        )
        .getSingle();
    final usersSql = usersRow.read<String>('sql');
    final terminalsRow = await probe
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'terminals'",
        )
        .getSingle();
    final terminalsSql = terminalsRow.read<String>('sql');
    await probe.customStatement(
      'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN terminal_id',
    );
    await probe.customStatement(
      'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN cart_version',
    );
    await probe.customStatement(
      'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN '
      'last_command_key',
    );
    final salesRow = await probe
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'sales'",
        )
        .getSingle();
    final salesSql = salesRow.read<String>('sql');
    await probe.close();

    final db = _openAsIfMigratingFromV29(
      sqlWithoutRejectWindow,
      usersSql,
      terminalsSql,
      salesSql,
    );
    addTearDown(db.close);

    final columns = await _columnsOf(db, db.thisPosEntries.actualTableName);
    expect(columns, isNot(contains(_rejectFromTimeColumn)));
    expect(columns, contains('print_vat_on_receipt'));
  });
}
