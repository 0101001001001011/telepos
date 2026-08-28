library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/security/legacy_pin_cipher.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/presentation/common/navigation/tg_bottom_bar.dart';
import 'package:telepos/presentation/common/navigation/tg_nav_column.dart';

import '../support/harness.dart' show releaseLoginScreen;

const _cashierName = 'Кассир Айгуль';
const _cashierPin = '0000';
const _wrongPin = '9999';

/// The seeded cashier is deliberately stored in the **superseded** scheme, so
/// that this journey walks the upgrade path the way a real till upgrading from
/// an older installation does: the operator types the PIN they already know,
/// gets in, and the record is rewritten underneath them. Nobody is asked to set
/// a PIN again. The user created through the Settings UI further down is stored
/// in the current scheme, so both are covered here.
late final String _legacyKey;

void main() {
  late AppDatabase db;
  late GoRouter router;

  setUpAll(() {
    _legacyKey = LegacyPinCipher.generatePublicKeyBase64();
    app_log.installLogger(Talker());
  });

  Future<void> bootApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    GetIt.I.allowReassignment = true;

    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    // Задача 12: `getPostLoginRoute()` спрашивает `GetIt<HostCapabilities>` на
    // каждом настоящем входе. `main()` регистрирует её сам, до
    // `configureDependencies`; этот тест входит в дерево в обход `main()`.
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);

    await configureDependencies(logger: app_log.talker);
    GetIt.I.registerSingleton<AppDatabase>(db);
    await _seed(db);

    // Личность терминала больше не заводится здесь руками: `LoginNotifier`
    // добывает её сам, лениво, при первой проверке PIN
    // (`_resolveTerminalId` — `TerminalIdentity.currentId()`, а если `null`,
    // то `TerminalRepository.self()` + `remember()`). Этот тест обязан идти
    // тем же путём, каким пойдёт живая касса — заранее выписанный `remember`
    // был бы подпоркой ровно на той дыре, которую этот путь и закрывает.
    final prefs = await SharedPreferences.getInstance();
    final base = createRouter();
    router = GoRouter(
      initialLocation: '/login',
      routes: base.configuration.routes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          supportedLocales: AppLocale.supportedLocales,
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  // `releaseScreen` used to be a private copy of this exact helper — moved
  // to `test/e2e/support/harness.dart::releaseLoginScreen` (imported above)
  // once a third file needed the identical fix, so the three copies could
  // not drift out of sync with each other unnoticed.

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final ch in pin.split('')) {
      final key = find.widgetWithText(ElevatedButton, ch);
      expect(key, findsWidgets, reason: 'keypad digit $ch must be present');
      await tester.tap(key.first);
      await tester.pump(const Duration(milliseconds: 60));
    }
    // Two different clocks have to move for this to resolve, and neither one
    // alone is enough:
    //
    // - the auto-verify debounce (`LoginNotifier._verifyDebounce`, 500 ms) is
    //   a *fake*-clock `Timer`, created while tapping keys above — only
    //   `tester.pump(duration)` advances that clock; a real-time wait inside
    //   `runAsync` does not touch it, so the debounce would never fire there.
    // - once it fires, the check crosses a real isolate
    //   (`LocalAuthRepository` matches candidates inside `Isolate.run`, task
    //   9), and this cashier's seeded record is in the **legacy** scheme —
    //   an RSA decrypt, documented elsewhere in this codebase as measurably
    //   slow (`test/data/auth/local_auth_repository_login_test.dart`: "2048-
    //   битный RSA — медленный"). Only real time lets a real isolate answer;
    //   the fake clock does not touch that, and a fixed short real budget
    //   (tried first: 500 ms) answered the wrong-PIN case reliably but left
    //   the correct-PIN case still mid-flight, landing on `/login` instead
    //   of `/shift` — not a hang, a real assertion failure with the login
    //   simply not finished yet.
    //
    // Interleaving both — the same device `test/e2e/journeys/settings_test.dart`
    // already uses in its `settle()` helper — is what lets each clock do the
    // part only it can do; polling [router] for a change of route, rather
    // than a fixed guessed duration, is what makes this the deterministic
    // wait `pendingVerification` would have been, had it not spanned the
    // fake/real zone boundary the debounce timer put it on the wrong side of.
    for (var round = 0; round < 30; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      if (router.routerDelegate.currentConfiguration.uri.path != '/login') {
        break;
      }
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('Login journey', () {
    testWidgets('READ: login screen lists the seeded cashier', (tester) async {
      await bootApp(tester);

      expect(
        find.text(_cashierName),
        findsWidgets,
        reason: 'Seeded cashier must be offered on the login screen',
      );
      expect(
        find.widgetWithText(ElevatedButton, '1'),
        findsWidgets,
        reason: 'PIN keypad must be rendered for a password-protected user',
      );

      await releaseLoginScreen(tester);
    });

    testWidgets('ERROR: a wrong PIN is rejected, no login', (tester) async {
      await bootApp(tester);
      expect(find.text(_cashierName), findsWidgets);

      await tester.tap(find.text(_cashierName).first);
      await tester.pumpAndSettle();
      await enterPin(tester, _wrongPin);

      expect(
        find.widgetWithText(ElevatedButton, '1'),
        findsWidgets,
        reason: 'Wrong PIN must keep us on the login screen',
      );
      expect(
        find.byType(TgNavColumn).evaluate().isEmpty &&
            find.byType(TgBottomBar).evaluate().isEmpty,
        isTrue,
        reason: 'Wrong PIN must NOT reach the main app shell',
      );
      final hasError = find
          .byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data?.toLowerCase().contains('pin') == true ||
                    w.data?.toLowerCase().contains('пин') == true ||
                    w.data?.toLowerCase().contains('невер') == true),
          )
          .evaluate()
          .isNotEmpty;
      expect(
        hasError,
        isTrue,
        reason: 'An honest wrong-PIN error must be displayed',
      );

      await releaseLoginScreen(tester);
    });

    testWidgets('FLOW: correct encrypted PIN logs in and reaches main app', (
      tester,
    ) async {
      await bootApp(tester);
      expect(find.text(_cashierName), findsWidgets);

      await tester.tap(find.text(_cashierName).first);
      await tester.pumpAndSettle();
      await enterPin(tester, _cashierPin);

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/shift',
        reason: 'Correct PIN must navigate into the app (shift screen)',
      );
      final hasNav =
          find.byType(TgNavColumn).evaluate().isNotEmpty ||
          find.byType(TgBottomBar).evaluate().isNotEmpty;
      expect(
        hasNav,
        isTrue,
        reason: 'Main app navigation surface must be visible after login',
      );

      // The upgrade, through the real screen: the row was seeded in the
      // superseded scheme, the operator typed the PIN they already had, and
      // the record must now be in the current one. This is why the migration
      // costs nobody a new PIN.
      await tester.pumpAndSettle();
      final upgraded = (await db.userDao.findAll())
          .firstWhere((u) => u.name == _cashierName)
          .passwordEnc!;
      expect(
        PinCredential.isCurrentScheme(upgraded),
        isTrue,
        reason: 'a successful login rewrites a pre-upgrade record on the spot',
      );
      expect(
        PinCredential.check(pin: _cashierPin, stored: upgraded).isOk,
        isTrue,
      );
      expect(
        PinCredential.check(pin: _wrongPin, stored: upgraded).isOk,
        isFalse,
      );

      await releaseLoginScreen(tester);
    });

    testWidgets(
      'CREATE (finding #5): user made via Settings UI can log in with PIN',
      (tester) async {
        await bootApp(tester);

        await tester.tap(find.text(_cashierName).first);
        await tester.pumpAndSettle();
        await enterPin(tester, _cashierPin);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/shift');

        router.go('/user-management');
        await tester.pumpAndSettle();
        expect(
          find.text('Пользователи и доступ'),
          findsOneWidget,
          reason: 'User management screen must render',
        );
        expect(find.text(_cashierName), findsWidgets);

        await tester.tap(find.byIcon(TeleposIcons.add).first);
        await tester.pumpAndSettle();
        expect(find.text('Новый пользователь'), findsOneWidget);

        const newName = 'Продавец Болат';
        const newPin = '1111';
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Имя'),
          newName,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(Tab, 'PIN'));
        await tester.pumpAndSettle();
        for (final ch in newPin.split('')) {
          await tester.tap(find.widgetWithText(ElevatedButton, ch).last);
          await tester.pump(const Duration(milliseconds: 60));
        }
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(
          find.text('Новый пользователь'),
          findsNothing,
          reason: 'Create dialog must close on successful save',
        );
        expect(
          find.text(newName),
          findsWidgets,
          reason: 'Newly created user must appear in the user list',
        );

        final created = (await db.userDao.findAll()).firstWhere(
          (u) => u.name == newName,
        );
        expect(created.passwordEnc, isNotNull);
        expect(
          created.passwordEnc,
          isNot(equals(newPin)),
          reason: 'PIN must be hashed, never stored as plaintext',
        );
        expect(
          PinCredential.isCurrentScheme(created.passwordEnc!),
          isTrue,
          reason: 'a user created today is stored in the current scheme',
        );
        expect(
          PinCredential.check(pin: newPin, stored: created.passwordEnc).isOk,
          isTrue,
          reason: 'and the PIN typed into the dialog must verify against it',
        );

        router.go('/login');
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          find.text(newName),
          findsWidgets,
          reason: 'New user must be offered on the login screen',
        );

        await tester.tap(find.text(newName).first);
        await tester.pumpAndSettle();
        await enterPin(tester, newPin);

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/shift',
          reason:
              'User created in Settings with encrypted PIN must be able to log in (finding #5)',
        );
        final hasNav =
            find.byType(TgNavColumn).evaluate().isNotEmpty ||
            find.byType(TgBottomBar).evaluate().isNotEmpty;
        expect(hasNav, isTrue);

        await releaseLoginScreen(tester);
      },
    );
  });
}

Future<void> _seed(AppDatabase db) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(1),
          name: const Value('Продукты'),
          createTime: DateTime.now(),
        ),
      );

  final posAccId = await db.accountDao.createPosAccount(name: 'Касса');
  final bankAccId = await db.accountDao.createAcquiringAccount(
    name: 'Kaspi Bank',
    acquirerId: 1,
  );

  await db.thisPosDao.insertInitialConfig(
    companyName: 'ТОО ТестПОС',
    iinbin: '123456789012',
    cashBoxName: 'Касса-1',
    countryCode: 0,
    currencyCode: 0,
    currencySymbol: '₸',
    currencyNameShort: 'KZT',
    paperWidth: 48,
    printerHeader: null,
    printerFooter: null,
    accountId: posAccId,
    acquiringAccountId: bankAccId,
    rsaPublicKey: _legacyKey,
    sendToOfd: false,
    cashInOut: true,
  );
  await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
      .write(const ThisPosEntriesCompanion(id: Value(1)));

  final encPin = LegacyPinCipher.encryptPin(_cashierPin, _legacyKey);
  final cashierId = await db.userDao.createCashier(
    name: _cashierName,
    passwordEnc: encPin,
  );
  // Задача 14: `createCashier` строк прав не пишет, а после переворота
  // умолчания (задача 16) пустая таблица означает «ничего нельзя».
  // Права заводятся тем же вызовом, каким это делает рабочий код.
  await db.userPermissionDao.setPermissions(cashierId, {
    for (final key in PermissionKeys.allPermissions) key: true,
  });
}
