/// Пробный проход ПЕРВОГО ЗАПУСКА — без записи.
///
/// # Зачем отдельный прогон, когда есть проход мастера
///
/// `wizard_dry_run_test` начинается со строки `router.go(initialSetup)` —
/// то есть **сам переносит кассу на мастер**. Это верно для главы 3, где
/// мастер и есть предмет разговора, но означает, что дорога ДО мастера не
/// проверялась ни разу: доходит ли касса туда сама.
///
/// Глава 2 ровно про это. Зритель поставил кассу и запустил её впервые;
/// всё, что он должен увидеть, — что она сама привела его к настройке, а не
/// к пустому экрану, не к входу с PIN, которого он не заводил, и не к
/// сообщению об ошибке.
///
/// Память проекта прямо говорит: «первый запуск и настройка в одно нажатие
/// всегда работали плохо». Значит мерить надо до камеры, а не на ней.
///
/// # Что здесь проверяется
///
/// Касса поднимается с ПУСТОЙ базой и пустыми настройками и дальше её никто
/// не трогает. Прогон ждёт и печатает, что она показывает сама, а в конце
/// утверждает единственное: она пришла на мастер настройки.
///
/// # Запуск
///
///     flutter test integration_test/first_launch_dry_run_test.dart -d windows
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/l10n/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    // Пусто и то и другое: у только что поставленной кассы нет ни базы, ни
    // запомненных настроек. Подсунуть сюда хоть что-то значило бы снимать
    // не первый запуск, а второй.
    SharedPreferences.setMockInitialValues({});
    app_log.installLogger(Talker());
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);
  });

  tearDownAll(() async => db.close());

  testWidgets('касса сама приводит к настройке, а не ждёт подсказки', (
    tester,
  ) async {
    final startedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          title: 'TelePOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          supportedLocales: AppLocale.supportedLocales,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    /// Где касса сейчас и что показывает — словами, которые видит человек.
    void describe(String when) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((d) => d.trim().isNotEmpty)
          .map((d) => d.trim())
          .toSet()
          .toList();
      final at = DateTime.now().difference(startedAt).inMilliseconds / 1000;
      final where =
          router.routerDelegate.currentConfiguration.uri.toString();
      // ignore: avoid_print
      print(
        '[FIRST] ${at.toStringAsFixed(1)} | $when | маршрут: $where | '
        '${texts.join(" · ")}',
      );
    }

    // Никаких `router.go`: смысл прогона в том, куда касса придёт САМА.
    // Шаги по секунде — чтобы в записи было видно, что именно человек
    // успевает прочитать, пока она поднимается.
    for (var second = 1; second <= 12; second++) {
      await tester.pumpAndSettle(const Duration(seconds: 1));
      describe('секунда $second');
    }

    final landed = router.routerDelegate.currentConfiguration.uri.toString();
    expect(
      landed,
      contains(AppRoutes.initialSetup),
      reason:
          'после первого запуска касса обязана сама оказаться на мастере '
          'настройки. Она на «$landed» — значит человек, поставивший кассу, '
          'видит не то, с чего начинают',
    );
  });
}
