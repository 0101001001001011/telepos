import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';

/// Задача 3 плана «продажа с браузерного терминала».
///
/// До появления владельца `undeferSale` удаляла **любой** чек в работе,
/// прежде чем поднять отложенный, — единственный способ освободить место,
/// пока рабочее место на кассе было ровно одно. С владельцем (`terminalId`,
/// v37) это стало ошибкой: чужой чек в работе (другого рабочего места)
/// удалять больше не за что, его не путает с этим `findInProgress`.
void main() {
  late AppDatabase db;
  late DeferredSaleServiceImpl service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = DeferredSaleServiceImpl(db: db, logger: Talker());

    await db.thisPosDao.insertInitialConfig(
      posId: 1,
      companyName: 'ТОО Тест',
      iinbin: null,
      cashBoxName: 'Касса-1',
      countryCode: null,
      currencyCode: null,
      currencySymbol: null,
      currencyNameShort: null,
      paperWidth: null,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedSale({
    required int receiptNo,
    required int state,
    int? terminalId,
  }) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: 1,
            userId: 1,
            amount: Decimal.zero,
            time: 0,
            state: Value(state),
            terminalId: Value(terminalId),
          ),
        );
  }

  test(
    'undeferSale не удаляет чужой чек в работе, поднимает названному месту',
    () async {
      await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

      // Чужое рабочее место уже набирает свою корзину.
      await seedSale(receiptNo: 1, state: 0, terminalId: 999);
      // Отложенный чек, который поднимает седьмое рабочее место.
      await seedSale(receiptNo: 2, state: 3, terminalId: null);

      final undeferred = await service.undeferSale(receiptNo: 2, terminalId: 7);

      expect(undeferred, isNotNull);
      expect(undeferred!.state, 0);
      expect(
        undeferred.terminalId,
        7,
        reason: 'поднятый чек становится собственностью того, кто поднял, '
            'а не той кассы, в чьём процессе это исполняется',
      );

      final foreign = await db.saleDao.findByKey(1, 1);
      expect(
        foreign,
        isNotNull,
        reason: 'чужой чек в работе больше не удаляется',
      );
      expect(foreign!.state, 0);
      expect(foreign.terminalId, 999);
    },
  );

  test(
    'undeferSale не удаляет и собственный незавершённый чек (задача 17)',
    () async {
      final self = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

      await seedSale(receiptNo: 1, state: 0, terminalId: self.id);
      await seedSale(receiptNo: 2, state: 3, terminalId: null);

      await service.undeferSale(receiptNo: 2, terminalId: self.id);

      expect(
        await db.saleDao.findByKey(1, 1),
        isNotNull,
        reason: 'молчаливое удаление своего чека в работе — приём времён, '
            'когда корзина жила в памяти; теперь оно теряет набранные '
            'строки, и освобождение места — решение вызывающего',
      );
    },
  );

  test('undeferSale не трогает чек, который уже не отложен', () async {
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    // Чек уже поднят седьмым местом — он в работе, а не в пуле.
    await seedSale(receiptNo: 2, state: 0, terminalId: 7);

    final second = await service.undeferSale(receiptNo: 2, terminalId: 9);

    expect(
      second,
      isNull,
      reason: 'подъём не отложенного чека уводит его у владельца молча',
    );
    final row = await db.saleDao.findByKey(2, 1);
    expect(row!.terminalId, 7);
    expect(row.state, 0);
  });

  test('deferSale снимает владельца — отложенный чек ничей', () async {
    final self = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    await seedSale(receiptNo: 3, state: 0, terminalId: self.id);

    await service.deferSale(receiptNo: 3);

    final deferred = await db.saleDao.findByKey(3, 1);
    expect(deferred!.state, 3);
    expect(deferred.terminalId, isNull);
  });
}
