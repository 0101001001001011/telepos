/// Миграция v43→v44 (задача 21): подарочный сертификат.
///
/// # Что здесь проверяется, кроме «таблица создалась»
///
/// **Поправка справочника.** На кассе, прошедшей v41, строка вида
/// «Сертификат» уже есть — с пустым счётом-получателем, потому что рода
/// счёта под обязательство тогда не существовало. Посев её не тронет
/// (`insertOrIgnore`, и это правильно: перезапись стёрла бы настройку
/// оператора), и без отдельной поправки вид остался бы **невключаемым
/// навсегда**: `PaymentKindRules` не даёт включить зачётный вид без счёта.
///
/// Это ровно тот класс дефекта, который не виден чтением: и посев, и
/// правило по отдельности верны, а вместе они запирают вид.
///
/// # И обратная сторона — решение оператора не отменяется
///
/// Поправка ставит род **только там, где поле пусто**. Оператор, назвавший
/// счёт сам, обязан остаться при своём: миграция, переписавшая его выбор,
/// — это отменённое решение владельца, и заметил бы он это только по
/// уехавшим не туда деньгам.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/payment_kind_dao.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/payment_kind_catalog.dart';

void main() {
  /// База, доведённая до состояния предыдущей версии, поверх которой открывается
  /// настоящая — открытие и есть миграция.
  ///
  /// Схема берётся **из настоящего DDL текущей версии** и урезается, а не
  /// пишется руками: фикстура, разошедшаяся со схемой, начинает проверять
  /// вымышленную базу — так покраснела первая редакция пробы v40, на
  /// собственной выдумке.
  ///
  /// Одна и та же `sqlite3.Database` держится открытой, и drift работает
  /// поверх неё (`NativeDatabase.opened`): `openInMemory` каждый раз даёт
  /// новую память, и фикстура с мигрирующей базой оказались бы двумя
  /// разными базами.
  Future<AppDatabase> openFromPrevious({int? certificatePayeeType}) async {
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
    raw.execute('DROP TABLE IF EXISTS gift_certificates');
    raw.execute('PRAGMA user_version = 43');

    for (final kind in SystemPaymentKinds.all) {
      raw.execute(
        'INSERT INTO payment_kinds '
        '(id, code, name, settlement, fiscal_treatment, payee_account_type, '
        ' requires_acquiring, requires_counterparty, requires_provider, '
        ' gives_change, refund_allowed, is_active, is_system, is_selectable, '
        ' sort_order) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, 1, ?, ?)',
        [
          kind.id,
          kind.code,
          kind.name,
          kind.settlement.index,
          kind.fiscalTreatment.code,
          kind.id == SystemPaymentKindIds.certificate
              ? certificatePayeeType
              : kind.payeeAccountType,
          kind.requiresAcquiring ? 1 : 0,
          kind.requiresCounterparty ? 1 : 0,
          kind.requiresProvider ? 1 : 0,
          kind.givesChange ? 1 : 0,
          kind.isActive ? 1 : 0,
          kind.isSelectable ? 1 : 0,
          kind.sortOrder,
        ],
      );
    }

    // Страховка от вырождения: фикстура обязана **не** содержать того, что
    // заводит v44, — иначе проба зеленела бы и без миграции.
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'gift_certificates'",
      ),
      isEmpty,
      reason: 'фикстура уже содержит таблицу v44 — мерить нечего',
    );

    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  test('свежая база: таблица есть, версия схемы — текущая', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.certificateDao.all(), isEmpty);

    // `onCreate` миграций не исполняет: посев видов идёт **обоими** путями,
    // и вид сертификата на свежей установке обязан уже знать свой счёт —
    // иначе оператор не смог бы его включить.
    final kind = (await db.paymentKindDao.rowById(
      SystemPaymentKindIds.certificate,
    ))!;
    expect(kind.payeeAccountType, AccountType.certificateLiability);
    expect(kind.isActive, isFalse, reason: 'вид заводится выключенным');
    expect(kind.givesChange, isFalse, reason: 'сдача с сертификата — обнал');
  });

  test('v43 → v44: таблица заводится, и она рабочая', () async {
    final db = await openFromPrevious(
      certificatePayeeType: AccountType.certificateLiability,
    );
    addTearDown(db.close);

    // Открытие и есть миграция.
    expect(await db.certificateDao.all(), isEmpty);

    // Утверждение о **работе**, а не о наличии имени в `sqlite_master`:
    // таблица, созданная не тем DDL, нашлась бы по имени и упала бы на
    // первой записи — у клиента, а не здесь.
    await db.certificateDao.insertCertificate(
      number: 'C-1',
      nominal: Decimal.fromInt(500),
      issuedAt: 1000,
      status: CertificateStatus.active,
    );
    final row = (await db.certificateDao.byNumber('C-1'))!;
    expect(row.balance, Decimal.fromInt(500));
    expect(row.status, CertificateStatus.active);
    expect(
      await db.certificateDao.redeem(
        number: 'C-1',
        amount: Decimal.fromInt(200),
      ),
      1,
      reason: 'условное гашение работает на мигрировавшей таблице',
    );
    expect((await db.certificateDao.byNumber('C-1'))!.balance, Decimal.fromInt(300));
  });

  test('v43 → v44: пустой счёт вида «Сертификат» проставляется', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    final row = (await db.paymentKindDao.rowById(
      SystemPaymentKindIds.certificate,
    ))!;
    expect(
      row.payeeAccountType,
      AccountType.certificateLiability,
      reason: 'без этого вид остался бы невключаемым навсегда: '
          'PaymentKindRules не даёт включить зачётный вид без счёта',
    );

    // И вид действительно **становится включаемым** — утверждение о
    // правиле, а не о колонке. Проверка «колонка заполнена» прошла бы и с
    // любым другим числом.
    final kind = PaymentKindDao.toDomain(row)!;
    expect(
      PaymentKindRules.validate(
        kind.copyWith(isActive: true),
        existing: kind,
      ),
      isNull,
    );
  });

  test('v43 → v44: НАЗВАННЫЙ оператором счёт не переписывается', () async {
    // Слом в другую сторону. Миграция, переписавшая выбор владельца, — это
    // отменённое решение, и заметил бы он его только по уехавшим не туда
    // деньгам.
    final db = await openFromPrevious(certificatePayeeType: AccountType.customBank);
    addTearDown(db.close);

    final row = (await db.paymentKindDao.rowById(
      SystemPaymentKindIds.certificate,
    ))!;
    expect(row.payeeAccountType, AccountType.customBank);
  });

  test('v43 → v44: справочник не потерял ни одного вида', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    final kinds = await db.paymentKindDao.allRows();
    expect(kinds.map((k) => k.id).toSet(), SystemPaymentKindIds.all.toSet());
  });
}
