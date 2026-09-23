/// Сторож десктопной таблицы маршрутов (задача 17, security-debt-closure).
///
/// **Измерено, не предположено.** `app_router.dart`'s `redirect`
/// (`:567-580` до этой задачи) проверял только «вошёл — не вошёл».
/// `PermissionKeys.routeToPermissionKey()` существовала с задачи 12
/// (написана для браузерной таблицы, `lib/app/router/setup_router.dart`), но
/// десктопный `redirect` её не звал ниоткуда — мёртвый код ровно там, где
/// решался бы вопрос. Настоящей защитой было «скрыть пункт меню»
/// (`nav_destinations.dart`, тем же ключом), не маршрут: прямой переход по
/// адресу проходил у любого вошедшего.
///
/// Эти тесты гоняют настоящий `routerProvider` (`ref.watch` внутри
/// `Consumer`, тот же провайдер, что читает `main.dart`, а не его копию) на
/// настоящей десктопной таблице `_buildRoutes()` через полный DI-граф
/// (`E2eHarness`, тот же стенд, что и `test/e2e/journeys/*`) — вход
/// подставляется напрямую через `appStateProvider.setUserInfo`, тем же
/// приёмом, каким `test/web/wt_setup_router_test.dart` проверяет браузерный
/// сторож, а не через набор PIN: эти тесты проверяют сторож, а не вход.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/additional/additional_screen.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/catalog/catalog_screen.dart';
import 'package:telepos/presentation/screens/history/history_screen.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';
import 'package:telepos/presentation/screens/settings/general_settings_screen.dart';

import '../../e2e/support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  Future<GoRouter> pumpDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    late GoRouter router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) {
            // Настоящий провайдер, тот же, что `main.dart` (`main.dart:312`,
            // `ref.watch(routerProvider)`) — не `createRouter()`, который
            // используют `E2eHarness.pumpApp` и большинство сценариев: та
            // функция строит таблицу без единого `redirect` и потому не
            // может ни доказать, ни опровергнуть сторож.
            router = ref.watch(routerProvider);
            return MaterialApp.router(
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
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    return router;
  }

  void logIn(WidgetTester tester, {required Set<String> permissions}) {
    final context = tester.element(find.byType(MaterialApp));
    ProviderScope.containerOf(context, listen: false)
        .read(appStateProvider.notifier)
        .setUserInfo(
          id: 1,
          name: 'Проверка',
          role: 3,
          permissions: permissions,
        );
  }

  String pathOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  group('маршрут без права', () {
    testWidgets('прямой переход на /sale без nav.sale уводит на дом', (
      tester,
    ) async {
      final router = await pumpDesktop(tester);
      // Роль без `nav.sale` — тот же набор, что `PermissionKeys.roleDefaults
      // [UserRole.user]` (только история и каталог), не придуманный:
      // единственная роль в проекте, у которой нет продажи вовсе.
      logIn(tester, permissions: const {PermissionKeys.navHistory});

      router.go(AppRoutes.sale);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.byType(SaleScreen),
        findsNothing,
        reason:
            'до задачи 17 redirect проверял только вход — этот экран '
            'строился у кого угодно вошедшего, вне зависимости от '
            'nav.sale',
      );
      expect(
        find.byType(HistoryScreen),
        findsOneWidget,
        reason:
            'дом — первый пункт бокового меню, который эта роль '
            'действительно может открыть (nav.history), а не '
            'фиксированный /sale: у роли без nav.sale увод на /sale '
            'заворачивал бы redirect на себя же',
      );
      expect(pathOf(router), AppRoutes.history);
    });

    testWidgets('вошедший с правом на запрошенный маршрут — не задет', (
      tester,
    ) async {
      final router = await pumpDesktop(tester);
      logIn(tester, permissions: const {PermissionKeys.navSale});

      router.go(AppRoutes.sale);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(SaleScreen), findsOneWidget);
      expect(pathOf(router), AppRoutes.sale);
    });
  });

  group('владелец обходит таблицу прав целиком', () {
    testWidgets(
      'allPermissions (LocalAuthRepository._issue для роли owner) открывает '
      'любой nav.*-маршрут без увода',
      (tester) async {
        final router = await pumpDesktop(tester);
        logIn(tester, permissions: PermissionKeys.allPermissions);

        router.go(AppRoutes.settings);
        await tester.pumpAndSettle(const Duration(seconds: 5));
        expect(find.byType(GeneralSettingsScreen), findsOneWidget);
        expect(pathOf(router), AppRoutes.settings);

        router.go(AppRoutes.catalog);
        await tester.pumpAndSettle(const Duration(seconds: 5));
        expect(find.byType(CatalogScreen), findsOneWidget);
        expect(pathOf(router), AppRoutes.catalog);
      },
    );
  });

  group('маршруты без ключа права', () {
    testWidgets('/additional остаётся достижим при самом узком наборе прав — '
        'routeToPermissionKey() его не покрывает, отказ был бы новым '
        'запретом там, где раньше не было даже показа/скрытия', (tester) async {
      final router = await pumpDesktop(tester);
      logIn(tester, permissions: const {PermissionKeys.navHistory});

      router.go(AppRoutes.additional);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(AdditionalScreen), findsOneWidget);
      expect(pathOf(router), AppRoutes.additional);
    });
  });

  group('публичные маршруты и вход не задеты', () {
    testWidgets('без входа /login остаётся собой', (tester) async {
      final router = await pumpDesktop(tester);
      // Сеанс не подставлен: `appState.isLoggedIn == false` здесь, ровно то
      // состояние, в котором стоит любая незалогиненная касса.

      router.go(AppRoutes.login);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(pathOf(router), AppRoutes.login);
    });

    testWidgets(
      'без входа /splash не уводится сторожем на /login — только своим '
      'собственным решением после определения состояния кассы',
      (tester) async {
        final router = await pumpDesktop(tester);

        // Один короткий кадр, а не `pumpAndSettle`: `SplashScreen` сама, по
        // истечении своей задержки, решает, куда идти дальше (это её
        // собственное поведение, не сторож задачи 17, и не то, что здесь
        // проверяется) — полный `pumpAndSettle` дал бы ей время это сделать
        // и превратил бы проверку `redirect` в проверку `SplashScreen`.
        // Немедленно после `go()`, до этого кадра, путь обязан остаться
        // `/splash`: `AppRoutes.publicRoutes` проверяется в `redirect` до
        // входа и до права, синхронно, раньше первого кадра.
        router.go(AppRoutes.splash);
        await tester.pump();

        expect(
          pathOf(router),
          AppRoutes.splash,
          reason:
              '`AppRoutes.publicRoutes` проверяется до входа и до права — '
              'сторож задачи 17 не должен был его тронуть',
        );

        // Не часть проверки выше: только даёт таймеру самой заставки
        // (`SplashScreen`, задержка ~300 мс) отработать и завершиться до
        // конца теста — иначе `flutter_test` находит его висящим
        // ('!timersPending') уже после `expect`, который к этому моменту
        // уже отработал.
        await tester.pumpAndSettle(const Duration(seconds: 2));
      },
    );

    testWidgets('без входа защищённый маршрут по-прежнему уводит на /login '
        '(поведение до задачи 17 не сломано)', (tester) async {
      final router = await pumpDesktop(tester);

      router.go(AppRoutes.sale);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(pathOf(router), AppRoutes.login);
    });
  });
}
