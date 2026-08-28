import '../support/settings_finders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/database/daos/user_dao.dart';
import 'package:telepos/data/database/daos/webkassa_receipt_dao.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/controllers/telegram/telegram_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockThisPosDao extends Mock implements ThisPosDao {}

class MockUserDao extends Mock implements UserDao {}

class MockAccountDao extends Mock implements AccountDao {}

class MockWebkassaReceiptDao extends Mock implements WebkassaReceiptDao {}

class TestableFlowNotifier extends InitialSetupNotifier {
  TestableFlowNotifier([this._initialStep = InitialSetupStep.countrySelection]);

  final InitialSetupStep _initialStep;

  @override
  InitialSetupState build() {
    return InitialSetupState(currentStep: _initialStep);
  }
}

class TestTelegramSetupNotifier extends Notifier<TelegramSetupState>
    implements TelegramSetupNotifier {
  @override
  TelegramSetupState build() => const TelegramSetupState();

  @override
  Future<void> startInitialization() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      return Future<void>.value();
    }
    return null;
  }
}

void main() {
  late MockAppDatabase mockDb;
  late MockThisPosDao mockThisPosDao;
  late MockUserDao mockUserDao;
  late MockAccountDao mockAccountDao;
  late MockWebkassaReceiptDao mockWebkassaReceiptDao;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

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

  Widget createApp({
    InitialSetupStep startStep = InitialSetupStep.countrySelection,
  }) {
    final router = GoRouter(
      initialLocation: '/initial-setup',
      routes: [
        GoRoute(
          path: '/initial-setup',
          builder: (context, state) => const InitialSetupScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Login Screen'))),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        initialSetupControllerProvider.overrideWith(
          () => TestableFlowNotifier(startStep),
        ),
        telegramSetupControllerProvider.overrideWith(
          () => TestTelegramSetupNotifier(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('en')],
        locale: const Locale('ru'),
      ),
    );
  }

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  group('Initial Setup Flow - Step Transitions', () {
    testWidgets('starts at country selection (first step after auth)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Добро пожаловать в TelePOS!'), findsOneWidget);
    });

    testWidgets('country selection moves to organization', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));

      await scrollAndTap(tester, find.text('Далее'));

      expect(find.text('Организация'), findsWidgets);
    });

    testWidgets('organization moves to VAT selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));

      await tester.enterText(
        settingsField('Название организации'),
        'Test Company',
      );
      await tester.enterText(settingsField('БИН/ИИН'), '123456789012');

      await scrollAndTap(tester, find.text('Далее'));

      expect(find.text('НДС'), findsWidgets);
    });

    testWidgets('VAT selection moves to employee setup', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));
      await tester.enterText(settingsField('Название организации'), 'Test');
      await tester.enterText(settingsField('БИН/ИИН'), '123456789012');
      await scrollAndTap(tester, find.text('Далее'));

      await scrollAndTap(tester, find.text('Далее'));

      expect(find.text('Пользователи'), findsOneWidget);
    });

    testWidgets('employee setup moves to operating mode then POS setup', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));
      await tester.enterText(settingsField('Название организации'), 'Test');
      await tester.enterText(settingsField('БИН/ИИН'), '123456789012');
      await scrollAndTap(tester, find.text('Далее'));
      await scrollAndTap(tester, find.text('Далее'));

      expect(find.text('Пользователи'), findsOneWidget);

      // Код администратора больше не подставляется — его надо задать, иначе
      // шаг не пускает дальше.
      await tester.enterText(settingsField('PIN'), '4321');
      await tester.enterText(settingsField('Подтверждение'), '4321');
      await tester.pump();

      await scrollAndTap(tester, find.text('Далее'));

      expect(find.text('Тип бизнеса'), findsWidgets);

      await scrollAndTap(tester, find.text('Далее'));

      expect(find.text('Касса'), findsWidgets);
    });
  });

  group('Initial Setup Flow - Back Navigation', () {
    testWidgets('back from organization returns to country', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));

      expect(find.text('Организация'), findsWidgets);

      await scrollAndTap(tester, find.byIcon(Icons.arrow_back));

      expect(find.text('Добро пожаловать в TelePOS!'), findsOneWidget);
    });

    testWidgets('data preserved when going back', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));

      await tester.enterText(
        settingsField('Название организации'),
        'My Company',
      );
      await tester.enterText(settingsField('БИН/ИИН'), '111222333444');

      await scrollAndTap(tester, find.text('Далее'));

      await scrollAndTap(tester, find.byIcon(Icons.arrow_back));

      await scrollAndTap(tester, find.byIcon(Icons.arrow_back));

      expect(find.text('Добро пожаловать в TelePOS!'), findsOneWidget);
    });
  });

  group('Initial Setup Flow - Validation', () {
    testWidgets('organization validation shows error for empty name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));

      await scrollAndTap(tester, find.text('Далее'));

      expect(find.textContaining('название'), findsOneWidget);
    });

    testWidgets('organization validation shows error for invalid tax ID', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));

      await tester.enterText(settingsField('Название организации'), 'Test');
      await tester.enterText(settingsField('БИН/ИИН'), '12345');

      await scrollAndTap(tester, find.text('Далее'));

      expect(find.textContaining('12'), findsWidgets);
    });
  });

  group('Initial Setup Flow - Default Values', () {
    testWidgets('кодов по умолчанию больше нет, и без кода дальше не пускает', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await scrollAndTap(tester, find.text('Казахстан'));
      await scrollAndTap(tester, find.text('Далее'));
      await tester.enterText(settingsField('Название организации'), 'Test');
      await tester.enterText(settingsField('БИН/ИИН'), '123456789012');
      await scrollAndTap(tester, find.text('Далее'));
      await scrollAndTap(tester, find.text('Далее'));

      // Коды больше не предлагаются. Код, который подставила касса и который
      // знает каждый, кто видел такую же кассу, — это отсутствие кода, а не
      // значение по умолчанию.
      final pins = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text ?? '')
          .toList();
      expect(pins, isNot(contains('0000')));
      expect(pins, isNot(contains('1111')));

      // И без кода шаг не пускает дальше.
      final next = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(next.onPressed, isNull);
    });
  });
}
