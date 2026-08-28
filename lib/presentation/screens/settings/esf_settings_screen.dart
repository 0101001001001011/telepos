import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/controllers/settings/esf_settings_controller.dart';

class EsfSettingsScreen extends ConsumerStatefulWidget {
  const EsfSettingsScreen({super.key});

  @override
  ConsumerState<EsfSettingsScreen> createState() => _EsfSettingsScreenState();
}

class _EsfSettingsScreenState extends ConsumerState<EsfSettingsScreen> {
  final _binController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _vatSeriesController = TextEditingController();
  final _vatNumberController = TextEditingController();
  final _vatRateController = TextEditingController();

  bool _primed = false;

  @override
  void dispose() {
    _binController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _vatSeriesController.dispose();
    _vatNumberController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  EsfSettingsController get _ctrl =>
      ref.read(esfSettingsControllerProvider.notifier);

  void _prime(EsfSettings s) {
    if (_primed) return;
    _primed = true;
    _binController.text = s.supplierBin ?? '';
    _nameController.text = s.supplierName ?? '';
    _addressController.text = s.supplierAddress ?? '';
    _vatSeriesController.text = s.supplierVatSeries ?? '';
    _vatNumberController.text = s.supplierVatNumber ?? '';
    _vatRateController.text = s.vatRatePercent.toString();
  }

  void _syncFromControllers() {
    final s = ref.read(esfSettingsControllerProvider).settings;
    _ctrl.update(
      s.copyWith(
        supplierBin: _binController.text.trim(),
        supplierName: _nameController.text.trim(),
        supplierAddress: _addressController.text.trim(),
        supplierVatSeries: _vatSeriesController.text.trim(),
        supplierVatNumber: _vatNumberController.text.trim(),
        vatRatePercent: _parseVat(_vatRateController.text),
      ),
    );
  }

  Decimal _parseVat(String raw) {
    final v = Decimal.tryParse(raw.trim().replaceAll(',', '.'));
    return v ?? EsfDefaults.vatRatePercent;
  }

  Future<void> _save() async {
    _syncFromControllers();
    final ok = await _ctrl.save();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(esfSettingsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.esfSettingsSaved
              : (state.validationError ?? l10n.esfSettingsSaveError),
        ),
        backgroundColor: ok
            ? AppColors.success
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(esfSettingsControllerProvider);
    final settings = state.settings;
    _prime(settings);

    final width = MediaQuery.of(context).size.width;
    final isDesktop = Breakpoints.fromWidth(width) == LayoutType.desktop;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.esfSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.esfOutboxTitle,
            icon: const Icon(Icons.outbox),
            onPressed: () => context.push(AppRoutes.esfOutbox),
          ),
          TextButton(
            key: const ValueKey('esf-save'),
            onPressed: _save,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(TeleposIcons.save, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.esfSettingsSave,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(
                  title: l10n.esfSettingsOperator,
                  icon: Icons.description,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('esf-enable'),
                        value: settings.enabled,
                        onChanged: (v) {
                          _syncFromControllers();
                          _ctrl.setEnabled(v);
                        },
                        title: Text(l10n.esfSettingsEnable),
                        subtitle: Text(l10n.esfSettingsEnableSubtitle),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                      ),
                      if (settings.enabled) ...[
                        const Divider(),
                        SwitchListTile(
                          key: const ValueKey('esf-b2bonly'),
                          value: settings.b2bOnly,
                          onChanged: (v) {
                            _syncFromControllers();
                            final s = ref
                                .read(esfSettingsControllerProvider)
                                .settings;
                            _ctrl.update(s.copyWith(b2bOnly: v));
                          },
                          title: Text(l10n.esfSettingsB2bOnly),
                          subtitle: Text(l10n.esfSettingsB2bOnlySubtitle),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
                if (settings.enabled) ...[
                  const SizedBox(height: 24),
                  _section(
                    title: l10n.esfSettingsSupplier,
                    icon: Icons.business,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(
                          l10n.esfSettingsBin,
                          _binController,
                          keyName: 'esf-bin',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          l10n.esfSettingsName,
                          _nameController,
                          keyName: 'esf-name',
                        ),
                        const SizedBox(height: 16),
                        _field(
                          l10n.esfSettingsAddress,
                          _addressController,
                          keyName: 'esf-address',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _section(
                    title: l10n.esfSettingsVatPayer,
                    icon: Icons.calculate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          key: const ValueKey('esf-vatpayer'),
                          value: settings.isVatPayer,
                          onChanged: (v) {
                            _syncFromControllers();
                            final s = ref
                                .read(esfSettingsControllerProvider)
                                .settings;
                            _ctrl.update(s.copyWith(isVatPayer: v));
                          },
                          title: Text(l10n.esfSettingsVatPayer),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                        ),
                        if (settings.isVatPayer) ...[
                          const Divider(),
                          _field(
                            l10n.esfSettingsVatSeries,
                            _vatSeriesController,
                            keyName: 'esf-vatseries',
                          ),
                          const SizedBox(height: 16),
                          _field(
                            l10n.esfSettingsVatNumber,
                            _vatNumberController,
                            keyName: 'esf-vatnumber',
                          ),
                          const SizedBox(height: 16),
                          _field(
                            l10n.esfSettingsVatRate,
                            _vatRateController,
                            keyName: 'esf-vatrate',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _webkassaNote(l10n),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _webkassaNote(AppLocalizations l10n) {
    return Container(
      key: const ValueKey('esf-webkassa-note'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(TeleposIcons.info, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.esfSettingsWebkassaNote,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
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
