library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/fiscal_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/user_management_screen.dart';
import 'package:telepos/presentation/screens/settings/wms_settings_screen.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();

    GetIt.I.registerSingleton<AppDatabase>(h.db);

    // No RSA key is seeded on purpose: creating a user must work on an
    // installation that has none, which is every installation created after
    // the PBKDF2 change. The screen used to refuse outright without one.

    final users = await h.db.userDao.findAll();
    if (users.isNotEmpty) {
      await h.db.userDao.updateUser(
        users.first.id,
        const UsersCompanion(role: Value(0)),
      );
    }
  });

  tearDownAll(() => h.tearDown());

  AppDatabase db() => GetIt.I<AppDatabase>();

  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 4; round++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('ru'),
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  group('Settings: User Management CRUD (PIN encrypted)', () {
    testWidgets('create (valid) → user persisted with encrypted PIN', (
      t,
    ) async {
      await pumpScreen(t, const UserManagementScreen());

      expect(
        find.text(E2eHarness.cashierName),
        findsOneWidget,
        reason: 'seeded cashier must render in the user list',
      );

      final before = await db().userDao.findAll();
      final beforeCount = before.length;

      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      expect(
        find.text('Новый пользователь'),
        findsOneWidget,
        reason: 'FAB must open the create-user dialog',
      );

      expect(
        find.widgetWithText(TextFormField, 'Имя'),
        findsOneWidget,
        reason: 'create dialog Profile tab must show the name field',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Имя'),
        'Менеджер Бекзат',
      );
      await settle(t);

      await t.tap(find.widgetWithText(Tab, 'PIN'));
      await settle(t);
      for (final ch in '1234'.split('')) {
        await t.tap(find.widgetWithText(ElevatedButton, ch).last);
        await t.pump(const Duration(milliseconds: 40));
      }
      await settle(t);

      await t.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await settle(t);

      final after = await db().userDao.findAll();
      expect(
        after.length,
        beforeCount + 1,
        reason: 'creating a user must persist exactly one new row',
      );
      final created = after.firstWhere((u) => u.name == 'Менеджер Бекзат');
      expect(created.status, 'active');

      expect(
        created.passwordEnc,
        isNotNull,
        reason: 'created user must have a stored credential',
      );
      expect(
        created.passwordEnc,
        isNot('1234'),
        reason: 'PIN must NOT be stored in plaintext',
      );
      expect(
        created.passwordEnc!.contains('1234'),
        isFalse,
        reason: 'nor anywhere inside the stored value',
      );
      expect(
        PinCredential.isCurrentScheme(created.passwordEnc!),
        isTrue,
        reason:
            'the screen must write the PBKDF2 scheme, not the superseded '
            'deterministic one',
      );
      expect(
        PinCredential.check(pin: '1234', stored: created.passwordEnc).isOk,
        isTrue,
        reason: 'the created user must actually be able to log in (finding #5)',
      );
      expect(
        PinCredential.check(pin: '4321', stored: created.passwordEnc).isOk,
        isFalse,
        reason: 'and a wrong PIN must not open the account',
      );
      expect(
        created.passwordEnc,
        isNot(PinCredential.create('1234')),
        reason:
            'the stored value must depend on a fresh random salt — this is the '
            'assertion that used to read "must equal RSA-encrypt(1234, key)", '
            'which is exactly the property that made the old scheme breakable',
      );

      expect(
        find.text('Менеджер Бекзат'),
        findsOneWidget,
        reason: 'created user must appear in the list after save',
      );
    });

    testWidgets(
      'create (default role, no permission tab touched) → save writes '
      'rows for ALL permission keys, not just the ones toggled off',
      (t) async {
        await pumpScreen(t, const UserManagementScreen());

        await t.tap(find.byType(FloatingActionButton));
        await settle(t);

        await t.enterText(
          find.widgetWithText(TextFormField, 'Имя'),
          'Кассир БезКасаний',
        );
        await settle(t);

        await t.tap(find.widgetWithText(Tab, 'PIN'));
        await settle(t);
        for (final ch in '5678'.split('')) {
          await t.tap(find.widgetWithText(ElevatedButton, ch).last);
          await t.pump(const Duration(milliseconds: 40));
        }
        await settle(t);

        // Deliberately never opens the Permissions tab — this is "create
        // and don't touch anything", the exact path that used to write
        // zero permission rows because the screen only ever wrote the keys
        // switched OFF, and nothing was switched here.
        await t.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
        await settle(t);

        final created = (await db().userDao.findAll()).firstWhere(
          (u) => u.name == 'Кассир БезКасаний',
        );
        expect(
          created.role,
          3,
          reason: 'the create dialog defaults _selectedRole to cashier (3), '
              'not owner — so this path must go through setPermissions, '
              'not the owner skip',
        );

        final rows = await db().userPermissionDao.findByUserId(created.id);
        expect(
          rows,
          isNotEmpty,
          reason:
              '"create and don\'t touch" must not be the default path to '
              'zero permission rows — that was the whole point of this '
              'task',
        );
        expect(
          rows.map((r) => r.permissionKey).toSet(),
          PermissionKeys.allPermissions,
          reason:
              'the create form must write a row for every key the user '
              'could see and could have toggled — not only the ones '
              'switched off, the same as the edit form already does',
        );
        expect(
          rows.every((r) => r.isAllowed),
          isTrue,
          reason:
              'the create dialog defaults every switch to ON, and nothing '
              'was touched, so every written row must be allowed',
        );
      },
    );

    testWidgets('create (invalid) → validation blocks save, no new row', (
      t,
    ) async {
      await pumpScreen(t, const UserManagementScreen());

      final before = (await db().userDao.findAll()).length;

      await t.tap(find.byType(FloatingActionButton));
      await settle(t);

      await t.tap(find.widgetWithText(Tab, 'PIN'));
      await settle(t);
      for (final ch in '12'.split('')) {
        await t.tap(find.widgetWithText(ElevatedButton, ch).last);
        await t.pump(const Duration(milliseconds: 40));
      }
      await settle(t);
      await t.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await settle(t);

      expect(
        find.text('Введите имя'),
        findsWidgets,
        reason: 'empty name must surface a validation message',
      );
      final after = (await db().userDao.findAll()).length;
      expect(after, before, reason: 'invalid input must NOT create a user');

      await t.tap(find.widgetWithText(TextButton, 'Отмена'));
      await settle(t);
    });

    testWidgets('update → edit name + block status persists', (t) async {
      await pumpScreen(t, const UserManagementScreen());

      await t.tap(find.text(E2eHarness.cashierName));
      await settle(t);
      expect(
        find.text('Редактирование'),
        findsOneWidget,
        reason: 'tapping a user must open the edit dialog',
      );

      expect(
        find.byType(TextFormField),
        findsOneWidget,
        reason: 'edit dialog must show only the name field (no PIN)',
      );

      await t.enterText(
        find.byType(TextFormField).first,
        'Кассир Айгуль (off)',
      );
      await t.tap(find.widgetWithText(SwitchListTile, 'Активен'));
      await settle(t);
      await t.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await settle(t);

      final users = await db().userDao.findAll();
      final edited = users.firstWhere((u) => u.name == 'Кассир Айгуль (off)');
      expect(
        edited.status,
        'blocked',
        reason: 'toggling off must persist status=blocked',
      );
      expect(find.text('Кассир Айгуль (off)'), findsOneWidget);
    });

    testWidgets('delete → user removed THROUGH the UI, gone from list', (
      t,
    ) async {
      final id = await db().userDao.getNextId();
      await db().userDao.insertUser(
        UsersCompanion(
          id: Value(id),
          name: const Value('Удаляемый Пользователь'),
          role: const Value(3),
          status: const Value('active'),
          editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        ),
      );

      await pumpScreen(t, const UserManagementScreen());
      expect(
        find.text('Удаляемый Пользователь'),
        findsOneWidget,
        reason: 'newly inserted user must render in the list',
      );

      await t.tap(find.text('Удаляемый Пользователь'));
      await settle(t);
      expect(
        find.text('Редактирование'),
        findsOneWidget,
        reason: 'tapping a user must open the edit dialog',
      );
      expect(
        find.byIcon(Icons.delete),
        findsOneWidget,
        reason: 'edit dialog must offer a delete action (FIXED)',
      );

      await t.tap(find.byIcon(Icons.delete));
      await settle(t);
      expect(
        find.text('Удалить пользователя?'),
        findsOneWidget,
        reason: 'delete must require confirmation',
      );

      await t.tap(find.widgetWithText(TextButton, 'Удалить').last);
      await settle(t);

      final after = await db().userDao.findAll();
      expect(
        after.any((u) => u.id == id),
        isFalse,
        reason: 'confirming delete must remove the user row from the DB',
      );

      await settle(t);
      expect(
        find.text('Удаляемый Пользователь'),
        findsNothing,
        reason: 'deleted user must not render in the list anymore',
      );
    });
  });

  group(
    'Settings: Fiscal operator selection (multi-operator, prefs store)',
    () {
      testWidgets(
        'select WebKassa, enter creds, save → persists to prefs store',
        (t) async {
          await pumpScreen(t, const FiscalSettingsScreen());

          expect(
            find.text('WebKassa'),
            findsWidgets,
            reason: 'fiscal operator selector must list WebKassa',
          );

          await t.tap(find.byKey(const ValueKey('fiscal-operator-webkassa')));
          await settle(t);

          await t.enterText(
            find.byKey(const ValueKey('fiscal-login')),
            'cashier@shop.kz',
          );
          await t.enterText(
            find.byKey(const ValueKey('fiscal-password')),
            's3cret',
          );
          await t.enterText(
            find.byKey(const ValueKey('fiscal-apikey')),
            'X-API-KEY-123',
          );
          await t.enterText(
            find.byKey(const ValueKey('fiscal-cashbox')),
            'SWK00033717',
          );
          await settle(t);

          await t.tap(find.widgetWithText(TextButton, 'Сохранить').first);
          await settle(t);

          final prefs = await SharedPreferences.getInstance();
          final saved = FiscalSettingsStore(prefs).load();
          expect(
            saved.operatorType,
            FiscalOperatorType.webkassa,
            reason: 'selected operator must persist',
          );
          expect(saved.login, 'cashier@shop.kz');
          expect(saved.apiKey, 'X-API-KEY-123');
          expect(saved.cashboxUniqueNumber, 'SWK00033717');
          expect(saved.baseUrl, 'https://devkkm.webkassa.kz');
          expect(saved.isEnabled, isTrue);

          await pumpScreen(t, const FiscalSettingsScreen());
          expect(
            find.text('cashier@shop.kz'),
            findsWidgets,
            reason: 'reopened screen must restore the saved login',
          );
          expect(
            find.text('SWK00033717'),
            findsWidgets,
            reason: 'reopened screen must restore the saved ЗНМ',
          );
        },
      );

      testWidgets(
        'select None → fiscalization disabled (stays offline-capable)',
        (t) async {
          await pumpScreen(t, const FiscalSettingsScreen());

          await t.tap(find.byKey(const ValueKey('fiscal-operator-none')));
          await settle(t);
          await t.tap(find.widgetWithText(TextButton, 'Сохранить').first);
          await settle(t);

          final prefs = await SharedPreferences.getInstance();
          final saved = FiscalSettingsStore(prefs).load();
          expect(
            saved.operatorType,
            FiscalOperatorType.none,
            reason: 'None operator must disable fiscalization',
          );
          expect(
            saved.isEnabled,
            isFalse,
            reason: 'POS stays usable offline with no operator',
          );
        },
      );
    },
  );

  group('Settings: WMS (guards #43)', () {
    testWidgets(
      'change picking strategy + expiry days + cost method, save, reopen',
      (t) async {
        await pumpScreen(t, const WmsSettingsScreen());
        expect(
          find.text('Настройки WMS'),
          findsWidgets,
          reason: 'WMS settings screen must render',
        );

        final strategyDd = find.byType(DropdownButtonFormField<String>).at(0);
        await t.tap(strategyDd);
        await settle(t);
        await t.tap(find.text('FIFO — первый пришёл, первый ушёл').last);
        await settle(t);

        final costDd = find.byType(DropdownButtonFormField<String>).at(1);
        await t.tap(costDd);
        await settle(t);
        await t.tap(find.text('Средневзвешенная стоимость').last);
        await settle(t);

        final slider = find.byType(Slider).first;
        await t.drag(slider, const Offset(120, 0));
        await settle(t);

        final saveBtn = find.widgetWithText(TextButton, 'Сохранить');
        expect(
          saveBtn,
          findsWidgets,
          reason: 'changing a setting must reveal the Save action',
        );
        await t.tap(saveBtn.first);
        await settle(t);
        expect(
          find.text('Настройки WMS сохранены'),
          findsOneWidget,
          reason: 'save must confirm via snackbar',
        );

        final saved = await db().wmsConfigDao.getConfig();
        expect(
          saved,
          isNotNull,
          reason: 'WMS config row must exist after save',
        );

        expect(
          saved!.defaultPickingStrategy,
          'fifo',
          reason: 'picking strategy FIFO must persist (#43)',
        );

        expect(
          saved.expiryWarningDays,
          isNotNull,
          reason: 'expiry warning days must persist (#43)',
        );
        final savedExpiry = saved.expiryWarningDays!;
        expect(
          savedExpiry,
          greaterThan(30),
          reason:
              'dragging the expiry slider right must persist a higher value',
        );

        expect(
          saved.costMethod,
          'AVG',
          reason:
              '#43: selecting "Средневзвешенная стоимость" (AVG) must persist '
              'to the WmsConfigs.costMethod column',
        );

        await pumpScreen(t, const WmsSettingsScreen());

        expect(
          find.text('FIFO — первый пришёл, первый ушёл'),
          findsWidgets,
          reason: 'reopened WMS screen must restore FIFO picking strategy',
        );

        expect(
          find.text('$savedExpiry дн.'),
          findsWidgets,
          reason: 'reopened WMS screen must restore the saved expiry days',
        );

        expect(
          find.text('Средневзвешенная стоимость'),
          findsWidgets,
          reason:
              '#43 FIXED: reopened WMS screen must restore the saved AVG cost '
              'method (round-tripped via WmsConfigEntity.costMethod)',
        );
      },
    );

    testWidgets('Empty: fresh config loads with defaults shown', (t) async {
      await pumpScreen(t, const WmsSettingsScreen());
      expect(
        find.byType(DropdownButtonFormField<String>),
        findsWidgets,
        reason: 'WMS screen must render its controls even with no saved config',
      );
      expect(
        find.byType(Slider),
        findsWidgets,
        reason: 'WMS screen must render the expiry/ABC sliders',
      );
    });
  });
}
