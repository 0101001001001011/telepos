import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_switch_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Шаг фискализации.
///
/// Реквизиты фискального сервиса — тот случай, где ошибка молчит: касса
/// работает, чеки печатаются, а расхождение всплывает при первой сверке.
/// Поэтому у таких полей есть объяснение по требованию.
class FiscalStep extends ConsumerStatefulWidget {
  const FiscalStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  ConsumerState<FiscalStep> createState() => _FiscalStepState();
}

class _FiscalStepState extends ConsumerState<FiscalStep> {
  late final TextEditingController _wkAccountId;
  late final TextEditingController _wkAccountToken;
  late final TextEditingController _wkPosId;
  late final TextEditingController _wkPosToken;
  late final TextEditingController _wkPosFactoryNo;
  late final TextEditingController _ofdInn;
  late final TextEditingController _ofdKktRegNo;
  late final TextEditingController _ofdFnNo;
  late final TextEditingController _ofdUrl;

  @override
  void initState() {
    super.initState();
    final f = widget.state.fiscalConfig;
    _wkAccountId = TextEditingController(text: f.wkAccountId ?? '');
    _wkAccountToken = TextEditingController(text: f.wkAccountToken ?? '');
    _wkPosId = TextEditingController(text: f.wkPosId ?? '');
    _wkPosToken = TextEditingController(text: f.wkPosToken ?? '');
    _wkPosFactoryNo = TextEditingController(text: f.wkPosFactoryNo ?? '');
    _ofdInn = TextEditingController(text: f.ofdInn ?? '');
    _ofdKktRegNo = TextEditingController(text: f.ofdKktRegNo ?? '');
    _ofdFnNo = TextEditingController(text: f.ofdFnNo ?? '');
    _ofdUrl = TextEditingController(text: f.ofdUrl ?? '');
  }

  @override
  void dispose() {
    _wkAccountId.dispose();
    _wkAccountToken.dispose();
    _wkPosId.dispose();
    _wkPosToken.dispose();
    _wkPosFactoryNo.dispose();
    _ofdInn.dispose();
    _ofdKktRegNo.dispose();
    _ofdFnNo.dispose();
    _ofdUrl.dispose();
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

    final config = state.fiscalConfig;
    // Протокол спрашивается у СТРАНЫ. Здесь стояла вторая таблица
    // «страна → оператор», и она разошлась с признаком `hasFiscalisation`:
    // девять стран объявляли фискализацию, а мастер предлагал оператора
    // двум. Чек при этом печатал фискальный блок у всех девяти.
    final availableFiscalType =
        (state.selectedCountry ?? CountryCode.kzt).fiscalProtocol;
    final notRequired = availableFiscalType == FiscalType.none;
    final skipping = !notRequired && !config.enabled;

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      // Кнопка «Пропустить» переехала из середины экрана в подпись основной:
      // две кнопки подряд, «Далее» и «Пропустить», заставляли выбирать между
      // синонимами.
      nextLabel: skipping ? l10n.setupSkipLater : null,
      onNext: () => skipping
          ? controller().skipFiscalSetup()
          : controller().confirmFiscalConfig(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Фискализация» стоит в шапке мастера и
      // подписью первой группы.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notRequired)
            SettingsSection(
              header: l10n.setupStepFiscal,
              footer: l10n.setupFiscalNotRequired,
              children: const [],
            )
          else ...[
            SettingsSection(
              header: l10n.setupStepFiscal,
              children: [
                SettingsSwitchTile(
                  metrics: metrics,
                  title: availableFiscalType == FiscalType.webkassa
                      ? l10n.setupEnableWebkassa
                      : l10n.setupEnableOfd,
                  subtitle: availableFiscalType == FiscalType.webkassa
                      ? l10n.setupWebkassaDescription
                      : l10n.setupOfdDescription,
                  value: config.enabled,
                  onChanged: (v) => controller().updateFiscalConfig(
                    enabled: v,
                    fiscalType: v ? availableFiscalType : FiscalType.none,
                  ),
                ),
              ],
            ),
            if (config.enabled &&
                availableFiscalType == FiscalType.webkassa) ...[
              const SizedBox(height: AppTokens.space24),
              SettingsSection(
                header: l10n.setupWebkassaAccountTitle,
                children: [
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupWebkassaAccountIdLabel,
                    controller: _wkAccountId,
                    hint: l10n.setupWebkassaAccountIdHint,
                    required: true,
                    explanation: l10n.setupFiscalCredentialsExplanation,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(wkAccountId: v),
                  ),
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupWebkassaTokenLabel,
                    controller: _wkAccountToken,
                    hint: l10n.setupWebkassaTokenHint,
                    required: true,
                    obscure: true,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(wkAccountToken: v),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space24),
              SettingsSection(
                header: l10n.setupWebkassaPosTitle,
                children: [
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupWebkassaPosIdLabel,
                    controller: _wkPosId,
                    hint: l10n.setupWebkassaPosIdHint,
                    required: true,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(wkPosId: v),
                  ),
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupWebkassaPosTokenLabel,
                    controller: _wkPosToken,
                    hint: l10n.setupWebkassaPosTokenHint,
                    required: true,
                    obscure: true,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(wkPosToken: v),
                  ),
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupWebkassaFactoryNoLabel,
                    controller: _wkPosFactoryNo,
                    hint: 'SN12345678',
                    explanation: l10n.setupKktNumberExplanation,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(wkPosFactoryNo: v),
                  ),
                ],
              ),
            ],
            if (config.enabled && availableFiscalType == FiscalType.ofd) ...[
              const SizedBox(height: AppTokens.space24),
              SettingsSection(
                header: l10n.setupOfdParamsTitle,
                children: [
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupOfdInnLabel,
                    controller: _ofdInn,
                    required: true,
                    explanation: l10n.setupFiscalCredentialsExplanation,
                    keyboardType: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    onChanged: (v) =>
                        controller().updateFiscalConfig(ofdInn: v),
                  ),
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupOfdKktRegNoLabel,
                    controller: _ofdKktRegNo,
                    required: true,
                    explanation: l10n.setupKktNumberExplanation,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(ofdKktRegNo: v),
                  ),
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupOfdFnNoLabel,
                    controller: _ofdFnNo,
                    required: true,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(ofdFnNo: v),
                  ),
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupOfdUrlLabel,
                    controller: _ofdUrl,
                    keyboardType: TextInputType.url,
                    onChanged: (v) =>
                        controller().updateFiscalConfig(ofdUrl: v),
                  ),
                ],
              ),
            ],
          ],
          if (state.hasError)
            WizardErrorNote(
              message: ErrorLocalizer.localize(context, state.error!),
            ),
        ],
      ),
    );
  }
}
