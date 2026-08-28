import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_switch_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Шаг правил работы кассы.
///
/// Права и лимиты — переключателями; поле ставки кэшбэка раскрывается только
/// когда кэшбэк включён.
class BusinessRulesStep extends ConsumerStatefulWidget {
  const BusinessRulesStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  ConsumerState<BusinessRulesStep> createState() => _BusinessRulesStepState();
}

class _BusinessRulesStepState extends ConsumerState<BusinessRulesStep> {
  late final TextEditingController _cashbackRate;
  late final TextEditingController _cashWithdrawalLimit;

  @override
  void initState() {
    super.initState();
    final rules = widget.state.businessRulesConfig;
    _cashbackRate = TextEditingController(text: '${rules.cashbackRate}');
    _cashWithdrawalLimit = TextEditingController(
      text: rules.cashWithdrawalLimit ?? '',
    );
  }

  @override
  void dispose() {
    _cashbackRate.dispose();
    _cashWithdrawalLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = AppLocalizations.of(context)!;
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );
    InitialSetupNotifier controller() =>
        ref.read(initialSetupControllerProvider.notifier);

    final rules = state.businessRulesConfig;

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      onNext: () => controller().confirmBusinessRulesConfig(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Правила» стоит в шапке мастера, а три
      // группы ниже — «Разрешения», «Ограничения», «Лояльность» — называют
      // себя сами.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupPermissionsTitle,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupAllowDiscounts,
                subtitle: l10n.setupAllowDiscountsDesc,
                value: rules.allowDiscounts,
                onChanged: (v) =>
                    controller().updateBusinessRulesConfig(allowDiscounts: v),
              ),
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupAllowPriceEdit,
                subtitle: l10n.setupAllowPriceEditDesc,
                value: rules.allowPriceEdit,
                onChanged: (v) =>
                    controller().updateBusinessRulesConfig(allowPriceEdit: v),
              ),
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupBlockPriceDecrease,
                subtitle: l10n.setupBlockPriceDecreaseDesc,
                value: rules.blockPriceDecrease,
                onChanged: (v) => controller().updateBusinessRulesConfig(
                  blockPriceDecrease: v,
                ),
              ),
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupAllowDebtSales,
                subtitle: l10n.setupAllowDebtSalesDesc,
                value: rules.allowDebtSales,
                onChanged: (v) =>
                    controller().updateBusinessRulesConfig(allowDebtSales: v),
              ),
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupAllowCashInOut,
                subtitle: l10n.setupAllowCashInOutDesc,
                value: rules.allowCashInOut,
                onChanged: (v) =>
                    controller().updateBusinessRulesConfig(allowCashInOut: v),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupLimitsTitle,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupAllowBigAmount,
                subtitle: l10n.setupAllowBigAmountDesc,
                value: rules.allowBigAmount,
                onChanged: (v) =>
                    controller().updateBusinessRulesConfig(allowBigAmount: v),
              ),
              if (rules.allowBigAmount)
                SettingsFieldTile(
                  metrics: metrics,
                  label: l10n.setupCashWithdrawalLimitLabel,
                  controller: _cashWithdrawalLimit,
                  helper: l10n.setupCashWithdrawalLimitHelper,
                  keyboardType: TextInputType.number,
                  // Сумма хранится строкой и разбирается Decimal'ом выше по
                  // слою: double для денег в проекте запрещён.
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => controller().updateBusinessRulesConfig(
                    cashWithdrawalLimit: v,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupLoyaltyTitle,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupCashbackLabel,
                subtitle: l10n.setupCashbackDesc,
                value: rules.cashbackEnabled,
                onChanged: (v) =>
                    controller().updateBusinessRulesConfig(cashbackEnabled: v),
              ),
              if (rules.cashbackEnabled)
                SettingsFieldTile(
                  metrics: metrics,
                  label: l10n.setupCashbackRateLabel,
                  controller: _cashbackRate,
                  helper: '%',
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onChanged: (v) => controller().updateBusinessRulesConfig(
                    cashbackRate: int.tryParse(v) ?? 0,
                  ),
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
