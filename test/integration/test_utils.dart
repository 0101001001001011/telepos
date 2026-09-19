// ignore_for_file: subtype_of_sealed_class
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:drift/native.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_quick_product_catalog.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/sale/local_sale_edit_terms.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/data/services/currency_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_round_option_use_case.dart';
import 'package:telepos/data/database/daos/product_price_dao.dart';
import 'package:telepos/data/database/daos/shift_dao.dart';
import 'package:telepos/data/database/daos/sale_dao.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/sale_product_dao.dart';
import 'package:telepos/data/database/daos/payment_dao.dart';
import 'package:telepos/data/database/daos/product_info_dao.dart';
import 'package:telepos/data/database/daos/terminal_dao.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart'
    as domain;
import 'package:telepos/domain/usecases/sale/deferred_sale_service.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/sale/receipt_line.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart'
    show RefundUseCase, RefundResult, RefundProductEntry;
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/core/constants/permission_keys.dart';
import '../helpers/cash_drawer.dart';

bool _appTalkerInitialized = false;

/// Настоящая база корзины — задача 8.
///
/// # Почему здесь появился настоящий drift рядом с моками
///
/// До задачи 8 `SaleNotifier` держал корзину в памяти, и подделки
/// `AppDatabase` хватало: контроллер к базе почти не обращался. Теперь
/// корзина живёт за контрактом `CartService`, и подделать его моком значит
/// проверить, что контроллер зовёт то, что мы велели ему звать, — а
/// проверять надо, что кассир видит правильный чек.
///
/// Поэтому под контрактом стоит **настоящая** `LocalCartService` над
/// настоящей базой в памяти, с теми же товарами, что у `testDomainProducts`.
/// Остальные подделки (платежи, смена, возвраты) не тронуты: они и
/// проверяют другое.
/// Ответ на «партия просрочена?» в пробах — пункт 11 ревизии 2026-09-19.
///
/// По умолчанию «нет ни у чего»: сквозные сценарии продажи про сроки не
/// спрашивают, и жёлтый снекбар посреди них был бы шумом. Проба, которой
/// просрочка нужна, кладёт сюда свои товары.
final expiryWarningStub = ExpiryWarningStub();

/// Подмена `ExpiryWarningReader` для проб: отвечает «просрочено» ровно тем
/// товарам, что названы в [expired], и запоминает, о чём спрашивали.
///
/// Запоминает нарочно: «спросили не про тот товар» и «не спросили вовсе» —
/// разные дефекты, и вопрос, ушедший про товар, который в чек не встал, был
/// настоящим дефектом до пункта 11 (вопрос шёл параллельно команде).
class ExpiryWarningStub implements ExpiryWarningReader {
  final Set<int> expired = <int>{};
  final List<int> asked = <int>[];

  void reset() {
    expired.clear();
    asked.clear();
  }

  @override
  Future<bool> isPickedBatchExpired(int productId) async {
    asked.add(productId);
    return expired.contains(productId);
  }
}

AppDatabase? _cartDb;

AppDatabase get cartDb => _cartDb!;

/// Подделка завершения продажи — единственное место, где видно, **на
/// какие счета** легли деньги.
///
/// Отдана наружу кругом правки 3 задачи 14: до него сквозные сценарии
/// оплаты утверждали только «получилось», а карточный и смешанный — ровно
/// те два пути, которые читают номер счёта из тела запроса. «Деньги легли
/// правильно» без этого оставалось словом.
MockSaleUseCase? _saleUseCase;

MockSaleUseCase get saleUseCaseSpy => _saleUseCase!;

/// Счета, на которые ушли платежи последнего завершения продажи.
List<int> lastPayeeAccountIds() {
  final captured = verify(
    () => saleUseCaseSpy.perform(
      receiptNo: any(named: 'receiptNo'),
      posId: any(named: 'posId'),
      amount: any(named: 'amount'),
      lines: any(named: 'lines'),
      payments: captureAny(named: 'payments'),
      change: any(named: 'change'),
      selectiveOfd: any(named: 'selectiveOfd'),
      customerBin: any(named: 'customerBin'),
      agentLocalId: any(named: 'agentLocalId'),
      agentServerId: any(named: 'agentServerId'),
      customFields: any(named: 'customFields'),
      withdrawal: any(named: 'withdrawal'),
    ),
  ).captured;
  final last = captured.last as List<PaymentEntry>;
  return last.map((p) => p.payeeAccountId).toList();
}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockProductPriceDao extends Mock implements ProductPriceDao {}

class MockShiftDao extends Mock implements ShiftDao {}

class MockSaleDao extends Mock implements SaleDao {}

class MockThisPosDao extends Mock implements ThisPosDao {}

class MockAccountDao extends Mock implements AccountDao {}

class MockSaleProductDao extends Mock implements SaleProductDao {}

class MockPaymentDao extends Mock implements PaymentDao {}

class MockProductInfoDao extends Mock implements ProductInfoDao {}

class MockTerminalDao extends Mock implements TerminalDao {}

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
  cartVersion: 0,
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
  registerFallbackValue(<ReceiptLine>[]);
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
  when(
    () => mockSaleDao.findInProgress(
      posId: any(named: 'posId'),
      terminalId: any(named: 'terminalId'),
    ),
  ).thenAnswer((_) async => null);

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
      // Схема v47 (сертификат и аванс в фискальном чеке): умолчания те же,
      // что задаёт таблица — продажа сертификата без чека, зачёт скидкой,
      // приём аванса с чеком.
      fiscalizeCertificateSale: false,
      offsetFiscalLayout: 0,
      fiscalizePrepaymentReceipt: true,
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

  // Задача 5: `sale_controller.dart` теперь сам вычисляет `terminals.self()`
  // (юзкейс больше не делает этого внутри себя — терминал стал доводом), и
  // это происходит на каждый `SaleController.build()`, а не только там, где
  // тест ждал такого обращения к базе. Без стаба `mockDb.terminalDao`
  // остался бы не-null геттером с `null`-реализацией из `noSuchMethod` —
  // несовпадение типов рушило бы `_initSale()` в каждом тесте, который
  // читает `saleControllerProvider`.
  final mockTerminalDao = MockTerminalDao();
  when(() => mockTerminalDao.self()).thenAnswer((_) async => null);

  final mockDb = MockAppDatabase();
  when(() => mockDb.productPriceDao).thenReturn(mockPriceDao);
  when(() => mockDb.shiftDao).thenReturn(mockShiftDao);
  when(() => mockDb.saleDao).thenReturn(mockSaleDao);
  when(() => mockDb.thisPosDao).thenReturn(mockThisPosDao);
  when(() => mockDb.accountDao).thenReturn(mockAccountDao);
  when(() => mockDb.saleProductDao).thenReturn(mockSaleProductDao);
  when(() => mockDb.paymentDao).thenReturn(mockPaymentDao);
  when(() => mockDb.productInfoDao).thenReturn(mockProductInfoDao);
  when(() => mockDb.terminalDao).thenReturn(mockTerminalDao);

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

  // Настоящая база корзины со своими товарами (см. докстринг `_cartDb`).
  final cart = AppDatabase.forTesting(NativeDatabase.memory());
  _cartDb = cart;
  _seedCartDb(cart);

  final cartLogger = getIt<Talker>();
  final realInitiation = SaleInitiationUseCaseImpl(
    db: cart,
    logger: cartLogger,
  );

  // Мок остаётся мокoм: `sale_controller_refusal_test` переопределяет его,
  // чтобы проверить путь отказа. Умолчание делегирует настоящему юзкейсу
  // над настоящей базой — иначе `CartService.start` получил бы чек,
  // которого в базе корзины нет.
  final mockSaleInitiation = MockSaleInitiationUseCase();
  when(
    () => mockSaleInitiation.initiate(
      terminalId: any(named: 'terminalId'),
      isWholesale: any(named: 'isWholesale'),
    ),
  ).thenAnswer((invocation) {
    return realInitiation.initiate(
      terminalId: invocation.namedArguments[const Symbol('terminalId')] as int,
      isWholesale:
          invocation.namedArguments[const Symbol('isWholesale')] as bool? ??
          false,
    );
  });
  getIt.registerLazySingleton<SaleInitiationUseCase>(() => mockSaleInitiation);

  final realDeferred = DeferredSaleServiceImpl(db: cart, logger: cartLogger);
  final localCart = LocalCartService(
    db: cart,
    logger: cartLogger,
    initiation: getIt<SaleInitiationUseCase>(),
    deferred: realDeferred,
    rounding: SaleRoundOptionUseCaseImpl(),
    findByBarcode: FindByBarcodeUseCaseImpl(db: cart, logger: cartLogger),
    searchProducts: SearchProductInfoUseCaseImpl(db: cart, logger: cartLogger),
  );
  getIt.registerLazySingleton<CartService>(() => localCart);
  getIt.registerLazySingleton<SaleRoundOptionUseCase>(
    () => SaleRoundOptionUseCaseImpl(),
  );
  getIt.registerLazySingleton<FindByBarcodeUseCase>(
    () => FindByBarcodeUseCaseImpl(db: cart, logger: cartLogger),
  );
  getIt.registerLazySingleton<SaleCheckoutService>(
    () =>
        LocalSaleCheckoutService(db: cart, cart: localCart, logger: cartLogger),
  );
  getIt.registerLazySingleton<QuickProductCatalog>(
    () => LocalQuickProductCatalog(db: cart),
  );
  // Условия правки строки — задача 44; тот же граф, что на кассе.
  getIt.registerLazySingleton<SaleEditTermsReader>(
    () => LocalSaleEditTerms(
      db: cart,
      discountPolicy: LocalDiscountPolicy(cart),
      currency: CurrencyServiceImpl(db: cart, logger: cartLogger),
      logger: cartLogger,
    ),
  );
  // «Партия просрочена?» — пункт 11 ревизии 2026-09-19. Тот же граф, что на
  // кассе: контроллер больше не спрашивает складские юзкейсы у контейнера, а
  // ходит одним договором, и подменить его в пробе — значит подменить один
  // ответ, а не два юзкейса.
  getIt.registerLazySingleton<ExpiryWarningReader>(() => expiryWarningStub);
  // Рабочее место экрана продажи: контроллер спрашивает его через домен
  // (`TerminalIdentity`), а не у базы.
  getIt.registerLazySingleton<TerminalIdentity>(() => _FakeTerminalIdentity());

  final mockSaleUseCase = MockSaleUseCase();
  when(
    () => mockSaleUseCase.perform(
      receiptNo: any(named: 'receiptNo'),
      posId: any(named: 'posId'),
      amount: any(named: 'amount'),
      lines: any(named: 'lines'),
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
  _saleUseCase = mockSaleUseCase;
  getIt.registerLazySingleton<SaleUseCase>(() => mockSaleUseCase);

  // Оплата как контракт (задача 14). Настоящая кассовая реализация над
  // настоящей базой корзины: подделка доказывала бы, что контроллер зовёт
  // то, что ему велели звать, а сквозной сценарий спрашивает другое —
  // легли ли деньги. `SaleUseCase` под ней остаётся подделкой, как и был:
  // фискализация и склад — не предмет этих сценариев.
  getIt.registerLazySingleton<PaymentService>(
    () => LocalPaymentService(
      db: cart,
      checkout: getIt<SaleCheckoutService>(),
      sale: mockSaleUseCase,
      logger: cartLogger,
      // Порт обязателен (задача 3). Общая оснастка проб экранов: узла
      // фискализации в ней нет, и теперь это написано, а не подразумевается
      // пропуском довода.
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    ),
  );

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

  // Настоящий сервис отложенных над базой корзины: подделка «ничего не
  // делаю» оставляла бы отложенный чек в работе, и экран после
  // откладывания продолжал бы тот же чек.
  getIt.registerLazySingleton<DeferredSaleService>(() => realDeferred);

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
      drawerAmount: Decimal.zero,
    ),
  );
  getIt.registerLazySingleton<RefundUseCase>(() => mockRefundUseCase);

  // Возврат за контрактом (задача 20): экран больше не зовёт юзкейсы сам, он
  // зовёт `RefundService`. Реализация здесь **настоящая** и над настоящей
  // базой корзины — с моком проверка «выделение доехало до кассы» доказывала
  // бы только то, что мы велели моку ответить.
  //
  // `RefundUseCaseImpl` достаёт `RefundProductService` из контейнера сам
  // (`refund_use_case_impl.dart`) — это форма продукта, а не выбор теста.
  getIt.registerLazySingleton<RefundProductService>(
    () => RefundProductServiceImpl(db: cart, logger: cartLogger),
  );
  getIt.registerLazySingleton<RefundService>(
    () => LocalRefundService(
      db: cart,
      logger: cartLogger,
      initiation: RefundInitiationUseCaseImpl(db: cart, logger: cartLogger),
      refunds: RefundUseCaseImpl(
        db: cart,
        logger: cartLogger,
        // Тем же доводом, что у `LocalPaymentService` выше: узла
        // фискализации в общей оснастке проб экранов нет, и это написано, а
        // не подразумевается пропуском довода.
        fiscal: const RefusingFiscalService(),
      ),
      canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: cart, logger: cartLogger),
      drawer: () async => true,
    ),
  );

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
  expiryWarningStub.reset();
  GetIt.instance.reset();
  _saleUseCase = null;
  final cart = _cartDb;
  _cartDb = null;
  if (cart != null) unawaited(cart.close());
}

/// Товары базы корзины — те же, что у [testDomainProducts]: тест ищет
/// «Молоко» и ждёт цену 450.
void _seedCartDb(AppDatabase cart) {
  // Счета в базе корзины — **обычный путь оплаты, а не аварийный**.
  //
  // До круга правки 2 счетов здесь не было ни одного, и обе ветки оплаты
  // падали в путь «мастер настройки прошёл криво — заводим счёт, а не
  // останавливаем торговлю» (`LocalPaymentService._posAccountId`/
  // `_bankAccountId`). То есть все сквозные сценарии оплаты годами мерили
  // аварийный путь: проверить, что деньги легли на **правильный** счёт,
  // не мог ни один — правильного счёта в базе не существовало.
  //
  // Круг правки 1 завёл банковский (без него проверка счёта отвергала
  // названный сценарием номер 1) — то есть починил половину. Здесь вторая:
  // кассовый счёт и `ThisPos.accountId`, который на него указывает.
  cart
      .into(cart.accounts)
      .insert(
        AccountsCompanion.insert(
          id: const Value(1),
          type: AccountType.customBank,
          name: const Value('Банк'),
          value: Value(Decimal.zero),
          visibleToPos: const Value(true),
        ),
      );
  cart
      .into(cart.accounts)
      .insert(
        AccountsCompanion.insert(
          id: const Value(2),
          type: AccountType.pos,
          name: const Value('Касса'),
          // 1050 — деньги чека №12345, который сеет `_seedCompletedReceipt`
          // для проб возврата: возвращать их кассе иначе не из чего.
          value: Value(Decimal.parse('1050')),
          visibleToPos: const Value(true),
        ),
      );

  // Счёт кассы — **тот же самый**, что заведён выше под id 2, и это решено
  // слиянием. Ветвь возвратов завела рядом второй (id 77, type 0, 1050) и
  // указала кассу на него; конфликта это не дало — строки разные, — а
  // сквозные пробы продажи покраснели сразу двумя утверждениями: «оплата
  // ушла аварийным путём и завела себе счёт» (счетов стало три) и
  // «наличные — на счёт кассы» (id 77 вместо 2). Двух счетов кассы не
  // бывает; остаётся один, а деньги чека, который сеет
  // `_seedCompletedReceipt` для возврата, кладутся на него.
  cart
      .into(cart.thisPosEntries)
      .insert(
        const ThisPosEntriesCompanion(
          id: Value(1),
          accountId: Value(2),
          // Задача 12: тумблер кассы «продажа со скидкой» читает
          // теперь сама касса, а не только экран. Сквозная проба
          // «sale with discount» без этой строки мерила бы отказ
          // политики, а не скидку.
          sellInDiscount: Value(true),
        ),
      );
  cart
      .into(cart.users)
      .insert(const UsersCompanion(id: Value(1), name: Value('Test User')));
  cart
      .into(cart.shifts)
      .insert(
        ShiftsCompanion(
          userId: Value(1),
          openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          isOpened: Value(true),
          isSynced: Value(false),
        ),
      );
  for (final p in testDomainProducts) {
    cart
        .into(cart.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(p.ucode),
            barcode: p.barcode,
            name: p.name,
            type: p.type,
            measure: p.measure,
            quantity: Value(Decimal.fromInt(100)),
          ),
        );
    cart
        .into(cart.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: Value(p.ucode),
            barcode: p.barcode,
            sellingPrice: Value(testProductPrices[p.ucode] ?? Decimal.zero),
          ),
        );
  }

  _seedCompletedReceipt(cart);
}

/// Совершённый чек №12345 — тот, который ищет `refund_cycle_test`.
///
/// Заведён задачей 20: до неё возврат читал **мок** базы, и чек существовал
/// в виде заранее подготовленных ответов `when(...)`. Теперь возврат идёт
/// через `RefundService` над настоящей базой корзины, и чек обязан быть
/// настоящим — со строками, оплатой и снятым остатком, иначе проверка
/// «товар вернулся на остаток» сравнивала бы возврат с остатком, которого
/// продажа не касалась.
///
/// Две строки, разные товары, разные количества: `1001` два раза по 450 и
/// `1002` один раз по 150. Итого 1050.
void _seedCompletedReceipt(AppDatabase cart) {
  const receiptNo = 12345;
  const posId = 1;
  const lines = [
    (ucode: 1001, quantity: 2, price: '450'),
    (ucode: 1002, quantity: 1, price: '150'),
  ];

  var amount = Decimal.zero;
  for (final line in lines) {
    amount += Decimal.parse(line.price) * Decimal.fromInt(line.quantity);
  }

  cart
      .into(cart.sales)
      .insert(
        SalesCompanion.insert(
          receiptNo: receiptNo,
          posId: posId,
          userId: 1,
          amount: amount,
          time: 1700000000,
          state: const Value(1),
        ),
      );

  for (final line in lines) {
    cart
        .into(cart.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: const Value(receiptNo),
            posId: const Value(posId),
            ucode: line.ucode,
            quantity: Decimal.fromInt(line.quantity),
            price: Decimal.parse(line.price),
            priceBefore: Decimal.parse(line.price),
          ),
        );
  }

  cart
      .into(cart.payments)
      .insert(
        PaymentsCompanion.insert(
          userId: 1,
          payeeAccountId: 77,
          amount: amount,
          time: 1700000000,
          receiptNo: const Value(receiptNo),
          posId: const Value(posId),
          state: const Value(1),
        ),
      );
}

class _FakeTerminalIdentity implements TerminalIdentity {
  int? _id = 1;

  @override
  Future<int?> currentId() async => _id;

  @override
  Future<void> remember(int terminalId) async => _id = terminalId;

  @override
  Future<void> forget() async => _id = null;
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
      // Задача 12: с этой работы `SaleNotifier` строит `DiscountAuthority`
      // из `AppState` вошедшего, и касса отказывает по праву тому,
      // у кого его нет. Пустой набор прав здесь означал бы «кассир
      // без единого op.*» — честный случай, но не тот, который мерят
      // сквозные пробы продажи: им нужен старший, которому всё
      // разрешено. Роль — владелец (0): своей строки в `DiscountLimits`
      // у него нет, значит действует умолчание миграции — сто процентов,
      // то есть «как вчера».
      userRole: 0,
      // `op.deferSale` — задача 28: корзина проверяет и его на кассе.
      permissions: {
        PermissionKeys.opSellDiscount,
        PermissionKeys.opEditPrice,
        PermissionKeys.opDeferSale,
      },
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
