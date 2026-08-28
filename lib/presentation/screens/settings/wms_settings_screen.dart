import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/entities/wms/wms_config_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/controllers/wms/wms_config_controller.dart';

class WmsSettingsScreen extends ConsumerStatefulWidget {
  const WmsSettingsScreen({super.key});

  @override
  ConsumerState<WmsSettingsScreen> createState() => _WmsSettingsScreenState();
}

class _WmsSettingsScreenState extends ConsumerState<WmsSettingsScreen> {
  bool _cellStorageEnabled = false;
  bool _batchTrackingEnabled = false;
  bool _serialTrackingEnabled = false;
  bool _expiryControlEnabled = false;
  bool _markingEnabled = false;
  bool _warrantyTrackingEnabled = false;

  String _pickingStrategy = 'FEFO';
  String _costMethod = 'FIFO';
  int _expiryWarningDays = 30;

  double _abcA = 80;
  double _abcB = 15;

  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  Future<void> _loadConfig() async {
    final configState = ref.read(wmsConfigControllerProvider);
    if (configState.config != null) {
      _applyConfig(configState);
      return;
    }
    await ref.read(wmsConfigControllerProvider.notifier).loadConfig();
    final updated = ref.read(wmsConfigControllerProvider);
    _applyConfig(updated);
  }

  void _applyConfig(WmsConfigState configState) {
    final config = configState.config;
    if (config == null) return;
    setState(() {
      _cellStorageEnabled = config.enableCells ?? false;
      _batchTrackingEnabled = config.enableBatches ?? false;
      _serialTrackingEnabled = config.enableSerials ?? false;
      _expiryControlEnabled = config.enableFefo ?? false;
      _markingEnabled = config.enableMarkingCodes ?? false;
      _warrantyTrackingEnabled = config.enableWarranty ?? false;
      const pickingStrategies = {'FEFO', 'FIFO', 'LIFO'};
      final savedPicking = config.pickingStrategy?.toUpperCase();
      if (savedPicking != null && pickingStrategies.contains(savedPicking)) {
        _pickingStrategy = savedPicking;
      } else {
        _pickingStrategy = config.enableFefo == true
            ? 'FEFO'
            : (config.enableFifo == true ? 'FIFO' : 'FEFO');
      }

      const costMethods = {'FIFO', 'LIFO', 'AVG'};
      if (config.costMethod != null &&
          costMethods.contains(config.costMethod)) {
        _costMethod = config.costMethod!;
      }

      if (config.expiryWarningDays != null) {
        _expiryWarningDays = config.expiryWarningDays!.clamp(1, 90).toInt();
      }
      if (config.lowStockThreshold != null) {
        _abcA = config.lowStockThreshold!
            .toDouble()
            .clamp(0.0, 100.0)
            .toDouble();
      }
      if (config.overStockThreshold != null) {
        _abcB = config.overStockThreshold!
            .toDouble()
            .clamp(0.0, 100.0)
            .toDouble();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = Breakpoints.of(context);

    if (layout.isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setWmsTitle),
        actions: [
          if (_isDirty)
            TextButton(
              onPressed: _save,
              child: Text(
                l10n.globalSave,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          _buildModulesSection(),
          _buildPickingStrategySection(),
          _buildCostMethodSection(),
          _buildExpirySection(),
          _buildAbcSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 28),
              const SizedBox(width: 12),
              Text(
                l10n.setWmsTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isDirty)
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(TeleposIcons.save),
                  label: Text(l10n.globalSave),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [_buildModulesSection(), _buildExpirySection()],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildPickingStrategySection(),
                    _buildCostMethodSection(),
                    _buildAbcSection(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModulesSection() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.setWmsModules,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.setWmsCellStorage),
            subtitle: Text(l10n.setWmsCellStorageDesc),
            value: _cellStorageEnabled,
            onChanged: (v) => _setDirty(() => _cellStorageEnabled = v),
          ),
          SwitchListTile(
            title: Text(l10n.setWmsBatchTracking),
            subtitle: Text(l10n.setWmsBatchTrackingDesc),
            value: _batchTrackingEnabled,
            onChanged: (v) => _setDirty(() => _batchTrackingEnabled = v),
          ),
          SwitchListTile(
            title: Text(l10n.setWmsSerialTracking),
            subtitle: Text(l10n.setWmsSerialTrackingDesc),
            value: _serialTrackingEnabled,
            onChanged: (v) => _setDirty(() => _serialTrackingEnabled = v),
          ),
          SwitchListTile(
            title: Text(l10n.setWmsExpiryControl),
            subtitle: Text(l10n.setWmsExpiryControlDesc),
            value: _expiryControlEnabled,
            onChanged: (v) => _setDirty(() => _expiryControlEnabled = v),
          ),
          SwitchListTile(
            title: Text(l10n.setWmsMarking),
            subtitle: Text(l10n.setWmsMarkingDesc),
            value: _markingEnabled,
            onChanged: (v) => _setDirty(() => _markingEnabled = v),
          ),
          SwitchListTile(
            title: Text(l10n.setWmsWarranty),
            subtitle: Text(l10n.setWmsWarrantyDesc),
            value: _warrantyTrackingEnabled,
            onChanged: (v) => _setDirty(() => _warrantyTrackingEnabled = v),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPickingStrategySection() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.setWmsPickingStrategy,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.setWmsPickingStrategyDesc,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _pickingStrategy,
              decoration: InputDecoration(
                labelText: l10n.setWmsStrategy,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'FEFO',
                  child: Text(l10n.setWmsStrategyFefo),
                ),
                DropdownMenuItem(
                  value: 'FIFO',
                  child: Text(l10n.setWmsStrategyFifo),
                ),
                DropdownMenuItem(
                  value: 'LIFO',
                  child: Text(l10n.setWmsStrategyLifo),
                ),
              ],
              onChanged: (v) {
                if (v != null) _setDirty(() => _pickingStrategy = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostMethodSection() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.setWmsCostMethod,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.setWmsCostMethodDesc,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _costMethod,
              decoration: InputDecoration(
                labelText: l10n.setWmsMethod,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'FIFO',
                  child: Text(l10n.setWmsCostFifo),
                ),
                DropdownMenuItem(
                  value: 'LIFO',
                  child: Text(l10n.setWmsCostLifo),
                ),
                DropdownMenuItem(value: 'AVG', child: Text(l10n.setWmsCostAvg)),
              ],
              onChanged: (v) {
                if (v != null) _setDirty(() => _costMethod = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirySection() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.setWmsExpiryControl,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.setWmsExpiryWarnDesc,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _expiryWarningDays.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    label: l10n.setWmsDaysShort(_expiryWarningDays),
                    onChanged: (v) =>
                        _setDirty(() => _expiryWarningDays = v.round()),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    l10n.setWmsDaysShort(_expiryWarningDays),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbcSection() {
    final l10n = AppLocalizations.of(context)!;
    final abcC = (100 - _abcA - _abcB).clamp(0, 100);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.setWmsAbcAnalysis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.setWmsAbcDesc,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _abcRow(l10n.setWmsAbcCategoryA, _abcA, Colors.green, (v) {
              if (v + _abcB <= 100) _setDirty(() => _abcA = v);
            }),
            const SizedBox(height: 8),
            _abcRow(l10n.setWmsAbcCategoryB, _abcB, Colors.orange, (v) {
              if (_abcA + v <= 100) _setDirty(() => _abcB = v);
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.setWmsAbcCategoryC,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                Text(
                  '${abcC.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _abcRow(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: TextStyle(color: color)),
        ),
        Expanded(
          flex: 4,
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: color,
            label: '${value.toStringAsFixed(0)}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  void _setDirty(VoidCallback mutation) {
    setState(() {
      mutation();
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    final controller = ref.read(wmsConfigControllerProvider.notifier);

    final bool wantFefo = _pickingStrategy == 'FEFO';
    final bool wantFifo = _pickingStrategy == 'FIFO';

    final current =
        ref.read(wmsConfigControllerProvider).config ??
        const WmsConfigEntity(id: 1);
    final updated = current.copyWith(
      enableCells: _cellStorageEnabled,
      enableBatches: _batchTrackingEnabled,
      enableSerials: _serialTrackingEnabled,
      enableFefo: wantFefo,
      enableFifo: wantFifo,
      pickingStrategy: _pickingStrategy,
      enableMarkingCodes: _markingEnabled,
      enableWarranty: _warrantyTrackingEnabled,
      costMethod: _costMethod,
      expiryWarningDays: _expiryWarningDays,
      lowStockThreshold: Decimal.parse(_abcA.toStringAsFixed(3)),
      overStockThreshold: Decimal.parse(_abcB.toStringAsFixed(3)),
    );

    final result = await controller.saveConfig(updated);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (result.success) {
      setState(() => _isDirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setWmsSaved),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? l10n.setWmsSaveError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
