import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/snt/snt_settings_store.dart';
import 'package:telepos/domain/snt/snt_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';

class SntSettingsScreen extends StatefulWidget {
  const SntSettingsScreen({super.key});

  @override
  State<SntSettingsScreen> createState() => _SntSettingsScreenState();
}

class _SntSettingsScreenState extends State<SntSettingsScreen> {
  late final SntSettingsStore _store;
  late SntSettings _settings;

  final _binController = TextEditingController();
  final _warehouseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store = GetIt.I<SntSettingsStore>();
    _settings = _store.load();
    _binController.text = _settings.ownBin ?? '';
    _warehouseController.text = _settings.ownWarehouseCode ?? '';
  }

  @override
  void dispose() {
    _binController.dispose();
    _warehouseController.dispose();
    super.dispose();
  }

  SntSettings _collect() => _settings.copyWith(
    ownBin: _binController.text.trim(),
    ownWarehouseCode: _warehouseController.text.trim(),
  );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final next = _collect();

    if (next.isActive && (next.ownBin == null || next.ownBin!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sntSettingsBinRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final ok = await _store.save(next);
    if (!mounted) return;
    setState(() => _settings = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.sntSettingsSaved : l10n.sntSettingsSaveError),
        backgroundColor: ok
            ? AppColors.success
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = _settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sntSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            key: const ValueKey('snt-settings-save'),
            onPressed: _save,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(TeleposIcons.save, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.sntSettingsSave,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(
                  title: l10n.sntSettingsOperator,
                  icon: Icons.local_shipping,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('snt-enable'),
                        value: s.enabled,
                        onChanged: (v) => setState(() {
                          _settings = s.copyWith(
                            enabled: v,
                            providerType:
                                v && s.providerType == SntProviderType.none
                                ? SntProviderType.webkassa
                                : s.providerType,
                          );
                        }),
                        title: Text(l10n.sntSettingsEnable),
                        subtitle: Text(l10n.sntSettingsEnableSubtitle),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                      ),
                      if (s.enabled) ...[
                        const Divider(),
                        _providerPicker(l10n, s),
                      ],
                    ],
                  ),
                ),
                if (s.enabled) ...[
                  const SizedBox(height: 24),
                  _section(
                    title: l10n.sntSettingsRequisites,
                    icon: Icons.business,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(
                          l10n.sntSettingsOwnBin,
                          _binController,
                          keyName: 'snt-bin',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          l10n.sntSettingsWarehouseCode,
                          _warehouseController,
                          keyName: 'snt-warehouse',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  key: const ValueKey('snt-webkassa-note'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            TeleposIcons.info,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.sntSettingsWebkassaNote,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('snt-open-esf'),
                        onPressed: () => context.push(AppRoutes.esfSettings),
                        icon: const Icon(Icons.description, size: 18),
                        label: Text(l10n.sntSettingsOpenEsf),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _providerPicker(AppLocalizations l10n, SntSettings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sntSettingsProvider,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButton<SntProviderType>(
            key: const ValueKey('snt-provider'),
            value: s.providerType == SntProviderType.none
                ? SntProviderType.webkassa
                : s.providerType,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: SntProviderType.webkassa,
                child: Text('WebKassa (СНТ)'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _settings = s.copyWith(providerType: v));
            },
          ),
        ],
      ),
    );
  }

  Widget _section({
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

  Widget _field(
    String label,
    TextEditingController controller, {
    String? keyName,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: keyName != null ? ValueKey(keyName) : null,
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
