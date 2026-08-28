/// Живая проверка «замка кассы» — задача 22 закрытия долга безопасности.
///
/// # Что здесь, в отличие от `wt_auth_probe.dart` (задача 8)
///
/// Задача 8 доказывала одну вещь прямым вызовом провода, без единого экрана.
/// Здесь проверяются пять пунктов брифа, три из которых — не про провод, а
/// про то, что **экран** (`LoginScreen`, `setup_router.dart`, `AppState`)
/// делает с ответом провода: называет ли причину, уводит ли вкладку сама,
/// пускает ли прямой переход. Провод можно проверить щупом; то, что с его
/// ответом делает `context.go`/`ref.listen`, — только настоящим деревом
/// виджетов, которое эти вызовы совершает само.
///
/// Поэтому этот файл — не отдельная `MaterialApp` с одним `SelectableText`,
/// как `wt_auth_probe.dart`, а **тот же `main_web.dart`**: та же сборка
/// `GetIt`, тот же `createSetupRouter()`, тот же `TelePosApp`. Экраны
/// рисуются по-настоящему — `Page.captureScreenshot` показывает то, что
/// увидел бы человек, а не текстовый лог.
///
/// Вход и переход по прямому адресу здесь не пиксельный клик (реальный
/// человек в headless Chrome недостижим — `docs/internal/testing-notes.md`, раздел
/// «Авторизация операций провода»), а вызов того же метода, который клик
/// вызывает: `LoginNotifier.addDigit`/`attemptLogin`, `GoRouter.go`. Экран
/// реагирует на смену состояния сам — `ref.listen` в `LoginScreen`,
/// `redirect` в `setup_router.dart`, `SetupRouterRefresh` — той же цепочкой,
/// какой он реагировал бы на настоящий клик. Непройденное этим — сам жест
/// (найти кнопку на канвасе и попасть по ней курсором) — не проверено, и
/// это названо в отчёте, а не спрятано.
///
/// # Роли и сценарии
///
/// Выбираются строкой запроса при открытии страницы:
/// `?scenario=route-guard`, `?scenario=terminal-mismatch&code=..&code2=..`
/// (задача 6 плана «знакомство терминала с кассой»: оба кода мятятся на
/// реальной кассе через `/terminal-pairing`, каждый — одноразовый),
/// `?scenario=idle-watch`, `?scenario=idle-trigger`,
/// `?scenario=revoke-watch`, `?scenario=revoke-actor&terminalId=N`.
///
/// `idle-*` и `revoke-*` — по два сценария каждый, потому что каждый из этих
/// двух пунктов брифа требует **двух вкладок**: одна логинится и смотрит,
/// другая (внешним таймингом драйвера сессии, не частью репозитория —
/// см. `wt_auth_probe.dart` про то же самое ограничение) вызывает то, что
/// должно столкнуть первую. `route-guard` и `terminal-mismatch` — один
/// сценарий на вкладку, координации не требуют.
///
/// Результат — тем же путём, что и в задаче 8: `window.TELEPOS_PROBE_LOG`
/// (текст) и `window.TELEPOS_PROBE_DONE` (готовность), опрашиваемые снаружи
/// по CDP.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/config/build_config.dart';
import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/router/setup_router.dart';
import 'package:telepos/app/telepos_app.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/data/terminal/terminal_identity_local.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/controllers/settings/sessions_controller.dart';
import 'package:telepos/presentation/screens/auth/widgets/user_selector.dart';

import 'package:telepos/web/wt_app_bootstrap.dart';
import 'package:telepos/web/wt_auth_repository.dart';
import 'package:telepos/web/wt_boot_gate.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_device_binding_repository.dart';
import 'package:telepos/web/wt_device_check.dart';
import 'package:telepos/web/wt_device_discovery.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_first_launch_repository.dart';
import 'package:telepos/web/wt_session.dart';
import 'package:telepos/web/wt_session_admin_repository.dart';
import 'package:telepos/web/wt_session_token_store.dart';
import 'package:telepos/web/wt_setup_repository.dart';
import 'package:telepos/web/wt_startup_state_repository.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

/// Заводится `curl .../stand/seed-cashiers` (`test/manual/wt_stand.dart`).
/// Права по умолчанию — без строк в `UserPermissions`, значит все, включая
/// `settings.hardware` и `settings.users`.
const _withPinName = 'Кассир С PIN';
const _withPinPin = '1234';

/// Тоже `stand/seed-cashiers` — вход без набора цифр, права те же (полные).
const _noPinName = 'Кассир Без PIN';

/// `curl .../stand/seed-restricted-cashier` — `settings.hardware` отнято
/// явной строкой, остальное разрешено.
const _restrictedName = 'Кассир Без Права На Оборудование';
const _restrictedPin = '9999';

/// Перепроверка «второго порядка» закрытия долга безопасности (2026-08-22),
/// пункт про `/sessions`: `curl .../stand/seed-no-users-cashier` —
/// `settings.users` отнято явной строкой, остальное разрешено. Отдельный
/// кассир, а не `_restrictedName`: тот лишён `settings.hardware`, а маршрут
/// `/sessions` заведён под `settings.users` (`permission_keys.dart:336`) —
/// проверка не тем правом доказала бы не то же самое.
const _noUsersName = 'Кассир Без Права На Сеансы';
const _noUsersPin = '5555';

@JS('TELEPOS_PROBE_LOG')
external set _probeLogJS(JSString value);

@JS('TELEPOS_PROBE_DONE')
external set _probeDoneJS(JSBoolean value);

final _log = <String>[];

void _say(String line) {
  _log.add(line);
  // ignore: avoid_print
  print('[замок] $line');
  _probeLogJS = _log.join('\n').toJS;
}

void main() {
  runZonedGuarded(_run, (error, stack) {
    // ignore: avoid_print
    print('[TelePOS] uncaught: $error\n$stack');
  });
}

late ProviderContainer _container;

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    // ignore: avoid_print
    print('[TelePOS] flutter: ${details.exceptionAsString()}\n${details.stack}');
  };

  installLogger(Talker());

  final prefs = await SharedPreferences.getInstance();

  // Дословно та же сборка, что `lib/web/main_web.dart` — иначе проверялся бы
  // не тот код, который уедет заказчику.
  final link = WtLink(WtSession.openFromDocument);
  final tokenStore = SessionTokenStore();
  final wire = WtDispatcher(link, tokens: tokenStore);

  GetIt.I
    ..registerLazySingleton<StartupStateRepository>(
      () => WtStartupStateRepository(wire),
    )
    ..registerLazySingleton<AppBootstrap>(() => WtAppBootstrap(wire))
    ..registerLazySingleton<FirstLaunchRepository>(
      () => WtFirstLaunchRepository(wire),
    )
    ..registerLazySingleton<SetupRepository>(() => WtSetupRepository(wire))
    ..registerLazySingleton<TerminalRepository>(
      () => WtTerminalRepository(wire),
    )
    ..registerLazySingleton<DeviceProfileCatalog>(
      () => BuiltinDeviceProfileCatalog(),
    )
    ..registerLazySingleton<DeviceBindingRepository>(
      () => WtDeviceBindingRepository(wire),
    )
    ..registerLazySingleton<DeviceDiscovery>(
      () => WtDeviceDiscovery(wire, GetIt.I<DeviceProfileCatalog>()),
    )
    ..registerLazySingleton<DeviceCheck>(() => WtDeviceCheck(wire))
    ..registerLazySingleton<AuthRepository>(() => WtAuthRepository(wire))
    // Перепроверка «второго порядка» (2026-08-22): без этого биндинга
    // `SessionsController` (`GetIt.I<SessionAdmin>()`) бросает на `/sessions`
    // — тот же биндинг, что `main_web.dart` завёл коммитом `a9cb0a3`, здесь
    // повторён для щупа отдельно, потому что щуп не читает `main_web.dart`,
    // а собирает тот же граф своими строками.
    ..registerLazySingleton<SessionAdmin>(
      () => WtSessionAdminRepository(wire),
    )
    ..registerSingleton<SessionTokenStorage>(tokenStore)
    ..registerLazySingleton<TerminalIdentity>(
      () => PrefsTerminalIdentity(prefs),
    )
    ..registerSingleton<LocalProperties>(await LocalProperties.create())
    ..registerSingleton<BuildConfig>(BuildConfig.fromEnvironment())
    ..registerSingleton<HostCapabilities>(HostCapabilities.browser)
    ..registerSingleton<WtLink>(link)
    ..registerSingleton<WtDispatcher>(wire);

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  _container = container;
  final router = createSetupRouter(refresh: SetupRouterRefresh(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: WtBootGate(
        link: link,
        terminal: TelePosApp(router: router),
      ),
    ),
  );

  // Дать `WtBootGate` поднять сессию (рукопожатие QUIC — доли секунды, но не
  // ноль) прежде чем сценарий начнёт спрашивать провод через тот же `wire`.
  await Future.delayed(const Duration(seconds: 2));

  final params = Uri.base.queryParameters;
  final scenario = params['scenario'] ?? 'route-guard';

  try {
    switch (scenario) {
      case 'route-guard':
        await _scenarioRouteGuard(router);
      case 'terminal-mismatch':
        // Задача 6 плана «знакомство терминала с кассой»: `terminals
        // .register` требует код привязки — мятите на реальной кассе через
        // `/terminal-pairing` ДВА кода (свой код — одноразовый) и передайте
        // их строкой запроса: `?scenario=terminal-mismatch&code=...
        // &code2=...`. Без них сценарий откажет по коду
        // `pairing_code_invalid` на первом же `register()` и назовёт это
        // прямо, а не зависнет.
        await _scenarioTerminalMismatch(
          wire,
          code: params['code'] ?? '',
          code2: params['code2'] ?? '',
        );
      case 'idle-watch':
        await _scenarioIdleWatch(router);
      case 'idle-trigger':
        await _scenarioIdleTrigger();
      case 'revoke-watch':
        await _scenarioRevokeWatch(router);
      case 'revoke-actor':
        await _scenarioRevokeActor(wire, int.parse(params['terminalId']!));
      // Перепроверка «второго порядка» (2026-08-22, коммит `a9cb0a3`):
      // тот же отзыв, что и `revoke-actor`, но через настоящий экран
      // `/sessions`, а не прямым вызовом провода — см. докстринги
      // сценариев ниже.
      case 'sessions-screen-actor':
        await _scenarioSessionsScreenActor(
          router,
          int.parse(params['terminalId']!),
        );
      case 'sessions-guard':
        await _scenarioSessionsGuard(router);
      default:
        _say('сценарий не опознан: $scenario');
    }
    _say('ГОТОВО');
  } on Object catch (error, stack) {
    _say('ПРОБА УПАЛА: $error');
    _say('$stack');
  } finally {
    _probeDoneJS = true.toJS;
  }
}

// --- Общее: вход тем же методом, каким его зовёт кнопка LoginScreen -------

Future<void> _loginAs(String userName, {String? pin}) async {
  final notifier = _container.read(loginControllerProvider.notifier);
  // НЕ зовёт `notifier.initialize()` сама: настоящий `LoginScreen.initState()`
  // уже зовёт его при монтировании (`login_screen.dart:32`) — это и есть
  // путь, каким список кассиров приезжает подпиской в проде. Второй, свой
  // вызов здесь состязался бы с этим первым: `initialize()` чистит
  // `enteredPin`, и гонка двух вызовов (найдена в этой же сессии — дважды
  // подряд `_withPinName`/`1234` получал то `error.wrong_pin`, то тихий
  // `error: null` без входа) вероятнее всего и была этим состязанием, а не
  // настоящим отказом провода. Щуп ждёт то же самое состояние, которое уже
  // готовит сам экран, а не заводит второе.
  UserItem? user;
  for (var i = 0; i < 100; i++) {
    final users = _container.read(loginControllerProvider).users;
    user = users.where((u) => u.name == userName).firstOrNull;
    if (user != null) break;
    await Future.delayed(const Duration(milliseconds: 100));
  }
  if (user == null) {
    throw StateError('кассир "$userName" не появился в списке (не заведён?)');
  }

  notifier.selectUser(user);
  if (pin != null) {
    for (final digit in pin.split('')) {
      notifier.addDigit(digit);
    }
  }
  notifier.attemptLogin();
  await notifier.pendingVerification;
}

// --- Пункт 3: прямой переход по адресу -------------------------------------

Future<void> _scenarioRouteGuard(GoRouter router) async {
  // Кассир БЕЗ права `settings.hardware` — прямой переход обязан увести на
  // дом терминала, а не открыть экран.
  await _loginAs(_restrictedName, pin: _restrictedPin);
  final loginState = _container.read(loginControllerProvider);
  if (!loginState.isAuthenticated) {
    throw StateError('вход "$_restrictedName" не удался: ${loginState.error}');
  }
  await Future.delayed(const Duration(milliseconds: 500)); // LoginScreen.context.go(postLoginRoute)

  router.go(AppRoutes.hardwareSettings);
  await Future.delayed(const Duration(milliseconds: 500));
  final afterDenied = router.routerDelegate.currentConfiguration.uri.path;
  _say(
    'БЕЗ ПРАВА, прямой переход на "${AppRoutes.hardwareSettings}" -> '
    'оказался на "$afterDenied" '
    '(ожидание: "${AppRoutes.terminalHome}", НЕ "${AppRoutes.hardwareSettings}")',
  );

  // Выход и повторный вход тем же кассиром, у которого право ЕСТЬ — чтобы
  // показать, что запрет не общий, а именно по праву (иначе половина
  // доказательства отсутствует).
  await _container.read(loginControllerProvider.notifier).logout();
  await Future.delayed(const Duration(milliseconds: 300));
  router.go(AppRoutes.login);
  await Future.delayed(const Duration(milliseconds: 300));

  await _loginAs(_withPinName, pin: _withPinPin);
  final loginState2 = _container.read(loginControllerProvider);
  if (!loginState2.isAuthenticated) {
    throw StateError('вход "$_withPinName" не удался: ${loginState2.error}');
  }
  await Future.delayed(const Duration(milliseconds: 500));

  router.go(AppRoutes.hardwareSettings);
  await Future.delayed(const Duration(milliseconds: 500));
  final afterAllowed = router.routerDelegate.currentConfiguration.uri.path;
  _say(
    'С ПРАВОМ, прямой переход на "${AppRoutes.hardwareSettings}" -> '
    'оказался на "$afterAllowed" (ожидание: "${AppRoutes.hardwareSettings}")',
  );
}

// --- Пункт 4: чужой terminalId в теле -------------------------------------

Future<void> _scenarioTerminalMismatch(
  WtDispatcher wire, {
  required String code,
  required String code2,
}) async {
  final terminals = GetIt.instance<TerminalRepository>();
  final auth = GetIt.instance<AuthRepository>();
  final tokenStore = GetIt.instance<SessionTokenStorage>();

  final own = (await terminals.register(name: 'Проба-Свой', code: code)).terminal;
  _say('свой терминал зарегистрирован: #${own.id}');

  final userId = (await auth.watchUsers().first)
      .where((u) => u.name == _withPinName)
      .first
      .id;
  final outcome = await auth.login(
    AuthAttempt(pin: _withPinPin, terminalId: own.id, userId: userId),
  );
  final session = switch (outcome) {
    AuthSession s => s,
    AuthRejection r => throw StateError('вход отказал: ${r.reason}'),
  };
  tokenStore.write(session.token, session.expiresAt);
  _say('сеанс выписан на terminalId=${session.terminalId} (обязан быть ${own.id})');

  // Второй терминал — эта же вкладка регистрирует его ПОСЛЕ входа: он не
  // портит уже выписанный сеанс (терминал сеанса — часть самого токена), но
  // даёт существующий, настоящий, но чужой id для тела запроса.
  final foreign = (await terminals.register(
    name: 'Проба-Чужой',
    code: code2,
  )).terminal;
  _say('чужой терминал зарегистрирован: #${foreign.id}');

  final foreignResult = await _tryDeviceCheck(wire, foreign.id);
  _say('deviceCheck(terminalId=${foreign.id}, ЧУЖОЙ):  $foreignResult');

  final ownResult = await _tryDeviceCheck(wire, own.id);
  _say('deviceCheck(terminalId=${own.id}, СВОЙ):     $ownResult');
}

Future<String> _tryDeviceCheck(WtDispatcher wire, int terminalId) async {
  try {
    final outcome = await wire.ask(TillOps.deviceCheck, (
      terminalId: terminalId,
      deviceClass: DeviceClass.cashDrawer,
    ));
    return 'ОТВЕТ ОБРАБОТЧИКА: $outcome';
  } on WtProtocolError catch (error) {
    return 'ОТКАЗ ${error.code}: ${error.detail}';
  } on Object catch (error) {
    return 'ИСКЛЮЧЕНИЕ: $error';
  }
}

// --- Пункт 1: истёкший сеанс -----------------------------------------------

Future<void> _scenarioIdleWatch(GoRouter router) async {
  await _loginAs(_withPinName, pin: _withPinPin);
  final notifier = _container.read(loginControllerProvider.notifier);
  final loginState = _container.read(loginControllerProvider);
  if (!loginState.isAuthenticated) {
    throw StateError('вход не удался: ${loginState.error}');
  }
  _say('TERMINAL_ID=${notifier.browserTerminalId}');
  _say('вход выполнен, живая подписка на сеанс заведена, жду отзыва временем...');

  final endedAt = await _waitForSessionEnd(timeout: const Duration(seconds: 40));
  if (endedAt == null) {
    _say('НЕ ДОЖДАЛСЯ: сеанс всё ещё активен по истечении срока ожидания');
    return;
  }
  await Future.delayed(const Duration(milliseconds: 500));
  final path = router.routerDelegate.currentConfiguration.uri.path;
  _say(
    'сеанс кончился сам, причина="${_container.read(loginControllerProvider).sessionEndedReason}", '
    'вкладка на "$path" (ожидание: "${AppRoutes.login}", причина "error.session_expired")',
  );
}

Future<void> _scenarioIdleTrigger() async {
  // Ждать заведомо дольше, чем короткий срок бездействия, выставленный
  // внешним драйвером через `stand/set-idle-seconds` ДО того, как обе
  // вкладки открылись. Затем — вход walk-up: `SessionRegistry.mint()`
  // первой строкой зовёт `_forget()` и выметает чужую просроченную запись
  // организмически, тем же путём, каким её вымел бы любой следующий вход
  // на настоящей кассе, — не синтетической командой ради теста.
  await Future.delayed(const Duration(seconds: 8));
  await _loginAs(_noPinName);
  final state = _container.read(loginControllerProvider);
  _say('уборщик вошёл: isAuthenticated=${state.isAuthenticated} (сам это не проверяемый исход, только триггер)');
}

Future<DateTime?> _waitForSessionEnd({required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final state = _container.read(loginControllerProvider);
    if (!state.isAuthenticated && state.sessionEndedReason != null) {
      return DateTime.now();
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }
  return null;
}

// --- Пункт 2: отзыв владельцем ----------------------------------------------

Future<void> _scenarioRevokeWatch(GoRouter router) async {
  await _loginAs(_withPinName, pin: _withPinPin);
  final notifier = _container.read(loginControllerProvider.notifier);
  final loginState = _container.read(loginControllerProvider);
  if (!loginState.isAuthenticated) {
    throw StateError('вход не удался: ${loginState.error}');
  }
  _say('TERMINAL_ID=${notifier.browserTerminalId}');
  _say('вход выполнен, живая подписка заведена, жду отзыва с другой вкладки, без единого своего действия...');

  // Перепроверка «второго порядка» (2026-08-22): было 30 секунд — хватало,
  // пока вкладка-владелец звала `auth.sessionRevoke` прямым вызовом провода
  // (`_scenarioRevokeActor`). Теперь тот же сценарий ждёт и отзыва через
  // настоящий экран `/sessions` (`_scenarioSessionsScreenActor`), а тот
  // сам логинится, открывает маршрут и ждёт первого значения списка —
  // секунды, не миллисекунды. 30 с однажды не хватило впритык (найдено
  // этой сессией живьём); 60 с — запас, а не гонка с самим собой.
  final endedAt = await _waitForSessionEnd(timeout: const Duration(seconds: 60));
  if (endedAt == null) {
    _say('НЕ ДОЖДАЛСЯ: отзыв с другой вкладки не дошёл за отведённое время');
    return;
  }
  await Future.delayed(const Duration(milliseconds: 500));
  final path = router.routerDelegate.currentConfiguration.uri.path;
  _say(
    'сеанс кончился сам, причина="${_container.read(loginControllerProvider).sessionEndedReason}", '
    'вкладка на "$path" (ожидание: "${AppRoutes.login}", причина "error.session_ended" — '
    'отзыв, а не истечение)',
  );
}

Future<void> _scenarioRevokeActor(WtDispatcher wire, int targetTerminalId) async {
  // Владелец — тот же посевной кассир (`_noPinName`), у него, как и у
  // `_withPinName`, полный набор прав (`stand/seed-cashiers`), включая
  // `settings.users`, которого требует `auth.sessionRevoke`.
  //
  // Прямой вызов провода, а не экран: `SessionsController`
  // (`lib/presentation/controllers/settings/sessions_controller.dart`)
  // читает `SessionRegistry` через `GetIt` напрямую и достижим только из
  // ДЕСКТОПНОЙ таблицы маршрутов (`app_router.dart`) — `setup_router.dart`
  // не несёт `/sessions` вовсе. Операция провода (`auth.sessionRevoke`)
  // существует и работает; экрана в браузере для неё сегодня нет. Это
  // находка, а не обход теста — названа в отчёте отдельно.
  await _loginAs(_noPinName);
  final loginState = _container.read(loginControllerProvider);
  if (!loginState.isAuthenticated) {
    throw StateError('вход владельца не удался: ${loginState.error}');
  }
  _say('владелец вошёл, отзываю terminalId=$targetTerminalId');

  final result = await wire.ask(TillOps.authSessionRevoke, targetTerminalId);
  _say('auth.sessionRevoke(terminalId=$targetTerminalId) -> $result');
}

// --- Перепроверка «второго порядка» (2026-08-22): экран /sessions --------

/// Отзыв через настоящий экран `/sessions`
/// (`lib/presentation/screens/settings/sessions_screen.dart`), а не прямым
/// вызовом провода, как в `_scenarioRevokeActor`. Владелец открывает
/// экран, видит цель в живом списке (`SessionsController.load()`,
/// подписка на `watchLiveSessions()`), затем зовётся
/// `SessionsController.revoke()` — ровно тот метод, который
/// `SessionsScreen._confirmRevoke` зовёт после «да» в диалоге
/// подтверждения. Пиксельного клика по кнопке и по диалогу здесь нет — та
/// же причина, что и во всём остальном щупе (см. докстринг файла): жест
/// курсором не проверен, вызванный метод — тот же самый.
Future<void> _scenarioSessionsScreenActor(
  GoRouter router,
  int targetTerminalId,
) async {
  // `_noPinName`, не `_withPinName`: цель этого сценария (`revoke-watch`,
  // общий с истечением по времени) уже занял `_withPinName` на своей
  // вкладке — двумя разными именами список экрана нагляднее отличить «кого
  // отзывают» от «кто отзывает», тем же приёмом, что и в `_scenarioRevokeActor`.
  await _loginAs(_noPinName);
  final loginState = _container.read(loginControllerProvider);
  if (!loginState.isAuthenticated) {
    throw StateError('вход владельца не удался: ${loginState.error}');
  }
  await Future.delayed(const Duration(milliseconds: 500));

  router.go(AppRoutes.sessions);
  await Future.delayed(const Duration(milliseconds: 800));
  final onScreen = router.routerDelegate.currentConfiguration.uri.path;
  _say('владелец на "$onScreen" (ожидание "${AppRoutes.sessions}")');
  if (onScreen != AppRoutes.sessions) {
    throw StateError('маршрут /sessions не открылся владельцу с правом');
  }

  var state = _container.read(sessionsControllerProvider);
  for (var i = 0; i < 50 && state.loading; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    state = _container.read(sessionsControllerProvider);
  }
  _say(
    'список на экране: '
    '${state.sessions.map((s) => "${s.name}#${s.terminalId}").join(", ")}',
  );
  final found = state.sessions
      .where((s) => s.terminalId == targetTerminalId)
      .firstOrNull;
  _say(
    'целевой terminalId=$targetTerminalId в списке экрана: '
    '${found != null}',
  );
  if (found == null) {
    throw StateError(
      'терминал $targetTerminalId не найден в списке экрана /sessions',
    );
  }

  final notifier = _container.read(sessionsControllerProvider.notifier);
  final revoked = await notifier.revoke(targetTerminalId);
  _say('SessionsController.revoke(terminalId=$targetTerminalId) -> $revoked');

  // Экран остаётся открытым и подписанным: живой список обязан сам потерять
  // отозванную строку, без перезахода на экран — то же свойство «касса
  // говорит первой», что и у остальных экранов этого щупа.
  var after = _container.read(sessionsControllerProvider);
  for (var i = 0; i < 30; i++) {
    if (!after.sessions.any((s) => s.terminalId == targetTerminalId)) break;
    await Future.delayed(const Duration(milliseconds: 200));
    after = _container.read(sessionsControllerProvider);
  }
  final stillThere = after.sessions.any(
    (s) => s.terminalId == targetTerminalId,
  );
  _say(
    'после отзыва список экрана: '
    '${after.sessions.map((s) => "${s.name}#${s.terminalId}").join(", ")} '
    '(цель ещё в списке: $stillThere, ожидание: false)',
  );
}

/// Кассир без `settings.users` (`stand/seed-no-users-cashier`) не должен
/// открыть `/sessions` прямым переходом — тот же приём, что
/// `_scenarioRouteGuard` уже применил к `/hardware-settings`, здесь для
/// второго защищённого маршрута.
Future<void> _scenarioSessionsGuard(GoRouter router) async {
  await _loginAs(_noUsersName, pin: _noUsersPin);
  final loginState = _container.read(loginControllerProvider);
  if (!loginState.isAuthenticated) {
    throw StateError('вход "$_noUsersName" не удался: ${loginState.error}');
  }
  await Future.delayed(const Duration(milliseconds: 500));

  router.go(AppRoutes.sessions);
  await Future.delayed(const Duration(milliseconds: 500));
  final afterDenied = router.routerDelegate.currentConfiguration.uri.path;
  _say(
    'БЕЗ ПРАВА settings.users, прямой переход на "${AppRoutes.sessions}" -> '
    'оказался на "$afterDenied" '
    '(ожидание: "${AppRoutes.terminalHome}", НЕ "${AppRoutes.sessions}")',
  );

  await _container.read(loginControllerProvider.notifier).logout();
  await Future.delayed(const Duration(milliseconds: 300));
  router.go(AppRoutes.login);
  await Future.delayed(const Duration(milliseconds: 300));

  await _loginAs(_withPinName, pin: _withPinPin);
  final loginState2 = _container.read(loginControllerProvider);
  if (!loginState2.isAuthenticated) {
    throw StateError('вход "$_withPinName" не удался: ${loginState2.error}');
  }
  await Future.delayed(const Duration(milliseconds: 500));

  router.go(AppRoutes.sessions);
  await Future.delayed(const Duration(milliseconds: 500));
  final afterAllowed = router.routerDelegate.currentConfiguration.uri.path;
  _say(
    'С ПРАВОМ, прямой переход на "${AppRoutes.sessions}" -> '
    'оказался на "$afterAllowed" (ожидание: "${AppRoutes.sessions}")',
  );
}
