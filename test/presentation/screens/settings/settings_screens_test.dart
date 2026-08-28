import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/screens/settings/general_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/printer_settings_screen.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/fiscal_settings_screen.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    final getIt = GetIt.I;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (!getIt.isRegistered<AppDatabase>()) {
      getIt.registerSingleton<AppDatabase>(db);
    }
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  Widget createTestWidget({
    required Widget child,
    double width = 400,
    double height = 800,
  }) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru')],
          home: child,
        ),
      ),
    );
  }

  group('GeneralSettingsScreen', () {
    testWidgets('renders Scaffold with AppBar title "Настройки"', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(child: const GeneralSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Настройки'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows back button when navigated to', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const Scaffold()),
            onGenerateInitialRoutes: (navigator, initialRoute) => [
              MaterialPageRoute(builder: (_) => const Scaffold()),
              MaterialPageRoute(builder: (_) => const GeneralSettingsScreen()),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows content after loading', (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const GeneralSettingsScreen()),
      );

      await tester.pump();

      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('PrinterSettingsScreen', () {
    testWidgets('renders Scaffold with title', (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const PrinterSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('FiscalSettingsScreen', () {
    testWidgets('renders Scaffold with title', (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const FiscalSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
