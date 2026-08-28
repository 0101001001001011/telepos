import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

void main() {
  group('Карта шагов мастера после удаления авторизации', () {
    test('в перечислении не осталось шагов авторизации', () {
      final names = InitialSetupStep.values.map((e) => e.name).toSet();
      expect(names.contains('authChoice'), isFalse);
      expect(names.contains('register'), isFalse);
      expect(names.contains('emailVerification'), isFalse);
      expect(names.contains('login'), isFalse);
    });

    test('мастер состоит из 11 нумерованных шагов', () {
      expect(const InitialSetupState().totalSteps, 11);
    });

    test('нумерация идёт подряд от страны до итога, без дыр', () {
      const order = [
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
      for (var i = 0; i < order.length; i++) {
        final state = const InitialSetupState().copyWith(currentStep: order[i]);
        expect(
          state.stepNumber,
          i + 1,
          reason: 'шаг ${order[i].name} должен быть номером ${i + 1}',
        );
      }
    });

    test('checking не нумеруется, complete идёт после последнего шага', () {
      expect(
        const InitialSetupState()
            .copyWith(currentStep: InitialSetupStep.checking)
            .stepNumber,
        0,
      );
      expect(
        const InitialSetupState()
            .copyWith(currentStep: InitialSetupStep.complete)
            .stepNumber,
        12,
      );
    });

    test('нечитаемое состояние тоже вне нумерации', () {
      expect(
        const InitialSetupState()
            .copyWith(currentStep: InitialSetupStep.unreadable)
            .stepNumber,
        0,
      );
    });
  });
}
