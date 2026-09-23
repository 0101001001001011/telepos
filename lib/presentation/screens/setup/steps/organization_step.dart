import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/inputs/mask_text_input_formatter.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Шаг организации.
///
/// Было: одна вертикальная лента из шести обведённых рамкой прямоугольников,
/// у каждого своя иконка слева. Стало: три секции с подписями, поля без рамок
/// — границу задаёт секция.
///
/// С 2026-08-04 шаг начинается сразу с первой подписи группы: центрированного
/// заголовка с подзаголовком над формой больше нет.
class OrganizationStep extends ConsumerStatefulWidget {
  const OrganizationStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  ConsumerState<OrganizationStep> createState() => _OrganizationStepState();
}

class _OrganizationStepState extends ConsumerState<OrganizationStep> {
  late final TextEditingController _companyName;
  late final TextEditingController _taxId;
  late final TextEditingController _legalAddress;
  late final TextEditingController _actualAddress;
  late final TextEditingController _contactName;
  late final TextEditingController _phone;
  late final MaskTextInputFormatter _phoneFormatter;

  static String _phoneMask(String? mask) =>
      (mask ?? '+# (###) ###-##-##').replaceAll('#', '_');

  @override
  void initState() {
    super.initState();
    _phoneFormatter = MaskTextInputFormatter(
      mask: widget.state.selectedCountry?.phoneMask ?? '+# (###) ###-##-##',
    );
    // Контроллер живёт ровно столько, сколько виден его шаг, поэтому
    // начальное значение берётся из черновика: иначе возврат на шаг назад и
    // снова вперёд стирал бы уже набранное.
    final org = widget.state.organization;
    _companyName = TextEditingController(text: org.companyName ?? '');
    _taxId = TextEditingController(text: org.taxId ?? '');
    _legalAddress = TextEditingController(text: org.legalAddress ?? '');
    _actualAddress = TextEditingController(text: org.actualAddress ?? '');
    _contactName = TextEditingController(text: org.contactName ?? '');
    _phone = TextEditingController(text: org.phone ?? '');
  }

  @override
  void dispose() {
    _companyName.dispose();
    _taxId.dispose();
    _legalAddress.dispose();
    _actualAddress.dispose();
    _contactName.dispose();
    _phone.dispose();
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
    // Лениво: чтение `.notifier` при построении создаёт контроллер со всеми
    // его таймерами и лишает шаг возможности рисоваться в одиночку.
    InitialSetupNotifier controller() =>
        ref.read(initialSetupControllerProvider.notifier);

    final country = state.selectedCountry;
    final taxIdLength = country?.taxIdLength ?? 12;

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      busy: state.isLoading,
      onNext: () => controller().confirmOrganization(),
      onBack: () => controller().goBack(),
      // Плаката здесь нет: «Данные организации» уже стоит в шапке мастера, а
      // подзаголовок «Введите информацию о вашей компании» не сообщал ничего
      // сверх подписи первой группы, которая так и называется — «Организация».
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupSectionOrganization,
            children: [
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupCompanyNameLabel,
                controller: _companyName,
                hint: l10n.setupCompanyNameHint,
                required: true,
                onChanged: (v) =>
                    controller().updateOrganization(companyName: v),
              ),
              SettingsFieldTile(
                metrics: metrics,
                label: country?.taxIdLabel ?? l10n.setupPhoneLabel,
                controller: _taxId,
                hint: country?.taxIdHint ?? '123456789012',
                required: true,
                helper: l10n.setupTaxIdDigits(taxIdLength),
                // Третий уровень объяснения: ошибка здесь молчит до первой
                // сверки с фискальным сервисом, то есть до момента, когда
                // чеки уже выданы покупателям.
                explanation: l10n.setupTaxIdExplanation,
                keyboardType: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(taxIdLength),
                ],
                onChanged: (v) => controller().updateOrganization(taxId: v),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionAddress,
            children: [
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupLegalAddressLabel,
                controller: _legalAddress,
                onChanged: (v) =>
                    controller().updateOrganization(legalAddress: v),
              ),
              // Адрес торговой точки — ОДНО поле, и оно здесь.
              //
              // 2026-09-21 я завёл второе такое же в разделе «Компания», не
              // заметив этого. Два поля с одной подписью писали в одно
              // значение `actualAddress` разными контроллерами: они не
              // синхронны, и побеждало то, которое тронули последним.
              // Заметил заказчик, глядя на экран.
              //
              // Пояснение переехало сюда: до него адрес выглядел
              // необязательной мелочью, а он печатается на чеке.
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupActualAddressLabel,
                controller: _actualAddress,
                hint: l10n.setupStoreAddressHint,
                helper: l10n.setupStoreAddressHelper,
                onChanged: (v) =>
                    controller().updateOrganization(actualAddress: v),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space24),
          SettingsSection(
            header: l10n.setupSectionContact,
            children: [
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupOwnerNameLabel,
                controller: _contactName,
                onChanged: (v) =>
                    controller().updateOrganization(contactName: v),
              ),
              // Телефон — такая же строка секции, как остальные. Маска здесь
              // форматтер, а не отдельный виджет со своей рамкой: рамку уже
              // задала секция.
              SettingsFieldTile(
                metrics: metrics,
                label: l10n.setupPhoneLabel,
                controller: _phone,
                hint: _phoneMask(country?.phoneMask),
                keyboardType: TextInputType.phone,
                formatters: [_phoneFormatter],
                onChanged: (_) => controller().updateOrganization(
                  phone: _phoneFormatter.getUnmaskedText(),
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
