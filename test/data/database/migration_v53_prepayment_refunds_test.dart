/// Миграция v52→v53: память кассы о **выданных** авансах.
///
/// Шаг приехал дорожкой «выдача аванса по проводу» как v52 и разъехался с
/// чужим v52 («долг по Z») при сведении 2026-09-19: две дорожки заняли один
/// номер независимо друг от друга. Выдача авансов уехала на 53.
///
/// # Что здесь проверяется, кроме «таблица создалась»
///
/// **Уникальный ключ.** Он и есть смысл шага: без него повтор заявки,
/// доехавший одновременно с первой попыткой, выдал бы из ящика вторые те же
/// деньги. Таблица, созданная без ключа, при чтении выглядит точно так же и
/// отличается только этим, поэтому ключ проверяется **вставкой**, а не
/// разбором DDL.
///
/// **Два пространства ключей, а не одно.** Довод за отдельную таблицу
/// (докстринг `PrepaymentRefunds`) держится ровно на том, что ключ приёма и
/// ключ выдачи не сталкиваются. Проба кладёт заведомо одинаковую строку в обе
/// памяти и требует, чтобы обе записи состоялись.
///
/// # Чего здесь нет намеренно
///
/// Переноса. До v53 выдача аванса жила только кассовым экраном, и ключа
/// заявки у неё не было вовсе: `refundPrepayment` его не принимал. Выдумать
/// ключ задним числом не из чего — он метка вкладки, а не свойство проводки,
/// — и выдуманный молча съел бы первую же законную вторую выдачу той же
/// суммы.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

void main() {
  /// База, доведённая до состояния v52, поверх которой открывается
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
    raw.execute('DROP TABLE IF EXISTS prepayment_refunds');
    raw.execute('PRAGMA user_version = 52');

    // Страховка от вырождения: фикстура обязана **не** содержать того, что
    // заводит v53, — иначе проба зеленела бы и без миграции.
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'prepayment_refunds'",
      ),
      isEmpty,
      reason: 'фикстура уже содержит таблицу v53 — мерить нечего',
    );

    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  test('свежая база: таблица есть и пуста', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.prepaymentRefundDao.byKey('нет такого'), isNull);
  });

  test('подъём с v52 заводит память, и она пуста', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    // Обращение к таблице и есть проверка: её отсутствие уронило бы запрос
    // «no such table», а не вернуло бы `null`.
    expect(await db.prepaymentRefundDao.byKey('r-1'), isNull);

    await db.prepaymentRefundDao.remember(
      refundKey: 'r-1',
      operationId: 77,
      balance: Decimal.parse('800.005'),
      time: 1700000000,
    );

    final row = await db.prepaymentRefundDao.byKey('r-1');
    expect(row, isNotNull);
    expect(row!.operationId, 77);
    expect(
      row.balanceMillis,
      800005,
      reason: 'деньги целыми тысячными: 800.005 — это 800005, а не 800.0',
    );
    expect(row.fiscalSign, isNull);
    expect(row.fiscalError, isNull);
  });

  test('ключ не даёт запомнить одну выдачу дважды', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    await db.prepaymentRefundDao.remember(
      refundKey: 'r-7',
      operationId: 1,
      balance: Decimal.parse('1000'),
      time: 1700000000,
    );

    // **Вторая запись того же ключа — это выданные дважды живые деньги.**
    // Первая линия (чтение памяти внутри транзакции) живёт в
    // `CustomerPaymentUseCaseImpl._payOutMoney`; здесь мерится вторая,
    // структурная — та, что закрывает окно между чтением и вставкой.
    await expectLater(
      db.prepaymentRefundDao.remember(
        refundKey: 'r-7',
        operationId: 2,
        balance: Decimal.parse('500'),
        time: 1700000001,
      ),
      throwsA(anything),
    );

    expect((await db.prepaymentRefundDao.byKey('r-7'))!.operationId, 1);
  });

  test('ключ приёма и ключ выдачи не сталкиваются', () async {
    // **Довод за отдельную таблицу, проверенный, а не объявленный.** Одно
    // пространство ключей на два действия означало бы, что вторая запись
    // упадёт уникальностью — и касса ответит на выдачу исходом приёма.
    final db = await openFromPrevious();
    addTearDown(db.close);

    const sameKey = 'одинаковый-ключ';
    await db.prepaymentIntakeDao.remember(
      intakeKey: sameKey,
      operationId: 1,
      balance: Decimal.parse('3000'),
      time: 1700000000,
    );
    await db.prepaymentRefundDao.remember(
      refundKey: sameKey,
      operationId: 2,
      balance: Decimal.parse('2500'),
      time: 1700000001,
    );

    expect((await db.prepaymentIntakeDao.byKey(sameKey))!.operationId, 1);
    expect((await db.prepaymentRefundDao.byKey(sameKey))!.operationId, 2);
  });

  test('отрицательное сальдо переживает хранение', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    // Выдать больше, чем лежит, условная запись не даст, но сальдо счёта
    // могло уйти в минус долгом между приёмом и выдачей: хранение целыми
    // тысячными обязано это пережить.
    await db.prepaymentRefundDao.remember(
      refundKey: 'r-долг',
      operationId: 3,
      balance: Decimal.parse('-4000.250'),
      time: 1700000000,
    );

    expect(
      (await db.prepaymentRefundDao.byKey('r-долг'))!.balanceMillis,
      -4000250,
    );
  });

  test('исход документа дописывается, а сальдо не трогается', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    await db.prepaymentRefundDao.remember(
      refundKey: 'r-документ',
      operationId: 9,
      balance: Decimal.parse('1000'),
      time: 1700000000,
    );
    await db.prepaymentRefundDao.rememberFiscal(
      refundKey: 'r-документ',
      sign: 'ФП-9',
    );

    final row = (await db.prepaymentRefundDao.byKey('r-документ'))!;
    expect(row.fiscalSign, 'ФП-9');
    expect(row.operationId, 9);
    expect(row.balanceMillis, 1000000);
  });
}
