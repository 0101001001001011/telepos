import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';

/// Задача 3, круг правки 1: инвариант «владельца имеет только чек в
/// работе» был объявлен докстрингом колонки (`sale_tables.dart`,
/// задача 2) и спекой, но не соблюдался — `SaleDao.updateState` (и
/// однотипные `markSyncedByKey`/`setState`) переводили чек в любое
/// состояние, не трогая `terminalId`. Читателей у колонки сегодня нет
/// вне `findInProgress`, поэтому ложь в данных была не видна — но
/// каждая новая продажа, дойдя до отправленного или синхронизированного
/// состояния, несла бы устаревшего владельца навсегда.
///
/// Правило смысла: владельца имеет только `state = 0`. Переход в любое
/// другое состояние снимает владельца; переход в `state = 0` его не
/// трогает — владельца проставляет тот, кто поднимает чек, отдельной
/// записью, не этот метод.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedSale({
    required int receiptNo,
    required int posId,
    required int state,
    int? terminalId,
  }) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: Decimal.zero,
            time: 0,
            state: Value(state),
            terminalId: Value(terminalId),
          ),
        );
  }

  test(
    'updateState в отправленное состояние снимает владельца',
    () async {
      await seedSale(receiptNo: 1, posId: 1, state: 0, terminalId: 7);

      // Продажа завершается — переход в состояние «ожидает отправки»
      // (1), тем же путём, что `merge_tables_use_case_impl.dart`.
      await db.saleDao.updateState(1, 1, 1);

      final sale = await db.saleDao.findByKey(1, 1);
      expect(
        sale!.terminalId,
        isNull,
        reason: 'завершённый чек не может нести владельца — он больше не '
            'чек в работе, и любой будущий читатель колонки увидел бы '
            'устаревшего хозяина',
      );
      expect(sale.state, 1);
    },
  );

  test('updateState в отправленное (state=4) тоже снимает владельца', () async {
    await seedSale(receiptNo: 2, posId: 1, state: 0, terminalId: 7);

    await db.saleDao.updateState(2, 1, 4);

    expect((await db.saleDao.findByKey(2, 1))!.terminalId, isNull);
  });

  test(
    'updateState в state=0 владельца не трогает — не его дело',
    () async {
      // Слабость, найденная переразбором: посев `terminalId: null`
      // перед переходом не отличил бы «колонку не трогают» от «колонку
      // записали пустой» — оба дали бы один и тот же результат. Сеется
      // ненулевой владелец (42, не тот, кто вызывает `updateState` в
      // этом тесте) — метод обязан оставить его как есть.
      await seedSale(receiptNo: 3, posId: 1, state: 3, terminalId: 42);

      await db.saleDao.updateState(3, 1, 0);

      expect(
        (await db.saleDao.findByKey(3, 1))!.terminalId,
        42,
        reason: 'updateState не проставляет и не снимает владельца при '
            'переходе в state=0 — это работа того, кто поднимает чек '
            '(undeferSale и т.п.); значение до вызова обязано уцелеть',
      );
    },
  );

  test('markSyncedByKey тоже снимает владельца', () async {
    await seedSale(receiptNo: 4, posId: 1, state: 0, terminalId: 7);

    await db.saleDao.markSyncedByKey(4, 1);

    final sale = await db.saleDao.findByKey(4, 1);
    expect(sale!.state, 4);
    expect(sale.terminalId, isNull);
  });

  test('setState (пакетный переход) тоже снимает владельца', () async {
    await seedSale(receiptNo: 5, posId: 1, state: 0, terminalId: 7);
    await seedSale(receiptNo: 6, posId: 1, state: 0, terminalId: 9);

    await db.saleDao.setState(1, 1, [5, 6]);

    expect((await db.saleDao.findByKey(5, 1))!.terminalId, isNull);
    expect((await db.saleDao.findByKey(6, 1))!.terminalId, isNull);
  });
}
