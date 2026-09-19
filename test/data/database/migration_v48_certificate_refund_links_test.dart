/// Миграция v47→v48: журнал связи «возврат → сертификат».
///
/// # Что здесь проверяется, кроме «таблица создалась»
///
/// **Уникальный ключ.** Он и есть смысл шага: без пары
/// `{refund_local_id, source_number}` повторный возврат по тому же чеку
/// выписал бы вторую бумажку на ту же сумму — то есть напечатал бы деньги.
/// Таблица, созданная без ключа, выглядит точно так же при чтении и
/// отличается только этим; поэтому ключ проверяется **вставкой**, а не
/// разбором DDL.
///
/// # Чего здесь нет намеренно
///
/// Переноса. До v48 возврат товара, оплаченного сертификатом, возвращал
/// деньги на ту же бумажку, и второй бумажки не заводилось вовсе —
/// связывать было нечего. Вывести журнал задним числом не из чего, а
/// выдумать значит записать историю, которая выглядит настоящей и врёт про
/// каждый прежний возврат. Пустая таблица честнее — тот же довод, что у
/// `SaleDiscounts` в v40 и `PaymentIntents` в v43.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/certificate_refund_tables.dart';

void main() {
  /// База, доведённая до состояния v47, поверх которой открывается
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
    raw.execute('DROP TABLE IF EXISTS certificate_refund_links');
    raw.execute('PRAGMA user_version = 47');

    // Страховка от вырождения: фикстура обязана **не** содержать того, что
    // заводит v48, — иначе проба зеленела бы и без миграции.
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'certificate_refund_links'",
      ),
      isEmpty,
      reason: 'фикстура уже содержит таблицу v48 — мерить нечего',
    );

    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  test('свежая база: таблица есть и пуста', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.certificateDao.linksByRefund(1), isEmpty);
  });

  test('подъём с v47 заводит журнал, и он пуст', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    // Обращение к таблице и есть проверка: её отсутствие уронило бы запрос
    // «no such table», а не вернуло бы пустой список.
    expect(await db.certificateDao.linksByRefund(1), isEmpty);

    await db.certificateDao.linkRefund(
      refundLocalId: 1,
      sourceNumber: 'C-1',
      issuedNumber: 'C-1-R1',
      amount: Decimal.parse('600.005'),
      reason: CertificateRefundReason.issued,
      time: 1700000000,
    );

    final links = await db.certificateDao.linksByRefund(1);
    expect(links, hasLength(1));
    expect(links.single.sourceNumber, 'C-1');
    expect(links.single.issuedNumber, 'C-1-R1');
    expect(
      links.single.amountMillis,
      600005,
      reason: 'деньги целыми тысячными: 600.005 — это 600005, а не 600.0',
    );
    expect(links.single.reason, 'issued');
  });

  test('ключ не даёт связать один возврат с одной бумажкой дважды', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    await db.certificateDao.linkRefund(
      refundLocalId: 7,
      sourceNumber: 'C-1',
      issuedNumber: 'C-1-R7',
      amount: Decimal.parse('500'),
      reason: CertificateRefundReason.issued,
      time: 1700000000,
    );

    // **Второй выпуск по тому же возврату — это напечатанные деньги.**
    // Первая линия (проверка журнала перед выпуском) живёт в
    // `RefundUseCaseImpl`; здесь мерится вторая, структурная.
    await expectLater(
      db.certificateDao.linkRefund(
        refundLocalId: 7,
        sourceNumber: 'C-1',
        issuedNumber: 'C-1-R7-again',
        amount: Decimal.parse('500'),
        reason: CertificateRefundReason.issued,
        time: 1700000001,
      ),
      throwsA(anything),
    );

    expect(await db.certificateDao.linksByRefund(7), hasLength(1));
  });

  test('тот же сертификат, другой возврат — связь законна', () async {
    final db = await openFromPrevious();
    addTearDown(db.close);

    await db.certificateDao.linkRefund(
      refundLocalId: 1,
      sourceNumber: 'C-1',
      amount: Decimal.parse('100'),
      reason: CertificateRefundReason.redeemed,
      time: 1700000000,
    );
    // Ключ по **паре**: одна бумажка живёт годами и законно попадает в
    // разные возвраты. Ключ по одному номеру запер бы её навсегда.
    await db.certificateDao.linkRefund(
      refundLocalId: 2,
      sourceNumber: 'C-1',
      amount: Decimal.parse('200'),
      reason: CertificateRefundReason.redeemed,
      time: 1700000001,
    );

    expect(await db.certificateDao.linksByRefund(1), hasLength(1));
    expect(await db.certificateDao.linksByRefund(2), hasLength(1));
  });
}
