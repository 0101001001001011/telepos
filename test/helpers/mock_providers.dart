import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
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
import 'package:telepos/domain/shift/shift_status.dart';

class MockSaleNotifier extends Notifier<SaleState> implements SaleNotifier {
  MockSaleNotifier([this.initialState]);

  final SaleState? initialState;

  @override
  SaleState build() => initialState ?? const SaleState();

  @override
  Future<void> search(String query) async {}

  @override
  Future<int?> currentTerminalId() async => 7;

  @override
  void clearWarning() {}

  @override
  void clearError() {}

  @override
  Future<void> addProduct(
    sale.ProductSearchResult product, {
    Decimal? quantity,
  }) async {}

  @override
  void selectItem(String? itemId) {}

  @override
  Future<void> updateQuantity(Decimal quantity) async {}

  @override
  Future<void> incrementQuantity() async {}

  @override
  Future<void> decrementQuantity() async {}

  /// Условия правки строки по умолчанию — предел **сто процентов с
  /// названной причиной**, правка цены и скидка разрешены.
  ///
  /// Не «удобное значение»: проба, которой предел не важен, не должна
  /// молча получать ограничение, а проба про предел обязана назвать своё
  /// (`_RecordingSaleNotifier` в `sale_discount_entry_test.dart`).
  @override
  Future<SaleEditTerms?> editTerms() async => SaleEditTerms(
    policy: const SalePolicy(editPrice: true, sellInDiscount: true),
    cap: DiscountCap(
      maxPercent: Decimal.fromInt(100),
      approvalAbove: null,
      source: 'предел кассы по умолчанию',
    ),
    currencySymbol: '₸',
  );

  @override
  Future<void> setDiscountPercent(Decimal percent) async {}

  @override
  Future<void> setDiscountAmount(Decimal amount) async {}

  @override
  Future<void> updatePrice(Decimal price) async {}

  @override
  Future<void> setMark(String mark) async {}

  @override
  Future<void> removeSelectedItem() async {}

  @override
  Future<void> clearSale() async {}

  @override
  Future<bool> deferSale() async => true;

  @override
  Future<void> loadDeferredSale(int receiptNo) async {}

  @override
  Future<void> toggleMode() async {}

  @override
  Future<void> setAgent(int id, String name) async {}

  @override
  Future<void> clearAgent() async {}

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
  SaleOutcome? get lastOutcome => null;

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(int receiptNo) async =>
      const [];

  @override
  void setPaymentType(PaymentType type) {}

  @override
  void setInstallmentTerms({
    required int termMonths,
    required InstallmentScheme scheme,
  }) {}

  @override
  void setPrepaymentToUse(Decimal amount) {}

  @override
  void useAllPrepayment() {}

  @override
  Future<void> startQr(Decimal amount) async {}

  @override
  Future<void> pollQr({bool manual = false}) async {}

  @override
  Future<void> cancelQr() async {}

  @override
  void dismissQr() {}

  @override
  Future<bool> presentCertificate(String number, {String? pin}) async =>
      false;

  @override
  void removeCertificate(String number) {}

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
  Future<void> setBonusToUse(Decimal amount) async {}

  @override
  Future<void> useAllBonus() async {}

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

  /// Признак обработки **настоящий**, а не пустышка.
  ///
  /// Круг правки 5 задачи 14: экран гасит кнопку и отсекает второе
  /// нажатие именно этим признаком, и подделка, которая его не помнит,
  /// доказывала бы про двойное нажатие ровно ничего.
  @override
  void setProcessing(bool value) => state = state.copyWith(isProcessing: value);

  /// Чем кончится оплата.
  ///
  /// `false` даёт пробе остановиться сразу после того, как экран
  /// поговорил с эквайрингом, — дальше `_onPaymentRecorded` печатает чек
  /// и уходит по маршруту, которых в виджет-пробе нет.
  bool completes = true;

  @override
  Future<bool> processPayment() async => completes;

  /// Суммы, с которыми экран звал эквайринг.
  ///
  /// Записываются, а не выбрасываются: круг правки 3 задачи 14 нашёл, что
  /// экран звал платёжный терминал **только** при чистой карте, а касса
  /// требовала доказательства при любой безналичной части — то есть
  /// смешанная оплата и долг с картой на кассе с привязанным эквайрингом
  /// не работали вовсе. Ни одна проба этого не видела, потому что ни одна
  /// не шла путём экрана.
  final chargedAmounts = <Decimal>[];

  @override
  Future<CardCharge> chargeCardViaTerminal(Decimal amount) async {
    chargedAmounts.add(amount);
    return const CardCharge(outcome: CardChargeOutcome.notConfigured);
  }
}

class MockRefundNotifier extends Notifier<RefundState>
    implements RefundNotifier {
  MockRefundNotifier([this.initialState]);

  final RefundState? initialState;

  @override
  RefundState build() => initialState ?? const RefundState();

  @override
  Future<void> setMode(RefundMode mode) async {}

  @override
  Future<void> loadReceipt(int receiptNo, int posId) async {}

  @override
  Future<void> search(String query) async {}

  @override
  Future<void> addProduct(
    RefundSearchResult product, {
    Decimal? quantity,
  }) async {}

  @override
  void selectItem(String? itemId) {}

  @override
  Future<void> toggleItemSelection(String itemId) async {}

  @override
  Future<void> selectAll() async {}

  @override
  Future<void> deselectAll() async {}

  @override
  Future<void> updateQuantity(String itemId, Decimal quantity) async {}

  @override
  void setReason(String itemId, RefundReason reason) {}

  @override
  Future<void> removeItem(String itemId) async {}

  @override
  Future<void> removeSelectedItem() async {}

  @override
  void clear() {}

  @override
  Future<bool> processRefund() async => true;

  /// Беды железа проведённого возврата — у подделки их нет.
  @override
  Future<List<CompletionTrouble>> hardwareTroubles() async => const [];

  /// Заведена кругом правки задачи 20: экран поднимает подписку при каждом
  /// заходе, а не один раз за жизнь провайдера. Подделке подписывать нечего.
  @override
  Future<void> ensureWatching() async {}
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
  void setShift(ShiftStatus shift) {}

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
