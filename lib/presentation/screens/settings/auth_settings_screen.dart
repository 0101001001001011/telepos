import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/settings/auth_settings_controller.dart';

/// Настройки входа этой точки: walk-up (вход без выбора кассира) и срок
/// сеанса. Закрывает И31 (задача 18) — до этого экрана `ThisPosDao
/// .saveAuthSettings` была живой в схеме и мёртвой в интерфейсе: писали её
/// только тесты.
///
/// Достижим из хаба настроек (`GeneralSettingsScreen`, плитка рядом с
/// «Пользователи») под правом `settings.users` — тем же, что закрывает
/// `/user-management`: и то, и другое решает, кто и как входит в кассу, а
/// администратор ни то, ни другое по умолчанию не получает
/// (`PermissionKeys.roleDefaults`).
class AuthSettingsScreen extends ConsumerStatefulWidget {
  const AuthSettingsScreen({super.key});

  @override
  ConsumerState<AuthSettingsScreen> createState() => _AuthSettingsScreenState();
}

class _AuthSettingsScreenState extends ConsumerState<AuthSettingsScreen> {
  final _minutesController = TextEditingController();

  /// Значение, для которого сейчас показан текст в поле — чтобы не
  /// перетирать то, что человек набирает, каждым перестроением виджета, и
  /// при этом подставить настоящее число, как только оно придёт из базы.
  int? _syncedMinutes;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authSettingsControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
      ),
    );
  }

  Future<void> _saveMinutes() async {
    final l10n = AppLocalizations.of(context)!;
    final value = int.tryParse(_minutesController.text.trim());
    if (value == null ||
        value < AuthSettingsController.minSessionIdleMinutes ||
        value > AuthSettingsController.maxSessionIdleMinutes) {
      _snack(l10n.authSettingsInvalidMinutes, error: true);
      return;
    }
    final ok = await ref
        .read(authSettingsControllerProvider.notifier)
        .setSessionIdleMinutes(value);
    if (!mounted) return;
    if (ok) {
      _snack(l10n.authSettingsSaved);
    } else {
      _snack(l10n.authSettingsInvalidMinutes, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authSettingsControllerProvider);

    ref.listen<AuthSettingsState>(authSettingsControllerProvider, (prev, next) {
      if (next.sessionIdleMinutes != _syncedMinutes) {
        _syncedMinutes = next.sessionIdleMinutes;
        _minutesController.text = next.sessionIdleMinutes.toString();
      }
      final err = next.error;
      if (err != null && err != prev?.error) {
        _snack(err, error: true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.authSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    key: const ValueKey('auth-settings-walk-up'),
                    value: state.walkUpEnabled,
                    onChanged: state.saving
                        ? null
                        : (value) => ref
                              .read(authSettingsControllerProvider.notifier)
                              .setWalkUpEnabled(value),
                    title: Text(l10n.authSettingsWalkUpTitle),
                    subtitle: Text(l10n.authSettingsWalkUpSubtitle),
                    secondary: Icon(
                      state.walkUpEnabled
                          ? Icons.touch_app
                          : Icons.touch_app_outlined,
                      color: state.walkUpEnabled
                          ? AppColors.warning
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.authSettingsSessionTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.authSettingsSessionSubtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey(
                                  'auth-settings-session-minutes',
                                ),
                                controller: _minutesController,
                                enabled: !state.saving,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText:
                                      l10n.authSettingsSessionMinutesLabel,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              key: const ValueKey('auth-settings-session-save'),
                              onPressed: state.saving ? null : _saveMinutes,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: Text(l10n.globalSave),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
