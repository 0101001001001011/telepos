import 'package:decimal/decimal.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/controllers/supply/supply_controller.dart'
    hide ProductSearchResult;
import 'package:telepos/presentation/controllers/writeoff/writeoff_controller.dart';
import 'package:telepos/presentation/controllers/inventory/inventory_controller.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';

class TestSaleStates {
  TestSaleStates._();

  static const empty = SaleState();

  static final withItems = SaleState(
    items: [
      SaleItem(
        id: 'item_1',
        productId: 1,
        name: 'Молоко 1л',
        price: Decimal.parse('500'),
        quantity: Decimal.fromInt(2),
        barcode: '4607025392408',
      ),
      SaleItem(
        id: 'item_2',
        productId: 2,
        name: 'Хлеб белый',
        price: Decimal.parse('150'),
        quantity: Decimal.one,
        barcode: '4607036278901',
      ),
      SaleItem(
        id: 'item_3',
        productId: 3,
        name: 'Яблоки',
        price: Decimal.parse('800'),
        quantity: Decimal.parse('1.5'),
        barcode: '2761234000003',
      ),
    ],
    selectedItemId: 'item_1',
  );

  static final manyItems = SaleState(
    items: List.generate(
      100,
      (i) => SaleItem(
        id: 'item_$i',
        productId: i,
        name: 'Товар $i',
        price: Decimal.parse('${100 + i * 10}'),
        quantity: Decimal.one,
      ),
    ),
  );

  static final withDiscount = SaleState(
    items: [
      SaleItem(
        id: 'item_1',
        productId: 1,
        name: 'Молоко 1л',
        price: Decimal.parse('500'),
        quantity: Decimal.fromInt(2),
        discount: Decimal.parse('100'),
        discountPercent: Decimal.fromInt(10),
      ),
    ],
    selectedItemId: 'item_1',
  );

  static const searching = SaleState(searchQuery: 'молоко', isSearching: true);

  static final withSearchResults = SaleState(
    searchQuery: 'молоко',
    searchResults: [
      ProductSearchResult(
        id: 1,
        name: 'Молоко 1л 2.5%',
        price: Decimal.parse('500'),
        barcode: '4607025392408',
      ),
      ProductSearchResult(
        id: 4,
        name: 'Молоко 1л 3.2%',
        price: Decimal.parse('550'),
        barcode: '4607025392409',
      ),
    ],
  );

  static final deferred = SaleState(
    items: [
      SaleItem(
        id: 'item_1',
        productId: 1,
        name: 'Молоко 1л',
        price: Decimal.parse('500'),
        quantity: Decimal.one,
      ),
    ],
    isDeferred: true,
    deferredSaleId: '42',
  );

  static final withAgent = SaleState(
    items: [
      SaleItem(
        id: 'item_1',
        productId: 1,
        name: 'Молоко 1л',
        price: Decimal.parse('500'),
        quantity: Decimal.one,
      ),
    ],
    agentId: 1,
    agentName: 'Покупатель Тест',
  );

  static const withError = SaleState(error: 'Ошибка поиска: timeout');
}

class TestPaymentStates {
  TestPaymentStates._();

  static final cashWaiting = PaymentState(
    totalAmount: Decimal.parse('1150'),
    paymentType: PaymentType.cash,
  );

  static final cashComplete = PaymentState(
    totalAmount: Decimal.parse('1150'),
    paymentType: PaymentType.cash,
    cashReceived: Decimal.parse('2000'),
  );

  static final cardPayment = PaymentState(
    totalAmount: Decimal.parse('1150'),
    paymentType: PaymentType.card,
  );

  static final mixedPayment = PaymentState(
    totalAmount: Decimal.parse('1150'),
    paymentType: PaymentType.mixed,
    cashReceived: Decimal.parse('500'),
    cardAmount: Decimal.parse('650'),
  );

  static final withLoyalty = PaymentState(
    totalAmount: Decimal.parse('1150'),
    paymentType: PaymentType.cash,
    loyaltyCustomer: LoyaltyCustomer(
      id: 1,
      phone: '+77001234567',
      name: 'Тестовый Клиент',
      bonusBalance: Decimal.parse('500'),
    ),
    bonusToUse: Decimal.parse('200'),
  );

  static final processing = PaymentState(
    totalAmount: Decimal.parse('1150'),
    paymentType: PaymentType.cash,
    cashReceived: Decimal.parse('1150'),
    isProcessing: true,
  );

  static final withError = PaymentState(
    totalAmount: Decimal.parse('1150'),
    error: 'Ошибка обработки платежа',
  );
}

class TestRefundStates {
  TestRefundStates._();

  static const empty = RefundState();

  static final byReceipt = RefundState(
    mode: RefundMode.byReceipt,
    receiptInfo: ReceiptInfo(
      receiptNo: 42,
      posId: 1,
      date: DateTime(2026, 2, 15, 10, 30),
      total: Decimal.parse('1150'),
      posName: 'Касса 1',
    ),
    items: [
      RefundItem(
        id: 'refund_1',
        productId: 1,
        name: 'Молоко 1л',
        price: Decimal.parse('500'),
        quantity: Decimal.fromInt(2),
        maxQuantity: Decimal.fromInt(2),
        isSelected: true,
      ),
      RefundItem(
        id: 'refund_2',
        productId: 2,
        name: 'Хлеб белый',
        price: Decimal.parse('150'),
        quantity: Decimal.one,
        maxQuantity: Decimal.one,
        isSelected: false,
      ),
    ],
  );

  static final withoutReceipt = RefundState(
    mode: RefundMode.withoutReceipt,
    items: [
      RefundItem(
        id: 'refund_1',
        productId: 1,
        name: 'Молоко 1л',
        price: Decimal.parse('500'),
        quantity: Decimal.one,
        maxQuantity: Decimal.fromInt(999),
        isSelected: true,
      ),
    ],
  );

  static const loading = RefundState(
    mode: RefundMode.byReceipt,
    isLoading: true,
  );

  static const withError = RefundState(error: 'Чек #999 не найден');
}

class TestShiftStates {
  TestShiftStates._();

  static final closed = ShiftState(isOpen: false, isLoading: false);

  static final open = ShiftState(
    isOpen: true,
    openTime: DateTime(2026, 2, 15, 9, 0),
    cashierName: 'Кассир Тест',
    cashierId: 1,
    systemTotal: Decimal.parse('50000'),
    investmentTotal: Decimal.parse('10000'),
    expenseTotal: Decimal.parse('2000'),
    dividendTotal: Decimal.parse('5000'),
    activeSalesCount: 0,
    pendingSalesCount: 0,
    cashOperations: [
      CashOperationItem(
        id: 1,
        type: CashOperationType.investment,
        amount: Decimal.parse('10000'),
        note: 'Размен',
        time: DateTime(2026, 2, 15, 9, 5),
      ),
      CashOperationItem(
        id: 2,
        type: CashOperationType.expense,
        amount: Decimal.parse('2000'),
        note: 'Канцтовары',
        time: DateTime(2026, 2, 15, 12, 30),
      ),
    ],
    isLoading: false,
  );

  static final withBills = ShiftState(
    isOpen: true,
    systemTotal: Decimal.parse('50000'),
    billCounts: {1000: 5, 2000: 10, 5000: 3, 10000: 1},
    billsTotal: Decimal.parse('50000'),
    isLoading: false,
  );

  static final withPositiveDifference = ShiftState(
    isOpen: true,
    systemTotal: Decimal.parse('50000'),
    billsTotal: Decimal.parse('52000'),
    billCounts: const {5000: 10, 2000: 1},
    isLoading: false,
  );

  static final withNegativeDifference = ShiftState(
    isOpen: true,
    systemTotal: Decimal.parse('50000'),
    billsTotal: Decimal.parse('48000'),
    billCounts: const {5000: 9, 2000: 1, 1000: 1},
    isLoading: false,
  );

  static final loading = ShiftState(isLoading: true);
}

class TestHistoryStates {
  TestHistoryStates._();

  static final empty = HistoryState(items: [], totalCount: 0, isLoading: false);

  static final withItems = HistoryState(
    items: [
      HistoryItem(
        id: 1,
        receiptNo: 42,
        posId: 1,
        type: HistoryItemType.sale,
        amount: Decimal.parse('1150'),
        time: DateTime(2026, 2, 15, 14, 30),
        syncState: HistorySyncState.synced,
        paymentType: HistoryPaymentType.cash,
        ofdState: HistoryOfdState.fiscalized,
      ),
      HistoryItem(
        id: 2,
        receiptNo: 43,
        posId: 1,
        type: HistoryItemType.sale,
        amount: Decimal.parse('500'),
        time: DateTime(2026, 2, 15, 15, 0),
        syncState: HistorySyncState.pendingSync,
        paymentType: HistoryPaymentType.card,
        ofdState: HistoryOfdState.notFiscalized,
      ),
      HistoryItem(
        id: 3,
        receiptNo: 42,
        posId: 1,
        type: HistoryItemType.refund,
        amount: Decimal.parse('500'),
        time: DateTime(2026, 2, 15, 16, 0),
        syncState: HistorySyncState.pendingSync,
        paymentType: HistoryPaymentType.cash,
        ofdState: HistoryOfdState.notFiscalized,
        customerName: 'Покупатель Тест',
      ),
    ],
    totalCount: 3,
    isLoading: false,
  );

  static final loading = HistoryState(isLoading: true);

  static final withFilters = HistoryState(
    items: [],
    totalCount: 0,
    dateFrom: DateTime(2026, 2, 1),
    dateTo: DateTime(2026, 2, 28),
    typeFilter: HistoryItemType.sale,
    isLoading: false,
  );
}

class TestAgentStates {
  TestAgentStates._();

  static const empty = AgentSearchState();

  static final withAgents = AgentSearchState(
    items: [
      AgentItem(
        localId: 1,
        name: 'Покупатель Тест',
        phone: '77001234567',
        balance: Decimal.parse('-5000'),
        type: AgentType.customer,
      ),
      AgentItem(
        localId: 2,
        name: 'ТОО "Поставщик"',
        phone: '77009876543',
        bin: '123456789012',
        balance: Decimal.parse('100000'),
        type: AgentType.supplier,
      ),
      AgentItem(
        localId: 3,
        name: 'Клиент без долга',
        balance: Decimal.zero,
        type: AgentType.customer,
      ),
    ],
  );

  static const loading = AgentSearchState(isLoading: true);

  static final suppliers = AgentSearchState(
    agentType: AgentType.supplier,
    items: [
      AgentItem(
        localId: 2,
        name: 'ТОО "Поставщик"',
        phone: '77009876543',
        bin: '123456789012',
        balance: Decimal.parse('100000'),
        type: AgentType.supplier,
      ),
    ],
  );
}

class TestSupplyStates {
  TestSupplyStates._();

  static const empty = SupplyState();

  static final withProducts = SupplyState(
    supplierId: 1,
    supplierName: 'ТОО "Поставщик"',
    paymentType: SupplyPaymentType.fullSupply,
    accountId: 1,
    accountName: 'Касса',
    products: [
      SupplyProductInfo(
        ucode: 1,
        productName: 'Молоко 1л',
        quantity: Decimal.fromInt(10),
        price: Decimal.parse('450'),
        barcode: '4607025392408',
      ),
      SupplyProductInfo(
        ucode: 2,
        productName: 'Хлеб белый',
        quantity: Decimal.fromInt(20),
        price: Decimal.parse('120'),
        barcode: '4607036278901',
      ),
    ],
  );

  static final consignment = SupplyState(
    supplierId: 1,
    supplierName: 'ТОО "Поставщик"',
    paymentType: SupplyPaymentType.consignment,
    products: [
      SupplyProductInfo(
        ucode: 1,
        productName: 'Молоко 1л',
        quantity: Decimal.fromInt(10),
        price: Decimal.parse('450'),
      ),
    ],
  );

  static const saving = SupplyState(isSaving: true);
}

class TestAppStates {
  TestAppStates._();

  static const initial = AppState();

  static const cashier = AppState(
    userId: 1,
    userName: 'Кассир Тест',
    userRole: 0,
    posName: 'Касса 1',
    isShiftOpened: true,
    permissions: {'SALE', 'REFUND', 'HISTORY', 'SHIFT'},
  );

  static const admin = AppState(
    userId: 2,
    userName: 'Администратор',
    userRole: 1,
    posName: 'Касса 1',
    isShiftOpened: true,
    permissions: {
      'SALE',
      'REFUND',
      'HISTORY',
      'SHIFT',
      'EDIT_PRICE',
      'SUPPLY',
      'AGENT',
      'CASH_OPERATION',
      'SETTINGS',
    },
  );
}

class TestWriteoffStates {
  TestWriteoffStates._();

  static const empty = WriteoffState();

  static final withProducts = WriteoffState(
    reason: WriteoffReason.breakage,
    products: [
      WriteoffProductItem(
        ucode: 1,
        name: 'Молоко 1л',
        quantity: Decimal.fromInt(2),
        price: Decimal.parse('500'),
        barcode: '4607025392408',
      ),
      WriteoffProductItem(
        ucode: 2,
        name: 'Хлеб белый',
        quantity: Decimal.one,
        price: Decimal.parse('150'),
        barcode: '4607036278901',
      ),
    ],
  );

  static const saving = WriteoffState(isSaving: true);

  static const withError = WriteoffState(error: 'Товар не найден: 999');

  static final expired = WriteoffState(
    reason: WriteoffReason.expired,
    products: [
      WriteoffProductItem(
        ucode: 1,
        name: 'Кефир 500мл',
        quantity: Decimal.fromInt(5),
        price: Decimal.parse('350'),
      ),
    ],
  );
}

class TestInventoryStates {
  TestInventoryStates._();

  static const inactive = InventoryState();

  static final active = InventoryState(
    inventoryId: 1,
    isActive: true,
    products: [
      InventoryProductItem(
        ucode: 1,
        name: 'Молоко 1л',
        expectedQty: Decimal.fromInt(10),
        actualQty: Decimal.fromInt(9),
        price: Decimal.parse('500'),
        barcode: '4607025392408',
      ),
      InventoryProductItem(
        ucode: 2,
        name: 'Хлеб белый',
        expectedQty: Decimal.fromInt(20),
        actualQty: Decimal.fromInt(20),
        price: Decimal.parse('150'),
        barcode: '4607036278901',
      ),
      InventoryProductItem(
        ucode: 3,
        name: 'Яблоки',
        expectedQty: Decimal.fromInt(15),
        actualQty: Decimal.fromInt(17),
        price: Decimal.parse('800'),
        barcode: '2761234000003',
      ),
    ],
  );

  static const activeEmpty = InventoryState(inventoryId: 1, isActive: true);

  static const withError = InventoryState(
    inventoryId: 1,
    isActive: true,
    error: 'Товар не найден: 999',
  );
}
