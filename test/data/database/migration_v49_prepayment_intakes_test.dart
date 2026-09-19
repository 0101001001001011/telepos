/// Миграция v48→v49: память кассы о принятых авансах.
///
/// # Что здесь проверяется, кроме «таблица создалась»
///
/// **Уникальный ключ.** Он и есть смысл шага: без него повтор заявки,
/// доехавший одновременно с первой попыткой, записал бы второй приём тех же
/// денег. Таблица, созданная без ключа, при чтении выглядит точно так же и
/// отличается только этим, поэтому ключ проверяется **вставкой**, а не
/// разбором DDL.
///
/// **Отрицательное сальдо.** Покупатель с долгом больше взноса остаётся в
/// минусе и после приёма; хранение целыми тысячными обязано это пережить.
///
/// # Чего здесь нет намеренно
///
/// Переноса. У приёмов, записанных до v49, ключа заявки не было вовсе —
/// `PrepaymentIntakeRequest` его не нёс, и по проводу он не ехал. Выдумать
/// ключ задним числом не из чего: это метка вкладки, а не свойство проводки.
/// Хуже того, выдуманный ключ выглядел бы настоящим и съел бы первый же
/// законный повторный взнос той же суммы.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

void main() {
  /// База, доведённая до состояния v48, поверх которой открывается
  /// настоящая — открытие и есть миграция.
  ///
  /// Схема берётся **из настоящего DDL текущей версии** и урезается, а не
  /// пишется руками: фикстура, разошедшаяся со схемой, начинает проверять
  /// вымышленную базу (разбор — в пробе v44).
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
    raw.execute('DROP TABLE IF EXISTS prepayment_intakes');
    raw.execute('PRAGMA user_version = 48');

    // Страховка от вырождения: фикстура обязана **не** содержать того, что
    // заводит v49, — иначе проба зеленела бы и без миграции.
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'prepayment_intakes'",
      ),
      isEmpty,
      reason: 'фикстура уже содержит таблицу v49 — мерить нечего',
    );

    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  test('свежая база: таблица есть и пуста', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.prepaymentIntakeDao.byKey('нет такого'), isNull);
  });

  test('подъём с v48 заводит память, и она пуста', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    // Обращение к таблице и есть проверка: её отсутствие уронило бы запрос
    // «no such table», а не вернуло бы `null`.
    expect(await db.prepaymentIntakeDao.byKey('k-1'), isNull);

    await db.prepaymentIntakeDao.remember(
      intakeKey: 'k-1',
      operationId: 77,
      balance: Decimal.parse('1500.505'),
      time: 1700000000,
    );

    final row = await db.prepaymentIntakeDao.byKey('k-1');
    expect(row, isNotNull);
    expect(row!.operationId, 77);
    expect(
      row.balanceMillis,
      1500505,
      reason: 'деньги целыми тысячными: 1500.505 — это 1500505, а не 1500.5',
    );
    expect(row.fiscalSign, isNull);
    expect(row.fiscalError, isNull);
  });

  test('ключ не даёт запомнить одну заявку дважды', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    await db.prepaymentIntakeDao.remember(
      intakeKey: 'k-7',
      operationId: 1,
      balance: Decimal.parse('1000'),
      time: 1700000000,
    );

    // **Вторая запись того же ключа — это принятые дважды деньги.** Первая
    // линия (чтение памяти внутри транзакции) живёт в
    // `CustomerPaymentUseCaseImpl._writeMoney`; здесь мерится вторая,
    // структурная — та, что закрывает окно между чтением и вставкой.
    await expectLater(
      db.prepaymentIntakeDao.remember(
        intakeKey: 'k-7',
        operationId: 2,
        balance: Decimal.parse('2000'),
        time: 1700000001,
      ),
      throwsA(anything),
    );

    expect((await db.prepaymentIntakeDao.byKey('k-7'))!.operationId, 1);
  });

  test('отрицательное сальдо переживает хранение', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    // Покупатель с долгом 5000, внёсший 1000, остаётся в минусе — и касса
    // обязана ответить повтору именно этим числом, а не нулём.
    await db.prepaymentIntakeDao.remember(
      intakeKey: 'k-долг',
      operationId: 3,
      balance: Decimal.parse('-4000.250'),
      time: 1700000000,
    );

    expect((await db.prepaymentIntakeDao.byKey('k-долг'))!.balanceMillis, -4000250);
  });

  test('исход чека дописывается, а сальдо не трогается', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    await db.prepaymentIntakeDao.remember(
      intakeKey: 'k-чек',
      operationId: 9,
      balance: Decimal.parse('1000'),
      time: 1700000000,
    );
    await db.prepaymentIntakeDao.rememberFiscal(
      intakeKey: 'k-чек',
      sign: 'ФП-7',
    );

    final row = (await db.prepaymentIntakeDao.byKey('k-чек'))!;
    expect(row.fiscalSign, 'ФП-7');
    expect(row.operationId, 9);
    expect(row.balanceMillis, 1000000);
  });
}
