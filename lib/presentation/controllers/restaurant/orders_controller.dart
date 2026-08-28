import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';
import 'package:telepos/domain/usecases/restaurant/get_open_orders_use_case.dart';

@immutable
class OrdersState {
  const OrdersState({
    this.orders = const [],
    this.filterType,
    this.isLoading = false,
    this.error,
  });

  final List<RestaurantOrderEntity> orders;
  final OrderType? filterType;
  final bool isLoading;
  final String? error;

  List<RestaurantOrderEntity> get filteredOrders {
    if (filterType == null) return orders;
    return orders.where((o) => o.orderType == filterType).toList();
  }

  int countByType(OrderType type) =>
      orders.where((o) => o.orderType == type).length;

  OrdersState copyWith({
    List<RestaurantOrderEntity>? orders,
    OrderType? filterType,
    bool clearFilterType = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      filterType: clearFilterType ? null : (filterType ?? this.filterType),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrdersNotifier extends Notifier<OrdersState> {
  @override
  OrdersState build() {
    Future.microtask(loadOrders);
    return const OrdersState();
  }

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await GetIt.I<GetOpenOrdersUseCase>().getAll();
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'error.load_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  void setFilterType(OrderType? type) {
    state = state.copyWith(filterType: type, clearFilterType: type == null);
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, OrdersState>(
  OrdersNotifier.new,
);
