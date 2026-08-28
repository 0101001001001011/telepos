import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

import 'support/harness.dart';

/// Сквозной проход мастера поверх настоящего графа зависимостей.
///
/// `seedData: false` намеренно: смысл теста в том, чтобы пройти реальный путь
/// `SetupRepository.completeSetup`, а не подсунутую фикстуру. Иначе он
/// проверял бы, что seed вставляет строки, — то, что и так известно.
///
/// Шаги перечислены явно, а не прокручены циклом с `advanceForTest`.
/// Обёртка ради теста в рабочем коде означала бы, что тест ходит не тем
/// путём, каким ходит экран.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late E2eHarness harness;
  late ProviderContainer container;

  setUp(() async {
    harness = E2eHarness();
    await harness.setUp(seedData: false);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await harness.tearDown();
  });

  InitialSetupStep step() =>
      container.read(initialSetupControllerProvider).currentStep;

  Future<void> walkToSummary() async {
    final n = container.read(initialSetupControllerProvider.notifier);

    // Мастер стартует с проверки состояния кассы: она асинхронная, и без
    // ожидания первый же шаг пришёлся бы на checking.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    n
      ..selectCountry(CountryCode.kzt)
      ..confirmCountrySelection();
    expect(step(), InitialSetupStep.organizationSetup);

    n
      ..updateOrganization(companyName: 'ТОО Ромашка', taxId: '123456789012')
      ..confirmOrganization();
    expect(step(), InitialSetupStep.vatSelection);

    n
      ..setVatPayer(true)
      ..confirmVatSelection();
    expect(step(), InitialSetupStep.employeeSetup);

    n
      ..updateFirstUser(name: 'Асхат', pin: '4321')
      ..confirmUsers();
    expect(step(), InitialSetupStep.operatingModeSelection);

    n
      ..setOperatingMode(OperatingMode.retail)
      ..confirmOperatingMode();
    expect(step(), InitialSetupStep.posSetup);

    n
      ..updatePosConfig(cashBoxName: 'Касса у входа', posId: 'POS-1')
      ..confirmPosConfig();
    expect(step(), InitialSetupStep.fiscalSetup);

    n.skipFiscalSetup();
    expect(step(), InitialSetupStep.equipmentSetup);

    n.confirmEquipmentConfig();
    expect(step(), InitialSetupStep.paymentTerminalSetup);

    n.confirmPaymentTerminalConfig();
    expect(step(), InitialSetupStep.businessRulesSetup);

    n.confirmBusinessRulesConfig();
    expect(step(), InitialSetupStep.summary);
  }

  test(
    'мастер проходится от страны до итога, и каждый шаг продвигает',
    () async {
      await walkToSummary();

      final state = container.read(initialSetupControllerProvider);
      expect(
        state.stepNumber,
        state.totalSteps,
        reason: 'итог — последний шаг',
      );
      expect(state.totalSteps, 11);
    },
  );

  test('возврат с итога на шаг не теряет введённого', () async {
    await walkToSummary();

    final n = container.read(initialSetupControllerProvider.notifier);
    n.goToStep(InitialSetupStep.organizationSetup);
    expect(step(), InitialSetupStep.organizationSetup);

    // Черновик обязан пережить прыжок: именно из него шаг восстанавливает
    // содержимое своих полей.
    final org = container.read(initialSetupControllerProvider).organization;
    expect(org.companyName, 'ТОО Ромашка');
    expect(org.taxId, '123456789012');
  });

  test(
    'после завершения касса действительно настроена, а не только отрисована',
    () async {
      await walkToSummary();

      final n = container.read(initialSetupControllerProvider.notifier);
      await n.finishSetup();

      expect(step(), InitialSetupStep.complete);

      // Записано в базу, а не только в состояние экрана.
      final users = await harness.db
          .customSelect('SELECT COUNT(*) AS c FROM users')
          .getSingle();
      expect(
        users.data['c'],
        greaterThan(0),
        reason: 'мастер обязан создать хотя бы администратора',
      );

      // Касса записана: конфигурация точки и счета, которые заводит
      // completeSetup. Именно они отличают настроенную кассу от пустой базы.
      final pos = await harness.db
          .customSelect('SELECT COUNT(*) AS c FROM this_pos_entries')
          .getSingle();
      expect(pos.data['c'], greaterThan(0), reason: 'конфигурация точки');

      final accounts = await harness.db
          .customSelect('SELECT COUNT(*) AS c FROM accounts')
          .getSingle();
      expect(accounts.data['c'], greaterThan(0), reason: 'счета кассы');
    },
  );
}
