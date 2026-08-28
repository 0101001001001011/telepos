import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';

/// Подсистема отчётов об ошибках удалена целиком. Этот файл — замок на то,
/// чтобы она не вернулась незаметно.
///
/// Что было и почему убрано (измерено 2026-08-04 на `redesign/telegram-light`):
///
///  * существовало ДВА класса `BugReportService` — `lib/core/bug_report/` на
///    236 строк и `lib/app/services/` на 192 — то есть буквально та самая
///    параллельная реализация, которую правила проекта запрещают;
///  * ни один из них не создавался нигде: `BugReportService(`,
///    `ErrorCatcher(`, `BugReportStorageImpl(` грепом по всему дереву
///    находились только в собственных объявлениях, в DI ничего не
///    регистрировалось;
///  * единственными импортёрами файлов подсистемы были другие файлы той же
///    подсистемы — замкнутый остров; оба «ствола» реэкспортов
///    (`bug_report_exports.dart`, `services_exports.dart`) не импортировал
///    никто;
///  * ни экрана, ни пункта меню, ни маршрута к отправке; в
///    `docs/system-architecture.md` нет ни одного упоминания отчётов об
///    ошибках и ни одного инварианта на них;
///  * обе «отправки» были заглушками: `Future.delayed(100 мс)` и пометка
///    `isSent = true` без единого сетевого вызова;
///  * `initialize(appVersion: ...)` не вызывался, так что версия в отчёте
///    всё равно осталась бы `'unknown'`.
///
/// При этом живой путь для ошибок в приложении уже есть и он другой:
/// `runZonedGuarded` и `FlutterError.onError` в `lib/main.dart` сводят всё в
/// talker и дальше в RFC 5424 syslog. Подсистема была вторым, никогда не
/// подключённым механизмом, который создавал впечатление, что отчёты
/// собираются и уходят. Мёртвый код, выглядящий работающим, хуже
/// отсутствующего — поэтому удалён, а не «подключён на будущее».
void main() {
  group('подсистема отчётов об ошибках не возвращается', () {
    test('в lib/ нет ни одного класса BugReportService', () {
      final offenders = _libDartFiles()
          .where(
            (f) => RegExp(
              r'^\s*class\s+BugReportService\b',
              multiLine: true,
            ).hasMatch(f.readAsStringSync()),
          )
          .map((f) => f.path)
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'Класс BugReportService объявлен заново. Подсистема отчётов об '
            'ошибках удалена намеренно: она никогда не была подключена, а её '
            'отправка была заглушкой. Живой путь для ошибок — '
            'runZonedGuarded/FlutterError.onError в lib/main.dart → talker → '
            'RFC 5424 syslog. Если отчёты действительно нужны, это надо '
            'сначала объявить инвариантом в docs/system-architecture.md, а не '
            'вносить вторую реализацию рядом с логированием.',
      );
    });

    test('в lib/ не осталось файлов подсистемы и мёртвых реэкспортов', () {
      final files = _libDartFiles();

      // Ни одного файла с bug_report в пути. Именно так подсистема и
      // выглядела: отдельная папка core/bug_report + двойник в app/services.
      final byPath = files
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.contains('bug_report'))
          .toList();
      expect(byPath, isEmpty, reason: 'Файлы подсистемы вернулись: $byPath');

      // Реэкспорт живёт дольше самого кода и делает мёртвое похожим на
      // работающее — ровно это здесь и произошло в прошлый раз.
      final byExport = <String>[];
      for (final f in files) {
        if (RegExp(
          '''^\\s*export\\s+['"][^'"]*bug_report[^'"]*['"]''',
          multiLine: true,
        ).hasMatch(f.readAsStringSync())) {
          byExport.add(f.path);
        }
      }
      expect(
        byExport,
        isEmpty,
        reason: 'Реэкспорт удалённого файла подсистемы: $byExport',
      );
    });

    test('в свежей схеме нет таблицы bug_reports', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name = 'bug_reports'",
          )
          .get();

      expect(
        rows,
        isEmpty,
        reason:
            'Таблица bug_reports создаётся заново на чистой установке. У неё '
            'никогда не было писателя, кроме удалённого BugReportStorageImpl.',
      );
    });

    test('база schema 30 с таблицей bug_reports теряет её при обновлении', () async {
      // Тот самый случай, ради которого поднята schema 31: установка,
      // которая таблицу уже получила.
      //
      // Фикстура строится из ТЕКУЩЕЙ полной схемы, а не вручную по столбцу —
      // приём из `test/unit/data/print_job_store_test.dart`
      // (группа «миграция v28 → v29 на установке с данными»: открыть на
      // полной схеме, закрыть, переоткрыть тот же файл с `setup:`,
      // подделывающим более раннюю версию). До этой правки фикстура была
      // собрана вручную — единственная таблица `bug_reports` плюс
      // `PRAGMA user_version = 30` — и комментарий здесь утверждал, что
      // прогон сводится к единственной ветке `if (from < 31)`, потому что
      // на момент, когда это писалось, 31 была старшей версией схемы. Это
      // было верно ровно до тех пор, пока схема не поднялась: `if (from <
      // 32)` (задача «вход браузерного терминала», две колонки на
      // `this_pos_entries`) — вторая ветка на пути от 30 к текущей версии
      // — и ручная фикстура, не создававшая `this_pos_entries` вовсе,
      // роняла прогон на «no such table: this_pos_entries» ещё до
      // проверки, ради которой тест написан.
      //
      // База, собранная из полного `onCreate`, везёт вперёд каждую таблицу
      // и колонку, какие есть сегодня, — значит любая будущая ветка
      // `if (from < N)`, включая ещё не написанную, находит свою таблицу
      // готовой (а `_safeAddColumn` идемпотентна и тихо пропускает уже
      // существующую колонку — `lib/data/database/app_database.dart`).
      // Единственное, что фикстура заводит вручную, — сама `bug_reports`:
      // её и не может быть в сегодняшнем `onCreate`, она удалена из схемы
      // именно этой миграцией, и это ровно то состояние «установка на
      // v30, ещё не потерявшая таблицу», которое тест обязан воссоздать.
      // Поднятие схемы дальше дописывает следующую ветку миграции; эту
      // фикстуру чинить снова не придётся.
      final tempDir = Directory.systemTemp.createTempSync(
        'telepos_bug_report_migration',
      );
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {
          // Windows иногда ещё держит файл мгновение после close() — каталог
          // временный и будет убран системой.
        }
      });
      final dbPath = '${tempDir.path}${Platform.pathSeparator}migration.sqlite';

      // Проход 1: обычное открытие на текущей полной схеме — `onCreate`
      // создаёт всё, включая `this_pos_entries` со всеми её сегодняшними
      // колонками.
      final fresh = AppDatabase(NativeDatabase(File(dbPath)));
      await fresh.checkpointWal();
      await fresh.close();

      // Проход 2: тот же файл, но с ручной подделкой — установка на v30,
      // у которой таблица `bug_reports` уже есть. Больше ничего не
      // тронуто: всё остальное — то, что оставил проход 1.
      final db = AppDatabase(
        NativeDatabase(
          File(dbPath),
          setup: (raw) {
            raw.execute(
              'CREATE TABLE bug_reports ('
              'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
              'version TEXT NULL, '
              'create_time INTEGER NULL, '
              'message TEXT NULL, '
              'stacktrace TEXT NULL, '
              'synced INTEGER NOT NULL DEFAULT 0)',
            );
            raw.execute('PRAGMA user_version = 30');
          },
        ),
      );
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name = 'bug_reports'",
          )
          .get();

      expect(
        rows,
        isEmpty,
        reason:
            'Миграция 30 → 31 не убрала таблицу bug_reports: установка, у '
            'которой она уже была, унесёт её дальше вместе со схемой.',
      );
    });
  });
}

/// Все `.dart` под `lib/`. Тест исходников, а не поведения: сама возможность
/// объявить второй класс с этим именем ловится только чтением дерева.
List<File> _libDartFiles() {
  final lib = Directory('lib');
  expect(
    lib.existsSync(),
    isTrue,
    reason: 'Тест обязан запускаться из корня пакета — lib/ не найден',
  );
  return lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}
