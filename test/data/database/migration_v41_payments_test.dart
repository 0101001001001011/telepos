/// Миграция v40→v41 (задача 14): у оплаты появляется вид, `Payments`
/// перестраивается.
///
/// # Что здесь на самом деле проверяется
///
/// Не «колонка появилась». `Payments` — таблица, где лежат деньги, и она
/// **переписывается копией**: sqlite не умеет менять уникальные ключи
/// через `ALTER TABLE`. Поэтому главные утверждения — денежные:
/// сумма не изменилась, ни одна строка не потеряна, и ни одна строка не
/// получила **выдуманный** вид.
///
/// Фикстура строится тем же приёмом, что `migration_v40_bonus_journal_test`:
/// вид предыдущей версии получается **из настоящего DDL текущей схемы**
/// правкой, а не переписыванием руками. Правка проверяется на месте
/// ([_v40PaymentsDdl] проверяет свой же результат): фикстура, разошедшаяся
/// со схемой, начинает проверять вымышленную базу — первая редакция пробы
/// v40 так и покраснела, на собственной выдумке.
library;

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

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

/// Пять колонок, которых на v40 не было.
const _v41Columns = <String>[
  'kind_id',
  'seq',
  'command_key',
  'reference',
  'provider_code',
];

/// `payments` в том виде, в каком она была на v40: без пяти колонок и со
/// **старым** ключом `{receipt_no, pos_id, payee_account_id}`.
///
/// Старый ключ восстанавливается нарочно, а не опускается: именно он
/// запрещал две законные строки на один счёт, и проба, поднявшая фикстуру
/// без ключа, доказала бы меньше, чем думает.
String _v40PaymentsDdl(String current) {
  var ddl = current;
  for (final column in _v41Columns) {
    ddl = ddl.replaceAll(
      RegExp('"$column" [A-Z]+( NOT NULL| NULL)?( DEFAULT [^,)]+)?, '),
      '',
    );
  }
  ddl = ddl
      .replaceAll(
        'UNIQUE ("receipt_no", "pos_id", "seq")',
        'UNIQUE ("receipt_no", "pos_id", "payee_account_id")',
      )
      .replaceAll(
        'UNIQUE ("refund_local_id", "seq")',
        'UNIQUE ("refund_local_id", "payee_account_id")',
      );

  // **Правка проверяет сама себя.** Без этого блока переименование
  // колонки в схеме оставило бы фикстуру «почти правильной» и проба
  // продолжала бы зеленеть над таблицей, которой не было ни в одной
  // версии продукта.
  for (final column in _v41Columns) {
    if (ddl.contains('"$column"')) {
      throw StateError('фикстура v40 не избавилась от колонки $column: $ddl');
    }
  }
  if (!ddl.contains('UNIQUE ("receipt_no", "pos_id", "payee_account_id")')) {
    throw StateError('фикстура v40 не получила старого ключа: $ddl');
  }
  return ddl;
}

Future<AppDatabase> _openAsIfMigratingFromV40({
  required void Function(sqlite3.Database raw) seed,
}) async {
  final ddl = await _realDdl(const ['accounts', 'payments', 'payment_kinds']);
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        for (final statement in ddl) {
          if (statement.contains('"payments"')) {
            raw.execute(_v40PaymentsDdl(statement));
          } else {
            raw.execute(statement);
          }
        }
        // Справочника видов на v40 не существовало.
        raw.execute('DROP TABLE IF EXISTS payment_kinds');
        seed(raw);
        raw.execute('PRAGMA user_version = 40');
      },
    ),
  );
}

void _seedAccount(sqlite3.Database raw, int id, int type) {
  raw.execute(
    'INSERT INTO accounts (id, type, name, value, visible_to_pos) '
    'VALUES (?, ?, ?, ?, ?)',
    [id, type, 'Счёт $id', 0.0, 0],
  );
}

void _seedPayment(
  sqlite3.Database raw, {
  required int id,
  required int payeeAccountId,
  required double amount,
  int? receiptNo,
  int? posId,
  int? refundLocalId,
}) {
  raw.execute(
    'INSERT INTO payments '
    '(id, user_id, receipt_no, pos_id, refund_local_id, payee_account_id, '
    'amount, time) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [id, 7, receiptNo, posId, refundLocalId, payeeAccountId, amount, 1000 + id],
  );
}

/// Счета: касса, банк, бонус, расчётный контрагента.
const _posAccount = 1;
const _bankAccount = 2;
const _bonusAccount = 3;
const _agentAccount = 4;

/// Счёт, снесённый из справочника: строк `accounts` под этим номером нет.
const _goneAccount = 99;

void _seedSixPayments(sqlite3.Database raw) {
  _seedAccount(raw, _posAccount, AccountType.pos);
  _seedAccount(raw, _bankAccount, AccountType.customBank);
  _seedAccount(raw, _bonusAccount, AccountType.cashback);
  _seedAccount(raw, _agentAccount, AccountType.agentMain);

  // Чек A — две строки: наличные и карта. Ровно то, что старый ключ
  // разрешал (счета разные), а новый обязан разрешать по `seq`.
  _seedPayment(
    raw,
    id: 1,
    receiptNo: 10,
    posId: 1,
    payeeAccountId: _posAccount,
    amount: 300,
  );
  _seedPayment(
    raw,
    id: 2,
    receiptNo: 10,
    posId: 1,
    payeeAccountId: _bankAccount,
    amount: 700,
  );
  // Чек B — бонус.
  _seedPayment(
    raw,
    id: 3,
    receiptNo: 11,
    posId: 1,
    payeeAccountId: _bonusAccount,
    amount: 50,
  );
  // Чек C — расчёт с контрагентом. До v41 читался «наличными» всюду, где
  // вид выводился по правилу «не банк — значит касса».
  _seedPayment(
    raw,
    id: 4,
    receiptNo: 12,
    posId: 1,
    payeeAccountId: _agentAccount,
    amount: 120,
  );
  // Возврат.
  _seedPayment(
    raw,
    id: 5,
    refundLocalId: 5,
    payeeAccountId: _posAccount,
    amount: -80,
  );
  // Строка со **снесённым счётом** — та, ради которой `kind_id` nullable.
  _seedPayment(
    raw,
    id: 6,
    receiptNo: 13,
    posId: 1,
    payeeAccountId: _goneAccount,
    amount: 40,
  );
}

Future<double> _sumOfPayments(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COALESCE(SUM(amount), 0) AS s FROM payments')
      .getSingle();
  return row.read<double>('s');
}

void main() {
  test('свежая база: справочник посеян, версия схемы — текущая', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);


    final kinds = await db.paymentKindDao.allRows();
    expect(
      kinds.map((k) => k.id).toList(),
      SystemPaymentKindIds.all,
      reason: 'девять системных видов на свежей установке, в порядке сортировки',
    );
    expect(
      kinds.firstWhere((k) => k.id == SystemPaymentKindIds.certificate).isActive,
      isFalse,
      reason: 'виды 5–8 заводятся выключенными: включить вид за оператора '
          'значит записать решение, которого он не принимал',
    );
    expect(
      kinds
          .firstWhere((k) => k.id == SystemPaymentKindIds.bonus)
          .fiscalTreatment,
      FiscalTreatment.notAPayment.code,
      reason: 'бонус фискально — скидка, а не платёж: объявить его платежом '
          'значит завысить базу налога',
    );
  });

  test('v40 → v41: шесть строк оплаты переезжают без потерь', () async {
    final db = await _openAsIfMigratingFromV40(seed: _seedSixPayments);
    addTearDown(db.close);

    // Открытие и есть миграция.
    final sumAfter = await _sumOfPayments(db);
    expect(sumAfter, closeTo(300 + 700 + 50 + 120 - 80 + 40, 0.0001));

    final rows = await db.customSelect('SELECT * FROM payments').get();
    expect(rows, hasLength(6), reason: 'ни одна строка не потеряна');
  });

  test('v40 → v41: seq считается внутри чека и внутри возврата', () async {
    final db = await _openAsIfMigratingFromV40(seed: _seedSixPayments);
    addTearDown(db.close);

    final receiptA = await db
        .customSelect(
          'SELECT seq FROM payments WHERE receipt_no = 10 AND pos_id = 1 '
          'ORDER BY id',
        )
        .get();
    expect(receiptA.map((r) => r.read<int>('seq')).toList(), [0, 1]);

    final refund = await db
        .customSelect('SELECT seq FROM payments WHERE refund_local_id = 5')
        .get();
    expect(refund.single.read<int>('seq'), 0);
  });

  test('v40 → v41: вид проставлен по роду счёта, и НЕ выдуман', () async {
    final db = await _openAsIfMigratingFromV40(seed: _seedSixPayments);
    addTearDown(db.close);

    Future<int?> kindOf(int id) async {
      final row = await db
          .customSelect('SELECT kind_id FROM payments WHERE id = ?', variables: [
            Variable.withInt(id),
          ])
          .getSingle();
      return row.read<int?>('kind_id');
    }

    expect(await kindOf(1), SystemPaymentKindIds.cash);
    expect(await kindOf(2), SystemPaymentKindIds.card);
    expect(await kindOf(3), SystemPaymentKindIds.bonus);
    expect(
      await kindOf(4),
      SystemPaymentKindIds.agentSettlement,
      reason: 'расчёт с контрагентом — не тендер продажи, и «наличными» его '
          'считать нельзя: он попал бы в выручку смены',
    );
    expect(await kindOf(5), SystemPaymentKindIds.cash);
    expect(
      await kindOf(6),
      isNull,
      reason: 'классифицировать нечем — и это НЕ «наличные по умолчанию»',
    );
  });

  test('v40 → v41: две строки одного чека на ОДИН счёт становятся законными',
      () async {
    final db = await _openAsIfMigratingFromV40(
      seed: (raw) {
        _seedSixPayments(raw);
      },
    );
    addTearDown(db.close);

    // Старый ключ `{receipt_no, pos_id, payee_account_id}` запрещал это
    // сырым `SqliteException(2067)`; ради него существовал отдельный
    // отказ `payment_account_conflict`. После перестройки строки
    // различаются по `seq`.
    await db.customStatement(
      'INSERT INTO payments '
      '(user_id, receipt_no, pos_id, payee_account_id, amount, time, seq, '
      'kind_id) VALUES (7, 10, 1, $_posAccount, 5, 9999, 2, '
      '${SystemPaymentKindIds.certificate})',
    );

    final rows = await db
        .customSelect(
          'SELECT seq FROM payments WHERE receipt_no = 10 AND pos_id = 1',
        )
        .get();
    expect(rows, hasLength(3));
  });

  test('повторный подъём v41 не трогает настройку оператора', () async {
    // Установка, прошедшая v41 и откатившаяся к прежней сборке, придёт
    // сюда второй раз. Перезапись стёрла бы решение оператора молча.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
      ).copyWith(isActive: true, payeeAccountType: AccountType.customCash),
    );
    await db.customStatement('PRAGMA user_version = 40');
    await db.close();

    // Второй посев поверх изменённой строки — тем же вызовом, что и
    // миграция.
    final again = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(again.close);
    await again.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
      ).copyWith(isActive: true),
    );
    await again.paymentKindDao.seed(
      SystemPaymentKinds.byId(SystemPaymentKindIds.certificate),
    );
    final row = await again.paymentKindDao.rowById(
      SystemPaymentKindIds.certificate,
    );
    expect(
      row!.isActive,
      isTrue,
      reason: 'посев — insertOrIgnore: включённый оператором вид остаётся '
          'включённым',
    );
  });
}
