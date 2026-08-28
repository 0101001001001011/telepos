import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/config/build_config.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/app_typography.dart';
import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/core/constants/app_constants.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/common/dialogs/app_error_dialog.dart';
import 'package:telepos/presentation/common/dialogs/confirmation_dialog.dart';
import 'package:telepos/presentation/common/dialogs/information_dialog.dart';
import 'package:telepos/presentation/common/dialogs/input_dialog.dart';
import 'package:telepos/presentation/controllers/startup/startup_state_provider.dart';

/// Заставка: подъём кассы и один выбор маршрута.
///
/// `ConsumerStatefulWidget`, а не `StatefulWidget`, ровно ради одного —
/// состояние установки берётся из общей живой подписки
/// [startupStateProvider], а не из собственного `watch().first`. См.
/// [_SplashScreenState._checkPosConfiguration].
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  double _progress = 0.0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialization();
    });
  }

  Future<void> _startInitialization() async {
    final l10n = AppLocalizations.of(context);
    if (l10n != null && _statusText.isEmpty) {
      _updateProgress(0.0, l10n.splashInitializing);
    }

    final status = await GetIt.I<AppBootstrap>().start(
      onProgress: (progress, message) {
        _updateProgress(progress, message);
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    if (GetIt.I.isRegistered<FirstLaunchRepository>()) {
      final firstLaunch = GetIt.I<FirstLaunchRepository>();
      final result = await firstLaunch.determineResult();

      if (!mounted) return;

      switch (result) {
        case FirstLaunchResult.alreadyConfigured:
          await _handleInitStatus(status);
          return;

        case FirstLaunchResult.newPosWithBackups:
          talker.info('Backups found, showing restore/new choice');
          context.go(AppRoutes.restoreOrNew);
          return;

        case FirstLaunchResult.existingUserNewPos:
          talker.info('Existing user, loading global data');
          _updateProgress(0.5, l10n?.splashLoadingOrg ?? '');
          await firstLaunch.loadGlobalData(
            onProgress: (progress, message) {
              _updateProgress(0.5 + progress * 0.4, message);
            },
          );
          if (mounted) context.go(AppRoutes.initialSetup);
          return;

        case FirstLaunchResult.newPosNoBackups:
        case FirstLaunchResult.offlineMode:
          talker.info('New POS setup required');
          context.go(AppRoutes.initialSetup);
          return;
      }
    }

    final isPosConfigured = await _checkPosConfiguration();
    if (!isPosConfigured) {
      talker.info('POS not configured, redirecting to initial setup');
      if (mounted) {
        context.go(AppRoutes.initialSetup);
      }
      return;
    }

    if (!mounted) return;

    await _handleInitStatus(status);
  }

  Future<void> _handleInitStatus(AppInitStatus status) async {
    if (!mounted) return;

    switch (status) {
      case AppInitStatus.success:
        context.go(AppRoutes.login);

      case AppInitStatus.noKey:
        await _showPosKeyDialog();

      case AppInitStatus.absentMandatoryData:
        await _showReinitializeDialog();

      case AppInitStatus.databaseFailure:
        await _showDatabaseErrorDialog();

      case AppInitStatus.syncSuspended:
        await _showSyncSuspendedWarning();
        if (mounted) context.go(AppRoutes.login);

      case AppInitStatus.authorizationFailure:
        await _showAuthorizationError();

      case AppInitStatus.supportEnded:
        await _showSupportEndedError();
    }
  }

  Future<void> _showPosKeyDialog() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    final posKey = await InputDialog.showText(
      context: context,
      title: l10n.splashEnterPosKey,
      message: l10n.splashEnterPosKeyMessage,
      hint: l10n.splashPosKeyHint,
      validator: (value) {
        if (value.isEmpty) return l10n.splashKeyEmpty;
        if (value.length < 8) return l10n.splashKeyTooShort;
        return null;
      },
    );

    if (posKey != null && mounted) {
      talker.info('POS key entered: ${posKey.substring(0, 4)}****');

      final localProperties = GetIt.I<LocalProperties>();
      localProperties.posKey = posKey;

      context.go(AppRoutes.initialSetup);
    } else if (mounted) {
      final dl10n = AppLocalizations.of(context)!;
      await InformationDialog.showError(
        context: context,
        message: dl10n.splashKeyRequiredMessage,
        title: dl10n.splashKeyNotEntered,
      );
      _exitApp();
    }
  }

  Future<void> _showReinitializeDialog() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: l10n.splashDataCorrupted,
      message: l10n.splashDataCorruptedMessage,
      confirmText: l10n.splashReconfigure,
      cancelText: l10n.splashExit,
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      talker.info('User chose to reinitialize');
      context.go(AppRoutes.initialSetup);
    } else {
      _exitApp();
    }
  }

  Future<void> _showDatabaseErrorDialog() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: l10n.splashDatabaseError,
      message: l10n.splashDatabaseErrorMessage,
      confirmText: l10n.splashRestoreFromBackup,
      cancelText: l10n.splashReconfigure,
      isDestructive: true,
    );

    if (!mounted) return;

    if (confirmed == true) {
      talker.info('User chose to restore from backup');
      context.go(AppRoutes.restoreOrNew);
    } else {
      talker.info('User chose to reinitialize after DB failure');
      context.go(AppRoutes.initialSetup);
    }
  }

  Future<void> _showSyncSuspendedWarning() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    await InformationDialog.showWarning(
      context: context,
      title: l10n.splashSyncSuspended,
      message: l10n.splashSyncSuspendedMessage,
    );
  }

  Future<void> _showAuthorizationError() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    await AppErrorDialog.show(
      context: context,
      error: l10n.splashAuthError,
      onRetry: () {
        if (mounted) _startInitialization();
      },
      onExit: _exitApp,
    );
  }

  Future<void> _showSupportEndedError() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    await AppErrorDialog.show(
      context: context,
      error: l10n.splashSupportEnded,
      onExit: _exitApp,
    );
  }

  void _exitApp() {
    talker.info('Exiting application');
    SystemNavigator.pop();
  }

  Future<bool> _checkPosConfiguration() async {
    try {
      // Состояние берётся из **общей живой подписки**, а не из своего
      // `watch().first`.
      //
      // Разница не косметическая. `first` заводил подписку и тут же её снимал,
      // и следующий экран — мастер настройки — заводил свою: два обращения к
      // кассе там, где состояние одно. Через `startupStateProvider` подписка у
      // заставки и мастера общая, переход между ними не стоит ни одного нового
      // вопроса, а мастер получает уже пришедшее значение вместо того, чтобы
      // спрашивать заново.
      //
      // Ждётся здесь именно первое значение, и это не обход подписки:
      // заставка выбирает маршрут ровно один раз и уходит. Живой её делает
      // не ожидание, а то, что подписка после ухода остаётся — у того, кто
      // рисуется дальше.
      final state = await ref.read(startupStateProvider.future);

      if (!state.configured) {
        talker.debug('POS configuration not found');
        return false;
      }

      if (!state.hasUsers) {
        talker.debug('No users found');
        return false;
      }

      talker.debug('POS configuration verified');
      return true;
    } catch (e) {
      talker.error('Error checking POS configuration: $e');
      return false;
    }
  }

  void _updateProgress(double value, String text) {
    if (!mounted) return;
    setState(() {
      _progress = value;
      _statusText = text;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Версия берётся из одного места и без запасного литерала.
  ///
  /// До 2026-08-04 здесь стояло `: '3.3.0'` — и печаталось всегда, потому что
  /// `BuildConfig` никто не регистрировал. Экран уверенно показывал версию,
  /// которой не существовало уже две минорных. Теперь запасное значение —
  /// [AppConstants.appVersion], а тест не даёт ему разойтись с `pubspec.yaml`.
  String get _version => GetIt.I.isRegistered<BuildConfig>()
      ? GetIt.I<BuildConfig>().version
      : AppConstants.appVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hairline = AppTokens.hairlineOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              children: [
                const Spacer(),
                // Знак приложения — залитый квадрат со скруглением, как метка
                // приложения в Telegram, а не иконка Material на белом.
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.tgBlue,
                    borderRadius: BorderRadius.circular(
                      AppTokens.radiusSection * 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.point_of_sale,
                    size: 36,
                    color: AppColors.tgSheet,
                  ),
                ),
                const SizedBox(height: AppTokens.space24),
                Text(
                  l10n?.appName ?? 'TelePOS',
                  style: AppTypography.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  l10n?.splashSubtitle ?? 'Point of Sale System',
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTokens.space48),

                // Тонкая линия вместо материальной полосы: прогресс здесь —
                // фон, а не главное на экране.
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.columnMaxWidthTablet,
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTokens.railHeight,
                        ),
                        // Дорожка полосы не задаётся: `progressIndicatorTheme`
                        // отдаёт под неё роль `hairline`, и это ровно тот же
                        // цвет в светлой теме — но уже другой в тёмной.
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: AppTokens.railHeight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.tgBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space12),
                      Text(
                        _statusText,
                        style: AppTypography.label.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                Container(
                  height: hairline,
                  width: 32,
                  color: AppColors.tgHairline,
                ),
                const SizedBox(height: AppTokens.space12),
                Text(
                  'v$_version',
                  style: AppTypography.label.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
