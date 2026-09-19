import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/diagnostics/terminal_diagnostics_screen.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/network_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/qr_payment_setup_screen.dart';
import 'package:telepos/presentation/screens/settings/receipt/receipt_templates_screen.dart';
import 'package:telepos/presentation/screens/settings/receipt/receipt_template_editor_screen.dart';
import 'package:telepos/presentation/screens/terminal/terminal_shift_screen.dart';
import 'package:telepos/presentation/screens/settings/sessions_screen.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';
import 'package:telepos/presentation/screens/certificate/certificate_issue_screen.dart';
import 'package:telepos/presentation/screens/prepayment/prepayment_intake_screen.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';
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
    // (задача 17 закрытия долга безопасности) она
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
      // планом 2b. `ScannerRulesRepository` до пункта 11 ревизии 2026-09-19
      // экран запрашивал условно (`GetIt.I.isRegistered`) ровно потому, что
      // этот биндинг его не регистрировал, — и правила сканера с планшета
      // только читались. Теперь запись есть на проводе
      // (`TillOps.scannerRulesSave`, право `settings.hardware`),
      // `main_web.dart` привязывает `WtScannerRules` и под пишущим
      // договором, а развилки на экране не осталось.
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
      // Экран продажи — задача 13 плана «Продажа с браузерного терминала»
      // (шаг 5 спеки). Экран тот же самый, что на кассе: корзина живёт за
      // контрактом `CartService` (задача 7), кассовая реализация —
      // `LocalCartService` (задача 8), браузерная — `WtCartService`
      // (задача 12), и `lib/web/main_web.dart` связывает контракт со
      // второй.
      //
      // Право — `nav.sale`, через ту же `PermissionKeys.routeToPermissionKey`,
      // которой уже пользуются `/hardware-settings` и `/sessions`: карта
      // маршрут→ключ содержит `'/sale': navSale` с самого начала, так что
      // сторож входа накрыл этот маршрут в тот же миг, как он здесь
      // появился, — без единой новой строки в `redirect`.
      //
      // `/payment` и `/shift`, куда экран продажи уходит с кнопки «Оплатить»
      // и из диалога просроченной смены, объявлены ниже заглушкой: это
      // задачи 15 и граница спеки соответственно. Отсутствие маршрута дало
      // бы «Page Not Found: GoException» — то же, что белый экран (И144).
      GoRoute(
        path: AppRoutes.sale,
        builder: (context, state) => const _BrowserSaleShell(),
      ),
      // Экран оплаты — задача 17 плана «Продажа с браузерного терминала»
      // (шаг 7 спеки). **То, ради чего вся работа и затевалась:** до неё
      // кассир набирал чек в браузере, жал «Оплатить» и упирался в «Этот
      // экран пока только на кассе».
      //
      // Экран тот же, что на кассе. Деньги, печать, ящик и фискализация
      // остаются кассой за контрактом `PaymentService` (задача 14):
      // кассовая реализация — `LocalPaymentService`, браузерная —
      // `WtPaymentService` поверх семи операций `PayOps`, и связывает
      // контракт со второй `lib/web/main_web.dart`.
      //
      // Право — `nav.payment`, через ту же `PermissionKeys.
      // routeToPermissionKey`, которой пользуются `/sale`, `/refund`,
      // `/hardware-settings` и `/sessions`. Сами денежные операции охраняет
      // **касса** ключами `op.*` (задача 19 прошлой работы): маршрут,
      // открытый по праву навигации, права двигать деньги не даёт.
      //
      // Оболочки здесь нет, и это **не** упущение — в отличие от `/refund`
      // ниже, где она заведена намеренно. Разница измерена чтением экрана:
      // все три раскладки `PaymentScreen` (узкая, планшетная, настольная)
      // строят собственный `Scaffold`, а две из трёх — ещё и `AppBar` с
      // крестиком; узкая держит свой `_Header` с тем же крестиком. Второй
      // `Scaffold` снаружи дал бы вторую шапку поверх первой.
      //
      // Уйти с экрана кассиру есть куда и без стека переходов: `_handleCancel`
      // и успешное завершение оба спрашивают `context.canPop()` и при пустом
      // стеке уходят `context.go(AppRoutes.sale)` — то есть вкладка,
      // открытая прямо по адресу `#/payment`, возвращается к чеку, а не
      // остаётся на экране оплаты навсегда. Это уже написано (задача 14) и
      // здесь только используется.
      //
      // Объявление один в один с десктопным (`app_router.dart`, `/payment`):
      // экран один и тот же, и расходиться этим двум таблицам незачем.
      GoRoute(
        path: AppRoutes.payment,
        builder: (context, state) => const PaymentScreen(),
      ),
      // `/shift` здесь нет и не появится: этот путь десктопной таблицы ведёт
      // на `ShiftScreen` — три вкладки поверх `ShiftNotifier`, который
      // читает `AppDatabase` напрямую и в браузер не собирается. Смена
      // браузерного терминала живёт под своим путём (`/terminal-shift`,
      // ниже); одно имя на два разных экрана сделало бы
      // `browser_routes_test` зелёным на заглушке — ровно тот дефект,
      // который уже стоил круга на `/payment`.
      //
      // Задача 37 ставила здесь `ShiftCloseAtTill` — «экрана нет, скажем
      // словами». С 2026-09-18 экран есть, и довод снят вместе с ним.
      // Возврат по чеку и без чека с планшета — задача 20 плана «Продажа с
      // браузерного терминала» (спека 2026-09-06, шаг 9). Экран тот же, что
      // на кассе; под ним контракт `RefundService`, привязанный к проводу в
      // `lib/web/main_web.dart` (`WtRefundService`). Право маршрута —
      // `nav.refund`, и его проверяет `redirect` этой таблицы через
      // `PermissionKeys.routeToPermissionKey()`, а сами операции возврата
      // охраняет **касса** ключами `op.refund` и `op.refundWithoutReceipt`
      // (задача 19): скрытая кнопка правом не является.
      //
      // Подсказка «последние чеки» в диалоге ввода номера в браузере пуста:
      // своей операции провода у списка нет (докстринг `RecentReceipts`).
      // Возврат по номеру от этого работает целиком.
      // Приём аванса покупателя — требование заказчика 2026-09-18. До него
      // терминал умел только **зачесть** внесённое (`pay.prepayment` —
      // чтение остатка, `PaymentRequest.prepaymentUsed` — зачёт в чеке), а
      // внести деньги вперёд — нет: приём жил в одном кассовом диалоге,
      // который зовёт `CustomerPaymentUseCase` из `GetIt` напрямую. Живая
      // приёмка 2026-09-17 намерила это как дыру.
      //
      // Экран **свой**, а не кассовый диалог, и это измерено, а не выбрано:
      // диалог открывается из карточки контрагента, а картотеки у браузера
      // нет — `nav.agent` по проводу не ездит. Покупатель ищется тем
      // единственным способом, какой у терминала есть, — по телефону
      // (`pay.loyalty`). Разбор — в докстринге `PrepaymentIntakeScreen`.
      //
      // Право маршрута — `nav.cashOperation`, через ту же
      // `PermissionKeys.routeToPermissionKey`, которой пользуются `/sale`,
      // `/refund` и `/sessions`. Саму операцию охраняет **касса** ключом
      // `op.creditRepay` сверх `nav.sale`: открытый маршрут права двигать
      // счёт расчётов покупателя не даёт.
      //
      // Оболочка **здесь**, а не в экране, и по тем же двум доводам, что у
      // `/refund` ниже: без `Scaffold` экранная клавиатура накрывает поле
      // суммы, а вкладка, открытая прямо по адресу, остаётся на экране
      // навсегда — стека переходов у неё нет.
      // Настройка оплаты по QR — решение заказчика 2026-09-18, дословно:
      // «это не граница, а пробел — в браузере должно работать то же, что в
      // приложении». Шаг 12 приёмки E0 записывал экран как достижимый только
      // с кассы; владелец, у которого вместо кассы планшет, включить оплату
      // по QR не мог ничем.
      //
      // Экран **тот же**, что на кассе (`QrPaymentSetupScreen`), и это не
      // экономия: под ним доменный порт `QrProviderSetupRepository`, у
      // которого с того дня две реализации — кассовая стойка и провод
      // (`WtQrProviderSetup`, привязан в `lib/web/main_web.dart`). Ключ
      // провайдера в браузер не едет: его нет в ответе по форме (докстринг
      // `qr_provider_setup.dart`).
      //
      // Оболочки **здесь нет**, и это не забывчивость: `QrPaymentSetupScreen`
      // строит собственный `Scaffold` с шапкой, и второй снаружи дал бы
      // вторую шапку поверх первой — ровно тот довод, по которому её нет у
      // `/payment` выше. Вместо оболочки экрану называется дом:
      // `homeRoute` — куда уходить стрелке «назад», когда стека переходов
      // нет вовсе (вкладка, открытая прямо по адресу). Дом называет таблица,
      // а не экран: у десктопной таблицы он другой, и `/terminal-home` в ней
      // не объявлен вовсе.
      //
      // Право маршрута — `settings.accounts`, через ту же
      // `PermissionKeys.routeToPermissionKey`, что и у соседей; те же четыре
      // операции провода касса охраняет тем же ключом, так что открытый
      // маршрут сам по себе правки провайдера не даёт (И162).
      GoRoute(
        path: AppRoutes.qrProviderSettings,
        builder: (context, state) =>
            const QrPaymentSetupScreen(homeRoute: AppRoutes.terminalHome),
      ),
      // Шаблон чека — решение заказчика 2026-09-18, дословно: «это не
      // граница, а пробел — в браузере должно работать то же, что в
      // приложении». Шапку и подвал чека правили только с кассы: оба экрана
      // шаблона ходили в `AppDatabase` напрямую, и в браузерную сборку не
      // собирались вовсе.
      //
      // Экраны **те же**, что на кассе, и это не экономия: под ними доменный
      // порт `ReceiptTemplateSetupRepository`, у которого с того дня две
      // реализации — кассовая (`LocalReceiptTemplateSetup`) и провод
      // (`WtReceiptTemplateSetup`, привязан в `lib/web/main_web.dart`).
      //
      // Предпросмотр в браузере — **те же байты, что уйдут в принтер**: их
      // собирает касса тем же кодом, каким печатает, разбирает своей
      // единственной функцией и присылает готовым текстом. Раскладки чека в
      // браузере нет ни строки — разбор в докстринге
      // `lib/domain/receipt/receipt_template_setup.dart`.
      //
      // Оболочки здесь нет: оба экрана строят собственный `Scaffold` с
      // шапкой, и второй снаружи дал бы вторую шапку поверх первой — тот же
      // довод, что у `/qr-provider-settings` выше. Вместо оболочки экрану
      // называется дом: `homeRoute` — куда уходить стрелке «назад», когда
      // стека переходов нет вовсе (вкладка, открытая прямо по адресу). Дом
      // называет таблица, а не экран: у десктопной таблицы он другой, и
      // `/terminal-home` в ней не объявлен вовсе.
      //
      // Право обоих маршрутов — `settings.printer`, через ту же
      // `PermissionKeys.routeToPermissionKey`, что и у соседей; те же шесть
      // операций провода касса охраняет тем же ключом, так что открытый
      // маршрут сам по себе правки шаблона не даёт (И162).
      GoRoute(
        path: AppRoutes.receiptTemplates,
        builder: (context, state) =>
            const ReceiptTemplatesScreen(homeRoute: AppRoutes.terminalHome),
      ),
      // Правка — **отдельной записью, а не вложенным маршрутом**: в
      // браузерной таблице оболочки нет, и `/receipt-templates/edit`,
      // объявленный дочерним, требовал бы `ShellRoute` ради одного экрана.
      //
      // `state.extra` в этой сборке может быть `null` и законно: вкладку
      // открывают прямо по адресу, а `extra` не переживает ни перезагрузки
      // страницы, ни ввода адреса руками. Тогда открывается **новый**
      // шаблон — то же, что показал бы список кнопкой «Новый», а не пустой
      // экран правки неизвестно чего.
      // Смена с браузерного терминала — решение заказчика 2026-09-18.
      // Замерено живьём в тот же день: смена старше суток запирает продажу
      // окном «закройте смену на кассе», а с планшета закрыть её было нечем
      // — путь упирался в стену.
      //
      // Экран **свой**, а не кассовый `ShiftScreen`, и разница названа
      // вслух в докстринге `TerminalShiftScreen`: кассовый контроллер смены
      // читает `AppDatabase` напрямую примерно в двадцати местах и в
      // браузер не собирается. Перенесено то, чего не хватало для работы, —
      // закрыть смену и открыть новую; числа приходят с кассы готовыми.
      //
      // Право маршрута — `nav.shift`, тот же, что у `/shift` на кассе и у
      // трёх операций провода. Кассиру он достаётся по умолчанию: закрыть
      // свою смену — рядовое действие у кассы.
      GoRoute(
        path: AppRoutes.terminalShift,
        builder: (context, state) =>
            const TerminalShiftScreen(homeRoute: AppRoutes.terminalHome),
      ),
      // Диагностика оборудования с планшета — пункт «Достижимость с
      // браузерного терминала» плана `2026-09-19-hardware-diagnostics.md`.
      // До него экран диагностики был заведён только в десктопной таблице, а
      // его вкладки читали кассу напрямую (`PrintQueue`, `AppDatabase`,
      // `FiscalQueueStore`) — три из четырёх договоров живут в `lib/data/` и
      // `lib/hardware/` и в браузер не собираются вовсе. Наладчик с планшетом
      // не видел ни одного байта, ушедшего в принтер.
      //
      // Экран **свой** (`TerminalDiagnosticsScreen`), а не кассовый
      // `DiagnosticsScreen`, и разница измерена, а не выбрана: кассовый
      // считает плашку эмулятора через `dart:io`, которого в браузере нет, и
      // держит пять вкладок, из которых по проводу сегодня едут две. Разбор
      // целиком — в докстринге того экрана.
      //
      // **Вкладки при этом те же самые файлы**, что на кассе: под ними
      // доменный порт `HardwareDiagnosticsRepository` с двумя реализациями —
      // `LocalHardwareDiagnostics` и `WtHardwareDiagnostics` (привязана в
      // `lib/web/main_web.dart`). Второй, «браузерной», вкладки не заведено
      // нарочно — две похожих расходятся молча.
      //
      // Чек приезжает **готовым текстом**: его разбирает касса своим
      // единственным на дерево разборщиком. Раскладки чека в браузере нет ни
      // строки — тот же довод, что у предпросмотра шаблона (докстринг
      // `lib/domain/diagnostics/hardware_diagnostics.dart`).
      //
      // Право маршрута — `settings.hardware`, через ту же
      // `PermissionKeys.routeToPermissionKey`, что и у соседей; тем же ключом
      // касса охраняет обе операции провода, так что открытый маршрут сам по
      // себе диагностики не даёт (И162).
      GoRoute(
        path: AppRoutes.terminalDiagnostics,
        builder: (context, state) =>
            const TerminalDiagnosticsScreen(homeRoute: AppRoutes.terminalHome),
      ),
      GoRoute(
        path: AppRoutes.receiptTemplateEdit,
        builder: (context, state) => ReceiptTemplateEditorScreen(
          args: state.extra is ReceiptTemplateEditorArgs
              ? state.extra! as ReceiptTemplateEditorArgs
              : const ReceiptTemplateEditorArgs(),
          homeRoute: AppRoutes.receiptTemplates,
        ),
      ),
      // Выпуск подарочного сертификата с планшета — дыра 1 ревизии
      // 2026-09-19. Операция провода `pay.certificateIssue` существует с
      // задачи 21 (своё право, свой кодек, свой обработчик, свои пробы), и
      // вызвать её было **нечем**: реализации контракта в браузере не
      // стояло, экрана не было ни на одной сборке. Закрыть дыру только на
      // кассе значило бы оставить эту операцию ровно таким же мёртвым
      // кодом, каким она была.
      //
      // Экран **тот же**, что на кассе: под ним доменный порт
      // `CertificateIssuer`, у которого с этого дня две реализации —
      // `LocalCertificateIssuer` и провод (`WtCertificateIssuer`, привязан
      // в `lib/web/main_web.dart`).
      //
      // Слип печатает **касса**, и с планшета тоже — это выяснилось разбором
      // 2026-09-18 и до него было записано здесь неверно. Слип выпуска
      // уходит в очередь внутри `LocalCertificateIssuer.issue`, которую и
      // зовёт обработчик `pay.certificateIssue`: то есть бумажка при выпуске
      // с планшета выходила всегда.
      //
      // Недостижим был **повтор** — то, ради чего кассир и приходит, когда
      // бумажка не вышла. С 2026-09-18 он едет своей операцией
      // (`pay.certificateSlip`) под портом `CertificateSlipReprinter`,
      // привязанным в `lib/web/main_web.dart`. Экран по-прежнему говорит
      // словами (`certificateSlipUnavailable`), а не прячет кнопку, — но
      // теперь только там, где порта действительно нет.
      //
      // Оболочки здесь нет: экран строит собственный `Scaffold` с шапкой, и
      // второй снаружи дал бы вторую поверх первой — тот же довод, что у
      // `/payment` и `/qr-provider-settings`. Вместо оболочки экрану
      // называется дом: куда уходить стрелке «назад», когда стека переходов
      // у вкладки нет вовсе.
      //
      // Право маршрута — `op.issueCertificate`, через ту же
      // `PermissionKeys.routeToPermissionKey`, что и у соседей; тем же
      // ключом касса охраняет саму операцию сверх `nav.sale`, так что
      // открытый маршрут выпуска сам по себе не даёт (I162).
      GoRoute(
        path: AppRoutes.certificateIssue,
        builder: (context, state) =>
            const CertificateIssueScreen(homeRoute: AppRoutes.terminalHome),
      ),
      GoRoute(
        path: AppRoutes.prepayment,
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.prepaymentIntakeTitle),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: AppLocalizations.of(context)!.globalBack,
              onPressed: () => context.go(AppRoutes.terminalHome),
            ),
          ),
          body: const PrepaymentIntakeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.refund,
        // Оболочка **здесь**, а не в экране: на кассе её даёт
        // `AdaptiveScaffold` (`lib/presentation/common/widgets/adaptive_
        // scaffold.dart`), а у браузерной таблицы оболочки нет вовсе.
        //
        // Она нужна не для красоты, и это измерено пробой:
        //
        // - **клавиатура.** Без `Scaffold` `viewInsets` никто не
        //   отрабатывает, и экранная клавиатура при вводе номера чека
        //   накрывает панель итога — сумму к возврату, последнее, что имеет
        //   право уехать под неё;
        // - **выход.** Браузерная вкладка открывается сразу по адресу, и
        //   стека переходов у неё нет: без шапки с возвратом кассир, зашедший
        //   на `/refund`, остаётся там навсегда.
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.refundTitle),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: AppLocalizations.of(context)!.globalBack,
              onPressed: () => context.go(AppRoutes.terminalHome),
            ),
          ),
          body: const RefundScreen(),
        ),
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

/// Оболочка экрана продажи в браузере: `Scaffold` и путь назад.
///
/// # Почему не `AdaptiveScaffold`
///
/// Десктопная таблица держит продажу, возврат, смену и историю внутри
/// `ShellRoute` с `AdaptiveScaffold` (`lib/app/router/app_router.dart:138`)
/// — оттуда и `Scaffold`, и боковая навигация. Браузерная таблица оболочки
/// не имеет вовсе: каждый её экран до задачи 13 приносил `Scaffold` с
/// собой, а `SaleScreen` его не приносит — он всегда жил внутри оболочки.
///
/// Взять `AdaptiveScaffold` сюда нельзя, и это измерено, а не предположено:
/// его замыкание импортов доходит до `AppDatabase` двумя путями —
/// `shift_controller.dart` и `core/services/update/updater_service.dart`, —
/// то есть до `dart:io` и `package:sqlite3/sqlite3.dart`. Перенос оболочки
/// на провод — отдельная работа; здесь ставится наименьшее, чего экрану не
/// хватает: `Material` под полем поиска и дверь наружу.
///
/// **Дверь обязательна.** Экран, из которого нельзя выйти, — тупик с
/// надписью: тот же вывод, которым `WtNotPortedScreen` получил кнопку
/// «Назад» (`wt_setup_router_test.dart`, «с названного экрана есть выход»).
/// Здесь выход — дом терминала, единственное осмысленное место у
/// браузерной таблицы.
class _BrowserSaleShell extends StatelessWidget {
  const _BrowserSaleShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.navSale),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: AppLocalizations.of(context)!.globalBack,
          onPressed: () => context.go(AppRoutes.terminalHome),
        ),
      ),
      // С 2026-09-18 у браузерной таблицы **есть** рабочий экран смены, и
      // потому здесь `ShiftCloseHere`, а не `ShiftCloseAtTill`. Задача 37
      // ставила сюда «на кассе» не из осторожности, а по правде: экрана не
      // было, и кнопка вела бы в заглушку `/shift`. Теперь путь есть, и
      // окно просроченной смены ведёт по нему.
      body: SaleScreen(
        shiftClose: ShiftCloseHere(
          (context) => context.go(AppRoutes.terminalShift),
        ),
      ),
    );
  }
}
