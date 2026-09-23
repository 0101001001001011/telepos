/// Адрес продавца на чеке можно ПОМЕНЯТЬ, а не только завести мастером.
///
/// # Что измерено 2026-09-22
///
/// Адрес торговой точки заводил только мастер настройки. Поменять его было
/// нечем ни одним экраном: магазин переехал — на чеке остался прежний
/// адрес, и поправить его можно было лишь переустановкой.
///
/// Это обязательный реквизит документа во многих странах, и он же —
/// единственное, по чему покупатель находит магазин, куда идти с
/// возвратом.
///
/// # Предыстория
///
/// До схемы v56 (2026-09-21) адрес не попадал на чек ВООБЩЕ ни в одной
/// стране: поля мастера существовали, но ни один экран их не заполнял, а
/// записывались они только под казахстанской фискализацией.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/receipt_requisites.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          ThisPosEntriesCompanion(
            id: const Value(1),
            cashBoxName: const Value('Till-1'),
            countryCode: Value(CountryCode.usd.index),
            storeAddress: const Value('742 Evergreen Terrace'),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<String?> addressOnReceipt() async {
    final req = await buildReceiptRequisites(
      db,
      posId: null,
      operationId: null,
      isSale: true,
    );
    return req.seller.address;
  }

  test('адрес доезжает до чека в стране без фискализации', () async {
    // США: фискального оператора нет, и до схемы v56 адрес писался ТОЛЬКО
    // из его настроек — то есть на американском чеке его не было никогда.
    expect(await addressOnReceipt(), '742 Evergreen Terrace');
  });

  test('адрес правится настройкой', () async {
    await db.thisPosDao.updateBusinessFlags(
      storeAddress: '1600 Pennsylvania Avenue NW',
    );
    expect(await addressOnReceipt(), '1600 Pennsylvania Avenue NW');
  });

  test('пустое значение стирает адрес, а не пишет пустую строку', () async {
    // Пустая строка на чеке — это строка-призрак: место под адресом есть, а
    // адреса нет. Пусто означает «адреса нет», и блок не печатается.
    await db.thisPosDao.updateBusinessFlags(storeAddress: '   ');
    final pos = await db.thisPosDao.get();
    expect(pos?.storeAddress, isNull);
  });

  test('пробелы по краям срезаются', () async {
    await db.thisPosDao.updateBusinessFlags(
      storeAddress: '  221B Baker Street  ',
    );
    expect(await addressOnReceipt(), '221B Baker Street');
  });

  test('непереданный адрес не стирает прежний', () async {
    // `updateBusinessFlags` зовут и ради других полей. Молча обнулить
    // адрес при правке потолка суммы значило бы потерять реквизит чека на
    // действии, которое к нему не относится.
    await db.thisPosDao.updateBusinessFlags(bigAmountLimit: '2000');
    expect(await addressOnReceipt(), '742 Evergreen Terrace');
  });
}
