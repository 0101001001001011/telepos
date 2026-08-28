// ignore_for_file: subtype_of_sealed_class
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/product_price_dao.dart';
import 'package:telepos/data/database/daos/shift_dao.dart';
import 'package:telepos/data/database/daos/sale_dao.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/sale_product_dao.dart';
import 'package:telepos/data/database/daos/payment_dao.dart';
import 'package:telepos/data/database/daos/product_info_dao.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart'
    as domain;
import 'package:telepos/domain/usecases/sale/deferred_sale_service.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart'
    show RefundUseCase, RefundResult, RefundProductEntry;
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;

bool _appTalkerInitialized = false;

class MockAppDatabase extends Mock implements AppDatabase {}

class MockProductPriceDao extends Mock implements ProductPriceDao {}

class MockShiftDao extends Mock implements ShiftDao {}

class MockSaleDao extends Mock implements SaleDao {}

class MockThisPosDao extends Mock implements ThisPosDao {}

class MockAccountDao extends Mock implements AccountDao {}

class MockSaleProductDao extends Mock implements SaleProductDao {}

class MockPaymentDao extends Mock implements PaymentDao {}

class MockProductInfoDao extends Mock implements ProductInfoDao {}

class MockProductPrice extends Mock implements ProductPrice {}

class MockSaleProduct extends Mock implements SaleProduct {}

class MockProductInfo extends Mock implements ProductInfo {}

class MockSearchProductInfoUseCase extends Mock
    implements domain.SearchProductInfoUseCase {}

class MockSaleInitiationUseCase extends Mock implements SaleInitiationUseCase {}

class MockSaleUseCase extends Mock implements SaleUseCase {}

class MockDeferredSaleService extends Mock implements DeferredSaleService {}

class MockRefundInitiationUseCase extends Mock
    implements RefundInitiationUseCase {}

class MockRefundUseCase extends Mock implements RefundUseCase {}

class MockShiftService extends Mock implements ShiftService {}

class MockAssembleShiftReceiptUseCase extends Mock
    implements AssembleShiftReceiptUseCase {}

class MockReceiptPrintService extends Mock implements ReceiptPrintService {}

class _ShiftMockState {
  Shift? currentShift;
  int nextShiftId = 1;

  void openShift({
    required int userId,
    required int openTime,
    Decimal? openingCash,
  }) {
    currentShift = Shift(
      id: nextShiftId++,
      userId: userId,
      openTime: openTime,
      closeTime: null,
      isOpened: true,
      isSynced: false,
      cashInPosOnShiftClose: null,
      openingCash: openingCash,
    );
  }

  void closeShift({required int closeTime, Decimal? cashInPos}) {
    if (currentShift != null) {
      currentShift = Shift(
        id: currentShift!.id,
        userId: currentShift!.userId,
        openTime: currentShift!.openTime,
        closeTime: closeTime,
        isOpened: false,
        isSynced: false,
        cashInPosOnShiftClose: cashInPos,
      );
    }
  }

  void reset() {
    currentShift = null;
    nextShiftId = 1;
  }
}

final _shiftMockState = _ShiftMockState();

final testDomainProducts = [
  const domain.ProductSearchResult(
    ucode: 1001,
    barcode: 4607001234567,
    name: 'Молоко 1л',
    type: 0,
    measure: 0,
    categoryId: 1,
    isDeleted: false,
  ),
  const domain.ProductSearchResult(
    ucode: 1002,
    barcode: 4607001234568,
    name: 'Хлеб белый',
    type: 0,
    measure: 0,
    categoryId: 2,
    isDeleted: false,
  ),
  const domain.ProductSearchResult(
    ucode: 1003,
    barcode: 4607001234569,
    name: 'Сахар 1кг',
    type: 0,
    measure: 1,
    categoryId: 3,
    isDeleted: false,
  ),
];

final testProductPrices = <int, Decimal>{
  1001: Decimal.parse('450'),
  1002: Decimal.parse('150'),
  1003: Decimal.parse('280'),
};

Sale get testSale => Sale(
  receiptNo: 12345,
  posId: 1,
  saleId: 1,
  userId: 1,
  time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  amount: Decimal.parse('600'),
  isOfd: false,
  isWholesale: false,
  state: 4,
  weightProductRoundType: 0,
  discountsRoundType: 0,
);

List<SaleProduct> get testSaleProducts => [
  SaleProduct(
    id: 1,
    receiptNo: 12345,
    posId: 1,
    ucode: 1001,
    quantity: Decimal.one,
    price: Decimal.parse('450'),
    priceBefore: Decimal.parse('450'),
  ),
  SaleProduct(
    id: 2,
    receiptNo: 12345,
    posId: 1,
    ucode: 1002,
    quantity: Decimal.one,
    price: Decimal.parse('150'),
    priceBefore: Decimal.parse('150'),
  ),
];

List<ProductInfo> get testProductInfoList => [
  const ProductInfo(
    ucode: 1001,
    barcode: 4607001234567,
    name: 'Молоко 1л',
    type: 0,
    measure: 0,
    categoryId: 1,
    isDeleted: false,
    isMarkable: false,
  ),
  const ProductInfo(
    ucode: 1002,
    barcode: 4607001234568,
    name: 'Хлеб белый',
    type: 0,
    measure: 0,
    categoryId: 2,
    isDeleted: false,
    isMarkable: false,
  ),
  const ProductInfo(
    ucode: 1003,
    barcode: 4607001234569,
    name: 'Сахар 1кг',
    type: 0,
    measure: 1,
    categoryId: 3,
    isDeleted: false,
    isMarkable: false,
  ),
];

ProductPrice createMockProductPrice(int ucode, Decimal price) {
  final mock = MockProductPrice();
  when(() => mock.ucode).thenReturn(ucode);
  when(() => mock.barcode).thenReturn(4607001234567 + ucode - 1001);
  when(() => mock.sellingPrice).thenReturn(price);
  when(() => mock.wholesalePrice).thenReturn(price);
  when(() => mock.editTime).thenReturn(null);
  when(() => mock.serverEditTime).thenReturn(null);
  return mock;
}

void _registerFallbacks() {
  registerFallbackValue(Decimal.zero);
  registerFallbackValue(<RefundProductEntry>[]);
  registerFallbackValue(<PaymentEntry>[]);
}

bool _fallbacksRegistered = false;

void setupTestDependencies() {
  if (!_fallbacksRegistered) {
    _registerFallbacks();
    _fallbacksRegistered = true;
  }

  if (!_appTalkerInitialized) {
    app_log.installLogger(Talker());
    _appTalkerInitialized = true;
  }

  final getIt = GetIt.instance;

  _shiftMockState.reset();

  if (getIt.isRegistered<Talker>()) {
    getIt.reset();
  }

  getIt.registerLazySingleton<Talker>(() => Talker());

  final mockPriceDao = MockProductPriceDao();
  when(() => mockPriceDao.findByUcode(any())).thenAnswer((invocation) async {
    final ucode = invocation.positionalArguments[0] as int;
    final price = testProductPrices[ucode];
    if (price == null) return null;
    return createMockProductPrice(ucode, price);
  });

  final mockShiftDao = MockShiftDao();
  when(() => mockShiftDao.findOpenedShift()).thenAnswer((_) async {
    final shift = _shiftMockState.currentShift;
    return (shift != null && shift.isOpened) ? shift : null;
  });
  when(() => mockShiftDao.findCurrentUser()).thenAnswer((_) async => null);

  final mockSaleDao = MockSaleDao();
  when(() => mockSaleDao.countWithState(any())).thenAnswer((_) async => 0);
  when(() => mockSaleDao.findLastReceiptNo()).thenAnswer((_) async => 100);
  when(() => mockSaleDao.findInProgress()).thenAnswer((_) async => null);

  final mockThisPosDao = MockThisPosDao();
  when(() => mockThisPosDao.get()).thenAnswer((_) async {
    return const ThisPosEntry(
      rId: true,
      accountId: 1,
      discountsRoundType: 0,
      weightProductRoundType: 0,
      limitToKztStores: false,
      printerTableView: false,
      printVatOnReceipt: true,
      isVatPayer: true,
      editProduct: true,
      editPrice: true,
      sellUniversal: true,
      minimizeCashbox: true,
      sellInDebt: true,
      sellInDiscount: true,
      cashInOut: true,
      sendToOfd: false,
      cancelPayment: true,
      deferSale: true,
      admitElectPayment: true,
      isSyncImmediately: false,
      isShowSaleHistory: true,
      isNewReportCheck: false,
      isKassaWholesaleEnabled: false,
      isSearchInGlobalProductsEnabled: true,
      priceCheckEnabled: true,
      allowBigAmount: true,
      isKassaPriceDecreasingBlocked: false,
      operatingMode: 0,
      serviceChargeEnabled: false,
      blockOversell: false,
      // Схема v32 (задача «вход браузерного терминала») добавила эти два
      // столбца к `this_pos_entries` — умолчания те же, что задаёт сама
      // таблица (`ThisPosTables.walkUpEnabled`/`sessionIdleMinutes`):
      // walk-up выключен, срок сеанса — тридцать минут.
      walkUpEnabled: false,
      sessionIdleMinutes: 30,
    );
  });

  final mockAccountDao = MockAccountDao();
  when(() => mockAccountDao.findById(any())).thenAnswer((_) async {
    return Account(
      id: 1,
      type: 0,
      name: 'Test Cash Account',
      value: Decimal.parse('10000'),
    );
  });
  when(() => mockAccountDao.findByType(any())).thenAnswer((invocation) async {
    final type = invocation.positionalArguments[0] as int;
    return [
      Account(
        id: type == 0 ? 1 : 2,
        type: type,
        name: type == 0 ? 'POS (cash)' : 'Bank (card)',
        value: Decimal.zero,
      ),
    ];
  });
  when(() => mockAccountDao.findByTypeAndVisibility(any(), any())).thenAnswer((
    invocation,
  ) async {
    final type = invocation.positionalArguments[0] as int;
    return [
      Account(
        id: type == 0 ? 1 : 2,
        type: type,
        name: type == 0 ? 'POS (cash)' : 'Bank (card)',
        value: Decimal.zero,
      ),
    ];
  });

  final mockSaleProductDao = MockSaleProductDao();
  when(() => mockSaleProductDao.findBySale(any(), any())).thenAnswer((
    invocation,
  ) async {
    final receiptNo = invocation.positionalArguments[0] as int;
    if (receiptNo == 12345) {
      return testSaleProducts;
    }
    return [];
  });
  when(
    () => mockSaleProductDao.deleteBySale(any(), any()),
  ).thenAnswer((_) async => 0);

  final mockPaymentDao = MockPaymentDao();
  when(
    () => mockPaymentDao.deleteBySale(any(), any()),
  ).thenAnswer((_) async => 0);

  final mockProductInfoDao = MockProductInfoDao();
  when(() => mockProductInfoDao.findByUcode(any())).thenAnswer((
    invocation,
  ) async {
    final ucode = invocation.positionalArguments[0] as int;
    return testProductInfoList.where((p) => p.ucode == ucode).firstOrNull;
  });

  final mockDb = MockAppDatabase();
  when(() => mockDb.productPriceDao).thenReturn(mockPriceDao);
  when(() => mockDb.shiftDao).thenReturn(mockShiftDao);
  when(() => mockDb.saleDao).thenReturn(mockSaleDao);
  when(() => mockDb.thisPosDao).thenReturn(mockThisPosDao);
  when(() => mockDb.accountDao).thenReturn(mockAccountDao);
  when(() => mockDb.saleProductDao).thenReturn(mockSaleProductDao);
  when(() => mockDb.paymentDao).thenReturn(mockPaymentDao);
  when(() => mockDb.productInfoDao).thenReturn(mockProductInfoDao);

  final mockSaleProductsTable = _MockSaleProductsTable();
  when(() => mockDb.saleProducts).thenReturn(mockSaleProductsTable);

  var _saleProductRowId = 0;
  when(
    () => mockDb.into<$SaleProductsTable, SaleProduct>(mockSaleProductsTable),
  ).thenAnswer((_) {
    return _MockInsertStatement<$SaleProductsTable, SaleProduct>(
      onInsert: (_) => Future.value(++_saleProductRowId),
    );
  });

  when(() => mockDb.batch(any())).thenAnswer((invocation) async {
    return;
  });

  final mockSalesTable = _MockSalesTable();
  when(() => mockDb.sales).thenReturn(mockSalesTable);

  final mockSelectStatement = _FakeSelectStatement<$SalesTable, Sale>([
    testSale,
  ]);
  when(
    () => mockDb.select<$SalesTable, Sale>(mockSalesTable),
  ).thenReturn(mockSelectStatement);

  when(() => mockDb.update<$SalesTable, Sale>(mockSalesTable)).thenAnswer((_) {
    return _MockUpdateStatement<$SalesTable, Sale>(
      onWrite: (_) => Future.value(1),
    );
  });

  final mockShiftsTable = _MockShiftsTable();
  when(() => mockDb.shifts).thenReturn(mockShiftsTable);

  when(() => mockDb.into<$ShiftsTable, Shift>(mockShiftsTable)).thenAnswer((_) {
    return _MockInsertStatement<$ShiftsTable, Shift>(
      onInsert: (companion) {
        if (companion is ShiftsCompanion) {
          _shiftMockState.openShift(
            userId: companion.userId.value,
            openTime: companion.openTime.value,
          );
        }
        return Future.value(1);
      },
    );
  });

  when(() => mockDb.update<$ShiftsTable, Shift>(mockShiftsTable)).thenAnswer((
    _,
  ) {
    return _MockUpdateStatement<$ShiftsTable, Shift>(
      onWrite: (companion) {
        if (companion is ShiftsCompanion &&
            companion.isOpened.present &&
            !companion.isOpened.value) {
          _shiftMockState.closeShift(
            closeTime: companion.closeTime.value ?? 0,
            cashInPos: companion.cashInPosOnShiftClose.value,
          );
        }
        return Future.value(1);
      },
    );
  });

  when(
    () => mockDb.customSelect(
      any(),
      variables: any(named: 'variables'),
      readsFrom: any(named: 'readsFrom'),
    ),
  ).thenAnswer((_) => _MockSelectable());

  when(() => mockDb.cashOperations).thenReturn(_MockCashOperationsTable());

  when(() => mockDb.payments).thenReturn(_MockPaymentsTable());
  when(() => mockDb.refunds).thenReturn(_MockRefundsTable());
  when(() => mockDb.accounts).thenReturn(_MockAccountsTable());

  getIt.registerLazySingleton<AppDatabase>(() => mockDb);

  final mockSaleInitiation = MockSaleInitiationUseCase();
  when(
    () => mockSaleInitiation.initiate(
      isWholesale: any(named: 'isWholesale'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer(
    (_) async => Sale(
      receiptNo: 101,
      posId: 1,
      userId: 1,
      amount: Decimal.zero,
      time: 0,
      isOfd: false,
      isWholesale: false,
      state: 0,
      weightProductRoundType: 0,
      discountsRoundType: 0,
    ),
  );
  getIt.registerLazySingleton<SaleInitiationUseCase>(() => mockSaleInitiation);

  final mockSaleUseCase = MockSaleUseCase();
  when(
    () => mockSaleUseCase.perform(
      receiptNo: any(named: 'receiptNo'),
      posId: any(named: 'posId'),
      amount: any(named: 'amount'),
      payments: any(named: 'payments'),
      change: any(named: 'change'),
      selectiveOfd: any(named: 'selectiveOfd'),
      customerBin: any(named: 'customerBin'),
      agentLocalId: any(named: 'agentLocalId'),
      agentServerId: any(named: 'agentServerId'),
      customFields: any(named: 'customFields'),
      withdrawal: any(named: 'withdrawal'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => mockSaleUseCase.reverseSaleStock(
      receiptNo: any(named: 'receiptNo'),
      posId: any(named: 'posId'),
    ),
  ).thenAnswer((_) async {});
  getIt.registerLazySingleton<SaleUseCase>(() => mockSaleUseCase);

  final mockSearchUseCase = MockSearchProductInfoUseCase();
  when(
    () => mockSearchUseCase.search(
      query: any(named: 'query'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((invocation) async {
    final raw = invocation.namedArguments[const Symbol('query')] as String;
    final query = raw.replaceAll('%', '');
    return testDomainProducts
        .where(
          (p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.barcode.toString().contains(query),
        )
        .toList();
  });
  getIt.registerLazySingleton<domain.SearchProductInfoUseCase>(
    () => mockSearchUseCase,
  );

  final mockDeferredService = MockDeferredSaleService();
  when(
    () => mockDeferredService.getDeferredSales(),
  ).thenAnswer((_) async => []);
  when(
    () => mockDeferredService.deferSale(receiptNo: any(named: 'receiptNo')),
  ).thenAnswer((_) async {});
  getIt.registerLazySingleton<DeferredSaleService>(() => mockDeferredService);

  final mockRefundInitiation = MockRefundInitiationUseCase();
  when(
    () => mockRefundInitiation.getInProgress(),
  ).thenAnswer((_) async => null);
  when(
    () => mockRefundInitiation.initiate(
      saleReceiptNo: any(named: 'saleReceiptNo'),
      salePosId: any(named: 'salePosId'),
      saleId: any(named: 'saleId'),
      saleWeightRoundType: any(named: 'saleWeightRoundType'),
      saleDiscountsRoundType: any(named: 'saleDiscountsRoundType'),
      customerLocalId: any(named: 'customerLocalId'),
      customerServerId: any(named: 'customerServerId'),
    ),
  ).thenAnswer(
    (_) async => Refund(
      localId: 1,
      userId: 1,
      amount: Decimal.zero,
      time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      isOfd: false,
    ),
  );
  getIt.registerLazySingleton<RefundInitiationUseCase>(
    () => mockRefundInitiation,
  );

  final mockRefundUseCase = MockRefundUseCase();
  when(
    () => mockRefundUseCase.perform(
      refundLocalId: any(named: 'refundLocalId'),
      amount: any(named: 'amount'),
      cashbackAmount: any(named: 'cashbackAmount'),
      userId: any(named: 'userId'),
      saleReceiptNo: any(named: 'saleReceiptNo'),
      salePosId: any(named: 'salePosId'),
      customerLocalId: any(named: 'customerLocalId'),
      customerServerId: any(named: 'customerServerId'),
      products: any(named: 'products'),
    ),
  ).thenAnswer(
    (_) async => RefundResult(
      refundLocalId: 1,
      amount: Decimal.parse('600'),
      productCount: 2,
      paymentCount: 1,
    ),
  );
  getIt.registerLazySingleton<RefundUseCase>(() => mockRefundUseCase);

  final mockShiftService = MockShiftService();
  when(
    () => mockShiftService.onOpenShift(
      any(),
      openingCash: any(named: 'openingCash'),
    ),
  ).thenAnswer((invocation) async {
    final userId = invocation.positionalArguments[0] as int;
    final openingCash =
        invocation.namedArguments[const Symbol('openingCash')] as Decimal?;
    final openTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _shiftMockState.openShift(
      userId: userId,
      openTime: openTime,
      openingCash: openingCash,
    );
  });
  when(() => mockShiftService.onCloseShift(any())).thenAnswer((
    invocation,
  ) async {
    final closeTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cashInPos = invocation.positionalArguments[0] as Decimal;
    _shiftMockState.closeShift(closeTime: closeTime, cashInPos: cashInPos);
  });
  when(() => mockShiftService.getOpenedShift()).thenAnswer((_) async {
    return _shiftMockState.currentShift;
  });
  when(() => mockShiftService.isShiftOverAge()).thenAnswer((_) async => false);
  getIt.registerLazySingleton<ShiftService>(() => mockShiftService);

  final mockAssembleReceipt = MockAssembleShiftReceiptUseCase();
  when(
    () => mockAssembleReceipt.assemble(any(), any()),
  ).thenAnswer((_) async => null);
  getIt.registerLazySingleton<AssembleShiftReceiptUseCase>(
    () => mockAssembleReceipt,
  );

  final mockPrintService = MockReceiptPrintService();
  when(
    () => mockPrintService.isPrinterAvailable(),
  ).thenAnswer((_) async => false);
  getIt.registerLazySingleton<ReceiptPrintService>(() => mockPrintService);
}

void tearDownTestDependencies() {
  _shiftMockState.reset();
  GetIt.instance.reset();
}

ProviderContainer createTestContainer() {
  setupTestDependencies();

  return ProviderContainer(
    overrides: [appStateProvider.overrideWith(() => _TestAppStateNotifier())],
  );
}

class _TestAppStateNotifier extends AppStateNotifier {
  @override
  AppState build() {
    return const AppState(
      userId: 1,
      userName: 'Test User',
      currentTime: '12:00',
    );
  }
}

class _MockInsertStatement<T extends Table, D> extends Mock
    implements InsertStatement<T, D> {
  _MockInsertStatement({required this.onInsert});

  final Future<int> Function(Insertable<D> entity) onInsert;

  @override
  Future<int> insert(
    Insertable<D> entity, {
    InsertMode? mode,
    UpsertClause<T, D>? onConflict,
  }) {
    return onInsert(entity);
  }
}

class _MockUpdateStatement<T extends Table, D> extends Mock
    implements UpdateStatement<T, D> {
  _MockUpdateStatement({required this.onWrite});

  final Future<int> Function(Insertable<D> entity) onWrite;

  @override
  UpdateStatement<T, D> where(Expression<bool> Function(T tbl) filter) {
    return this;
  }

  @override
  Future<int> write(Insertable<D> entity, {bool dontExecute = false}) {
    return onWrite(entity);
  }
}

class _MockSelectable extends Mock implements Selectable<QueryRow> {
  @override
  Future<List<QueryRow>> get() async => [];

  @override
  Future<QueryRow> getSingle() async => _ZeroQueryRow();

  @override
  Future<QueryRow?> getSingleOrNull() async => _ZeroQueryRow();
}

class _ZeroQueryRow extends Fake implements QueryRow {
  @override
  Map<String, dynamic> get data => const {};

  @override
  T read<T>(String key) {
    if (T == int) return 0 as T;
    if (T == double) return 0.0 as T;
    if (T == String) return '' as T;
    if (T == bool) return false as T;
    return 0 as T;
  }

  @override
  T? readNullable<T extends Object>(String key) => null;
}

class _MockCashOperationsTable extends Mock implements $CashOperationsTable {}

class _MockPaymentsTable extends Mock implements $PaymentsTable {}

class _MockRefundsTable extends Mock implements $RefundsTable {}

class _MockAccountsTable extends Mock implements $AccountsTable {}

class _MockShiftsTable extends Mock implements $ShiftsTable {}

class _MockSalesTable extends Mock implements $SalesTable {}

class _MockSaleProductsTable extends Mock implements $SaleProductsTable {}

class _FakeSelectStatement<T extends HasResultSet, D> extends Fake
    implements SimpleSelectStatement<T, D> {
  _FakeSelectStatement(this._results);

  final List<D> _results;

  @override
  SimpleSelectStatement<T, D> where(Expression<bool> Function(T tbl) filter) {
    return this;
  }

  @override
  Future<List<D>> get() async => _results;

  @override
  Future<D?> getSingleOrNull() async =>
      _results.isEmpty ? null : _results.first;

  @override
  Future<D> getSingle() async => _results.first;
}
