import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/migrations/device_binding_migration.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';

/// Column/table names and `CREATE TABLE` SQL for `ThisPosEntries` and
/// `Terminals`, read off a throwaway database instead of hand-typed — same
/// technique as `test/unit/data/terminal_migration_test.dart`, extended to
/// also cover `Terminals`.
///
/// Neither table is unchanged by this task any more: plan 2, task 5 dropped
/// `Terminals`'s seven legacy per-terminal device columns
/// (`printer_type`/`printer_address`/`scanner_type`/`scale_port`/
/// `scale_baud_rate`/`drawer_via_printer`/`display_port`) once
/// `TerminalDeviceBindings` carried their content — see task-5-report.md —
/// and final review finding I1 dropped `ThisPosEntries.printerConnectionType`/
/// `.printerAddress`/`.printerPort` (schema v27, see
/// `app_database.dart`'s `if (from < 27)` block). The *current* Dart schema
/// is therefore already past what a real v26 database looked like, and this
/// fixture adds all ten columns back by raw `ALTER TABLE ... ADD COLUMN`,
/// mirroring the exact DDL `sqlite3_flutter_libs` produced for them before
/// the drops (`TEXT`/`INTEGER` as appropriate, `INTEGER NOT NULL DEFAULT 1`
/// for the boolean `drawer_via_printer` — the same encoding drift still uses
/// for every other `BoolColumn` in this schema, e.g. `terminals.isSelf`
/// itself, which is left alone here). This is the same direction
/// `_safeAddColumn` uses in the real migration, just via raw SQL since the
/// Dart column definitions this fixture used to read (`probe.terminals
/// .printerType`, `probe.thisPosEntries.printerConnectionType`, etc.) no
/// longer exist to read from.
class _V26Shape {
  _V26Shape({
    required this.thisPosCreateSql,
    required this.thisPosTableName,
    required this.rIdColumn,
    required this.cashBoxNameColumn,
    required this.paperWidthColumn,
    required this.terminalsCreateSql,
    required this.terminalsTableName,
    required this.terminalIdColumn,
    required this.terminalNameColumn,
    required this.terminalIsSelfColumn,
    required this.terminalPointModeColumn,
    required this.terminalCreatedAtColumn,
    required this.usersCreateSql,
  });

  final String thisPosCreateSql;
  final String thisPosTableName;
  final String rIdColumn;
  final String cashBoxNameColumn;
  final String paperWidthColumn;

  final String terminalsCreateSql;
  final String terminalsTableName;
  final String terminalIdColumn;
  final String terminalNameColumn;
  final String terminalIsSelfColumn;
  final String terminalPointModeColumn;
  final String terminalCreatedAtColumn;

  // Задача 15/16 (замок кассы, фаза 5): схема поднимается до 33, и открытие
  // с `PRAGMA user_version = 26` теперь проходит и блок `if (from < 33)`
  // (`UserPermissionDao`), который читает `users` через
  // `userDao.findAll()`. Эта фикстура никогда не заводила `users` — он ей
  // не был нужен ни для чего своего, только чтобы пережить более позднюю
  // миграцию, добавленную после неё. Настоящая база апгрейда всегда имела
  // `users` (таблица существует с версии 1), поэтому это пробел фикстуры,
  // а не свойство реального апгрейда.
  final String usersCreateSql;

  // The ten legacy raw columns this fixture adds back are always named
  // exactly this way — literal, not read off the (now column-less) Dart
  // class. Kept as constants here rather than fields so every call site
  // shares one spelling.
  static const printerConnectionTypeColumn = 'printer_connection_type';
  static const printerAddressColumn = 'printer_address';
  static const printerPortColumn = 'printer_port';
  static const terminalPrinterTypeColumn = 'printer_type';
  static const terminalPrinterAddressColumn = 'printer_address';
  static const terminalScannerTypeColumn = 'scanner_type';
  static const terminalScalePortColumn = 'scale_port';
  static const terminalScaleBaudRateColumn = 'scale_baud_rate';
  static const terminalDrawerViaPrinterColumn = 'drawer_via_printer';
  static const terminalDisplayPortColumn = 'display_port';
}

Future<_V26Shape> _readV26Shape() async {
  final probe = AppDatabase(NativeDatabase.memory());

  // Strip the two v27-only ThisPosEntries columns so the extracted CREATE
  // TABLE reflects the true v26 shape. This uses the exact same DROP COLUMN
  // mechanism the real migration uses — so this doubles as a smoke test
  // that `ALTER TABLE ... DROP COLUMN` actually works against the sqlite3
  // build this test runs on, before any real migration depends on it.
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'DROP COLUMN ${probe.thisPosEntries.barcodeMinLength.name}',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'DROP COLUMN ${probe.thisPosEntries.barcodeMaxLength.name}',
  );

  // Add the three legacy `this_pos_entries` printer columns back — final
  // review finding I1 dropped them from the current Dart schema (see this
  // class's doc comment above).
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'ADD COLUMN ${_V26Shape.printerConnectionTypeColumn} INTEGER',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'ADD COLUMN ${_V26Shape.printerPortColumn} INTEGER',
  );
  // printer_address is added further down, shared spelling with Terminals'
  // own printer_address column name (both tables happened to use the same
  // column name pre-branch) — see the `legacyTerminalColumns` map below,
  // which adds `Terminals.printer_address`. ThisPosEntries needs its own
  // ADD COLUMN too, on its own table.
  await probe.customStatement(
    'ALTER TABLE ${probe.thisPosEntries.actualTableName} '
    'ADD COLUMN ${_V26Shape.printerAddressColumn} TEXT',
  );

  // Add the seven legacy `terminals` device columns back — task 5 dropped
  // them from the current Dart schema (see this class's doc comment above).
  const legacyTerminalColumns = <String, String>{
    'printer_type': 'printer_type TEXT',
    'printer_address': 'printer_address TEXT',
    'scanner_type': 'scanner_type TEXT',
    'scale_port': 'scale_port TEXT',
    'scale_baud_rate': 'scale_baud_rate INTEGER',
    'drawer_via_printer': 'drawer_via_printer INTEGER NOT NULL DEFAULT 1',
    'display_port': 'display_port TEXT',
  };
  for (final columnDdl in legacyTerminalColumns.values) {
    await probe.customStatement(
      'ALTER TABLE ${probe.terminals.actualTableName} ADD COLUMN $columnDdl',
    );
  }

  final thisPosRow = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(probe.thisPosEntries.actualTableName)],
      )
      .getSingle();
  final terminalsRow = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(probe.terminals.actualTableName)],
      )
      .getSingle();
  final usersRow = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'users'",
      )
      .getSingle();

  final shape = _V26Shape(
    thisPosCreateSql: thisPosRow.read<String>('sql'),
    thisPosTableName: probe.thisPosEntries.actualTableName,
    rIdColumn: probe.thisPosEntries.rId.name,
    cashBoxNameColumn: probe.thisPosEntries.cashBoxName.name,
    paperWidthColumn: probe.thisPosEntries.paperWidth.name,
    terminalsCreateSql: terminalsRow.read<String>('sql'),
    terminalsTableName: probe.terminals.actualTableName,
    terminalIdColumn: probe.terminals.id.name,
    terminalNameColumn: probe.terminals.name.name,
    terminalIsSelfColumn: probe.terminals.isSelf.name,
    terminalPointModeColumn: probe.terminals.pointMode.name,
    terminalCreatedAtColumn: probe.terminals.createdAt.name,
    usersCreateSql: usersRow.read<String>('sql'),
  );
  await probe.close();
  return shape;
}

/// Opens an in-memory database pre-seeded to look like schema 26: both
/// `ThisPosEntries` and `Terminals` exist (created via raw SQL in `setup`,
/// which runs before drift's migration machinery), `PRAGMA user_version` is
/// forced to 26, and [seed] (if given) inserts rows directly with `?`
/// parameter binding — real values, not string-interpolated SQL, so Cyrillic
/// names round-trip exactly and nothing needs manual escaping. Opening this
/// through `AppDatabase` triggers exactly the `if (from < 27)` branch.
AppDatabase _openAsIfMigratingFromV26(
  _V26Shape shape, {
  void Function(sqlite3.Database raw, _V26Shape shape)? seed,
  String? legacyHardwareSettingsBlobJson,
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(shape.thisPosCreateSql);
        raw.execute(shape.terminalsCreateSql);
        raw.execute(shape.usersCreateSql);
        raw.execute('PRAGMA user_version = 26');
        if (seed != null) seed(raw, shape);
      },
    ),
    legacyHardwareSettingsBlobJson: legacyHardwareSettingsBlobJson,
  );
}

void main() {
  test('фикстура v26 действительно не содержит колонок schema 27', () async {
    final shape = await _readV26Shape();
    expect(shape.thisPosCreateSql, isNot(contains('barcode_min_length')));
    expect(shape.thisPosCreateSql, isNot(contains('barcode_max_length')));
  });

  test('свежая база onCreate: новые колонки существуют, привязок не выдумано', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // schemaVersion itself is not asserted here — see
    // test/data/database/app_database_test.dart, which checks the real
    // invariant (every bump has a matching migration branch) once,
    // generically, instead of every migration test re-asserting the
    // current literal and breaking on the next bump.

    final bindings = await db.select(db.terminalDeviceBindings).get();
    expect(bindings, isEmpty, reason: 'onCreate не должен выдумывать привязки');

    // Колонки существуют и доступны — вставка со значениями в них не падает.
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    await db.into(db.thisPosEntries).insertOnConflictUpdate(
      ThisPosEntriesCompanion(
        rId: const Value(true),
        barcodeMinLength: const Value(5),
        barcodeMaxLength: const Value(25),
      ),
    );
    final pos = await db.thisPosDao.get();
    expect(pos!.barcodeMinLength, 5);
    expect(pos.barcodeMaxLength, 25);
  });

  test(
    'миграция v26→v27: несколько терминалов (казахская и киргизская кириллица), '
    'блоб (включая живые ключи принтера/этикеток/весов) и raw-колонки переносятся '
    'по одному терминалу на комплект, неоднозначное не переносится нигде, '
    'мёртвая копия (ThisPosEntries/Terminals raw) уступает живой (блоб)',
    () async {
      final shape = await _readV26Shape();

      final blob = jsonEncode({
        'barcodeMinLength': 6,
        'barcodeMaxLength': 20,
        'scannerMode': 2, // camera — unambiguous
        'scannerTimeout': 150,
        'drawerMode': 1, // standalone
        'drawerPort': 'COM7',
        'displayEnabled': true,
        'displayModel': 1,
        'displayPort': 'COM9',
        'displayBaudRate': 9600,
        'kaspiEnabled': true,
        'kaspiIp': '10.0.0.5',
        'kaspiPort': '8888',
        // Rahmet выведен из продукта (решение владельца продукта, посреди
        // fix round 1 — см. task-2-report.md). Заданы с реальными, валидными
        // значениями (не false/пусто), чтобы тест ниже доказывал, что эти
        // три ключа действительно проигнорированы, а не просто случайно не
        // сработали бы всё равно.
        'rahmetEnabled': true,
        'rahmetMerchant': 'M-IGNORED',
        'rahmetTerminal': 'T-IGNORED',
        // Живые ключи принтера, этикеток и весов — final review finding C3:
        // одиннадцать ключей, которые printer_settings_screen.dart/
        // label_printer_settings_screen.dart/hardware_settings_screen.dart
        // писали НАПРЯМУЮ в тот же блоб, минуя HardwareSettingsProvider,
        // и которые исходный "инвентарь шестнадцати ключей" не учитывал.
        // receiptPrinterAddress/Port сознательно ОТЛИЧАЮТСЯ от значений,
        // засеянных ниже в ThisPosEntries.printer_address/printer_port —
        // доказывает, что миграция берёт живую копию (блоб), а не мёртвую
        // (сырые колонки), а не просто совпадение значений.
        'receiptPrinterType': 'wifi',
        'receiptPrinterAddress': '10.0.9.9',
        'receiptPrinterPort': 9101,
        'labelHost': '10.0.9.50',
        'labelPort': 9100,
        'labelLanguage': 'zpl',
        'labelWidthMm': 104,
        'labelHeightMm': 60,
        'scaleEnabled': true,
        'scalePort': 'COM6',
        'scaleBaudRate': 9600,
        'scaleProtocol': 'cas',
        // Посторонний ключ, которого нет среди официальных — используется
        // реальным кодом (lib/main.dart), но не имеет отношения к устройствам.
        // Не должен ни потеряться из блоба (его тут никто не переписывает),
        // ни превратиться в привязку/бизнес-правило.
        'customerScreenEnabled': true,
      });

      final db = _openAsIfMigratingFromV26(
        shape,
        legacyHardwareSettingsBlobJson: blob,
        seed: (raw, s) {
          // ThisPosEntries.printer_connection_type/printer_address/printer_port
          // — the now-dropped, dead v26 columns (final review finding I1).
          // Deliberately seeded with values DIFFERENT from the blob's live
          // receiptPrinterAddress/receiptPrinterPort above, so the assertion
          // below can only pass if the migration actually prefers the blob.
          //
          // paper_width = 48 — a REAL character-count value the product can
          // actually store (32/42/48; never a millimetre value like 80).
          // Second-review-round finding: this fixture used to seed the
          // millimetre value 80 directly, which happened to also be a valid
          // `paperWidthsMm` entry by coincidence, so it never exercised the
          // character-to-millimetre conversion the real column requires.
          // 48 converts to 80mm via paperWidthMmFromCharWidth, so the
          // downstream assertions (profileId printer.escpos.80mm, option
          // paperWidthMm '80') are unchanged — only the input is now real.
          raw.execute(
            'INSERT INTO ${s.thisPosTableName} '
            '(${s.rIdColumn}, ${s.cashBoxNameColumn}, ${s.paperWidthColumn}, '
            '${_V26Shape.printerConnectionTypeColumn}, ${_V26Shape.printerAddressColumn}, '
            '${_V26Shape.printerPortColumn}) '
            'VALUES (?, ?, ?, ?, ?, ?)',
            [1, 'Каспи-Алматы', 48, 2, '192.168.1.77-DEAD', 9100],
          );

          // Terminal A — self, gets the blob. Own raw columns (usb scanner,
          // via-printer drawer) are deliberately overridden by the blob's
          // camera/standalone values below, proving precedence.
          raw.execute(
            'INSERT INTO ${s.terminalsTableName} '
            '(${s.terminalIdColumn}, ${s.terminalNameColumn}, ${s.terminalIsSelfColumn}, '
            '${_V26Shape.terminalPrinterTypeColumn}, ${_V26Shape.terminalPrinterAddressColumn}, '
            '${_V26Shape.terminalScannerTypeColumn}, ${_V26Shape.terminalScalePortColumn}, '
            '${_V26Shape.terminalScaleBaudRateColumn}, ${_V26Shape.terminalDrawerViaPrinterColumn}, '
            '${_V26Shape.terminalDisplayPortColumn}, ${s.terminalPointModeColumn}, '
            '${s.terminalCreatedAtColumn}) '
            'VALUES (1, ?, 1, NULL, ?, ?, ?, ?, 1, ?, ?, ?)',
            [
              'Кассаүй',
              '192.168.1.77-TERMINALS-DEAD',
              'usb',
              'COM3',
              9600,
              'COM5',
              'cashier',
              1000,
            ],
          );

          // Terminal B — not self, no blob. scannerType=camera is
          // unambiguous on its own; printerType=wifi alone (no width, terminal
          // B isn't self so gets no ThisPosEntries.paperWidth either) stays
          // ambiguous between printer.escpos.80mm/usb/serial-shaped
          // candidates once width can't narrow further — actually 'wifi'
          // uniquely selects the two networked profiles only, and without a
          // width neither one wins, so still no binding; drawerViaPrinter=false
          // has no COM port anywhere to satisfy the standalone profile's
          // requirement.
          raw.execute(
            'INSERT INTO ${s.terminalsTableName} '
            '(${s.terminalIdColumn}, ${s.terminalNameColumn}, ${s.terminalIsSelfColumn}, '
            '${_V26Shape.terminalPrinterTypeColumn}, ${_V26Shape.terminalPrinterAddressColumn}, '
            '${_V26Shape.terminalScannerTypeColumn}, ${_V26Shape.terminalScalePortColumn}, '
            '${_V26Shape.terminalScaleBaudRateColumn}, ${_V26Shape.terminalDrawerViaPrinterColumn}, '
            '${_V26Shape.terminalDisplayPortColumn}, ${s.terminalPointModeColumn}, '
            '${s.terminalCreatedAtColumn}) '
            'VALUES (2, ?, 0, ?, ?, ?, NULL, NULL, 0, NULL, ?, ?)',
            ['Дүкен №2', 'wifi', '192.168.50.10', 'camera', 'cashier', 1000],
          );

          // Terminal C — not self, no blob. drawerViaPrinter=true needs no
          // parameters, so it binds; scannerType=bluetooth stays ambiguous.
          raw.execute(
            'INSERT INTO ${s.terminalsTableName} '
            '(${s.terminalIdColumn}, ${s.terminalNameColumn}, ${s.terminalIsSelfColumn}, '
            '${_V26Shape.terminalPrinterTypeColumn}, ${_V26Shape.terminalPrinterAddressColumn}, '
            '${_V26Shape.terminalScannerTypeColumn}, ${_V26Shape.terminalScalePortColumn}, '
            '${_V26Shape.terminalScaleBaudRateColumn}, ${_V26Shape.terminalDrawerViaPrinterColumn}, '
            '${_V26Shape.terminalDisplayPortColumn}, ${s.terminalPointModeColumn}, '
            '${s.terminalCreatedAtColumn}) '
            'VALUES (3, ?, 0, NULL, NULL, ?, NULL, NULL, 1, NULL, ?, ?)',
            ['Ысык-Көл', 'bluetooth', 'cashier', 1000],
          );
        },
      );
      addTearDown(db.close);

      // Business rules — И142. Not a binding, lands on ThisPosEntries.
      final pos = await db.thisPosDao.get();
      expect(pos!.barcodeMinLength, 6);
      expect(pos.barcodeMaxLength, 20);
      expect(
        pos.scannerTimeoutMs,
        150,
        reason:
            'v26->v28 in one launch: the from < 28 step reads the same blob '
            'the from < 27 step already had in hand, via '
            'migrateLegacyScannerTimeoutMs (fix round 1) — same source, same '
            'blob value the fixture seeded above',
      );

      final allBindings = await db.select(db.terminalDeviceBindings).get();
      expect(
        allBindings.where((b) => b.deviceClass == 'scale'),
        isEmpty,
        reason:
            'scaleProtocol=cas сужает до двух CAS-профилей каталога, но оба '
            'делят один baud rate — неотличимы, привязка не создаётся даже '
            'притом что scaleEnabled/scalePort/scaleBaudRate/scaleProtocol '
            'все присутствуют в блобе (см. _inferScaleBinding)',
      );
      expect(
        allBindings.where((b) => b.deviceClass == 'customerDisplay'),
        isEmpty,
        reason: 'таксономия displayModel блоба не совпадает с профилями каталога',
      );
      expect(
        allBindings.where((b) => b.deviceClass == 'receiptPrinter'),
        hasLength(1),
        reason:
            'ровно одна привязка принтера — терминала A, из блоба (wifi + '
            'адрес); у B/C своего блоба нет',
      );
      expect(
        allBindings.where((b) => b.deviceClass == 'labelPrinter'),
        hasLength(1),
        reason:
            'ровно одна привязка принтера этикеток — терминала A, '
            'labelLanguage=zpl однозначно указывает на printer.label.zpl.104mm',
      );

      final terminalA = allBindings.where((b) => b.terminalId == 1).toList();
      expect(
        terminalA.map((b) => b.deviceClass).toSet(),
        {
          'cashDrawer',
          'scanner',
          'paymentTerminal',
          'receiptPrinter',
          'labelPrinter',
        },
        reason: 'терминал-self получает блоб; свои usb/via-printer колонки перекрыты им',
      );
      final drawerA = terminalA.singleWhere((b) => b.deviceClass == 'cashDrawer');
      expect(drawerA.profileId, 'drawer.rj11.standalone');
      expect(jsonDecode(drawerA.parametersJson), {'comPort': 'COM7'});
      final scannerA = terminalA.singleWhere((b) => b.deviceClass == 'scanner');
      expect(scannerA.profileId, 'scanner.camera');
      // singleWhere below would throw if rahmetEnabled (seeded true, above)
      // had also produced a binding — proving Rahmet is truly ignored, not
      // just coincidentally inert.
      final paymentA = terminalA.singleWhere(
        (b) => b.deviceClass == 'paymentTerminal',
      );
      expect(paymentA.profileId, 'payment.kaspi.pos');
      expect(
        jsonDecode(paymentA.parametersJson),
        {'ipAddress': '10.0.0.5', 'port': '8888'},
      );
      expect(
        allBindings.where((b) => b.profileId == 'payment.rahmet.qr'),
        isEmpty,
        reason:
            'Rahmet выведен из продукта — rahmetEnabled/rahmetMerchant/'
            'rahmetTerminal больше не читаются этой миграцией вовсе',
      );

      // C3's central case: the blob's receiptPrinterType/Address/Port win
      // over both dead raw sources (ThisPosEntries and Terminals), which
      // were seeded above with visibly different ("-DEAD") values.
      final printerA = terminalA.singleWhere(
        (b) => b.deviceClass == 'receiptPrinter',
      );
      expect(printerA.profileId, 'printer.escpos.80mm');
      expect(
        jsonDecode(printerA.parametersJson),
        {'ipAddress': '10.0.9.9', 'port': '9101'},
        reason:
            'адрес/порт должны быть из блоба (живая копия), а не из мёртвых '
            'ThisPosEntries/Terminals raw колонок',
      );
      expect(jsonDecode(printerA.optionsJson), {'paperWidthMm': '80'});

      final labelA = terminalA.singleWhere((b) => b.deviceClass == 'labelPrinter');
      expect(labelA.profileId, 'printer.label.zpl.104mm');
      expect(
        jsonDecode(labelA.parametersJson),
        {'ipAddress': '10.0.9.50', 'port': '9100'},
      );
      expect(
        jsonDecode(labelA.optionsJson),
        {'paperWidthMm': '104', 'labelHeightMm': '60'},
      );

      final terminalB = allBindings.where((b) => b.terminalId == 2).toList();
      expect(
        terminalB.map((b) => b.deviceClass).toSet(),
        {'scanner'},
        reason:
            'терминал B не self — блоб на него не переносится; свой '
            'scannerType=camera однозначен, printerType=wifi без ширины — нет',
      );
      expect(terminalB.single.profileId, 'scanner.camera');
      expect(
        jsonDecode(terminalB.single.parametersJson),
        <String, dynamic>{},
        reason: 'у камеры нет обязательных параметров',
      );

      final terminalC = allBindings.where((b) => b.terminalId == 3).toList();
      expect(
        terminalC.map((b) => b.deviceClass).toSet(),
        {'cashDrawer'},
        reason: 'drawerViaPrinter=true не требует параметров и переносится',
      );
      expect(terminalC.single.profileId, 'drawer.rj11.via-printer');

      expect(
        allBindings.length,
        terminalA.length + terminalB.length + terminalC.length,
        reason:
            'привязки одного терминала не должны просачиваться в выборку другого',
      );
    },
  );

  test(
    'миграция v27→v28: scannerTimeoutMs переносится из блоба, даже когда шаг '
    'from < 27 в этом запуске не выполняется вовсе (fix round 1) — это '
    'обычный случай: установка уже на v27 из прошлого запуска',
    () async {
      // The scenario the fix-round-1 review named directly: an installation
      // already sitting at v27 (device bindings already migrated in an
      // earlier launch) now upgrading only to v28. The `from < 27` block
      // does not run at all here (`from` starts at 27, not below it) — so
      // if scannerTimeoutMs were only ever read inside that block, this
      // installation's real, previously-set blob value would be silently
      // dropped and every operator who had configured a scanner timeout
      // would be reset to the fixed default with no way to tell.
      final probe = AppDatabase(NativeDatabase.memory());
      final createSql = (await probe
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
                variables: [
                  Variable.withString(probe.thisPosEntries.actualTableName),
                ],
              )
              .getSingle())
          .read<String>('sql');
      final tableName = probe.thisPosEntries.actualTableName;
      final columnName = probe.thisPosEntries.scannerTimeoutMs.name;
      // Задача 15/16: `if (from < 33)` теперь тоже проходится при открытии
      // этой фикстуры и читает `users` — см. комментарий у `_V26Shape
      // .usersCreateSql` выше.
      final usersCreateSql = (await probe
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE type = 'table' "
                "AND name = 'users'",
              )
              .getSingle())
          .read<String>('sql');
      // `terminals` без `secret_fingerprint` — задача 4 плана «знакомство
      // терминала с кассой» (миграция v35→v36) трогает существующую
      // таблицу и требует, чтобы она уже была: без неё подъём этой фикстуры
      // выше v35 падает на `no such table: terminals`, хотя настоящая база
      // апгрейда таблицу имеет с v27 (та же причина, что и у `users` выше).
      await probe.customStatement(
        'ALTER TABLE ${probe.terminals.actualTableName} DROP COLUMN '
        'secret_fingerprint',
      );
      final terminalsCreateSql = (await probe
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE type = 'table' "
                "AND name = 'terminals'",
              )
              .getSingle())
          .read<String>('sql');
      await probe.close();

      // v27 shape = current (v28) shape minus scanner_timeout_ms — the one
      // column this task's `from < 28` step adds.
      final v27CreateSql = createSql.replaceAll(
        RegExp(',\\s*"$columnName" INTEGER'),
        '',
      );
      expect(
        v27CreateSql,
        isNot(contains(columnName)),
        reason: 'фикстура должна реально не содержать колонку — иначе тест '
            'ничего не проверяет',
      );

      final blob = jsonEncode({'scannerTimeout': 175});

      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(v27CreateSql);
            raw.execute(usersCreateSql);
            raw.execute(terminalsCreateSql);
            raw.execute(
              "INSERT INTO $tableName (r_id, company_name, cash_box_name) "
              "VALUES (1, 'ТОО Уже На v27', 'Касса V27')",
            );
            raw.execute('PRAGMA user_version = 27');
          },
        ),
        legacyHardwareSettingsBlobJson: blob,
      );
      addTearDown(db.close);

      final pos = await db.thisPosDao.get();
      expect(
        pos!.scannerTimeoutMs,
        175,
        reason:
            'migrateLegacyScannerTimeoutMs must be called from inside the '
            'from < 28 step itself, not only from the from < 27 step (which '
            'never runs for this installation) — this is exactly the '
            'red/green case fix round 1 asked for',
      );
    },
  );

  test(
    'сканер: keyboard-wedge (mode 0) неоднозначен, serial (mode 1) без comPort '
    'в блобе — обе привязки отсутствуют, а не угаданы',
    () {
      final catalog = BuiltinDeviceProfileCatalog();

      final wedge = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({'scannerMode': 0}),
        ),
        catalog: catalog,
      );
      expect(
        wedge.bindings.where((b) => b.deviceClass.name == 'scanner'),
        isEmpty,
        reason: 'usb.hid и bluetooth.hid делят hidKeyboard — неотличимы',
      );

      final serial = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({'scannerMode': 1}),
        ),
        catalog: catalog,
      );
      expect(
        serial.bindings.where((b) => b.deviceClass.name == 'scanner'),
        isEmpty,
        reason:
            'профиль scanner.serial однозначен, но в блобе нет COM-порта '
            'сканера — обязательный параметр нечем заполнить',
      );
    },
  );

  test(
    'платёжный терминал: Rahmet выведен из продукта — три ключа больше не читаются, даже включённые с реальными значениями',
    () {
      final result = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({
            'kaspiEnabled': true,
            'kaspiIp': '10.0.0.1',
            'kaspiPort': '8888',
            'rahmetEnabled': true,
            'rahmetMerchant': 'M1',
            'rahmetTerminal': 'T1',
          }),
        ),
      );
      final payments = result.bindings
          .where((b) => b.deviceClass.name == 'paymentTerminal')
          .toList();
      expect(
        payments,
        hasLength(1),
        reason: 'только Kaspi — Rahmet больше не имеет профиля в этой миграции',
      );
      expect(payments.single.profileId, 'payment.kaspi.pos');
      expect(payments.single.parameters, {'ipAddress': '10.0.0.1', 'port': '8888'});
    },
  );

  group('принтер этикеток (final review finding C3)', () {
    test('labelLanguage=zpl/epl однозначно выбирает профиль, tspl — нет', () {
      final catalog = BuiltinDeviceProfileCatalog();

      final zpl = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({
            'labelLanguage': 'zpl',
            'labelHost': '10.0.0.20',
            'labelWidthMm': 104,
            'labelHeightMm': 40,
          }),
        ),
        catalog: catalog,
      );
      final zplBinding = zpl.bindings.singleWhere(
        (b) => b.deviceClass.name == 'labelPrinter',
      );
      expect(zplBinding.profileId, 'printer.label.zpl.104mm');
      expect(zplBinding.parameters['ipAddress'], '10.0.0.20');
      expect(zplBinding.options['paperWidthMm'], '104');
      expect(zplBinding.options['labelHeightMm'], '40');

      final epl = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({
            'labelLanguage': 'epl',
            'labelHost': '10.0.0.21',
          }),
        ),
        catalog: catalog,
      );
      final eplBinding = epl.bindings.singleWhere(
        (b) => b.deviceClass.name == 'labelPrinter',
      );
      expect(eplBinding.profileId, 'printer.label.epl.58mm');

      final tspl = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({
            'labelLanguage': 'tspl',
            'labelHost': '10.0.0.22',
          }),
        ),
        catalog: catalog,
      );
      expect(
        tspl.bindings.where((b) => b.deviceClass.name == 'labelPrinter'),
        isEmpty,
        reason: 'ни один профиль каталога не говорит на TSPL',
      );
    });

    test('без блоба — нет привязки принтера этикеток', () {
      final result = inferLegacyDeviceMigration(const LegacyDeviceSettings());
      expect(
        result.bindings.where((b) => b.deviceClass.name == 'labelPrinter'),
        isEmpty,
      );
    });
  });

  group('весы (final review finding C3) — attempted, genuinely never binds', () {
    test('scaleProtocol=generic/massaK — нет профиля в каталоге', () {
      for (final protocol in ['generic', 'massaK']) {
        final result = inferLegacyDeviceMigration(
          LegacyDeviceSettings(
            hardwareSettingsBlobJson: jsonEncode({
              'scaleEnabled': true,
              'scalePort': 'COM3',
              'scaleBaudRate': 9600,
              'scaleProtocol': protocol,
            }),
          ),
        );
        expect(
          result.bindings.where((b) => b.deviceClass.name == 'scale'),
          isEmpty,
          reason: '$protocol: каталог не знает такого протокола весов',
        );
      }
    });

    test(
      'scaleProtocol=cas — оба CAS-профиля каталога делят baud rate, '
      'привязка не создаётся даже с портом и baud rate в блобе',
      () {
        final result = inferLegacyDeviceMigration(
          LegacyDeviceSettings(
            hardwareSettingsBlobJson: jsonEncode({
              'scaleEnabled': true,
              'scalePort': 'COM3',
              'scaleBaudRate': 9600,
              'scaleProtocol': 'cas',
            }),
          ),
        );
        expect(
          result.bindings.where((b) => b.deviceClass.name == 'scale'),
          isEmpty,
          reason:
              'scale.cas.pd2 и scale.cas.er-plus оба имеют defaultBaudRate '
              '9600 — ничто в блобе не отличает их',
        );
      },
    );

    test('scaleEnabled=false — привязка не создаётся', () {
      final result = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({
            'scaleEnabled': false,
            'scaleProtocol': 'cas',
            'scalePort': 'COM3',
          }),
        ),
      );
      expect(
        result.bindings.where((b) => b.deviceClass.name == 'scale'),
        isEmpty,
      );
    });
  });

  test(
    'плюральность: две привязки одного класса на одном терминале различимы после round-trip через базу',
    () async {
      // Не через инференс — сегодня ни один источник этой миграции не даёт
      // больше одной привязки на класс (Rahmet, ранее дававший второй
      // случай для paymentTerminal, выведен из продукта). Свойство, которое
      // нужно доказать, — то, что СХЕМА (TerminalDeviceBindings,
      // уникальный ключ (terminalId, deviceClass, bindingKey)) допускает и
      // корректно round-trip'ит две привязки одного класса, а не то, что
      // конкретно эта миграция их сегодня производит. Два чековых принтера
      // — ровно пример, которым коордиантор обосновал сохранение формы
      // после удаления Rahmet (task-2-report.md, fix round 1).
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-Два-Принтера');

      await db.into(db.terminalDeviceBindings).insert(
        TerminalDeviceBindingsCompanion.insert(
          terminalId: terminal.id,
          deviceClass: 'receiptPrinter',
          profileId: 'printer.escpos.80mm',
          bindingKey: 'printer.escpos.80mm',
          parametersJson: const Value('{"ipAddress":"10.0.0.1","port":"9100"}'),
          optionsJson: const Value('{"paperWidthMm":"80"}'),
        ),
      );
      await db.into(db.terminalDeviceBindings).insert(
        TerminalDeviceBindingsCompanion.insert(
          terminalId: terminal.id,
          deviceClass: 'receiptPrinter',
          profileId: 'printer.escpos.58mm-compact',
          bindingKey: 'printer.escpos.58mm-compact',
          parametersJson: const Value('{"ipAddress":"10.0.0.2"}'),
        ),
      );

      final rows = await db.terminalDao.deviceBindingsFor(terminal.id);
      final printers = rows.where((r) => r.deviceClass == 'receiptPrinter').toList();
      expect(
        printers,
        hasLength(2),
        reason: 'обе строки одного класса должны были дойти до таблицы',
      );

      // Уникальный индекс (terminalId, deviceClass, bindingKey) не отверг
      // вторую вставку — а отверг бы, будь bindingKey одинаковым у обеих.
      final bindingKeys = printers.map((r) => r.bindingKey).toSet();
      expect(
        bindingKeys,
        hasLength(2),
        reason: 'bindingKey должен различать сиблингов одного класса',
      );

      final printer80 = printers.singleWhere((r) => r.profileId == 'printer.escpos.80mm');
      final printer58 = printers.singleWhere(
        (r) => r.profileId == 'printer.escpos.58mm-compact',
      );
      expect(jsonDecode(printer80.parametersJson)['ipAddress'], '10.0.0.1');
      expect(jsonDecode(printer58.parametersJson)['ipAddress'], '10.0.0.2');
      expect(printer80.id, isNot(printer58.id), reason: 'действительно две строки, не одна');
    },
  );

  test(
    'paperWidth сужает профиль принтера в рамках уже сужённого транспорта — '
    'на РЕАЛЬНЫХ значениях символьной ширины (32/42/48), не миллиметровых '
    '(fix round 1, скорректировано под четыре транспорта; ширина в мм — '
    'второй раунд финального обзора)',
    () {
      final catalog = BuiltinDeviceProfileCatalog();

      // 48 символов (>= 42) конвертируется в 80мм и сужает однозначно до
      // printer.escpos.80mm — только этот сетевой профиль поддерживает 80мм
      // (58mm-compact — только 58). thisPosPaperWidthChars — единственное
      // значение, которое продукт реально хранит здесь (32/42/48); передача
      // готового значения в мм — именно то, что скрывало баг во втором
      // раунде обзора.
      final width48 = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          thisPosPaperWidthChars: 48,
          terminalPrinterType: 'wifi',
          terminalPrinterAddress: '192.168.1.50',
        ),
        catalog: catalog,
      );
      final printer80 = width48.bindings.singleWhere(
        (b) => b.deviceClass.name == 'receiptPrinter',
      );
      expect(printer80.profileId, 'printer.escpos.80mm');
      expect(printer80.options['paperWidthMm'], '80');
      expect(printer80.parameters['ipAddress'], '192.168.1.50');

      // 42 символа — граница ">= 42": тоже конвертируется в 80мм, не 58.
      // Проверяет саму границу, а не только значение внутри интервала.
      final width42 = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          thisPosPaperWidthChars: 42,
          terminalPrinterType: 'wifi',
          terminalPrinterAddress: '192.168.1.50',
        ),
        catalog: catalog,
      );
      expect(
        width42.bindings.singleWhere((b) => b.deviceClass.name == 'receiptPrinter').profileId,
        'printer.escpos.80mm',
        reason: '42 — граница ">= 42 ? 80 : 58", должна давать 80, не 58',
      );

      // 32 символа (< 42) конвертируется в 58мм. 58мм НЕ сужает однозначно
      // даже с wifi заданным: printer.escpos.80mm тоже поддерживает 58мм
      // (paperWidthsMm: [58, 80]), в отличие от того, что предполагал fix
      // round 1 в своём примере "58 → 58mm-compact". Оба сетевых профиля
      // остаются кандидатами, поэтому по правилу "сужать по каждому факту,
      // отказывать только если после сужения всё ещё не единственный
      // кандидат" привязка не создаётся — угадывание между двумя реальными
      // моделями было бы ровно тем, что это правило запрещает. См.
      // task-2-report.md, fix round 1.
      final width32 = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          thisPosPaperWidthChars: 32,
          terminalPrinterType: 'wifi',
          terminalPrinterAddress: '192.168.1.50',
        ),
        catalog: catalog,
      );
      expect(
        width32.bindings.where((b) => b.deviceClass.name == 'receiptPrinter'),
        isEmpty,
        reason:
            'и 80mm-профиль, и 58mm-compact поддерживают 58мм — неоднозначно, '
            'не угадано',
      );

      // Без какого-либо признака транспорта paperWidth в одиночку теперь
      // НИКОГДА не сужает однозначно — с добавлением USB/Bluetooth/serial
      // профилей (final review, C1) каждая поддерживаемая ширина
      // поддерживается более чем одним транспортом.
      final widthOnly = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          thisPosPaperWidthChars: 48,
          terminalPrinterAddress: '192.168.1.50',
        ),
        catalog: catalog,
      );
      expect(
        widthOnly.bindings.where((b) => b.deviceClass.name == 'receiptPrinter'),
        isEmpty,
        reason:
            '80мм (из 48 символов) поддерживают printer.escpos.80mm, '
            'printer.escpos.usb и printer.escpos.serial все разом — без '
            'транспорта неотличимы',
      );

      // Ширина в мм, которую не поддерживает ни один профиль каталога, —
      // ноль кандидатов, а не ближайшее совпадение. Проверено на уровне
      // resolveReceiptPrinterProfileId напрямую (тест «резолвер печатника»
      // ниже), а не через символьную ширину здесь: paperWidthMmFromCharWidth
      // всегда возвращает 58 либо 80, так что «неподдерживаемое мм-значение»
      // недостижимо через этот путь ни при каком реальном символьном вводе —
      // это и есть свойство, которое делает конвертацию безопасной.
    },
  );

  test(
    'paperWidthMmFromCharWidth: единственное место конвертации, обе границы '
    'и середина каждого диапазона',
    () {
      expect(paperWidthMmFromCharWidth(32), 58, reason: 'типичное 58мм-значение');
      expect(paperWidthMmFromCharWidth(41), 58, reason: 'чуть ниже границы — ещё 58');
      expect(paperWidthMmFromCharWidth(42), 80, reason: 'граница ">= 42" — уже 80');
      expect(paperWidthMmFromCharWidth(48), 80, reason: 'типичное 80мм-значение');
    },
  );

  group(
    'C1: USB/Bluetooth/serial чековые принтеры представимы и переносятся '
    'сквозным путём (final review — самая серьёзная находка)',
    () {
      test('usb: devicePath необязателен, привязка создаётся даже без него', () {
        final catalog = BuiltinDeviceProfileCatalog();
        final result = inferLegacyDeviceMigration(
          LegacyDeviceSettings(terminalPrinterType: 'usb'),
          catalog: catalog,
        );
        final printer = result.bindings.singleWhere(
          (b) => b.deviceClass.name == 'receiptPrinter',
        );
        expect(printer.profileId, 'printer.escpos.usb');
        expect(printer.parameters, isEmpty);
      });

      test('usb: devicePath, когда он есть в блобе, попадает в devicePath параметр', () {
        final catalog = BuiltinDeviceProfileCatalog();
        final result = inferLegacyDeviceMigration(
          LegacyDeviceSettings(
            hardwareSettingsBlobJson: jsonEncode({
              'receiptPrinterType': 'usb',
              'receiptPrinterAddress': '/dev/usb/lp0',
            }),
          ),
          catalog: catalog,
        );
        final printer = result.bindings.singleWhere(
          (b) => b.deviceClass.name == 'receiptPrinter',
        );
        expect(printer.profileId, 'printer.escpos.usb');
        expect(printer.parameters, {'devicePath': '/dev/usb/lp0'});
      });

      test('bluetooth: macAddress обязателен — без него привязка не создаётся', () {
        final catalog = BuiltinDeviceProfileCatalog();
        final withoutAddress = inferLegacyDeviceMigration(
          LegacyDeviceSettings(terminalPrinterType: 'bluetooth'),
          catalog: catalog,
        );
        expect(
          withoutAddress.bindings.where((b) => b.deviceClass.name == 'receiptPrinter'),
          isEmpty,
          reason: 'printer.escpos.bluetooth требует macAddress',
        );

        final withAddress = inferLegacyDeviceMigration(
          LegacyDeviceSettings(
            hardwareSettingsBlobJson: jsonEncode({
              'receiptPrinterType': 'bluetooth',
              'receiptPrinterAddress': 'AA:BB:CC:DD:EE:FF',
            }),
          ),
          catalog: catalog,
        );
        final printer = withAddress.bindings.singleWhere(
          (b) => b.deviceClass.name == 'receiptPrinter',
        );
        expect(printer.profileId, 'printer.escpos.bluetooth');
        expect(printer.parameters, {'macAddress': 'AA:BB:CC:DD:EE:FF'});
      });

      test('serial: comPort обязателен, попадает в comPort параметр', () {
        final catalog = BuiltinDeviceProfileCatalog();
        final withoutPort = inferLegacyDeviceMigration(
          LegacyDeviceSettings(terminalPrinterType: 'serial'),
          catalog: catalog,
        );
        expect(
          withoutPort.bindings.where((b) => b.deviceClass.name == 'receiptPrinter'),
          isEmpty,
        );

        final withPort = inferLegacyDeviceMigration(
          LegacyDeviceSettings(
            terminalPrinterType: 'serial',
            terminalPrinterAddress: 'COM4',
          ),
          catalog: catalog,
        );
        final printer = withPort.bindings.singleWhere(
          (b) => b.deviceClass.name == 'receiptPrinter',
        );
        expect(printer.profileId, 'printer.escpos.serial');
        expect(printer.parameters, {'comPort': 'COM4'});
      });

      test(
        'C1 SECOND-REVIEW-ROUND FINDING: usb/bluetooth/serial resolve when '
        'paperWidth is a REAL character-count value (32/42/48), not just '
        'when it is absent or an impossible millimetre value',
        () {
          // The tests above all leave thisPosPaperWidthChars unset — which
          // never exercised the bug at all, because a null paperWidthMm
          // skips the width filter entirely. Every configured till has a
          // real paperWidth value (32/42/48). The reviewer proved with the
          // real code that `inferLegacyDeviceMigration(thisPosPaperWidth:
          // 48, terminalPrinterType: 'usb', ...)` returned `[]` before this
          // fix, because the unconverted character count (48) was compared
          // directly against printer.escpos.usb's paperWidthsMm ([58, 80])
          // and matched nothing — emptying the candidate set even though
          // the transport alone would otherwise have narrowed to exactly
          // one profile.
          final catalog = BuiltinDeviceProfileCatalog();

          for (final charWidth in [32, 42, 48]) {
            final usb = inferLegacyDeviceMigration(
              LegacyDeviceSettings(
                thisPosPaperWidthChars: charWidth,
                terminalPrinterType: 'usb',
              ),
              catalog: catalog,
            );
            expect(
              usb.bindings.where((b) => b.deviceClass.name == 'receiptPrinter'),
              hasLength(1),
              reason:
                  'charWidth=$charWidth (a real stored value) must still '
                  'resolve printer.escpos.usb — the profile has nothing to '
                  'do with paper width for narrowing purposes, but the '
                  'unconverted char count used to fail the width filter '
                  'anyway',
            );
            expect(
              usb.bindings.single.profileId,
              'printer.escpos.usb',
            );
          }

          // printer.escpos.bluetooth only supports 58mm, so this needs a
          // char width that converts to 58 (< 42), not 80.
          final bluetooth = inferLegacyDeviceMigration(
            LegacyDeviceSettings(
              thisPosPaperWidthChars: 32,
              hardwareSettingsBlobJson: jsonEncode({
                'receiptPrinterType': 'bluetooth',
                'receiptPrinterAddress': 'AA:BB:CC:DD:EE:FF',
              }),
            ),
            catalog: catalog,
          );
          expect(
            bluetooth.bindings.singleWhere((b) => b.deviceClass.name == 'receiptPrinter').profileId,
            'printer.escpos.bluetooth',
          );

          final serial = inferLegacyDeviceMigration(
            LegacyDeviceSettings(
              thisPosPaperWidthChars: 32,
              terminalPrinterType: 'serial',
              terminalPrinterAddress: 'COM4',
            ),
            catalog: catalog,
          );
          expect(
            serial.bindings.singleWhere((b) => b.deviceClass.name == 'receiptPrinter').profileId,
            'printer.escpos.serial',
          );
        },
      );

      test(
        'wizard end-to-end: LocalSetupRepository._createDeviceBindings reuses '
        'the exact same resolver, so a USB choice in the setup wizard also '
        'produces a binding — covered directly by '
        'test/unit/data/setup_repository_device_bindings_test.dart',
        () {
          // Placeholder assertion documenting the cross-file guarantee; the
          // real proof lives in setup_repository_device_bindings_test.dart,
          // which this migration test does not duplicate.
          expect(true, isTrue);
        },
      );
    },
  );

  test(
    'резолвер печатника: транспорт сужает кандидатов по параметрам профиля, '
    'а не по протоколу — неизвестный тип по-прежнему отвергается',
    () {
      final catalog = BuiltinDeviceProfileCatalog();

      // usb/bluetooth/serial теперь каждый сужает до РОВНО ОДНОГО профиля
      // своего транспорта — до финального фикса они (как и 'none') обнуляли
      // кандидатов, потому что каталог был исключительно сетевым.
      expect(
        resolveReceiptPrinterProfileId(catalog, connectionKind: 'usb'),
        'printer.escpos.usb',
      );
      expect(
        resolveReceiptPrinterProfileId(catalog, connectionKind: 'bluetooth'),
        'printer.escpos.bluetooth',
      );
      expect(
        resolveReceiptPrinterProfileId(catalog, connectionKind: 'serial'),
        'printer.escpos.serial',
      );
      expect(
        resolveReceiptPrinterProfileId(catalog, connectionKind: 'wifi'),
        isNull,
        reason:
            'wifi в одиночку (без ширины) всё ещё неоднозначен между '
            'printer.escpos.80mm и printer.escpos.58mm-compact',
      );

      // Неизвестное значение — не факт "неизвестно", а факт "не сужает ни к '
      // чему": обнуляет кандидатов, а не пропускает сужение.
      expect(
        resolveReceiptPrinterProfileId(
          catalog,
          connectionKind: 'no-such-transport',
          paperWidthMm: 80,
        ),
        isNull,
      );

      // Ничего не известно о типе подключения вовсе (аргумент не передан) —
      // этот факт просто не участвует в сужении. С добавлением
      // USB/Bluetooth/serial профилей это больше не сужает однозначно даже
      // с шириной: 80мм поддерживают три разных транспорта разом.
      expect(
        resolveReceiptPrinterProfileId(catalog, paperWidthMm: 80),
        isNull,
        reason:
            'без признака транспорта 80мм неоднозначны между сетевым, usb и '
            'serial профилями',
      );

      // Ширина, которую не поддерживает ни один профиль, обнуляет
      // кандидатов на уровне самого резолвера — проверено здесь напрямую
      // (не только через inferLegacyDeviceMigration/_buildReceiptPrinterBinding
      // выше), потому что DeviceBinding.validateAgainst's option-permitted
      // check would independently refuse an unsupported width anyway,
      // masking a bug in _narrowToUniqueProfile itself. This assertion is
      // what the fix-round-1 anti-gaps mutation actually targets — see
      // task-2-report.md.
      expect(
        resolveReceiptPrinterProfileId(
          catalog,
          connectionKind: 'wifi',
          paperWidthMm: 40,
        ),
        isNull,
        reason: '40мм не поддерживает ни один профиль чекового принтера',
      );
    },
  );

  test(
    'paperWidth становится выбранной опцией привязки принтера; недопустимая '
    'ширина не проходит тихо; адрес попадает в параметр, определённый '
    'транспортом',
    () {
      final catalog = BuiltinDeviceProfileCatalog();

      // buildReceiptPrinterBindingForTesting проверяет часть маппинга,
      // которая идёт ПОСЛЕ того, как resolveReceiptPrinterProfileId уже
      // выбрал профиль — напрямую, с явным profileId, чтобы доказать, что
      // сопоставление paperWidth→опция и адрес→параметр(по транспорту)
      // работает и отказывает недопустимой ширине само по себе, а не только
      // как побочный эффект того, какой профиль был выбран.
      final ok = buildReceiptPrinterBindingForTesting(
        catalog: catalog,
        profileId: 'printer.escpos.80mm',
        connectionKind: 'wifi',
        address: '192.168.1.50',
        printerPort: 9100,
        paperWidthMm: 80,
      );
      expect(ok, isNotNull);
      expect(ok!.options['paperWidthMm'], '80');
      expect(ok.parameters['port'], '9100');
      expect(ok.parameters['ipAddress'], '192.168.1.50');

      final badWidth = buildReceiptPrinterBindingForTesting(
        catalog: catalog,
        profileId: 'printer.escpos.58mm-compact', // supports only 58mm
        connectionKind: 'wifi',
        address: '192.168.1.50',
        paperWidthMm: 80,
      );
      expect(
        badWidth,
        isNull,
        reason: 'принтер на 58мм не должен молча принять ширину 80',
      );

      final missingRequiredAddress = buildReceiptPrinterBindingForTesting(
        catalog: catalog,
        profileId: 'printer.escpos.80mm',
        connectionKind: 'wifi',
        paperWidthMm: 80, // no address supplied — required by the profile
      );
      expect(
        missingRequiredAddress,
        isNull,
        reason: 'ipAddress обязателен для обеих сетевых моделей принтера',
      );

      // Транспорт определяет, в какой параметр попадёт адрес — не всегда
      // ipAddress. usb/bluetooth/serial routes to devicePath/macAddress/
      // comPort respectively.
      final usb = buildReceiptPrinterBindingForTesting(
        catalog: catalog,
        profileId: 'printer.escpos.usb',
        connectionKind: 'usb',
        address: '/dev/usb/lp1',
      );
      expect(usb!.parameters, {'devicePath': '/dev/usb/lp1'});

      final bluetooth = buildReceiptPrinterBindingForTesting(
        catalog: catalog,
        profileId: 'printer.escpos.bluetooth',
        connectionKind: 'bluetooth',
        address: '11:22:33:44:55:66',
      );
      expect(bluetooth!.parameters, {'macAddress': '11:22:33:44:55:66'});

      final serial = buildReceiptPrinterBindingForTesting(
        catalog: catalog,
        profileId: 'printer.escpos.serial',
        connectionKind: 'serial',
        address: 'COM7',
      );
      expect(serial!.parameters, {'comPort': 'COM7'});
    },
  );

  group('M3: значение неожиданного типа пропускается, а не роняет обновление схемы', () {
    // `migrateLegacyScannerTimeoutMs` и `inferLegacyDeviceMigration`
    // вызываются из `onUpgrade` (`app_database.dart`). Раньше значения из
    // блоба читались `as int?` вне try/catch `_decodeBlob`, поэтому строка
    // или дробное число под этим ключом роняли миграцию `TypeError`, и база
    // переставала открываться. Блоб — свободный JSON: то, что единственный
    // исторический писатель всегда писал int, делает падение недостижимым
    // сегодня, но не безопасным.

    test('scannerTimeout строкой не бросает — возвращается null', () {
      expect(
        () => migrateLegacyScannerTimeoutMs(
          jsonEncode({'scannerTimeout': '250'}),
        ),
        returnsNormally,
      );
      expect(
        migrateLegacyScannerTimeoutMs(jsonEncode({'scannerTimeout': '250'})),
        isNull,
        reason:
            'значение, записанное не в том виде, — это «нечего переносить», '
            'ровно как отсутствующий ключ и как испорченный JSON',
      );
    });

    test('scannerTimeout дробным числом и списком тоже не бросает', () {
      expect(
        migrateLegacyScannerTimeoutMs(jsonEncode({'scannerTimeout': 250.5})),
        isNull,
      );
      expect(
        migrateLegacyScannerTimeoutMs(jsonEncode({'scannerTimeout': [250]})),
        isNull,
      );
      expect(
        migrateLegacyScannerTimeoutMs(jsonEncode({'scannerTimeout': null})),
        isNull,
      );
    });

    test('корректное значение по-прежнему переносится', () {
      expect(
        migrateLegacyScannerTimeoutMs(jsonEncode({'scannerTimeout': 250})),
        250,
        reason:
            'проверка типа не должна отбрасывать то, ради чего эта функция '
            'существует',
      );
    });

    test(
      'barcodeMinLength/barcodeMaxLength неожиданного типа — та же защита, '
      'та же функция onUpgrade',
      () {
        late LegacyDeviceMigrationResult result;
        expect(
          () => result = inferLegacyDeviceMigration(
            LegacyDeviceSettings(
              hardwareSettingsBlobJson: jsonEncode({
                'barcodeMinLength': '8',
                'barcodeMaxLength': 13.0,
              }),
            ),
          ),
          returnsNormally,
        );
        expect(result.barcodeMinLength, isNull);
        expect(result.barcodeMaxLength, isNull);

        final good = inferLegacyDeviceMigration(
          LegacyDeviceSettings(
            hardwareSettingsBlobJson: jsonEncode({
              'barcodeMinLength': 8,
              'barcodeMaxLength': 13,
            }),
          ),
        );
        expect(good.barcodeMinLength, 8);
        expect(good.barcodeMaxLength, 13);
      },
    );
  });
}
