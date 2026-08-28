import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Шаг платёжного терминала.
///
/// Адрес и порт показываются только у включённого терминала: настройки
/// железа, которого на кассе нет, — это вопросы без правильного ответа.
class PaymentTerminalStep extends ConsumerStatefulWidget {
  const PaymentTerminalStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  ConsumerState<PaymentTerminalStep> createState() =>
      _PaymentTerminalStepState();
}

class _PaymentTerminalStepState extends ConsumerState<PaymentTerminalStep> {
  late final TextEditingController _kaspiIp;
  late final TextEditingController _kaspiPort;

  @override
  void initState() {
    super.initState();
    final config = widget.state.paymentTerminalConfig;
    _kaspiIp = TextEditingController(text: config.kaspiTerminalIp ?? '');
    _kaspiPort = TextEditingController(text: '${config.kaspiTerminalPort}');
  }

  @override
  void dispose() {
    _kaspiIp.dispose();
    _kaspiPort.dispose();
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

    final config = state.paymentTerminalConfig;
    final showKaspi = state.selectedCountry == CountryCode.kzt;

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      onNext: () => controller().confirmPaymentTerminalConfig(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Терминалы» стоит в шапке мастера и подписью
      // группы.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!showKaspi)
            SettingsSection(
              header: l10n.setupSectionTerminal,
              footer: l10n.setupNoTerminalsAvailable,
              children: const [],
            )
          else
            SettingsSection(
              header: l10n.setupSectionTerminal,
              children: [
                SettingsSwitchTile(
                  metrics: metrics,
                  title: 'Kaspi POS',
                  value: config.kaspiEnabled,
                  onChanged: (v) =>
                      controller().updatePaymentTerminalConfig(kaspiEnabled: v),
                ),
                if (config.kaspiEnabled) ...[
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupKaspiIpLabel,
                    controller: _kaspiIp,
                    hint: '192.168.1.100',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => controller().updatePaymentTerminalConfig(
                      kaspiTerminalIp: v,
                    ),
                  ),
                  SettingsFieldTile(
                    metrics: metrics,
                    label: l10n.setupPortLabel,
                    controller: _kaspiPort,
                    hint: '9999',
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => controller().updatePaymentTerminalConfig(
                      // Пустое поле не превращается в ноль: порт 0 не
                      // существует, и молча подставленный он привёл бы к
                      // необъяснимому отказу связи.
                      kaspiTerminalPort: int.tryParse(v) ?? 9999,
                    ),
                  ),
                ],
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
