/// **Мастер настройки обязан заканчиваться экраном, а не исключением.**
///
/// 2026-08-06 заказчик прошёл настройку в браузере до конца и получил «Page Not
/// Found: `GoException: no routes for location: /login`». Настроить кассу
/// терминал умел; показать после этого хоть что-нибудь — нет.
///
/// Сторож `test/architecture/browser_routes_test.dart` читает исходники и не
/// даёт списку переходов разойтись с таблицей маршрутов. Здесь проверяется то,
/// чего чтение исходников доказать не может: **настоящая** `createSetupRouter`
/// на настоящем переходе приводит к названному экрану. Разница не
/// схоластическая — маршрут можно объявить и построить в нём то, что упадёт
/// при отрисовке, и текстовая проверка этого не заметит.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/router/setup_router.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/network_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/sessions_screen.dart';
import 'package:telepos/presentation/screens/terminal/terminal_home_screen.dart';
import 'package:telepos/web/wt_not_ported_screen.dart';

import '../presentation/auth/support/fakes.dart';

/// Касса, которая поднялась. Ровно то состояние, в котором заставка уходит на
/// `/login`, — то есть тот самый путь, на котором заказчик получил исключение.
class _BootedTill implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async {
    onProgress(1.0, 'готово');
    return AppInitStatus.success;
  }
}

/// Настроенная установка: мастер проходить не надо, надо входить.
class _AlreadyConfigured implements FirstLaunchRepository {
  @override
  Future<FirstLaunchResult> determineResult() async =>
      FirstLaunchResult.alreadyConfigured;

  @override
  Future<List<FoundBackup>> findAvailableBackups() async => const [];

  @override
  Future<bool> restoreFromBackup(
    FoundBackup backup, {
    BootProgress? onProgress,
  }) async => false;

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) async => false;

  @override
  Future<String> startNewPos() async => '';
}

/// Живая подписка на состояние установки, которая ничем не кончается — как
/// настоящая.
class _TillState implements StartupStateRepository {
  @override
  Stream<SetupState> watch() {
    // Поток не закрывается сам — как настоящий: `watchTables` на кассе и
    // `WtDispatcher.watch` в браузере живут, пока их слушают. Держится это
    // контроллером, а не отложенным будущим: таймер в `testWidgets` идёт по
    // поддельным часам и остаётся висеть после разбора дерева, что сам
    // `flutter_test` считает дефектом теста.
    late final StreamController<SetupState> out;
    out = StreamController<SetupState>(
      onListen: () => out.add(
        const SetupState(
          configured: true,
          hasUsers: true,
          companyName: 'ТОО Ромашка',
          cashBoxName: 'Касса-1',
        ),
      ),
    );
    return out.stream;
  }
}

/// Кассир, которого касса покажет на экране входа. С задачи 12 на `/login`
/// стоит настоящий `LoginScreen`, а он спрашивает `AuthRepository`,
/// `TerminalIdentity` и `TerminalRepository` через `GetIt` (`login_controller.dart`)
/// — без этих трёх регистраций `initialize()` упал бы прямо в микрозадаче, и
/// ни один из тестов ниже не добрался бы даже до заставки.
Widget _terminal(SharedPreferences prefs, GoRouter router) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: router,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  ),
);

/// Тот же экран, но контейнер заведён явно и вставлен `UncontrolledProviderScope`
/// — ровно то, чем устроен `lib/web/main_web.dart`. Нужен только группе
/// «сторож без нажатия» ниже: там `redirect` обязан перечитаться сам, когда
/// `isLoggedIn` меняется без единой навигации, а для этого `SetupRouterRefresh`
/// должен слушать тот же контейнер, что и дерево виджетов, — `_terminal` выше
/// заводит контейнер только внутри `ProviderScope`, и достать его для
/// `createSetupRouter(refresh: ...)` раньше первого кадра нечем.
Widget _terminalWithContainer(
  SharedPreferences prefs,
  ProviderContainer container,
  GoRouter router,
) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: router,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  ),
);

/// Подставной `SessionAdmin` для проверки маршрута `/sessions` — этому
/// тесту важно, что сторож пускает вошедшего с правом на сам экран, а не что
/// экран рисует список сеансов (у него свой файл,
/// `wt_session_admin_repository_test.dart`).
class _EmptySessionAdmin implements SessionAdmin {
  @override
  Stream<List<LiveSession>> watchLiveSessions() => Stream.value(const []);

  @override
  Future<bool> revokeSession(int terminalId) async => false;
}

/// Касса с сетью — задача «сетевые настройки по проводу» (спека 2026-08-24).
/// Отдаёт настоящее значение, а не пустоту: тест ниже проверяет, что экран
/// действительно показал то, что пришло по проводу, а не просто не упал.
class _FakeNetworkRepository implements NetworkRepository {
  @override
  bool get bluetoothAvailable => true;

  @override
  Future<NetworkStatus> status() async => const NetworkStatus(
    wifiConnected: true,
    wifiSsid: 'Касса-Wi-Fi',
    wifiSignal: 90,
    ethernetConnected: false,
    ethernetInterface: null,
    internet: true,
  );

  @override
  Future<List<WifiNetwork>> wifiScan() async => const [];

  @override
  Future<({bool success, String message})> wifiConnect(
    String ssid, [
    String? password,
  ]) async => (success: true, message: '');

  @override
  Future<bool> wifiDisconnect() async => true;

  @override
  Future<Map<String, dynamic>> ethernetStatus() async => const {};

  @override
  Future<({bool success, String mode})> ethernetConfigureDhcp(String iface) async =>
      (success: true, mode: 'dhcp');

  @override
  Future<({bool success, String mode})> ethernetConfigureStatic(
    String iface, {
    required String ipCidr,
    String? gateway,
    String? dns,
  }) async => (success: true, mode: 'static');

  @override
  Future<List<({String address, String name})>> bluetoothScan() async =>
      const [];

  @override
  Future<({bool success, String message})> bluetoothPair(String address) async =>
      (success: false, message: '');
}

/// Заставка ждёт 300 мс своей задержки, потом решает маршрут; `pumpAndSettle`
/// до неё не сходится — на экране крутится индикатор.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    GetIt.I
      ..registerSingleton<AppBootstrap>(_BootedTill())
      ..registerSingleton<FirstLaunchRepository>(_AlreadyConfigured())
      ..registerSingleton<StartupStateRepository>(_TillState())
      ..registerSingleton<AuthRepository>(FakeAuthRepository())
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
      ..registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          self: () async => const Terminal(
            id: 1,
            name: 'Касса-1',
            pointMode: PointMode.cashier,
          ),
        ),
      )
      // Задача «сетевые настройки по проводу» (спека 2026-08-24):
      // `NetworkSettingsScreen` теперь настоящий экран и в браузере, а его
      // контроллер резолвит `NetworkRepository` через `GetIt`
      // (`network_controller.dart`) — без регистрации экран упал бы в
      // микрозадаче, тем же приёмом, каким `LoginScreen` не построится без
      // `AuthRepository`/`TerminalIdentity`/`TerminalRepository` выше.
      ..registerSingleton<NetworkRepository>(_FakeNetworkRepository())
      // Пункт 11 ревизии 2026-09-19: правила сканера с планшета задаются, и
      // `HardwareSettingsScreen` резолвит писателя **прямо**, а не через
      // `isRegistered`. Отсутствие привязки стало ошибкой сборки — ровно
      // то, чего сторож `presentation_is_registered_test` и добивался; эта
      // фальшивка и есть цена такого решения в пробах.
      ..registerSingleton<ScannerRulesRepository>(_FakeScannerRules());
  });

  tearDown(() async => GetIt.I.reset());

  testWidgets('настроенная касса приводит терминал к экрану входа', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_terminal(prefs, createSetupRouter()));
    await _settle(tester);

    expect(
      find.byType(LoginScreen),
      findsOneWidget,
      reason:
          'заставка уходит на /login — в браузере там обязан быть настоящий '
          'вход, а не GoException и не заглушка',
    );
    // Не только «экран есть», но и «он живой»: кассир, заведённый на кассе
    // (`_FakeAuth.watchUsers()`), обязан появиться на экране без перезахода —
    // если бы `LoginScreen` держал в браузере старый путь через
    // `AppDatabase`, эта строка не нашла бы ничего.
    expect(find.text('Айгуль'), findsOneWidget);
  });

  testWidgets(
    'кнопка Wi-Fi мастера ведёт на настоящий экран сетевых настроек',
    (tester) async {
      // Задача «сетевые настройки по проводу» (спека 2026-08-24):
      // `/network-settings` больше не отдаёт заглушку — это последний
      // экран, у которого она оставалась (докстринг `setup_router.dart`).
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);

      // Переход тот же, что делает `_NetworkButton` на каждом шаге мастера.
      // `/network-settings` — публичный маршрут (`AppRoutes.publicRoutes`), и
      // сторож входа не должен его тронуть даже без входа.
      router.push(AppRoutes.networkSettings);
      await _settle(tester);

      expect(
        find.byType(WtNotPortedScreen),
        findsNothing,
        reason: 'заглушки здесь больше нет — контракт привязан к проводу',
      );
      expect(find.byType(NetworkSettingsScreen), findsOneWidget);
      // Не только «экран есть», но и «он живой»: состояние сети, которое
      // отдала подставная `NetworkRepository` (`_FakeNetworkRepository`),
      // обязано дойти до отрисовки через настоящий контроллер
      // (`network_controller.dart`) — если бы экран в браузере всё ещё
      // держал старый путь через `SysdClient`, эта строка не нашла бы
      // ничего (тот же приём, что и у «настроенная касса приводит терминал
      // к экрану входа» выше — Айгуль в списке кассиров).
      expect(find.textContaining('Касса-Wi-Fi'), findsOneWidget);
    },
  );

  testWidgets('маршрут, которого нет вовсе, тоже даёт экран', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = createSetupRouter();
    await tester.pumpWidget(_terminal(prefs, router));
    await _settle(tester);

    // Вошедший — иначе сторож входа, заведённый финальным разбором задачи 12,
    // сам увёл бы неопознанный адрес на `/login` раньше, чем дело дошло бы до
    // `errorBuilder`, и эта проверка перестала бы проверять то, что называет.
    _logIn(tester);

    // Ровно та форма, что стоила заказчику пройденного мастера: адрес,
    // которого в таблице нет. Сторож по исходникам сюда не дотягивается —
    // строку можно собрать во время выполнения или набрать в адресной строке.
    router.go('/nothing-like-this');
    await _settle(tester);

    expect(
      find.byType(WtNotPortedScreen),
      findsOneWidget,
      reason: 'умолчание go_router здесь — страница с текстом исключения',
    );
    expect(find.textContaining('/nothing-like-this'), findsOneWidget);
  });

  testWidgets('с названного экрана есть выход', (tester) async {
    // Экран, из которого нельзя выйти, — тот же тупик, только с надписью.
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = createSetupRouter();
    await tester.pumpWidget(_terminal(prefs, router));
    await _settle(tester);

    _logIn(tester);

    router.go('/nothing-like-this');
    await _settle(tester);
    expect(find.byType(WtNotPortedScreen), findsOneWidget);

    await tester.tap(find.text('Назад'));
    await _settle(tester);

    expect(
      find.byType(LoginScreen),
      findsOneWidget,
      reason:
          'из тупика без стека единственное осмысленное место — экран входа, '
          'на который `WtNotPortedScreen` уходит через `AppRoutes.login`',
    );
  });

  group('сторож входа', () {
    testWidgets('без входа /hardware-settings уводит на /login', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);

      // Красный без `redirect:` в `createSetupRouter()`: без него
      // `HardwareSettingsScreen` строится как есть — без входа, без сеанса
      // и без права `settings.hardware`, ровно то, что нашёл разбор
      // (`https://касса:9443/#/hardware-settings`).
      router.go(AppRoutes.hardwareSettings);
      await _settle(tester);

      expect(
        find.byType(LoginScreen),
        findsOneWidget,
        reason:
            'непрошедший вход не имеет права увидеть настройки '
            'оборудования',
      );
      expect(find.byType(HardwareSettingsScreen), findsNothing);
    });

    testWidgets('вошедший без права settings.hardware тоже не проходит на '
        '/hardware-settings', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);

      // Вошедший, но без `settings.hardware` в действующих правах —
      // `_onSession` в `login_controller.dart` в проде кладёт сюда именно
      // то множество, которое прислала касса, и здесь оно нарочно пустое.
      _logIn(tester, permissions: const {});

      router.go(AppRoutes.hardwareSettings);
      await _settle(tester);

      expect(
        find.byType(HardwareSettingsScreen),
        findsNothing,
        reason: 'право есть у показа, а не у нажатия — без него экрана нет',
      );
      expect(
        find.byType(TerminalHomeScreen),
        findsOneWidget,
        reason: 'вошедшего без права возвращает на дом терминала',
      );
    });

    // Пункт 6 закрытия долга безопасности, правка «второй порядок»: второй
    // защищённый маршрут этой таблицы — тот самый случай, ради которого
    // ручной `if` на `/hardware-settings` был сведён к
    // `PermissionKeys.routeToPermissionKey()` (см. докстринг `redirect` в
    // `setup_router.dart`).
    testWidgets('без входа /sessions уводит на /login', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);

      router.go(AppRoutes.sessions);
      await _settle(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SessionsScreen), findsNothing);
    });

    testWidgets(
      'вошедший без права settings.users не проходит на /sessions',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final router = createSetupRouter();
        await tester.pumpWidget(_terminal(prefs, router));
        await _settle(tester);

        _logIn(tester, permissions: const {});

        router.go(AppRoutes.sessions);
        await _settle(tester);

        expect(find.byType(SessionsScreen), findsNothing);
        expect(find.byType(TerminalHomeScreen), findsOneWidget);
      },
    );

    testWidgets('вошедший с settings.users проходит на /sessions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      GetIt.I.registerSingleton<SessionAdmin>(_EmptySessionAdmin());

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);

      _logIn(tester, permissions: {PermissionKeys.settingsUsers});

      router.go(AppRoutes.sessions);
      await _settle(tester);

      expect(find.byType(SessionsScreen), findsOneWidget);
    });
  });

  group('вкладка уходит на вход сама (задача 5)', () {
    testWidgets(
      'выход из appState без единого router.go() всё равно приводит к '
      '/login',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Не `addTearDown(container.dispose)`: `AppStateNotifier.build`
        // заводит периодические `Timer` (часы, свободное место), и проверка
        // связности `flutter_test` («A Timer is still pending») смотрит
        // раньше, чем добегают `addTearDown`-колбэки, — контейнер, которым
        // владеет этот тест, а не дерево виджетов, обязан быть закрыт здесь
        // же, до конца функции.
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );

        // `SetupRouterRefresh(container)` — тот же довод, каким
        // `lib/web/main_web.dart` заводит `createSetupRouter` в проде.
        // Красный без него: `GoRouter` не перечитывает `redirect` сам по
        // себе, когда `isLoggedIn` меняется без навигации — состояние
        // `appStateProvider` уже говорит «вышел», но виджет остаётся тем же.
        final router = createSetupRouter(
          refresh: SetupRouterRefresh(container),
        );
        await tester.pumpWidget(
          _terminalWithContainer(prefs, container, router),
        );
        await _settle(tester);

        container
            .read(appStateProvider.notifier)
            .setUserInfo(
              id: 7,
              name: 'Айгуль',
              role: 0,
              permissions: const {'settings.hardware'},
            );
        await _settle(tester);
        router.go(AppRoutes.hardwareSettings);
        await _settle(tester);
        expect(
          find.byType(HardwareSettingsScreen),
          findsOneWidget,
          reason: 'предпосылка теста — вошедший на самом деле дошёл дотуда',
        );

        // Отзыв сеанса — ровно то, что делает `LoginNotifier._endSession`
        // (задача 5) на живой подписке `watchSession`, но здесь без
        // единого вызова `router.go`/`push`/`replace`: то самое отличие,
        // которое и проверяет тест.
        container.read(appStateProvider.notifier).logout();
        await _settle(tester);

        expect(
          find.byType(LoginScreen),
          findsOneWidget,
          reason:
              'касса, отозвавшая сеанс, обязана выкинуть вкладку сама — без '
              'нажатия и без навигации',
        );
        expect(find.byType(HardwareSettingsScreen), findsNothing);

        container.dispose();
      },
    );
  });
}

/// Кладёт `AppState`, как это делает `LoginNotifier._onSession` на настоящем
/// сеансе — прямиком через контейнер того же дерева, без набора PIN на
/// экране: эти тесты проверяют сторож входа, а не сам вход.
void _logIn(WidgetTester tester, {Set<String> permissions = const {}}) {
  final context = tester.element(find.byType(LoginScreen));
  ProviderScope.containerOf(context, listen: false)
      .read(appStateProvider.notifier)
      .setUserInfo(id: 7, name: 'Айгуль', role: 0, permissions: permissions);
}

/// Правила сканера в памяти — экран настроек резолвит писателя прямо
/// (пункт 11 ревизии 2026-09-19), и без привязки он не построится.
class _FakeScannerRules implements ScannerRulesRepository {
  ScannerRules? _saved;

  @override
  Future<ScannerRules> read() async => _saved ?? ScannerRules.unset;

  @override
  Future<void> save(ScannerRules rules) async => _saved = rules;
}
