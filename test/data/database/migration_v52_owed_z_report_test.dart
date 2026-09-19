/// Миграция v51→v52: долг по Z-отчёту.
///
/// # Что здесь проверяется, кроме «таблица появилась»
///
/// **Что на поднятой базе долг можно записать и прочитать.** Таблица,
/// созданная миграцией, отличается от объявленной в схеме ровно тем, что
/// её DDL пишет другой код; проверять её наличие через `PRAGMA` и не
/// пробовать записать значило бы поверить DDL на слово.
///
/// **Что переноса нет и он пуст честно.** Долгов, накопленных до v52,
/// вывести не из чего: задержка Z нигде не записывалась. Выдуманный долг
/// заставил бы кассу послать Z за смену, давно закрытую чужим отчётом, —
/// то есть завёл бы ровно ту беду, от которой таблица заводится.
///
/// # Чего здесь нет намеренно
///
/// Правила «когда долг гасится» — оно принадлежит службе смены и меряется
/// в `test/data/services/owed_z_report_test.dart` против эмулятора на
/// сокете. Здесь — только подъём.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

void main() {
  /// База, доведённая до состояния v51, поверх которой открывается
  /// настоящая — открытие и есть миграция.
  ///
  /// Схема берётся **из настоящего DDL текущей версии** и урезается, а не
  /// пишется руками (разбор — в пробе v44).
  Future<AppDatabase> openFromPrevious() async {
    final probe = AppDatabase.forTesting(NativeDatabase.memory());
    final ddl =
        (await probe
                .customSelect(
                  'SELECT sql FROM sqlite_master '
                  "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
                )
                .get())
            .map((r) => r.read<String>('sql'))
            .toList();
    await probe.close();

    final raw = sqlite3.sqlite3.openInMemory();
    for (final statement in ddl) {
      raw.execute(statement);
    }
    // Таблица v52 снимается с фикстуры — иначе проба зеленела бы и без
    // миграции.
    raw.execute('DROP TABLE fiscal_owed_reports');
    raw.execute('PRAGMA user_version = 51');

    expect(
      raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String),
      isNot(contains('fiscal_owed_reports')),
      reason: 'фикстура уже содержит таблицу v52 — мерить нечего',
    );

    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  test('свежая база: долгов нет', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.fiscalOwedReportDao.current(), isNull);
  });

  test('подъём с v51 заводит таблицу и не выдумывает долгов', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    final tables =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(tables, contains('fiscal_owed_reports'));

    expect(
      await db.fiscalOwedReportDao.current(),
      isNull,
      reason:
          'переноса нет: задержка Z до v52 нигде не записывалась, и '
          'выдуманный долг послал бы отчёт за чужую смену',
    );
  });

  test('на поднятой базе долг пишется, не двоится и гасится со следом', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    final at = DateTime.fromMillisecondsSinceEpoch(1758000000000);
    final first = await db.fiscalOwedReportDao.owe(
      shiftId: 7,
      at: at,
      documentsWaiting: 3,
    );
    expect(first.shiftId, 7);
    expect(first.documentsWaiting, 3);
    expect(first.settledAt, isNull);

    final second = await db.fiscalOwedReportDao.owe(
      shiftId: 8,
      at: at.add(const Duration(days: 1)),
      documentsWaiting: 1,
    );
    expect(
      second.id,
      first.id,
      reason: 'смена оператора одна — второй строки не заводится',
    );

    await db.fiscalOwedReportDao.noteAttempt(id: first.id, reason: 'оператор');
    await db.fiscalOwedReportDao.noteAttempt(id: first.id, reason: 'оператор');
    expect(
      (await db.fiscalOwedReportDao.current())!.attempts,
      2,
      reason: 'счётчик двигает sqlite, а не чтение в память',
    );

    final closed = await db.fiscalOwedReportDao.settleAll(
      at: at.add(const Duration(days: 1, hours: 8)),
      by: 'досылка',
    );
    expect(closed, 1);
    expect(await db.fiscalOwedReportDao.current(), isNull);

    final rows = await db.select(db.fiscalOwedReports).get();
    expect(
      rows,
      hasLength(1),
      reason: 'погашенная строка остаётся: у расхождения должен быть след',
    );
    expect(rows.single.settledBy, 'досылка');
  });
}
