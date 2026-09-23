import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/boot_stage_label.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';

/// Первый экран новой кассы: восстановить из копии или настроить с нуля.
///
/// Плана он не касался, но лежит в `screens/setup/` и попадает под то же
/// правило — и это первое, что человек видит. Карточка с рамкой и тенью,
/// стоявшая здесь, задавала тон всему остальному ещё до того, как начиналась
/// сама настройка.
class RestoreOrNewScreen extends ConsumerStatefulWidget {
  const RestoreOrNewScreen({super.key});

  @override
  ConsumerState<RestoreOrNewScreen> createState() => _RestoreOrNewScreenState();
}

class _RestoreOrNewScreenState extends ConsumerState<RestoreOrNewScreen> {
  final FirstLaunchRepository _firstLaunch = GetIt.I<FirstLaunchRepository>();

  List<FoundBackup> _backups = [];
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _statusMessage;
  double _restoreProgress = 0;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Поиск копий начинается здесь, а не в initState: он сразу же читает
    // локализацию, а обращение к InheritedWidget из initState — ошибка
    // времени выполнения. Экран падал на этом и до перевёрстки, просто
    // никто его не проверял.
    if (_started) return;
    _started = true;
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _statusMessage = l10n.restoreSearchingBackups;
    });

    try {
      final backups = await _firstLaunch.findAvailableBackups();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = l10n.restoreLoadError(e.toString());
      });
    }
  }

  Future<void> _restoreFromBackup(FoundBackup backup) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isRestoring = true;
      _restoreProgress = 0;
      _statusMessage = l10n.restoreRestoring;
    });

    final success = await _firstLaunch.restoreFromBackup(
      backup,
      onProgress: (progress, stage, [detail]) {
        if (!mounted) return;
        final words = AppLocalizations.of(context);
        setState(() {
          _restoreProgress = progress;
          _statusMessage = words == null
              ? ''
              : bootStageLabel(stage, words, detail: detail);
        });
      },
    );

    if (!mounted) return;
    if (success) {
      context.go(AppRoutes.login);
      return;
    }
    setState(() {
      _isRestoring = false;
      _statusMessage = l10n.restoreRestoreError;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.restoreRestoreFailed)));
  }

  Future<void> _createNewPos() async {
    await _firstLaunch.startNewPos();
    if (mounted) context.go(AppRoutes.initialSetup);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: metrics.columnMaxWidth ?? double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.pageMargin),
              child: _isRestoring
                  ? _buildRestoring()
                  : _buildSelection(metrics),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestoring() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.restoreTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTokens.space32),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          child: LinearProgressIndicator(value: _restoreProgress),
        ),
        const SizedBox(height: AppTokens.space16),
        Text(
          _statusMessage ?? '',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSelection(WizardMetrics metrics) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTokens.space40),
        WizardHero(
          metrics: metrics,
          title: 'TelePOS',
          subtitle: l10n.restoreChooseMethod,
        ),
        const SizedBox(height: AppTokens.space32),
        Expanded(
          child: _isLoading
              ? _buildLoading()
              : SingleChildScrollView(child: _buildBackups(metrics)),
        ),
        const SizedBox(height: AppTokens.space16),
        OutlinedButton(
          onPressed: _isLoading ? null : _createNewPos,
          child: Text(l10n.restoreSetupNewPos),
        ),
        const SizedBox(height: AppTokens.space16),
      ],
    );
  }

  Widget _buildLoading() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTokens.space16),
          Text(
            _statusMessage ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackups(WizardMetrics metrics) {
    final l10n = AppLocalizations.of(context)!;

    if (_backups.isEmpty) {
      // Пустой список — не ошибка, а обычное начало: касса новая. Поэтому
      // подпись объясняет, что делать дальше, а не сообщает о неудаче.
      return SettingsSection(
        header: l10n.restoreNoBackups,
        footer: l10n.restoreSetupAsNew,
        children: const [],
      );
    }

    return SettingsSection(
      header: l10n.restoreFoundBackups,
      children: [
        for (final backup in _backups)
          SettingsTile(
            metrics: metrics,
            title: backup.posName,
            value: backup.formattedSize,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _restoreFromBackup(backup),
          ),
      ],
    );
  }
}
