@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/business_rules_step.dart';
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
import 'package:telepos/presentation/screens/setup/steps/vat_step.dart';

import 'golden_test_helpers.dart';

/// Одиннадцать шагов мастера и экран «готово» — в трёх ширинах.
///
/// Снимается настоящий виджет шага, а не макет: эталон с макета не поймал бы
/// ничего, потому что макет и есть то, что рисует тест.
///
/// Заполненный черновик подставлен намеренно. Пустой мастер выглядит одинаково
/// на любом оформлении — половина того, что здесь проверяется (значения в
/// строках итога, раскрытые поля устройств, набранный текст), на пустом
/// состоянии просто не появится.
InitialSetupState _at(InitialSetupStep step) => InitialSetupState(
  currentStep: step,
  selectedCountry: CountryCode.kzt,
  operatingMode: OperatingMode.retail,
  organization: const OrganizationInfo(
    companyName: 'ТОО «Ромашка»',
    taxId: '123456789012',
    legalAddress: 'Алматы, Абая 1',
    contactName: 'Айгуль Сатпаева',
    isVatPayer: true,
  ),
  posConfig: const PosConfigInfo(cashBoxName: 'Касса у входа', posId: 'POS-1'),
  fiscalConfig: const FiscalConfigInfo(
    enabled: true,
    fiscalType: FiscalType.webkassa,
    wkAccountId: 'acc-42',
  ),
  equipmentConfig: const EquipmentConfigInfo(
    printerEnabled: true,
    printerConnectionType: PrinterConnectionType.wifi,
    printerAddress: '192.168.1.100',
    scannerEnabled: true,
  ),
  paymentTerminalConfig: const PaymentTerminalConfigInfo(kaspiEnabled: true),
  businessRulesConfig: const BusinessRulesConfigInfo(cashbackEnabled: true),
  firstUser: const EmployeeInfo(name: 'Асхат', pin: '4321'),
);

/// Контроллер подменён неподвижным состоянием.
///
/// Настоящий заводит таймер начальной проверки, как только его создадут, а шаг
/// сотрудников создаёт его на первом же кадре — он записывает в черновик имя
/// администратора по умолчанию. Снимок при этом падал бы на «таймер остался
/// висеть», а не показывал бы экран.
class _StubNotifier extends InitialSetupNotifier {
  _StubNotifier(this._state);

  final InitialSetupState _state;

  @override
  InitialSetupState build() => _state;
}

class _FixedInputMode extends InputModeNotifier {
  _FixedInputMode(this.value);

  final InputMode value;

  @override
  InputMode build() => value;
}

/// Обёртка шага под конкретный способ ввода.
///
/// Режим ввода задаётся явно, а не берётся из платформы. В испытательном
/// движке `defaultTargetPlatform` — Android, то есть «палец»: без этой
/// подмены десктопный снимок показывал бы кнопку во всю ширину и стрелку
/// «Назад» в шапке, то есть пальцевую раскладку под видом настольной, и
/// одиннадцать снимков на трёх ширинах не проверяли бы ровно то, ради чего
/// снимаются.
Widget _wrap(InitialSetupStep step, Widget child, InputMode input) {
  final state = _at(step);
  return ProviderScope(
    overrides: [
      initialSetupControllerProvider.overrideWith(() => _StubNotifier(state)),
      inputModeProvider.overrideWith(() => _FixedInputMode(input)),
    ],
    child: child,
  );
}

typedef _StepBuilder = Widget Function(InitialSetupState state);

void main() {
  final steps = <String, ({InitialSetupStep step, _StepBuilder build})>{
    'country': (
      step: InitialSetupStep.countrySelection,
      build: (s) => CountryStep(state: s),
    ),
    'organization': (
      step: InitialSetupStep.organizationSetup,
      build: (s) => OrganizationStep(state: s),
    ),
    'vat': (
      step: InitialSetupStep.vatSelection,
      build: (s) => VatStep(state: s),
    ),
    'mode': (
      step: InitialSetupStep.operatingModeSelection,
      build: (s) => OperatingModeStep(state: s),
    ),
    'employees': (
      step: InitialSetupStep.employeeSetup,
      build: (s) => EmployeesStep(state: s),
    ),
    'pos': (step: InitialSetupStep.posSetup, build: (s) => PosStep(state: s)),
    'fiscal': (
      step: InitialSetupStep.fiscalSetup,
      build: (s) => FiscalStep(state: s),
    ),
    'equipment': (
      step: InitialSetupStep.equipmentSetup,
      build: (s) => EquipmentStep(state: s),
    ),
    'terminal': (
      step: InitialSetupStep.paymentTerminalSetup,
      build: (s) => PaymentTerminalStep(state: s),
    ),
    'rules': (
      step: InitialSetupStep.businessRulesSetup,
      build: (s) => BusinessRulesStep(state: s),
    ),
    'summary': (
      step: InitialSetupStep.summary,
      build: (s) => SummaryStep(state: s),
    ),
    'complete': (
      step: InitialSetupStep.complete,
      build: (_) => const CompleteStep(),
    ),
  };

  steps.forEach((name, entry) {
    group('Мастер настройки — $name', () {
      Widget widget(InputMode input) =>
          _wrap(entry.step, entry.build(_at(entry.step)), input);

      // Обе темы равноправны, и это не удвоение ради удвоения.
      //
      // `AppTheme.dark` подключена 2026-08-04, а до того её не видел никто:
      // экраны проверялись только в светлой, и «работает» означало «работает
      // в одной из двух». Пока тёмная не снимается, её поломка обнаруживается
      // не тестом, а кассиром в ночную смену.
      for (final theme in const {
        'светлая': Brightness.light,
        'тёмная': Brightness.dark,
      }.entries) {
        testWidgets('телефон, ${theme.key}', (tester) async {
          await GoldenTestHelpers.matchGoldenMobile(
            tester,
            widget(InputMode.touch),
            'setup_$name',
            brightness: theme.value,
          );
        });

        testWidgets('планшет, ${theme.key}', (tester) async {
          // Планшет широкий, но пальцевый — по таблице привязки к платформе.
          await GoldenTestHelpers.matchGoldenTablet(
            tester,
            widget(InputMode.touch),
            'setup_$name',
            brightness: theme.value,
          );
        });

        testWidgets('десктоп, ${theme.key}', (tester) async {
          await GoldenTestHelpers.matchGoldenDesktop(
            tester,
            widget(InputMode.pointer),
            'setup_$name',
            brightness: theme.value,
          );
        });
      }
    });
  });
}
