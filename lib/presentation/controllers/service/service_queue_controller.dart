import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/domain/usecases/service/find_service_orders_use_case.dart';

@immutable
class ServiceQueueState {
  const ServiceQueueState({
    this.orders = const [],
    this.ordersNeedingApproval = const {},
    this.statusFilter,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  final List<ServiceOrderEntity> orders;
  final Set<int> ordersNeedingApproval;
  final ServiceOrderStatus? statusFilter;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  bool get hasError => error != null;
  bool get isEmpty => filteredOrders.isEmpty && !isLoading;

  List<ServiceOrderEntity> get filteredOrders {
    var result = orders.toList();

    if (statusFilter != null) {
      result = result.where((o) => o.status == statusFilter).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((o) {
        return o.orderNumber.toLowerCase().contains(q) ||
            (o.clientName?.toLowerCase().contains(q) ?? false) ||
            (o.clientPhone?.toLowerCase().contains(q) ?? false) ||
            (o.deviceDescription?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return result;
  }

  bool needsApproval(int orderId) => ordersNeedingApproval.contains(orderId);

  ServiceQueueState copyWith({
    List<ServiceOrderEntity>? orders,
    Set<int>? ordersNeedingApproval,
    ServiceOrderStatus? statusFilter,
    bool clearStatusFilter = false,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ServiceQueueState(
      orders: orders ?? this.orders,
      ordersNeedingApproval:
          ordersNeedingApproval ?? this.ordersNeedingApproval,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ServiceQueueNotifier extends Notifier<ServiceQueueState> {
  Talker get _logger => GetIt.I<Talker>();
  FindServiceOrdersUseCase get _findUseCase =>
      GetIt.I<FindServiceOrdersUseCase>();

  @override
  ServiceQueueState build() {
    Future.microtask(loadOrders);
    return const ServiceQueueState();
  }

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _findUseCase.findActive();
      final pendingIds = await GetIt.I<AppDatabase>().serviceMarkDao
          .getOrderIdsWithPendingApprovals();
      state = state.copyWith(
        orders: orders,
        ordersNeedingApproval: pendingIds,
        isLoading: false,
      );
      _logger.debug(
        'Loaded ${orders.length} active service orders, ${pendingIds.length} need approval',
      );
    } catch (e) {
      _logger.error('Failed to load service orders: $e');
      state = state.copyWith(isLoading: false, error: 'error.load_failed');
    }
  }

  Future<void> searchOrders(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.trim().isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await _findUseCase.search(query);
      state = state.copyWith(orders: results, isLoading: false);
    } catch (e) {
      _logger.error('Failed to search service orders: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void setStatusFilter(ServiceOrderStatus? status) {
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
    );
    if (status != null &&
        (status == ServiceOrderStatus.closed ||
            status == ServiceOrderStatus.cancelled)) {
      _loadByStatus(status);
    }
  }

  Future<void> _loadByStatus(ServiceOrderStatus status) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _findUseCase.findByStatus(status);
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      _logger.error('Failed to load orders by status: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    if (state.statusFilter != null &&
        (state.statusFilter == ServiceOrderStatus.closed ||
            state.statusFilter == ServiceOrderStatus.cancelled)) {
      await _loadByStatus(state.statusFilter!);
    } else {
      await loadOrders();
    }
  }
}

final serviceQueueProvider =
    NotifierProvider<ServiceQueueNotifier, ServiceQueueState>(
      ServiceQueueNotifier.new,
    );
