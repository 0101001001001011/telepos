import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_choice_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Шаг НДС: платит организация налог или нет.
///
/// Вариантов ровно два, и третьего состояния у флага нет — поэтому один из
/// них отмечен всегда.
class VatStep extends ConsumerWidget {
  const VatStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );
    // Лениво: чтение `.notifier` при построении создаёт контроллер со всеми
    // его таймерами и лишает шаг возможности рисоваться в одиночку.
    InitialSetupNotifier controller() =>
        ref.read(initialSetupControllerProvider.notifier);

    final isVatPayer = state.organization.isVatPayer;
    final vatRate = state.selectedCountry?.vatRate ?? 0;

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      onNext: () => controller().confirmVatSelection(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «НДС» стоит в шапке мастера, а подзаголовок
      // «Выберите режим налогообложения» повторял то же самое третий раз.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupStepVat,
            // Описания обоих режимов — одним абзацем под списком, а не
            // мелким текстом внутри каждой строки: внутри строки они
            // соревнуются с самим выбором и проигрывают ему.
            footer:
                '${l10n.setupVatPayerDescription}\n\n'
                '${l10n.setupVatNonPayerDescription}',
            children: [
              SettingsChoiceTile(
                metrics: metrics,
                title: l10n.setupVatPayerTitle,
                subtitle: vatRate > 0
                    ? l10n.setupVatPayerRate(vatRate)
                    : l10n.setupVatPayerRateUnknown,
                selected: isVatPayer,
                onTap: () => controller().setVatPayer(true),
              ),
              SettingsChoiceTile(
                metrics: metrics,
                title: l10n.setupVatNonPayerTitle,
                subtitle: l10n.setupVatNonPayerSubtitle,
                selected: !isVatPayer,
                onTap: () => controller().setVatPayer(false),
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
