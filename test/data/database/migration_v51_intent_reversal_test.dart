/// Миграция v50→v51: возврат по намерению QR.
///
/// # Что здесь проверяется, кроме «столбцы появились»
///
/// **Что старые строки остались нетронутыми.** Перенос здесь пуст
/// намеренно (разбор — в ветви `from < 51` в `app_database.dart`), и
/// «пусто» обязано быть видно: намерение, оплаченное до подъёма, после
/// миграции остаётся `paid` с пустым `reversed_amount`, а не получает
/// выдуманный ноль. Ноль здесь — это «вернули нисколько», то есть
/// утверждение; `NULL` — «не знаем», и это правда.
///
/// **Что записать возврат по перенесённой строке можно.** Столбец,
/// добавленный `ALTER TABLE`, отличается от объявленного в схеме
/// преобразователем: без `DecimalConverter` сумма легла бы `double`, и
/// проба на тысячных это поймала бы.
///
/// # Чего здесь нет намеренно
///
/// Проверки того, что `markReversed` переводит статус: это правило самого
/// журнала, и меряется оно в `test/data/refund/qr_intent_reversal_test.dart`
/// на свежей базе. Здесь — только подъём.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/payment/payment_intent.dart';

void main() {
  /// База, доведённая до состояния v50, поверх которой открывается
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
    // Столбцы v51 снимаются с фикстуры — иначе проба зеленела бы и без
    // миграции.
    raw.execute('ALTER TABLE payment_intents DROP COLUMN reversed_amount');
    raw.execute('ALTER TABLE payment_intents DROP COLUMN reversed_at');
    raw.execute('PRAGMA user_version = 50');

    expect(
      raw
          .select("PRAGMA table_info('payment_intents')")
          .map((r) => r['name'] as String),
      isNot(contains('reversed_amount')),
      reason: 'фикстура уже содержит столбец v51 — мерить нечего',
    );

    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  /// Оплаченное и уложенное в чек намерение — такое, каких на живой кассе
  /// большинство.
  Future<void> seedPaidIntent(AppDatabase db) async {
    final (intent, _) = await db.paymentIntentDao.claim(
      intentKey: 'k-1',
      providerCode: 'kaspi',
      amount: Decimal.parse('600'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      posId: 1,
      receiptNo: 7,
    );
    await db.paymentIntentDao.attachProviderIntent(
      id: intent.id,
      providerIntentId: 'p-600',
      status: QrIntentStatus.pending,
    );
    await db.paymentIntentDao.applyState(
      id: intent.id,
      status: QrIntentStatus.paid,
      paidAmount: Decimal.parse('600'),
      confirmedAt: DateTime.fromMillisecondsSinceEpoch(1700000060000),
    );
    await db.paymentIntentDao.markSettled(
      id: intent.id,
      receiptNo: 7,
      at: DateTime.fromMillisecondsSinceEpoch(1700000061000),
    );
  }

  test('свежая база: возврата на намерении нет', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);


    await seedPaidIntent(db);
    final intent = await db.paymentIntentDao.byKey('k-1');
    expect(intent!.reversedAmount, isNull);
    expect(intent.reversedAt, isNull);
  });

  test('подъём с v50 не выдумывает возвратов у прежних намерений', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    // # Столбец спрашивается у СХЕМЫ, а не выводится из пустого ответа
    //
    // Круг правки, измеренный диверсией: первая редакция этой пробы читала
    // `byKey` и проверяла, что `reversedAmount` пуст. Со снятым шагом
    // миграции она осталась **зелёной** — `select(paymentIntents)` идёт
    // `SELECT *`, недостающий столбец в ответе просто отсутствует, и drift
    // отдаёт по нему `null`. То есть «пусто» означало и «перенос честен», и
    // «столбца нет вовсе», а различить их было нечем.
    final columns =
        (await db
                .customSelect("PRAGMA table_info('payment_intents')")
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(columns, containsAll(['reversed_amount', 'reversed_at']));

    await seedPaidIntent(db);

    final intent = await db.paymentIntentDao.byKey('k-1');
    expect(intent!.status, QrIntentStatus.paid);
    expect(
      intent.reversedAmount,
      isNull,
      reason:
          'переноса нет: «вернули нисколько» — это утверждение, а у прежних '
          'возвратов его сделать не из чего. Пустая колонка честнее нуля',
    );
    expect(intent.reversedAt, isNull);
  });

  test('по перенесённой строке возврат записывается, и он в Decimal', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);
    await seedPaidIntent(db);
    final intent = await db.paymentIntentDao.byKey('k-1');

    final written = await db.paymentIntentDao.markReversed(
      id: intent!.id,
      amount: Decimal.parse('300.505'),
      at: DateTime.fromMillisecondsSinceEpoch(1700000200000),
    );
    expect(written, isTrue);

    final after = await db.paymentIntentDao.byKey('k-1');
    expect(
      after!.reversedAmount,
      Decimal.parse('300.505'),
      reason:
          'столбец, добавленный ALTER TABLE, обязан ходить через тот же '
          'DecimalConverter: тысячные — то, на чём ломается double',
    );
    expect(
      after.status,
      QrIntentStatus.paid,
      reason: 'вернули половину — намерение остаётся оплаченным наполовину',
    );
  });
}
