import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/core/logging/setup_logger.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/tax_step_words.dart';
import 'package:telepos/presentation/common/help/help_button.dart';
import 'package:telepos/presentation/common/widgets/language_switcher.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/business_rules_step.dart';
import 'package:telepos/presentation/screens/setup/steps/checking_step.dart';
import 'package:telepos/presentation/screens/setup/steps/complete_step.dart';
import 'package:telepos/presentation/screens/setup/steps/country_step.dart';
import 'package:telepos/presentation/screens/setup/steps/employees_step.dart';
import 'package:telepos/presentation/screens/setup/steps/equipment_step.dart';
import 'package:telepos/presentation/screens/setup/steps/fiscal_step.dart';
import 'package:telepos/presentation/screens/setup/steps/operating_mode_step.dart';
import 'package:telepos/presentation/screens/setup/steps/organization_step.dart';
import 'package:telepos/presentation/screens/setup/steps/payment_terminal_step.dart';
import 'package:telepos/presentation/screens/setup/steps/pos_step.dart';
import 'package:telepos/presentation/screens/setup/steps/summary_step.dart';
import 'package:telepos/presentation/screens/setup/steps/unreadable_step.dart';
import 'package:telepos/presentation/screens/setup/steps/vat_step.dart';

/// Мастер первоначальной настройки — только маршрутизация по текущему шагу.
///
/// Здесь было три тысячи строк вёрстки всех одиннадцати экранов сразу, и любая
/// правка задевала соседние. Теперь каждый шаг — свой файл, а этот знает
/// только, какой из них показать.
class InitialSetupScreen extends ConsumerStatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  ConsumerState<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends ConsumerState<InitialSetupScreen> {
  @override
  void initState() {
    super.initState();
    SetupLogger.init();
    SetupLogger.info('InitialSetupScreen: экран открыт');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(initialSetupControllerProvider);
    final theme = Theme.of(context);

    ref.listen(initialSetupControllerProvider, (previous, next) {
      if (next.isComplete) {
        context.go(AppRoutes.login);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // `unreadable` тоже без рельсы: у этого состояния нет номера шага,
            // и `stepNumber` честно отдаёт 0 — а «шаг 0 из 11» на экране не
            // значит ничего. Замечено 2026-08-04 на снимке из браузера.
            if (state.currentStep != InitialSetupStep.checking &&
                state.currentStep != InitialSetupStep.unreadable &&
                state.currentStep != InitialSetupStep.complete)
              _buildProgressIndicator(state, theme)
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTokens.space8),
                child: Row(
                  children: [
                    LanguageSwitcher(),
                    _NetworkButton(),
                    Spacer(),
                    HelpButton(screenId: 'initial_setup'),
                  ],
                ),
              ),

            Expanded(child: _buildContent(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(InitialSetupState state, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                l10n.setupStepProgress(state.stepNumber, state.totalSteps),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // Название шага — теперь ЕДИНСТВЕННОЕ место, где шаг назван.
              //
              // Центрированный заголовок внутри шага убран 2026-08-04, и
              // подпись, которая раньше дублировала его мелким кеглем,
              // осталась одна. Поэтому здесь роль `bodyStrong` (15/500) через
              // слот titleMedium, а не 13-й кегль, дожатый до bold: жирность,
              // приписанная поверх подписи, — это стиль, заданный экраном, а
              // тема для того и существует, чтобы его там не было.
              Text(
                _getStepTitle(state.currentStep, l10n, state.selectedCountry),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: AppTokens.space4),
              const LanguageSwitcher(),
              const _NetworkButton(),
              const HelpButton(screenId: 'initial_setup'),
            ],
          ),
        ],
      ),
    );
  }
  // Полосы прогресса здесь больше нет намеренно.
  //
  // Замечено 2026-08-04 на снимке мастера: их было ДВЕ разом — материальная в
  // этой шапке и сегментированный рельс внутри шага. Две полосы про одно и то
  // же противоречат друг другу уже тем, что считают по-разному: эта делила
  // номер шага на общее число, рельс же показывает шаги дискретно.
  //
  // Рельс живёт в `WizardScaffold`, то есть у шага, и это верное место: шаг
  // знает, который он по счёту, а оболочка — нет.

  String _getStepTitle(
    InitialSetupStep step,
    AppLocalizations l10n,
    CountryCode? country,
  ) {
    return switch (step) {
      InitialSetupStep.checking => l10n.setupStepChecking,
      InitialSetupStep.countrySelection => l10n.setupStepCountry,
      InitialSetupStep.organizationSetup => l10n.setupStepOrganization,
      // Название шага — тоже по укладу: в шапке «НДС» на американской
      // кассе выглядело бы как чужой налог.
      InitialSetupStep.vatSelection => TaxStepWords.of(country, l10n).stepTitle,
      InitialSetupStep.employeeSetup => l10n.setupStepUsers,
      InitialSetupStep.posSetup => l10n.setupStepPos,
      InitialSetupStep.fiscalSetup => l10n.setupStepFiscal,
      InitialSetupStep.equipmentSetup => l10n.setupStepEquipment,
      InitialSetupStep.paymentTerminalSetup => l10n.setupStepTerminals,
      InitialSetupStep.operatingModeSelection => l10n.setupStepOperatingMode,
      InitialSetupStep.businessRulesSetup => l10n.setupStepBusinessRules,
      // `setupStepSummary`, а не `setupStepChecking`: тексты у них совпадают,
      // но шаги разные, и подмена жила бы ровно до первой правки перевода.
      InitialSetupStep.summary => l10n.setupStepSummary,
      InitialSetupStep.complete => l10n.setupStepComplete,
      InitialSetupStep.unreadable => l10n.errorCheckFailedGeneric,
    };
  }

  Widget _buildContent(InitialSetupState state) {
    return switch (state.currentStep) {
      InitialSetupStep.checking => const CheckingStep(),
      InitialSetupStep.unreadable => const UnreadableStep(),
      InitialSetupStep.countrySelection => CountryStep(state: state),
      InitialSetupStep.organizationSetup => OrganizationStep(state: state),
      InitialSetupStep.vatSelection => VatStep(state: state),
      InitialSetupStep.operatingModeSelection => OperatingModeStep(
        state: state,
      ),
      InitialSetupStep.employeeSetup => EmployeesStep(state: state),
      InitialSetupStep.posSetup => PosStep(state: state),
      InitialSetupStep.fiscalSetup => FiscalStep(state: state),
      InitialSetupStep.equipmentSetup => EquipmentStep(state: state),
      InitialSetupStep.paymentTerminalSetup => PaymentTerminalStep(
        state: state,
      ),
      InitialSetupStep.businessRulesSetup => BusinessRulesStep(state: state),
      InitialSetupStep.summary => SummaryStep(state: state),
      InitialSetupStep.complete => const CompleteStep(),
    };
  }
}

class _NetworkButton extends StatelessWidget {
  const _NetworkButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.push(AppRoutes.networkSettings),
      icon: const Icon(Icons.wifi),
      tooltip: AppLocalizations.of(context)!.navNetwork,
    );
  }
}
