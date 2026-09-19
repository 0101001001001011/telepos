/// Миграция v41→v42 (задача 23): у «Предоплаты» появляется
/// счёт-получатель.
///
/// # Зачем шаг миграции ради одной строки справочника
///
/// Потому что посев идёт `insertOrIgnore` — и правильно идёт: он не имеет
/// права затирать настройки оператора. Значит на кассе, доехавшей до v41
/// вчера, строка вида `prepayment` осталась бы **без**
/// `payee_account_type`. А правило 4 справочника
/// (`kind_account_missing`) отказывает **включить** зачёт без счёта:
/// вид стал бы невключаемым, то есть окном, в которое видно, но через
/// которое ничего не проходит.
///
/// # Что здесь проверяется, кроме «поле заполнилось»
///
/// Что миграция **не приняла решения за оператора**: `is_active`
/// остаётся `false`. Правятся ровно те поля, решения по которым оператор
/// принять не мог, — их у вида до сих пор не было вовсе.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/payment_kind_catalog.dart';

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

/// Справочник в том виде, в каком его оставила v41: у «Предоплаты» счёта
/// нет, и это ровно та строка, ради которой шаг существует.
void _seedV41Kinds(sqlite3.Database raw) {
  for (final kind in SystemPaymentKinds.all) {
    raw.execute(
      'INSERT INTO payment_kinds (id, code, name, settlement, '
      'fiscal_treatment, payee_account_type, payee_account_id, '
      'requires_acquiring, requires_counterparty, requires_provider, '
      'gives_change, refund_allowed, is_active, is_system, is_selectable, '
      'sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        kind.id,
        kind.code,
        kind.name,
        kind.settlement.index,
        kind.fiscalTreatment.code,
        // v41 не знала счёта ни у сертификата, ни у предоплаты.
        kind.id == SystemPaymentKindIds.prepayment
            ? null
            : kind.payeeAccountType,
        kind.payeeAccountId,
        kind.requiresAcquiring ? 1 : 0,
        kind.id == SystemPaymentKindIds.prepayment
            ? 0
            : (kind.requiresCounterparty ? 1 : 0),
        kind.requiresProvider ? 1 : 0,
        kind.givesChange ? 1 : 0,
        kind.refundAllowed ? 1 : 0,
        kind.isActive ? 1 : 0,
        kind.isSystem ? 1 : 0,
        kind.isSelectable ? 1 : 0,
        kind.sortOrder,
      ],
    );
  }
}

Future<AppDatabase> _openAsIfMigratingFromV41({
  void Function(sqlite3.Database raw)? extraSeed,
}) async {
  final ddl = await _realDdl(const ['payment_kinds', 'payments', 'accounts']);
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        for (final statement in ddl) {
          raw.execute(statement);
        }
        _seedV41Kinds(raw);
        extraSeed?.call(raw);
        raw.execute('PRAGMA user_version = 41');
      },
    ),
  );
}

void main() {
  test('v41 → v42: у предоплаты появляется расчётный счёт покупателя', () async {
    final db = await _openAsIfMigratingFromV41();
    addTearDown(db.close);

    // Открытие и есть миграция.
    final row = await db.paymentKindDao.rowById(
      SystemPaymentKindIds.prepayment,
    );

    expect(
      row!.payeeAccountType,
      AccountType.agentMain,
      reason: 'без счёта вид невозможно включить: правило 4 справочника '
          'отвечает kind_account_missing',
    );
    expect(row.requiresCounterparty, isTrue,
        reason: 'аванс всегда чей-то');
    expect(
      row.isActive,
      isFalse,
      reason: 'включение вида — решение оператора, и миграция его за него '
          'не принимает',
    );
  });

  test('включить предоплату после миграции можно, до неё — нельзя', () async {
    // **Достижимость, а не поле.** Проба существует затем, чтобы утверждение
    // «без счёта вид невключаем» было не пересказом правила, а замером.
    final db = await _openAsIfMigratingFromV41();
    addTearDown(db.close);

    final migrated = SystemPaymentKinds.byId(
      SystemPaymentKindIds.prepayment,
    );
    expect(
      PaymentKindRules.validate(
        migrated.copyWith(isActive: true),
        existing: migrated,
      ),
      isNull,
      reason: 'после миграции оператор включает вид одним движением',
    );
    expect(
      PaymentKindRules.validate(
        migrated.copyWith(isActive: true, clearPayeeAccountType: true),
        existing: migrated,
      ),
      kindAccountMissingCode,
      reason: 'а без счёта — не включает вовсе',
    );
  });

  test('чужие настройки оператора миграция не трогает', () async {
    final db = await _openAsIfMigratingFromV41(
      extraSeed: (raw) {
        // Оператор переименовал карту и выключил её — обе правки обязаны
        // пережить миграцию.
        raw.execute(
          "UPDATE payment_kinds SET name = 'Безнал', is_active = 0 "
          'WHERE id = ?',
          [SystemPaymentKindIds.card],
        );
      },
    );
    addTearDown(db.close);

    final card = await db.paymentKindDao.rowById(SystemPaymentKindIds.card);
    expect(card!.name, 'Безнал');
    expect(card.isActive, isFalse);
  });
}
