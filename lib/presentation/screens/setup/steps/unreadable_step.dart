import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Shown when the till could not be asked whether it is configured.
///
/// It offers **retry and nothing else**. There is deliberately no way from
/// here into the wizard: this screen exists precisely because the previous
/// behaviour — treat an unanswerable question as "not configured" and start
/// setting up — is what could overwrite a working shop.
///
/// Перевёрстка ничего из этого не меняет: рельса нет (номера шага у состояния
/// нет), кнопка одна, и она повторяет проверку.
class UnreadableStep extends ConsumerWidget {
  const UnreadableStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );

    return WizardScaffold(
      totalSteps: InitialSetupState.orderedSteps.length,
      // Ноль означает «вне нумерации» — рельс себя не рисует.
      currentStep: 0,
      nextLabel: l10n.globalRetry,
      onNext: () =>
          ref.read(initialSetupControllerProvider.notifier).retryInitialCheck(),
      // Знак обрыва связи переехал из `child` в иллюстрацию: он и был
      // иллюстрацией, только стоял ПОД подписью — то есть композиция читалась
      // снизу вверх.
      hero: WizardHero(
        metrics: metrics,
        // Своя строка, а не `errorCheckFailedGeneric`: «Ошибка проверки»
        // здесь неправда — проверять было нечего, касса не ответила.
        // Экран обязан назвать, что случилось, и сказать, что делать.
        title: l10n.setupStateUnreadableTitle,
        illustration: Icon(
          Icons.cloud_off,
          size: AppTokens.iconSizeSuccess,
          color: theme.colorScheme.error,
        ),
      ),
      child: SettingsSection(
        footer: l10n.setupStateUnreadableBody,
        children: const [],
      ),
    );
  }
}
