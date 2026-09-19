/// Миграция v44→v45 (задача 24): рассрочка с кредитным договором.
///
/// # Что здесь проверяется, кроме «таблицы создались»
///
/// **Новое право `op.creditRepay` выдаётся существующим пользователям.**
/// Таблица `user_permissions` с задачи 16 — allow-list: пустая строка
/// значит «запрещено». Ключ, добавленный в `PermissionKeys.allPermissions`
/// без шага миграции, у каждого существующего не-владельца строки не имеет
/// и потому читается **отказом** — новая возможность тихо не работает ни
/// для кого, включая роль, которой она полагается по умолчанию.
///
/// Это тот же класс дефекта, что поправка справочника в v44: и словарь, и
/// правило чтения по отдельности верны, а вместе они запирают возможность.
/// Чтением он не виден.
///
/// # И обратная сторона — чужое решение не отменяется
///
/// Ключ выдаётся **только** тому, у кого он есть в умолчаниях роли, и
/// **только** если строки на него ещё нет. Пользователь, у которого право
/// отобрано явно (`is_allowed = 0`), обязан остаться без права: миграция,
/// вернувшая ему отнятое, — это отменённое решение владельца.
///
/// # Таблицы проверяются РАБОТОЙ, а не именем
///
/// «Строка появилась в `sqlite_master`» зелено и у таблицы, в которую
/// нельзя вставить: недостающая колонка, чужой тип, забытый уникальный
/// ключ. Поэтому ниже в новую таблицу пишут договор с графиком, читают его
/// обратно и проверяют **условную запись** `allocate` — то, ради чего
/// колонки и целые.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/credit_dao.dart';
import 'package:telepos/data/database/daos/payment_kind_dao.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  /// База, доведённая до состояния v44, поверх которой открывается
  /// настоящая — открытие и есть миграция.
  ///
  /// Схема берётся **из настоящего DDL текущей версии** и урезается, а не
  /// пишется руками: фикстура, разошедшаяся со схемой, начинает проверять
  /// вымышленную базу.
  Future<AppDatabase> openFromPrevious({
    bool cashierKeepsRepayDenied = false,
  }) async {
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
    raw.execute('DROP TABLE IF EXISTS credit_contracts');
    raw.execute('DROP TABLE IF EXISTS credit_schedule_entries');
    raw.execute('PRAGMA user_version = 44');

    // Кассир, заведённый до v45: у него есть строки на все ключи словаря
    // **той** сборки, и ни одной на `op.creditRepay`.
    raw.execute(
      'INSERT INTO users (id, name, role) VALUES (?, ?, ?)',
      [7, 'Айгуль', UserRole.cashier.index],
    );
    for (final key in PermissionKeys.allPermissions) {
      if (key == PermissionKeys.opCreditRepay) continue;
      final allowed =
          PermissionKeys.roleDefaults[UserRole.cashier]!.contains(key) ? 1 : 0;
      raw.execute(
        'INSERT INTO user_permissions (user_id, permission_key, is_allowed) '
        'VALUES (?, ?, ?)',
        [7, key, allowed],
      );
    }
    if (cashierKeepsRepayDenied) {
      // Владелец отнял право явно. Миграция обязана это уважать.
      raw.execute(
        'INSERT INTO user_permissions (user_id, permission_key, is_allowed) '
        'VALUES (?, ?, 0)',
        [7, PermissionKeys.opCreditRepay],
      );
    }

    // Страховка от вырождения: фикстура обязана **не** содержать того, что
    // заводит v45, — иначе проба зеленела бы и без миграции.
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'credit_contracts'",
      ),
      isEmpty,
      reason: 'фикстура уже содержит таблицу v45 — мерить нечего',
    );
    expect(
      raw.select(
        'SELECT permission_key FROM user_permissions '
        'WHERE user_id = 7 AND permission_key = ?',
        [PermissionKeys.opCreditRepay],
      ).isEmpty,
      !cashierKeepsRepayDenied,
      reason: 'фикстура задаёт исходное состояние права',
    );

    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  test('свежая база: таблицы есть, версия схемы — текущая', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.creditDao.rowByNumber('РС-1-1'), isNull);

    // Вид заводится **выключенным**: включить его за оператора значит
    // записать решение, которого он не принимал.
    final kind = PaymentKindDao.toDomain(
      (await db.paymentKindDao.rowById(SystemPaymentKindIds.installment))!,
    );
    expect(kind, isNotNull);
    expect(kind!.isActive, isFalse);
    expect(kind.settlement, PaymentSettlement.deferred);
    expect(kind.requiresCounterparty, isTrue);
  });

  test('v44 → v45: таблицы заводятся, и они РАБОЧИЕ', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    final id = await db.creditDao.insertContract(
      number: 'РС-1-1',
      agentLocalId: 5,
      receivableAccountId: 14,
      receiptNo: 1,
      posId: 1,
      principal: d('900'),
      feeTotal: Decimal.zero,
      downPayment: d('100'),
      termMonths: 3,
      scheme: InstallmentScheme.equalInstalments,
      signedAt: 1000,
      schedule: InstallmentScheduler.build(
        principal: d('900'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: DateTime(2026, 10, 1),
        scheme: InstallmentScheme.equalInstalments,
      ),
    );

    final row = await db.creditDao.rowByNumber('РС-1-1');
    expect(row, isNotNull);
    final contract = CreditDao.toDomain(row!);
    expect(contract!.principal, d('900'));
    expect(contract.downPayment, d('100'));
    expect(contract.status, CreditContractStatus.active);

    final schedule = await db.creditDao.scheduleRows(id);
    expect(schedule.length, 3);

    // **Условная запись работает** — то, ради чего колонки целые.
    expect(
      await db.creditDao.allocate(entryId: schedule.first.id, amount: d('300')),
      1,
    );
    expect(
      await db.creditDao.allocate(entryId: schedule.first.id, amount: d('1')),
      0,
      reason: 'строка уже закрыта — переплатить её нельзя',
    );
  });

  test('v44 → v45: уникальный ключ не даёт второй договор на один чек',
      () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    Future<int> insert(String number) => db.creditDao.insertContract(
      number: number,
      agentLocalId: 5,
      receivableAccountId: 14,
      receiptNo: 1,
      posId: 1,
      principal: d('900'),
      feeTotal: Decimal.zero,
      downPayment: Decimal.zero,
      termMonths: 3,
      scheme: InstallmentScheme.equalInstalments,
      signedAt: 1000,
      schedule: InstallmentScheduler.build(
        principal: d('900'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: DateTime(2026, 10, 1),
        scheme: InstallmentScheme.equalInstalments,
      ),
    );

    await insert('РС-1-1');
    // Второй договор на тот же чек — под другим номером, чтобы ключ по
    // номеру не перехватил проверку раньше ключа по чеку.
    await expectLater(insert('РС-1-1-бис'), throwsA(anything));
  });

  test('v44 → v45: право op.creditRepay достаётся кассиру', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    final allowed = await db.userPermissionDao.getAllowedKeys(7);
    expect(
      allowed.contains(PermissionKeys.opCreditRepay),
      isTrue,
      reason: 'без этого шага погашение не работало бы ни у кого',
    );
  });

  test('v44 → v45: отнятое владельцем право НЕ возвращается', () async {
    final db = await openFromPrevious(cashierKeepsRepayDenied: true);
    addTearDown(db.close);

    final allowed = await db.userPermissionDao.getAllowedKeys(7);
    expect(
      allowed.contains(PermissionKeys.opCreditRepay),
      isFalse,
      reason: 'миграция, вернувшая отнятое, отменяет решение владельца',
    );
  });

  test('v44 → v45: справочник не потерял ни одного вида', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    final kinds = await db.paymentKindDao.allRows();
    expect(
      kinds.map((k) => k.id).toSet(),
      SystemPaymentKindIds.all.toSet(),
    );
  });
}
