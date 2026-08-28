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

/// Снимки мастера настройки — чтобы «новый вид» был показан, а не заявлен.
///
/// Отличие от `real_screens_golden_test.dart` только в маршруте: там вход, тут
/// мастер. Экран поднимается через настоящий граф зависимостей поверх БД в
/// памяти, поэтому реагирует на тему так же, как в работе.
void main() {
  late AppDatabase db;
  var talkerReady = false;

  Future<void> boot(WidgetTester tester, Brightness brightness) async {
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
      initialLocation: '/initial-setup',
      routes: base.configuration.routes,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? AppTheme.dark
              : AppTheme.light,
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
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  for (final size in const {
    'mobile': Size(400, 800),
    'tablet': Size(834, 1112),
    'desktop': Size(1440, 900),
  }.entries) {
    // Обе темы, а не одна: `AppTheme.dark` подключена 2026-08-04, и это
    // единственный снимок мастера, поднятого через настоящий граф зависимостей
    // — то есть единственное место, где видно шапку с названием шага. Она и
    // осталась после того, как центрированный заголовок внутри шага убрали.
    for (final theme in const {
      'светлая': Brightness.light,
      'тёмная': Brightness.dark,
    }.entries) {
      final suffix = theme.value == Brightness.dark ? '_dark' : '';

      testWidgets('мастер настройки — ${size.key}, ${theme.key}', (
        tester,
      ) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await boot(tester, theme.value);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/wizard_${size.key}$suffix.png'),
        );
      });
    }
  }
}
