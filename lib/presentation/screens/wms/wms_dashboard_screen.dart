import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/wms/claim_controller.dart';
import 'package:telepos/presentation/controllers/wms/warehouse_controller.dart';
import 'package:telepos/presentation/controllers/wms/wms_config_controller.dart';

class WmsDashboardScreen extends ConsumerStatefulWidget {
  const WmsDashboardScreen({super.key});

  @override
  ConsumerState<WmsDashboardScreen> createState() => _WmsDashboardScreenState();
}

class _WmsDashboardScreenState extends ConsumerState<WmsDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wmsConfigControllerProvider.notifier).loadConfig();
      ref.read(warehouseControllerProvider.notifier).loadWarehouses();
      ref.read(claimControllerProvider.notifier).loadAllClaims();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final configState = ref.watch(wmsConfigControllerProvider);
    final layout = Breakpoints.of(context);
    final crossAxisCount = switch (layout) {
      LayoutType.mobile => 2,
      LayoutType.tablet => 3,
      LayoutType.desktop => 4,
    };

    if (configState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, configState.error!)),
          ),
        );
      });
    }

    if (configState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final config = configState.config;
    final cellStorageEnabled = config?.enableCells ?? true;
    final batchTrackingEnabled = config?.enableBatches ?? true;
    final serialTrackingEnabled = config?.enableSerials ?? true;
    final markingEnabled = config?.enableMarkingCodes ?? true;

    final warehouseCount = ref
        .watch(warehouseControllerProvider)
        .warehouses
        .length;
    final claimCount = ref.watch(claimControllerProvider).claims.length;

    final modules = _buildModuleList(
      l10n: l10n,
      cellStorageEnabled: cellStorageEnabled,
      batchTrackingEnabled: batchTrackingEnabled,
      serialTrackingEnabled: serialTrackingEnabled,
      markingEnabled: markingEnabled,
      warehouseCount: warehouseCount,
      claimCount: claimCount,
    );

    if (layout.isDesktop) {
      return _buildDesktopLayout(modules, crossAxisCount);
    }
    return _buildMobileLayout(modules, crossAxisCount);
  }

  Widget _buildMobileLayout(List<_WmsModule> modules, int crossAxisCount) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wmsDashboardTitleShort),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openWmsSettings,
            tooltip: l10n.wmsSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) => _buildModuleCard(modules[index]),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(List<_WmsModule> modules, int crossAxisCount) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warehouse, size: 28),
              const SizedBox(width: 12),
              Text(
                l10n.wmsDashboardTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _openWmsSettings,
                icon: const Icon(Icons.settings),
                label: Text(l10n.wmsSettings),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) => _buildModuleCard(modules[index]),
          ),
        ],
      ),
    );
  }

  List<_WmsModule> _buildModuleList({
    required AppLocalizations l10n,
    required bool cellStorageEnabled,
    required bool batchTrackingEnabled,
    required bool serialTrackingEnabled,
    required bool markingEnabled,
    required int warehouseCount,
    required int claimCount,
  }) {
    final modules = <_WmsModule>[];

    if (cellStorageEnabled) {
      modules.add(
        _WmsModule(
          title: l10n.wmsModuleWarehouses,
          subtitle: l10n.wmsModuleWarehousesSubtitle,
          icon: Icons.warehouse_outlined,
          color: Colors.blue,
          count: '$warehouseCount',
          onTap: () => context.go(AppRoutes.wmsWarehouses),
        ),
      );
    }

    if (batchTrackingEnabled) {
      modules.add(
        _WmsModule(
          title: l10n.wmsModuleBatches,
          subtitle: l10n.wmsModuleBatchesSubtitle,
          icon: Icons.inventory_2_outlined,
          color: Colors.orange,
          count: null,
          onTap: () => context.go(AppRoutes.wmsBatches),
        ),
      );
    }

    if (cellStorageEnabled) {
      modules.add(
        _WmsModule(
          title: l10n.wmsModuleCellStock,
          subtitle: l10n.wmsModuleCellStockSubtitle,
          icon: Icons.inventory,
          color: Colors.indigo,
          count: null,
          onTap: () => context.go(AppRoutes.wmsCellStock),
        ),
      );
    }

    if (serialTrackingEnabled) {
      modules.add(
        _WmsModule(
          title: l10n.wmsModuleSerials,
          subtitle: l10n.wmsModuleSerialsSubtitle,
          icon: Icons.qr_code_2,
          color: Colors.teal,
          count: null,
          onTap: () => context.go(AppRoutes.wmsSerials),
        ),
      );
    }

    if (markingEnabled) {
      modules.add(
        _WmsModule(
          title: l10n.wmsModuleMarking,
          subtitle: l10n.wmsModuleMarkingSubtitle,
          icon: Icons.verified_outlined,
          color: Colors.purple,
          count: null,
          onTap: () => context.go(AppRoutes.wmsMarking),
        ),
      );
    }

    modules.add(
      _WmsModule(
        title: l10n.wmsModuleClaims,
        subtitle: l10n.wmsModuleClaimsSubtitle,
        icon: Icons.report_problem_outlined,
        color: Colors.red,
        count: '$claimCount',
        onTap: () => context.go(AppRoutes.wmsClaims),
      ),
    );

    modules.add(
      _WmsModule(
        title: l10n.wmsSettings,
        subtitle: l10n.wmsSettingsSubtitle,
        icon: Icons.tune,
        color: Colors.grey,
        count: null,
        onTap: _openWmsSettings,
      ),
    );

    return modules;
  }

  Widget _buildModuleCard(_WmsModule module) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: module.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(module.icon, size: 36, color: module.color),
              const SizedBox(height: 8),
              Text(
                module.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                module.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (module.count != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: module.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    module.count!,
                    style: TextStyle(
                      color: module.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openWmsSettings() {
    context.go(AppRoutes.wmsSettings);
  }
}

class _WmsModule {
  const _WmsModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? count;
  final VoidCallback onTap;
}
