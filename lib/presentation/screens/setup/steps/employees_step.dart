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

/// Шаг сотрудников: кто будет работать на кассе и под каким кодом входить.
class EmployeesStep extends ConsumerStatefulWidget {
  const EmployeesStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  ConsumerState<EmployeesStep> createState() => _EmployeesStepState();
}

class _EmployeesStepState extends ConsumerState<EmployeesStep> {
  late final TextEditingController _userName;
  late final TextEditingController _pin;
  late final TextEditingController _pinConfirm;
  late final TextEditingController _sellerName;
  late final TextEditingController _sellerPin;

  bool _createSecondUser = false;
  bool _defaultsInitialized = false;

  @override
  void initState() {
    super.initState();
    final first = widget.state.firstUser;
    final second = widget.state.secondUser;
    _userName = TextEditingController(text: first.name ?? '');
    // Коды начинаются пустыми. Прежние 0000 и 1111 подставлялись сами и почти
    // всегда оставались как есть — код, который предложила касса и который
    // знает каждый, кто видел такую же кассу, это отсутствие кода.
    _pin = TextEditingController(text: first.pin ?? '');
    _pinConfirm = TextEditingController(text: first.pin ?? '');
    _sellerName = TextEditingController(text: second?.name ?? '');
    _sellerPin = TextEditingController(text: second?.pin ?? '');
    _createSecondUser = second != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Имя по умолчанию берётся из локализации, а она доступна только здесь.
    // Ставится один раз и только поверх пустого.
    if (_defaultsInitialized) return;
    _defaultsInitialized = true;

    final defaultName = AppLocalizations.of(context)!.loginAdmin;
    if (_userName.text.isNotEmpty) return;
    _userName.text = defaultName;

    // Черновик правится после кадра, а не внутри него: Riverpod запрещает
    // менять провайдер во время построения дерева, и это не придирка — два
    // виджета, слушающие один провайдер, увидели бы разное состояние.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(initialSetupControllerProvider.notifier)
          .updateFirstUser(name: defaultName);
    });
  }

  @override
  void dispose() {
    _userName.dispose();
    _pin.dispose();
    _pinConfirm.dispose();
    _sellerName.dispose();
    _sellerPin.dispose();
    super.dispose();
  }

  /// Код короче четырёх цифр или не совпавшее подтверждение — не «предупредить
  /// и пустить», а «не пустить»: иначе касса заводится с кодом, которого
  /// владелец не набирал.
  bool get _pinLooksUsable =>
      _pin.text.length >= 4 && _pin.text == _pinConfirm.text;

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

    final mismatch =
        _pinConfirm.text.isNotEmpty && _pin.text != _pinConfirm.text;

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      nextEnabled: _pinLooksUsable && _userName.text.trim().isNotEmpty,
      onNext: () => controller().confirmUsers(),
      onBack: () => controller().goBack(),
      // Заголовка по центру нет: «Пользователи» стоит в шапке мастера, а
      // «Создайте пользователей для работы с кассой» ничего не добавляло к
      // подписи первой группы — «Кто будет работать».
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupSectionUsers,
            children: [
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupUserNameLabel,
                controller: _userName,
                required: true,
                onChanged: (v) {
                  controller().updateFirstUser(name: v);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionSecurity,
            footer: l10n.setupAdminSubtitle,
            children: [
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupUserPinLabel,
                controller: _pin,
                required: true,
                obscure: true,
                keyboardType: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (v) {
                  controller().updateFirstUser(pin: v);
                  setState(() {});
                },
              ),
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupUserPinConfirmLabel,
                controller: _pinConfirm,
                required: true,
                obscure: true,
                keyboardType: TextInputType.number,
                errorText: mismatch ? l10n.setupAdminPinMismatch : null,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            footer: l10n.setupSellerOptional,
            children: [
              SettingsSwitchTile(
                metrics: metrics,
                title: l10n.setupSellerLabel,
                value: _createSecondUser,
                onChanged: (v) {
                  setState(() => _createSecondUser = v);
                  if (!v) {
                    controller().updateSecondUser(name: '', pin: '');
                  }
                },
              ),
              if (_createSecondUser) ...[
                SettingsFieldTile(
                  metrics: metrics,
                  label: l10n.setupUserNameLabel,
                  controller: _sellerName,
                  onChanged: (v) => controller().updateSecondUser(name: v),
                ),
                SettingsFieldTile(
                  metrics: metrics,
                  label: l10n.setupUserPinLabel,
                  controller: _sellerPin,
                  obscure: true,
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (v) => controller().updateSecondUser(pin: v),
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
