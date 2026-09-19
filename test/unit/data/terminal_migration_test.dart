import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

/// Column/table names and `CREATE TABLE` SQL for `ThisPosEntries`, read off
/// a throwaway v26 database instead of hand-typed — `ThisPosEntries` has not
/// changed since v22, so what `onCreate` produces today is exactly what a
/// v25 install already had, and the test can't silently drift out of sync
/// with the real table.
class _ThisPosEntriesShape {
  _ThisPosEntriesShape({
    required this.createSql,
    required this.tableName,
    required this.rIdColumn,
    required this.cashBoxNameColumn,
    required this.usersCreateSql,
    required this.salesCreateSql,
  });

  final String createSql;
  final String tableName;
  final String rIdColumn;
  final String cashBoxNameColumn;

  // Задача 15/16 (замок кассы, фаза 5): схема поднимается до 33, и открытие
  // с `PRAGMA user_version = 25` теперь проходит и блок `if (from < 33)`
  // (`UserPermissionDao`), который читает `users` через
  // `userDao.findAll()`. Эта фикстура никогда не заводила `users` — он ей
  // не был нужен ни для чего своего, только чтобы пережить более позднюю
  // миграцию, добавленную после неё. Настоящая база апгрейда всегда имела
  // `users` (таблица существует с версии 1), поэтому это пробел фикстуры, а
  // не свойство реального апгрейда.
  final String usersCreateSql;

  // Задача 2 плана «продажа с браузерного терминала»: схема поднимается до
  // 37, и открытие с `PRAGMA user_version = 25` теперь проходит и блок
  // `if (from < 37)`, который трогает существующую таблицу `sales` (`ADD
  // COLUMN` трижды). Та же причина, что у `usersCreateSql` выше: без неё
  // подъём падает на `no such table: sales`, хотя настоящая база апгрейда
  // имеет `sales` с самой первой схемы.
  final String salesCreateSql;
}

Future<_ThisPosEntriesShape> _readThisPosEntriesShape() async {
  final probe = AppDatabase(NativeDatabase.memory());
  final table = probe.thisPosEntries;
  final row = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(table.actualTableName)],
      )
      .getSingle();
  final usersRow = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'users'",
      )
      .getSingle();
  await probe.customStatement(
    'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN terminal_id',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN cart_version',
  );
  await probe.customStatement(
    'ALTER TABLE ${probe.sales.actualTableName} DROP COLUMN last_command_key',
  );
  final salesRow = await probe
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'sales'",
      )
      .getSingle();
  final shape = _ThisPosEntriesShape(
    createSql: row.read<String>('sql'),
    tableName: table.actualTableName,
    rIdColumn: table.rId.name,
    cashBoxNameColumn: table.cashBoxName.name,
    usersCreateSql: usersRow.read<String>('sql'),
    salesCreateSql: salesRow.read<String>('sql'),
  );
  await probe.close();
  return shape;
}

/// Opens an in-memory database pre-seeded to look like schema 25: only
/// `ThisPosEntries` exists (created via raw SQL in `setup`, which runs
/// before drift's migration machinery), and `PRAGMA user_version` is forced
/// to 25 so opening this database through `AppDatabase` triggers exactly the
/// `if (from < 26)` branch — nothing lower fires, because `from` is already
/// 25.
AppDatabase _openAsIfMigratingFromV25(
  _ThisPosEntriesShape shape, {
  void Function(sqlite3.Database raw, _ThisPosEntriesShape shape)? seedRow,
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(shape.createSql);
        raw.execute(shape.usersCreateSql);
        raw.execute(shape.salesCreateSql);
        raw.execute('PRAGMA user_version = 25');
        if (seedRow != null) {
          seedRow(raw, shape);
        }
      },
    ),
  );
}

void main() {
  test('таблица терминалов существует на текущей схеме', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Не проверяем здесь конкретное число schemaVersion: это уже дважды
    // ломало файл на ровном месте (25→26, затем 26→27), хотя миграция
    // v25→v26 для Terminals, которую тестирует этот файл, не менялась ни
    // разу. Инвариант «каждый бамп версии сопровождён миграционной веткой»
    // проверяется один раз и по-настоящему в
    // test/data/database/app_database_test.dart.

    // Пустая база создаётся onCreate; таблица должна быть.
    final rows = await db.select(db.terminals).get();
    expect(rows, isEmpty);
  });

  test('первый терминал создаётся с именем кассы из настроек установки', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

    final self = await db.terminalDao.self();
    expect(self, isNotNull);
    expect(self!.name, 'Касса-1');
    expect(self.isSelf, isTrue);
  });

  test('ensureSelf идемпотентен', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    await db.terminalDao.ensureSelf(fallbackName: 'Другое имя');

    final all = await db.select(db.terminals).get();
    expect(all, hasLength(1), reason: 'повтор не создаёт второй терминал');
    expect(all.single.name, 'Касса-1', reason: 'имя не перезаписывается');
  });

  test('несколько терминалов на всех пяти языках продукта находятся корректно', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final names = [
      'Кассаүй', // kk
      'Дүкен №2', // kk
      'Ысык-Көл', // ky
      'Касса №5', // ru
      "Do'kon-3", // uz (латиница)
      'Register-3', // en (ascii)
    ];
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (final name in names) {
      await db.into(db.terminals).insert(
            TerminalsCompanion.insert(
              name: name,
              isSelf: Value(name == 'Ысык-Көл'),
              createdAt: createdAt,
            ),
          );
    }

    final all = await db.terminalDao.all();
    expect(all, hasLength(names.length));
    expect(
      all.map((t) => t.name).toSet(),
      equals(names.toSet()),
      reason: 'все имена, включая казахскую и киргизскую кириллицу, должны сохраняться и читаться без потерь',
    );

    final self = await db.terminalDao.self();
    expect(self, isNotNull);
    expect(self!.name, 'Ысык-Көл', reason: 'поиск по isSelf должен находить именно терминал с кириллическим именем');
  });

  test(
    'миграция v25→v26 без ThisPosEntries не создаёт терминал; ensureSelf позже создаёт его с настоящим именем',
    () async {
      final shape = await _readThisPosEntriesShape();
      final db = _openAsIfMigratingFromV25(shape); // no row inserted at all
      addTearDown(db.close);

      final afterMigration = await db.select(db.terminals).get();
      expect(
        afterMigration,
        isEmpty,
        reason:
            'без сконфигурированной установки миграция не должна выдумывать имя терминала',
      );

      final created = await db.terminalDao.ensureSelf(
        fallbackName: 'Касса Реальная',
      );
      expect(
        created.name,
        'Касса Реальная',
        reason:
            'настоящее имя из мастера установки не должно теряться из-за миграции',
      );

      final all = await db.select(db.terminals).get();
      expect(all, hasLength(1));
    },
  );

  test(
    'миграция v25→v26 со сконфигурированной установкой переносит имя кассы в '
    'терминал 1 и помечает его self',
    () async {
      // ThisPosEntries.printerConnectionType/.printerAddress/.printerPort no
      // longer exist at all (schema v27, final review finding I1 — dropped
      // in app_database.dart's `if (from < 27)` block; they carried an
      // unusable second int encoding with no reader). Nor do any of the
      // seven raw `Terminals` device columns (printerType/printerAddress/
      // scannerType/scalePort/scaleBaudRate/drawerViaPrinter/displayPort) —
      // plan 2, task 5 dropped those (see app_database.dart's `if (from <
      // 26)` block): terminal device settings live in
      // TerminalDeviceBindings, read/written through DeviceBindingRepository,
      // not raw columns. Nothing printer-related survives to seed here any
      // more — the test is narrowed to what still transfers: name and
      // isSelf.
      final shape = await _readThisPosEntriesShape();
      final db = _openAsIfMigratingFromV25(
        shape,
        seedRow: (raw, shape) {
          raw.execute(
            'INSERT INTO ${shape.tableName} '
            '(${shape.rIdColumn}, ${shape.cashBoxNameColumn}) '
            "VALUES (1, 'Касса-Настоящая')",
          );
        },
      );
      addTearDown(db.close);

      final all = await db.select(db.terminals).get();
      expect(all, hasLength(1));
      expect(all.single.name, 'Касса-Настоящая');
      expect(all.single.isSelf, isTrue);
    },
  );

  test(
    'миграция v25→v26: строка ThisPosEntries есть, но cashBoxName = NULL — терминал не создаётся',
    () async {
      final shape = await _readThisPosEntriesShape();
      final db = _openAsIfMigratingFromV25(
        shape,
        seedRow: (raw, shape) {
          // cashBoxName сознательно не указан — NULL по умолчанию.
          raw.execute(
            'INSERT INTO ${shape.tableName} (${shape.rIdColumn}) VALUES (1)',
          );
        },
      );
      addTearDown(db.close);

      final all = await db.select(db.terminals).get();
      expect(
        all,
        isEmpty,
        reason:
            'строка установки есть, но без названия кассы — это не считается '
            'сконфигурированной установкой',
      );
    },
  );

  test(
    'миграция v25→v26: cashBoxName состоит только из пробелов — терминал не создаётся',
    () async {
      final shape = await _readThisPosEntriesShape();
      final db = _openAsIfMigratingFromV25(
        shape,
        seedRow: (raw, shape) {
          raw.execute(
            'INSERT INTO ${shape.tableName} '
            '(${shape.rIdColumn}, ${shape.cashBoxNameColumn}) '
            "VALUES (1, '   ')",
          );
        },
      );
      addTearDown(db.close);

      final all = await db.select(db.terminals).get();
      expect(
        all,
        isEmpty,
        reason:
            'пробельное название кассы после trim() пусто — установка '
            'считается несконфигурированной, как и с NULL',
      );
    },
  );

  test(
    'ensureSelf безопасен при одновременном вызове: ровно один терминал, оба вызова видят победителя, self() не падает',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Ключевое отличие от "ensureSelf идемпотентен" выше: там вызовы шли
      // последовательно (await между ними), что никогда не могло поймать
      // гонку. Здесь оба вызова стартуют без ожидания друг друга.
      final results = await Future.wait([
        db.terminalDao.ensureSelf(fallbackName: 'Терминал A'),
        db.terminalDao.ensureSelf(fallbackName: 'Терминал B'),
      ]);

      final all = await db.select(db.terminals).get();
      expect(
        all,
        hasLength(1),
        reason:
            'одновременный запуск с двух сторон не должен создавать вторую '
            'строку isSelf=true',
      );

      expect(
        results[0].id,
        results[1].id,
        reason: 'оба вызова должны сойтись на одном и том же терминале-победителе',
      );

      final self = await db.terminalDao.self();
      expect(
        self,
        isNotNull,
        reason:
            'self() использует getSingleOrNull() и падает при более чем '
            'одной строке — после гонки он должен по-прежнему работать',
      );
    },
  );

  test(
    'частичный уникальный индекс отклоняет вторую параллельную «сырую» вставку isSelf=true в обход ensureSelf',
    () async {
      // Тест выше гоняет ensureSelf() параллельно, но drift.transaction()
      // сам по себе уже полностью сериализует конкурентные вызовы на одном
      // подключении (проверено отдельно: тело второй transaction() не
      // стартует, пока не завершится первая) — поэтому тот тест проходит
      // даже без индекса и не может служить доказательством, что нужен
      // именно индекс. Структурная гарантия существует для случаев, которые
      // транзакция DAO не видит: два прямых INSERT в обход ensureSelf,
      // как было бы со вторым подключением/процессом. Здесь оба вызова идут
      // напрямую через into(terminals).insert(), без ensureSelf и без
      // транзакции, поэтому только индекс может остановить второй.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      Future<Object?> insertSelfCapturingError(String name) async {
        try {
          await db.into(db.terminals).insert(
            TerminalsCompanion.insert(
              name: name,
              isSelf: const Value(true),
              createdAt: 1000,
            ),
          );
          return null;
        } catch (e) {
          return e;
        }
      }

      final errors = await Future.wait([
        insertSelfCapturingError('Терминал A'),
        insertSelfCapturingError('Терминал B'),
      ]);

      expect(
        errors.where((e) => e != null),
        hasLength(1),
        reason:
            'ровно одна из двух параллельных сырых вставок должна быть '
            'отклонена индексом — без него обе бы успешно вставились',
      );

      final all = await db.select(db.terminals).get();
      expect(all, hasLength(1));
    },
  );
}
