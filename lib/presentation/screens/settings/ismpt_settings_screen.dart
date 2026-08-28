import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/ismpt/ismpt_settings_store.dart';
import 'package:telepos/domain/ismpt/ismpt_provider_registry.dart';
import 'package:telepos/domain/ismpt/ismpt_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';

class IsMptSettingsScreen extends StatefulWidget {
  const IsMptSettingsScreen({super.key});

  @override
  State<IsMptSettingsScreen> createState() => _IsMptSettingsScreenState();
}

class _IsMptSettingsScreenState extends State<IsMptSettingsScreen> {
  late final IsMptSettingsStore _store;
  late IsMptSettings _settings;

  @override
  void initState() {
    super.initState();
    _store = GetIt.I<IsMptSettingsStore>();
    _settings = _store.load();
  }

  IsMptSettings _collect() => _settings;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final next = _collect();

    final ok = await _store.save(next);
    if (!mounted) return;
    setState(() => _settings = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.ismptSettingsSaved : l10n.ismptSettingsSaveError,
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
    final s = _settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ismptSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            key: const ValueKey('ismpt-settings-save'),
            onPressed: _save,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(TeleposIcons.save, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.ismptSettingsSave,
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
                  title: l10n.ismptSettingsOperator,
                  icon: Icons.qr_code_2,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('ismpt-enable'),
                        value: s.enabled,
                        onChanged: (v) => setState(() {
                          _settings = s.copyWith(
                            enabled: v,
                            backend: v && s.backend == IsMptBackend.none
                                ? IsMptBackend.live
                                : s.backend,
                          );
                        }),
                        title: Text(l10n.ismptSettingsEnable),
                        subtitle: Text(l10n.ismptSettingsEnableSubtitle),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                      ),
                      if (s.enabled) ...[
                        const Divider(),
                        _backendPicker(l10n, s),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  key: const ValueKey('ismpt-webkassa-note'),
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
                              l10n.ismptSettingsWebkassaNote,
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
                        key: const ValueKey('ismpt-open-esf'),
                        onPressed: () => context.push(AppRoutes.esfSettings),
                        icon: const Icon(Icons.description, size: 18),
                        label: Text(l10n.ismptSettingsOpenEsf),
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

  Widget _backendPicker(AppLocalizations l10n, IsMptSettings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.ismptSettingsBackend,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButton<IsMptBackend>(
            key: const ValueKey('ismpt-backend'),
            value: s.backend == IsMptBackend.none
                ? IsMptBackend.live
                : s.backend,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: IsMptBackend.live,
                child: Text('ИС МПТ (ismet.kz / Tañba)'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _settings = s.copyWith(backend: v));
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
}
