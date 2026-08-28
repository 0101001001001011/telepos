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
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Шаг кассы: как она называется и что печатает.
class PosStep extends ConsumerStatefulWidget {
  const PosStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  ConsumerState<PosStep> createState() => _PosStepState();
}

class _PosStepState extends ConsumerState<PosStep> {
  late final TextEditingController _cashBoxName;
  late final TextEditingController _posId;
  late final TextEditingController _printerHeader;
  late final TextEditingController _printerFooter;

  @override
  void initState() {
    super.initState();
    // Начальное значение — из черновика: шаг пересоздаётся при каждом
    // возврате, и без этого набранное стёрлось бы молча.
    final pos = widget.state.posConfig;
    _cashBoxName = TextEditingController(text: pos.cashBoxName ?? '');
    _posId = TextEditingController(text: pos.posId ?? 'POS-1');
    _printerHeader = TextEditingController(text: pos.printerHeader ?? '');
    _printerFooter = TextEditingController(text: pos.printerFooter ?? '');
  }

  @override
  void dispose() {
    _cashBoxName.dispose();
    _posId.dispose();
    _printerHeader.dispose();
    _printerFooter.dispose();
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

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      onNext: () => controller().confirmPosConfig(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Касса» стоит в шапке мастера и подписью
      // первой группы. «Укажите параметры кассового аппарата» — тот же текст
      // третьим кеглем.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupSectionCashBox,
            children: [
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupCashBoxNameLabel,
                controller: _cashBoxName,
                hint: l10n.setupCashBoxNameHint,
                required: true,
                onChanged: (v) => controller().updatePosConfig(cashBoxName: v),
              ),
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupPosIdLabel,
                controller: _posId,
                hint: 'POS-1',
                onChanged: (v) => controller().updatePosConfig(posId: v),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupPrinterConfigTitle,
            children: [
              SettingsTile(
                metrics: metrics,
                title: l10n.setupPaperWidthLabel,
                trailing: DropdownButton<int>(
                  value: state.posConfig.paperWidth,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 32,
                      child: Text(l10n.setupPaperWidth58),
                    ),
                    DropdownMenuItem(
                      value: 48,
                      child: Text(l10n.setupPaperWidth80),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) controller().updatePosConfig(paperWidth: v);
                  },
                ),
              ),
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupPrinterHeaderLabel,
                controller: _printerHeader,
                hint: l10n.setupPrinterHeaderHint,
                maxLines: 3,
                onChanged: (v) =>
                    controller().updatePosConfig(printerHeader: v),
              ),
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupPrinterFooterLabel,
                controller: _printerFooter,
                hint: l10n.setupPrinterFooterHint,
                maxLines: 2,
                onChanged: (v) =>
                    controller().updatePosConfig(printerFooter: v),
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
