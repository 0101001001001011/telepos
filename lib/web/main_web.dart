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
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/stock/stock_changes.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/shift/shift_desk.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/refund/refund_service.dart';
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
import 'wt_cart_service.dart';
import 'wt_certificate_issuer.dart';
import 'wt_certificate_slip_reprinter.dart';
import 'wt_device_binding_repository.dart';
import 'wt_expiry_warning.dart';
import 'wt_hardware_diagnostics.dart';
import 'wt_device_check.dart';
import 'wt_device_discovery.dart';
import 'wt_first_launch_repository.dart';
import 'wt_network_repository.dart';
import 'wt_payment_service.dart';
import 'wt_qr_provider_setup.dart';
import 'wt_receipt_template_setup.dart';
import 'wt_shift_desk.dart';
import 'wt_refund_service.dart';
import 'wt_quick_product_catalog.dart';
import 'wt_sale_edit_terms.dart';
import 'wt_scanner_rules.dart';
import 'wt_session_admin_repository.dart';
import 'wt_session_token_store.dart';
import 'wt_setup_repository.dart';
import 'wt_startup_state_repository.dart';
import 'wt_stock_changes.dart';
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
    // ВСТРОЕННЫЙ каталог, а не `buildDeviceProfileCatalog()`, и это
    // намеренно: композит тянет `lib/data/device/composite_*` и
    // `lib/emulators/*`, а точке входа браузера позволено ровно два файла из
    // `lib/data/` (сторож `browser_routes_test.dart`). Виртуальных профилей
    // в браузере и не нужно: оба они — файловые (сканер читает файл, спулер
    // пишет в файл), а файловой системы у страницы нет. Эмуляторы, которые
    // браузеру ДОСТУПНЫ, — сетевые, и их адрес вписывается на экране
    // настроек без всякого каталога.
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
    // Возврат с планшета — задача 20 плана «Продажа с браузерного
    // терминала». Черновик, деньги, сверки с чеком, смена и печать остаются
    // кассой (`LocalRefundService`); эта половина только зовёт шесть
    // операций `RefundOps` по проводу.
    //
    // `RecentReceipts` здесь **намеренно не регистрируется**: своей операции
    // провода у списка последних чеков нет (докстринг `RecentReceipts`), и
    // диалог ввода номера спрашивает контракт условно. `CartService` — тоже
    // нет: поиск товара для возврата без чека приедет вместе с корзиной,
    // задачей 13 того же плана, и до тех пор экран называет это, а не
    // падает.
    ..registerLazySingleton<RefundService>(() => WtRefundService(wire))
    // Задача «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 6: `TillOps.authSessions`/`authSessionRevoke` заведены задачей
    // 19 с готовым обработчиком на кассе, но без единого вызывающего в
    // `lib/` — этот биндинг и есть недостающий путь, доступный из
    // браузерного терминала. См. докстринг `WtSessionAdminRepository`.
    ..registerLazySingleton<SessionAdmin>(() => WtSessionAdminRepository(wire))
    // Корзина чека — задача 13 (маршрут `/sale` в `setup_router.dart`).
    // Контракт тот же, что на кассе (`CartService`, задача 7); кассовая
    // реализация — `LocalCartService`, здесь под ним провод.
    //
    // Регистрируется под доменным контрактом, а не под собственным типом:
    // `SaleController` резолвит `GetIt.I<CartService>()` и знать про
    // `WtCartService` не имеет права — в этом и смысл того, что экран у
    // кассы и у браузера один.
    //
    // `registerLazySingleton`, а не `registerFactory`: `WtCartService`
    // держит очередь команд на рабочее место (I161, «одна команда в
    // полёте»). Второй экземпляр завёл бы вторую очередь, и порядок,
    // ради которого она существует, перестал бы держаться — два быстрых
    // скана могли бы примениться наоборот.
    ..registerLazySingleton<CartService>(() => WtCartService(wire))
    // Оплата чека — задача 17 (маршрут `/payment` в `setup_router.dart`).
    //
    // **Строки не было ни одной**, при том что `WtPaymentService` написан
    // задачей 14 и покрыт шестью пробами: служба существовала, была верна и
    // не была подключена никуда. Ровно тот род «мёртвого кода, выглядящего
    // живым», от которого в этом дереве уже заведено правило. Держит эту
    // строку сторож `test/architecture/browser_routes_test.dart`, «точка
    // входа привязывает оплату», — по образцу такого же сторожа корзины.
    //
    // Контракт тот же, что на кассе; под ним семь операций `PayOps`. Деньги,
    // печать, ящик и фискализация остаются кассой
    // (`LocalPaymentService`) — эта половина только зовёт их по проводу, и
    // именно поэтому `LocalPaymentService` в браузер и не тащится: он
    // импортирует принтер, ящик и drift.
    //
    // `registerLazySingleton`, а не `registerFactory`, по той же причине,
    // что у корзины выше: `WtPaymentService` — тонкая обёртка над одним
    // `WtDispatcher`, и второй экземпляр был бы вторым собеседником кассы
    // об одном и том же чеке.
    ..registerLazySingleton<PaymentService>(() => WtPaymentService(wire))
    // Приём аванса покупателя — требование заказчика 2026-09-18 (маршрут
    // `/prepayment` в `setup_router.dart`). Отдельный контракт, а не метод
    // оплаты: разбор — в докстринге `WtPrepaymentIntakeService`.
    //
    // На кассе под этим же контрактом стоит `CustomerPaymentUseCase` — тот
    // самый, что зовёт кассовый диалог приёма. Здесь его нет и быть не
    // может: он импортирует drift и фискальный узел.
    ..registerLazySingleton<PrepaymentIntakeService>(
      () => WtPrepaymentIntakeService(wire),
    )
    // Выдача аванса деньгами — решение заказчика 2026-09-18, вторая
    // половина того же экрана `/prepayment`. Без этой строки экран выдачи
    // падает резолвом `GetIt` на первом нажатии, а операция
    // `pay.prepaymentRefund` остаётся мёртвым кодом — ровно тем, каким
    // полтора месяца был `pay.certificateIssue`.
    //
    // На кассе под этим контрактом стоит тот же `CustomerPaymentUseCase`,
    // что и под приёмом. Здесь его нет и быть не может: он импортирует
    // drift и фискальный узел.
    ..registerLazySingleton<PrepaymentRefundService>(
      () => WtPrepaymentRefundService(wire),
    )
    // Выпуск подарочного сертификата — дыра 1 ревизии 2026-09-19 (маршрут
    // `/certificate-issue` в `setup_router.dart`). Операция провода
    // `pay.certificateIssue` существует с задачи 21 — со своим правом,
    // кодеком, обработчиком и пробами, — и до этой строки её было **нечем
    // вызвать**: ни одной реализации контракта в браузере не стояло.
    //
    // На кассе под этим же контрактом стоит `LocalCertificateIssuer`.
    // Здесь его нет и быть не может: он пишет обязательство в drift и
    // отправляет слип в очередь печати — и **этим же самым отправляет слип
    // при выпуске с планшета**: обработчик зовёт его целиком. Прежняя запись
    // на этом месте утверждала, что слипа у вкладки не будет вовсе, и была
    // неверна с первого дня. Чего не было — повтора печати; он едет строкой
    // ниже.
    ..registerLazySingleton<CertificateIssuer>(() => WtCertificateIssuer(wire))
    // Повтор печати слипа — решение заказчика 2026-09-18. Комментарий строкой
    // выше до этого дня утверждал, что слипа у вкладки «не будет вовсе», и
    // это было неверно уже тогда: выпуск с планшета исполняет касса, а она
    // печатает слип внутри выпуска. Недостижим был **повтор** — та самая
    // кнопка, ради которой кассир и приходит, когда бумажка не вышла.
    //
    // На кассе под этим контрактом стоит `LocalCertificateSlipReprinter`
    // (`lookup` + очередь печати). Здесь её нет и быть не может: очередь
    // печати тянет drift и принтер.
    ..registerLazySingleton<CertificateSlipReprinter>(
      () => WtCertificateSlipReprinter(wire),
    )
    // Настройка оплаты по QR — решение заказчика 2026-09-18 (маршрут
    // `/qr-provider-settings` в `setup_router.dart`). Экран и контроллер те
    // же, что на кассе: контроллер резолвит **доменный порт**
    // (`QrProviderSetupRepository`) и о том, какая из двух реализаций под
    // ним, не знает — в этом и смысл того, что экран один.
    //
    // На кассе под этим же портом стоит `QrPaymentDesk` — та самая стойка,
    // которой касса звонит провайдеру. Здесь её нет и быть не может: она
    // тянет drift и HTTP-клиента, а ключ провайдера в браузер не едет вовсе
    // (докстринг `WtQrProviderSetup`).
    ..registerLazySingleton<QrProviderSetupRepository>(
      () => WtQrProviderSetup(wire),
    )
    // Шаблон чека — решение заказчика 2026-09-18 (маршруты
    // `/receipt-templates` и `/receipt-templates/edit` в
    // `setup_router.dart`). Экраны те же, что на кассе: они резолвят
    // **доменный порт** (`ReceiptTemplateSetupRepository`) и о том, какая из
    // двух реализаций под ним, не знают — в этом и смысл того, что экран
    // один.
    //
    // На кассе под этим же портом стоит `LocalReceiptTemplateSetup` над
    // `receiptTemplateDao` и службой печати. Здесь её нет и быть не может:
    // она тянет drift, а предпросмотр собирается из настоящих байтов
    // ESC/POS, которых в браузере не собрать — их собирает касса и
    // присылает готовым текстом (докстринг `WtReceiptTemplateSetup`).
    ..registerLazySingleton<ReceiptTemplateSetupRepository>(
      () => WtReceiptTemplateSetup(wire),
    )
    // Смена — решение заказчика 2026-09-18 (маршрут `/terminal-shift` в
    // `setup_router.dart`). Под доменным портом `ShiftDeskRepository`; на
    // кассе под ним `LocalShiftDesk`, которую с того же дня зовёт и
    // кассовый экран смены, — то есть закрывают смену обе поверхности
    // **одной процедурой**, а не двумя похожими.
    //
    // `registerLazySingleton`, а не `registerFactory`: `watch()` заводит
    // подписку на кассу, и второй экземпляр означал бы вторую подписку на
    // одно и то же состояние.
    ..registerLazySingleton<ShiftDeskRepository>(() => WtShiftDesk(wire))
    // Диагностика оборудования — пункт «Достижимость с браузерного
    // терминала» плана `2026-09-19-hardware-diagnostics.md` (маршрут
    // `/terminal-diagnostics` в `setup_router.dart`). Вкладки те же, что на
    // кассе: они резолвят **доменный порт**
    // (`HardwareDiagnosticsRepository`) и о том, какая из двух реализаций
    // под ним, не знают.
    //
    // На кассе под этим же портом стоит `LocalHardwareDiagnostics` над
    // очередью печати, службой печати, базой и очередью фискализации. Здесь
    // её нет и быть не может: три из четырёх живут в `lib/data/` и
    // `lib/hardware/`, а разбор байтов ESC/POS в браузере завёл бы **вторую
    // раскладку чека** — чек приезжает готовым текстом, разобранным кассой
    // (докстринг `WtHardwareDiagnostics`).
    //
    // `registerLazySingleton`, а не `registerFactory`, тем же доводом, что у
    // `ShiftDeskRepository` строкой выше: `watchPrinter()` заводит подписку
    // на кассу, и второй экземпляр означал бы второй поток QUIC на одно и то
    // же состояние.
    ..registerLazySingleton<HardwareDiagnosticsRepository>(
      () => WtHardwareDiagnostics(wire),
    )
    // Условия правки строки — задачи 44–45. Без этой строки скидку с
    // терминала ввести нельзя: до них кнопка «Редактировать» пряталась
    // проверкой `isRegistered<SaleCheckoutService>()`, и отсутствие
    // привязки было режимом работы, а не ошибкой. Теперь кнопка стоит
    // всегда, а незаведённую привязку ловит сторож
    // `browser_routes_test.dart` («каждый договор, который экран продажи
    // просит у контейнера, привязан точкой входа»).
    ..registerLazySingleton<SaleEditTermsReader>(() => WtSaleEditTerms(wire))
    // Задача 45: быстрые товары и правила сканера — касса владеет обоими.
    // До задачи экран прятал «Быстрые товары» (`isRegistered`), а сканер
    // молча брал зашитые длины кода; теперь незаведённую привязку ловит
    // сторож `browser_routes_test.dart`.
    ..registerLazySingleton<QuickProductCatalog>(
      () => WtQuickProductCatalog(wire),
    )
    // Пункт 11 ревизии 2026-09-19: правила сканера с планшета не только
    // читаются. Один экземпляр под двумя договорами, а не два рядом: второй
    // означал бы вторую подписку на ту же кассу и второй кэш того же
    // состояния. Читающий договор просит `BarcodeScannerMixin`, пишущий —
    // `hardware_settings_screen.dart`.
    ..registerLazySingleton<ScannerRulesRepository>(() => WtScannerRules(wire))
    ..registerLazySingleton<ScannerRulesReader>(
      () => GetIt.I<ScannerRulesRepository>(),
    )
    // Пункт 11 ревизии 2026-09-19: «партия просрочена?». Без этой строки
    // кассир за планшетом пробивал просроченный товар молча — экран
    // продажи спрашивал складские юзкейсы у контейнера, а их здесь нет и
    // быть не может: они тянут базу кассы.
    ..registerLazySingleton<ExpiryWarningReader>(() => WtExpiryWarning(wire))
    // Пункт 12 ревизии 2026-09-19: продажа соседнего рабочего места
    // доезжает до этой вкладки. Без этой строки остаток в выдаче поиска и
    // в каталоге устаревал молча — а «молча» здесь хуже ошибки: цифра
    // выглядит свежей.
    ..registerLazySingleton<StockChanges>(() => WtStockChanges(wire))
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
