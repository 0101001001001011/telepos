import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/database/daos/user_dao.dart';
import 'package:telepos/data/database/daos/webkassa_receipt_dao.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockThisPosDao extends Mock implements ThisPosDao {}

class MockUserDao extends Mock implements UserDao {}

class MockAccountDao extends Mock implements AccountDao {}

class MockWebkassaReceiptDao extends Mock implements WebkassaReceiptDao {}

class TestableInitialSetupNotifier extends InitialSetupNotifier {
  TestableInitialSetupNotifier(this._initialStep);

  final InitialSetupStep _initialStep;

  @override
  InitialSetupState build() {
    return InitialSetupState(currentStep: _initialStep);
  }
}

void main() {
  late MockAppDatabase mockDb;
  late MockThisPosDao mockThisPosDao;
  late MockUserDao mockUserDao;
  late MockAccountDao mockAccountDao;
  late MockWebkassaReceiptDao mockWebkassaReceiptDao;

  setUp(() {
    mockDb = MockAppDatabase();
    mockThisPosDao = MockThisPosDao();
    mockUserDao = MockUserDao();
    mockAccountDao = MockAccountDao();
    mockWebkassaReceiptDao = MockWebkassaReceiptDao();

    when(() => mockDb.thisPosDao).thenReturn(mockThisPosDao);
    when(() => mockDb.userDao).thenReturn(mockUserDao);
    when(() => mockDb.accountDao).thenReturn(mockAccountDao);
    when(() => mockDb.webkassaReceiptDao).thenReturn(mockWebkassaReceiptDao);

    when(() => mockThisPosDao.exists()).thenAnswer((_) async => false);
    when(() => mockUserDao.hasUsers()).thenAnswer((_) async => false);

    final getIt = GetIt.instance;
    if (getIt.isRegistered<AppDatabase>()) {
      getIt.unregister<AppDatabase>();
    }
    getIt.registerSingleton<AppDatabase>(mockDb);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  ProviderContainer createContainer({InitialSetupStep? startStep}) {
    return ProviderContainer(
      overrides: [
        initialSetupControllerProvider.overrideWith(() {
          return TestableInitialSetupNotifier(
            startStep ?? InitialSetupStep.countrySelection,
          );
        }),
      ],
    );
  }

  // Step order moved to initial_setup_steps_test.dart: with the auth steps
  // gone the numbering is derived from one ordered list, and asserting it
  // here as well would only duplicate that file.

  group('InitialSetupController - Country Selection', () {
    test('selectCountry should update selectedCountry', () {
      final container = createContainer(
        startStep: InitialSetupStep.countrySelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.selectCountry(CountryCode.kzt);

      final state = container.read(initialSetupControllerProvider);

      expect(state.selectedCountry, equals(CountryCode.kzt));
    });

    test('confirmCountrySelection should move to organizationSetup', () {
      final container = createContainer(
        startStep: InitialSetupStep.countrySelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.selectCountry(CountryCode.kzt);
      notifier.confirmCountrySelection();

      final state = container.read(initialSetupControllerProvider);

      expect(state.currentStep, equals(InitialSetupStep.organizationSetup));
    });
  });

  group('InitialSetupController - Organization Setup', () {
    test('confirmOrganization without data should set error', () {
      final container = createContainer(
        startStep: InitialSetupStep.organizationSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.confirmOrganization();

      final state = container.read(initialSetupControllerProvider);

      expect(state.hasError, isTrue);
      expect(state.error, contains('org_name'));
    });

    test('confirmOrganization with invalid taxId should set error', () {
      final container = createContainer(
        startStep: InitialSetupStep.countrySelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.selectCountry(CountryCode.kzt);
      notifier.confirmCountrySelection();
      notifier.updateOrganization(companyName: 'Test Company', taxId: '123');
      notifier.confirmOrganization();

      final state = container.read(initialSetupControllerProvider);

      expect(state.hasError, isTrue);
      expect(state.error, contains('12'));
    });

    test('confirmOrganization with valid data should move to vatSelection', () {
      final container = createContainer(
        startStep: InitialSetupStep.countrySelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.selectCountry(CountryCode.kzt);
      notifier.confirmCountrySelection();
      notifier.updateOrganization(
        companyName: 'Test Company',
        taxId: '123456789012',
      );
      notifier.confirmOrganization();

      final state = container.read(initialSetupControllerProvider);

      expect(state.currentStep, equals(InitialSetupStep.vatSelection));
    });
  });

  group('InitialSetupController - VAT Selection', () {
    test('setVatPayer should update organization isVatPayer', () {
      final container = createContainer(
        startStep: InitialSetupStep.vatSelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.setVatPayer(false);

      final state = container.read(initialSetupControllerProvider);

      expect(state.organization.isVatPayer, isFalse);
    });

    test('confirmVatSelection should move to employeeSetup', () {
      final container = createContainer(
        startStep: InitialSetupStep.vatSelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.confirmVatSelection();

      final state = container.read(initialSetupControllerProvider);

      expect(state.currentStep, equals(InitialSetupStep.employeeSetup));
    });
  });

  group('InitialSetupController - Employee Setup', () {
    test('updateFirstUser should update firstUser', () {
      final container = createContainer(
        startStep: InitialSetupStep.employeeSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.updateFirstUser(name: 'Admin', pin: '0000');

      final state = container.read(initialSetupControllerProvider);

      expect(state.firstUser.name, equals('Admin'));
      expect(state.firstUser.pin, equals('0000'));
    });

    test('updateSecondUser should update secondUser', () {
      final container = createContainer(
        startStep: InitialSetupStep.employeeSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.updateSecondUser(name: 'Seller', pin: '1111');

      final state = container.read(initialSetupControllerProvider);

      expect(state.secondUser?.name, equals('Seller'));
      expect(state.secondUser?.pin, equals('1111'));
    });

    test('confirmUsers without name should set error', () {
      final container = createContainer(
        startStep: InitialSetupStep.employeeSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.confirmUsers();

      final state = container.read(initialSetupControllerProvider);

      expect(state.hasError, isTrue);
      expect(state.error, contains('admin_name'));
    });

    test('confirmUsers with short PIN should set error', () {
      final container = createContainer(
        startStep: InitialSetupStep.employeeSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.updateFirstUser(name: 'Admin', pin: '12');
      notifier.confirmUsers();

      final state = container.read(initialSetupControllerProvider);

      expect(state.hasError, isTrue);
      expect(state.error, contains('pin_short'));
    });

    test(
      'confirmUsers with valid data should move to operatingModeSelection',
      () {
        final container = createContainer(
          startStep: InitialSetupStep.employeeSetup,
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          initialSetupControllerProvider.notifier,
        );
        notifier.updateFirstUser(name: 'Admin', pin: '0000');
        notifier.confirmUsers();

        final state = container.read(initialSetupControllerProvider);

        expect(
          state.currentStep,
          equals(InitialSetupStep.operatingModeSelection),
        );
      },
    );

    test('confirmUsers validates secondUser PIN if secondUser is set', () {
      final container = createContainer(
        startStep: InitialSetupStep.employeeSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.updateFirstUser(name: 'Admin', pin: '0000');
      notifier.updateSecondUser(name: 'Seller', pin: '12');
      notifier.confirmUsers();

      final state = container.read(initialSetupControllerProvider);

      expect(state.hasError, isTrue);
      expect(state.error, contains('seller_pin_short'));
    });
  });

  group('InitialSetupController - Operating Mode Selection', () {
    test('setOperatingMode should update operatingMode', () {
      final container = createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.setOperatingMode(OperatingMode.restaurant);

      final state = container.read(initialSetupControllerProvider);

      expect(state.operatingMode, equals(OperatingMode.restaurant));
    });

    test('default operatingMode should be retail', () {
      final container = createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      final state = container.read(initialSetupControllerProvider);

      expect(state.operatingMode, equals(OperatingMode.retail));
    });

    test('confirmOperatingMode should move to posSetup', () {
      final container = createContainer(
        startStep: InitialSetupStep.operatingModeSelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.confirmOperatingMode();

      final state = container.read(initialSetupControllerProvider);

      expect(state.currentStep, equals(InitialSetupStep.posSetup));
    });
  });

  group('InitialSetupController - Go Back Navigation', () {
    test('goBack from organizationSetup should return to countrySelection', () {
      final container = createContainer(
        startStep: InitialSetupStep.organizationSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.goBack();

      final state = container.read(initialSetupControllerProvider);

      expect(state.currentStep, equals(InitialSetupStep.countrySelection));
    });

    test('goBack from vatSelection should return to organizationSetup', () {
      final container = createContainer(
        startStep: InitialSetupStep.vatSelection,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.goBack();

      final state = container.read(initialSetupControllerProvider);

      expect(state.currentStep, equals(InitialSetupStep.organizationSetup));
    });

    test('goBack from employeeSetup should return to vatSelection', () {
      final container = createContainer(
        startStep: InitialSetupStep.employeeSetup,
      );
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.goBack();

      final state = container.read(initialSetupControllerProvider);

      expect(state.currentStep, equals(InitialSetupStep.vatSelection));
    });

    test(
      'goBack from operatingModeSelection should return to employeeSetup',
      () {
        final container = createContainer(
          startStep: InitialSetupStep.operatingModeSelection,
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          initialSetupControllerProvider.notifier,
        );
        notifier.goBack();

        final state = container.read(initialSetupControllerProvider);

        expect(state.currentStep, equals(InitialSetupStep.employeeSetup));
      },
    );

    test('goBack from posSetup should return to operatingModeSelection', () {
      final container = createContainer(startStep: InitialSetupStep.posSetup);
      addTearDown(container.dispose);

      final notifier = container.read(initialSetupControllerProvider.notifier);
      notifier.goBack();

      final state = container.read(initialSetupControllerProvider);

      expect(
        state.currentStep,
        equals(InitialSetupStep.operatingModeSelection),
      );
    });
  });

  group('InitialSetupController - Data Classes', () {
    test('EmployeeInfo.isComplete should check name and pin', () {
      const incomplete = EmployeeInfo();
      const withName = EmployeeInfo(name: 'Test');
      const withShortPin = EmployeeInfo(name: 'Test', pin: '12');
      const complete = EmployeeInfo(name: 'Test', pin: '1234');

      expect(incomplete.isComplete, isFalse);
      expect(withName.isComplete, isFalse);
      expect(withShortPin.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });

    test('OrganizationInfo.isComplete should check companyName and taxId', () {
      const incomplete = OrganizationInfo();
      const withName = OrganizationInfo(companyName: 'Test');
      const complete = OrganizationInfo(
        companyName: 'Test',
        taxId: '123456789012',
      );

      expect(incomplete.isComplete, isFalse);
      expect(withName.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });

    test('PosConfigInfo.isComplete should check cashBoxName', () {
      const incomplete = PosConfigInfo();
      const complete = PosConfigInfo(cashBoxName: 'Касса 1');

      expect(incomplete.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });
  });

  group('InitialSetupController - Default PIN Values', () {
    test('default admin PIN is accessible as 0000', () {
      const user = EmployeeInfo(name: 'Администратор', pin: '0000');
      expect(user.isComplete, isTrue);
    });

    test('default seller PIN is accessible as 1111', () {
      const user = EmployeeInfo(name: 'Продавец', pin: '1111');
      expect(user.isComplete, isTrue);
    });
  });
}
