import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/config/build_config.dart';
import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/app/router/setup_router.dart';
import 'package:telepos/app/telepos_app.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret_storage.dart';
import 'package:telepos/data/terminal/terminal_identity_local.dart';

import 'package:telepos/web/wt_boot_gate.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_session.dart';

import 'wt_app_bootstrap.dart';
import 'wt_auth_repository.dart';
import 'wt_device_binding_repository.dart';
import 'wt_device_check.dart';
import 'wt_device_discovery.dart';
import 'wt_first_launch_repository.dart';
import 'wt_network_repository.dart';
import 'wt_session_admin_repository.dart';
import 'wt_session_token_store.dart';
import 'wt_setup_repository.dart';
import 'wt_startup_state_repository.dart';
import 'wt_terminal_repository.dart';
import 'wt_terminal_secret_store.dart';

/// Browser entry point.
///
/// It owns no screens. Its whole job is to bind the domain contracts to
/// implementations that reach the backend over HTTP, then run the same
/// [TelePosApp] the desktop build runs — same screens, same design.
///
/// The route table starts at the first-launch wizard and widens as each
/// screen's contracts gain an implementation that works over the wire. A screen
/// missing here is a binding that has not been written yet, never a screen that
/// only exists natively. See docs/ARCHITECTURE.md.
Future<void> main() async {
  // Anything that escapes goes to the browser console with its message intact.
  // A compiled bundle reports uncaught errors as a bare minified stack, which
  // says nothing; the browser binding exists to be debugged, so it has to be
  // able to say what went wrong. See docs/ARCHITECTURE.md, "Debugging".
  runZonedGuarded(_run, (error, stack) {
    // ignore: avoid_print
    print('[TelePOS] uncaught: $error\n$stack');
  });
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    // ignore: avoid_print
    print(
      '[TelePOS] flutter: ${details.exceptionAsString()}\n${details.stack}',
    );
  };

  // The screens log through `talker`, and it is a late field an entry point
  // must assign. The desktop build gives it a file observer; a browser has no
  // file, so this one goes to the console — which is where Playwright and
  // devtools read it from anyway.
  installLogger(Talker());

  final prefs = await SharedPreferences.getInstance();

  // Провод — единственный. Сессия одна на терминал: поднимать её на каждый
  // обмен значило бы платить рукопожатием QUIC за каждое нажатие.
  //
  // `ApiClient` и восемь `http_*` реализаций сняты (задача 17 плана
  // `2026-08-04-webtransport-browser-terminal.md`). Запасного пути через REST
  // нет по решению заказчика, и сторож в `test/architecture/layering_test.dart`
  // краснеет, если `package:http` вернётся в `lib/web/`: двух живых
  // реализаций у этого проекта не бывает. HTTP-сервер на кассе остаётся — он
  // отдаёт страницу, шрифты и бандл, которые браузер обязан скачать раньше,
  // чем появится хоть одна сессия WebTransport, — но данных он больше не
  // отдаёт.
  final link = WtLink(WtSession.openFromDocument);
  final tokenStore = SessionTokenStore();
  final wire = WtDispatcher(link, tokens: tokenStore);

  // Bind the contracts this scope needs to implementations that reach the
  // backend. Everything the screens use must be bound here before they run —
  // an unbound contract is a screen that has not been ported yet, and it will
  // fail loudly rather than silently showing nothing.
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
    // The built-in device profile catalog is pure Dart, compiled straight
    // into the web bundle — no `dart:io`/drift/Flutter dependency to keep
    // out (verified: it only imports lib/domain/device/*). It is genuinely
    // identical on every terminal running this build, the same way
    // service_locator.dart (the desktop DI root) wires the exact same class
    // directly rather than through a network round trip. Plan 2b, which
    // makes the catalog editable from the UI (И124), is what turns this into
    // a real per-installation source that would need a wire binding of its
    // own — until then, a settings screen just needs the reference data, not
    // a server round trip for it.
    ..registerLazySingleton<DeviceProfileCatalog>(
      () => BuiltinDeviceProfileCatalog(),
    )
    ..registerLazySingleton<DeviceBindingRepository>(
      () => WtDeviceBindingRepository(wire),
    )
    // Второй биндинг обоих контрактов (план 2b, задача 4) — рядом с
    // `DeviceDiscoveryLocal`/`DeviceCheckLocal`
    // (`lib/data/device/device_discovery_local.dart`,
    // `lib/data/device/device_check_local.dart`), которые эта касса
    // выполняет на кассе, к которой браузер подключён, а не здесь: браузер
    // сам ничего не перечисляет и ничего не проверяет — только спрашивает
    // (docs/system-architecture.md, раздел 8).
    ..registerLazySingleton<DeviceDiscovery>(
      () => WtDeviceDiscovery(wire, GetIt.I<DeviceProfileCatalog>()),
    )
    ..registerLazySingleton<DeviceCheck>(() => WtDeviceCheck(wire))
    // Задача «сетевые настройки по проводу» (спека 2026-08-24) — последний
    // экран, отдававший в браузере заглушку (`WtNotPortedScreen`). Шесть
    // вопросов, все `Ask`; Bluetooth и точка доступа этой работой не
    // переносятся — граница спеки, докстринг `NetworkRepository`.
    ..registerLazySingleton<NetworkRepository>(() => WtNetworkRepository(wire))
    // Тот же контракт, что на кассе (`LocalAuthRepository`), и та же
    // логика — эта половина только зовёт её по проводу. Проверки PIN здесь
    // нет ни строки (задача 10 плана `2026-08-20-browser-terminal-login`).
    ..registerLazySingleton<AuthRepository>(() => WtAuthRepository(wire))
    // Задача «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 6: `TillOps.authSessions`/`authSessionRevoke` заведены задачей
    // 19 с готовым обработчиком на кассе, но без единого вызывающего в
    // `lib/` — этот биндинг и есть недостающий путь, доступный из
    // браузерного терминала. См. докстринг `WtSessionAdminRepository`.
    ..registerLazySingleton<SessionAdmin>(
      () => WtSessionAdminRepository(wire),
    )
    // Токен сеанса живёт в `sessionStorage` вкладки, а не в get_it: это
    // ячейка хранения, а не служба с состоянием процесса, и `main_web.dart`
    // заводит её здесь просто как ближайшее место, где уже собираются все
    // остальные привязки этой сборки.
    //
    // Регистрируется под доменным контрактом ([SessionTokenStorage]), а не
    // под собственным типом: `LoginNotifier` (shared, VM-testable) читает её
    // через `GetIt.isRegistered<SessionTokenStorage>()`, тем же приёмом, каким
    // уже читает `ScannerRulesRepository`, — и не может назвать
    // `SessionTokenStore` по имени вовсе: этот класс тянет `dart:js_interop`,
    // которого на VM нет. Диспетчер получит тот же экземпляр.
    ..registerSingleton<SessionTokenStorage>(tokenStore)
    // Секрет терминала — не токен сеанса, и это не то же самое различие под
    // другим именем: `localStorage`, а не `sessionStorage`, потому что этот
    // приём отвечает не «кто вошёл», а «какое это устройство» (докстринг
    // `TerminalSecretStorage`, `lib/domain/terminal/terminal_secret_storage.dart`,
    // задача 5 плана «знакомство терминала с кассой»). Регистрируется под
    // доменным контрактом тем же приёмом, что и `SessionTokenStorage` выше —
    // `login_controller.dart` не может назвать `TerminalSecretStore` по
    // имени: он тянет `dart:js_interop`, которого на VM нет.
    ..registerSingleton<TerminalSecretStorage>(const TerminalSecretStore())
    ..registerLazySingleton<TerminalIdentity>(
      () => PrefsTerminalIdentity(prefs),
    )
    // Preferences are this terminal's, not the installation's: which language
    // this browser shows is a property of the browser. Anything belonging to
    // the till lives behind a contract above.
    ..registerSingleton<LocalProperties>(await LocalProperties.create())
    ..registerSingleton<BuildConfig>(BuildConfig.fromEnvironment())
    ..registerSingleton<HostCapabilities>(HostCapabilities.browser)
    // Опора и диспетчер провода. Регистрируются здесь, потому что опора одна
    // на терминал и её время жизни — время жизни вкладки.
    ..registerSingleton<WtLink>(link)
    ..registerSingleton<WtDispatcher>(wire);

  // Контейнер заводится явно, а не рождается внутри `ProviderScope`: маршруту
  // (`createSetupRouter`, `lib/app/router/setup_router.dart`) нужен готовый
  // `Listenable`, который переживёт `isLoggedIn`, ещё до первого кадра — без
  // него касса, отозвавшая сеанс, гасит состояние `LoginNotifier`, но сама
  // вкладка остаётся на прежнем экране до следующей навигации (задача 5,
  // «вкладка уходит на вход сама»). `UncontrolledProviderScope` ниже вставляет
  // этот же контейнер в дерево — `ProviderScope.containerOf(context)`,
  // которым уже пользуется `redirect` этой таблицы, находит его как обычно.
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  final router = createSetupRouter(refresh: SetupRouterRefresh(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      // Створка, а не прямой запуск: без сессии показывать нечего, и терминал
      // обязан назвать причину, а не открыться пустым. Запасного пути через
      // REST нет — решение заказчика 2026-08-04.
      child: WtBootGate(
        link: link,
        terminal: TelePosApp(router: router),
      ),
    ),
  );
}
