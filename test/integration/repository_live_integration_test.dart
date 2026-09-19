library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/repositories/product_repository_impl.dart';
import 'package:telepos/data/repositories/payment_repository_impl.dart';
import 'package:telepos/data/repositories/shift_repository_impl.dart';
import 'package:telepos/data/repositories/sale_repository_impl.dart';
import 'package:telepos/data/repositories/refund_repository_impl.dart';
import 'package:telepos/data/repositories/agent_repository_impl.dart';
import 'package:telepos/data/repositories/supply_repository_impl.dart';
import 'package:telepos/data/repositories/cash_operation_repository_impl.dart';
import 'package:telepos/domain/entities/payment/payment_entity.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/refund/refund_entity.dart';
import 'package:telepos/domain/entities/agent/agent_entity.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_entity.dart';

Decimal _d(String v) => Decimal.parse(v);

int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

AppDatabase _createDb() => AppDatabase.forTesting(NativeDatabase.memory());

Future<({int posAccountId, int bankAccountId})> _seed(AppDatabase db) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(1),
          createTime: DateTime.now(),
        ),
      );

  final posAccId = await db.accountDao.createPosAccount(name: 'Касса');
  final bankAccId = await db.accountDao.createAcquiringAccount(
    name: 'Kaspi',
    acquirerId: 1,
  );

  await db.thisPosDao.insertInitialConfig(
    companyName: 'ТОО Тест',
    iinbin: '123456789012',
    cashBoxName: 'Касса-1',
    countryCode: 0,
    currencyCode: 0,
    currencySymbol: '₸',
    currencyNameShort: 'KZT',
    paperWidth: 48,
    printerHeader: null,
    printerFooter: null,
    accountId: posAccId,
    acquiringAccountId: bankAccId,
    rsaPublicKey: null,
    sendToOfd: false,
    cashInOut: true,
  );

  await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
      .write(const ThisPosEntriesCompanion(id: Value(1)));

  final cashierId = await db.userDao.createCashier(
    name: 'Кассир Айгуль',
    passwordEnc: null,
  );
  // Задача 14: `createCashier` строк прав не пишет, а после переворота
  // умолчания (задача 16) пустая таблица означает «ничего нельзя».
  // Права заводятся тем же вызовом, каким это делает рабочий код.
  await db.userPermissionDao.setPermissions(cashierId, {
    for (final key in PermissionKeys.allPermissions) key: true,
  });

  final products = [
    (
      ucode: 1001,
      barcode: 4607001,
      name: 'Молоко 1л',
      price: '450',
      type: 0,
      measure: 0,
    ),
    (
      ucode: 1002,
      barcode: 4607002,
      name: 'Хлеб белый',
      price: '150',
      type: 0,
      measure: 0,
    ),
    (
      ucode: 1003,
      barcode: 4607003,
      name: 'Сахар 1кг',
      price: '280',
      type: 0,
      measure: 0,
    ),
    (
      ucode: 2001,
      barcode: 2000001,
      name: 'Яблоки Голден',
      price: '600',
      type: 1,
      measure: 1,
    ),
  ];

  for (final p in products) {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(p.ucode),
            barcode: Value(p.barcode),
            name: Value(p.name),
            type: Value(p.type),
            measure: Value(p.measure),
            quantity: Value(_d('100')),
            categoryId: const Value(1),
            isDeleted: const Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: Value(p.ucode),
            barcode: Value(p.barcode),
            sellingPrice: Value(_d(p.price)),
          ),
        );
  }

  return (posAccountId: posAccId, bankAccountId: bankAccId);
}

void main() {
  late AppDatabase db;
  late int posAccId;
  late int bankAccId;

  setUp(() async {
    db = _createDb();
    final ids = await _seed(db);
    posAccId = ids.posAccountId;
    bankAccId = ids.bankAccountId;
  });

  tearDown(() => db.close());

  group('ProductRepository live DB', () {
    late ProductRepositoryImpl repo;

    setUp(() => repo = ProductRepositoryImpl(db));

    test(
      'findByBarcode returns product with correct unitName for normal product',
      () async {
        final info = await repo.findByBarcode(4607001);

        expect(info, isNotNull);
        expect(info!.ucode, 1001);
        expect(info.name, 'Молоко 1л');
        expect(info.unitName, 'шт');
        expect(info.isWeightProduct, false);
        expect(info.categoryId, 1);
      },
    );

    test(
      'findByBarcode returns weight product with кг and isWeightProduct=true',
      () async {
        final info = await repo.findByBarcode(2000001);

        expect(info, isNotNull);
        expect(info!.ucode, 2001);
        expect(info.name, 'Яблоки Голден');
        expect(info.unitName, 'кг');
        expect(info.isWeightProduct, true);
      },
    );

    test('findByUcode returns product with correct fields', () async {
      final info = await repo.findByUcode(1002);

      expect(info, isNotNull);
      expect(info!.name, 'Хлеб белый');
      expect(info.barcode, 4607002);
      expect(info.unitName, 'шт');
      expect(info.isWeightProduct, false);
    });

    test('findByBarcode returns null for non-existent barcode', () async {
      final info = await repo.findByBarcode(9999999);

      expect(info, isNull);
    });

    test(
      'search returns products matching query with correct field mapping',
      () async {
        final results = await repo.search('%Молоко%');

        expect(results.length, 1);
        expect(results.first.name, 'Молоко 1л');
        expect(results.first.unitName, 'шт');
      },
    );

    test('search returns both normal and weight products', () async {
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion(
              ucode: const Value(3001),
              barcode: const Value(3000001),
              name: const Value('Масло подсолнечное'),
              type: const Value(0),
              measure: const Value(2),
              quantity: Value(_d('50')),
              categoryId: const Value(1),
              isDeleted: const Value(false),
            ),
          );

      final all = await repo.search('%');

      final liter = all.firstWhere((p) => p.ucode == 3001);
      expect(liter.unitName, 'литр');
      expect(liter.isWeightProduct, false);

      final weight = all.firstWhere((p) => p.ucode == 2001);
      expect(weight.unitName, 'кг');
      expect(weight.isWeightProduct, true);
    });

    test('count returns correct number of non-deleted products', () async {
      final count = await repo.count();

      expect(count, 4);
    });
  });

  group('PaymentRepository live DB', () {
    late PaymentRepositoryImpl repo;

    setUp(() async {
      repo = PaymentRepositoryImpl(db);
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 1,
              userId: 1,
              amount: _d('1500'),
              time: _nowSec(),
              state: const Value(1),
            ),
          );
    });

    test('insertPayments batch inserts multiple payments atomically', () async {
      final payments = [
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: posAccId,
          amount: _d('1000.000'),
          time: _nowSec(),
          state: 1,
        ),
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: bankAccId,
          amount: _d('500.000'),
          time: _nowSec(),
          state: 1,
        ),
      ];

      await repo.insertPayments(payments);

      final saved = await repo.findBySale(1, 1);
      expect(saved.length, 2);

      final cashPayment = saved.firstWhere((p) => p.payeeAccountId == posAccId);
      final cardPayment = saved.firstWhere(
        (p) => p.payeeAccountId == bankAccId,
      );
      expect(cashPayment.amount, _d('1000.000'));
      expect(cardPayment.amount, _d('500.000'));
    });

    test('insertPayments with empty list does nothing', () async {
      await repo.insertPayments([]);

      final saved = await repo.findBySale(1, 1);
      expect(saved, isEmpty);
    });

    test('insertPayments preserves Decimal precision', () async {
      await repo.insertPayments([
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: posAccId,
          amount: _d('1234.567'),
          time: _nowSec(),
          state: 1,
        ),
      ]);

      final saved = await repo.findBySale(1, 1);
      expect(saved.length, 1);
      expect(saved.first.amount, _d('1234.567'));
    });

    test('findByRefund returns payments linked to refund', () async {
      final refundId = await db
          .into(db.refunds)
          .insert(
            RefundsCompanion.insert(
              saleReceiptNo: const Value(1),
              salePosId: const Value(1),
              userId: 1,
              amount: Value(_d('500')),
              time: _nowSec(),
              state: const Value(1),
            ),
          );

      await repo.insertPayments([
        PaymentEntity(
          userId: 1,
          refundLocalId: refundId,
          payeeAccountId: posAccId,
          amount: _d('500.000'),
          time: _nowSec(),
          state: 1,
        ),
      ]);

      final refundPayments = await repo.findByRefund(refundId);
      expect(refundPayments.length, 1);
      expect(refundPayments.first.refundLocalId, refundId);
      expect(refundPayments.first.amount, _d('500.000'));
    });

    test('setState updates all sale payments', () async {
      await repo.insertPayments([
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: posAccId,
          amount: _d('1000.000'),
          time: _nowSec(),
          state: 1,
        ),
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: bankAccId,
          amount: _d('500.000'),
          time: _nowSec(),
          state: 1,
        ),
      ]);

      await repo.setState(1, 1, 4);

      final saved = await repo.findBySale(1, 1);
      for (final p in saved) {
        expect(p.state, 4);
      }
    });
  });

  group('ShiftRepository live DB', () {
    late ShiftRepositoryImpl repo;

    setUp(() => repo = ShiftRepositoryImpl(db));

    test('openShift creates shift via DAO and returns ID', () async {
      final shiftId = await repo.openShift(1);

      expect(shiftId, greaterThan(0));

      final entity = await repo.findById(shiftId);
      expect(entity, isNotNull);
      expect(entity!.userId, 1);
      expect(entity.isOpened, true);
      expect(entity.isSynced, false);
      expect(entity.closeTime, isNull);
    });

    test('closeShift updates shift via DAO', () async {
      final shiftId = await repo.openShift(1);
      final openedShift = await repo.findById(shiftId);
      final openTime = openedShift!.openTime;
      final closeTime = openTime + 28800;

      await repo.closeShift(
        shiftId,
        closeTime: closeTime,
        openTime: openTime,
        cashInPos: _d('150000.500'),
      );

      final closed = await repo.findById(shiftId);
      expect(closed, isNotNull);
      expect(closed!.isOpened, false);
      expect(closed.closeTime, closeTime);
      expect(closed.cashInPosOnShiftClose, _d('150000.500'));
    });

    test('findOpenedShift returns only the currently open shift', () async {
      expect(await repo.findOpenedShift(), isNull);

      final shiftId = await repo.openShift(1);
      final opened = await repo.findOpenedShift();
      expect(opened, isNotNull);
      expect(opened!.id, shiftId);

      await repo.closeShift(
        shiftId,
        closeTime: _nowSec(),
        openTime: opened.openTime,
        cashInPos: _d('0'),
      );

      expect(await repo.findOpenedShift(), isNull);
    });

    test('findLastClosed returns most recently closed shift', () async {
      final id1 = await repo.openShift(1);
      final shift1 = await repo.findById(id1);
      await repo.closeShift(
        id1,
        closeTime: _nowSec(),
        openTime: shift1!.openTime,
        cashInPos: _d('100'),
      );

      final id2 = await repo.openShift(1);
      final shift2 = await repo.findById(id2);
      await repo.closeShift(
        id2,
        closeTime: _nowSec() + 1,
        openTime: shift2!.openTime,
        cashInPos: _d('200'),
      );

      final lastClosed = await repo.findLastClosed();
      expect(lastClosed, isNotNull);
      expect(lastClosed!.id, id2);
      expect(lastClosed.cashInPosOnShiftClose, _d('200'));
    });

    test('markAsSynced updates sync flag', () async {
      final shiftId = await repo.openShift(1);

      var shift = await repo.findById(shiftId);
      expect(shift!.isSynced, false);

      await repo.markAsSynced(shiftId);

      shift = await repo.findById(shiftId);
      expect(shift!.isSynced, true);
    });

    test('countOpened tracks open shifts', () async {
      expect(await repo.countOpened(), 0);

      final id1 = await repo.openShift(1);
      expect(await repo.countOpened(), 1);

      final shift1 = await repo.findById(id1);
      await repo.closeShift(
        id1,
        closeTime: _nowSec(),
        openTime: shift1!.openTime,
        cashInPos: _d('0'),
      );
      expect(await repo.countOpened(), 0);
    });
  });

  group('SaleRepository live DB', () {
    late SaleRepositoryImpl repo;

    setUp(() => repo = SaleRepositoryImpl(db));

    test('insert and findByKey returns correct SaleEntity', () async {
      final entity = SaleEntity(
        receiptNo: 1,
        posId: 1,
        userId: 1,
        amount: _d('1050.000'),
        time: _nowSec(),
        state: 0,
      );

      await repo.insert(entity);

      final found = await repo.findByKey(1, 1);
      expect(found, isNotNull);
      expect(found!.receiptNo, 1);
      expect(found.posId, 1);
      expect(found.userId, 1);
      expect(found.amount, _d('1050.000'));
      expect(found.state, 0);
    });

    test('findByKey returns null for non-existent sale', () async {
      final found = await repo.findByKey(999, 999);
      expect(found, isNull);
    });

    test('findLastReceiptNo tracks sequence', () async {
      expect(await repo.findLastReceiptNo(), isNull);

      await repo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('100'),
          time: _nowSec(),
          state: 1,
        ),
      );
      expect(await repo.findLastReceiptNo(), 1);

      await repo.insert(
        SaleEntity(
          receiptNo: 5,
          posId: 1,
          userId: 1,
          amount: _d('200'),
          time: _nowSec(),
          state: 1,
        ),
      );
      expect(await repo.findLastReceiptNo(), 5);
    });

    test(
      'findInProgress returns only the state=0 sale of the asking terminal',
      () async {
        // `SaleMapper` не знает про `terminalId` (задача 3 плана «продажа с
        // браузерного терминала» сознательно этого не требует) — владелец
        // проставляется напрямую через drift, а не через `repo.insert`.
        await repo.insert(
          SaleEntity(
            receiptNo: 1,
            posId: 1,
            userId: 1,
            amount: _d('100'),
            time: _nowSec(),
            state: 0,
          ),
        );
        await (db.update(db.sales)..where(
              (s) => s.receiptNo.equals(1) & s.posId.equals(1),
            ))
            .write(const SalesCompanion(terminalId: Value(7)));

        await repo.insert(
          SaleEntity(
            receiptNo: 2,
            posId: 1,
            userId: 1,
            amount: _d('200'),
            time: _nowSec(),
            state: 1,
          ),
        );

        final inProgress = await repo.findInProgress(posId: 1, terminalId: 7);
        expect(inProgress, isNotNull);
        expect(inProgress!.receiptNo, 1);

        expect(
          await repo.findInProgress(posId: 1, terminalId: 9),
          isNull,
          reason: 'чужому рабочему месту чек не виден',
        );
      },
    );

    test('updateState changes sale state', () async {
      await repo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('100'),
          time: _nowSec(),
          state: 0,
        ),
      );

      await repo.updateState(1, 1, 1);

      final updated = await repo.findByKey(1, 1);
      expect(updated!.state, 1);
    });

    test('findByState returns correct sales', () async {
      await repo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('100'),
          time: _nowSec(),
          state: 1,
        ),
      );
      await repo.insert(
        SaleEntity(
          receiptNo: 2,
          posId: 1,
          userId: 1,
          amount: _d('200'),
          time: _nowSec(),
          state: 1,
        ),
      );
      await repo.insert(
        SaleEntity(
          receiptNo: 3,
          posId: 1,
          userId: 1,
          amount: _d('300'),
          time: _nowSec(),
          state: 4,
        ),
      );

      final pending = await repo.findByState(1);
      expect(pending.length, 2);

      final synced = await repo.findByState(4);
      expect(synced.length, 1);
      expect(synced.first.receiptNo, 3);
    });

    test('countWithState returns correct counts', () async {
      await repo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('100'),
          time: _nowSec(),
          state: 1,
        ),
      );
      await repo.insert(
        SaleEntity(
          receiptNo: 2,
          posId: 1,
          userId: 1,
          amount: _d('200'),
          time: _nowSec(),
          state: 1,
        ),
      );
      await repo.insert(
        SaleEntity(
          receiptNo: 3,
          posId: 1,
          userId: 1,
          amount: _d('300'),
          time: _nowSec(),
          state: 4,
        ),
      );

      expect(await repo.countWithState(1), 2);
      expect(await repo.countWithState(4), 1);
      expect(await repo.countWithState(0), 0);
    });

    test('Decimal precision preserved in amountOfShift', () async {
      final now = _nowSec();
      await repo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('1234.567'),
          time: now,
          state: 1,
        ),
      );
      await repo.insert(
        SaleEntity(
          receiptNo: 2,
          posId: 1,
          userId: 1,
          amount: _d('8765.433'),
          time: now + 1,
          state: 1,
        ),
      );

      final sum = await repo.amountOfShift(1, now - 1, now + 2);
      expect(sum, isNotNull);
      expect(sum, _d('10000.000'));
    });
  });

  group('RefundRepository live DB', () {
    late RefundRepositoryImpl repo;

    setUp(() async {
      repo = RefundRepositoryImpl(db);
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 1,
              userId: 1,
              amount: _d('1500'),
              time: _nowSec(),
              state: const Value(1),
            ),
          );
    });

    test('insert and findById returns correct RefundEntity', () async {
      final entity = RefundEntity(
        saleReceiptNo: 1,
        salePosId: 1,
        userId: 1,
        amount: _d('500.000'),
        time: _nowSec(),
        state: 0,
      );

      final localId = await repo.insert(entity);
      expect(localId, greaterThan(0));

      final found = await repo.findById(localId);
      expect(found, isNotNull);
      expect(found!.saleReceiptNo, 1);
      expect(found.salePosId, 1);
      expect(found.amount, _d('500.000'));
      expect(found.state, 0);
    });

    test('findById returns null for non-existent refund', () async {
      final found = await repo.findById(9999);
      expect(found, isNull);
    });

    test('findBySale returns refund for given sale', () async {
      await repo.insert(
        RefundEntity(
          saleReceiptNo: 1,
          salePosId: 1,
          userId: 1,
          amount: _d('500'),
          time: _nowSec(),
          state: 1,
        ),
      );

      final found = await repo.findBySale(1, 1);
      expect(found, isNotNull);
      expect(found!.saleReceiptNo, 1);
    });

    test('updateState changes refund state', () async {
      final localId = await repo.insert(
        RefundEntity(
          saleReceiptNo: 1,
          salePosId: 1,
          userId: 1,
          amount: _d('500'),
          time: _nowSec(),
          state: 0,
        ),
      );

      await repo.updateState(localId, 1);

      final updated = await repo.findById(localId);
      expect(updated!.state, 1);
    });

    test('findByState returns correct refunds', () async {
      await repo.insert(
        RefundEntity(
          saleReceiptNo: 1,
          salePosId: 1,
          userId: 1,
          amount: _d('100'),
          time: _nowSec(),
          state: 1,
        ),
      );

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 2,
              posId: 1,
              userId: 1,
              amount: _d('300'),
              time: _nowSec(),
              state: const Value(1),
            ),
          );
      await repo.insert(
        RefundEntity(
          saleReceiptNo: 2,
          salePosId: 1,
          userId: 1,
          amount: _d('300'),
          time: _nowSec(),
          state: 4,
        ),
      );

      final pending = await repo.findByState(1);
      expect(pending.length, 1);

      final synced = await repo.findByState(4);
      expect(synced.length, 1);
      expect(synced.first.amount, _d('300'));
    });

    test('findProducts returns mapped RefundProductEntity list', () async {
      final refundId = await repo.insert(
        RefundEntity(
          saleReceiptNo: 1,
          salePosId: 1,
          userId: 1,
          amount: _d('450'),
          time: _nowSec(),
          state: 1,
        ),
      );

      await db
          .into(db.refundProducts)
          .insert(
            RefundProductsCompanion(
              refundLocalId: Value(refundId),
              ucode: const Value(1001),
              price: Value(_d('450')),
              quantity: Value(_d('1')),
            ),
          );

      final products = await repo.findProducts(refundId);
      expect(products.length, 1);
      expect(products.first.ucode, 1001);
      expect(products.first.price, _d('450'));
      expect(products.first.quantity, _d('1'));
    });
  });

  group('AgentRepository live DB', () {
    late AgentRepositoryImpl repo;

    setUp(() => repo = AgentRepositoryImpl(db));

    test('create and findById returns correct AgentEntity', () async {
      final entity = AgentEntity(
        type: 1,
        name: 'Иванов Иван',
        phone: 77771234567,
        bin: '123456789012',
      );

      final localId = await repo.create(entity);
      expect(localId, greaterThan(0));

      final found = await repo.findById(localId);
      expect(found, isNotNull);
      expect(found!.name, 'Иванов Иван');
      expect(found.phone, 77771234567);
      expect(found.bin, '123456789012');
      expect(found.type, 1);
      expect(found.isDeleted, false);
    });

    test('findByPhone returns agent', () async {
      await repo.create(
        AgentEntity(type: 1, name: 'Петрова Мария', phone: 77009876543),
      );

      final found = await repo.findByPhone(77009876543);
      expect(found, isNotNull);
      expect(found!.name, 'Петрова Мария');
    });

    test('search finds agents across all types', () async {
      await repo.create(
        AgentEntity(type: 0, name: 'ОптТорг Поставщик', phone: 77001111111),
      );
      await repo.create(
        AgentEntity(type: 1, name: 'Оптовый Покупатель', phone: 77002222222),
      );
      await repo.create(
        AgentEntity(type: 2, name: 'Опытный Владелец', phone: 77003333333),
      );

      final results = await repo.search('%Опт%');

      expect(results.length, greaterThanOrEqualTo(2));
      final names = results.map((a) => a.name).toList();
      expect(names, contains('ОптТорг Поставщик'));
      expect(names, contains('Оптовый Покупатель'));
    });

    test('findByType returns agents of specific type', () async {
      await repo.create(
        AgentEntity(type: 0, name: 'Поставщик 1', phone: 77001111111),
      );
      await repo.create(
        AgentEntity(type: 0, name: 'Поставщик 2', phone: 77002222222),
      );
      await repo.create(
        AgentEntity(type: 1, name: 'Клиент 1', phone: 77003333333),
      );

      final suppliers = await repo.findByType(0);
      expect(suppliers.length, 2);
      expect(suppliers.every((a) => a.type == 0), true);

      final customers = await repo.findByType(1);
      expect(customers.length, 1);
      expect(customers.first.name, 'Клиент 1');
    });

    test('update modifies agent fields', () async {
      final localId = await repo.create(
        AgentEntity(type: 1, name: 'Old Name', phone: 77001111111),
      );

      await repo.update(
        AgentEntity(
          localId: localId,
          type: 1,
          name: 'New Name',
          phone: 77009999999,
        ),
      );

      final updated = await repo.findById(localId);
      expect(updated!.name, 'New Name');
      expect(updated.phone, 77009999999);
    });

    test('softDelete sets isDeleted flag', () async {
      final localId = await repo.create(
        AgentEntity(type: 1, name: 'To Delete', phone: 77001111111),
      );

      await repo.softDelete(localId);

      final found = await db.agentDao.findByLocalId(localId);
      expect(found, isNotNull);
      expect(found!.isDeleted, true);

      final customers = await repo.findByType(1);
      expect(customers.where((a) => a.localId == localId), isEmpty);
    });
  });

  group('SupplyRepository live DB', () {
    late SupplyRepositoryImpl repo;

    setUp(() => repo = SupplyRepositoryImpl(db));

    test('create and findById returns correct SupplyEntity', () async {
      final entity = SupplyEntity(
        supplierId: 1,
        accountId: posAccId,
        amount: _d('50000.000'),
        editTime: _nowSec(),
        paymentType: 0,
        state: 0,
      );

      final id = await repo.create(entity);
      expect(id, greaterThan(0));

      final found = await repo.findById(id);
      expect(found, isNotNull);
      expect(found!.supplierId, 1);
      expect(found.amount, _d('50000.000'));
      expect(found.paymentType, 0);
    });

    test('addProduct and findProducts returns correct entities', () async {
      final supplyId = await repo.create(
        SupplyEntity(supplierId: 1, editTime: _nowSec(), state: 0),
      );

      await repo.addProduct(
        SupplyProductEntity(
          supplyId: supplyId,
          ucode: 1001,
          quantity: _d('10'),
          price: _d('400'),
          amount: _d('4000'),
        ),
      );
      await repo.addProduct(
        SupplyProductEntity(
          supplyId: supplyId,
          ucode: 1002,
          quantity: _d('20'),
          price: _d('120'),
          amount: _d('2400'),
        ),
      );

      final products = await repo.findProducts(supplyId);
      expect(products.length, 2);

      final milk = products.firstWhere((p) => p.ucode == 1001);
      expect(milk.quantity, _d('10'));
      expect(milk.price, _d('400'));
      expect(milk.amount, _d('4000'));

      final bread = products.firstWhere((p) => p.ucode == 1002);
      expect(bread.quantity, _d('20'));
      expect(bread.price, _d('120'));
    });

    test('Decimal precision preserved in supply amount', () async {
      final id = await repo.create(
        SupplyEntity(
          supplierId: 1,
          amount: _d('123456.789'),
          editTime: _nowSec(),
          state: 0,
        ),
      );

      final found = await repo.findById(id);
      expect(found!.amount, _d('123456.789'));
    });

    test('findById returns null for non-existent supply', () async {
      final found = await repo.findById(9999);
      expect(found, isNull);
    });
  });

  group('CashOperationRepository live DB', () {
    late CashOperationRepositoryImpl repo;

    setUp(() => repo = CashOperationRepositoryImpl(db));

    test(
      'insert and findByShift returns correct CashOperationEntity',
      () async {
        final shiftOpenTime = _nowSec() - 3600;

        final entity = CashOperationEntity(
          type: 0,
          amount: _d('10000.000'),
          accountId: posAccId,
          userId: 1,
          note: 'Размен',
          docTime: _nowSec(),
          state: 1,
        );

        final id = await repo.insert(entity);
        expect(id, greaterThan(0));

        final operations = await repo.findByShift(shiftOpenTime);
        expect(operations.length, 1);
        expect(operations.first.type, 0);
        expect(operations.first.amount, _d('10000.000'));
        expect(operations.first.note, 'Размен');
        expect(operations.first.isInvestment, true);
        expect(operations.first.isExpense, false);
        expect(operations.first.isDividend, false);
      },
    );

    test('multiple cash operations types in same shift', () async {
      final shiftOpenTime = _nowSec() - 7200;

      await repo.insert(
        CashOperationEntity(
          type: 0,
          amount: _d('10000'),
          userId: 1,
          docTime: _nowSec() - 3600,
          state: 1,
        ),
      );

      await repo.insert(
        CashOperationEntity(
          type: 1,
          amount: _d('3000'),
          userId: 1,
          note: 'Канцтовары',
          docTime: _nowSec() - 1800,
          state: 1,
        ),
      );

      await repo.insert(
        CashOperationEntity(
          type: 2,
          amount: _d('5000'),
          userId: 1,
          docTime: _nowSec(),
          state: 1,
        ),
      );

      final operations = await repo.findByShift(shiftOpenTime);
      expect(operations.length, 3);

      final investment = operations.firstWhere((op) => op.type == 0);
      expect(investment.isInvestment, true);
      expect(investment.amount, _d('10000'));

      final expense = operations.firstWhere((op) => op.type == 1);
      expect(expense.isExpense, true);
      expect(expense.note, 'Канцтовары');

      final dividend = operations.firstWhere((op) => op.type == 2);
      expect(dividend.isDividend, true);
      expect(dividend.amount, _d('5000'));
    });

    test('findByShift returns empty for future shift open time', () async {
      await repo.insert(
        CashOperationEntity(
          type: 0,
          amount: _d('1000'),
          docTime: _nowSec(),
          state: 1,
        ),
      );

      final operations = await repo.findByShift(_nowSec() + 3600);
      expect(operations, isEmpty);
    });
  });

  group('Cross-repository full sale cycle', () {
    late SaleRepositoryImpl saleRepo;
    late PaymentRepositoryImpl paymentRepo;
    late ShiftRepositoryImpl shiftRepo;

    setUp(() {
      saleRepo = SaleRepositoryImpl(db);
      paymentRepo = PaymentRepositoryImpl(db);
      shiftRepo = ShiftRepositoryImpl(db);
    });

    test('open shift → create sale → add payments → close shift', () async {
      final shiftId = await shiftRepo.openShift(1);
      expect(await shiftRepo.countOpened(), 1);

      final now = _nowSec();
      await saleRepo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('1050.000'),
          time: now,
          state: 0,
        ),
      );

      await paymentRepo.insertPayments([
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: posAccId,
          amount: _d('800.000'),
          time: now,
          state: 1,
        ),
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: bankAccId,
          amount: _d('250.000'),
          time: now,
          state: 1,
        ),
      ]);

      final payments = await paymentRepo.findBySale(1, 1);
      expect(payments.length, 2);
      final totalPaid = payments.fold<Decimal>(
        Decimal.zero,
        (sum, p) => sum + p.amount,
      );
      expect(totalPaid, _d('1050.000'));

      await saleRepo.updateState(1, 1, 1);
      final sale = await saleRepo.findByKey(1, 1);
      expect(sale!.state, 1);

      final shift = await shiftRepo.findById(shiftId);
      await shiftRepo.closeShift(
        shiftId,
        closeTime: _nowSec(),
        openTime: shift!.openTime,
        cashInPos: _d('800.000'),
      );

      final closedShift = await shiftRepo.findById(shiftId);
      expect(closedShift!.isOpened, false);
      expect(closedShift.cashInPosOnShiftClose, _d('800.000'));
      expect(await shiftRepo.countOpened(), 0);
    });

    test('multiple sales with different payment methods', () async {
      final shiftId = await shiftRepo.openShift(1);
      final now = _nowSec();

      await saleRepo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('450'),
          time: now,
          state: 1,
        ),
      );
      await paymentRepo.insertPayments([
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: posAccId,
          amount: _d('450'),
          time: now,
          state: 1,
        ),
      ]);

      await saleRepo.insert(
        SaleEntity(
          receiptNo: 2,
          posId: 1,
          userId: 1,
          amount: _d('280'),
          time: now + 1,
          state: 1,
        ),
      );
      await paymentRepo.insertPayments([
        PaymentEntity(
          userId: 1,
          receiptNo: 2,
          posId: 1,
          payeeAccountId: bankAccId,
          amount: _d('280'),
          time: now + 1,
          state: 1,
        ),
      ]);

      await saleRepo.insert(
        SaleEntity(
          receiptNo: 3,
          posId: 1,
          userId: 1,
          amount: _d('1000'),
          time: now + 2,
          state: 1,
        ),
      );
      await paymentRepo.insertPayments([
        PaymentEntity(
          userId: 1,
          receiptNo: 3,
          posId: 1,
          payeeAccountId: posAccId,
          amount: _d('600'),
          time: now + 2,
          state: 1,
        ),
        PaymentEntity(
          userId: 1,
          receiptNo: 3,
          posId: 1,
          payeeAccountId: bankAccId,
          amount: _d('400'),
          time: now + 2,
          state: 1,
        ),
      ]);

      expect(await saleRepo.countWithState(1), 3);
      final shiftAmount = await saleRepo.amountOfShift(1, now - 1, now + 3);
      expect(shiftAmount, _d('1730.000'));

      expect((await paymentRepo.findBySale(1, 1)).length, 1);
      expect((await paymentRepo.findBySale(2, 1)).length, 1);
      expect((await paymentRepo.findBySale(3, 1)).length, 2);

      final shift = await shiftRepo.findById(shiftId);
      await shiftRepo.closeShift(
        shiftId,
        closeTime: _nowSec(),
        openTime: shift!.openTime,
        cashInPos: _d('1050'),
      );
    });
  });

  group('Decimal precision across repositories', () {
    test('all repositories preserve P18,S3 precision', () async {
      final saleRepo = SaleRepositoryImpl(db);
      final paymentRepo = PaymentRepositoryImpl(db);
      final supplyRepo = SupplyRepositoryImpl(db);
      final cashOpRepo = CashOperationRepositoryImpl(db);

      await saleRepo.insert(
        SaleEntity(
          receiptNo: 1,
          posId: 1,
          userId: 1,
          amount: _d('99999.999'),
          time: _nowSec(),
          state: 1,
        ),
      );
      final sale = await saleRepo.findByKey(1, 1);
      expect(sale!.amount, _d('99999.999'));

      await paymentRepo.insertPayments([
        PaymentEntity(
          userId: 1,
          receiptNo: 1,
          posId: 1,
          payeeAccountId: posAccId,
          amount: _d('12345.678'),
          time: _nowSec(),
          state: 1,
        ),
      ]);
      final payments = await paymentRepo.findBySale(1, 1);
      expect(payments.first.amount, _d('12345.678'));

      final supplyId = await supplyRepo.create(
        SupplyEntity(
          supplierId: 1,
          amount: _d('55555.555'),
          editTime: _nowSec(),
          state: 0,
        ),
      );
      final supply = await supplyRepo.findById(supplyId);
      expect(supply!.amount, _d('55555.555'));

      await cashOpRepo.insert(
        CashOperationEntity(
          type: 0,
          amount: _d('77777.777'),
          docTime: _nowSec(),
          state: 1,
        ),
      );
      final ops = await cashOpRepo.findByShift(_nowSec() - 3600);
      expect(ops.first.amount, _d('77777.777'));
    });
  });
}
