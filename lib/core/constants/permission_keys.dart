import 'package:telepos/core/constants/enums/user_role.dart';

abstract class PermissionKeys {
  PermissionKeys._();

  static const navSale = 'nav.sale';
  static const navRefund = 'nav.refund';
  static const navShift = 'nav.shift';
  static const navHistory = 'nav.history';
  static const navCatalog = 'nav.catalog';
  static const navAgent = 'nav.agent';
  static const navSupply = 'nav.supply';
  static const navCashOperation = 'nav.cashOperation';
  static const navSettings = 'nav.settings';
  static const navSync = 'nav.sync';
  static const navReports = 'nav.reports';
  static const navServiceQueue = 'nav.serviceQueue';
  static const navServiceIntake = 'nav.serviceIntake';
  static const navTables = 'nav.tables';
  static const navOrders = 'nav.orders';

  // Пункт 6 финальной волны закрытия долга безопасности (2026-08-22):
  // объявлены, показаны в форме `user_management_screen.dart`, розданы
  // ролям (`roleDefaults`), мигрированы в базу каждому пользователю
  // (v32→v33/v34→v35) — но **ни одна из этих восьми строк не читается ни
  // одним вызовом `hasPermission` во всём `lib/`**. Всего пять мест зовут
  // `hasPermission` (`app_router.dart`, `setup_router.dart`,
  // `app_state_controller.dart`'s `hasPermissionProvider` — которую тоже
  // никто не зовёт, `terminal_home_screen.dart` дважды), и ни одно не
  // спрашивает `op.*`. `PointModePermissions.effective` их только
  // *вычитает* у роли по режиму терминала — доходят до `AppState.
  // permissions` как действующее множество, но ничего в `lib/` это
  // множество на `op.*` не проверяет: владелец, снявший кассиру «Возврат
  // без чека», получает ровно ничего.
  //
  // Тот же критерий, по которому фаза 5 сняла три ключа-плацебо (объявлены,
  // показаны, не читаются ни одним экраном) — но эти восемь **не сняты**:
  // решение — не удалить, а подключить к настоящим проверкам, потому что
  // это операционные права, которые кассе нужны по существу (в отличие от
  // снятых трёх). До подключения — читай эту строку как предупреждение, не
  // как работающий механизм. Граница названа в спеке
  // (`docs/internal/superpowers/specs/2026-08-21-security-debt-closure-design.md`,
  // «Границы»).
  static const opEditPrice = 'op.editPrice';
  static const opSellDiscount = 'op.sellDiscount';
  static const opSellDebt = 'op.sellDebt';
  static const opCashInOut = 'op.cashInOut';
  static const opCancelPayment = 'op.cancelPayment';
  static const opDeferSale = 'op.deferSale';
  static const opRefund = 'op.refund';
  static const opRefundWithoutReceipt = 'op.refundWithoutReceipt';

  static const settingsUsers = 'settings.users';
  static const settingsAccounts = 'settings.accounts';
  static const settingsPrinter = 'settings.printer';
  static const settingsFiscal = 'settings.fiscal';
  static const settingsHardware = 'settings.hardware';
  static const settingsRestaurant = 'settings.restaurant';
  static const settingsTransport = 'settings.transport';
  static const settingsTelegram = 'settings.telegram';

  // Правка «второй порядок» закрытия долга безопасности (2026-08-22),
  // пункт 1: три маршрута настроек — `/terminal-service-settings`,
  // `/log-journal`, `/appliance-settings` — не были закрыты ничем: ни
  // ключом права, ни `ownerOnlyScaffold` (в отличие от `/system-management`
  // и `/system-terminal`, которых виджет проверяет напрямую). Любой
  // вошедший с любой ролью, включая `UserRole.user` (самую узкую), открывал
  // их прямым переходом по адресу. Три новых ключа, а не переиспользование
  // существующих: ни один из трёх экранов не совпадает по смыслу ни с одним
  // уже заведённым ключом настроек (`settingsHardware` — профили
  // периферии кассы: сканер/весы/денежный ящик/POS-терминал, не сеть и не
  // журнал; `settingsUsers` — кто и как входит, не то же самое, что порт
  // терминалов или системный журнал).
  static const settingsTerminalService = 'settings.terminalService';
  static const settingsLogJournal = 'settings.logJournal';
  static const settingsAppliance = 'settings.appliance';

  /// Полный словарь ключей прав — 34 на 2026-08-22 (правка «второй порядок»
  /// добавила три: [settingsTerminalService], [settingsLogJournal],
  /// [settingsAppliance] — см. комментарий над ними).
  ///
  /// # Граница Б-2 закрытия долга безопасности (2026-08-22): allow-list
  /// замкнут навсегда, если добавить ключ сюда без миграции
  ///
  /// После задачи 16 (`UserPermissionDao.getAllowedKeys`: пустая строка =
  /// запрещено) и правки Б-1 (миграция v32→v33 дописывает разрешающую
  /// строку на каждый ключ существующему не-владельцу) таблица
  /// `user_permissions` — allow-list: ключ действует, только если для него
  /// есть строка `isAllowed = true`. [roleDefaults] читается ОДИН раз —
  /// при заведении нового пользователя (мастер, форма создания). Больше
  /// никто и никогда не дописывает недостающие строки существующим
  /// пользователям — миграция v32→v33 сделала это один раз, для одного
  /// перехода, и не повторяется на каждый новый ключ.
  ///
  /// Значит: **любой ключ, добавленный в этот набор будущей версией, будет
  /// запрещён всем существующим не-владельцам** — у них просто не будет
  /// строки на него, а отсутствие строки теперь и означает запрет. Новый
  /// ключ достаётся только тем, кого заведут ПОСЛЕ его появления в словаре;
  /// все, кто уже существовал, — нет, до тех пор, пока кто-то не даст им
  /// права вручную через экран.
  ///
  /// **Правило на будущее:** добавление ключа в этот набор обязано
  /// сопровождаться шагом миграции (по образцу блока `if (from < 33)` в
  /// `app_database.dart`), который выдаёт новый ключ существующим
  /// пользователям по умолчанию их роли (`roleDefaults[role]`) — иначе
  /// новая возможность тихо не работает ни для кого, кроме тех, кого заведут
  /// заново. Граница названа явно в спеке
  /// (`docs/internal/superpowers/specs/2026-08-21-security-debt-closure-design.md`,
  /// «Границы»).
  static const Set<String> allPermissions = {
    navSale,
    navRefund,
    navShift,
    navHistory,
    navCatalog,
    navAgent,
    navSupply,
    navCashOperation,
    navSettings,
    navSync,
    navReports,
    navServiceQueue,
    navServiceIntake,
    navTables,
    navOrders,
    opEditPrice,
    opSellDiscount,
    opSellDebt,
    opCashInOut,
    opCancelPayment,
    opDeferSale,
    opRefund,
    opRefundWithoutReceipt,
    settingsUsers,
    settingsAccounts,
    settingsPrinter,
    settingsFiscal,
    settingsHardware,
    settingsRestaurant,
    settingsTransport,
    settingsTelegram,
    settingsTerminalService,
    settingsLogJournal,
    settingsAppliance,
  };

  static const Map<String, List<String>> groups = {
    'navigation': [
      navSale,
      navRefund,
      navShift,
      navHistory,
      navCatalog,
      navAgent,
      navSupply,
      navCashOperation,
      navSettings,
      navSync,
      navReports,
      navServiceQueue,
      navServiceIntake,
      navTables,
      navOrders,
    ],
    'operations': [
      opEditPrice,
      opSellDiscount,
      opSellDebt,
      opCashInOut,
      opCancelPayment,
      opDeferSale,
      opRefund,
      opRefundWithoutReceipt,
    ],
    'settings': [
      settingsUsers,
      settingsAccounts,
      settingsPrinter,
      settingsFiscal,
      settingsHardware,
      settingsRestaurant,
      settingsTransport,
      settingsTelegram,
      settingsTerminalService,
      settingsLogJournal,
      settingsAppliance,
    ],
  };

  /// Что получает **новый** пользователь, заведённый мастером, если никто
  /// ничего не выбирал руками.
  ///
  /// Единственное место, где умолчания по роли вообще существуют — их не
  /// было в проекте нигде до задачи 12. `owner` здесь — для полноты и
  /// симметрии с правилом ниже, а не потому что его кто-то читает:
  /// `LocalAuthRepository._issue` выдаёт владельцу [allPermissions] в обход
  /// этой таблицы и таблицы прав целиком.
  ///
  /// # Кто на самом деле читает эту карту (поправлено правкой Б-4, 2026-08-22)
  ///
  /// Только мастер первого запуска — `SetupRepositoryLocal
  /// ._writeRoleDefaultPermissions` (задача 13), заводящий не-владельцев без
  /// экрана прав вовсе. Форма из настроек (`user_management_screen.dart`,
  /// `_UserEditDialogState._loadPermissions`, ветка `isCreating`) эту карту
  /// **не читает**: она включает все переключатели по умолчанию для любой
  /// роли — человек видит каждый ключ на экране и должен снять лишнее сам,
  /// прежде чем нажать «Сохранить». Старая формулировка этого абзаца
  /// («применяется только к заведению новых не-владельцев, задача 13») эту
  /// разницу стирала — читалась как «применяется к любому заведению нового
  /// пользователя», что для формы неверно.
  ///
  /// Миграция существующих пользователей (задача 15, `if (from < 33)` в
  /// `app_database.dart`) эту карту тоже не читает — она пишет каждому то,
  /// что действует сегодня (недостающие ключи — как разрешённые, правка
  /// Б-1), а не умолчание по роли.
  ///
  /// **Граница Б-2** (см. докстринг [allPermissions]): это единственное
  /// место, где умолчания по роли применяются, — и только при заведении. Ни
  /// один механизм не дописывает недостающие ключи существующим
  /// пользователям на постоянной основе; добавление ключа в [allPermissions]
  /// требует отдельного шага миграции, иначе он тихо не достаётся никому,
  /// кроме заведённых заново.
  static final Map<UserRole, Set<String>> roleDefaults = {
    // Обходит таблицу прав в LocalAuthRepository._issue — значение ниже не
    // проверяется рантаймом, но правило то же самое: владелец не сужается.
    UserRole.owner: allPermissions,

    // Всё, кроме управления пользователями. `settings.users` — это право
    // назначать роли и PIN другим, то есть право раздавать права; отдав его
    // администратору, отдаёшь ему и путь самоповышения (завести себе или
    // другому администратору права владельца через ту же форму). Это
    // единственное, что «явно принадлежит владельцу» — линия проведена по
    // одному ключу, а не по вкусу.
    //
    // Правка Б-4 закрытия долга безопасности (2026-08-22): до этой правки
    // здесь стоял рукописный литерал — те же 30 ключей, но набранные
    // вручную, — а докстринг класса обещал «вычисляется от [allPermissions],
    // новый ключ появится сам». Расхождение молчало бы: новый ключ,
    // добавленный в словарь, тихо НЕ появлялся бы у администратора, пока
    // кто-то не вспомнил бы дописать его в этот литерал руками. Приведено к
    // докстрингу, не наоборот, — вычисляемое множество, а не переписанное:
    // администратор получает всё, кроме единственного явно исключённого
    // ключа, и это верно как автоматическое умолчание для нового ключа —
    // «всё, что не раздача прав» ближе к намерению роли, чем «то, что было
    // явно перечислено на момент, когда писали этот код».
    UserRole.administrator: {...allPermissions}..remove(settingsUsers),

    // Самый узкий набор из всех четырёх: никакой строки кода в проекте не
    // отличает `UserRole.user` предметно (только цвет бейджа в
    // user_management_screen.dart и место в `role.index <=
    // UserRole.administrator.index`, где эта роль — НЕ супервизор наравне с
    // кассиром). Раз назначение роли предметно не находится, умолчание не
    // придумывает его: только то, что не открывает ни денег, ни настроек —
    // посмотреть историю продаж и каталог, не более.
    UserRole.user: {
      navHistory,
      navCatalog,
    },

    // Торговля и смена — как велит бриф — и ничего из настроек. Список
    // навигации — рабочее место кассира во всех четырёх режимах
    // (nav_destinations.dart): помимо retail-троицы sale/refund/shift это
    // также tables/orders (restaurant) и serviceQueue/serviceIntake
    // (service) — те же самые «продаю сейчас», только под другим именем в
    // другом режиме. cashOperation — внесение/изъятие по смене, тоже часть
    // «смены», не настроек. history — свой же чек посмотреть.
    //
    // Исключены из навигации: agent (это не продажа, а ведение картотеки
    // контрагентов — CRUD-экран, а не выбор покупателя на кассе),
    // supply (приёмка товара — складская операция, не торговая), reports
    // (аналитика по всей кассе — управленческая функция), sync — и, по
    // прямому требованию брифа, settings и всё settings.* целиком: ни один
    // settings-ключ кассиру не достаётся, хотя до этой задачи пустая
    // таблица прав отдавала ему их все.
    //
    // Операции: скидка, продажа в долг, внесение/изъятие, отложенная
    // продажа и обычный возврат (по чеку) — обыденные действия у кассы.
    // Не достаются: editPrice (произвольная правка цены — путь слить
    // маржу), cancelPayment (отмена уже проведённой оплаты — деньги
    // фактически взяты, отмена без чужого подтверждения — путь кражи) и
    // refundWithoutReceipt (возврат без чека — самый дешёвый способ обнала
    // без следа). Эти три — ровно то, ради чего в системе вообще есть
    // роль-супервизор, авторизующая операцию поверх кассира
    // (RoleIdentificationServiceImpl.identify, role.index <=
    // UserRole.administrator.index): без них кассир не может провернуть их
    // в одиночку.
    UserRole.cashier: {
      navSale,
      navRefund,
      navShift,
      navHistory,
      navCatalog,
      navCashOperation,
      navTables,
      navOrders,
      navServiceQueue,
      navServiceIntake,
      opSellDiscount,
      opSellDebt,
      opCashInOut,
      opDeferSale,
      opRefund,
    },
  };

  /// Карта маршрут → ключ права, читаемая [routeToPermissionKey].
  ///
  /// Правка «маршрут → ключ» закрытия долга безопасности (2026-08-22):
  /// восемь `settings.*`-маршрутов ниже добавлены сюда, а не второй
  /// параллельной картой в `app_router.dart` — задача 17 сознательно не
  /// стала туда лезть именно потому, что вторая карта рядом с этой была бы
  /// тем самым дублированием, из-за которого долг и возник (см.
  /// `task-17-report.md`, «В чём не уверен», пункт 1). `/user-management` —
  /// самый острый: это ровно путь самоповышения, который докстринг
  /// [roleDefaults] называет причиной, по которой `settings.users` не
  /// достаётся администратору.
  static const Map<String, String> _routePermissions = {
    '/sale': navSale,
    '/refund': navRefund,
    '/shift': navShift,
    '/history': navHistory,
    '/catalog': navCatalog,
    '/agent': navAgent,
    '/supply': navSupply,
    '/cash-operation': navCashOperation,
    '/settings': navSettings,
    '/sync': navSync,
    '/reports': navReports,
    '/service-queue': navServiceQueue,
    '/service-intake': navServiceIntake,
    '/tables': navTables,
    '/orders': navOrders,
    '/printer-settings': settingsPrinter,
    '/fiscal-settings': settingsFiscal,
    '/hardware-settings': settingsHardware,
    '/restaurant-settings': settingsRestaurant,
    '/transport-settings': settingsTransport,
    '/telegram-settings': settingsTelegram,

    // Блокер 2 финальной волны закрытия долга безопасности (2026-08-22):
    // `/telegram-setup` (`TelegramAuthScreen` — телефон, код, авторизация
    // учётной записи Telegram, один из двух оставшихся транспортов) не был
    // в этой карте вовсе и проходил `redirect` любому вошедшему без
    // проверки права. `route_permission_coverage_test.dart` объявлял его
    // «нет ключа права ни для одной роли» — неправда: тот же периметр, что
    // и у соседнего `/telegram-settings` прямо над этой строкой, тот же
    // ключ.
    '/telegram-setup': settingsTelegram,
    '/accounts-settings': settingsAccounts,
    '/user-management': settingsUsers,

    // Задача 18, закрытие И31: walk-up и срок сеанса — то же решение «кто и
    // как входит в кассу», что и управление пользователями, поэтому тот же
    // ключ, а не собственный. Отдельный ключ потребовал бы отдельного шага
    // миграции (см. докстринг [allPermissions], «Правило на будущее») ради
    // экрана, который семантически — часть той же самой границы, что и
    // `/user-management`: администратор не получает его по умолчанию по той
    // же причине — самоповышение через смену политики входа не менее острое,
    // чем через смену роли.
    '/auth-settings': settingsUsers,

    // Задача 19 закрытия долга безопасности: список живых сеансов и их
    // отзыв — тот же периметр «кто и как входит в кассу», что и у
    // `/auth-settings` и `/user-management` прямо над ней. Отзыв чужого
    // сеанса не то же самое, что настройка оборудования
    // (`settings.hardware`): решение здесь — кого вообще пускать в кассу
    // дальше, а не что к ней подключено.
    '/sessions': settingsUsers,

    // Задача 2 работы «знакомство терминала с кассой» (2026-08-23): экран
    // кода привязки. Тот же периметр «кто и как входит в кассу», что и у
    // `/sessions` прямо над ней — код привязки решает, кто вообще может
    // завести себе новый терминал, а не что к кассе подключено
    // (`settings.hardware`/`settings.terminalService`). Отдельного ключа не
    // заводим: новый ключ потребовал бы отдельного шага миграции
    // ([allPermissions], «Правило на будущее»), а выигрыша не даёт.
    '/terminal-pairing': settingsUsers,

    // Правка «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 1: три маршрута без ключа и без ownerOnlyScaffold — см.
    // комментарий над [settingsTerminalService].
    '/terminal-service-settings': settingsTerminalService,
    '/log-journal': settingsLogJournal,
    '/appliance-settings': settingsAppliance,
  };

  /// Ключ права на маршрут, сопоставленный **по префиксу**, а не по
  /// равенству строк.
  ///
  /// До этой правки сравнение было литеральным (`switch (route) { '/tables'
  /// => ... }`), поэтому `/tables/:tableId`, `/orders/:orderId` и
  /// `/service-queue/:orderId` не совпадали ни с одним case и проходили
  /// сторож свободно — при том что их родительские списки (`/tables`,
  /// `/orders`, `/service-queue`) защищены тем же ключом. Совпадение по
  /// границе `/` (`route == key || route.startsWith('$key/')`), а не голый
  /// `startsWith`: голый `startsWith` дал бы ложное совпадение, будь в
  /// таблице одновременно, например, `/orders` и `/orders-archive` — среди
  /// нынешних ключей такой пары нет (проверено переборкой всех пар в тесте
  /// `permission_keys_test.dart`), но граница ловит это по конструкции, а не
  /// по факту, что сегодня повезло.
  static String? routeToPermissionKey(String route) {
    for (final entry in _routePermissions.entries) {
      if (route == entry.key || route.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  static String label(String key) {
    return switch (key) {
      navSale => 'Продажа',
      navRefund => 'Возврат',
      navShift => 'Смена',
      navHistory => 'История',
      navCatalog => 'Каталог',
      navAgent => 'Контрагенты',
      navSupply => 'Приёмка',
      navCashOperation => 'Кассовые операции',
      navSettings => 'Настройки',
      navSync => 'Синхронизация',
      navReports => 'Отчёты',
      navServiceQueue => 'Очередь заказов',
      navServiceIntake => 'Приём заказов',
      navTables => 'Столы',
      navOrders => 'Заказы',
      opEditPrice => 'Редактирование цены',
      opSellDiscount => 'Продажа со скидкой',
      opSellDebt => 'Продажа в долг',
      opCashInOut => 'Внесение / изъятие',
      opCancelPayment => 'Отмена оплаты',
      opDeferSale => 'Отложенная продажа',
      opRefund => 'Возврат товара',
      opRefundWithoutReceipt => 'Возврат без чека',
      settingsUsers => 'Пользователи',
      settingsAccounts => 'Счета оплаты',
      settingsPrinter => 'Принтер',
      settingsFiscal => 'Фискализация',
      settingsHardware => 'Оборудование',
      settingsRestaurant => 'Ресторан',
      settingsTransport => 'Транспорт',
      settingsTelegram => 'Telegram',
      settingsTerminalService => 'Браузерные терминалы',
      settingsLogJournal => 'Журнал работы',
      settingsAppliance => 'Система (TelePOS OS)',
      _ => key,
    };
  }

  static String groupLabel(String groupKey) {
    return switch (groupKey) {
      'navigation' => 'Навигация',
      'operations' => 'Операции',
      'settings' => 'Настройки',
      _ => groupKey,
    };
  }
}
