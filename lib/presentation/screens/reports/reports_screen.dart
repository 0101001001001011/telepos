import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/tabs/customers_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/dashboard_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/kz_reports_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/finance_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/forecasts_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/products_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/sales_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/restaurant_tab.dart';
import 'package:telepos/presentation/screens/reports/tabs/suppliers_tab.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_date_filter.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _tabs = <_TabDef>[
    _TabDef(
      icon: Icons.dashboard,
      label: 'Dashboard',
      tab: ReportTab.dashboard,
    ),
    _TabDef(icon: Icons.shopping_cart, label: 'Продажи', tab: ReportTab.sales),
    _TabDef(icon: Icons.inventory, label: 'Товары', tab: ReportTab.products),
    _TabDef(
      icon: Icons.account_balance,
      label: 'Финансы',
      tab: ReportTab.finance,
    ),
    _TabDef(icon: Icons.people, label: 'Клиенты', tab: ReportTab.customers),
    _TabDef(
      icon: Icons.local_shipping,
      label: 'Поставщики',
      tab: ReportTab.suppliers,
    ),
    _TabDef(
      icon: Icons.trending_up,
      label: 'Прогнозы',
      tab: ReportTab.forecasts,
    ),
    _TabDef(
      icon: Icons.restaurant,
      label: 'Ресторан',
      tab: ReportTab.restaurant,
    ),
    _TabDef(icon: Icons.receipt_long, label: 'Налоги/КЗ', tab: ReportTab.kz),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    if (isDesktop) {
      return _buildDesktopLayout(state);
    }
    return _buildMobileLayout(state);
  }

  Widget _buildDesktopLayout(ReportsState state) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            tabs: _tabs,
            activeTab: state.activeTab,
            onTabSelected: (tab) =>
                ref.read(reportsProvider.notifier).setTab(tab),
          ),

          Expanded(
            child: Column(
              children: [
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(color: context.semantic.canvas),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Text('Отчеты', style: AppTextStyles.h3),
                      const Spacer(),
                      Expanded(
                        flex: 2,
                        child: ReportDateFilter(
                          dateRange: state.dateRange,
                          onChanged: (range) => ref
                              .read(reportsProvider.notifier)
                              .setDateRange(range),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Обновить',
                        onPressed: () =>
                            ref.read(reportRefreshProvider.notifier).bump(),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    color: context.semantic.canvas,
                    child: _buildTabContent(state.activeTab),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ReportsState state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчеты'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: () => ref.read(reportRefreshProvider.notifier).bump(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ReportDateFilter(
              dateRange: state.dateRange,
              onChanged: (range) =>
                  ref.read(reportsProvider.notifier).setDateRange(range),
            ),
          ),

          Container(
            color: Theme.of(context).colorScheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: _tabs.map((t) {
                  final isActive = state.activeTab == t.tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _MobileTabButton(
                      icon: t.icon,
                      label: t.label,
                      isActive: isActive,
                      onTap: () =>
                          ref.read(reportsProvider.notifier).setTab(t.tab),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Divider(height: 1, color: context.semantic.canvas),

          Expanded(
            child: Container(
              color: context.semantic.canvas,
              child: _buildTabContent(state.activeTab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(ReportTab tab) {
    switch (tab) {
      case ReportTab.dashboard:
        return const DashboardTab();
      case ReportTab.sales:
        return const SalesTab();
      case ReportTab.products:
        return const ProductsTab();
      case ReportTab.finance:
        return const FinanceTab();
      case ReportTab.customers:
        return const CustomersTab();
      case ReportTab.suppliers:
        return SuppliersTab(dateRange: ref.read(reportsProvider).dateRange);
      case ReportTab.forecasts:
        return ForecastsTab(dateRange: ref.read(reportsProvider).dateRange);
      case ReportTab.restaurant:
        return const RestaurantTab();
      case ReportTab.kz:
        return const KzReportsTab();
    }
  }
}

class _TabDef {
  const _TabDef({required this.icon, required this.label, required this.tab});
  final IconData icon;
  final String label;
  final ReportTab tab;
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.tabs,
    required this.activeTab,
    required this.onTabSelected,
  });

  final List<_TabDef> tabs;
  final ReportTab activeTab;
  final ValueChanged<ReportTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Аналитика',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF334155), height: 1),

          const SizedBox(height: 8),

          ...tabs.map((t) {
            final isActive = t.tab == activeTab;
            return _SidebarItem(
              icon: t.icon,
              label: t.label,
              isActive: isActive,
              onTap: () => onTabSelected(t.tab),
            );
          }),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'TelePOS v1.6.0',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileTabButton extends StatelessWidget {
  const _MobileTabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
