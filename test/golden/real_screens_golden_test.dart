@Tags(['golden'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/config/background_task_manager.dart';
import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

import '../e2e/support/harness.dart' show releaseLoginScreen;

/// Эталоны **настоящих** экранов, а не их макетов.
///
/// Причина завести отдельный файл названа измерением. `screens_golden_test`
/// и `product_doc_golden_test` вместе дают 44 эталона, и все 44 сняты с
/// `_Mock`-виджетов, крашеных `Colors.grey`, `Colors.white`, `Colors.blue` и
/// `Color(0xFF1E88E5)` напрямую. Проверено 2026-08-03: смена всей темы
/// приложения — палитра, типографика, снятые тени — не изменила в них **ни
/// одного пикселя**. Такой эталон сравнивает макет сам с собой и о приложении
/// не говорит ничего.
///
/// Здесь экран поднимается через настоящий граф зависимостей поверх БД в
/// памяти, ровно как в e2e-сценариях, и потому реагирует на тему.
void main() {
  late AppDatabase db;
  var talkerReady = false;

  Future<void> boot(WidgetTester tester, String location) async {
    BackgroundTaskManager.disabledForTests = true;
    SharedPreferences.setMockInitialValues({});
    if (!talkerReady) {
      app_log.installLogger(Talker());
      talkerReady = true;
    }
    GetIt.I.allowReassignment = true;

    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    await configureDependencies(logger: app_log.talker);
    GetIt.I.registerSingleton<AppDatabase>(db);

    final prefs = await SharedPreferences.getInstance();
    final base = createRouter();
    final router = GoRouter(
      initialLocation: location,
      routes: base.configuration.routes,
    );

    await tester.pumpWidget(
      ProviderScope(
        // Без этого LanguageSwitcher валит сборку: провайдер объявлен как
        // обязательный к переопределению и бросает UnimplementedError.
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
  // once a third file needed the identical fix.

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  for (final size in const {
    'mobile': Size(400, 800),
    'desktop': Size(1440, 900),
  }.entries) {
    testWidgets('экран входа — ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await boot(tester, '/login');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/real_login_${size.key}.png'),
      );

      await releaseLoginScreen(tester);
    });
  }
}
