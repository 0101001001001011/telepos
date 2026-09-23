/// Адрес продавца доезжает до чека — в любой стране.
///
/// # Что измерено 2026-09-21
///
/// Адрес продавца не попадал на чек **никогда и ни в одной стране**.
/// Цепочка была такой: поля `legalAddress`/`actualAddress` жили в модели
/// мастера, `updateOrganization` их принимал — и ни один экран их не
/// заполнял. Единственный писатель, `setup_repository_local.dart`, брал
/// оттуда `null` и клал его в настройки WebKassa, то есть только при
/// включённой казахстанской фискализации.
///
/// Итог: у кассы вне Казахстана адреса не было вовсе, а у казахстанской он
/// был пустым.
///
/// # Что проверяется здесь
///
/// Что адрес живёт у САМОЙ кассы и оттуда попадает в реквизиты чека, а
/// настройки фискального оператора остались запасным источником, а не
/// единственным.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/receipt_requisites.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          ThisPosEntriesCompanion.insert(
            companyName: const Value('Northwind Trading'),
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> setTillAddress(String? value) => db
      .update(db.thisPosEntries)
      .write(ThisPosEntriesCompanion(storeAddress: Value(value)));

  test('адрес кассы попадает в реквизиты чека', () async {
    await setTillAddress('1600 Blake Street, Denver, CO 80202');

    final requisites = await buildReceiptRequisites(db, posId: 1, operationId: 1, isSale: true);

    expect(
      requisites.seller.address,
      '1600 Blake Street, Denver, CO 80202',
      reason:
          'без адреса покупатель не видит, где сделана покупка; в США это '
          'обычная часть чека',
    );
  });

  test('без фискализации адрес всё равно есть', () async {
    // Несущий случай: у кассы США настроек WebKassa нет и быть не может.
    // До правки это означало чек без адреса.
    await setTillAddress('1600 Blake Street, Denver, CO 80202');
    expect(
      await db.select(db.webkassaConfigs).get(),
      isEmpty,
      reason: 'предпосылка: фискального конфига нет',
    );

    final requisites = await buildReceiptRequisites(db, posId: 1, operationId: 1, isSale: true);
    expect(requisites.seller.address, isNotNull);
  });

  test('настройки ОФД остались запасным источником, а не единственным',
      () async {
    await setTillAddress(null);
    await db.webkassaReceiptDao.createConfig(
      posId: 1,
      posFactoryNo: 'SN-1',
      taxpayerName: 'Northwind',
      iinBin: '123456789012',
      address: 'ул. Абая, 10, Алматы',
      isActive: true,
      isTaxpayer: true,
    );

    final requisites = await buildReceiptRequisites(db, posId: 1, operationId: 1, isSale: true);

    expect(
      requisites.seller.address,
      'ул. Абая, 10, Алматы',
      reason:
          'касса, где адрес ввели через настройку ОФД, обязана печатать '
          'его и дальше — иначе обновление отняло бы строку у чека',
    );
  });

  test('идентификатор налогоплательщика печатается маской страны', () async {
    // Форматировщик `CountryCode.formatTaxId` существовал и не звался
    // НИКЕМ: чек печатал «Business ID: 841234567» девятью голыми цифрами,
    // и на американской ленте это читалось как чужой номер.
    await db
        .update(db.thisPosEntries)
        .write(
          const ThisPosEntriesCompanion(
            countryCode: Value(4),
            iinbin: Value('841234567'),
          ),
        );

    final requisites = await buildReceiptRequisites(
      db,
      posId: 1,
      operationId: 1,
      isSale: true,
    );

    expect(requisites.seller.binIin, '84-1234567');
  });

  test('казахстанский номер маска не трогает', () async {
    await db
        .update(db.thisPosEntries)
        .write(
          const ThisPosEntriesCompanion(
            countryCode: Value(0),
            iinbin: Value('123456789012'),
          ),
        );

    final requisites = await buildReceiptRequisites(
      db,
      posId: 1,
      operationId: 1,
      isSale: true,
    );

    expect(
      requisites.seller.binIin,
      '123456789012',
      reason: 'у БИН разделителей нет, и придумывать их нечего',
    );
  });

  test('адрес кассы главнее адреса ОФД', () async {
    await setTillAddress('1600 Blake Street, Denver, CO 80202');
    await db.webkassaReceiptDao.createConfig(
      posId: 1,
      posFactoryNo: 'SN-1',
      taxpayerName: 'Northwind',
      iinBin: '123456789012',
      address: 'ул. Абая, 10, Алматы',
      isActive: true,
      isTaxpayer: true,
    );

    final requisites = await buildReceiptRequisites(db, posId: 1, operationId: 1, isSale: true);

    expect(
      requisites.seller.address,
      startsWith('1600 Blake'),
      reason:
          'адрес правят в настройке кассы; будь старший источник обратным, '
          'правка не давала бы никакого видимого действия',
    );
  });
}
