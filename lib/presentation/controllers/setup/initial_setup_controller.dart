import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/logging/setup_logger.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/presentation/controllers/startup/startup_state_provider.dart';

// The wizard's value objects moved to the contract layer; the screens consume
// them through this controller, so they keep reaching them here.
export 'package:telepos/domain/setup/setup_draft.dart';

/// What asking the till "are you configured?" concluded.
///
/// Three values because there are three answers. See
/// [InitialSetupStep.unreadable].
enum _ConfigurationProbe { configured, notConfigured, unreadable }

enum InitialSetupStep {
  checking,

  countrySelection,

  organizationSetup,

  vatSelection,

  employeeSetup,

  operatingModeSelection,

  posSetup,

  fiscalSetup,

  equipmentSetup,

  paymentTerminalSetup,

  businessRulesSetup,

  summary,

  complete,

  /// The till could not be asked whether it is configured.
  ///
  /// A third state, and it has to exist. Without it the only answers available
  /// were "configured" and "not configured", so an unreachable or broken
  /// backend was reported as **not configured** — and that is the answer that
  /// offers to run the setup wizard over a working shop.
  ///
  /// Seen for real on 2026-08-02: a till whose database failed to open
  /// answered `/api/setup/state` with HTTP 500 and the body `Internal Server
  /// Error`; the browser client could not parse it, swallowed the failure and
  /// walked on to the wizard. Nothing was lost only because nobody pressed
  /// anything.
  unreadable,
}

@immutable
class InitialSetupState {
  const InitialSetupState({
    this.currentStep = InitialSetupStep.checking,
    this.isLoading = false,
    this.error,
    this.selectedCountry = CountryCode.kzt,
    this.organization = const OrganizationInfo(),
    this.posConfig = const PosConfigInfo(),
    this.fiscalConfig = const FiscalConfigInfo(),
    this.equipmentConfig = const EquipmentConfigInfo(),
    this.paymentTerminalConfig = const PaymentTerminalConfigInfo(),
    this.businessRulesConfig = const BusinessRulesConfigInfo(),
    this.employees = const [],
    this.operatingMode = OperatingMode.retail,
    this.firstUser = const EmployeeInfo(),
    this.secondUser,
    this.telegramConfigured = false,
  });

  final InitialSetupStep currentStep;

  final bool isLoading;

  final String? error;

  final CountryCode? selectedCountry;

  final OrganizationInfo organization;

  final PosConfigInfo posConfig;

  final FiscalConfigInfo fiscalConfig;

  final EquipmentConfigInfo equipmentConfig;

  final PaymentTerminalConfigInfo paymentTerminalConfig;

  final BusinessRulesConfigInfo businessRulesConfig;

  final List<EmployeeInfo> employees;

  final OperatingMode operatingMode;

  final EmployeeInfo firstUser;

  final EmployeeInfo? secondUser;

  final bool telegramConfigured;

  bool get isAllDataComplete {
    final userOk = employees.isNotEmpty
        ? employees.first.isComplete
        : firstUser.isComplete;
    return organization.isComplete &&
        posConfig.isComplete &&
        fiscalConfig.isComplete &&
        equipmentConfig.isComplete &&
        paymentTerminalConfig.isComplete &&
        businessRulesConfig.isComplete &&
        userOk;
  }

  bool get hasError => error != null;

  bool get isComplete => currentStep == InitialSetupStep.complete;

  /// Порядок шагов мастера — тот же, по которому идут переходы в
  /// [InitialSetupNotifier]. Один список вместо двух веток нумерации: ветка
  /// «у пользователя уже есть учётка» существовала только ради Go-бэкенда.
  static const List<InitialSetupStep> orderedSteps = [
    InitialSetupStep.countrySelection,
    InitialSetupStep.organizationSetup,
    InitialSetupStep.vatSelection,
    InitialSetupStep.employeeSetup,
    InitialSetupStep.operatingModeSelection,
    InitialSetupStep.posSetup,
    InitialSetupStep.fiscalSetup,
    InitialSetupStep.equipmentSetup,
    InitialSetupStep.paymentTerminalSetup,
    InitialSetupStep.businessRulesSetup,
    InitialSetupStep.summary,
  ];

  /// Номер шага для рельса прогресса. Ноль означает «вне нумерации»:
  /// [InitialSetupStep.checking] и [InitialSetupStep.unreadable] рельса не
  /// показывают.
  int get stepNumber {
    if (currentStep == InitialSetupStep.complete) {
      return orderedSteps.length + 1;
    }
    final index = orderedSteps.indexOf(currentStep);
    return index == -1 ? 0 : index + 1;
  }

  int get totalSteps => orderedSteps.length;

  InitialSetupState copyWith({
    InitialSetupStep? currentStep,
    bool? isLoading,
    String? error,
    bool clearError = false,
    CountryCode? selectedCountry,
    OrganizationInfo? organization,
    PosConfigInfo? posConfig,
    FiscalConfigInfo? fiscalConfig,
    EquipmentConfigInfo? equipmentConfig,
    PaymentTerminalConfigInfo? paymentTerminalConfig,
    BusinessRulesConfigInfo? businessRulesConfig,
    List<EmployeeInfo>? employees,
    OperatingMode? operatingMode,
    EmployeeInfo? firstUser,
    EmployeeInfo? secondUser,
    bool clearSecondUser = false,
    bool? telegramConfigured,
  }) {
    return InitialSetupState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedCountry: selectedCountry ?? this.selectedCountry,
      organization: organization ?? this.organization,
      posConfig: posConfig ?? this.posConfig,
      fiscalConfig: fiscalConfig ?? this.fiscalConfig,
      equipmentConfig: equipmentConfig ?? this.equipmentConfig,
      paymentTerminalConfig:
          paymentTerminalConfig ?? this.paymentTerminalConfig,
      businessRulesConfig: businessRulesConfig ?? this.businessRulesConfig,
      employees: employees ?? this.employees,
      operatingMode: operatingMode ?? this.operatingMode,
      firstUser: firstUser ?? this.firstUser,
      secondUser: clearSecondUser ? null : (secondUser ?? this.secondUser),
      telegramConfigured: telegramConfigured ?? this.telegramConfigured,
    );
  }
}

class InitialSetupNotifier extends Notifier<InitialSetupState> {
  /// Шаги, которыми распоряжается ответ кассы, а не человек.
  ///
  /// На них мастер стоит ровно потому, что так сказала касса, — и если касса
  /// скажет иначе, он обязан послушаться. На всех остальных шагах человек уже
  /// что-то ввёл, и новость с кассы не имеет права его оттуда сдвинуть: он
  /// потерял бы введённое, а мастер выглядел бы сломанным.
  ///
  /// [InitialSetupStep.complete] здесь потому, что обратный ход тоже бывает:
  /// касса, переставшая быть настроенной (восстановление, сброс), обязана
  /// вернуть мастер к настройке, а не оставить его с надписью «готово».
  static const Set<InitialSetupStep> _tillOwnedSteps = {
    InitialSetupStep.checking,
    InitialSetupStep.unreadable,
    InitialSetupStep.countrySelection,
    InitialSetupStep.complete,
  };

  @override
  InitialSetupState build() {
    // Живая подписка вместо `startup.watch().first`.
    //
    // Раньше состояние кассы бралось одним значением, и подписка снималась
    // сразу же. Отсюда брался тупик: касса не ответила — мастер показывал
    // [UnreadableStep] с единственной кнопкой «повторить», и выйти оттуда
    // можно было только вопросом со своей стороны. Теперь касса, которая
    // ответила позже, выводит экран из тупика сама — ради этого и менялся
    // транспорт.
    //
    // `ref.listen`, а не `ref.watch`: `watch` перестраивал бы весь
    // [InitialSetupState] на каждую новость с кассы и стирал введённое
    // человеком. Новость приходит в [_applyTillState], и он сам решает, имеет
    // ли право двигать текущий шаг.
    //
    // Подписка снимается вместе с этим провайдером — см. доку
    // `startup_state_provider.dart` про то, почему она `autoDispose` и как
    // снятие доходит до кассы.
    ref.listen<AsyncValue<SetupState>>(
      startupStateProvider,
      (_, next) => _applyTillState(next),
    );

    Future.microtask(() async {
      await SetupLogger.init();
      if (!ref.mounted) return;
      SetupLogger.info('InitialSetupNotifier.build() called');
      await _checkInitialState();
    });
    return const InitialSetupState();
  }

  /// Проверка состояния кассы асинхронна и переживает сам экран.
  ///
  /// Если провайдер успели выбросить, пока она шла, запись в [state] бросает
  /// «Cannot use the Ref after it has been disposed». Проверка живости стоит
  /// после каждого промежутка ожидания — а не один раз в начале, — потому что
  /// выбросить провайдер могли в любом из них.
  Future<void> _checkInitialState() async {
    if (!ref.mounted) return;
    SetupLogger.info('_checkInitialState: начало проверки...');
    state = state.copyWith(
      currentStep: InitialSetupStep.checking,
      isLoading: true,
    );

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!ref.mounted) return;

      // Берётся то, что подписка уже успела принести; всё остальное доедет
      // само через `ref.listen` из [build].
      //
      // Ждать здесь «первого значения» нельзя, и это измерено: `Stream.first`
      // завершается не по приходу значения, а по завершению будущего ОТМЕНЫ
      // (`dart:async`, `_cancelAndValue`), а отмена подписки drift под
      // `pumpAndSettle` не завершается. Экран получал значение и оставался с
      // крутящимся индикатором навсегда — в поле это белый экран со спиннером.
      _applyTillState(ref.read(startupStateProvider));
    } catch (e, stack) {
      SetupLogger.error('_checkInitialState FAILED', e, stack);
      if (!ref.mounted) return;
      state = state.copyWith(
        error: 'error.check_failed:${safeErrorText(e)}',
        // A failure here used to land on the wizard's first screen. That
        // screen was `authChoice` until the account steps were removed; the
        // hazard was never the screen, it was treating "could not ask" as
        // "nothing is here".
        currentStep: InitialSetupStep.unreadable,
        isLoading: false,
      );
    }
  }

  /// Что мастер делает с очередной новостью о состоянии кассы.
  ///
  /// Раньше на её месте был `_probeConfiguration()` — один вопрос и один
  /// ответ. Разница не в форме: пришедшее сюда **второй раз** и есть вся
  /// выгода нового транспорта. Касса, ответившая с опозданием, выводит мастер
  /// из тупика [InitialSetupStep.unreadable] сама; магазин, настроенный с
  /// другого терминала, уводит мастер с предложения настроить его заново — и
  /// ни то, ни другое не ждёт нажатия.
  void _applyTillState(AsyncValue<SetupState> answer) {
    if (!ref.mounted) return;

    final probe = _probeOf(answer);
    if (probe == null) {
      // Касса не сказала пока ничего. Это не «пусто» и не «сломано»: пусто и
      // сломано — уже сведения, а здесь их нет, и шаг остаётся `checking`.
      return;
    }

    if (!_tillOwnedSteps.contains(state.currentStep)) {
      // Человек уже внутри мастера и что-то ввёл. Сдвинуть его отсюда значило
      // бы стереть введённое; узнать он об этом сможет на итоговом шаге, где
      // настройка и записывается.
      SetupLogger.info(
        '_applyTillState: новость с кассы (${probe.name}) не двигает '
        'шаг ${state.currentStep.name} — на нём работает человек',
      );
      return;
    }

    SetupLogger.info('_applyTillState: probe=${probe.name}');
    switch (probe) {
      case _ConfigurationProbe.configured:
        SetupLogger.info(
          '_applyTillState: система настроена, переход к complete',
        );
        state = state.copyWith(
          currentStep: InitialSetupStep.complete,
          isLoading: false,
          clearError: true,
        );
      case _ConfigurationProbe.notConfigured:
        SetupLogger.info(
          '_applyTillState: система не настроена, начинаем визард',
        );
        state = state.copyWith(
          currentStep: InitialSetupStep.countrySelection,
          isLoading: false,
          clearError: true,
        );
      case _ConfigurationProbe.unreadable:
        // Deliberately NOT the wizard. Not knowing is not the same as knowing
        // there is nothing here, and only one of those two answers can destroy
        // a working shop.
        SetupLogger.error(
          '_applyTillState: состояние прочитать не удалось — '
          'мастер не запускается',
        );
        state = state.copyWith(
          error: 'error.setup_state_unreadable',
          currentStep: InitialSetupStep.unreadable,
          isLoading: false,
        );
    }
  }

  /// Три ответа из [AsyncValue], и `null` — «ответа пока нет».
  ///
  /// The `bool` this replaced answered `false` on every failure — an
  /// unreachable backend, a 500, a body that was not JSON — so "the till did
  /// not answer" and "the till is brand new" were the same value. The screen
  /// then offered to set up a shop that already existed.
  ///
  /// Отказ проверяется ПЕРВЫМ: подписка, оборвавшаяся после нескольких
  /// значений, несёт и последнее значение, и ошибку разом, — и правдой из этих
  /// двух является ошибка. Показать последнее известное значение как текущее
  /// значило бы уверенно показать устаревшее.
  _ConfigurationProbe? _probeOf(AsyncValue<SetupState> answer) {
    if (answer.hasError) {
      SetupLogger.error(
        '_probeOf: не удалось прочитать состояние',
        answer.error,
        answer.stackTrace,
      );
      return _ConfigurationProbe.unreadable;
    }
    final till = answer.value;
    if (till == null) return null;

    SetupLogger.info(
      '_probeOf: configured=${till.configured} hasUsers=${till.hasUsers}',
    );
    return till.configured && till.hasUsers
        ? _ConfigurationProbe.configured
        : _ConfigurationProbe.notConfigured;
  }

  void addEmployee(EmployeeInfo employee) {
    state = state.copyWith(
      employees: [...state.employees, employee],
      clearError: true,
    );
  }

  void removeEmployee(int index) {
    if (index < 0 || index >= state.employees.length) return;
    final list = List<EmployeeInfo>.from(state.employees)..removeAt(index);
    state = state.copyWith(employees: list, clearError: true);
  }

  void updateEmployee(int index, EmployeeInfo employee) {
    if (index < 0 || index >= state.employees.length) return;
    final list = List<EmployeeInfo>.from(state.employees);
    list[index] = employee;
    state = state.copyWith(employees: list, clearError: true);
  }

  void selectCountry(CountryCode country) {
    SetupLogger.info('selectCountry: ${country.name}');
    state = state.copyWith(selectedCountry: country, clearError: true);
  }

  void confirmCountrySelection() {
    SetupLogger.info(
      'confirmCountrySelection: country=${state.selectedCountry?.name}',
    );
    if (state.selectedCountry == null) {
      SetupLogger.warning('confirmCountrySelection: страна не выбрана');
      state = state.copyWith(error: 'error.select_country');
      return;
    }

    SetupLogger.step('countrySelection', 'organizationSetup');
    state = state.copyWith(
      currentStep: InitialSetupStep.organizationSetup,
      clearError: true,
    );
  }

  void markTelegramConfigured() {
    SetupLogger.info('markTelegramConfigured: Telegram авторизован');
    SetupLogger.step('telegramSetup', 'countrySelection');
    state = state.copyWith(
      telegramConfigured: true,
      currentStep: InitialSetupStep.countrySelection,
      clearError: true,
    );
  }

  void skipTelegramSetup() {
    SetupLogger.info('skipTelegramSetup: Telegram пропущен');
    SetupLogger.step('telegramSetup', 'countrySelection');
    state = state.copyWith(
      telegramConfigured: false,
      currentStep: InitialSetupStep.countrySelection,
      clearError: true,
    );
  }

  void updateOrganization({
    String? companyName,
    String? legalName,
    String? taxId,
    String? legalAddress,
    String? actualAddress,
    String? phone,
    String? email,
    String? contactName,
    String? description,
    bool? isVatPayer,
  }) {
    state = state.copyWith(
      organization: state.organization.copyWith(
        companyName: companyName,
        legalName: legalName,
        taxId: taxId,
        legalAddress: legalAddress,
        actualAddress: actualAddress,
        phone: phone,
        email: email,
        contactName: contactName,
        description: description,
        isVatPayer: isVatPayer,
      ),
      clearError: true,
    );
  }

  void confirmOrganization() {
    final country = state.selectedCountry;
    final org = state.organization;

    SetupLogger.info(
      'confirmOrganization: companyName="${org.companyName}", taxId="${org.taxId}", country=${country?.name}',
    );

    if (org.companyName == null || org.companyName!.isEmpty) {
      SetupLogger.validation('companyName', false, 'пустое');
      state = state.copyWith(error: 'error.enter_org_name');
      return;
    }

    if (org.taxId == null || org.taxId!.isEmpty) {
      final label = country?.taxIdLabel ?? 'tax ID';
      SetupLogger.validation('taxId', false, 'пустое');
      state = state.copyWith(error: 'error.enter_tax_id:$label');
      return;
    }

    if (country != null && !country.isValidTaxId(org.taxId!)) {
      SetupLogger.validation(
        'taxId',
        false,
        'длина не соответствует: ${org.taxId!.length} вместо ${country.taxIdLength}',
      );
      state = state.copyWith(
        error:
            'error.tax_id_length:${country.taxIdLabel} must contain ${country.taxIdLength} digits',
      );
      return;
    }

    SetupLogger.validation('organization', true);
    SetupLogger.step('organizationSetup', 'vatSelection');
    state = state.copyWith(
      currentStep: InitialSetupStep.vatSelection,
      clearError: true,
    );
  }

  void setVatPayer(bool isVatPayer) {
    state = state.copyWith(
      organization: state.organization.copyWith(isVatPayer: isVatPayer),
      clearError: true,
    );
  }

  void confirmVatSelection() {
    SetupLogger.info(
      'confirmVatSelection: isVatPayer=${state.organization.isVatPayer}',
    );
    SetupLogger.step('vatSelection', 'employeeSetup');
    state = state.copyWith(
      currentStep: InitialSetupStep.employeeSetup,
      clearError: true,
    );
  }

  void updatePosConfig({
    String? cashBoxName,
    String? posId,
    bool? printerEnabled,
    int? paperWidth,
    String? printerHeader,
    String? printerFooter,
  }) {
    state = state.copyWith(
      posConfig: state.posConfig.copyWith(
        cashBoxName: cashBoxName,
        posId: posId,
        printerEnabled: printerEnabled,
        paperWidth: paperWidth,
        printerHeader: printerHeader,
        printerFooter: printerFooter,
      ),
      clearError: true,
    );
  }

  void confirmPosConfig() {
    final pos = state.posConfig;
    SetupLogger.info(
      'confirmPosConfig: cashBoxName="${pos.cashBoxName}", posId="${pos.posId}", paperWidth=${pos.paperWidth}',
    );

    if (pos.cashBoxName == null || pos.cashBoxName!.isEmpty) {
      SetupLogger.validation('cashBoxName', false, 'пустое');
      state = state.copyWith(error: 'error.enter_pos_name');
      return;
    }

    SetupLogger.validation('posConfig', true);
    SetupLogger.step('posSetup', 'fiscalSetup');
    state = state.copyWith(
      currentStep: InitialSetupStep.fiscalSetup,
      clearError: true,
    );
  }

  void updateFiscalConfig({
    FiscalType? fiscalType,
    bool? enabled,
    String? wkAccountId,
    String? wkAccountToken,
    String? wkPosId,
    String? wkPosToken,
    String? wkPosFactoryNo,
    String? ofdInn,
    String? ofdKktRegNo,
    String? ofdFnNo,
    String? ofdUrl,
  }) {
    state = state.copyWith(
      fiscalConfig: state.fiscalConfig.copyWith(
        fiscalType: fiscalType,
        enabled: enabled,
        wkAccountId: wkAccountId,
        wkAccountToken: wkAccountToken,
        wkPosId: wkPosId,
        wkPosToken: wkPosToken,
        wkPosFactoryNo: wkPosFactoryNo,
        ofdInn: ofdInn,
        ofdKktRegNo: ofdKktRegNo,
        ofdFnNo: ofdFnNo,
        ofdUrl: ofdUrl,
      ),
      clearError: true,
    );
  }

  void confirmFiscalConfig() {
    final fiscal = state.fiscalConfig;
    SetupLogger.info(
      'confirmFiscalConfig: enabled=${fiscal.enabled}, type=${fiscal.fiscalType.name}',
    );

    if (fiscal.enabled) {
      if (fiscal.fiscalType == FiscalType.webkassa) {
        if (!fiscal.isWebKassaComplete) {
          SetupLogger.validation('webkassa', false, 'не все поля заполнены');
          state = state.copyWith(error: 'error.fill_webkassa');
          return;
        }
      } else if (fiscal.fiscalType == FiscalType.ofd) {
        if (!fiscal.isOfdComplete) {
          SetupLogger.validation('ofd', false, 'не все поля заполнены');
          state = state.copyWith(error: 'error.fill_ofd');
          return;
        }
      }
    }

    SetupLogger.validation('fiscalConfig', true);
    SetupLogger.step('fiscalSetup', 'equipmentSetup');
    state = state.copyWith(
      currentStep: InitialSetupStep.equipmentSetup,
      clearError: true,
    );
  }

  void skipFiscalSetup() {
    SetupLogger.info('skipFiscalSetup: фискализация пропущена');
    SetupLogger.step('fiscalSetup', 'equipmentSetup');
    state = state.copyWith(
      fiscalConfig: const FiscalConfigInfo(),
      currentStep: InitialSetupStep.equipmentSetup,
      clearError: true,
    );
  }

  void updateEquipmentConfig({
    bool? printerEnabled,
    PrinterConnectionType? printerConnectionType,
    String? printerAddress,
    String? printerName,
    bool? scannerEnabled,
    ScannerConnectionType? scannerConnectionType,
    String? scannerAddress,
    bool? scaleEnabled,
    ScaleType? scaleType,
    String? scalePort,
    int? scaleBaudRate,
    bool? cashDrawerEnabled,
    bool? cashDrawerConnectedToPrinter,
    bool? customerDisplayEnabled,
    String? customerDisplayPort,
  }) {
    var effectivePrinterConnection = printerConnectionType;
    if (printerEnabled == true &&
        state.equipmentConfig.printerConnectionType ==
            PrinterConnectionType.none &&
        printerConnectionType == null) {
      effectivePrinterConnection = PrinterConnectionType.usb;
    }

    var effectiveScannerConnection = scannerConnectionType;
    if (scannerEnabled == true &&
        state.equipmentConfig.scannerConnectionType ==
            ScannerConnectionType.none &&
        scannerConnectionType == null) {
      effectiveScannerConnection = ScannerConnectionType.camera;
    }

    var effectiveScaleType = scaleType;
    if (scaleEnabled == true &&
        state.equipmentConfig.scaleType == ScaleType.none &&
        scaleType == null) {
      effectiveScaleType = ScaleType.serial;
    }

    state = state.copyWith(
      equipmentConfig: state.equipmentConfig.copyWith(
        printerEnabled: printerEnabled,
        printerConnectionType: effectivePrinterConnection,
        printerAddress: printerAddress,
        printerName: printerName,
        scannerEnabled: scannerEnabled,
        scannerConnectionType: effectiveScannerConnection,
        scannerAddress: scannerAddress,
        scaleEnabled: scaleEnabled,
        scaleType: effectiveScaleType,
        scalePort: scalePort,
        scaleBaudRate: scaleBaudRate,
        cashDrawerEnabled: cashDrawerEnabled,
        cashDrawerConnectedToPrinter: cashDrawerConnectedToPrinter,
        customerDisplayEnabled: customerDisplayEnabled,
        customerDisplayPort: customerDisplayPort,
      ),
      clearError: true,
    );
  }

  void confirmEquipmentConfig() {
    final eq = state.equipmentConfig;
    SetupLogger.info(
      'confirmEquipmentConfig: printer=${eq.printerEnabled}, scanner=${eq.scannerEnabled}, scale=${eq.scaleEnabled}, drawer=${eq.cashDrawerEnabled}, display=${eq.customerDisplayEnabled}',
    );
    SetupLogger.step('equipmentSetup', 'paymentTerminalSetup');
    state = state.copyWith(
      currentStep: InitialSetupStep.paymentTerminalSetup,
      clearError: true,
    );
  }

  void skipEquipmentSetup() {
    SetupLogger.info('skipEquipmentSetup: оборудование пропущено');
    SetupLogger.step('equipmentSetup', 'paymentTerminalSetup');
    state = state.copyWith(
      equipmentConfig: const EquipmentConfigInfo(),
      currentStep: InitialSetupStep.paymentTerminalSetup,
      clearError: true,
    );
  }

  void updatePaymentTerminalConfig({
    bool? kaspiEnabled,
    String? kaspiTerminalIp,
    int? kaspiTerminalPort,
  }) {
    state = state.copyWith(
      paymentTerminalConfig: state.paymentTerminalConfig.copyWith(
        kaspiEnabled: kaspiEnabled,
        kaspiTerminalIp: kaspiTerminalIp,
        kaspiTerminalPort: kaspiTerminalPort,
      ),
      clearError: true,
    );
  }

  void confirmPaymentTerminalConfig() {
    final config = state.paymentTerminalConfig;
    SetupLogger.info(
      'confirmPaymentTerminalConfig: kaspi=${config.kaspiEnabled}',
    );

    if (config.kaspiEnabled) {
      if (config.kaspiTerminalIp == null || config.kaspiTerminalIp!.isEmpty) {
        SetupLogger.validation('kaspiIp', false, 'пустое');
        state = state.copyWith(error: 'error.enter_kaspi_ip');
        return;
      }
    }

    SetupLogger.validation('paymentTerminals', true);
    SetupLogger.step('paymentTerminalSetup', 'businessRulesSetup');
    state = state.copyWith(
      currentStep: InitialSetupStep.businessRulesSetup,
      clearError: true,
    );
  }

  void skipPaymentTerminalSetup() {
    SetupLogger.info('skipPaymentTerminalSetup: терминалы пропущены');
    SetupLogger.step('paymentTerminalSetup', 'businessRulesSetup');
    state = state.copyWith(
      paymentTerminalConfig: const PaymentTerminalConfigInfo(),
      currentStep: InitialSetupStep.businessRulesSetup,
      clearError: true,
    );
  }

  void updateBusinessRulesConfig({
    int? discountsRoundType,
    int? weightProductRoundType,
    bool? cashbackEnabled,
    int? cashbackRate,
    bool? allowBigAmount,
    String? cashWithdrawalLimit,
    bool? allowDiscounts,
    bool? allowDebtSales,
    bool? allowPriceEdit,
    bool? allowProductEdit,
    bool? allowCashInOut,
    bool? allowUniversalProduct,
    bool? blockPriceDecrease,
  }) {
    state = state.copyWith(
      businessRulesConfig: state.businessRulesConfig.copyWith(
        discountsRoundType: discountsRoundType,
        weightProductRoundType: weightProductRoundType,
        cashbackEnabled: cashbackEnabled,
        cashbackRate: cashbackRate,
        allowBigAmount: allowBigAmount,
        cashWithdrawalLimit: cashWithdrawalLimit,
        allowDiscounts: allowDiscounts,
        allowDebtSales: allowDebtSales,
        allowPriceEdit: allowPriceEdit,
        allowProductEdit: allowProductEdit,
        allowCashInOut: allowCashInOut,
        allowUniversalProduct: allowUniversalProduct,
        blockPriceDecrease: blockPriceDecrease,
      ),
      clearError: true,
    );
  }

  void confirmBusinessRulesConfig() {
    SetupLogger.info(
      'confirmBusinessRulesConfig: discountRound=${state.businessRulesConfig.discountsRoundType}, cashback=${state.businessRulesConfig.cashbackEnabled}',
    );
    SetupLogger.step('businessRulesSetup', 'summary');
    state = state.copyWith(
      currentStep: InitialSetupStep.summary,
      clearError: true,
    );
  }

  void updateFirstUser({String? name, String? pin}) {
    state = state.copyWith(
      firstUser: state.firstUser.copyWith(name: name, pin: pin),
      clearError: true,
    );
  }

  void updateSecondUser({String? name, String? pin}) {
    final currentSecondUser = state.secondUser ?? const FirstUserInfo();
    state = state.copyWith(
      secondUser: currentSecondUser.copyWith(name: name, pin: pin),
      clearError: true,
    );
  }

  void confirmUsers() {
    final user = state.firstUser;
    SetupLogger.info(
      'confirmUsers: adminName="${user.name}", pinLength=${user.pin?.length}, hasSecondUser=${state.secondUser != null}',
    );

    if (user.name == null || user.name!.isEmpty) {
      SetupLogger.validation('adminName', false, 'пустое');
      state = state.copyWith(error: 'error.enter_admin_name');
      return;
    }

    if (user.pin == null || user.pin!.length < 4) {
      SetupLogger.validation('adminPin', false, 'длина=${user.pin?.length}');
      state = state.copyWith(error: 'error.admin_pin_short');
      return;
    }

    final secondUser = state.secondUser;
    if (secondUser != null &&
        secondUser.name != null &&
        secondUser.name!.isNotEmpty) {
      if (secondUser.pin == null || secondUser.pin!.length < 4) {
        SetupLogger.validation(
          'sellerPin',
          false,
          'длина=${secondUser.pin?.length}',
        );
        state = state.copyWith(error: 'error.seller_pin_short');
        return;
      }
    }

    SetupLogger.validation('users', true);
    SetupLogger.step('employeeSetup', 'operatingModeSelection');
    state = state.copyWith(
      currentStep: InitialSetupStep.operatingModeSelection,
      clearError: true,
    );
  }

  void confirmFirstUser() => confirmUsers();

  void setOperatingMode(OperatingMode mode) {
    state = state.copyWith(operatingMode: mode, clearError: true);
  }

  void confirmOperatingMode() {
    SetupLogger.info(
      'confirmOperatingMode: operatingMode=${state.operatingMode.name}',
    );
    SetupLogger.step('operatingModeSelection', 'posSetup');
    state = state.copyWith(
      currentStep: InitialSetupStep.posSetup,
      clearError: true,
    );
  }

  bool _isSaving = false;

  Future<void> finishSetup() async {
    if (_isSaving) {
      SetupLogger.warning(
        'finishSetup: уже выполняется — игнорируем повторный вызов',
      );
      return;
    }
    _isSaving = true;

    SetupLogger.info('finishSetup: начало финализации...');

    try {
      if (state.selectedCountry == null) {
        SetupLogger.info(
          'finishSetup: страна не указана → по умолчанию Казахстан',
        );
        state = state.copyWith(selectedCountry: CountryCode.kzt);
      }

      final hasCountry = state.selectedCountry != null;
      final orgComplete = state.organization.isComplete;
      final posComplete = state.posConfig.isComplete;
      final fiscalComplete = state.fiscalConfig.isComplete;
      final equipComplete = state.equipmentConfig.isComplete;
      final terminalComplete = state.paymentTerminalConfig.isComplete;
      final rulesComplete = state.businessRulesConfig.isComplete;
      final userComplete = state.employees.isNotEmpty
          ? state.employees.first.isComplete
          : state.firstUser.isComplete;

      SetupLogger.info(
        'finishSetup: country=$hasCountry, org=$orgComplete, pos=$posComplete, fiscal=$fiscalComplete, equip=$equipComplete, terminal=$terminalComplete, rules=$rulesComplete, user=$userComplete',
      );

      final allComplete =
          hasCountry &&
          orgComplete &&
          posComplete &&
          fiscalComplete &&
          equipComplete &&
          terminalComplete &&
          rulesComplete &&
          userComplete;

      if (!allComplete) {
        final missing = <String>[
          if (!orgComplete) 'организация',
          if (!posComplete) 'касса',
          if (!fiscalComplete) 'фискализация',
          if (!equipComplete) 'оборудование',
          if (!terminalComplete) 'платёжные терминалы',
          if (!rulesComplete) 'правила',
          if (!userComplete) 'пользователь',
        ].join(', ');
        SetupLogger.warning(
          'finishSetup: данные неполные — не хватает: $missing',
        );
        state = state.copyWith(error: 'error.setup_incomplete:$missing');
        _isSaving = false;
        return;
      }
    } catch (e, stack) {
      SetupLogger.error('finishSetup: ошибка валидации', e, stack);
      _isSaving = false;
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await GetIt.instance<SetupRepository>().completeSetup(_buildDraft());

      SetupLogger.info('finishSetup: ВСЕ ДАННЫЕ СОХРАНЕНЫ УСПЕШНО');
      SetupLogger.step('summary', 'complete');
      state = state.copyWith(
        currentStep: InitialSetupStep.complete,
        isLoading: false,
      );
    } catch (e, stack) {
      SetupLogger.error('finishSetup FAILED', e, stack);
      state = state.copyWith(
        error: 'error.save_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    } finally {
      _isSaving = false;
    }
  }

  /// Freezes what the operator filled in into the payload the contract takes.
  SetupDraft _buildDraft() {
    return SetupDraft(
      countryIndex: (state.selectedCountry ?? CountryCode.kzt).index,
      operatingModeIndex: state.operatingMode.index,
      organization: state.organization,
      posConfig: state.posConfig,
      fiscalConfig: state.fiscalConfig,
      businessRules: state.businessRulesConfig,
      equipment: state.equipmentConfig,
      paymentTerminal: state.paymentTerminalConfig,
      employees: state.employees,
      firstUser: state.firstUser,
      secondUser: state.secondUser,
    );
  }

  /// Прыжок на конкретный шаг с экрана итога.
  ///
  /// Исправить замеченное на итоге раньше было нечем: единственным способом
  /// вернуться к неверно заполненному шагу было нажать «Назад» столько раз,
  /// сколько шагов между ними.
  ///
  /// Прыгать можно только на нумерованные шаги. `unreadable` в этот список не
  /// входит намеренно: это состояние существует, чтобы неотвеченный вопрос
  /// «настроена ли касса» не был принят за «не настроена», и вход в него
  /// откуда бы то ни было сводил бы его смысл на нет.
  void goToStep(InitialSetupStep step) {
    if (!InitialSetupState.orderedSteps.contains(step)) {
      SetupLogger.warning('goToStep: шаг ${step.name} вне нумерации, отказ');
      return;
    }
    SetupLogger.step(state.currentStep.name, step.name);
    state = state.copyWith(currentStep: step, clearError: true);
  }

  void goBack() {
    SetupLogger.info('goBack: from ${state.currentStep.name}');

    // Back from "could not read" leads nowhere, and neither does back from
    // checking or complete. Every other value is a wizard step, and walking
    // into one is the exact move `unreadable` was added to prevent.
    if (state.currentStep == InitialSetupStep.unreadable ||
        state.currentStep == InitialSetupStep.checking ||
        state.currentStep == InitialSetupStep.complete) {
      return;
    }

    // The order comes from the same list the progress numbering uses, so
    // "back" and the rail cannot drift apart. The wildcard branch this
    // replaced defaulted to the wizard entry point, which is how a state
    // added to keep an unanswered till out of the wizard got walked back
    // into it.
    final index = InitialSetupState.orderedSteps.indexOf(state.currentStep);
    if (index <= 0) return;

    state = state.copyWith(
      currentStep: InitialSetupState.orderedSteps[index - 1],
      clearError: true,
    );
  }

  /// Asks again, from the screen that says it could not be asked.
  ///
  /// Separate from [reset], which throws the whole wizard state away. Nothing
  /// is thrown away here because nothing was collected — the till never
  /// answered.
  /// Повтор проверки — единственное действие [UnreadableStep].
  ///
  /// Подписка заводится заново, а не перечитывается: сюда попадают ровно тогда,
  /// когда касса не ответила, и одна из причин этого — оборвавшийся поток. У
  /// оборвавшегося потока спрашивать нечего, и без [Ref.invalidate] кнопка
  /// «повторить» крутила бы индикатор над мёртвой подпиской.
  Future<void> retryInitialCheck() {
    ref.invalidate(startupStateProvider);
    return _checkInitialState();
  }

  void reset() {
    SetupLogger.warning('reset: полный сброс визарда');
    state = const InitialSetupState();
    _checkInitialState();
  }
}

final initialSetupControllerProvider =
    NotifierProvider<InitialSetupNotifier, InitialSetupState>(
      InitialSetupNotifier.new,
    );
