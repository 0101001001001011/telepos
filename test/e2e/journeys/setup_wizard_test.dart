library;

import '../../support/settings_finders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_routes.dart' show AppRoutes;
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/global_product_import_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';

import '../pages/setup_wizard_page.dart';
import '../support/harness.dart';

class _NoopProductImport extends GlobalProductImportService {
  _NoopProductImport(AppDatabase db)
    : super(
        db.globalProductDao,
        db.categoryDao,
        db.productInfoDao,
        db.productPriceDao,
      );

  @override
  Future<bool> needsImport() async => false;

  @override
  Future<int> import({
    void Function(double progress, String message)? onProgress,
    String? fromFile,
  }) async {
    onProgress?.call(1.0, 'skipped (test)');
    return 0;
  }
}

Future<void> pumpWizard(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: AppRoutes.initialSetup,
    routes: [
      GoRoute(
        path: AppRoutes.initialSetup,
        builder: (_, __) => const InitialSetupScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
    ],
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
  await tester.pumpAndSettle();
}

void main() {
  final h = E2eHarness();
  late SetupWizardPage wizard;

  setUpAll(() async {
    await h.setUp();

    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });

  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.quickProducts).go();
    await h.db.delete(h.db.productPrices).go();
    await h.db.delete(h.db.productInfos).go();
    await h.db.delete(h.db.users).go();
    await h.db.delete(h.db.thisPosEntries).go();
    await h.db.delete(h.db.accounts).go();
    await h.db.delete(h.db.categories).go();

    expect(await h.db.thisPosDao.exists(), isFalse);
    expect(await h.db.userDao.hasUsers(), isFalse);

    GetIt.I.registerSingleton<GlobalProductImportService>(
      _NoopProductImport(h.db),
    );
  });

  group('Setup wizard — offline completion', () {
    test(
      'offline first-launch routes to the setup wizard (not login)',
      () async {
        final state = await GetIt.I<StartupStateRepository>().watch().first;
        expect(state.configured, isFalse);

        final result = await GetIt.I<FirstLaunchRepository>().determineResult();
        expect(
          result,
          FirstLaunchResult.offlineMode,
          reason: 'Empty + offline must require the setup wizard, never login',
        );

        // Deciding "offline first launch" has to leave the till identifiable.
        expect(GetIt.I<LocalProperties>().posKey, isNotNull);
        expect(GetIt.I<LocalProperties>().posKey, isNotEmpty);
      },
    );

    testWidgets(
      'wizard opens on the country step and never asks for an account',
      (tester) async {
        await pumpWizard(tester);
        wizard = SetupWizardPage(tester);
        await wizard.waitForFirstStep();

        wizard.expectOnWizard();
        // The wizard used to open on a choice between registering, signing in
        // and "set up offline". All three talked to a server this project no
        // longer has, so the offline path was the only one that ever worked and
        // the other two were dead ends presented as options.
        wizard.expectNoAccountQuestions();
        wizard.expectStepTitle('Добро пожаловать в TelePOS!');
        expect(find.text(E2eHarness.cashierName), findsNothing);
      },
    );

    testWidgets('walks the wizard fully OFFLINE to login + persists config', (
      tester,
    ) async {
      await pumpWizard(tester);
      wizard = SetupWizardPage(tester);
      await wizard.waitForFirstStep();

      wizard.expectNoAccountQuestions();

      wizard.expectStepTitle('Добро пожаловать в TelePOS!');
      await wizard.selectCountryAndNext('Казахстан');

      await wizard.fillOrganizationAndNext(
        companyName: 'ТОО Офлайн Тест',
        taxId: '123456789012',
      );

      await wizard.tapNext();

      wizard.expectStepTitle('Пользователи');
      // Код администратора больше не подставляется мастером: пока его не
      // задали, шаг дальше не пускает.
      await tester.enterText(settingsField('PIN'), '4321');
      await tester.enterText(settingsField('Подтверждение'), '4321');
      await tester.pump();
      await wizard.tapNext();

      wizard.expectStepTitle('Тип бизнеса');
      await wizard.tapNext();

      wizard.expectStepTitle('Касса');
      final cashBox = settingsField('Название кассы');
      expect(cashBox, findsOneWidget);
      await tester.enterText(cashBox, 'Касса Офлайн');
      await tester.pump();
      await wizard.tapNext();

      wizard.expectStepTitle('Фискализация');
      await wizard.tapNext();

      await wizard.tapNext();

      await wizard.tapNext();

      await wizard.tapNext();

      wizard.expectStepTitle('Проверка');
      await wizard.tapDone();

      wizard.expectReachedLogin();

      expect(
        await h.db.thisPosDao.exists(),
        isTrue,
        reason: 'ThisPos config must be persisted by the wizard',
      );
      expect(
        await h.db.userDao.hasUsers(),
        isTrue,
        reason: 'The owner user must be created',
      );

      final thisPos = await h.db.thisPosDao.get();
      expect(thisPos, isNotNull);
      expect(thisPos!.companyName, 'ТОО Офлайн Тест');
      expect(thisPos.iinbin, '123456789012');
      expect(thisPos.cashBoxName, 'Касса Офлайн');
      // Inverted deliberately. This used to demand an RSA public key "for PIN
      // encryption", and that key was the defect: it sat in `ThisPos`, in the
      // same database as the values it was supposed to protect, and the
      // encryption under it was unpadded and deterministic — so anyone holding
      // the file could rebuild every PIN from it. PINs are now PBKDF2
      // derivations over a per-user salt and no key is involved.
      //
      // The column stays, because an installation upgrading from the old
      // scheme still needs it to read its existing records once. A **new**
      // installation must not create one: a stored key with nothing to decrypt
      // is a leftover that would outlive the reason it existed.
      expect(
        thisPos.rsaPublicKey,
        isNull,
        reason:
            'a fresh installation stores no RSA key — PINs are hashed, and '
            'the key this used to require lived in the same database as the '
            'PINs it protected',
      );

      final owners = await (h.db.select(
        h.db.users,
      )..where((u) => u.role.equals(0))).get();
      expect(owners, isNotEmpty, reason: 'An owner user must be created');
      final owner = owners.first;
      expect(owner.name, 'Администратор');
      expect(
        owner.passwordEnc,
        isNotNull,
        reason: 'PIN must be persisted (encrypted), not null',
      );
      expect(
        owner.passwordEnc,
        isNot('0000'),
        reason: 'PIN must be RSA-encrypted, never stored as plaintext',
      );

      expect(
        await h.db.accountDao.countPosAccounts(),
        greaterThanOrEqualTo(1),
        reason: 'A POS cash account must be created during setup',
      );
    });

    testWidgets('invalid organization input blocks progress (validation)', (
      tester,
    ) async {
      await pumpWizard(tester);
      wizard = SetupWizardPage(tester);
      await wizard.waitForFirstStep();

      wizard.expectStepTitle('Добро пожаловать в TelePOS!');
      await wizard.selectCountryAndNext('Казахстан');

      wizard.expectStepTitle('Название организации');
      await wizard.tapNext();

      expect(
        settingsField('Название организации'),
        findsOneWidget,
        reason: 'Empty org name must block advancing past the org step',
      );

      final nameField = settingsField('Название организации');
      await tester.enterText(nameField, 'ТОО X');
      await tester.pump();
      final taxField = settingsField('БИН/ИИН');
      await tester.enterText(taxField, '123');
      await tester.pump();
      await wizard.tapNext();

      expect(
        settingsField('БИН/ИИН'),
        findsOneWidget,
        reason: 'Invalid (short) BIN must block advancing',
      );
    });
  });
}
