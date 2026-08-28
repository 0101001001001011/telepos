import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/wms/warehouse_entity.dart';
import 'package:telepos/domain/usecases/wms/manage_cells_use_case.dart';
import 'package:telepos/domain/usecases/wms/manage_warehouse_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/wms/warehouse_controller.dart';

class WarehouseManagementScreen extends ConsumerStatefulWidget {
  const WarehouseManagementScreen({super.key});

  @override
  ConsumerState<WarehouseManagementScreen> createState() =>
      _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState
    extends ConsumerState<WarehouseManagementScreen> {
  _MobileView _mobileView = _MobileView.warehouses;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(warehouseControllerProvider.notifier).loadWarehouses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final whState = ref.watch(warehouseControllerProvider);
    final layout = Breakpoints.of(context);

    if (whState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, whState.error!)),
          ),
        );
      });
    }

    if (layout.isDesktop) {
      return _buildDesktopLayout(whState);
    }
    return _buildMobileLayout(whState);
  }

  Widget _buildDesktopLayout(WarehouseState whState) {
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
              Flexible(
                child: Text(
                  l10n.wmsWarehousesAndCells,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (whState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _addWarehouse,
                icon: const Icon(TeleposIcons.add),
                label: Text(l10n.wmsAddWarehouse),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildWarehousePanel(whState)),
                const SizedBox(width: 16),
                Expanded(child: _buildZonePanel(whState)),
                const SizedBox(width: 16),
                Expanded(child: _buildCellPanel(whState)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehousePanel(WarehouseState whState) {
    final l10n = AppLocalizations.of(context)!;
    final warehouses = whState.warehouses;
    final selectedWarehouse = whState.selectedWarehouse;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.warehouse_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.wmsWarehouses,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(TeleposIcons.add, size: 20),
                  onPressed: _addWarehouse,
                  tooltip: l10n.wmsAddWarehouse,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: warehouses.isEmpty
                ? Center(
                    child: Text(
                      l10n.wmsNoWarehouses,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: warehouses.length,
                    itemBuilder: (context, index) {
                      final wh = warehouses[index];
                      final selected = selectedWarehouse?.id == wh.id;
                      return ListTile(
                        selected: selected,
                        leading: Icon(
                          wh.isDefault == true
                              ? Icons.star
                              : Icons.warehouse_outlined,
                          color: selected ? AppColors.primary : null,
                        ),
                        title: Text(wh.name ?? l10n.wmsNoName),
                        subtitle: Text(wh.code ?? ''),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) =>
                              _onWarehouseAction(action, wh),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(l10n.globalEdit),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(l10n.globalDelete),
                            ),
                          ],
                        ),
                        onTap: () {
                          ref
                              .read(warehouseControllerProvider.notifier)
                              .selectWarehouse(wh.id!);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonePanel(WarehouseState whState) {
    final l10n = AppLocalizations.of(context)!;
    final selectedWarehouse = whState.selectedWarehouse;
    final zones = whState.zones;
    final selectedZone = whState.selectedZone;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.grid_view, size: 20),
                const SizedBox(width: 8),
                Text(
                  selectedWarehouse != null
                      ? l10n.wmsZonesNamed(selectedWarehouse.name ?? '')
                      : l10n.wmsZones,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (selectedWarehouse != null)
                  IconButton(
                    icon: const Icon(TeleposIcons.add, size: 20),
                    onPressed: _addZone,
                    tooltip: l10n.wmsAddZone,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedWarehouse == null
                ? Center(
                    child: Text(
                      l10n.wmsSelectWarehouse,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : zones.isEmpty
                ? Center(
                    child: Text(
                      l10n.wmsNoZones,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: zones.length,
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      final selected = selectedZone?.id == zone.id;
                      return ListTile(
                        selected: selected,
                        leading: const Icon(Icons.grid_view),
                        title: Text(zone.name ?? l10n.wmsNoName),
                        subtitle: Text(zone.code ?? ''),
                        trailing: Text(
                          '${zone.id != null ? '' : '0'} ',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () {
                          ref
                              .read(warehouseControllerProvider.notifier)
                              .selectZone(zone.id!);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellPanel(WarehouseState whState) {
    final l10n = AppLocalizations.of(context)!;
    final selectedZone = whState.selectedZone;
    final cells = whState.cells;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.view_comfy, size: 20),
                const SizedBox(width: 8),
                Text(
                  selectedZone != null
                      ? l10n.wmsCellsNamed(selectedZone.name ?? '')
                      : l10n.wmsCells,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (selectedZone != null)
                  TextButton.icon(
                    onPressed: _generateCells,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.wmsGenerate),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedZone == null
                ? Center(
                    child: Text(
                      l10n.wmsSelectZone,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : cells.isEmpty
                ? Center(
                    child: Text(
                      l10n.wmsNoCells,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: cells.length,
                    itemBuilder: (context, index) {
                      final cell = cells[index];
                      return ListTile(
                        leading: Icon(
                          Icons.view_comfy,
                          color: cell.isBlocked == true
                              ? Theme.of(context).colorScheme.error
                              : AppColors.success,
                        ),
                        title: Text(cell.address ?? l10n.wmsNoAddress),
                        subtitle: Text(
                          '${cell.rowCode ?? ''}-${cell.rackCode ?? ''}-${cell.levelCode ?? ''}-${cell.binCode ?? ''}',
                        ),
                        trailing: cell.isBlocked == true
                            ? Chip(
                                label: Text(
                                  l10n.wmsCellBlocked,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: const Color(0xFFFFCDD2),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(WarehouseState whState) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mobileTitle(whState)),
        leading: _mobileView != _MobileView.warehouses
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _mobileGoBack,
              )
            : null,
        actions: [
          if (whState.isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(TeleposIcons.add),
            onPressed: _mobileAddAction,
          ),
        ],
      ),
      body: switch (_mobileView) {
        _MobileView.warehouses => _buildMobileWarehouseList(whState),
        _MobileView.zones => _buildMobileZoneList(whState),
        _MobileView.cells => _buildMobileCellList(whState),
      },
    );
  }

  String _mobileTitle(WarehouseState whState) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_mobileView) {
      _MobileView.warehouses => l10n.wmsWarehouses,
      _MobileView.zones => l10n.wmsZonesNamed(
        whState.selectedWarehouse?.name ?? '',
      ),
      _MobileView.cells => l10n.wmsCellsNamed(whState.selectedZone?.name ?? ''),
    };
  }

  Widget _buildMobileWarehouseList(WarehouseState whState) {
    final l10n = AppLocalizations.of(context)!;
    final warehouses = whState.warehouses;

    if (warehouses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warehouse_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.wmsNoWarehouses,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: warehouses.length,
      itemBuilder: (context, index) {
        final wh = warehouses[index];
        return ListTile(
          leading: Icon(
            wh.isDefault == true ? Icons.star : Icons.warehouse_outlined,
          ),
          title: Text(wh.name ?? l10n.wmsNoName),
          subtitle: Text(wh.address ?? wh.code ?? ''),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ref
                .read(warehouseControllerProvider.notifier)
                .selectWarehouse(wh.id!);
            setState(() {
              _mobileView = _MobileView.zones;
            });
          },
        );
      },
    );
  }

  Widget _buildMobileZoneList(WarehouseState whState) {
    final l10n = AppLocalizations.of(context)!;
    final zones = whState.zones;

    if (zones.isEmpty) {
      return Center(
        child: Text(
          l10n.wmsNoZones,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: zones.length,
      itemBuilder: (context, index) {
        final zone = zones[index];
        return ListTile(
          leading: const Icon(Icons.grid_view),
          title: Text(zone.name ?? l10n.wmsNoName),
          subtitle: Text(zone.code ?? ''),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ref.read(warehouseControllerProvider.notifier).selectZone(zone.id!);
            setState(() {
              _mobileView = _MobileView.cells;
            });
          },
        );
      },
    );
  }

  Widget _buildMobileCellList(WarehouseState whState) {
    final l10n = AppLocalizations.of(context)!;
    final cells = whState.cells;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.wmsCellsCount(cells.length),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _generateCells,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(l10n.wmsGenerate),
              ),
            ],
          ),
        ),
        Expanded(
          child: cells.isEmpty
              ? Center(
                  child: Text(
                    l10n.wmsNoCells,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: cells.length,
                  itemBuilder: (context, index) {
                    final cell = cells[index];
                    return ListTile(
                      leading: Icon(
                        Icons.view_comfy,
                        color: cell.isBlocked == true
                            ? Theme.of(context).colorScheme.error
                            : AppColors.success,
                      ),
                      title: Text(cell.address ?? l10n.wmsNoAddress),
                      subtitle: Text(cell.barcode ?? ''),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _mobileGoBack() {
    setState(() {
      if (_mobileView == _MobileView.cells) {
        _mobileView = _MobileView.zones;
      } else if (_mobileView == _MobileView.zones) {
        _mobileView = _MobileView.warehouses;
      }
    });
  }

  void _mobileAddAction() {
    switch (_mobileView) {
      case _MobileView.warehouses:
        _addWarehouse();
      case _MobileView.zones:
        _addZone();
      case _MobileView.cells:
        _generateCells();
    }
  }

  void _addWarehouse() {
    final l10n = AppLocalizations.of(context)!;
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsNewWarehouse),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(labelText: l10n.wmsWarehouseCode),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.wmsName),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
              Navigator.of(ctx).pop();
              final result = await ref
                  .read(warehouseControllerProvider.notifier)
                  .createWarehouse(
                    code: codeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                  );
              if (mounted && !result.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.errorMessage ?? l10n.wmsError)),
                );
              }
            },
            child: Text(l10n.wmsCreate),
          ),
        ],
      ),
    );
  }

  void _addZone() {
    final l10n = AppLocalizations.of(context)!;
    final whState = ref.read(warehouseControllerProvider);
    final warehouseId = whState.selectedWarehouseId;
    if (warehouseId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.wmsSelectWarehouseFirst)));
      return;
    }

    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsNewZone),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(labelText: l10n.wmsZoneCode),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.wmsName),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
              Navigator.of(ctx).pop();
              final result = await ref
                  .read(warehouseControllerProvider.notifier)
                  .createZone(
                    warehouseId: warehouseId,
                    code: codeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    type: 0,
                  );
              if (mounted && !result.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.errorMessage ?? l10n.wmsError)),
                );
              }
            },
            child: Text(l10n.wmsCreate),
          ),
        ],
      ),
    );
  }

  void _generateCells() {
    final l10n = AppLocalizations.of(context)!;
    final whState = ref.read(warehouseControllerProvider);
    final zoneId = whState.selectedZoneId;
    if (zoneId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.wmsSelectZoneFirst)));
      return;
    }

    final rowsCtrl = TextEditingController(text: '1');
    final racksCtrl = TextEditingController(text: '1');
    final levelsCtrl = TextEditingController(text: '1');
    final binsCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsGenerateCells),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rowsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.wmsRows),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: racksCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.wmsRacks),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: levelsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.wmsLevels),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: binsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.wmsBins),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final params = CellGenerationParams(
                rows: int.tryParse(rowsCtrl.text) ?? 1,
                racks: int.tryParse(racksCtrl.text) ?? 1,
                levels: int.tryParse(levelsCtrl.text) ?? 1,
                bins: int.tryParse(binsCtrl.text) ?? 1,
              );
              final result = await ref
                  .read(warehouseControllerProvider.notifier)
                  .generateCells(zoneId, params);
              if (mounted && !result.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.errorMessage ?? l10n.wmsError)),
                );
              }
            },
            child: Text(l10n.wmsGenerate),
          ),
        ],
      ),
    );
  }

  void _editWarehouse(WarehouseEntity warehouse) {
    final l10n = AppLocalizations.of(context)!;
    final codeCtrl = TextEditingController(text: warehouse.code ?? '');
    final nameCtrl = TextEditingController(text: warehouse.name ?? '');
    final addressCtrl = TextEditingController(text: warehouse.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsEditWarehouse),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(labelText: l10n.wmsWarehouseCode),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.wmsName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(labelText: l10n.wmsAddress),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
              Navigator.of(ctx).pop();
              WmsResult result;
              try {
                result = await GetIt.I<ManageWarehouseUseCase>()
                    .updateWarehouse(
                      warehouse.id!,
                      code: codeCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                    );
              } catch (e) {
                result = WmsResult.failed('error.unknown:${safeErrorText(e)}');
              }
              if (!mounted) return;
              if (result.success) {
                await ref
                    .read(warehouseControllerProvider.notifier)
                    .loadWarehouses();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.errorMessage ?? l10n.wmsError)),
                );
              }
            },
            child: Text(l10n.globalSave),
          ),
        ],
      ),
    );
  }

  void _onWarehouseAction(String action, WarehouseEntity warehouse) {
    switch (action) {
      case 'edit':
        _editWarehouse(warehouse);
      case 'delete':
        final l10n = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.wmsDeleteWarehouseTitle),
            content: Text(l10n.wmsDeleteWarehouseConfirm(warehouse.name ?? '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.globalCancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final result = await ref
                      .read(warehouseControllerProvider.notifier)
                      .deleteWarehouse(warehouse.id!);
                  if (mounted && !result.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.errorMessage ?? l10n.wmsError),
                      ),
                    );
                  }
                },
                child: Text(l10n.globalDelete),
              ),
            ],
          ),
        );
    }
  }
}

enum _MobileView { warehouses, zones, cells }
