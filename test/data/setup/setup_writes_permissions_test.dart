import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/domain/setup/setup_draft.dart';

/// Task 13 (security-debt-closure, phase 5): before this, the wizard's
/// commit path (`LocalSetupRepository.completeSetup`) never called
/// `UserPermissionDao.setPermissions` at all — every non-owner user the
/// wizard created got zero permission rows. Under today's placebo-free but
/// still "empty table = allow everything" read path
/// (`UserPermissionDao.getAllowedKeys`), that meant "create through the
/// wizard and don't touch anything" was the DEFAULT path to a user with
/// every permission, `settings.*` included — not a corner case.
///
/// This file proves both wizard commit paths now write permission rows
/// derived from `PermissionKeys.roleDefaults` (task 12) for every non-owner
/// user, and that owner accounts get none — `LocalAuthRepository._issue`
/// bypasses the permission table for `owner` entirely, so rows would be
/// unread data, not access control (see `roleDefaults`'s own doc comment).
void main() {
  SetupDraft baseDraft({
    required List<EmployeeInfo> employees,
    EmployeeInfo firstUser = const EmployeeInfo(),
    EmployeeInfo? secondUser,
  }) {
    return SetupDraft(
      countryIndex: 0,
      operatingModeIndex: 0,
      organization: const OrganizationInfo(
        companyName: 'ТОО ТестПОС',
        taxId: '123456789012',
      ),
      posConfig: const PosConfigInfo(cashBoxName: 'Касса-1'),
      fiscalConfig: const FiscalConfigInfo(),
      businessRules: const BusinessRulesConfigInfo(),
      equipment: const EquipmentConfigInfo(),
      paymentTerminal: const PaymentTerminalConfigInfo(),
      employees: employees,
      firstUser: firstUser,
      secondUser: secondUser,
    );
  }

  Future<AppDatabase> completeSetupWith(SetupDraft draft) async {
    final db = AppDatabase(NativeDatabase.memory());
    await LocalSetupRepository(db).completeSetup(draft);
    return db;
  }

  group('employees-list path (multi-staff wizard step)', () {
    test(
      'the owner (staff row #1) gets no permission rows at all — '
      'LocalAuthRepository._issue bypasses the table for owner',
      () async {
        final db = await completeSetupWith(
          baseDraft(
            employees: const [
              EmployeeInfo(name: 'Владелец Тест', pin: '1111'),
              EmployeeInfo(name: 'Кассир Тест', pin: '2222', position: 'cashier'),
            ],
          ),
        );

        final owner = (await db.userDao.findAll()).firstWhere(
          (u) => u.name == 'Владелец Тест',
        );
        expect(owner.role, UserRole.owner.index);

        final rows = await db.userPermissionDao.findByUserId(owner.id);
        expect(
          rows,
          isEmpty,
          reason:
              'owner rows would be dead data — the bypass in _issue never '
              'reads them — writing them would only invite someone to '
              'believe access is controlled by rows that are not consulted',
        );

        await db.close();
      },
    );

    test(
      'a cashier (staff row #2+) gets permission rows derived from '
      'PermissionKeys.roleDefaults[cashier], and none of them are settings.*',
      () async {
        final db = await completeSetupWith(
          baseDraft(
            employees: const [
              EmployeeInfo(name: 'Владелец Тест', pin: '1111'),
              EmployeeInfo(name: 'Кассир Тест', pin: '2222', position: 'cashier'),
            ],
          ),
        );

        final cashier = (await db.userDao.findAll()).firstWhere(
          (u) => u.name == 'Кассир Тест',
        );
        expect(cashier.role, UserRole.cashier.index);

        final rows = await db.userPermissionDao.findByUserId(cashier.id);
        expect(
          rows,
          isNotEmpty,
          reason:
              'a cashier created by the wizard must not end up with zero '
              'permission rows — that was the whole point of this task',
        );

        final keys = rows.map((r) => r.permissionKey).toSet();
        expect(
          keys.where((k) => k.startsWith('settings.')),
          isEmpty,
          reason:
              'PermissionKeys.roleDefaults[cashier] contains no settings.* '
              'key, and the wizard writes exactly that set — not a full '
              '30-key closure with settings.* explicitly denied',
        );

        expect(
          keys,
          PermissionKeys.roleDefaults[UserRole.cashier],
          reason:
              'the wizard must write precisely the cashier role default '
              'set, no more and no less',
        );
        expect(
          rows.every((r) => r.isAllowed),
          isTrue,
          reason: 'every key the wizard writes for a role default is a '
              'granted key, never an explicit denial',
        );

        await db.close();
      },
    );
  });

  group('two-user short path (firstUser/secondUser)', () {
    test(
      'the owner (firstUser) gets no permission rows',
      () async {
        final db = await completeSetupWith(
          baseDraft(
            employees: const [],
            firstUser: const EmployeeInfo(name: 'Владелец', pin: '1111'),
          ),
        );

        final owner = (await db.userDao.findAll()).firstWhere(
          (u) => u.name == 'Владелец',
        );
        expect(owner.role, UserRole.owner.index);

        final rows = await db.userPermissionDao.findByUserId(owner.id);
        expect(rows, isEmpty);

        await db.close();
      },
    );

    test(
      'the secondUser (always a cashier — createCashier) gets permission '
      'rows matching PermissionKeys.roleDefaults[cashier]',
      () async {
        final db = await completeSetupWith(
          baseDraft(
            employees: const [],
            firstUser: const EmployeeInfo(name: 'Владелец', pin: '1111'),
            secondUser: const EmployeeInfo(name: 'Продавец', pin: '2222'),
          ),
        );

        final cashier = (await db.userDao.findAll()).firstWhere(
          (u) => u.name == 'Продавец',
        );
        expect(cashier.role, UserRole.cashier.index);

        final rows = await db.userPermissionDao.findByUserId(cashier.id);
        expect(
          rows,
          isNotEmpty,
          reason:
              'the secondUser short-path cashier must not end up with zero '
              'permission rows either — this is the second of the two '
              'wizard paths that used to write nothing at all',
        );

        final keys = rows.map((r) => r.permissionKey).toSet();
        expect(keys.where((k) => k.startsWith('settings.')), isEmpty);
        expect(keys, PermissionKeys.roleDefaults[UserRole.cashier]);

        await db.close();
      },
    );
  });

  test(
    'the default-owner path (no employees, no firstUser filled in) writes '
    'no permission rows either — same owner bypass',
    () async {
      final db = await completeSetupWith(
        baseDraft(employees: const [], firstUser: const EmployeeInfo()),
      );

      final owner = (await db.userDao.findAll()).single;
      expect(owner.role, UserRole.owner.index);

      final rows = await db.userPermissionDao.findByUserId(owner.id);
      expect(rows, isEmpty);

      await db.close();
    },
  );
}
