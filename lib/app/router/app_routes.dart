/// Every route path in the application, and nothing else.
///
/// This file deliberately imports nothing. Screens need the path constants to
/// navigate, and if they took them from the router table instead, every screen
/// would transitively import every other screen — which is exactly what used to
/// happen: the browser binding asked for three setup screens and the compiler
/// pulled in 653 files, the database and the hardware with them.
///
/// Route *tables* live next to this file, one per binding. See
/// docs/ARCHITECTURE.md.
abstract class AppRoutes {
  static const splash = '/';
  static const initialSetup = '/initial-setup';
  static const restoreOrNew = '/restore-or-new';
  static const telegramSetup = '/telegram-setup';
  static const login = '/login';

  /// Дом терминала: куда `getPostLoginRoute()` ведёт вошедшего там, где базы
  /// нет — то есть в браузере (`HostCapabilities.ownsData == false`). `/shift`
  /// и экран продажи читают `AppDatabase` напрямую и под браузер не
  /// собираются; здесь показывается, кто вошёл, состояние смены и то немногое,
  /// что этому хосту доступно по правам. См. `login_controller.dart`,
  /// `lib/domain/host/host_capabilities.dart`, раздел 4 управляющего
  /// документа.
  static const terminalHome = '/terminal-home';

  /// Смена на браузерном терминале — решение заказчика 2026-09-18.
  ///
  /// **Свой путь, а не `/shift`**, и это не прихоть: `/shift` объявлен
  /// десктопной таблицей и ведёт на `ShiftScreen` — три вкладки поверх
  /// `ShiftNotifier`, который читает `AppDatabase` напрямую и в браузер не
  /// собирается вовсе. Одно имя на два разных экрана означало бы, что
  /// `browser_routes_test` считает `/shift` обслуженным в браузерной
  /// таблице, а кассир упирается в заглушку — ровно тот дефект, который уже
  /// стоил круга на `/payment`.
  ///
  /// Разница между экранами названа вслух в докстринге
  /// `TerminalShiftScreen`.
  static const terminalShift = '/terminal-shift';
  static const sale = '/sale';
  static const refund = '/refund';
  static const payment = '/payment';

  /// Приём аванса покупателя — требование заказчика 2026-09-18.
  ///
  /// **Маршрут браузерной таблицы, и только её.** На кассе то же действие
  /// живёт диалогом в карточке контрагента (`RecordCustomerPaymentDialog`),
  /// и второй вход к нему рядом был бы вторым экраном на одно действие. У
  /// терминала карточки контрагентов нет вовсе — картотека за `nav.agent`
  /// по проводу не ездит, — поэтому покупатель ищется по телефону прямо на
  /// этом экране.
  ///
  /// Право — `nav.cashOperation` (карта `PermissionKeys`): приём денег у
  /// покупателя это кассовая операция, а не продажа, и кассиру этот ключ
  /// полагается по умолчанию. Саму операцию провода охраняет **касса**
  /// ключом `op.creditRepay` сверх `nav.sale`: маршрут, открытый по праву
  /// навигации, права двигать счёт расчётов не даёт.
  static const prepayment = '/prepayment';
  static const shift = '/shift';
  static const shiftHistory = '/shift-history';
  static const history = '/history';
  static const agent = '/agent';
  static const supply = '/supply';
  static const cashOperation = '/cash-operation';
  static const settings = '/settings';
  static const transportSettings = '/transport-settings';
  static const printerSettings = '/printer-settings';
  static const labelPrinterSettings = '/label-printer-settings';
  static const labelTemplates = '/label-templates';
  static const labelTemplateEdit = '/label-templates/edit';
  static const receiptTemplates = '/receipt-templates';
  static const receiptTemplateEdit = '/receipt-templates/edit';
  static const fiscalSettings = '/fiscal-settings';
  static const taxSettings = '/tax-settings';

  /// Часы, в которые категорию продавать нельзя.
  ///
  /// Механизм запрета был в продукте с самого начала и не имел ни
  /// экрана, ни вызова: заполнить его было нечем, а проверка не
  /// выполнялась ни разу (измерено 2026-09-22).
  static const sellingHours = '/selling-hours';

  /// Настройка оплаты по QR: провайдер (адрес, код, ключ, ожидание) и
  /// выключатель вида оплаты 6 — пункт 8 C (2026-09-15).
  static const qrProviderSettings = '/qr-provider-settings';

  /// Экран нефискализованных чеков — «деньги взяты, документа нет».
  ///
  /// Один на всю кассу. Источник списка — очередь фискализации, а не
  /// колонка исхода в `Sales`: колонка появляется позже (задача 14) и
  /// будет правдой на чеке, но не источником списка.
  static const unfiscalizedReceipts = '/unfiscalized-receipts';

  /// Договоры рассрочки покупателя — задача 24.
  ///
  /// **Маршрут go_router, а не `MaterialPageRoute` из диалога**, и это не
  /// вкусовщина: право `op.creditRepay` проверяет `redirect`
  /// маршрутизатора по карте `PermissionKeys.routeToPermissionKey`, и
  /// экран, вытолкнутый мимо таблицы маршрутов, прошёл бы мимо проверки
  /// целиком. Спрятанная кнопка правом не является (I162) — а здесь и
  /// прятать нечего: кнопка в карточке покупателя видна всем.
  ///
  /// Покупатель едет **параметрами запроса**: `?agentId=5&agentName=…`.
  static const creditContracts = '/credit-contracts';

  /// Выпуск подарочного сертификата и повтор печати его слипа — дыра 1
  /// ревизии 2026-09-19.
  ///
  /// # Почему это маршрут, а не диалог и не шаг оплаты
  ///
  /// Три места были взвешены, и выбрано третье.
  ///
  /// 1. **Действие в карточке товара с родом `giftCertificate`** — карточка
  ///    товара это редактор каталога, а не место у прилавка. Выпуск создаёт
  ///    обязательство кассы; заводить его из справочника значило бы дать
  ///    бумажке остаток до того, как за неё кто-нибудь заплатил.
  /// 2. **Шаг оплаты** — самый верный по смыслу и самый опасный по
  ///    построению: выпуск встал бы **после** взятых денег, внутри экрана,
  ///    который к этому моменту уже показал успех. Отказ выпуска (занятый
  ///    номер — достижим опечаткой) пришлось бы либо проглотить, либо
  ///    откатить оплату, которой оператор уже выдал признак. Провод этой
  ///    ловушки избегает намеренно: `pay.certificateIssue` — **отдельная**
  ///    операция, а не поле `pay.complete` (докстринг `PayOps
  ///    .certificateIssue`), и интерфейс, сросшийся с оплатой там, где
  ///    провод разошёлся, разойдётся с проводом.
  /// 3. **Свой маршрут** — выбран. Он повторяет ту же границу, что провод:
  ///    деньги берёт чек, бумажку заводит отдельное действие. Кассир
  ///    приходит сюда с уже пробитым чеком и называет его номер
  ///    (`receiptNo`, необязательный) — тем же полем, каким его называет
  ///    кадр провода.
  ///
  /// # Право проверяет `redirect`, а не видимость кнопки
  ///
  /// Ключ `op.issueCertificate` стоит в карте
  /// `PermissionKeys.routeToPermissionKey`, и маршрут без него не
  /// открывается — тем же приёмом, каким закрыт `/credit-contracts`.
  /// Спрятанная кнопка правом не является (I162); экран сверх того
  /// спрашивает право **у самого действия**, перед вызовом выпуска.
  static const certificateIssue = '/certificate-issue';

  /// Выдача аванса покупателю деньгами — дыра 2 ревизии 2026-09-19.
  ///
  /// **Рядом с приёмом, а не второе место.** Приём живёт диалогом в
  /// карточке контрагента (`RecordCustomerPaymentDialog`), и выдача
  /// открывается кнопкой **из той же карточки**, соседней с ним; под обеими
  /// один контроллер (`CustomerPaymentController`) и один юзкейс.
  /// Покупатель едет параметрами запроса (`?agentId=5&agentName=…`) — ровно
  /// как у [creditContracts] и по тому же доводу.
  ///
  /// # Почему выдача — маршрут, а приём остался диалогом
  ///
  /// Не из любви к симметрии и не из её отсутствия: из-за **права**.
  /// Выдача выпускает деньги из кассы и уменьшает расчётный счёт
  /// покупателя, а единственное место на кассе, где право проверяется не
  /// видимостью кнопки, — карта маршрутов (`redirect` в `app_router.dart`).
  /// У `showDialog` такой проверки нет вовсе, и выдача, сделанная диалогом,
  /// была бы закрыта ровно настолько, насколько закрыт вызов метода, — то
  /// есть никак (I162).
  ///
  /// Приём при этом **не переносится** сюда же: он работает, у него есть
  /// живая приёмка, и переезд ради красоты стоил бы круга проверок при
  /// нулевой прибыли. Что приём на кассе не закрыт правом — названо, а не
  /// починено: это тот же второй фронт кассы, что у скидки и у отложенных,
  /// и чинится он одной работой на все три, а не тремя.
  ///
  /// Ключ — `op.creditRepay`, тот же, каким касса закрывает приём аванса
  /// **на проводе** (`pay.prepaymentIntake`). Разбор — в карте
  /// `_routePermissions`.
  static const prepaymentRefund = '/prepayment-refund';

  static const esfSettings = '/esf-settings';
  static const esfOutbox = '/esf-outbox';
  static const snt = '/snt';
  static const sntSettings = '/snt-settings';
  static const esutd = '/esutd';
  static const esutdSettings = '/esutd-settings';
  static const ismptSettings = '/ismpt-settings';
  static const restaurantSettings = '/restaurant-settings';
  static const hardwareSettings = '/hardware-settings';

  /// Где оператор открывает и закрывает порт кассы для браузерных терминалов.
  ///
  /// Только в десктопном маршрутизаторе: экран настраивает сокеты этой машины,
  /// а у браузерной вкладки своих нет (И11).
  static const terminalServiceSettings = '/terminal-service-settings';

  /// Что касса отправила приборам: вкладки принтера и фискализации.
  ///
  /// В десктопной таблице: показывает задания печати ЭТОГО рабочего места и
  /// очередь фискализации этой кассы.
  static const diagnostics = '/diagnostics';

  /// То же, открытое **с планшета** — пункт «Достижимость с браузерного
  /// терминала» плана `2026-09-19-hardware-diagnostics.md`.
  ///
  /// Отдельный путь, а не тот же `/diagnostics`, и по тому же доводу, что у
  /// `/terminal-shift`: экран **другой**, и одно имя на два разных экрана
  /// сделало бы `browser_routes_test` зелёным на подмене. Разница измерена и
  /// названа в докстринге `TerminalDiagnosticsScreen` — кассовый экран тянет
  /// `dart:io` ради плашки эмулятора и держит пять вкладок, из которых по
  /// проводу сегодня едут две.
  ///
  /// Только в браузерной таблице: на кассе тот же ответ даёт `/diagnostics`,
  /// и второй вход в него был бы двумя именами одного места.
  static const terminalDiagnostics = '/terminal-diagnostics';

  /// Где оператор включает встроенные эмуляторы приборов.
  ///
  /// Тоже только в десктопном маршрутизаторе, и по той же причине: эмулятор —
  /// сокет ЭТОЙ машины. Браузерной вкладке включать нечего (И11).
  static const emulatorSettings = '/emulator-settings';
  static const applianceSettings = '/appliance-settings';
  static const systemManagement = '/system-management';
  static const systemTerminal = '/system-terminal';
  static const logJournal = '/log-journal';
  static const networkSettings = '/network-settings';
  static const accountsSettings = '/accounts-settings';
  static const userManagement = '/user-management';

  /// Walk-up (вход без выбора кассира) и срок сеанса. Задача 18, закрытие
  /// И31: `ThisPosDao.saveAuthSettings` существовала в схеме без единого
  /// вызывающего в `lib/`.
  static const authSettings = '/auth-settings';

  /// Список живых сеансов и их отзыв. Задача 19 закрытия долга безопасности:
  /// экран списка сеансов (`sessions_screen.dart`) не имел вызывающего для
  /// отзыва одного сеанса — этот маршрут и есть недостающий путь к нему
  /// (`SessionRegistry.revokeSession`). Отдельно от этого,
  /// `SessionRegistry.revokeAll()` существовал с задачи 9 без единого
  /// вызывающего в `lib/` и снят задачей 21 — маршрут не восстанавливает
  /// его, а обходится без него вовсе.
  static const sessions = '/sessions';

  /// Экран кода привязки — задача 2 работы «знакомство терминала с кассой»
  /// (`docs/internal/superpowers/specs/2026-08-23-terminal-enrolment-design.md`).
  /// Оживляет `PairingInvites.mint()` (задача 1 вывела его в `GetIt`,
  /// `service_locator.dart`): без вызывающего второе устройство не могло
  /// получить `/ca.crt` никаким путём из интерфейса — только ручным
  /// копированием файла. Только в десктопном маршрутизаторе, тем же доводом,
  /// что и у [terminalServiceSettings]: `ApiServer` и его `PairingInvites`
  /// живут в процессе кассы, а не в браузерной вкладке.
  static const terminalPairing = '/terminal-pairing';
  static const sync = '/sync';
  static const writeoff = '/writeoff';
  static const inventory = '/inventory';
  static const catalog = '/catalog';
  static const reports = '/reports';
  static const additional = '/additional';
  static const staffChat = '/staff-chat';
  static const telegramSettings = '/telegram-settings';

  static const tables = '/tables';
  static const tableDetail = '/tables/:tableId';
  static const orders = '/orders';
  static const orderDetail = '/orders/:orderId';

  static const stockRegistry = '/stock-registry';
  static const movement = '/movement';
  static const supplierReturn = '/supplier-return';
  static const supplierOrder = '/supplier-order';
  static const reorderRules = '/reorder-rules';
  static const markupSettings = '/markup-settings';
  static const promotions = '/promotions';

  /// Пределы ручной скидки по ролям — задача 12 плана «Полнота продажи».
  /// Единственный вход — пункт «Пределы скидки» в общих настройках.
  static const discountLimits = '/discount-limits';
  static const customerDisplay = '/customer-display';

  static const serviceQueue = '/service-queue';
  static const serviceIntake = '/service-intake';
  static const serviceDetail = '/service-queue/:orderId';
  static const serviceCatalog = '/service-catalog';

  static const wmsDashboard = '/wms';
  static const wmsWarehouses = '/wms-warehouses';
  static const wmsBatches = '/wms-batches';
  static const wmsSerials = '/wms-serials';
  static const wmsClaims = '/wms-claims';
  static const wmsCellStock = '/wms-cell-stock';
  static const wmsMarking = '/wms-marking';
  static const wmsSettings = '/wms-settings';

  static const shellRoutes = [
    sale,
    refund,
    shift,
    shiftHistory,
    history,
    catalog,
    agent,
    supply,
    stockRegistry,
    movement,
    supplierReturn,
    supplierOrder,
    reorderRules,
    markupSettings,
    promotions,
    discountLimits,
    unfiscalizedReceipts,
    creditContracts,
    certificateIssue,
    prepaymentRefund,
    esfSettings,
    esfOutbox,
    snt,
    sntSettings,
    esutd,
    esutdSettings,
    ismptSettings,
    cashOperation,
    settings,
    terminalServiceSettings,
    sync,
    additional,
    applianceSettings,
    systemManagement,
    systemTerminal,
    logJournal,
    tables,
    orders,
    serviceQueue,
    serviceIntake,
    wmsDashboard,
    wmsWarehouses,
    wmsBatches,
    wmsSerials,
    wmsCellStock,
    wmsClaims,
    wmsMarking,
    wmsSettings,
  ];

  static const standaloneRoutes = [
    splash,
    initialSetup,
    restoreOrNew,
    login,
    terminalHome,
    payment,
    networkSettings,
  ];

  /// Routes reachable without being logged in.
  static const publicRoutes = [
    splash,
    login,
    initialSetup,
    restoreOrNew,
    networkSettings,
  ];
}
