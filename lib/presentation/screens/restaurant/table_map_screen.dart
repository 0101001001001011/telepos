import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_table_entity.dart';
import 'package:telepos/domain/usecases/restaurant/create_table_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/get_open_orders_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/controllers/restaurant/table_map_controller.dart';

class TableMapScreen extends ConsumerStatefulWidget {
  const TableMapScreen({super.key});

  @override
  ConsumerState<TableMapScreen> createState() => _TableMapScreenState();
}

class _TableMapScreenState extends ConsumerState<TableMapScreen>
    with TickerProviderStateMixin {
  Timer? _refreshTimer;
  late AnimationController _pulseController;
  late AnimationController _staggerController;
  late Animation<double> _pulseAnimation;

  final Set<int> _animatedTableIds = {};

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tableMapProvider);
    final layoutType = Breakpoints.of(context);

    ref.listen<TableMapState>(tableMapProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    if (state.isLoading && state.tables.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (state.tables.isEmpty) {
      return _buildEmptyState(l10n);
    }

    final crossAxisCount = switch (layoutType) {
      LayoutType.desktop => 5,
      LayoutType.tablet => 4,
      LayoutType.mobile => 2,
    };

    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          _buildHeaderBar(state, l10n),

          _buildZoneFilterTabs(state, l10n),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(tableMapProvider.notifier).refreshTables(),
              color: AppColors.primary,
              backgroundColor: const Color(0xFF16213E),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1 / 1.1,
                ),
                itemCount: state.filteredTables.length,
                itemBuilder: (context, index) {
                  final table = state.filteredTables[index];
                  return _buildAnimatedTableCard(table, index, l10n);
                },
              ),
            ),
          ),

          _buildBottomActionBar(l10n),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(TableMapState state, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            state.filterZone ?? l10n.restaurantAllZones,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),

          const Spacer(),

          _buildStatusLegend(state, l10n),
        ],
      ),
    );
  }

  Widget _buildStatusLegend(TableMapState state, AppLocalizations l10n) {
    final items = [
      (
        l10n.restaurantTableFree,
        state.countByStatus(TableStatus.free),
        const Color(0xFF43A047),
        false,
      ),
      (
        l10n.restaurantTableOccupied,
        state.countByStatus(TableStatus.occupied),
        const Color(0xFFE53935),
        true,
      ),
      (
        l10n.restaurantTableReserved,
        state.countByStatus(TableStatus.reserved),
        const Color(0xFFF57C00),
        false,
      ),
      (
        l10n.restaurantTableDirty,
        state.countByStatus(TableStatus.dirty),
        const Color(0xFF616161),
        false,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.$4)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.$3.withValues(
                            alpha: _pulseAnimation.value,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: item.$3.withValues(
                                alpha: _pulseAnimation.value * 0.5,
                              ),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  '${item.$1} ${item.$2}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildZoneFilterTabs(TableMapState state, AppLocalizations l10n) {
    final zones = state.zones;

    final allTabs = <(String, String?)>[
      (l10n.restaurantAllZones, null),
      ...zones.map((z) => (z, z)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1A1A2E),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: allTabs.map((tab) {
            final isSelected = state.filterZone == tab.$2;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => ref
                        .read(tableMapProvider.notifier)
                        .setFilterZone(
                          state.filterZone == tab.$2 ? null : tab.$2,
                        ),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tab.$1,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAnimatedTableCard(
    RestaurantTableEntity table,
    int index,
    AppLocalizations l10n,
  ) {
    final isNew = !_animatedTableIds.contains(table.id);
    if (isNew) {
      _animatedTableIds.add(table.id);
    }

    final delay = math.min(index * 0.06, 0.6);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: isNew ? 0.0 : 1.0, end: 1.0),
      duration: Duration(milliseconds: isNew ? 500 : 0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final staggeredValue = (value - delay).clamp(0.0, 1.0);
        final adjustedValue = isNew
            ? Curves.easeOutCubic.transform(staggeredValue.clamp(0.0, 1.0))
            : 1.0;

        return Opacity(
          opacity: adjustedValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - adjustedValue)),
            child: child,
          ),
        );
      },
      child: _TableCard(
        table: table,
        pulseAnimation: _pulseAnimation,
        onTap: () => context.go('/tables/${table.id}'),
        onLongPress: () => _showQuickActions(table, l10n),
      ),
    );
  }

  Widget _buildBottomActionBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _createTakeoutOrDelivery(l10n, OrderType.takeout),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                  label: Text(
                    l10n.restaurantNewTakeout,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A3D62),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _createTakeoutOrDelivery(l10n, OrderType.delivery),
                  icon: const Icon(Icons.two_wheeler, size: 22),
                  label: Text(
                    l10n.restaurantNewDelivery,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A3D62),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTakeoutOrDelivery(
    AppLocalizations l10n,
    OrderType type,
  ) async {
    final partySizeCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          type == OrderType.takeout
              ? l10n.restaurantOrderTakeout
              : l10n.restaurantOrderDelivery,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: partySizeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.restaurantPartySize,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: l10n.restaurantNote,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.restaurantOpenOrder),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final partySize = int.tryParse(partySizeCtrl.text)?.clamp(1, 50) ?? 1;
      final note = noteCtrl.text.trim();
      final order = await GetIt.I<CreateTableOrderUseCase>().create(
        tableId: null,
        partySize: partySize,
        orderType: type,
        note: note.isNotEmpty ? note : null,
      );
      if (!mounted) return;
      context.go('/orders/${order.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 72,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.restaurantNoTables,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.restaurantNoTablesHint,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: Text(l10n.restaurantGoToSettings),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.go(AppRoutes.restaurantSettings),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions(RestaurantTableEntity table, AppLocalizations l10n) {
    if (table.isFree) {
      context.go('/tables/${table.id}');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16213E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: _getStatusGradient(table.status),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          table.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.restaurantQuickActions,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            table.name,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                color: Color(0xFF2A2A4A),
                height: 1,
                indent: 20,
                endIndent: 20,
              ),

              if (table.isOccupied) ...[
                _buildQuickActionTile(
                  ctx,
                  icon: Icons.payment_rounded,
                  color: AppColors.primary,
                  title: l10n.restaurantGoToPayment,
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/tables/${table.id}');
                  },
                ),
                _buildQuickActionTile(
                  ctx,
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.info,
                  title: l10n.restaurantTransfer,
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/tables/${table.id}');
                  },
                ),
                _buildQuickActionTile(
                  ctx,
                  icon: Icons.cleaning_services_rounded,
                  color: const Color(0xFF616161),
                  title: l10n.restaurantSetDirty,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(tableMapProvider.notifier)
                        .setTableStatus(table.id, TableStatus.dirty);
                  },
                ),
              ],
              if (table.isDirty)
                _buildQuickActionTile(
                  ctx,
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF43A047),
                  title: l10n.restaurantSetFree,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(tableMapProvider.notifier)
                        .setTableStatus(table.id, TableStatus.free);
                  },
                ),
              if (table.isReserved)
                _buildQuickActionTile(
                  ctx,
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF43A047),
                  title: l10n.restaurantSetFree,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(tableMapProvider.notifier)
                        .setTableStatus(table.id, TableStatus.free);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _getStatusGradient(TableStatus status) {
    return switch (status) {
      TableStatus.free => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
      ),
      TableStatus.occupied => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC62828), Color(0xFFE53935)],
      ),
      TableStatus.reserved => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE65100), Color(0xFFF57C00)],
      ),
      TableStatus.dirty => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF424242), Color(0xFF616161)],
      ),
    };
  }
}

class _TableCard extends StatefulWidget {
  const _TableCard({
    required this.table,
    required this.pulseAnimation,
    required this.onTap,
    required this.onLongPress,
  });

  final RestaurantTableEntity table;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  double _scale = 1.0;

  int? _openTimeSeconds;

  RestaurantTableEntity get table => widget.table;

  @override
  void initState() {
    super.initState();
    _loadOpenTime();
  }

  @override
  void didUpdateWidget(covariant _TableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table.id != widget.table.id ||
        oldWidget.table.status != widget.table.status) {
      _openTimeSeconds = null;
      _loadOpenTime();
    }
  }

  Future<void> _loadOpenTime() async {
    if (!table.isOccupied) return;
    try {
      final order = await GetIt.I<GetOpenOrdersUseCase>().getByTable(table.id);
      if (!mounted) return;
      setState(() => _openTimeSeconds = order?.openTime);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getStatusGradient(table.status);

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      onLongPress: () {
        setState(() => _scale = 1.0);
        widget.onLongPress();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Hero(
          tag: 'table_${table.id}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
                const BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: _SubtlePatternPainter(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        table.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${table.capacity}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      if (table.isOccupied && _openTimeSeconds != null) ...[
                        const SizedBox(height: 10),
                        AnimatedBuilder(
                          animation: widget.pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: widget.pulseAnimation.value,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatElapsedTime(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      if (table.zone != null && !table.isOccupied) ...[
                        const SizedBox(height: 8),
                        Text(
                          table.zone!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                if (table.isOccupied)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: AnimatedBuilder(
                      animation: widget.pulseAnimation,
                      builder: (context, _) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: widget.pulseAnimation.value,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(
                                  alpha: widget.pulseAnimation.value * 0.4,
                                ),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                if (table.isReserved)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.event_seat_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),

                if (table.isDirty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.cleaning_services_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatElapsedTime() {
    final openSeconds = _openTimeSeconds;
    if (openSeconds == null) return '';
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var minutes = ((nowSeconds - openSeconds) / 60).round();
    if (minutes < 0) minutes = 0;
    if (minutes < 60) {
      return '$minutes \u043C\u0438\u043D';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '$hours\u0447 $mins\u043C';
  }

  LinearGradient _getStatusGradient(TableStatus status) {
    return switch (status) {
      TableStatus.free => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
      ),
      TableStatus.occupied => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC62828), Color(0xFFE53935)],
      ),
      TableStatus.reserved => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE65100), Color(0xFFF57C00)],
      ),
      TableStatus.dirty => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF424242), Color(0xFF616161)],
      ),
    };
  }
}

class _SubtlePatternPainter extends CustomPainter {
  _SubtlePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    final maxDimension = size.width + size.height;

    for (double i = 0; i < maxDimension; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), paint);
    }
  }

  @override
  bool shouldRepaint(_SubtlePatternPainter oldDelegate) =>
      color != oldDelegate.color;
}
