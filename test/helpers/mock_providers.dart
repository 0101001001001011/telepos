import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart'
    hide ProductSearchResult;
import 'package:telepos/presentation/controllers/sale/sale_controller.dart'
    as sale
    show ProductSearchResult;
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/controllers/supply/supply_controller.dart'
    hide ProductSearchResult;
import 'package:telepos/presentation/controllers/supply/supply_controller.dart'
    as supply
    show ProductSearchResult;
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';
import 'package:telepos/domain/usecases/inventory/create_inventory_use_case.dart';
import 'package:telepos/presentation/controllers/writeoff/writeoff_controller.dart';
import 'package:telepos/presentation/controllers/inventory/inventory_controller.dart';

class MockSaleNotifier extends Notifier<SaleState> implements SaleNotifier {
  MockSaleNotifier([this.initialState]);

  final SaleState? initialState;

  @override
  SaleState build() => initialState ?? const SaleState();

  @override
  Future<void> search(String query) async {}

  @override
  void clearWarning() {}

  @override
  void addProduct(sale.ProductSearchResult product, {Decimal? quantity}) {}

  @override
  void selectItem(String? itemId) {}

  @override
  void updateQuantity(Decimal quantity) {}

  @override
  void incrementQuantity() {}

  @override
  void decrementQuantity() {}

  @override
  void setDiscountPercent(Decimal percent) {}

  @override
  void setDiscountAmount(Decimal amount) {}

  @override
  void updatePrice(Decimal price) {}

  @override
  Future<bool> canEditPrice() async => true;

  @override
  void setMark(String mark) {}

  @override
  void removeSelectedItem() {}

  @override
  void clearSale() {}

  @override
  Future<void> deferSale() async {}

  @override
  Future<void> loadDeferredSale(int receiptNo) async {}

  @override
  void toggleMode() {}

  @override
  void setAgent(int id, String name) {}

  @override
  void clearAgent() {}

  @override
  Future<void> startNewSale() async {}

  @override
  Future<bool> addByBarcode(String barcode) async => true;

  @override
  Future<void> loadFromRestaurantOrder({
    required int receiptNo,
    required int posId,
  }) async {}

  @override
  Future<bool> completeSale({
    required List<PaymentEntry> payments,
    required Decimal change,
    String? customerBin,
    bool? selectiveOfd,
    List<CustomFieldEntry>? customFields,
    WithdrawalEntry? withdrawal,
  }) async => true;
}

class MockPaymentNotifier extends Notifier<PaymentState>
    implements PaymentNotifier {
  MockPaymentNotifier([this.initialState]);

  final PaymentState? initialState;

  @override
  PaymentState build() =>
      initialState ?? PaymentState(totalAmount: Decimal.zero);

  @override
  void initialize(Decimal amount) {}

  @override
  void setPaymentType(PaymentType type) {}

  @override
  void setCashReceived(Decimal amount) {}

  @override
  void addCash(Decimal amount) {}

  @override
  void setExactAmount() {}

  @override
  void clearCashReceived() {}

  @override
  void setCardAmount(Decimal amount) {}

  @override
  void selectAccount(int accountId) {}

  @override
  Future<void> searchLoyaltyCustomer(String phone) async {}

  @override
  void clearLoyaltyCustomer() {}

  @override
  void setBonusToUse(Decimal amount) {}

  @override
  void useAllBonus() {}

  @override
  void setIin(String? iin) {}

  @override
  void setActiveInput(PaymentInputField field) {}

  @override
  void numpadKey(String key) {}

  @override
  void numpadBackspace() {}

  @override
  void numpadClear() {}

  @override
  void setProcessing(bool value) {}

  @override
  Future<bool> processPayment() async => true;

  @override
  Future<CardTerminalResult> chargeCardViaTerminal(Decimal amount) async =>
      const CardTerminalResult(outcome: CardTerminalOutcome.notConfigured);
}

class MockRefundNotifier extends Notifier<RefundState>
    implements RefundNotifier {
  MockRefundNotifier([this.initialState]);

  final RefundState? initialState;

  @override
  RefundState build() => initialState ?? const RefundState();

  @override
  void setMode(RefundMode mode) {}

  @override
  Future<void> loadReceipt(int receiptNo, int posId) async {}

  @override
  Future<void> search(String query) async {}

  @override
  void addProduct(RefundSearchResult product, {Decimal? quantity}) {}

  @override
  void selectItem(String? itemId) {}

  @override
  void toggleItemSelection(String itemId) {}

  @override
  void selectAll() {}

  @override
  void deselectAll() {}

  @override
  void updateQuantity(String itemId, Decimal quantity) {}

  @override
  void setReason(String itemId, RefundReason reason) {}

  @override
  void removeItem(String itemId) {}

  @override
  void removeSelectedItem() {}

  @override
  void clear() {}

  @override
  Future<bool> processRefund() async => true;
}

class MockShiftNotifier extends Notifier<ShiftState> implements ShiftNotifier {
  MockShiftNotifier([this.initialState]);

  final ShiftState? initialState;

  @override
  ShiftState build() => initialState ?? ShiftState(isLoading: false);

  @override
  Future<void> openShift(Decimal initialAmount, {int? userId}) async {}

  @override
  Future<void> closeShift() async {}

  @override
  Future<ZReportOutcome> printZReport() async => ZReportOutcome.queued;

  @override
  void setBillCount(int denomination, int count) {}

  @override
  void incrementBill(int denomination) {}

  @override
  void decrementBill(int denomination) {}

  @override
  void clearBills() {}

  @override
  void setManualTotal(Decimal amount) {}

  @override
  void clearManualTotal() {}

  @override
  void selectTab(int index) {}

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHistoryNotifier extends Notifier<HistoryState>
    implements HistoryNotifier {
  MockHistoryNotifier([this.initialState]);

  final HistoryState? initialState;

  @override
  HistoryState build() => initialState ?? HistoryState(isLoading: false);

  @override
  Future<void> loadPage(int page) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> goToFirst() async {}

  @override
  Future<void> goToPrevious() async {}

  @override
  Future<void> goToNext() async {}

  @override
  Future<void> goToLast() async {}

  @override
  void setDateRange(DateTime? from, DateTime? to) {}

  @override
  void setPosFilter(int? posId) {}

  @override
  void setSearchQuery(String? query) {}

  @override
  void setTypeFilter(HistoryItemType? type) {}

  @override
  void clearFilters() {}

  @override
  void sortBy(String column, bool ascending) {}
}

class MockAgentSearchNotifier extends Notifier<AgentSearchState>
    implements AgentSearchNotifier {
  MockAgentSearchNotifier([this.initialState]);

  final AgentSearchState? initialState;

  @override
  AgentSearchState build() => initialState ?? const AgentSearchState();

  @override
  Future<void> search(String query) async {}

  @override
  void setAgentType(AgentType type) {}

  @override
  void toggleShowOnlyWithDebt() {}

  @override
  void clear() {}
}

class MockAddCustomerNotifier extends Notifier<AddCustomerState>
    implements AddCustomerNotifier {
  MockAddCustomerNotifier([this.initialState]);

  final AddCustomerState? initialState;

  @override
  AddCustomerState build() => initialState ?? const AddCustomerState();

  @override
  void setAgentType(AgentType type) {}

  @override
  void setName(String value) {}

  @override
  void setPhone(String value) {}

  @override
  void setBin(String value) {}

  @override
  Future<AgentItem?> save() async => null;

  @override
  Future<AgentItem?> restoreDeleted() async => null;

  @override
  void reset() {}
}

class MockSupplyNotifier extends Notifier<SupplyState>
    implements SupplyController {
  MockSupplyNotifier([this.initialState]);

  final SupplyState? initialState;

  @override
  SupplyState build() => initialState ?? const SupplyState();

  @override
  Future<List<SupplierItem>> getSuppliers() async => [];

  @override
  Future<List<AccountItem>> getAccounts() async => [];

  @override
  Future<supply.ProductSearchResult?> findProductByBarcode(
    String barcode,
  ) async => null;

  @override
  Future<bool> addByBarcode(String barcode) async => true;

  @override
  Future<void> selectSupplier(int agentId) async {}

  @override
  Future<void> selectAccount(int accountId) async {}

  @override
  void setPaymentType(SupplyPaymentType type) {}

  @override
  void setComment(String comment) {}

  @override
  Future<void> addProduct({
    required int ucode,
    required Decimal quantity,
    required Decimal price,
    List<String>? serialNumbers,
  }) async {}

  @override
  void updateProduct({
    required int ucode,
    required Decimal quantity,
    required Decimal price,
    List<String>? serialNumbers,
  }) {}

  @override
  Future<bool> isSerialTrackingEnabled() async => false;

  @override
  void removeProduct(int ucode) {}

  @override
  Future<SaveSupplyResult> save() async => SaveSupplyResult.failed('Mock');

  @override
  void cancel() {}

  @override
  void reset() {}

  @override
  void clearError() {}
}

class MockAppStateNotifier extends Notifier<AppState>
    implements AppStateNotifier {
  MockAppStateNotifier([this.initialState]);

  final AppState? initialState;

  @override
  AppState build() => initialState ?? const AppState();

  @override
  void setPosInfo({String? name}) {}

  @override
  void setUserInfo({
    int? id,
    String? name,
    int? role,
    Set<String>? permissions,
  }) {}

  @override
  void setTestUser({required int userId, String? userName}) {}

  @override
  void setShiftOpened(bool isOpened) {}

  @override
  void setConnectionStatus(ConnectionStatus status) {}

  @override
  void dismissStorageWarning() {}

  @override
  void setOperatingMode(OperatingMode mode) {}

  @override
  void logout() {}
}

class MockWriteoffNotifier extends Notifier<WriteoffState>
    implements WriteoffNotifier {
  MockWriteoffNotifier([this.initialState]);

  final WriteoffState? initialState;

  @override
  WriteoffState build() => initialState ?? const WriteoffState();

  @override
  void setReason(WriteoffReason reason) {}

  @override
  void setComment(String comment) {}

  @override
  Future<void> addProductByBarcode(String barcode) async {}

  @override
  void updateQuantity(int ucode, Decimal quantity) {}

  @override
  void removeProduct(int ucode) {}

  @override
  Future<CreateWriteoffResult> save() async =>
      CreateWriteoffResult.failed('Mock');

  @override
  void reset() {}
}

class MockInventoryNotifier extends Notifier<InventoryState>
    implements InventoryNotifier {
  MockInventoryNotifier([this.initialState]);

  final InventoryState? initialState;

  @override
  InventoryState build() => initialState ?? const InventoryState();

  @override
  Future<void> startNew({String? comment, bool? isFullCount}) async {}

  @override
  void setFullCount(bool isFullCount) {}

  @override
  Future<void> scanProduct(String barcode) async {}

  @override
  Future<void> setActualQty(int ucode, Decimal qty) async {}

  @override
  Future<CreateInventoryResult> complete() async =>
      CreateInventoryResult.failed('Mock');

  @override
  void reset() {}
}

List<dynamic> createTestOverrides({
  SaleState? saleState,
  PaymentState? paymentState,
  RefundState? refundState,
  ShiftState? shiftState,
  HistoryState? historyState,
  AgentSearchState? agentSearchState,
  AddCustomerState? addCustomerState,
  SupplyState? supplyState,
  WriteoffState? writeoffState,
  InventoryState? inventoryState,
  AppState? appState,
}) {
  final overrides = <dynamic>[];

  if (saleState != null) {
    overrides.add(
      saleControllerProvider.overrideWith(() => MockSaleNotifier(saleState)),
    );
  }

  if (paymentState != null) {
    overrides.add(
      paymentControllerProvider.overrideWith(
        () => MockPaymentNotifier(paymentState),
      ),
    );
  }

  if (refundState != null) {
    overrides.add(
      refundControllerProvider.overrideWith(
        () => MockRefundNotifier(refundState),
      ),
    );
  }

  if (shiftState != null) {
    overrides.add(
      shiftControllerProvider.overrideWith(() => MockShiftNotifier(shiftState)),
    );
  }

  if (historyState != null) {
    overrides.add(
      historyControllerProvider.overrideWith(
        () => MockHistoryNotifier(historyState),
      ),
    );
  }

  if (agentSearchState != null) {
    overrides.add(
      agentSearchProvider.overrideWith(
        () => MockAgentSearchNotifier(agentSearchState),
      ),
    );
  }

  if (addCustomerState != null) {
    overrides.add(
      addCustomerProvider.overrideWith(
        () => MockAddCustomerNotifier(addCustomerState),
      ),
    );
  }

  if (supplyState != null) {
    overrides.add(
      supplyControllerProvider.overrideWith(
        () => MockSupplyNotifier(supplyState),
      ),
    );
  }

  if (writeoffState != null) {
    overrides.add(
      writeoffControllerProvider.overrideWith(
        () => MockWriteoffNotifier(writeoffState),
      ),
    );
  }

  if (inventoryState != null) {
    overrides.add(
      inventoryControllerProvider.overrideWith(
        () => MockInventoryNotifier(inventoryState),
      ),
    );
  }

  if (appState != null) {
    overrides.add(
      appStateProvider.overrideWith(() => MockAppStateNotifier(appState)),
    );
  }

  return overrides;
}
