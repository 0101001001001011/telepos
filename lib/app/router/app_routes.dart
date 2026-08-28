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
  static const sale = '/sale';
  static const refund = '/refund';
  static const payment = '/payment';
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
