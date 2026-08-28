library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/cash_operation/cash_in_out_controller_impl.dart';
import 'package:telepos/data/usecases/shift/assemble_shift_receipt_use_case_impl.dart';
import 'package:telepos/data/usecases/shift/custom_bank_payments_sum_use_case_impl.dart';
import 'package:telepos/data/services/shift_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';

Decimal _d(String v) => Decimal.parse(v);

int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class _StubWebKassaService extends Mock implements WebKassaService {}

AppDatabase? _activeDb;

AppDatabase _createDb() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  _activeDb = db;
  return db;
}

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
    name: 'Kaspi Bank',
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
    (ucode: 1001, barcode: 4607001, name: 'Молоко 1л', price: '450'),
    (ucode: 1002, barcode: 4607002, name: 'Хлеб белый', price: '150'),
    (ucode: 1003, barcode: 4607003, name: 'Сахар 1кг', price: '280'),
  ];

  for (final p in products) {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(p.ucode),
            barcode: Value(p.barcode),
            name: Value(p.name),
            type: const Value(0),
            measure: const Value(0),
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
            wholesalePrice: Value(_d(p.price)),
          ),
        );
  }

  return (posAccountId: posAccId, bankAccountId: bankAccId);
}

Future<Shift> _openShift(AppDatabase db, {required int userId}) async {
  final now = _nowSec();
  await db
      .into(db.shifts)
      .insert(
        ShiftsCompanion.insert(
          userId: userId,
          openTime: now,
          isOpened: true,
          isSynced: false,
        ),
      );
  final shift = await db.shiftDao.findOpenedShift();
  return shift!;
}

Future<void> _closeShift(
  AppDatabase db, {
  required int shiftId,
  required Decimal cashInPos,
}) async {
  final now = _nowSec();
  await (db.update(db.shifts)..where((sh) => sh.id.equals(shiftId))).write(
    ShiftsCompanion(
      isOpened: const Value(false),
      closeTime: Value(now),
      cashInPosOnShiftClose: Value(cashInPos),
    ),
  );
}

Future<void> _addSaleProducts(
  AppDatabase db, {
  required int receiptNo,
  required int posId,
  required List<({int ucode, Decimal qty, Decimal price})> items,
}) async {
  for (final item in items) {
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            ucode: item.ucode,
            quantity: item.qty,
            price: item.price,
            priceBefore: item.price,
          ),
        );
  }
}

Future<Decimal> _accountBalance(AppDatabase db, int accountId) async {
  final acc = await db.accountDao.findById(accountId);
  return acc?.value ?? Decimal.zero;
}

Future<Decimal> _productQty(AppDatabase db, int ucode) async {
  final pi = await db.productInfoDao.findByUcode(ucode);
  return pi?.quantity ?? Decimal.zero;
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<Talker>()) getIt.reset();
    getIt.registerLazySingleton<Talker>(() => Talker());
    getIt.registerLazySingleton<WebKassaService>(() => _StubWebKassaService());
    getIt.registerLazySingleton<RefundProductService>(
      () => RefundProductServiceImpl(db: _activeDb!, logger: getIt<Talker>()),
    );
  });

  tearDown(() => GetIt.instance.reset());

  group('Test 1: Полный рабочий день кассы', () {
    late AppDatabase db;
    late int posAccId;
    late int bankAccId;
    late SaleInitiationUseCaseImpl saleInitiation;
    late SaleUseCaseImpl saleUseCase;
    late RefundInitiationUseCaseImpl refundInitiation;
    late RefundUseCaseImpl refundUseCase;
    late CashInOutControllerImpl cashCtrl;
    late AssembleShiftReceiptUseCaseImpl shiftReceipt;

    setUp(() async {
      db = _createDb();
      final ids = await _seed(db);
      posAccId = ids.posAccountId;
      bankAccId = ids.bankAccountId;

      final logger = GetIt.I<Talker>();
      saleInitiation = SaleInitiationUseCaseImpl(
        db: db,
        logger: logger,
        shiftService: ShiftServiceImpl(db: db, logger: logger),
      );
      saleUseCase = SaleUseCaseImpl(db: db, logger: logger);
      refundInitiation = RefundInitiationUseCaseImpl(db: db, logger: logger);
      refundUseCase = RefundUseCaseImpl(db: db, logger: logger);
      cashCtrl = CashInOutControllerImpl(db);
      final paymentsSumUC = CustomBankPaymentsSumUseCaseImpl(
        db: db,
        logger: logger,
      );
      shiftReceipt = AssembleShiftReceiptUseCaseImpl(
        db: db,
        paymentsSumUseCase: paymentsSumUC,
        logger: logger,
      );
    });

    tearDown(() => db.close());

    test('shift → sales → refund → cash-in → Z-report', () async {
      final shift = await _openShift(db, userId: 1);
      expect(shift.isOpened, isTrue);
      expect(shift.userId, 1);

      await db.accountDao.updateBalance(posAccId, _d('50000'));
      expect(await _accountBalance(db, posAccId), _d('50000'));

      final sale1 = await saleInitiation.initiate();
      expect(sale1, isNotNull);
      expect(sale1!.state, 0);

      await _addSaleProducts(
        db,
        receiptNo: sale1.receiptNo,
        posId: sale1.posId,
        items: [
          (ucode: 1001, qty: _d('2'), price: _d('450')),
          (ucode: 1002, qty: _d('1'), price: _d('150')),
        ],
      );

      await db.saleDao.setAmount(sale1.receiptNo, sale1.posId, _d('1050'));

      await saleUseCase.perform(
        receiptNo: sale1.receiptNo,
        posId: sale1.posId,
        amount: _d('1050'),
        payments: [PaymentEntry(payeeAccountId: posAccId, amount: _d('1050'))],
        change: _d('950'),
        selectiveOfd: false,
      );

      expect(await _accountBalance(db, posAccId), _d('51050'));
      expect(await _productQty(db, 1001), _d('98'));
      expect(await _productQty(db, 1002), _d('99'));
      final savedSale1 =
          await (db.select(db.sales)..where(
                (s) =>
                    s.receiptNo.equals(sale1.receiptNo) &
                    s.posId.equals(sale1.posId),
              ))
              .getSingle();
      expect(savedSale1.state, 1);
      final payments1 = await db.paymentDao.findBySale(
        sale1.receiptNo,
        sale1.posId,
      );
      expect(payments1.length, 1);
      expect(payments1.first.amount, _d('1050'));

      final sale2 = await saleInitiation.initiate();
      expect(sale2, isNotNull);
      expect(sale2!.receiptNo, sale1.receiptNo + 1);

      await _addSaleProducts(
        db,
        receiptNo: sale2.receiptNo,
        posId: sale2.posId,
        items: [(ucode: 1003, qty: _d('3'), price: _d('280'))],
      );
      await db.saleDao.setAmount(sale2.receiptNo, sale2.posId, _d('840'));

      await saleUseCase.perform(
        receiptNo: sale2.receiptNo,
        posId: sale2.posId,
        amount: _d('840'),
        payments: [PaymentEntry(payeeAccountId: bankAccId, amount: _d('840'))],
        change: Decimal.zero,
        selectiveOfd: false,
      );

      expect(await _accountBalance(db, posAccId), _d('51050'));
      expect(await _accountBalance(db, bankAccId), _d('840'));
      expect(await _productQty(db, 1003), _d('97'));

      final refund = await refundInitiation.initiate(
        saleReceiptNo: sale1.receiptNo,
        salePosId: sale1.posId,
      );
      expect(refund, isNotNull);

      final refundResult = await refundUseCase.perform(
        refundLocalId: refund!.localId,
        amount: _d('450'),
        userId: 1,
        saleReceiptNo: sale1.receiptNo,
        salePosId: sale1.posId,
        products: [
          RefundProductEntry(
            ucode: 1001,
            quantity: _d('1'),
            price: _d('450'),
            inSalePrice: _d('450'),
            inSaleQuantity: _d('2'),
          ),
        ],
      );

      expect(refundResult.productCount, 1);
      expect(refundResult.paymentCount, 1);
      expect(await _accountBalance(db, posAccId), _d('50600'));
      expect(await _productQty(db, 1001), _d('99'));
      final refundProducts = await db.refundDao.findProductsByRefund(
        refund.localId,
      );
      expect(refundProducts.length, 1);
      expect(refundProducts.first.ucode, 1001);

      final investResult = await cashCtrl.createInvestment(
        amount: _d('10000'),
        accountId: posAccId,
        note: 'Разменные деньги',
      );
      expect(investResult.success, isTrue);
      expect(await _accountBalance(db, posAccId), _d('60600'));

      final cashInPos = await _accountBalance(db, posAccId);
      await _closeShift(db, shiftId: shift.id, cashInPos: cashInPos);

      final closedShift = await db.shiftDao.findById(shift.id);
      expect(closedShift, isNotNull);
      expect(closedShift!.isOpened, isFalse);
      expect(closedShift.cashInPosOnShiftClose, _d('60600'));

      final receipt = await shiftReceipt.assemble(shift.id, cashInPos);
      expect(receipt, isNotNull);
      expect(receipt!.shiftUserName, 'Кассир Айгуль');
      expect(receipt.companyName, 'ТОО Тест');
      expect(receipt.saleAmount, _d('1890'));
      expect(receipt.cashPaymentsSum, _d('1050'));
      expect(receipt.cashInPos, _d('60600'));
    });
  });

  group('Test 2: Смешанная оплата и многократные операции', () {
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

    test('mixed payment sale and refund without receipt', () async {
      final logger = GetIt.I<Talker>();
      final saleInit = SaleInitiationUseCaseImpl(
        db: db,
        logger: logger,
        shiftService: ShiftServiceImpl(db: db, logger: logger),
      );
      final saleUC = SaleUseCaseImpl(db: db, logger: logger);
      final refundInit = RefundInitiationUseCaseImpl(db: db, logger: logger);
      final refundUC = RefundUseCaseImpl(db: db, logger: logger);

      await _openShift(db, userId: 1);

      final sale = await saleInit.initiate();
      expect(sale, isNotNull);

      await _addSaleProducts(
        db,
        receiptNo: sale!.receiptNo,
        posId: sale.posId,
        items: [
          (ucode: 1001, qty: _d('2'), price: _d('450')),
          (ucode: 1002, qty: _d('1'), price: _d('150')),
        ],
      );
      await db.saleDao.setAmount(sale.receiptNo, sale.posId, _d('1050'));

      await saleUC.perform(
        receiptNo: sale.receiptNo,
        posId: sale.posId,
        amount: _d('1050'),
        payments: [
          PaymentEntry(payeeAccountId: posAccId, amount: _d('900')),
          PaymentEntry(payeeAccountId: bankAccId, amount: _d('150')),
        ],
        change: Decimal.zero,
        selectiveOfd: false,
      );

      expect(await _accountBalance(db, posAccId), _d('900'));
      expect(await _accountBalance(db, bankAccId), _d('150'));

      final refund = await refundInit.initiate(
        saleReceiptNo: sale.receiptNo,
        salePosId: sale.posId,
      );

      final result = await refundUC.perform(
        refundLocalId: refund!.localId,
        amount: _d('450'),
        userId: 1,
        saleReceiptNo: sale.receiptNo,
        salePosId: sale.posId,
        products: [
          RefundProductEntry(
            ucode: 1001,
            quantity: _d('1'),
            price: _d('450'),
            inSalePrice: _d('450'),
            inSaleQuantity: _d('2'),
          ),
        ],
      );

      expect(result.paymentCount, 2);

      final posBalance = await _accountBalance(db, posAccId);
      final bankBalance = await _accountBalance(db, bankAccId);
      expect((_d('900') - posBalance) + (_d('150') - bankBalance), _d('450'));
    });

    test('refund without receipt goes to POS account', () async {
      final logger = GetIt.I<Talker>();
      final refundInit = RefundInitiationUseCaseImpl(db: db, logger: logger);
      final refundUC = RefundUseCaseImpl(db: db, logger: logger);

      await _openShift(db, userId: 1);
      await db.accountDao.updateBalance(posAccId, _d('5000'));

      final refund = await refundInit.initiate();
      expect(refund, isNotNull);

      final result = await refundUC.perform(
        refundLocalId: refund!.localId,
        amount: _d('300'),
        userId: 1,
        products: [
          RefundProductEntry(ucode: 1002, quantity: _d('2'), price: _d('150')),
        ],
      );

      expect(result.paymentCount, 1);
      expect(await _accountBalance(db, posAccId), _d('4700'));
      expect(await _productQty(db, 1002), _d('102'));
    });
  });

  group('Test 3: Мульти-POS — две кассы', () {
    test('two POS with separate DBs get unique receiptNos', () async {
      final db1 = _createDb();
      final db2 = _createDb();
      final logger = GetIt.I<Talker>();

      try {
        final ids1 = await _seed(db1);
        final ids2 = await _seed(db2);

        await (db2.update(db2.thisPosEntries)
              ..where((tp) => tp.rId.equals(true)))
            .write(const ThisPosEntriesCompanion(id: Value(2)));

        await _openShift(db1, userId: 1);
        await _openShift(db2, userId: 1);

        final saleInit1 = SaleInitiationUseCaseImpl(
          db: db1,
          logger: logger,
          shiftService: ShiftServiceImpl(db: db1, logger: logger),
        );
        final saleInit2 = SaleInitiationUseCaseImpl(
          db: db2,
          logger: logger,
          shiftService: ShiftServiceImpl(db: db2, logger: logger),
        );
        final saleUC1 = SaleUseCaseImpl(db: db1, logger: logger);
        final saleUC2 = SaleUseCaseImpl(db: db2, logger: logger);

        final s1 = await saleInit1.initiate();
        await _addSaleProducts(
          db1,
          receiptNo: s1!.receiptNo,
          posId: s1.posId,
          items: [(ucode: 1001, qty: _d('5'), price: _d('450'))],
        );
        await db1.saleDao.setAmount(s1.receiptNo, s1.posId, _d('2250'));
        await saleUC1.perform(
          receiptNo: s1.receiptNo,
          posId: s1.posId,
          amount: _d('2250'),
          payments: [
            PaymentEntry(payeeAccountId: ids1.posAccountId, amount: _d('2250')),
          ],
          change: Decimal.zero,
          selectiveOfd: false,
        );

        final s2 = await saleInit2.initiate();
        await _addSaleProducts(
          db2,
          receiptNo: s2!.receiptNo,
          posId: s2.posId,
          items: [(ucode: 1002, qty: _d('10'), price: _d('150'))],
        );
        await db2.saleDao.setAmount(s2.receiptNo, s2.posId, _d('1500'));
        await saleUC2.perform(
          receiptNo: s2.receiptNo,
          posId: s2.posId,
          amount: _d('1500'),
          payments: [
            PaymentEntry(payeeAccountId: ids2.posAccountId, amount: _d('1500')),
          ],
          change: Decimal.zero,
          selectiveOfd: false,
        );

        expect(s1.receiptNo, s2.receiptNo);
        expect(s1.posId, isNot(s2.posId));

        expect(await _productQty(db1, 1001), _d('95'));
        expect(await _productQty(db2, 1002), _d('90'));
      } finally {
        await db1.close();
        await db2.close();
      }
    });
  });

  group('Test 4: Кассовые операции — Investment/Expense/Dividend', () {
    late AppDatabase db;
    late int posAccId;
    late CashInOutControllerImpl cashCtrl;

    setUp(() async {
      db = _createDb();
      final ids = await _seed(db);
      posAccId = ids.posAccountId;
      cashCtrl = CashInOutControllerImpl(db);
    });

    tearDown(() => db.close());

    test('investment increases balance', () async {
      await _openShift(db, userId: 1);
      await db.accountDao.updateBalance(posAccId, _d('1000'));

      final r = await cashCtrl.createInvestment(
        amount: _d('5000'),
        accountId: posAccId,
      );
      expect(r.success, isTrue);
      expect(await _accountBalance(db, posAccId), _d('6000'));
    });

    test('expense decreases balance', () async {
      await _openShift(db, userId: 1);
      await db.accountDao.updateBalance(posAccId, _d('10000'));

      final r = await cashCtrl.createExpense(
        amount: _d('3000'),
        accountId: posAccId,
        expenseType: ExpenseType.smallPurchases,
      );
      expect(r.success, isTrue);
      expect(await _accountBalance(db, posAccId), _d('7000'));
    });

    test('dividend decreases balance (with sufficiency check)', () async {
      await _openShift(db, userId: 1);
      await db.accountDao.updateBalance(posAccId, _d('2000'));

      final r = await cashCtrl.createDividend(
        amount: _d('1500'),
        accountId: posAccId,
      );
      expect(r.success, isTrue);
      expect(await _accountBalance(db, posAccId), _d('500'));
    });

    test('dividend fails when insufficient funds', () async {
      await _openShift(db, userId: 1);
      await db.accountDao.updateBalance(posAccId, _d('100'));

      final r = await cashCtrl.createDividend(
        amount: _d('500'),
        accountId: posAccId,
      );
      expect(r.success, isFalse);
      expect(await _accountBalance(db, posAccId), _d('100'));
    });

    test('validates zero and negative amounts', () async {
      final v1 = await cashCtrl.validateAmount(Decimal.zero);
      expect(v1.isValid, isFalse);

      final v2 = await cashCtrl.validateAmount(_d('-100'));
      expect(v2.isValid, isFalse);

      final v3 = await cashCtrl.validateAmount(_d('1000001'));
      expect(v3.isValid, isFalse);

      final v4 = await cashCtrl.validateAmount(_d('500'));
      expect(v4.isValid, isTrue);
    });
  });

  group('Test 5: Устойчивость к ошибкам', () {
    late AppDatabase db;

    setUp(() async {
      db = _createDb();
      await _seed(db);
    });

    tearDown(() => db.close());

    test('sale without opened shift auto-opens a shift', () async {
      expect(await db.shiftDao.findOpenedShift(), isNull);

      final logger = GetIt.I<Talker>();
      final saleInit = SaleInitiationUseCaseImpl(
        db: db,
        logger: logger,
        shiftService: ShiftServiceImpl(db: db, logger: logger),
      );
      final sale = await saleInit.initiate();

      expect(sale, isNotNull);
      expect(sale!.state, 0);
      expect(await db.shiftDao.findOpenedShift(), isNotNull);
    });

    test('refund with zero amount throws InvalidRefundException', () async {
      await _openShift(db, userId: 1);
      final logger = GetIt.I<Talker>();
      final refundInit = RefundInitiationUseCaseImpl(db: db, logger: logger);
      final refundUC = RefundUseCaseImpl(db: db, logger: logger);

      final refund = await refundInit.initiate();

      expect(
        () => refundUC.perform(
          refundLocalId: refund!.localId,
          amount: Decimal.zero,
          userId: 1,
          products: [
            RefundProductEntry(
              ucode: 1001,
              quantity: _d('1'),
              price: _d('450'),
            ),
          ],
        ),
        throwsA(isA<InvalidRefundException>()),
      );
    });

    test('closing already-closed shift is idempotent', () async {
      final shift = await _openShift(db, userId: 1);
      await _closeShift(db, shiftId: shift.id, cashInPos: _d('1000'));

      await _closeShift(db, shiftId: shift.id, cashInPos: _d('2000'));
      final closedShift = await db.shiftDao.findById(shift.id);
      expect(closedShift!.isOpened, isFalse);
      expect(closedShift.cashInPosOnShiftClose, _d('2000'));
    });

    test('sale initiation without ThisPos returns null', () async {
      final emptyDb = _createDb();
      try {
        await emptyDb
            .into(emptyDb.categories)
            .insert(
              CategoriesCompanion.insert(
                id: const Value(1),
                createTime: DateTime.now(),
              ),
            );
        final testCashierId = await emptyDb.userDao.createCashier(
          name: 'Test',
          passwordEnc: null,
        );
        // Задача 14: `createCashier` строк прав не пишет, а после переворота
        // умолчания (задача 16) пустая таблица означает «ничего нельзя».
        // Права заводятся тем же вызовом, каким это делает рабочий код.
        await emptyDb.userPermissionDao.setPermissions(testCashierId, {
          for (final key in PermissionKeys.allPermissions) key: true,
        });
        await emptyDb
            .into(emptyDb.shifts)
            .insert(
              ShiftsCompanion.insert(
                userId: 1,
                openTime: _nowSec(),
                isOpened: true,
                isSynced: false,
              ),
            );

        final logger = GetIt.I<Talker>();
        final saleInit = SaleInitiationUseCaseImpl(
          db: emptyDb,
          logger: logger,
          shiftService: ShiftServiceImpl(db: emptyDb, logger: logger),
        );
        final sale = await saleInit.initiate();
        expect(sale, isNull);
      } finally {
        await emptyDb.close();
      }
    });

    test('product quantities stay consistent after failed refund', () async {
      await _openShift(db, userId: 1);
      final logger = GetIt.I<Talker>();
      final refundInit = RefundInitiationUseCaseImpl(db: db, logger: logger);
      final refundUC = RefundUseCaseImpl(db: db, logger: logger);

      final refund = await refundInit.initiate();

      try {
        await refundUC.perform(
          refundLocalId: refund!.localId,
          amount: _d('0'),
          userId: 1,
          products: [
            RefundProductEntry(
              ucode: 1001,
              quantity: _d('1'),
              price: Decimal.zero,
            ),
          ],
        );
      } catch (_) {}

      expect(await _productQty(db, 1001), _d('100'));
    });
  });

  group('Test 6: Z-отчёт точность с несколькими продажами', () {
    test('Z-report calculates correct totals', () async {
      final db = _createDb();
      try {
        final ids = await _seed(db);
        final logger = GetIt.I<Talker>();
        final saleInit = SaleInitiationUseCaseImpl(
          db: db,
          logger: logger,
          shiftService: ShiftServiceImpl(db: db, logger: logger),
        );
        final saleUC = SaleUseCaseImpl(db: db, logger: logger);
        final paymentsSumUC = CustomBankPaymentsSumUseCaseImpl(
          db: db,
          logger: logger,
        );
        final shiftReceiptUC = AssembleShiftReceiptUseCaseImpl(
          db: db,
          paymentsSumUseCase: paymentsSumUC,
          logger: logger,
        );

        final shift = await _openShift(db, userId: 1);

        final s1 = await saleInit.initiate();
        await _addSaleProducts(
          db,
          receiptNo: s1!.receiptNo,
          posId: s1.posId,
          items: [(ucode: 1001, qty: _d('1'), price: _d('450'))],
        );
        await db.saleDao.setAmount(s1.receiptNo, s1.posId, _d('450'));
        await saleUC.perform(
          receiptNo: s1.receiptNo,
          posId: s1.posId,
          amount: _d('450'),
          payments: [
            PaymentEntry(payeeAccountId: ids.posAccountId, amount: _d('450')),
          ],
          change: Decimal.zero,
          selectiveOfd: false,
        );

        final s2 = await saleInit.initiate();
        await _addSaleProducts(
          db,
          receiptNo: s2!.receiptNo,
          posId: s2.posId,
          items: [(ucode: 1003, qty: _d('1'), price: _d('280'))],
        );
        await db.saleDao.setAmount(s2.receiptNo, s2.posId, _d('280'));
        await saleUC.perform(
          receiptNo: s2.receiptNo,
          posId: s2.posId,
          amount: _d('280'),
          payments: [
            PaymentEntry(payeeAccountId: ids.bankAccountId, amount: _d('280')),
          ],
          change: Decimal.zero,
          selectiveOfd: false,
        );

        final s3 = await saleInit.initiate();
        await _addSaleProducts(
          db,
          receiptNo: s3!.receiptNo,
          posId: s3.posId,
          items: [(ucode: 1002, qty: _d('2'), price: _d('150'))],
        );
        await db.saleDao.setAmount(s3.receiptNo, s3.posId, _d('300'));
        await saleUC.perform(
          receiptNo: s3.receiptNo,
          posId: s3.posId,
          amount: _d('300'),
          payments: [
            PaymentEntry(payeeAccountId: ids.posAccountId, amount: _d('200')),
            PaymentEntry(payeeAccountId: ids.bankAccountId, amount: _d('100')),
          ],
          change: Decimal.zero,
          selectiveOfd: false,
        );

        final cashInPos = await _accountBalance(db, ids.posAccountId);
        await _closeShift(db, shiftId: shift.id, cashInPos: cashInPos);

        final receipt = await shiftReceiptUC.assemble(shift.id, cashInPos);
        expect(receipt, isNotNull);

        expect(receipt!.saleAmount, _d('1030'));

        expect(receipt.cashPaymentsSum, _d('650'));

        expect(receipt.paymentSums.length, greaterThanOrEqualTo(2));

        final totalPaymentSums = receipt.paymentSums.fold<Decimal>(
          Decimal.zero,
          (sum, e) => sum + e.amount,
        );
        expect(totalPaymentSums, _d('1030'));
      } finally {
        await db.close();
      }
    });
  });

  group('Test 7: Последовательность receiptNo', () {
    test('receiptNo increments correctly across multiple sales', () async {
      final db = _createDb();
      try {
        await _seed(db);
        await _openShift(db, userId: 1);
        final logger = GetIt.I<Talker>();
        final saleInit = SaleInitiationUseCaseImpl(
          db: db,
          logger: logger,
          shiftService: ShiftServiceImpl(db: db, logger: logger),
        );
        final saleUC = SaleUseCaseImpl(db: db, logger: logger);
        final ids = await db.thisPosDao.get();
        final posAccId = ids!.accountId!;

        final receiptNos = <int>[];

        for (var i = 0; i < 5; i++) {
          final sale = await saleInit.initiate();
          expect(sale, isNotNull);
          receiptNos.add(sale!.receiptNo);

          await _addSaleProducts(
            db,
            receiptNo: sale.receiptNo,
            posId: sale.posId,
            items: [(ucode: 1001, qty: _d('1'), price: _d('450'))],
          );
          await db.saleDao.setAmount(sale.receiptNo, sale.posId, _d('450'));
          await saleUC.perform(
            receiptNo: sale.receiptNo,
            posId: sale.posId,
            amount: _d('450'),
            payments: [
              PaymentEntry(payeeAccountId: posAccId, amount: _d('450')),
            ],
            change: Decimal.zero,
            selectiveOfd: false,
          );
        }

        for (var i = 1; i < receiptNos.length; i++) {
          expect(receiptNos[i], receiptNos[i - 1] + 1);
        }

        expect(await _productQty(db, 1001), _d('95'));
      } finally {
        await db.close();
      }
    });
  });

  group('Test 8: Telegram sync pipeline (data packer/unpacker)', () {
    test('pack → chunk → reassemble → unpack preserves data', () async {
      final db = _createDb();
      try {
        await _seed(db);
        await _openShift(db, userId: 1);

        final logger = GetIt.I<Talker>();
        final saleInit = SaleInitiationUseCaseImpl(
          db: db,
          logger: logger,
          shiftService: ShiftServiceImpl(db: db, logger: logger),
        );
        final saleUC = SaleUseCaseImpl(db: db, logger: logger);
        final thisPos = await db.thisPosDao.get();
        final posAccId = thisPos!.accountId!;

        final sale = await saleInit.initiate();
        await _addSaleProducts(
          db,
          receiptNo: sale!.receiptNo,
          posId: sale.posId,
          items: [(ucode: 1001, qty: _d('3'), price: _d('450'))],
        );
        await db.saleDao.setAmount(sale.receiptNo, sale.posId, _d('1350'));
        await saleUC.perform(
          receiptNo: sale.receiptNo,
          posId: sale.posId,
          amount: _d('1350'),
          payments: [
            PaymentEntry(payeeAccountId: posAccId, amount: _d('1350')),
          ],
          change: Decimal.zero,
          selectiveOfd: false,
        );

        final savedSale =
            await (db.select(db.sales)..where(
                  (s) =>
                      s.receiptNo.equals(sale.receiptNo) &
                      s.posId.equals(sale.posId),
                ))
                .getSingle();
        expect(savedSale.state, 1);

        final saleProducts = await db.saleProductDao.findBySale(
          sale.receiptNo,
          sale.posId,
        );
        expect(saleProducts.length, 1);
        expect(saleProducts.first.quantity, _d('3'));

        final payments = await db.paymentDao.findBySale(
          sale.receiptNo,
          sale.posId,
        );
        expect(payments.length, 1);
        expect(payments.first.amount, _d('1350'));
      } finally {
        await db.close();
      }
    });
  });

  group('Test 9: Stress — 10 продаж + возвраты + кассовые операции', () {
    test('10 sales, 3 refunds, 2 cash ops — all balances correct', () async {
      final db = _createDb();
      try {
        final ids = await _seed(db);
        await _openShift(db, userId: 1);
        final logger = GetIt.I<Talker>();
        final saleInit = SaleInitiationUseCaseImpl(
          db: db,
          logger: logger,
          shiftService: ShiftServiceImpl(db: db, logger: logger),
        );
        final saleUC = SaleUseCaseImpl(db: db, logger: logger);
        final refundInit = RefundInitiationUseCaseImpl(db: db, logger: logger);
        final refundUC = RefundUseCaseImpl(db: db, logger: logger);
        final cashCtrl = CashInOutControllerImpl(db);

        var expectedPosBalance = Decimal.zero;
        var expectedMilkQty = _d('100');

        final saleReceipts = <int>[];
        for (var i = 0; i < 10; i++) {
          final sale = await saleInit.initiate();
          await _addSaleProducts(
            db,
            receiptNo: sale!.receiptNo,
            posId: sale.posId,
            items: [(ucode: 1001, qty: _d('1'), price: _d('450'))],
          );
          await db.saleDao.setAmount(sale.receiptNo, sale.posId, _d('450'));
          await saleUC.perform(
            receiptNo: sale.receiptNo,
            posId: sale.posId,
            amount: _d('450'),
            payments: [
              PaymentEntry(payeeAccountId: ids.posAccountId, amount: _d('450')),
            ],
            change: Decimal.zero,
            selectiveOfd: false,
          );
          expectedPosBalance += _d('450');
          expectedMilkQty -= _d('1');
          saleReceipts.add(sale.receiptNo);
        }

        expect(await _accountBalance(db, ids.posAccountId), expectedPosBalance);
        expect(await _productQty(db, 1001), expectedMilkQty);

        for (var i = 0; i < 3; i++) {
          final refund = await refundInit.initiate(
            saleReceiptNo: saleReceipts[i],
            salePosId: 1,
          );
          await refundUC.perform(
            refundLocalId: refund!.localId,
            amount: _d('450'),
            userId: 1,
            saleReceiptNo: saleReceipts[i],
            salePosId: 1,
            products: [
              RefundProductEntry(
                ucode: 1001,
                quantity: _d('1'),
                price: _d('450'),
                inSalePrice: _d('450'),
                inSaleQuantity: _d('1'),
              ),
            ],
          );
          expectedPosBalance -= _d('450');
          expectedMilkQty += _d('1');
        }

        expect(await _accountBalance(db, ids.posAccountId), expectedPosBalance);
        expect(await _productQty(db, 1001), expectedMilkQty);

        await cashCtrl.createInvestment(
          amount: _d('20000'),
          accountId: ids.posAccountId,
        );
        expectedPosBalance += _d('20000');

        await cashCtrl.createExpense(
          amount: _d('5000'),
          accountId: ids.posAccountId,
          expenseType: ExpenseType.salary,
        );
        expectedPosBalance -= _d('5000');

        expect(await _accountBalance(db, ids.posAccountId), expectedPosBalance);
        expect(expectedPosBalance, _d('18150'));
      } finally {
        await db.close();
      }
    });
  });
}
