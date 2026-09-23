import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/presentation/controllers/app/money_ledger_revision.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';

enum HistoryItemType { sale, refund, serviceOrder, restaurantOrder }

enum HistoryPaymentType { cash, card, mixed, bonus, debt, discount }

enum HistorySyncState { inProgress, pendingSync, beingSent, deferred, synced }

enum HistoryOfdState { notFiscalized, fiscalized, error }

@immutable
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.receiptNo,
    required this.posId,
    required this.type,
    required this.amount,
    required this.time,
    required this.syncState,
    required this.paymentType,
    required this.ofdState,
    this.customerName,
    this.orderNumber,
    this.deviceDescription,
    this.orderStatus,
    this.orderType,
  });

  final int id;

  final int receiptNo;

  final int posId;

  final HistoryItemType type;

  final Decimal amount;

  final DateTime time;

  final HistorySyncState syncState;

  final HistoryPaymentType paymentType;

  final HistoryOfdState ofdState;

  final String? customerName;

  final String? orderNumber;

  final String? deviceDescription;

  final int? orderStatus;

  final int? orderType;

  String get formattedReceiptNo => switch (type) {
    HistoryItemType.serviceOrder => orderNumber ?? '#$receiptNo',
    HistoryItemType.restaurantOrder => 'R-$receiptNo',
    _ => '#$receiptNo',
  };

  String get typePrefix => switch (type) {
    HistoryItemType.sale => '+',
    HistoryItemType.refund => '-',
    HistoryItemType.serviceOrder => '',
    HistoryItemType.restaurantOrder => '',
  };
}

@immutable
class HistoryState {
  // ignore: prefer_const_constructors_in_immutables - List fields
  HistoryState({
    this.items = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.pageSize = 23,
    this.dateFrom,
    this.dateTo,
    this.posId,
    this.searchQuery,
    this.typeFilter,
    this.sortColumn = 'time',
    this.sortAscending = false,
    this.isLoading = false,
    this.error,
  });

  final List<HistoryItem> items;

  final int totalCount;

  final int currentPage;

  final int pageSize;

  final DateTime? dateFrom;

  final DateTime? dateTo;

  final int? posId;

  final String? searchQuery;

  final HistoryItemType? typeFilter;

  final String sortColumn;

  final bool sortAscending;

  final bool isLoading;

  final String? error;

  int get totalPages => (totalCount / pageSize).ceil().clamp(1, 999999);

  bool get canGoPrevious => currentPage > 1;

  bool get canGoNext => currentPage < totalPages;

  int get startIndex => (currentPage - 1) * pageSize + 1;

  int get endIndex => (startIndex + items.length - 1).clamp(1, totalCount);

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      posId != null ||
      (searchQuery != null && searchQuery!.isNotEmpty) ||
      typeFilter != null;

  HistoryState copyWith({
    List<HistoryItem>? items,
    int? totalCount,
    int? currentPage,
    int? pageSize,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? posId,
    String? searchQuery,
    HistoryItemType? typeFilter,
    String? sortColumn,
    bool? sortAscending,
    bool? isLoading,
    String? error,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearPosId = false,
    bool clearSearchQuery = false,
    bool clearTypeFilter = false,
  }) {
    return HistoryState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      posId: clearPosId ? null : (posId ?? this.posId),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    // См. `ShiftNotifier.build` и докстринг `MoneyLedgerRevision`.
    ref.watch(moneyLedgerRevisionProvider);
    Future.microtask(() => _loadPage(1));
    return HistoryState(isLoading: true);
  }

  AppDatabase get _db => GetIt.I<AppDatabase>();

  Future<void> loadPage(int page) async {
    if (page < 1 || page > state.totalPages) return;
    await _loadPage(page);
  }

  Future<void> refresh() async {
    await _loadPage(state.currentPage);
  }

  Future<void> goToFirst() async {
    await loadPage(1);
  }

  Future<void> goToPrevious() async {
    if (state.canGoPrevious) {
      await loadPage(state.currentPage - 1);
    }
  }

  Future<void> goToNext() async {
    if (state.canGoNext) {
      await loadPage(state.currentPage + 1);
    }
  }

  Future<void> goToLast() async {
    await loadPage(state.totalPages);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void setPosFilter(int? posId) {
    state = state.copyWith(
      posId: posId,
      clearPosId: posId == null,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(
      searchQuery: query,
      clearSearchQuery: query == null || query.isEmpty,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void setTypeFilter(HistoryItemType? type) {
    state = state.copyWith(
      typeFilter: type,
      clearTypeFilter: type == null,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void clearFilters() {
    state = state.copyWith(
      clearDateFrom: true,
      clearDateTo: true,
      clearPosId: true,
      clearSearchQuery: true,
      clearTypeFilter: true,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void sortBy(String column, bool ascending) {
    state = state.copyWith(
      sortColumn: column,
      sortAscending: ascending,
      currentPage: 1,
    );
    _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dateFromTs = state.dateFrom != null
          ? state.dateFrom!.millisecondsSinceEpoch ~/ 1000
          : null;
      final dateToTs = state.dateTo != null
          ? (state.dateTo!.millisecondsSinceEpoch ~/ 1000) + 86400
          : null;

      final sales = await _loadSales(
        page: page,
        dateFromTs: dateFromTs,
        dateToTs: dateToTs,
      );

      final refunds =
          (state.typeFilter == null ||
              state.typeFilter == HistoryItemType.refund)
          ? await _loadRefunds(
              page: page,
              dateFromTs: dateFromTs,
              dateToTs: dateToTs,
            )
          : <HistoryItem>[];

      final serviceOrders =
          (state.typeFilter == null ||
              state.typeFilter == HistoryItemType.serviceOrder)
          ? await _loadServiceOrders(dateFromTs: dateFromTs, dateToTs: dateToTs)
          : <HistoryItem>[];

      final restaurantOrders =
          (state.typeFilter == null ||
              state.typeFilter == HistoryItemType.restaurantOrder)
          ? await _loadRestaurantOrders(
              dateFromTs: dateFromTs,
              dateToTs: dateToTs,
            )
          : <HistoryItem>[];

      var items = <HistoryItem>[];
      if (state.typeFilter == HistoryItemType.sale) {
        items = sales;
      } else if (state.typeFilter == HistoryItemType.refund) {
        items = refunds;
      } else if (state.typeFilter == HistoryItemType.serviceOrder) {
        items = serviceOrders;
      } else if (state.typeFilter == HistoryItemType.restaurantOrder) {
        items = restaurantOrders;
      } else {
        items = [...sales, ...refunds, ...serviceOrders, ...restaurantOrders];
      }
      items.sort(_compareItems);

      final startIdx = (page - 1) * state.pageSize;
      final pageItems = items.length > startIdx
          ? items.skip(startIdx).take(state.pageSize).toList()
          : <HistoryItem>[];

      state = state.copyWith(
        items: pageItems,
        totalCount: items.length,
        currentPage: page,
        isLoading: false,
      );
    } catch (e, st) {
      debugPrint('HistoryNotifier._loadPage failed: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<List<HistoryItem>> _loadSales({
    required int page,
    int? dateFromTs,
    int? dateToTs,
  }) async {
    final thisPos = await _db.thisPosDao.get();
    final currentPosId = state.posId ?? thisPos?.id ?? 0;

    final sales = await _db.saleDao.findByPosIdAndBetweenDate(
      currentPosId,
      dateFromTs ?? 0,
      dateToTs ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400),
      limit: -1,
    );

    final items = <HistoryItem>[];
    for (final sale in sales) {
      final paymentType = await _determinePaymentTypeForSale(
        sale.receiptNo,
        sale.posId,
      );
      items.add(
        HistoryItem(
          id: sale.saleId ?? sale.receiptNo,
          receiptNo: sale.receiptNo,
          posId: sale.posId,
          type: HistoryItemType.sale,
          amount: sale.amount,
          time: DateTime.fromMillisecondsSinceEpoch(sale.time * 1000),
          syncState: _convertSyncState(sale.state),
          paymentType: paymentType,
          ofdState: sale.isOfd
              ? HistoryOfdState.fiscalized
              : HistoryOfdState.notFiscalized,
        ),
      );
    }

    return items;
  }

  Future<List<HistoryItem>> _loadRefunds({
    required int page,
    int? dateFromTs,
    int? dateToTs,
  }) async {
    final byState = await Future.wait([
      _db.refundDao.findByState(0),
      _db.refundDao.findByState(1),
      _db.refundDao.findByState(2),
      _db.refundDao.findByState(3),
      _db.refundDao.findByState(4),
    ]);
    final refunds = [for (final list in byState) ...list];

    final posFilter = state.posId;

    final items = <HistoryItem>[];
    for (final refund in refunds) {
      if (dateFromTs != null && refund.time < dateFromTs) continue;
      if (dateToTs != null && refund.time > dateToTs) continue;

      if (posFilter != null && refund.salePosId != posFilter) continue;

      final paymentType = await _determinePaymentTypeForRefund(refund.localId);

      items.add(
        HistoryItem(
          id: refund.localId,
          receiptNo: refund.saleReceiptNo ?? 0,
          posId: refund.salePosId ?? 0,
          type: HistoryItemType.refund,
          amount: refund.amount,
          time: DateTime.fromMillisecondsSinceEpoch(refund.time * 1000),
          syncState: _convertSyncState(refund.state),
          paymentType: paymentType,
          ofdState: refund.isOfd
              ? HistoryOfdState.fiscalized
              : HistoryOfdState.notFiscalized,
        ),
      );
    }

    return items;
  }

  Future<List<HistoryItem>> _loadServiceOrders({
    int? dateFromTs,
    int? dateToTs,
  }) async {
    final allOrders = await _db.serviceOrderDao.findAll();

    final posFilter = state.posId;

    final items = <HistoryItem>[];
    for (final order in allOrders) {
      if (dateFromTs != null && order.intakeTime < dateFromTs) continue;
      if (dateToTs != null && order.intakeTime > dateToTs) continue;

      if (posFilter != null && order.posId != posFilter) continue;

      if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
        final q = state.searchQuery!.toLowerCase();
        final matches =
            order.orderNumber.toLowerCase().contains(q) ||
            (order.clientName?.toLowerCase().contains(q) ?? false) ||
            (order.clientPhone?.toLowerCase().contains(q) ?? false) ||
            (order.deviceDescription?.toLowerCase().contains(q) ?? false);
        if (!matches) continue;
      }

      items.add(
        HistoryItem(
          id: order.id,
          receiptNo: order.receiptNo ?? 0,
          posId: order.posId ?? 0,
          type: HistoryItemType.serviceOrder,
          amount: order.estimatedAmount ?? order.finalAmount ?? Decimal.zero,
          time: DateTime.fromMillisecondsSinceEpoch(order.intakeTime * 1000),
          syncState: HistorySyncState.inProgress,
          paymentType: HistoryPaymentType.cash,
          ofdState: HistoryOfdState.notFiscalized,
          customerName: order.clientName,
          orderNumber: order.orderNumber,
          deviceDescription: order.deviceDescription,
          orderStatus: order.status,
        ),
      );
    }

    return items;
  }

  Future<List<HistoryItem>> _loadRestaurantOrders({
    int? dateFromTs,
    int? dateToTs,
  }) async {
    final posFilter = state.posId;

    final rows = await _db
        .customSelect(
          'SELECT ro.id, ro.table_id, ro.receipt_no, ro.pos_id, '
          'ro.order_type, ro.open_time, ro.close_time, ro.party_size, '
          'ro.tips, rt.name AS table_name, rt.zone, '
          'COALESCE(s.amount, 0) AS amount '
          'FROM restaurant_orders ro '
          'LEFT JOIN restaurant_tables rt ON rt.id = ro.table_id '
          'LEFT JOIN sales s ON s.receipt_no = ro.receipt_no AND s.pos_id = ro.pos_id '
          'WHERE ro.open_time BETWEEN ? AND ? '
          '${posFilter != null ? 'AND ro.pos_id = ? ' : ''}'
          'ORDER BY ro.open_time DESC',
          variables: [
            Variable.withInt(dateFromTs ?? 0),
            Variable.withInt(
              dateToTs ??
                  (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400),
            ),
            if (posFilter != null) Variable.withInt(posFilter),
          ],
          readsFrom: {},
        )
        .get();

    final items = <HistoryItem>[];
    for (final row in rows) {
      final openTime = row.read<int>('open_time');

      if (state.searchQuery != null && state.searchQuery!.isNotEmpty) {
        final q = state.searchQuery!.toLowerCase();
        final tableName = row.read<String?>('table_name') ?? '';
        final zone = row.read<String?>('zone') ?? '';
        final matches =
            tableName.toLowerCase().contains(q) ||
            zone.toLowerCase().contains(q) ||
            'r-${row.read<int?>('receipt_no') ?? 0}'.contains(q);
        if (!matches) continue;
      }

      final orderTypeVal = row.read<int?>('order_type') ?? 0;
      final tableName = row.read<String?>('table_name');
      final zone = row.read<String?>('zone');
      // Род заказа уже едет значением (`orderType`), и экран рисует по нему
      // значок на своём языке. Здесь остаются только ДАННЫЕ — имя стола и
      // зона; до 2026-09-22 тут же лежали русские слова «Навынос» и
      // «Доставка», которые на английской кассе так и показывались.
      final deviceDesc = orderTypeVal == 0
          ? [
              if (tableName != null && tableName.isNotEmpty) tableName,
              if (zone != null && zone.isNotEmpty) zone,
            ].join(' · ')
          : '';

      items.add(
        HistoryItem(
          id: row.read<int>('id'),
          receiptNo: row.read<int?>('receipt_no') ?? 0,
          posId: row.read<int?>('pos_id') ?? 0,
          type: HistoryItemType.restaurantOrder,
          amount: Decimal.parse((row.read<double?>('amount') ?? 0).toString()),
          time: DateTime.fromMillisecondsSinceEpoch(openTime * 1000),
          syncState: HistorySyncState.synced,
          paymentType: HistoryPaymentType.cash,
          ofdState: HistoryOfdState.notFiscalized,
          deviceDescription: deviceDesc,
          orderType: orderTypeVal,
          orderStatus: row.read<int?>('close_time') != null ? 1 : 0,
        ),
      );
    }

    return items;
  }

  // ignore: unused_element
  HistoryPaymentType _determinePaymentType({
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal bonusAmount,
    required Decimal debtAmount,
    required Decimal discountAmount,
  }) {
    final hasCash = cashAmount > Decimal.zero;
    final hasCard = cardAmount > Decimal.zero;
    final hasBonus = bonusAmount > Decimal.zero;
    final hasDebt = debtAmount > Decimal.zero;
    final hasDiscount = discountAmount > Decimal.zero;

    if (hasDebt) return HistoryPaymentType.debt;
    if (hasBonus) return HistoryPaymentType.bonus;
    if (hasDiscount) return HistoryPaymentType.discount;
    if (hasCash && hasCard) return HistoryPaymentType.mixed;
    if (hasCard) return HistoryPaymentType.card;
    return HistoryPaymentType.cash;
  }

  // ignore: unused_element
  Future<HistoryPaymentType> _determinePaymentTypeForSale(
    int receiptNo,
    int posId,
  ) async {
    try {
      final payments = await _db.paymentDao.findBySale(receiptNo, posId);
      if (payments.isEmpty) return HistoryPaymentType.cash;

      bool hasCash = false;
      bool hasCard = false;

      for (final p in payments) {
        final account = await _db.accountDao.findById(p.payeeAccountId);
        final accountType = account?.type ?? 0;
        if (accountType == 0 || accountType == 2) {
          hasCash = true;
        } else {
          hasCard = true;
        }
      }

      if (hasCash && hasCard) return HistoryPaymentType.mixed;
      if (hasCard) return HistoryPaymentType.card;
      return HistoryPaymentType.cash;
    } catch (_) {
      return HistoryPaymentType.cash;
    }
  }

  Future<HistoryPaymentType> _determinePaymentTypeForRefund(
    int refundLocalId,
  ) async {
    try {
      final payments = await _db.paymentDao.findByRefund(refundLocalId);
      if (payments.isEmpty) return HistoryPaymentType.cash;

      bool hasCash = false;
      bool hasCard = false;

      for (final p in payments) {
        final account = await _db.accountDao.findById(p.payeeAccountId);
        final accountType = account?.type ?? 0;
        if (accountType == 0 || accountType == 2) {
          hasCash = true;
        } else {
          hasCard = true;
        }
      }

      if (hasCash && hasCard) return HistoryPaymentType.mixed;
      if (hasCard) return HistoryPaymentType.card;
      return HistoryPaymentType.cash;
    } catch (_) {
      return HistoryPaymentType.cash;
    }
  }

  int _compareItems(HistoryItem a, HistoryItem b) {
    final int cmp;
    switch (state.sortColumn) {
      case 'receiptNo':
        cmp = a.receiptNo.compareTo(b.receiptNo);
        break;
      case 'amount':
        cmp = a.amount.compareTo(b.amount);
        break;
      case 'time':
      default:
        cmp = a.time.compareTo(b.time);
        break;
    }
    return state.sortAscending ? cmp : -cmp;
  }

  HistorySyncState _convertSyncState(int? state) {
    return switch (state) {
      0 => HistorySyncState.inProgress,
      1 => HistorySyncState.pendingSync,
      2 => HistorySyncState.beingSent,
      3 => HistorySyncState.deferred,
      4 => HistorySyncState.synced,
      _ => HistorySyncState.inProgress,
    };
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);

final hasActiveFiltersProvider = Provider<bool>((ref) {
  final state = ref.watch(historyControllerProvider);
  return state.hasActiveFilters;
});
