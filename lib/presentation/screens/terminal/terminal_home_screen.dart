import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';

/// Куда браузерный терминал приходит после входа, если у этого хоста нет
/// своей базы.
///
/// # Почему не `/shift` и не экран продажи
///
/// `getPostLoginRoute()` в `login_controller.dart` спрашивает
/// `HostCapabilities.ownsData`, а не облик хоста (`lib/domain/host/host_capabilities.dart`,
/// раздел 4 управляющего документа). `/shift` и экран продажи читают
/// `AppDatabase` напрямую — drift, `dart:ffi`, которого в браузерной сборке
/// не бывает, — и там, где `ownsData == false`, вход ведёт сюда вместо них.
///
/// # Права проверяются показом
///
/// Плитка, до которой у вошедшего нет действующего права
/// ([AuthSession.permissions], уже пересечённых с правами режима точки на
/// кассе), не строится вовсе — не строится, а не строится и блокируется:
/// показанная кнопка, которая ничего не делает по нажатию, обещание, которого
/// система не держит (раздел 11 управляющего документа).
///
/// # Что здесь переиспользовано, а не написано заново
///
/// `SettingsSection`/`SettingsTile`/`WizardMetrics` — та же тройка, которой
/// был собран `WtTerminalReadyScreen`, экран, который этот файл заменяет на
/// маршруте `/login`. Форма подошла без изменений: сгруппированный список в
/// духе Telegram с заголовком, подвалом и разделителями в один физический
/// пиксель. Сам состав секций и правило видимости плиток написаны заново —
/// у прежнего экрана их не было вовсе, он показывал только состояние мастера.
class TerminalHomeScreen extends ConsumerWidget {
  const TerminalHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );

    // `ref.watch` — не снимок: любая перемена сеанса (выход, новое право,
    // открытие смены другим путём) перерисовывает экран сама, без ручного
    // опроса. Живой подпиской в собственном смысле слова (потоком с кассы)
    // здесь оборачивать нечего — вся нужная информация уже приехала в
    // `AuthSession` при входе и лежит в `AppState`.
    final state = ref.watch(appStateProvider);
    final canOpenHardwareSettings = state.hasPermission(
      PermissionKeys.settingsHardware,
    );
    // Задача «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 6: `/sessions` — тот же периметр `settings.users`, что уже
    // держит `/hardware-settings` вход браузерного терминала (`settings
    // .hardware`) — плитка ниже даёт вошедшему администратору путь до
    // отзыва чужого сеанса, которого раньше не было вовсе.
    final canOpenSessions = state.hasPermission(PermissionKeys.settingsUsers);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: metrics.columnMaxWidth ?? double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.pageMargin,
                vertical: AppTokens.space24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    header: l10n.terminalHomeWhoHeader,
                    children: [
                      SettingsTile(
                        metrics: metrics,
                        icon: Icons.person_outline,
                        title: l10n.terminalHomeUserLabel,
                        value: state.userName ?? '—',
                      ),
                      SettingsTile(
                        metrics: metrics,
                        icon: state.isShiftOpened
                            ? Icons.lock_open
                            : TeleposIcons.lock,
                        title: l10n.navShift,
                        value: state.isShiftOpened
                            ? l10n.loginShiftOpen
                            : l10n.loginShiftClosed,
                        trailing: Icon(
                          state.isShiftOpened
                              ? TeleposIcons.checkCircle
                              : Icons.radio_button_unchecked,
                          color: state.isShiftOpened
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space16),
                  // Подпись — `l10n.hwSettingsTitle`, тот же ключ, каким это
                  // называется в `general_settings_screen.dart` и
                  // `hardware_settings_screen.dart`, а не отдельная строка со
                  // своим текстом: у этой плитки один пункт назначения
                  // (`/hardware-settings`), а не два имени на него.
                  // Право показом, а не запретом нажатия: без
                  // `settings.hardware` эта секция не строится вовсе, а не
                  // строится серой.
                  if (canOpenHardwareSettings) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.settings_outlined,
                          title: l10n.hwSettingsTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.hardwareSettings),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  // Пункт 6 закрытия долга безопасности, правка «второй
                  // порядок»: тот же приём, что у плитки оборудования выше —
                  // право показом, не запретом нажатия.
                  if (canOpenSessions) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.devices_other,
                          title: l10n.sessionsTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.sessions),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  SettingsSection(
                    footer: l10n.terminalHomeSaleNote,
                    children: [
                      SettingsTile(
                        metrics: metrics,
                        icon: Icons.point_of_sale,
                        title: l10n.navSale,
                        trailing: Icon(
                          Icons.schedule,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => unawaited(_logout(context, ref)),
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.loginLogout),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        minimumSize: const Size(
                          double.infinity,
                          AppTokens.rowHeightTouch,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Гасит сеанс и уводит на вход.
  ///
  /// [LoginNotifier.logout] чистит `AppState` (и вместе с ним — право
  /// `settings.hardware`, если оно было) и токен вкладки **первым делом**,
  /// не дожидаясь кассы, и лишь затем — без `await` — сообщает ей
  /// (`AuthRepository.logout`); переход на `/login` следует сразу за этим.
  /// Выход обязан состояться независимо от кассы: у обмена с ней нет ни
  /// таймаута, ни отмены (`WtDispatcher.ask`), и молчащий провод не имеет
  /// права держать кнопку выхода нерабочей. Касса узнаёт о выходе, если
  /// ответит; если нет — сеанс там всё равно погаснет сам по истечении
  /// бездействия.
  ///
  /// До появления [LoginNotifier.logout] здесь чистился только `AppState`:
  /// ни касса, ни `sessionStorage` о выходе не узнавали — сеанс на кассе
  /// оставался живым до истечения бездействия, а токен пережил бы саму
  /// вкладку.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(loginControllerProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }
}
