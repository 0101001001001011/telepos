import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/screens/shift/widgets/bills_tab.dart';
import 'package:telepos/presentation/screens/shift/widgets/cash_operations_tab.dart';
import 'package:telepos/presentation/screens/shift/widgets/shift_actions.dart';
import 'package:telepos/presentation/screens/shift/widgets/shift_info_panel.dart';
import 'package:telepos/presentation/screens/shift/widgets/total_tab.dart';
import 'package:telepos/core/locale/till_conventions.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref
          .read(shiftControllerProvider.notifier)
          .selectTab(_tabController.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shiftControllerProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (_tabController.index != state.selectedTab) {
      _tabController.animateTo(state.selectedTab);
    }

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (screenWidth >= 900) {
      return _DesktopLayout(state: state, tabController: _tabController);
    } else if (screenWidth >= 600) {
      return _TabletLayout(state: state, tabController: _tabController);
    } else {
      return _MobileLayout(state: state);
    }
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({required this.state, required this.tabController});

  final ShiftState state;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildTabBar(context),

                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: const [
                      BillsTab(),
                      TotalTab(),
                      CashOperationsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          SizedBox(
            width: 320,
            child: Column(
              children: [
                Expanded(child: ShiftInfoPanel(state: state)),
                const Divider(height: 1),
                ShiftActions(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        controller: tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        indicatorColor: AppColors.primary,
        tabs: [
          Tab(
            icon: const Icon(Icons.payments_outlined),
            text: l10n.shiftBillsTab,
          ),
          Tab(
            icon: const Icon(Icons.calculate_outlined),
            text: l10n.shiftTotalTab,
          ),
          Tab(
            icon: const Icon(Icons.receipt_long_outlined),
            text: l10n.shiftOperationsTab,
          ),
        ],
      ),
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({required this.state, required this.tabController});

  final ShiftState state;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: l10n.shiftBillsTab),
                Tab(text: l10n.shiftAmountTab),
                Tab(text: l10n.shiftOperationsTab),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: tabController,
              children: const [BillsTab(), TotalTab(), CashOperationsTab()],
            ),
          ),

          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCompactInfo(context),
                const SizedBox(height: 12),
                ShiftActions(state: state, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              state.isOpen ? Icons.lock_open : Icons.lock,
              color: state.isOpen
                  ? AppColors.success
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              state.isOpen ? l10n.shiftOpened : l10n.shiftClosed,
              style: AppTextStyles.body,
            ),
          ],
        ),

        if (state.isOpen) _buildDifference(context),
      ],
    );
  }

  Widget _buildDifference(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diff = state.difference;
    final isPositive = diff > Decimal.zero;
    final isNegative = diff < Decimal.zero;

    return Row(
      children: [
        Text(l10n.shiftDifferenceLabel, style: AppTextStyles.body),
        Text(
          '${isPositive ? '+' : ''}${diff.toStringAsFixed(2)}',
          style: AppTextStyles.body.copyWith(
            color: isNegative
                ? Theme.of(context).colorScheme.error
                : isPositive
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.state});

  final ShiftState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // Шапка ничего не переопределяет: `appBarTheme` задаёт и поверхность, и
      // цвет содержимого, и нулевую высоту тени — сразу в обеих темах. Пока
      // `foregroundColor` стоял константой, подпись в тёмной оставалась
      // тёмной на тёмном.
      appBar: AppBar(
        title: Text(
          state.isOpen ? l10n.shiftClosingShift : l10n.shiftOpeningShift,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(context),
            const SizedBox(height: 16),

            if (state.isOpen) ...[
              _buildSectionCard(
                context,
                title: l10n.shiftBillCount,
                icon: Icons.payments_outlined,
                child: const BillsTab(compact: true),
              ),
              const SizedBox(height: 16),

              _buildSectionCard(
                context,
                title: l10n.shiftManualEntry,
                icon: Icons.calculate_outlined,
                child: const TotalTab(compact: true),
              ),
              const SizedBox(height: 16),

              _buildSectionCard(
                context,
                title: l10n.shiftCashOperations,
                icon: Icons.receipt_long_outlined,
                child: const CashOperationsTab(compact: true),
              ),
              const SizedBox(height: 16),
            ],

            ShiftActions(state: state, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: state.isOpen
                        ? AppColors.success.withValues(alpha: 0.1)
                        : context.semantic.canvas,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    state.isOpen ? Icons.lock_open : Icons.lock,
                    color: state.isOpen
                        ? AppColors.success
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isOpen ? l10n.shiftOpened : l10n.shiftClosed,
                        style: AppTextStyles.h3,
                      ),
                      if (state.isOpen && state.openTime != null)
                        Text(
                          l10n.shiftSince(_formatTime(state.openTime!)),
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (state.cashierName != null)
                        Text(
                          state.cashierName!,
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: l10n.shiftHistoryTitle,
                  onPressed: () => context.push(AppRoutes.shiftHistory),
                ),
              ],
            ),
            if (state.isOpen) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoItem(context, l10n.shiftSystem, state.expectedCash),
                  _buildInfoItem(
                    context,
                    l10n.shiftEntered,
                    state.enteredTotal,
                  ),
                  _buildDifferenceItem(context, state.difference),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, Decimal value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value.toStringAsFixed(2), style: AppTextStyles.h3),
      ],
    );
  }

  Widget _buildDifferenceItem(BuildContext context, Decimal value) {
    final l10n = AppLocalizations.of(context)!;
    final isPositive = value > Decimal.zero;
    final isNegative = value < Decimal.zero;

    return Column(
      children: [
        Text(
          l10n.shiftDifference,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${isPositive ? '+' : ''}${value.toStringAsFixed(2)}',
          style: AppTextStyles.h3.copyWith(
            color: isNegative
                ? Theme.of(context).colorScheme.error
                : isPositive
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.body),
        initiallyExpanded: false,
        children: [Padding(padding: const EdgeInsets.all(16), child: child)],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return TillConventions.current.formatDateTime(time);
  }
}
