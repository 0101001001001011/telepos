import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

class _TestSetupNotifier extends InitialSetupNotifier {
  _TestSetupNotifier(this._initialStep, {OperatingMode? initialMode})
    : _initialMode = initialMode ?? OperatingMode.retail;

  final InitialSetupStep _initialStep;
  final OperatingMode _initialMode;

  @override
  InitialSetupState build() {
    return InitialSetupState(
      currentStep: _initialStep,
      operatingMode: _initialMode,
    );
  }
}

ProviderContainer _createContainer({
  required InitialSetupStep startStep,
  OperatingMode? initialMode,
}) {
  final container = ProviderContainer(
    overrides: [
      initialSetupControllerProvider.overrideWith(
        () => _TestSetupNotifier(startStep, initialMode: initialMode),
      ),
    ],
  );
  container.read(initialSetupControllerProvider);
  return container;
}

void main() {
  group('InitialSetup - Operating Mode Selection', () {
    test('operatingModeSelection step comes after employeeSetup', () {
      final container = _createContainer(
        startStep: InitialSetupStep.employeeSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.updateFirstUser(name: 'Admin', pin: '0000');
      notifier.confirmUsers();

      final state = container.read(initialSetupControllerProvider);
      expect(
        state.currentStep,
        equals(InitialSetupStep.operatingModeSelection),
      );
    });

    test('setOperatingMode(restaurant) updates state', () {
      final container = _createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      container
          .read(initialSetupControllerProvider.notifier)
          .setOperatingMode(OperatingMode.restaurant);

      final state = container.read(initialSetupControllerProvider);
      expect(state.operatingMode, equals(OperatingMode.restaurant));
    });

    test('setOperatingMode(service) updates state', () {
      final container = _createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      container
          .read(initialSetupControllerProvider.notifier)
          .setOperatingMode(OperatingMode.service);

      final state = container.read(initialSetupControllerProvider);
      expect(state.operatingMode, equals(OperatingMode.service));
    });

    test('confirmOperatingMode moves to posSetup', () {
      final container = _createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      container
          .read(initialSetupControllerProvider.notifier)
          .confirmOperatingMode();

      final state = container.read(initialSetupControllerProvider);
      expect(state.currentStep, equals(InitialSetupStep.posSetup));
    });

    test('goBack from operatingModeSelection returns to employeeSetup', () {
      final container = _createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      container.read(initialSetupControllerProvider.notifier).goBack();

      final state = container.read(initialSetupControllerProvider);
      expect(state.currentStep, equals(InitialSetupStep.employeeSetup));
    });

    test('default operatingMode is retail', () {
      const state = InitialSetupState();
      expect(state.operatingMode, equals(OperatingMode.retail));
    });

    test('operatingModeSelection step number is 5', () {
      // Was 8 while the wizard opened with three account screens. Those went
      // with the Go backend they talked to, so every step moved up by three.
      final state = const InitialSetupState().copyWith(
        currentStep: InitialSetupStep.operatingModeSelection,
      );
      expect(state.stepNumber, equals(5));
    });

    test('switching operating mode preserves other state', () {
      final container = _createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);

      notifier.setOperatingMode(OperatingMode.restaurant);

      final state = container.read(initialSetupControllerProvider);
      expect(state.operatingMode, equals(OperatingMode.restaurant));
      expect(
        state.currentStep,
        equals(InitialSetupStep.operatingModeSelection),
      );
    });

    test('can change operating mode multiple times before confirming', () {
      final container = _createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);

      notifier.setOperatingMode(OperatingMode.restaurant);
      notifier.setOperatingMode(OperatingMode.service);
      notifier.setOperatingMode(OperatingMode.retail);

      final state = container.read(initialSetupControllerProvider);
      expect(state.operatingMode, equals(OperatingMode.retail));
    });

    test('goBack from posSetup returns to operatingModeSelection', () {
      final container = _createContainer(startStep: InitialSetupStep.posSetup);
      addTearDown(container.dispose);

      container.read(initialSetupControllerProvider.notifier).goBack();

      final state = container.read(initialSetupControllerProvider);
      expect(
        state.currentStep,
        equals(InitialSetupStep.operatingModeSelection),
      );
    });
  });

  group('InitialSetupState - Operating Mode copyWith', () {
    test('copyWith preserves operatingMode when not specified', () {
      const state = InitialSetupState(operatingMode: OperatingMode.service);
      final newState = state.copyWith(isLoading: true);
      expect(newState.operatingMode, equals(OperatingMode.service));
    });

    test('copyWith changes operatingMode when specified', () {
      const state = InitialSetupState(operatingMode: OperatingMode.retail);
      final newState = state.copyWith(operatingMode: OperatingMode.restaurant);
      expect(newState.operatingMode, equals(OperatingMode.restaurant));
    });
  });
}
