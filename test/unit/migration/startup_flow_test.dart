import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

void main() {
  group('Router: public routes', () {
    // Правка «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 2: здесь раньше стояла собственная локальная копия
    // publicRoutes (четыре записи, без /network-settings) — тест проверял
    // копию, а не настоящий AppRoutes.publicRoutes, и не мог покраснеть,
    // что бы ни стало с настоящим списком; сама копия уже была устаревшей.
    // Полное закрепление состава списка — в
    // test/presentation/router/public_routes_test.dart; здесь остаётся
    // только этот один факт про telegramSetup, читающий настоящий список.
    test('telegramSetup is NOT a public route', () {
      expect(AppRoutes.publicRoutes.contains(AppRoutes.telegramSetup), false);
    });

    test('telegramSetup route still exists (accessible from settings)', () {
      expect(AppRoutes.telegramSetup, '/telegram-setup');
    });

    test('telegramSetup is NOT in standaloneRoutes', () {
      expect(
        AppRoutes.standaloneRoutes.contains(AppRoutes.telegramSetup),
        false,
      );
    });
  });

  group('InitialSetupStep enum', () {
    test('has all required steps', () {
      final steps = InitialSetupStep.values.map((s) => s.name).toSet();
      expect(steps.contains('countrySelection'), true);
      expect(steps.contains('organizationSetup'), true);
      expect(steps.contains('vatSelection'), true);
      expect(steps.contains('employeeSetup'), true);
      expect(steps.contains('operatingModeSelection'), true);
      expect(steps.contains('posSetup'), true);
      expect(steps.contains('fiscalSetup'), true);
      expect(steps.contains('equipmentSetup'), true);
      expect(steps.contains('paymentTerminalSetup'), true);
      expect(steps.contains('businessRulesSetup'), true);
      expect(steps.contains('summary'), true);
      expect(steps.contains('complete'), true);
      expect(steps.contains('unreadable'), true);
    });

    test('does NOT have removed steps', () {
      final steps = InitialSetupStep.values.map((s) => s.name).toSet();
      expect(steps.contains('telegramSetup'), false);
      expect(steps.contains('workModeSelection'), false);
      expect(steps.contains('userCreation'), false);
      // The five account steps went with the Go backend they talked to.
      expect(steps.contains('authChoice'), false);
      expect(steps.contains('register'), false);
      expect(steps.contains('emailVerification'), false);
      expect(steps.contains('login'), false);
    });
  });

  group('InitialSetupState defaults', () {
    test('default state', () {
      const state = InitialSetupState();
      expect(state.currentStep, InitialSetupStep.checking);
      expect(state.isLoading, false);
      expect(state.employees, isEmpty);
      expect(state.telegramConfigured, false);
    });
  });

  group('OrganizationInfo', () {
    test('carries the fields the wizard collects', () {
      const org = OrganizationInfo(
        companyName: 'Test',
        legalName: 'TOO Test',
        taxId: '123',
        legalAddress: 'Addr',
        email: 'e@e.com',
        phone: '+7',
        contactName: 'Contact',
        description: 'Desc',
      );

      expect(org.legalName, 'TOO Test');
      expect(org.email, 'e@e.com');
      expect(org.phone, '+7');
      expect(org.contactName, 'Contact');
      expect(org.description, 'Desc');
      expect(org.isComplete, true);
    });

    test('isComplete requires companyName and taxId', () {
      expect(const OrganizationInfo().isComplete, false);
      expect(const OrganizationInfo(companyName: 'T').isComplete, false);
      expect(
        const OrganizationInfo(companyName: 'T', taxId: '1').isComplete,
        true,
      );
    });

    test('toJson carries the collected fields', () {
      const org = OrganizationInfo(
        companyName: 'N',
        legalName: 'L',
        email: 'e',
      );
      final json = org.toJson();
      expect(json['companyName'], 'N');
      expect(json['legalName'], 'L');
      expect(json['email'], 'e');
    });

    test('no backend identifier survives on the draft', () {
      // The till has no account on any server, so an id issued by one would
      // be a field nothing can ever fill and nothing can ever check.
      expect(
        const OrganizationInfo().toJson().containsKey('backendOrgId'),
        isFalse,
      );
    });
  });

  group('EmployeeInfo', () {
    test('replaces FirstUserInfo (typedef)', () {
      const FirstUserInfo user = EmployeeInfo(name: 'Admin', pin: '0000');
      expect(user.isComplete, true);
      expect(user.position, 'cashier');
    });

    test('roleIndex mapping', () {
      expect(const EmployeeInfo(position: 'admin').roleIndex, 0);
      expect(const EmployeeInfo(position: 'manager').roleIndex, 1);
      expect(const EmployeeInfo(position: 'cashier').roleIndex, 3);
    });

    test('copyWith works', () {
      const emp = EmployeeInfo(name: 'A', pin: '1234');
      final updated = emp.copyWith(name: 'B', position: 'admin');
      expect(updated.name, 'B');
      expect(updated.position, 'admin');
      expect(updated.pin, '1234');
    });
  });
}
