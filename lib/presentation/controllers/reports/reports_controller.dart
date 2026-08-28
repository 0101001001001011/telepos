import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReportTab {
  dashboard,
  sales,
  products,
  finance,
  customers,
  suppliers,
  forecasts,
  restaurant,
  kz,
}

@immutable
class ReportsState {
  const ReportsState({
    required this.dateRange,
    this.activeTab = ReportTab.dashboard,
  });

  final DateTimeRange dateRange;

  final ReportTab activeTab;

  ReportsState copyWith({DateTimeRange? dateRange, ReportTab? activeTab}) =>
      ReportsState(
        dateRange: dateRange ?? this.dateRange,
        activeTab: activeTab ?? this.activeTab,
      );
}

class ReportsNotifier extends Notifier<ReportsState> {
  @override
  ReportsState build() {
    final now = DateTime.now();
    return ReportsState(
      dateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
    );
  }

  void setDateRange(DateTimeRange range) =>
      state = state.copyWith(dateRange: range);

  void setTab(ReportTab tab) => state = state.copyWith(activeTab: tab);
}

final reportsProvider = NotifierProvider<ReportsNotifier, ReportsState>(
  ReportsNotifier.new,
);

final reportRefreshProvider = NotifierProvider<ReportRefreshNotifier, int>(
  ReportRefreshNotifier.new,
);

class ReportRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
