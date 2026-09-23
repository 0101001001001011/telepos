import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_switch_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_progress_rail.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/business_rules_step.dart';
import 'package:telepos/presentation/screens/setup/steps/employees_step.dart';
import 'package:telepos/presentation/screens/setup/steps/equipment_step.dart';
import 'package:telepos/presentation/screens/setup/steps/fiscal_step.dart';
import 'package:telepos/presentation/screens/setup/steps/payment_terminal_step.dart';

/// Подменяет контроллер мастера неподвижным состоянием.
///
/// Настоящий заводит таймер начальной проверки, как только его создадут.
/// Шаг сотрудников создаёт его на первом же кадре — он записывает в черновик
/// имя администратора по умолчанию.
class _StubNotifier extends InitialSetupNotifier {
  _StubNotifier(this._state);

  final InitialSetupState _state;

  @override
  InitialSetupState build() => _state;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  InitialSetupState? stub,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (stub != null)
          initialSetupControllerProvider.overrideWith(
            () => _StubNotifier(stub),
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('выключенное устройство не показывает своих полей', (
    tester,
  ) async {
    // Экран оборудования показывал поля адреса и имени принтера даже там,
    // где принтера нет: человек читал настройки железа, которого не купит.
    await _pump(
      tester,
      const EquipmentStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.equipmentSetup,
          equipmentConfig: EquipmentConfigInfo(
            printerEnabled: false,
            scannerEnabled: false,
            scaleEnabled: false,
            customerDisplayEnabled: false,
          ),
        ),
      ),
    );

    expect(find.byType(SettingsSwitchTile), findsWidgets);
    expect(
      find.byType(SettingsFieldTile),
      findsNothing,
      reason: 'поля выключенного устройства не должны занимать экран',
    );
  });

  testWidgets('включённый принтер раскрывает свои поля', (tester) async {
    await _pump(
      tester,
      const EquipmentStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.equipmentSetup,
          equipmentConfig: EquipmentConfigInfo(printerEnabled: true),
        ),
      ),
    );

    expect(find.byType(SettingsFieldTile), findsWidgets);
  });

  testWidgets('адрес принтера появляется только у сетевого подключения', (
    tester,
  ) async {
    // По USB адреса не бывает. Поле «IP-адрес» рядом с USB-принтером — это
    // вопрос, на который нет правильного ответа.
    await _pump(
      tester,
      const EquipmentStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.equipmentSetup,
          equipmentConfig: EquipmentConfigInfo(
            printerEnabled: true,
            printerConnectionType: PrinterConnectionType.usb,
          ),
        ),
      ),
    );
    final byUsb = tester
        .widgetList<SettingsFieldTile>(find.byType(SettingsFieldTile))
        .length;

    await _pump(
      tester,
      const EquipmentStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.equipmentSetup,
          equipmentConfig: EquipmentConfigInfo(
            printerEnabled: true,
            printerConnectionType: PrinterConnectionType.wifi,
          ),
        ),
      ),
    );
    final byWifi = tester
        .widgetList<SettingsFieldTile>(find.byType(SettingsFieldTile))
        .length;

    expect(byWifi, byUsb + 1);
  });

  testWidgets('выключенный терминал не показывает адреса', (tester) async {
    await _pump(
      tester,
      const PaymentTerminalStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.paymentTerminalSetup,
        ),
      ),
    );

    expect(find.byType(SettingsSwitchTile), findsOneWidget);
    expect(find.byType(SettingsFieldTile), findsNothing);
  });

  testWidgets('включённый терминал показывает адрес и порт', (tester) async {
    await _pump(
      tester,
      const PaymentTerminalStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.paymentTerminalSetup,
          paymentTerminalConfig: PaymentTerminalConfigInfo(kaspiEnabled: true),
        ),
      ),
    );

    expect(find.byType(SettingsFieldTile), findsNWidgets(2));
  });

  testWidgets('выключенный кэшбэк не показывает ставки', (tester) async {
    await _pump(
      tester,
      const BusinessRulesStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.businessRulesSetup,
        ),
      ),
    );

    expect(find.byType(SettingsSwitchTile), findsWidgets);
    expect(find.byType(SettingsFieldTile), findsNothing);
  });

  testWidgets('коды сотрудников больше не предлагаются по умолчанию', (
    tester,
  ) async {
    // Было 0000 у администратора и 1111 у продавца. Код, который подставила
    // касса и который знает каждый, кто видел такую же кассу, — это
    // отсутствие кода, а не значение по умолчанию.
    await _pump(
      tester,
      const EmployeesStep(
        state: InitialSetupState(currentStep: InitialSetupStep.employeeSetup),
      ),
      stub: const InitialSetupState(
        currentStep: InitialSetupStep.employeeSetup,
      ),
    );

    final values = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller?.text ?? '')
        .toList();
    expect(values, isNot(contains('0000')));
    expect(values, isNot(contains('1111')));
  });

  testWidgets('без кода дальше не пускает', (tester) async {
    await _pump(
      tester,
      const EmployeesStep(
        state: InitialSetupState(currentStep: InitialSetupStep.employeeSetup),
      ),
      stub: const InitialSetupState(
        currentStep: InitialSetupStep.employeeSetup,
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('выключенная фискализация зовёт кнопку «Пропустить»', (
    tester,
  ) async {
    // Раньше «Пропустить» стояла отдельной кнопкой посреди экрана рядом с
    // «Далее» — выбор между двумя синонимами.
    await _pump(
      tester,
      const FiscalStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.fiscalSetup,
          selectedCountry: CountryCode.kzt,
        ),
      ),
    );

    expect(
      find.widgetWithText(ElevatedButton, 'Пропустить (настроить позже)'),
      findsOneWidget,
    );
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('включённая фискализация раскрывает реквизиты с объяснением', (
    tester,
  ) async {
    await _pump(
      tester,
      const FiscalStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.fiscalSetup,
          selectedCountry: CountryCode.kzt,
          fiscalConfig: FiscalConfigInfo(
            enabled: true,
            fiscalType: FiscalType.webkassa,
          ),
        ),
      ),
    );

    expect(find.byType(SettingsFieldTile), findsNWidgets(5));
    // Иконка-подсказка есть там, где ошибка молчит до сверки.
    expect(find.byIcon(Icons.help_outline), findsWidgets);
  });

  testWidgets('где страна без фискализации — ни одного поля', (tester) async {
    // Здесь стоял Узбекистан — и это закрепляло дефект. Он объявлял
    // `hasFiscalisation: true`, а таблица мастера про него не знала: шаг
    // пропускался, а чек печатал фискальный блок. 2026-09-22 два источника
    // сведены в один `CountryCode.fiscalProtocol`, и Узбекистан получил
    // ОФД, общий для СНГ.
    //
    // Страна без фискализации теперь — та, где её у нас действительно нет:
    // США. Там фискализации не существует как понятия.
    await _pump(
      tester,
      const FiscalStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.fiscalSetup,
          selectedCountry: CountryCode.usd,
        ),
      ),
    );

    expect(find.byType(SettingsFieldTile), findsNothing);
    expect(find.byType(SettingsSwitchTile), findsNothing);
  });

  testWidgets('все три шага без карточек и без материальной полосы', (
    tester,
  ) async {
    for (final step in <Widget>[
      const EquipmentStep(
        state: InitialSetupState(currentStep: InitialSetupStep.equipmentSetup),
      ),
      const PaymentTerminalStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.paymentTerminalSetup,
        ),
      ),
      const BusinessRulesStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.businessRulesSetup,
        ),
      ),
    ]) {
      await _pump(tester, step);
      expect(find.byType(Card), findsNothing, reason: '${step.runtimeType}');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(WizardProgressRail), findsOneWidget);
    }
  });
}
