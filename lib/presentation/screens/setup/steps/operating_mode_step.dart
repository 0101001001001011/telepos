import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_choice_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Шаг выбора типа бизнеса.
///
/// Выбор определяет, какие разделы кассы вообще появятся, поэтому у каждого
/// варианта есть третья строка с перечнем возможностей — здесь она уместна,
/// в отличие от шага НДС, где выбор бинарный.
class OperatingModeStep extends ConsumerWidget {
  const OperatingModeStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );
    // Лениво: чтение .notifier при построении создаёт контроллер со всеми
    // его таймерами и лишает шаг возможности рисоваться в одиночку.
    InitialSetupNotifier controller() =>
        ref.read(initialSetupControllerProvider.notifier);

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      onNext: () => controller().confirmOperatingMode(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Тип бизнеса» стоит в шапке мастера и здесь
      // же подписью группы. Третьего повтора крупным кеглем не требуется.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupStepOperatingMode,
            children: [
              SettingsChoiceTile(
                metrics: metrics,
                title: l10n.setupRetailTitle,
                subtitle: l10n.setupRetailSubtitle,
                detail: l10n.setupRetailDescription,
                selected: state.operatingMode == OperatingMode.retail,
                onTap: () =>
                    controller().setOperatingMode(OperatingMode.retail),
              ),
              SettingsChoiceTile(
                metrics: metrics,
                title: l10n.setupRestaurantTitle,
                subtitle: l10n.setupRestaurantSubtitle,
                detail: l10n.setupRestaurantDescription,
                selected: state.operatingMode == OperatingMode.restaurant,
                onTap: () =>
                    controller().setOperatingMode(OperatingMode.restaurant),
              ),
              SettingsChoiceTile(
                metrics: metrics,
                title: l10n.setupServiceTitle,
                subtitle: l10n.setupServiceSubtitle,
                detail: l10n.setupServiceDescription,
                selected: state.operatingMode == OperatingMode.service,
                onTap: () =>
                    controller().setOperatingMode(OperatingMode.service),
              ),
            ],
          ),
          if (state.hasError)
            WizardErrorNote(
              message: ErrorLocalizer.localize(context, state.error!),
            ),
        ],
      ),
    );
  }
}
