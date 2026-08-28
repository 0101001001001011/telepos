import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Итог: то, ради чего строка «название — значение» и заводилась.
///
/// Каждая строка ведёт назад к своему шагу по нажатию. Раньше исправить
/// замеченное здесь было нечем — вернуться можно было только нажав «Назад»
/// столько раз, сколько шагов между ними, и по дороге пройти их все заново.
class SummaryStep extends ConsumerWidget {
  const SummaryStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );
    InitialSetupNotifier controller() =>
        ref.read(initialSetupControllerProvider.notifier);

    final org = state.organization;
    final pos = state.posConfig;
    final fiscal = state.fiscalConfig;
    final eq = state.equipmentConfig;
    final vatRate = state.selectedCountry?.vatRate ?? 0;

    final devices = <String>[
      if (eq.printerEnabled) l10n.setupSummaryPrinter,
      if (eq.scannerEnabled) l10n.setupSummaryScanner,
      if (eq.scaleEnabled) l10n.setupSummaryScales,
      if (eq.customerDisplayEnabled) l10n.setupSummaryEquipment,
    ];

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      nextLabel: l10n.globalDone,
      onNext: () => controller().finishSetup(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Проверка» стоит в шапке мастера. Итог — это
      // список того, что уже введено, и первое, что человек должен увидеть, —
      // сами значения, а не приглашение их посмотреть.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupSummaryOrganization,
            children: [
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryName,
                value: org.companyName ?? l10n.setupNotConfigured,
                onTap: () =>
                    controller().goToStep(InitialSetupStep.organizationSetup),
              ),
              SettingsTile(
                metrics: metrics,
                title: state.selectedCountry?.taxIdLabel ?? l10n.setupSummaryId,
                value: org.taxId ?? l10n.setupNotConfigured,
                onTap: () =>
                    controller().goToStep(InitialSetupStep.organizationSetup),
              ),
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryVat,
                value: org.isVatPayer
                    ? l10n.setupVatPayerSummary(vatRate)
                    : l10n.setupVatNonPayerTitle,
                onTap: () =>
                    controller().goToStep(InitialSetupStep.vatSelection),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionCashBox,
            children: [
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryName,
                value: pos.cashBoxName ?? l10n.setupNotConfigured,
                onTap: () => controller().goToStep(InitialSetupStep.posSetup),
              ),
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryId,
                value: pos.posId ?? l10n.setupNotConfigured,
                onTap: () => controller().goToStep(InitialSetupStep.posSetup),
              ),
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryFormat,
                value: pos.paperWidth == 32
                    ? l10n.setupPaperWidth58
                    : l10n.setupPaperWidth80,
                onTap: () => controller().goToStep(InitialSetupStep.posSetup),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionUsers,
            children: [
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryAdmin,
                value: state.firstUser.name ?? l10n.setupNotConfigured,
                onTap: () =>
                    controller().goToStep(InitialSetupStep.employeeSetup),
              ),
              if (state.secondUser?.name?.isNotEmpty ?? false)
                SettingsTile(
                  metrics: metrics,
                  title: l10n.setupSummarySeller,
                  value: state.secondUser!.name!,
                  onTap: () =>
                      controller().goToStep(InitialSetupStep.employeeSetup),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupStepFiscal,
            children: [
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryFiscalType,
                value: fiscal.enabled
                    ? fiscal.fiscalType.name
                    : l10n.setupDisabled,
                onTap: () =>
                    controller().goToStep(InitialSetupStep.fiscalSetup),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupStepEquipment,
            children: [
              SettingsTile(
                metrics: metrics,
                title: l10n.setupSummaryEquipment,
                value: devices.isEmpty
                    ? l10n.setupNotConfigured
                    : devices.join(', '),
                onTap: () =>
                    controller().goToStep(InitialSetupStep.equipmentSetup),
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
