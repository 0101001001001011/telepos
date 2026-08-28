import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/network_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/sessions_screen.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';
import 'package:telepos/presentation/screens/setup/restore_or_new_screen.dart';
import 'package:telepos/presentation/screens/splash/splash_screen.dart';
import 'package:telepos/presentation/screens/terminal/terminal_home_screen.dart';
import 'package:telepos/web/wt_not_ported_screen.dart';

import 'app_routes.dart';

/// The route table a binding gets while only the first-launch wizard has been
/// ported: splash, the wizard, and the restore-or-new fork.
///
/// It is a separate file from the full table on purpose. Choosing the scope at
/// runtime would still compile every screen in, and the browser binding cannot
/// compile screens that reach the database or a printer. The scope has to be a
/// compile-time boundary to mean anything.
///
/// The screens themselves are shared — this says which of them a binding can
/// currently serve, never that the browser has screens of its own. As each
/// screen's contracts gain an implementation that works over the wire, its
/// route moves here. See docs/ARCHITECTURE.md.
///
/// # Таблица обязана отвечать на каждый переход, который умеют делать её
/// собственные экраны
///
/// Правило заведено 2026-08-06 и оплачено дорого. До него в таблице было ровно
/// три записи, а компилируемые ими экраны звали `/login` из пяти мест и
/// `/network-settings` из кнопки Wi-Fi, стоящей на **каждом** шаге мастера.
/// Заказчик прошёл настройку до конца и получил «Page Not Found:
/// `GoException: no routes for location: /login`». Настроить кассу терминал
/// умел; показать после этого хоть что-нибудь — нет.
///
/// Экран, чьи договоры ещё не переехали на провод, получает не отсутствие
/// маршрута, а **названное состояние**: отказ приходит значением (И144).
/// Когда экран переедет, здесь меняется один `builder` — и больше ничего.
/// `/login` переехал задачей 10 (провод входа) и задачей 12 (эта таблица);
/// `/hardware-settings` — планом 2b, задолго до задачи 12 — просто маршрута
/// у него не было, пока дом терминала не дал на него ссылку.
///
/// Сторож — `test/architecture/browser_routes_test.dart`: он обходит граф
/// импортов от этого файла, собирает все `context.go`/`context.push` в
/// достижимых экранах и краснеет, если хоть один ведёт на маршрут, которого
/// здесь нет.
/// [refresh] — то же самое, что десктопный `routerProvider` получает от
/// собственного `_AuthNotifier` (`lib/app/router/app_router.dart`):
/// `GoRouter` не перечитывает `redirect` сам по себе, когда `isLoggedIn`
/// меняется без нажатия — задача 5 (сеанс, отозванный кассой, гасит эту
/// вкладку без единого нажатия) без него осталась бы верной только для
/// состояния `LoginNotifier`, а сама вкладка так и стояла бы на прежнем
/// экране до следующей навигации. `createSetupRouter()` зовётся раньше, чем
/// существует `ProviderContainer` (см. докстринг `redirect` ниже), поэтому
/// готовый `Listenable` — довод, а не что-то, что функция могла бы завести
/// сама; `null` (умолчание, каким пользуются все тесты этого файла) просто
/// не даёт редиректу основания перечитаться без навигации — тем же
/// поведением, каким жила эта таблица до задачи 5.
GoRouter createSetupRouter({Listenable? refresh}) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    // Последняя черта: сторож выше сверяет то, что сумел прочесть в исходниках,
    // а `errorBuilder` отвечает за всё остальное — переход, собранный из строки,
    // адрес, набранный руками, ссылка из закладки. Умолчание go_router на этом
    // месте — страница «Page Not Found» с текстом исключения, и именно её
    // увидел заказчик.
    errorBuilder: (context, state) =>
        WtNotPortedScreen(location: state.uri.toString()),
    // Сторож входа — по образцу десктопного `routerProvider`
    // (`lib/app/router/app_router.dart`). До финального разбора задачи 12 его
    // не было вовсе: эта таблица завела `/terminal-home` и `/hardware-settings`,
    // а `HardwareSettingsScreen` собственной проверки права не содержит —
    // `https://касса:9443/#/hardware-settings` открывал настройки оборудования
    // без входа, без сеанса и без права `settings.hardware`.
    //
    // Проверка права — через `PermissionKeys.routeToPermissionKey()`, ту же
    // функцию, что использует десктопный `routerProvider`, а не собственный
    // `if` на единственный маршрут. До правки «второй порядок» закрытия
    // долга безопасности (2026-08-22, пункт 6) здесь стояла именно такая
    // ручная проверка на `/hardware-settings` — правкой «маршрут → ключ»
    // (`task-17-report.md`, «Что решил про браузерную таблицу», пункт 3) она
    // была названа терпимой ровно потому, что маршрут был один: «если
    // браузерная таблица дорастёт до нескольких защищённых маршрутов, стоит
    // свести оба места к одной функции, а не разрастить собственный
    // if-каскад». `/sessions` (пункт 6) — тот самый второй маршрут, и
    // предсказанный момент настал.
    //
    // `ProviderScope.containerOf(context)`, а не захваченный `ref`: эта функция
    // строит `GoRouter` до того, как есть дерево виджетов и, значит, до того,
    // как есть `ProviderContainer` — `createSetupRouter()` зовётся из
    // `main_web.dart` напрямую, а не изнутри `Provider((ref) => ...)`, как
    // устроен десктопный `routerProvider`. `context`, который `redirect`
    // получает от go_router, — это контекст самого `Router`, уже вложенного в
    // `UncontrolledProviderScope` (`main_web.dart`: `runApp(UncontrolledProviderScope(
    // container: container, child: WtBootGate(link: link, terminal:
    // TelePosApp(router: router))))`, тот же `container`, которым выше заведён
    // `SetupRouterRefresh`), так что контейнер всегда находится. Найдено
    // ревью волны правок фазы 2, пункт 8: комментарий называл `ProviderScope`
    // и разошёлся с кодом в том же коммите, который завёл
    // `UncontrolledProviderScope` (`2fff6d3`).
    redirect: (context, state) {
      final appState = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appStateProvider);
      final currentPath = state.uri.path;

      if (AppRoutes.publicRoutes.contains(currentPath)) {
        return null;
      }

      if (!appState.isLoggedIn) {
        return AppRoutes.login;
      }

      // Оба маршрута этой таблицы, до которых у вошедшего может не быть
      // права — `/hardware-settings` (`settings.hardware`) и `/sessions`
      // (`settings.users`, задача «второй порядок», пункт 6) — идут через
      // одну и ту же функцию, которой уже пользуется десктопный
      // `routerProvider`: `TerminalHomeScreen` не строит плитку без права
      // (показом), здесь же граница держится и на случай прямого перехода
      // по адресу.
      final permissionKey = PermissionKeys.routeToPermissionKey(currentPath);
      if (permissionKey != null && !appState.hasPermission(permissionKey)) {
        return AppRoutes.terminalHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.initialSetup,
        builder: (context, state) => const InitialSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.restoreOrNew,
        builder: (context, state) => const RestoreOrNewScreen(),
      ),
      // Куда мастер уходит, закончившись, и куда заставка отправляет
      // настроенную кассу. `LoginNotifier` больше не читает базу сам — он
      // спрашивает `AuthRepository` (задача 10 плана
      // `2026-08-20-browser-terminal-login.md`), и в браузере эта роль у
      // `WtAuthRepository`, которая зовёт кассу по проводу. Экран один и тот
      // же на кассе и здесь.
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // Куда вход ведёт там, где базы нет: `getPostLoginRoute()` в
      // `login_controller.dart` спрашивает `HostCapabilities.ownsData`, а не
      // облик хоста, и `/shift` с экраном продажи сюда не годятся — оба тянут
      // `AppDatabase`. См. `terminal_home_screen.dart`.
      GoRoute(
        path: AppRoutes.terminalHome,
        builder: (context, state) => const TerminalHomeScreen(),
      ),
      // Настройки оборудования терминала — единственная плитка, которую дом
      // терминала показывает вошедшему с правом `settings.hardware`. Контракты
      // экрана (`DeviceDiscovery`, `DeviceCheck`, `DeviceBindingRepository`,
      // `TerminalRepository`) уже привязаны к проводу в `lib/web/main_web.dart`
      // планом 2b; `ScannerRulesRepository` экран запрашивает условно
      // (`GetIt.I.isRegistered`) ровно потому, что этот биндинг его не
      // регистрирует.
      GoRoute(
        path: AppRoutes.hardwareSettings,
        builder: (context, state) => const HardwareSettingsScreen(),
      ),
      // Список живых сеансов и их отзыв — задача «второй порядок» закрытия
      // долга безопасности (2026-08-22), пункт 6: `TillOps.authSessions`/
      // `authSessionRevoke` заведены задачей 19 с готовым обработчиком на
      // кассе, но без единого вызывающего в `lib/` — живая проверка нашла,
      // что отозвать сеанс из браузера было нечем, приходилось обращаться к
      // проводу напрямую (`test/manual/wt_lock_probe.dart`). Экран тот же
      // (`SessionsScreen`), что и на кассе; контракт (`SessionAdmin`) привязан
      // к проводу в `lib/web/main_web.dart` (`WtSessionAdminRepository`). У
      // этой таблицы нет хаба настроек — маршрут достижим напрямую с дома
      // терминала, тем же приёмом, что и `/hardware-settings`.
      GoRoute(
        path: AppRoutes.sessions,
        builder: (context, state) => const SessionsScreen(),
      ),
      // Кнопка Wi-Fi в шапке мастера. Задача «сетевые настройки по проводу»
      // (спека 2026-08-24) — последний экран, отдававший в браузере
      // заглушку: `network_settings_screen.dart` больше не говорит с
      // `SysdClient` напрямую, контракт (`NetworkRepository`) привязан к
      // проводу в `lib/web/main_web.dart` (`WtNetworkRepository`). Bluetooth
      // и точка доступа этой работой не переносятся — экран называет это
      // сам (докстринг `NetworkRepository`).
      GoRoute(
        path: AppRoutes.networkSettings,
        builder: (context, state) => const NetworkSettingsScreen(),
      ),
    ],
  );
}

/// Мост между Riverpod и `GoRouter.refreshListenable`.
///
/// `GoRouter` слушает обычный `Listenable`, а не провайдер напрямую. Тот же
/// приём, каким уже устроен десктопный `routerProvider` (`_AuthNotifier`,
/// `lib/app/router/app_router.dart`) — там его можно завести Riverpod-
/// провайдером с готовым `ref`; здесь `createSetupRouter()` зовётся раньше,
/// чем существует `ProviderContainer` (см. докстринг у `redirect` внутри
/// функции), и слушатель заводится снаружи, уже с готовым контейнером —
/// `lib/web/main_web.dart` строит его явно (`ProviderContainer` +
/// `UncontrolledProviderScope`) ровно затем, чтобы этому классу было к чему
/// подключиться до первого кадра.
class SetupRouterRefresh extends ChangeNotifier {
  SetupRouterRefresh(ProviderContainer container) {
    _subscription = container.listen<bool>(
      appStateProvider.select((state) => state.isLoggedIn),
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<bool> _subscription;

  /// Не звана никем — найдено ревью волны правок фазы 2, пункт 8.
  /// `lib/web/main_web.dart` строит ровно один экземпляр этого класса на
  /// весь подъём вкладки, отдаёт его `createSetupRouter(refresh: ...)` и
  /// больше не держит ссылки — `GoRouter` не берёт на себя владение
  /// переданным `refreshListenable` (это забота вызывающего, по контракту
  /// самого go_router), а у корневого маршрутизатора браузерной вкладки нет
  /// момента управляемого выключения: вкладка закрывается вместе со всем
  /// процессом, а не через явный `dispose()` дерева виджетов. Шов
  /// оставлен закрытым намеренно, а не забыт: `dispose()` живёт здесь как
  /// корректная реализация `ChangeNotifier`, но её некому звать на
  /// единственном месте, где этот класс вообще заводится.
  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
