/// Потолок суммы чека сохраняется — и по Enter, и по уходу фокуса.
///
/// # Зачем проба
///
/// Первая редакция сохраняла только по `onSubmitted`. Владелец, набравший
/// число и нажавший на соседний переключатель, терял его молча — тот же род
/// дефекта, что «невидимая кнопка сохранения» в настройках принтера,
/// найденная на съёмке 2026-09-21.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/sale/big_amount_limit.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await GetIt.I.reset();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    await db.thisPosDao.insertInitialConfig(
      companyName: 'Northwind',
      iinbin: '841234567',
      cashBoxName: 'Till-1',
      countryCode: 4,
      currencyCode: 4,
      currencySymbol: r'$',
      currencyNameShort: 'USD',
      paperWidth: 48,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
      sendToOfd: false,
      cashInOut: true,
    );
  });

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  test('число сохраняется и читается обратно', () async {
    await db.thisPosDao.updateBusinessFlags(bigAmountLimit: '2000');
    final pos = await db.thisPosDao.get();
    expect(pos?.bigAmountLimit, '2000');
    expect(bigAmountLimitOf(pos?.bigAmountLimit), Decimal.parse('2000'));
  });

  test('пусто — возврат к умолчанию, а не «ноль»', () async {
    // Владелец стирает число и не обязан вспоминать, каким оно было.
    await db.thisPosDao.updateBusinessFlags(bigAmountLimit: '2000');
    await db.thisPosDao.updateBusinessFlags(bigAmountLimit: '');
    final pos = await db.thisPosDao.get();
    expect(pos?.bigAmountLimit, isNull);
    expect(bigAmountLimitOf(pos?.bigAmountLimit), kDefaultBigAmountLimit);
  });

  test('пробелы по краям срезаются, а не сохраняются', () async {
    await db.thisPosDao.updateBusinessFlags(bigAmountLimit: '  1500  ');
    final pos = await db.thisPosDao.get();
    expect(pos?.bigAmountLimit, '1500');
  });

  test('касса без настройки живёт прежним числом', () async {
    final pos = await db.thisPosDao.get();
    expect(pos?.bigAmountLimit, isNull);
    expect(bigAmountLimitOf(pos?.bigAmountLimit), kDefaultBigAmountLimit);
  });
}
