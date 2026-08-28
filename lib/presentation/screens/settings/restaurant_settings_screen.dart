import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

class RestaurantSettingsScreen extends ConsumerStatefulWidget {
  const RestaurantSettingsScreen({super.key});

  @override
  ConsumerState<RestaurantSettingsScreen> createState() =>
      _RestaurantSettingsScreenState();
}

class _RestaurantSettingsScreenState
    extends ConsumerState<RestaurantSettingsScreen> {
  bool _isLoading = true;
  OperatingMode _operatingMode = OperatingMode.retail;
  bool _serviceChargeEnabled = false;
  final _serviceChargeController = TextEditingController();
  List<String> _zones = [];
  List<RestaurantTable> _tables = [];
  final _newZoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serviceChargeController.dispose();
    _newZoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final pos = await db.thisPosDao.get();
      final persistedZones = await db.restaurantZoneDao.getNames();
      final tableZones = await db.restaurantTableDao.getZones();
      final tables = await db.restaurantTableDao.getActive();

      final mergedZones = <String>[...persistedZones];
      for (final z in tableZones) {
        if (!mergedZones.contains(z)) mergedZones.add(z);
      }

      setState(() {
        if (pos != null) {
          _operatingMode = OperatingMode.values[pos.operatingMode];
          _serviceChargeEnabled = pos.serviceChargeEnabled;
          if (pos.defaultServiceChargePercent != null) {
            _serviceChargeController.text = pos.defaultServiceChargePercent
                .toString();
          }
        }
        _zones = mergedZones;
        _tables = tables;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[RestaurantSettings] Failed to load settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final db = GetIt.I<AppDatabase>();

      Decimal? servicePercent;
      if (_serviceChargeController.text.trim().isNotEmpty) {
        servicePercent = Decimal.tryParse(_serviceChargeController.text.trim());
      }

      await db.thisPosDao.upsert(
        ThisPosEntriesCompanion(
          operatingMode: Value(_operatingMode.index),
          serviceChargeEnabled: Value(_serviceChargeEnabled),
          defaultServiceChargePercent: Value(servicePercent),
        ),
      );

      await db.restaurantZoneDao.replaceAll(_zones);

      ref.read(appStateProvider.notifier).setOperatingMode(_operatingMode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.restaurantSaved),
            backgroundColor: AppColors.success,
          ),
        );

        final defaultRoute = NavDestinations.defaultRoute(_operatingMode);
        context.go(defaultRoute);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _addZone(String zoneName) {
    final trimmed = zoneName.trim();
    if (trimmed.isEmpty) return;
    if (_zones.contains(trimmed)) return;
    setState(() {
      _zones = [..._zones, trimmed];
    });
    _newZoneController.clear();
  }

  Future<void> _addTable() async {
    final result = await _showTableEditDialog(null);
    if (result == true) await _loadSettings();
  }

  Future<void> _editTable(RestaurantTable table) async {
    final result = await _showTableEditDialog(table);
    if (result == true) await _loadSettings();
  }

  Future<void> _deactivateTable(RestaurantTable table) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restaurantTableDeactivate),
        content: Text(l10n.restaurantTableDeactivateConfirm(table.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.globalCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.globalConfirm,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await GetIt.I<AppDatabase>().restaurantTableDao.deactivate(table.id);
      await _loadSettings();
    }
  }

  Future<bool?> _showTableEditDialog(RestaurantTable? table) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: table?.name ?? '');
    final capacityCtrl = TextEditingController(
      text: (table?.capacity ?? 4).toString(),
    );
    final sortCtrl = TextEditingController(
      text: (table?.sortOrder ?? 0).toString(),
    );
    String? selectedZone =
        table?.zone ?? (_zones.isNotEmpty ? _zones.first : null);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            table == null ? l10n.restaurantTableAdd : l10n.restaurantTableEdit,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.restaurantTableName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.restaurantTableCapacity,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedZone,
                  decoration: InputDecoration(
                    labelText: l10n.restaurantTableZone,
                    border: const OutlineInputBorder(),
                  ),
                  items: _zones
                      .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedZone = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.restaurantTableSortOrder,
                    border: const OutlineInputBorder(),
                  ),
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
              onPressed: () async {
                final db = GetIt.I<AppDatabase>();
                final name = nameCtrl.text.trim();
                final capacity = int.tryParse(capacityCtrl.text) ?? 4;
                final sortOrder = int.tryParse(sortCtrl.text) ?? 0;

                if (name.isEmpty) return;

                if (table == null) {
                  await db.restaurantTableDao.insert(
                    RestaurantTablesCompanion(
                      name: Value(name),
                      capacity: Value(capacity.clamp(1, 50)),
                      zone: Value(selectedZone),
                      sortOrder: Value(sortOrder),
                    ),
                  );
                } else {
                  await db.restaurantTableDao.updateTable(
                    RestaurantTable(
                      id: table.id,
                      name: name,
                      capacity: capacity.clamp(1, 50),
                      status: table.status,
                      zone: selectedZone,
                      positionX: table.positionX,
                      positionY: table.positionY,
                      isActive: true,
                      sortOrder: sortOrder,
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(l10n.globalSave),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);
    final isDesktop = layoutType == LayoutType.desktop;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.restaurantSettings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(TeleposIcons.save, color: Colors.white),
            label: Text(
              l10n.globalSave,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        title: l10n.restaurantOperatingMode,
                        icon: Icons.storefront,
                        child: _buildOperatingModeSelector(l10n),
                      ),
                      const SizedBox(height: 24),

                      _buildSection(
                        title: l10n.restaurantZoneManagement,
                        icon: Icons.layers,
                        child: _buildZoneManagement(l10n),
                      ),
                      const SizedBox(height: 24),

                      _buildSection(
                        title: l10n.restaurantTableManagement,
                        icon: Icons.table_restaurant,
                        child: _buildTableManagement(l10n),
                      ),
                      const SizedBox(height: 24),

                      if (_operatingMode == OperatingMode.restaurant)
                        _buildSection(
                          title: l10n.restaurantServiceCharge,
                          icon: Icons.percent,
                          child: _buildServiceCharge(l10n),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildOperatingModeSelector(AppLocalizations l10n) {
    final modes = [
      (
        OperatingMode.retail,
        l10n.restaurantModeRetail,
        l10n.restaurantModeRetailDesc,
        Icons.shopping_cart,
      ),
      (
        OperatingMode.restaurant,
        l10n.restaurantModeRestaurant,
        l10n.restaurantModeRestaurantDesc,
        Icons.restaurant,
      ),
      (
        OperatingMode.service,
        l10n.restaurantModeService,
        l10n.restaurantModeServiceDesc,
        Icons.build,
      ),
    ];

    return Column(
      children: modes.map((m) {
        final isSelected = _operatingMode == m.$1;
        return InkWell(
          onTap: () => setState(() => _operatingMode = m.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Icon(
                  m.$4,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        m.$3,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildZoneManagement(AppLocalizations l10n) {
    final presets = [
      l10n.restaurantZoneHall,
      l10n.restaurantZoneTerrace,
      l10n.restaurantZoneVip,
      l10n.restaurantZoneBar,
      l10n.restaurantZoneBooth,
      l10n.restaurantZoneKaraoke,
      l10n.restaurantZoneVeranda,
      l10n.restaurantZonePrivate,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_zones.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _zones.map((zone) {
              final count = _tables.where((t) => t.zone == zone).length;
              return Chip(
                label: Text('$zone ($count)'),
                backgroundColor: selectedSurfaceOf(context),
                side: const BorderSide(color: AppColors.primary, width: 0.5),
              );
            }).toList(),
          ),
        if (_zones.isNotEmpty) const SizedBox(height: 16),

        Text(
          l10n.restaurantZonePresets,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets
              .where((p) => !_zones.contains(p))
              .map(
                (preset) => ActionChip(
                  label: Text(preset),
                  onPressed: () => _addZone(preset),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newZoneController,
                decoration: InputDecoration(
                  hintText: l10n.restaurantZoneAdd,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(TeleposIcons.add),
              onPressed: () => _addZone(_newZoneController.text),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableManagement(AppLocalizations l10n) {
    final grouped = <String?, List<RestaurantTable>>{};
    for (final t in _tables) {
      grouped.putIfAbsent(t.zone, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tables.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                l10n.restaurantNoTables,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

        ...grouped.entries.map((entry) {
          final zone = entry.key ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (zone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    zone,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ...entry.value.map((table) => _buildTableRow(table)),
              const Divider(height: 1),
            ],
          );
        }),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(TeleposIcons.add),
            label: Text(l10n.restaurantTableAdd),
            onPressed: _addTable,
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(RestaurantTable table) {
    final statusColor = switch (table.status) {
      0 => AppColors.success,
      1 => Theme.of(context).colorScheme.error,
      2 => AppColors.warning,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };

    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
      ),
      title: Text(
        table.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${table.zone ?? ""} · ${l10n.restaurantTableSeats(table.capacity)}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _editTable(table),
          ),
          IconButton(
            icon: Icon(
              TeleposIcons.delete,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _deactivateTable(table),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCharge(AppLocalizations l10n) {
    return Column(
      children: [
        SwitchListTile(
          value: _serviceChargeEnabled,
          onChanged: (value) => setState(() => _serviceChargeEnabled = value),
          title: Text(l10n.restaurantServiceChargeEnabled),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
        ),
        if (_serviceChargeEnabled) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _serviceChargeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.restaurantServiceChargePercent,
              suffixText: '%',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
