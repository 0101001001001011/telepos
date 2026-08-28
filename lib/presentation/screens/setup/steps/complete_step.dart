import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Последний экран: касса настроена.
///
/// Рельс заполнен целиком — это и есть сообщение о том, что пройдено всё.
/// Зелёный круг 120 px с галочкой убран: успех показывает сам рельс и текст,
/// а круг был самым громким элементом во всём мастере.
class CompleteStep extends ConsumerWidget {
  const CompleteStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );

    return WizardScaffold(
      totalSteps: InitialSetupState.orderedSteps.length,
      currentStep: InitialSetupState.orderedSteps.length,
      nextLabel: l10n.loginEnterSystem,
      onNext: () => context.go(AppRoutes.login),
      // Один из двух экранов, где иллюстрация с заголовком уместна, — как
      // первый запуск Telegram. Заголовок под ней набирается ролью `title`
      // (20), крупнее в приложении нет ничего, кроме сумм.
      //
      // Знак завершения переехал из `child` в иллюстрацию: он и был
      // иллюстрацией, только стоял ПОД подписью, и композиция получалась
      // перевёрнутой.
      hero: WizardHero(
        metrics: metrics,
        title: l10n.setupCompleteTitle,
        subtitle: l10n.setupCompleteSubtitle,
        illustration: Icon(
          TeleposIcons.checkCircle,
          size: AppTokens.iconSizeSuccess,
          color: context.semantic.success,
        ),
      ),
      // Ниже заголовка на этом экране делать нечего: настройка кончилась.
      child: const SizedBox.shrink(),
    );
  }
}
