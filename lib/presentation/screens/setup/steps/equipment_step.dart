import 'package:flutter/material.dart';
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
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Шаг оборудования: четыре устройства, каждое за своим переключателем.
///
/// Выключенное устройство не показывает ни одного поля. Раньше экран
/// перечислял настройки железа, которого на кассе нет, и человек читал
/// вопросы, на которые не мог ответить.
class EquipmentStep extends ConsumerStatefulWidget {
  const EquipmentStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  ConsumerState<EquipmentStep> createState() => _EquipmentStepState();
}

class _EquipmentStepState extends ConsumerState<EquipmentStep> {
  late final TextEditingController _printerAddress;
  late final TextEditingController _printerName;
  late final TextEditingController _scalePort;
  late final TextEditingController _customerDisplayPort;

  @override
  void initState() {
    super.initState();
    final eq = widget.state.equipmentConfig;
    _printerAddress = TextEditingController(text: eq.printerAddress ?? '');
    _printerName = TextEditingController(text: eq.printerName ?? '');
    _scalePort = TextEditingController(text: eq.scalePort ?? '');
    _customerDisplayPort = TextEditingController(
      text: eq.customerDisplayPort ?? '',
    );
  }

  @override
  void dispose() {
    _printerAddress.dispose();
    _printerName.dispose();
    _scalePort.dispose();
    _customerDisplayPort.dispose();
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

    final eq = state.equipmentConfig;
    // У проводного подключения адреса не существует. Поле «IP-адрес» рядом с
    // USB-принтером — вопрос, на который нет правильного ответа.
    final printerNeedsAddress =
        eq.printerConnectionType == PrinterConnectionType.wifi ||
        eq.printerConnectionType == PrinterConnectionType.bluetooth;

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      onNext: () => controller().confirmEquipmentConfig(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Оборудование» стоит в шапке мастера, а
      // четыре группы ниже сами называют, что настраивается.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupEquipmentPrinter,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupEquipmentPrinter,
                value: eq.printerEnabled,
                onChanged: (v) =>
                    controller().updateEquipmentConfig(printerEnabled: v),
              ),
              if (eq.printerEnabled) ...[
                SettingsTile(
                  metrics: metrics,
                  title: l10n.setupConnectionTypeLabel,
                  trailing: DropdownButton<PrinterConnectionType>(
                    value:
                        eq.printerConnectionType == PrinterConnectionType.none
                        ? PrinterConnectionType.usb
                        : eq.printerConnectionType,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: PrinterConnectionType.usb,
                        child: Text(l10n.setupConnectionUsb),
                      ),
                      DropdownMenuItem(
                        value: PrinterConnectionType.bluetooth,
                        child: Text(l10n.setupConnectionBluetooth),
                      ),
                      DropdownMenuItem(
                        value: PrinterConnectionType.wifi,
                        child: Text(l10n.setupConnectionWifi),
                      ),
                      DropdownMenuItem(
                        value: PrinterConnectionType.serial,
                        child: Text(l10n.setupConnectionSerial),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        controller().updateEquipmentConfig(
                          printerConnectionType: v,
                        );
                      }
                    },
                  ),
                ),
                if (printerNeedsAddress)
                  SettingsFieldTile(
                    metrics: metrics,
                    label:
                        eq.printerConnectionType == PrinterConnectionType.wifi
                        ? l10n.setupPrinterIpLabel
                        : l10n.setupPrinterMacLabel,
                    controller: _printerAddress,
                    hint: eq.printerConnectionType == PrinterConnectionType.wifi
                        ? '192.168.1.100'
                        : 'AA:BB:CC:DD:EE:FF',
                    onChanged: (v) =>
                        controller().updateEquipmentConfig(printerAddress: v),
                  ),
                SettingsFieldTile(
                  metrics: metrics,
                  label: l10n.setupPrinterNameLabel,
                  controller: _printerName,
                  hint: l10n.setupPrinterNameHint,
                  onChanged: (v) =>
                      controller().updateEquipmentConfig(printerName: v),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionScanner,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupEquipmentScanner,
                value: eq.scannerEnabled,
                onChanged: (v) =>
                    controller().updateEquipmentConfig(scannerEnabled: v),
              ),
              if (eq.scannerEnabled)
                SettingsTile(
                  metrics: metrics,
                  title: l10n.setupScannerTypeLabel,
                  trailing: DropdownButton<ScannerConnectionType>(
                    value:
                        eq.scannerConnectionType == ScannerConnectionType.none
                        ? ScannerConnectionType.camera
                        : eq.scannerConnectionType,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: ScannerConnectionType.camera,
                        child: Text(l10n.setupScannerCamera),
                      ),
                      DropdownMenuItem(
                        value: ScannerConnectionType.usb,
                        child: Text(l10n.setupScannerUsb),
                      ),
                      DropdownMenuItem(
                        value: ScannerConnectionType.bluetooth,
                        child: Text(l10n.setupScannerBluetooth),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        controller().updateEquipmentConfig(
                          scannerConnectionType: v,
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionScale,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupEquipmentScales,
                value: eq.scaleEnabled,
                onChanged: (v) =>
                    controller().updateEquipmentConfig(scaleEnabled: v),
              ),
              if (eq.scaleEnabled)
                SettingsFieldTile(
                  metrics: metrics,
                  label: l10n.setupScalePortLabel,
                  controller: _scalePort,
                  hint: 'COM1',
                  onChanged: (v) =>
                      controller().updateEquipmentConfig(scalePort: v),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionDisplay,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupEquipmentDisplay,
                value: eq.customerDisplayEnabled,
                onChanged: (v) => controller().updateEquipmentConfig(
                  customerDisplayEnabled: v,
                ),
              ),
              if (eq.customerDisplayEnabled)
                SettingsFieldTile(
                  metrics: metrics,
                  label: l10n.setupDisplayPortLabel,
                  controller: _customerDisplayPort,
                  hint: 'COM2',
                  onChanged: (v) => controller().updateEquipmentConfig(
                    customerDisplayPort: v,
                  ),
                ),
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupEquipmentCashDrawer,
                subtitle: l10n.setupCashDrawerConnectedDesc,
                value: eq.cashDrawerEnabled,
                onChanged: (v) =>
                    controller().updateEquipmentConfig(cashDrawerEnabled: v),
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
