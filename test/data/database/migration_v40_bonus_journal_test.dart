/// Миграция v39→v40 (задача 13): бонусный остаток получает журнал.
///
/// # Главное утверждение здесь — «сверка не покраснела в первый же день»
///
/// Не «таблица появилась». Инвариант этой работы — «остаток бонусного
/// счёта равен сумме журнала», и он обязан держаться **с первой секунды
/// после обновления**. Пустой журнал при непустом остатке дал бы
/// расхождение у каждого клиента, у кого бонусы есть; объяснить его было
/// бы нечем; сторож обесценился бы в тот же день, а обесценившийся сторож
/// отключают.
///
/// Фикстура строится тем же приёмом, что `migration_v39_limits_test.dart`:
/// вид предыдущей версии получается сносом настоящей таблицы над настоящей
/// текущей схемой, а не переписыванием DDL руками.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';

/// Настоящий DDL перечисленных таблиц — из свежей базы текущей схемы.
///
/// Фикстура, написанная руками, расходится со схемой на первой же правке и
/// начинает проверять вымышленную базу. Первая редакция этой пробы так и
/// сделала — объявила `accounts` тремя колонками, — и покраснела не на
/// дефекте, а на собственной выдумке.
Future<List<String>> _realDdl(List<String> tables) async {
  final probe = AppDatabase.forTesting(NativeDatabase.memory());
  final quoted = tables.map((t) => "'$t'").join(', ');
  final rows = await probe
      .customSelect(
        'SELECT sql FROM sqlite_master '
        "WHERE sql IS NOT NULL AND (name IN ($quoted) OR tbl_name IN ($quoted))",
      )
      .get();
  final sql = rows.map((r) => r.read<String>('sql')).toList();
  await probe.close();
  return sql;
}

/// База, выглядящая как настоящая v39: та же схема, но без журнала.
Future<AppDatabase> _openAsIfMigratingFromV39({
  required void Function(sqlite3.Database raw) seed,
  bool keepJournal = false,
}) async {
  final ddl = await _realDdl(const [
    'accounts',
    'this_pos_entries',
    'bonus_entries',
  ]);
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        for (final s in ddl) {
          raw.execute(s);
        }
        // Журнала на v39 не существовало. [keepJournal] оставляет его —
        // это случай «установка уже поднималась на v40 и откатилась».
        if (!keepJournal) raw.execute('DROP TABLE IF EXISTS bonus_entries');
        seed(raw);
        raw.execute('PRAGMA user_version = 39');
      },
    ),
  );
}

/// Счета заводятся сырым SQL: строить их через DAO нельзя — база ещё не
/// открыта, а открытие и есть то, что проверяется.
void _seedAccount(sqlite3.Database raw, int id, int type, double value) {
  raw.execute(
    'INSERT INTO accounts (id, type, name, value, visible_to_pos) '
    'VALUES (?, ?, ?, ?, ?)',
    [id, type, 'Счёт $id', value, 0],
  );
}

void main() {
  test('свежая база: таблица есть с самого начала, версия схемы — текущая', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
      tables.map((r) => r.read<String>('name')),
      contains(db.bonusEntries.actualTableName),
    );
  });

  test('остаток, живший до журнала, становится стартовой записью', () async {
    final db = await _openAsIfMigratingFromV39(
      seed: (raw) {
        _seedAccount(raw, 13, AccountType.agentCashback, 300);
        _seedAccount(raw, 17, AccountType.cashback, 25.5);
      },
    );
    addTearDown(db.close);

    // Несущее утверждение: сверка чиста сразу после подъёма.
    expect(
      await db.bonusEntryDao.divergences(),
      isEmpty,
      reason: 'иначе первая же сверка обвинила бы каждого клиента с бонусами',
    );

    expect(await db.bonusEntryDao.balanceOf(13), Decimal.fromInt(300));
    expect(await db.bonusEntryDao.balanceOf(17), Decimal.parse('25.5'));

    final rows = await db.bonusEntryDao.findByAccount(13);
    expect(rows, hasLength(1));
    expect(rows.single.kind, BonusEntryKind.opening);
    expect(rows.single.amount, Decimal.fromInt(300));
    expect(
      rows.single.receiptNo,
      isNull,
      reason: 'чека у стартового остатка нет, и выдумывать его нельзя',
    );
    expect(
      rows.single.reason,
      contains('стартовый остаток'),
      reason: 'запись обязана сама объяснять, откуда она',
    );
    expect(
      rows.single.state,
      isNull,
      reason: 'у соседней кассы свой стартовый остаток — отправлять нельзя',
    );
  });

  test('нулевой остаток записи не получает', () async {
    // Слом в обратную сторону: «одна запись на каждый бонусный счёт» без
    // этой проверки означало бы мусор в журнале у каждого, кто бонусами не
    // пользовался, — а таких большинство.
    final db = await _openAsIfMigratingFromV39(
      seed: (raw) => _seedAccount(raw, 13, AccountType.agentCashback, 0),
    );
    addTearDown(db.close);

    expect(await db.bonusEntryDao.findByAccount(13), isEmpty);
    expect(await db.bonusEntryDao.divergences(), isEmpty);
  });

  test('счёт не бонусного рода журнала не получает вовсе', () async {
    // Сторож на список родов: миграция читает `BonusAccountTypes`, а не
    // свой список. Кассовый счёт с остатком 700 — обычное дело.
    final db = await _openAsIfMigratingFromV39(
      seed: (raw) {
        _seedAccount(raw, 11, AccountType.pos, 700);
        _seedAccount(raw, 12, AccountType.customBank, 900);
        _seedAccount(raw, 14, AccountType.agentMain, -400);
        _seedAccount(raw, 16, AccountType.teleposBonus, 60);
      },
    );
    addTearDown(db.close);

    final all = await db.select(db.bonusEntries).get();
    expect(
      all,
      isEmpty,
      reason: 'ни один из этих родов бонусным не объявлен, включая род 6',
    );
  });

  test('отрицательный остаток записывается долгом, а не обнуляется', () async {
    // База, прошедшая через дефект возврата (задача 10): бонусный счёт
    // ушёл в минус. Обнулить его тихо значило бы подарить покупателю чужие
    // деньги; выровнять сверку выдумкой — соврать в другую сторону.
    final db = await _openAsIfMigratingFromV39(
      seed: (raw) => _seedAccount(raw, 13, AccountType.agentCashback, -300),
    );
    addTearDown(db.close);

    final rows = await db.bonusEntryDao.findByAccount(13);
    expect(rows.single.kind, BonusEntryKind.openingDeficit);
    expect(
      rows.single.amount,
      Decimal.fromInt(300),
      reason: 'сумма неотрицательна всегда — направление называет kind',
    );
    expect(await db.bonusEntryDao.balanceOf(13), Decimal.fromInt(-300));
    expect(await db.bonusEntryDao.divergences(), isEmpty);
  });

  test('повторная миграция не удваивает стартовые остатки', () async {
    // Установка, поднявшаяся на v40 и откатившаяся к прежней сборке,
    // придёт сюда второй раз. Обычная вставка удвоила бы бонусы всем.
    // Ключ происхождения постоянен именно поэтому: повтор обязан попасть в
    // тот же ключ, а не завести соседний.
    final db = await _openAsIfMigratingFromV39(
      keepJournal: true,
      seed: (raw) {
        _seedAccount(raw, 13, AccountType.agentCashback, 300);
        raw.execute(
          'INSERT INTO bonus_entries '
          '(account_id, kind, amount, time, origin_pos_id, origin_entry_id) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [13, BonusEntryKind.opening, 300.0, 1000, 0, 1],
        );
      },
    );
    addTearDown(db.close);

    expect(await db.bonusEntryDao.findByAccount(13), hasLength(1));
    expect(await db.bonusEntryDao.balanceOf(13), Decimal.fromInt(300));
    expect(await db.bonusEntryDao.divergences(), isEmpty);
  });
}
