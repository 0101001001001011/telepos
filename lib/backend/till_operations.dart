/// Единственное место, где имя операции провода связывается с работой кассы.
///
/// # Почему это здесь, а не в `TillWire`
///
/// `lib/data/transport/till_wire.dart` не знает ни базы, ни репозиториев, ни
/// железа — он умеет разобрать кадр и написать ответ в тот поток, из которого
/// пришёл вопрос. Зависимости, которые нужны обработчикам, уже собраны здесь,
/// в `lib/backend/`; собирать их второй раз означало бы завести вторую кассу
/// внутри той же.
///
/// # Единственная реализация, а не «главная из двух»
///
/// До 2026-08-05 рядом жили четырнадцать маршрутов `/api/*`
/// (`setup_routes.dart`, `terminal_routes.dart`), и обработчики ниже делили с
/// ними и репозитории, и вспомогательные функции — [readSetupState],
/// [findBackup], — чтобы две реализации не разошлись. Маршруты сняты: их
/// недостижимость доказана поимённо (ни одного клиента ни в Dart, ни в
/// скриптах, ни в CI), и делить теперь не с кем. Вспомогательные функции
/// остались — их зовёт этот же файл.
///
/// # Имена берутся из `TillOps`, а не набираются строкой
///
/// До 2026-08-04 согласование концов держалось на строке пути в двух местах, и
/// расхождение обнаруживалось в браузере кодом 404. Здесь имя приходит из
/// каталога операций — того самого, из которого его берёт и терминал.
///
/// # Откуда у кассы взялся источник изменений
///
/// [TillOps.setupState], [TillOps.terminalsList], [TillOps.terminalSelf] и
/// [TillOps.deviceBindings] объявлены подписками, и до 2026-08-05 их здесь не
/// было: договоры репозиториев отдавали `Future<T>`, то есть значение на момент
/// вопроса, а подписка, отдающая одно значение и закрывающаяся, была бы
/// вопросом в одежде подписки — выглядела бы работающей и не приносила бы ровно
/// того, ради чего менялся транспорт.
///
/// Источником стал `AppDatabase.tableUpdates` — сигнал, который drift подаёт
/// от самой записи. Заводить рядом свою шину событий было бы вторым
/// источником правды о том же: запись, попавшая в базу мимо шины, разошлась бы
/// с тем, что видит терминал, и разошлась бы молча.
///
/// Значение по сигналу читают **те же методы репозиториев**, которыми касса
/// отвечает на одноразовый вопрос, — `watchTables`
/// (`lib/data/database/watch_source.dart`) устроен именно так. Почему не
/// `Selectable.watch()` drift, который делает и то и другое разом, там же и
/// записано: под `testWidgets` он не отдаёт ни одного значения, и экран,
/// ждущий первого, остаётся со спиннером навсегда.
///
/// Цена названа: сигнал приходит по **таблице**, а не по строке, поэтому кадр
/// может уйти и тогда, когда по существу ничего не изменилось. Значение в нём
/// всегда верное — читает тот же метод, — и это дешевле, чем вести список
/// того, что кого касается.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/setup/setup_state_source.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/auth/terminal_session_check.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/stock/stock_changes.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/setup/setup_draft_json.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/auth_wire.dart';
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/device_wire.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/network_wire.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/data/shift/local_shift_desk.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/refund_codec.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/quick_products_codec.dart';
import 'package:telepos/domain/wire/sale_terms_codec.dart';
import 'package:telepos/domain/wire/scanner_rules_codec.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/terminal_wire.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_money.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'certificate_throttle.dart';
import 'pairing_invites.dart';

class TillOperations {
  TillOperations({
    required AppDatabase db,
    required AppBootstrap bootstrap,
    required SetupRepository setup,
    required TerminalRepository terminals,
    required DeviceBindingRepository deviceBindings,
    required AuthRepository auth,
    FirstLaunchRepository? firstLaunch,
    DeviceDiscovery? deviceDiscovery,
    DeviceCheck? deviceCheck,
    // Довесок фазы 3/4 закрытия долга — уборка неиспользуемых строк
    // `terminals` (см. [_pruneUnusedTerminals]). `null` — та же осторожная
    // деградация, что у [_deviceDiscovery]/[_deviceCheck] выше: без порта,
    // умеющего ответить «есть ли живой сеанс на этом терминале», уборка не
    // может доказать, что строка безопасна трогать, и не трогает вовсе —
    // не отказом, молча, потому что уборка не операция, которую кто-то
    // ждёт, а внутренняя гигиена. Тесты, которым эта гигиена не нужна (их
    // большинство — до этого довеска их было тринадцать), не обязаны знать
    // о новом доводе.
    TerminalSessionCheck? sessions,
    // Задача 19 закрытия долга безопасности: экран списка сеансов и его
    // отзыв. Опционально тем же приёмом, что и [_deviceDiscovery]/
    // [_deviceCheck]/[_firstLaunch] выше — на настоящей кассе всегда
    // приходит (`main.dart` передаёт тот же `SessionRegistry`, что и
    // `sessions`/`auth` парой строк выше), но тесты, которым эти две
    // операции не нужны, не обязаны знать о новом доводе.
    SessionAdmin? sessionAdmin,
    // Задача 6 плана «знакомство терминала с кассой» (шаг 3 спеки): довод
    // `terminals.register` — код привязки, который тратится здесь
    // (`PairingInvites.redeem`), не в сторожа (докстринг [EnrolmentAccess],
    // `wire_access.dart`). `null` — **не** та же деградация, что у
    // [_deviceDiscovery]/[_sessions]/[_sessionAdmin] выше (там отсутствие
    // порта отключает одну необязательную деталь, а сама операция либо
    // отвечает по существу иначе, либо не про безопасность). Здесь
    // отсутствие означает, что заводить терминалы **некому доказать право**
    // — то же самое «отказ вместо тихого прохода», которым уже отвечают
    // [_requireDiscovery]/[_requireSessionAdmin] на отсутствующий порт, и то
    // же имя типа отказа (`WireRefusal`), но без него операция не выполняет
    // ничего и не деградирует до «работает иначе» — заведение терминала без
    // способа проверить код было бы ровно той дырой, которую задача 6
    // закрывает. `ApiServer` передаёт сюда тот же экземпляр, что и
    // `/ca.crt` (`api_server.dart`, `required this.invites`) — вторых
    // списков кодов в процессе нет.
    PairingInvites? invites,
    // Задача «сетевые настройки по проводу» (спека 2026-08-24): `null` —
    // та же деградация, что у [_deviceDiscovery]/[_deviceCheck] выше, но по
    // другому доводу — не отсутствие драйверов, а отсутствие демона
    // `telepos-sysd` (обычная Windows-касса). Операции отказывают названной
    // причиной (`_requireNetwork`), а не падают и не выдумывают результат.
    NetworkRepository? network,
    // Задача 10 плана «Продажа с браузерного терминала»: касса исполняет
    // команды корзины, пришедшие по проводу. `null` — та же деградация, что
    // у [network] выше: процесс, который не собрал реализацию продажи
    // (`bin/telepos_backend.dart` — там нет DI вовсе, а `LocalCartService`
    // требует шесть юзкейсов), отказывает названной причиной
    // (`_requireCart`), а не падает и не отдаёт пустую корзину. Пустая
    // корзина здесь была бы худшим из возможных ответов: она неотличима от
    // честного «чек пуст», и терминал набирал бы товар в никуда.
    CartService? cart,
    // Задача 44: условия правки строки (`sale.editTerms`). `null` — та же
    // деградация и тот же код, что у [cart]: процесс, не собравший продажу,
    // отказывает `no_sale_module` (`_requireEditTerms`), а не выдумывает
    // предел «сто процентов».
    SaleEditTermsReader? editTerms,
    // Задача 45: быстрые товары и правила сканера для браузерного терминала.
    // `null` — та же деградация и тот же код `no_sale_module`, что у
    // [editTerms]: процесс, не собравший продажу, отказывает названной
    // причиной, а не отдаёт пустую сетку или зашитые правила.
    QuickProductCatalog? quickProducts,
    // **Пишущий** договор, а не читающий — пункт 11 ревизии 2026-09-19.
    // Разделение `ScannerRulesReader`/`ScannerRulesRepository` заведено
    // ради того, кто правила **применяет** (`BarcodeScannerMixin`): ему
    // запись не нужна. Касса — другой случай: она единственная, кто эти
    // правила хранит, и с появлением `scanner.saveRules` обязана уметь их
    // записать. Читающего довода здесь больше не бывает: `null` означает
    // «продажа в этом процессе не собрана», а не «правила только для
    // чтения».
    ScannerRulesRepository? scannerRules,
    // Пункт 11 ревизии 2026-09-19: «партия просрочена?». `null` — та же
    // деградация и тот же код `no_sale_module`, что у [quickProducts]:
    // процесс без склада отказывает названной причиной, а не отвечает
    // «не просрочено» — выдуманное «годен» хуже молчания, оно учит
    // кассира верить снекбару, которого не будет.
    ExpiryWarningReader? expiryWarning,
    // Пункт 12 ревизии 2026-09-19: «остатки кассы изменились». `null` —
    // подписка отказывает названной причиной, а не отдаёт вечную тишину:
    // подписка, которая никогда ничего не скажет, неотличима на вкладке от
    // кассы, где остаток не двигали, и кассир доверял бы старой цифре.
    StockChanges? stockChanges,
    // Задача 14 плана «Продажа с браузерного терминала»: пять денежных
    // операций оплаты. `null` — **не** та же деградация, что у
    // [deviceDiscovery]/[network] выше: там отсутствие порта отключает
    // деталь, а операция всё равно отвечает по существу. Здесь отсутствие
    // означает, что принять деньги нечем вовсе, и отказ обязан быть
    // названным (`payments_unavailable`, `_requirePayments`). Так стоит
    // голый процесс `bin/telepos_backend.dart`: он не строит ни подготовку
    // чека, ни `SaleUseCase`, а изображать приём денег без них — худшее из
    // возможного.
    PaymentService? payments,
    // Выпуск подарочных сертификатов — задача 21. `null` той же
    // деградацией, что и [payments]: голый процесс
    // `bin/telepos_backend.dart` контейнера зависимостей не поднимает, и
    // изображать выпуск обязательств без него — худшее из возможного.
    // Операция отказывает названной причиной (`_requireCertificates`).
    CertificateIssuer? certificates,
    // Повтор печати слипа — решение заказчика 2026-09-18. Та же деградация и
    // тот же довод, что у [certificates] строкой выше: голый процесс
    // `bin/telepos_backend.dart` не поднимает ни очереди печати, ни базы
    // сертификатов. Операция отказывает названной причиной
    // (`_requireCertificateSlips`), а не отвечает «отправлено» в пустоту:
    // покупатель в этом случае стоит у прилавка и ждёт бумажку, которой
    // никто не печатал.
    CertificateSlipReprinter? certificateSlips,
    // Приём аванса покупателя — требование заказчика 2026-09-18. Та же
    // деградация и тот же довод, что у [certificates] строкой выше: голый
    // процесс `bin/telepos_backend.dart` контейнера зависимостей не
    // поднимает, а отвечать «принято» без записи денег — худшее из
    // возможного. Операция отказывает названной причиной
    // (`_requirePrepaymentIntake`).
    PrepaymentIntakeService? prepaymentIntake,
    // Выдача аванса покупателя — решение заказчика 2026-09-18. Та же
    // деградация и тот же довод, что у [prepaymentIntake] строкой выше, и
    // цена «изобразить» здесь выше: ответить «выдано» без записи значит
    // сказать кассиру, что деньги ушли покупателю, которому их никто не
    // отдавал. Операция отказывает названной причиной
    // (`_requirePrepaymentRefund`).
    PrepaymentRefundService? prepaymentRefund,
    // Задача 19 плана «Продажа с браузерного терминала»: шесть операций
    // возврата. `null` — та же деградация, что у [_network] выше, и по
    // сходному доводу: голый процесс Dart (`bin/telepos_backend.dart`) не
    // поднимает контейнер зависимостей вовсе, а `LocalRefundService`
    // собирается из трёх юзкейсов, которые живут только в нём. Операции
    // отказывают названной причиной (`_requireRefund`), а не отвечают
    // пустым черновиком: «возврат этой кассой по проводу не проводится» и
    // «черновика нет» — разные вещи, и второе есть законный снимок, который
    // терминал показал бы как рабочее состояние.
    RefundService? refund,
    // Диагностика оборудования с планшета — пункт «Достижимость с
    // браузерного терминала» плана 2026-09-19. `null` — та же деградация,
    // что у [refund] выше, и по тому же доводу: голый процесс
    // `bin/telepos_backend.dart` не поднимает контейнера зависимостей, а
    // `LocalHardwareDiagnostics` собирается из очереди печати, службы
    // печати, базы и очереди фискализации — их там нет ни одной.
    //
    // Отказ **названный** (`_requireDiagnostics`), а не пустой список, и это
    // существенно именно здесь: пустой список на экране диагностики читается
    // как «касса ничего не отправляла», и наладчик пошёл бы искать беду в
    // принтере, которого никто не спрашивал.
    //
    // Отдельным доводом, а не снятым с `PaymentService`, как шаблон чека и
    // настройка QR: там порт приходится брать с раскладки оплаты, потому что
    // правка шаблона обязана сбросить кэш **того самого** экземпляра службы
    // печати, который напечатает следующий чек. Здесь кэша нет — диагностика
    // только читает, — и связывать её с оплатой было бы копированием приёма
    // без его довода.
    HardwareDiagnosticsRepository? diagnostics,
    // Замок перебора сертификатов (2026-09-13). **Не `null`-деградация**, как
    // у соседей выше: отсутствие замка не отключает деталь, а открывает
    // перебор, поэтому довод — только чтобы пробы подставили свои величины и
    // часы; без него касса заводит замок с величинами по умолчанию сама.
    CertificateThrottle? certificateThrottle,
    Duration terminalIdleGrace = const Duration(minutes: 5),
    // Круг правки 2 задачи 10: срок спасения осиротевшего чека — довод, а не
    // константа, ровно по той же причине, что и [terminalIdleGrace] выше:
    // проба, которая ждала бы настоящие пять секунд, мерила бы длину срока, а
    // не то, что он вообще есть.
    Duration rescueDeadline = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _db = db,
       _bootstrap = bootstrap,
       _setup = setup,
       _terminals = terminals,
       _deviceBindings = deviceBindings,
       _auth = auth,
       _firstLaunch = firstLaunch,
       _deviceDiscovery = deviceDiscovery,
       _deviceCheck = deviceCheck,
       _sessions = sessions,
       _sessionAdmin = sessionAdmin,
       _invites = invites,
       _network = network,
       _cart = cart,
       _editTerms = editTerms,
       _quickProducts = quickProducts,
       _scannerRules = scannerRules,
       _expiryWarning = expiryWarning,
       _stockChanges = stockChanges,
       _payments = payments,
       _certificates = certificates,
       _certificateSlips = certificateSlips,
       _prepaymentIntake = prepaymentIntake,
       _prepaymentRefund = prepaymentRefund,
       _refund = refund,
       _diagnostics = diagnostics,
       _certificateThrottle =
           certificateThrottle ?? CertificateThrottle(clock: clock),
       _terminalIdleGrace = terminalIdleGrace,
       _rescueDeadline = rescueDeadline,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AppBootstrap _bootstrap;
  final SetupRepository _setup;
  final TerminalRepository _terminals;
  final DeviceBindingRepository _deviceBindings;

  /// Единственная реализация проверки PIN, которую зовёт эта касса — вся
  /// логика входа живёт в ней (`LocalAuthRepository`), а обработчики ниже
  /// только переводят кадр в довод и исход в кадр.
  final AuthRepository _auth;

  /// Отсутствует на установке без транспорта Telegram — это офлайновое
  /// развёртывание. Операции, которым он нужен, отказывают названной причиной,
  /// а не делают вид, что копий нет.
  final FirstLaunchRepository? _firstLaunch;

  /// Отсутствуют там, где железа нет вовсе: голый Dart-процесс
  /// (`bin/telepos_backend.dart`) не строит ни одного драйвера. Операция
  /// отказывает названной причиной, а не выдумывает пустой результат поиска —
  /// «ничего не нашлось» и «искать было нечем» для оператора разные вещи.
  final DeviceDiscovery? _deviceDiscovery;
  final DeviceCheck? _deviceCheck;

  /// `null` — этот процесс не завёл ни одной реализации (голый Dart,
  /// `bin/telepos_backend.dart`), не то же самое, что «демон недоступен»:
  /// демон, недостижимый на настоящей кассе, — это исключение уже внутри
  /// ненулевого `NetworkRepositoryLocal` (см. докстринг [NetworkRepository]),
  /// которое просто не ловится здесь и доезжает как `handler_failed`. Оба
  /// случая заканчиваются отказом, а не пустотой — см. докстринг довода
  /// конструктора выше и `_requireNetwork`.
  final NetworkRepository? _network;

  /// Корзина чека — тот же контракт и та же кассовая реализация, что стоит
  /// под экраном продажи на десктопе (`service_locator.dart`,
  /// `LocalCartService`), а не вторая рядом.
  ///
  /// Это существенно, а не гигиена: защита от повтора живёт **в базе**
  /// (`Sales.lastCommandKey`, одна колонка на чек — докстринг
  /// [CartService]), а не в памяти реализации, так что два экземпляра
  /// поверх одной базы не разошлись бы в ключах повтора. Разошлись бы они в
  /// другом — в подписках: `watchTables` заводит свой поток на экземпляр, и
  /// вторая реализация означала бы вторую цепочку уведомлений там, где
  /// экран кассы и браузерный терминал обязаны видеть **одну** корзину.
  ///
  /// `null` — см. докстринг довода конструктора.
  final CartService? _cart;

  /// Условия правки строки — задача 44. `null` — см. довод конструктора и
  /// [_requireEditTerms].
  final SaleEditTermsReader? _editTerms;

  final QuickProductCatalog? _quickProducts;

  final ScannerRulesRepository? _scannerRules;

  final ExpiryWarningReader? _expiryWarning;

  final StockChanges? _stockChanges;

  /// Оплата чека — задача 14. `null` — приём денег по проводу недоступен на
  /// этой кассе; см. довод конструктора и [_requirePayments].
  final PaymentService? _payments;

  /// Выпуск подарочных сертификатов — задача 21. `null` — эта касса
  /// сертификатов не выпускает; см. [_requireCertificates].
  final CertificateIssuer? _certificates;

  /// Диагностика оборудования — план 2026-09-19. `null` — эта касса
  /// диагностики не отдаёт; см. довод конструктора и [_requireDiagnostics].
  final HardwareDiagnosticsRepository? _diagnostics;

  /// Приём аванса покупателя — требование заказчика 2026-09-18.
  ///
  /// **Это тот же самый `CustomerPaymentUseCase`, что стоит под кассовым
  /// диалогом**, а не вторая реализация рядом: контракт
  /// [PrepaymentIntakeService] он наследует именно затем, чтобы `main.dart`
  /// отдал сюда уже зарегистрированный синглтон. Вторая копия развела бы
  /// **путь к деньгам**, а не только состояние: приём аванса пишет три
  /// строки — счёт покупателя, счёт кассы и проводку — и второй код,
  /// делающий то же самое, расходится с первым на первой же правке.
  ///
  /// `null` — эта касса приёма аванса по проводу не проводит; см. довод
  /// конструктора и [_requirePrepaymentIntake].
  final CertificateSlipReprinter? _certificateSlips;
  final PrepaymentIntakeService? _prepaymentIntake;
  final PrepaymentRefundService? _prepaymentRefund;

  /// Кассовая половина возврата — задача 19. `null` там, где её не собрали
  /// (голый Dart-процесс без контейнера зависимостей); шесть операций
  /// возврата тогда отказывают названной причиной через [_requireRefund], а
  /// не отвечают пустым черновиком.
  final RefundService? _refund;

  /// Замок перебора номеров и ПИНов сертификатов — на `pay.certificate` и
  /// на `pay.complete` с сертификатами. Один на кассу, как и сама
  /// `TillOperations`: ключ номера обязан быть общим для всех сеансов.
  final CertificateThrottle _certificateThrottle;

  AppInitStatus? _bootResult;

  /// Какая QUIC-сессия какой терминал завела — пункт 2 фазы 3/4 закрытия
  /// долга.
  ///
  /// До этой правки `auth.login` брал `terminalId` из тела кадра как есть и
  /// проверял о нём только одно: что такая строка существует
  /// (`terminals.list()`). Кассир с собственным действительным PIN мог
  /// назваться **чужим** терминалом — список видно через `terminals.list`
  /// любому сеансу — и получить `AuthSession.terminalId`, за которым его
  /// вкладка не сидит: пробный чек и денежный ящик открывались бы ровно как
  /// до задачи 10.
  ///
  /// Заполняется двумя обработчиками, и обоим сессия обязана **что-то
  /// предъявить**: `terminals.register` (код привязки) и `terminals.resume`
  /// (секрет уже заведённого места). Читается `auth.login`: терминал берётся
  /// из того, что **эта же QUIC-сессия** сама доказала.
  ///
  /// **`terminals.selfEnsure` сюда больше не пишет — круг правки 4 задачи
  /// 19.** Он открыт (ни кода, ни секрета) и отдаёт строку самой кассы, так
  /// что пока он писал, на этой строке оказывались вдвоём и делили черновик
  /// возврата: остаток +10, касса −5000 кадрами провода. Разбор — у самого
  /// обработчика.
  ///
  /// Не переживает закрытие сессии — [forgetSession] чистит запись, тот же
  /// приём, что `SessionRegistry._forget()`/`LoginThrottle._forget()`: без
  /// уборки карта росла бы без предела на весь срок жизни кассы.
  ///
  /// **Ключ — не сырой `sessionId`.** До правки 3 волны закрытия долга
  /// безопасности (2026-08-22) им был он, а `TillOperations` — один объект
  /// на всё развёртывание (см. `main.dart`), в то время как `rk_quic`
  /// заводит `sessionId` независимым счётчиком **на каждый листенер**
  /// (`packages/rk_quic/rust/src/transport.rs`, `next_session` — счётчик
  /// внутри функции подъёма, не статика процесса). В `loopback` (два
  /// листенера — IPv4- и IPv6-петля) `sessionId=1` существовал на обоих
  /// одновременно, и запись одного слушателя перезаписывала запись другого:
  /// та самая подмена терминала, которую задача 10 закрывала на уровне
  /// сторожа, вернулась бы с другой стороны.
  ///
  /// Решено не здесь и не в `rk_quic`, а на стороне кассы, в `TillWire`
  /// (`till_wire.dart`, `TillWire.listenerId`/`_sessionKey`): то, что
  /// приходит сюда вторым доводом [WireHandler] и первым доводом
  /// [forgetSession], уже уникально на кассу — `loopback`-коллизии нет
  /// структурно, а не потому, что она маловероятна. `everywhere` (настоящее
  /// развёртывание, один сокет, один `TillWire`) не меняется вовсе:
  /// `listenerId` там 0, и составной ключ равен сырому.
  final Map<int, int> _sessionTerminals = {};

  /// Порт «есть ли живой сеанс на этом терминале» — довесок фазы 3/4
  /// закрытия долга, часть Б. `null` там, где его не завели (см. докстринг
  /// конструктора): уборка тогда не работает вовсе, а не работает неверно.
  final TerminalSessionCheck? _sessions;

  /// Порт «список живых сеансов и их отзыв» — задача 19 закрытия долга
  /// безопасности. `null` там, где его не завели, см. докстринг
  /// конструктора; операции [TillOps.authSessions]/[TillOps.authSessionRevoke]
  /// отказывают названной причиной через [_requireSessionAdmin], а не молчат.
  final SessionAdmin? _sessionAdmin;

  /// Список выданных кодов привязки — довод `terminals.register` (задача 6
  /// плана «знакомство терминала с кассой», шаг 3 спеки). `null` там, где не
  /// заведён — регистрация тогда отказывает названной причиной на любой
  /// код, а не пропускает: см. докстринг конструктора про то, чем это
  /// отличается от прочих опциональных портов выше.
  final PairingInvites? _invites;

  /// Сколько терминал обязан простоять без хозяина, прежде чем
  /// [_pruneUnusedTerminals] сочтёт его безопасным убрать — см. докстринг
  /// там же.
  final Duration _terminalIdleGrace;

  final DateTime Function() _clock;

  /// Когда [_pruneUnusedTerminals] в последний раз видела, что у терминала
  /// **нет** сессии-хозяина — то есть с этого момента он простаивает.
  ///
  /// Заполняется в **четырёх** местах, а не в двух, как говорила эта строка до
  /// круга правки 2 задачи 10 плана «Продажа с браузерного терминала»:
  /// [forgetSession] (QUIC-сессия, владевшая терминалом, закрылась) и три
  /// писателя [_sessionTerminals] — `terminals.register`, `terminals.resume`,
  /// `terminals.selfEnsure`. У трёх последних причина одна: та же QUIC-сессия
  /// сменила себе рабочее место, не закрывшись, — прежнее осиротело ровно тем
  /// же способом, просто без события `SessionClosed`. `selfEnsure` был найден
  /// последним и дольше всех считался исключением: он не заводит новой
  /// **строки** терминала, но место сессии меняет так же, как соседки.
  ///
  /// Не переживает перезапуск кассы — тем же решением, что и
  /// [_sessionTerminals], которую эта карта зеркалит: `sessionId`, с которым
  /// связана запись, сам не переживает перезапуск (`rk_quic` заводит его
  /// заново с нуля на каждый листенер), так что хранить это где-то ещё, кроме
  /// памяти процесса, было бы враньём о точности, которой нет. Касса,
  /// перезапущенная посреди дня, честно теряет память о том, что терминал
  /// давно осиротел, — как теряет и все живые сеансы
  /// (`SessionRegistry`, «это свойство»).
  final Map<int, DateTime> _terminalIdleSince = {};

  /// Забывает, какой терминал завела эта сессия — зовётся `TillWire` на
  /// `SessionClosed` (`onSessionClosed`, `till_wire.dart`).
  ///
  /// Отмечает терминал осиротевшим в [_terminalIdleSince] — единственный
  /// путь, которым карта узнаёт про закрытие QUIC-сессии; сама она наружу
  /// об этом не сигналит. `terminalSelfEnsure` [_sessionTerminals] не пишет
  /// вовсе (круг правки 4, разбор у самого обработчика) и сюда не заходит:
  /// он не заводит новой строки (`self()` идемпотентен), значит и
  /// осиротевшего терминала после него не остаётся, а `isSelf`-терминал,
  /// на который он указывает,
  /// [_pruneUnusedTerminals] и так не тронет ни при каких условиях.
  void forgetSession(int sessionId) {
    final terminalId = _sessionTerminals.remove(sessionId);
    if (terminalId != null) _terminalIdleSince[terminalId] = _clock();
  }

  /// Терминал, который эта же QUIC-сессия сама доказала — кодом привязки
  /// (`terminals.register`) или секретом (`terminals.resume`); задача 21
  /// закрытия долга безопасности.
  ///
  /// **Четвёртый читатель [_sessionTerminals], и в круге правки 4 я его при
  /// обходе пропустил** — довод «читателей три» был неполон: у этого геттера
  /// два боевых потребителя, сам сторож провода
  /// (`WireGuard._boundTerminalId`, `main.dart`) и журнал событий
  /// безопасности (`buildWireDeniedJournalHandler`). Рез `selfEnsure`
  /// корректен и для них — журнал раньше приписывал браузерной вкладке
  /// строку самой кассы, то есть врал точнее, а теперь падает на
  /// `body.terminalId`, — но перебор, которым рез обосновывался, читателя
  /// не назвал.
  ///
  /// Читающий двойник [_sessionTerminals], а не второй источник: тот же
  /// самый источник, которым уже пользуется `auth.login` (`askHandlers`
  /// выше). Заведён затем, что `TillWire.onDenied`
  /// (`lib/data/transport/till_wire.dart`) видит отказ сторожа раньше, чем
  /// дело доходит до `askHandlers`, и без сеанса (`WireDenied.unauthorized`)
  /// у него нет другого способа узнать, какой терминал прислал отказанный
  /// запрос — см. `buildWireDeniedJournalHandler`,
  /// `lib/backend/security_journal.dart`.
  int? terminalForSessionKey(int sessionKey) => _sessionTerminals[sessionKey];

  /// Имена **необязательных** сотрудников, которых этой кассе не дали, — то
  /// есть перечень того, чем она отличается от полной.
  ///
  /// # Зачем это существует
  ///
  /// Каждый довод-`null` в конструкторе выше — законная деградация: операция
  /// отказывает названной причиной вместо того, чтобы падать или выдумывать
  /// результат. Но у этой честности есть цена, измеренная дважды и дорого:
  /// **касса, собранная не полностью, выглядит исправной**. Отказ
  /// `no_refund_service` неотличим на вид от рабочего ответа «эта касса так
  /// не умеет», и найти его можно только тем, что кто-то позовёт операцию
  /// и прочитает причину.
  ///
  /// Так уже случалось на стенде живой проверки
  /// (`test/manual/wt_stand.dart`) **трижды**: 2026-08-22 он не отдавал
  /// `SessionAdmin`, и живая проверка отзыва сеансов мерила отказ сборки, а
  /// не продукт; 2026-09-06 обнаружилось, что не отдаёт ни `refund`, ни
  /// `network`, ни `terminalSessions` — то есть шесть операций возврата на
  /// стенде не существовали вовсе, молча.
  ///
  /// Поэтому список **отсутствующего** — наблюдаемая величина, а не то, что
  /// вычитают глазами из двух файлов. Тот, кто собирает кассу, обязан
  /// сравнить её с тем, что собирался собрать, и упасть при подъёме, если
  /// разошлось: см. `_assertStandIsWholeTill` в стенде.
  ///
  /// # Почему здесь, а не списком имён в стенде
  ///
  /// Единственное место, которое знает, чего у кассы нет, — сама касса.
  /// Список, живущий у вызывающего, разошёлся бы с полями молча — ровно та
  /// болезнь, которую он призван лечить.
  Set<String> get absentCollaborators => {
    if (_firstLaunch == null) 'firstLaunch',
    if (_deviceDiscovery == null) 'deviceDiscovery',
    if (_deviceCheck == null) 'deviceCheck',
    if (_sessions == null) 'terminalSessions',
    if (_sessionAdmin == null) 'sessionAdmin',
    if (_invites == null) 'invites',
    if (_network == null) 'network',
    if (_refund == null) 'refund',
    // Диагностика оборудования — план 2026-09-19. Вписана сюда **той же
    // работой**, что и сам довод: список, отставший на один довод, делает
    // обрезанный стенд неотличимым от целого, а операции при этом вежливо
    // отказывают — ровно та ловушка, ради которой этот список и заведён
    // (докстринг `stand_matches_till_test.dart`).
    if (_diagnostics == null) 'diagnostics',
  };

  /// Чем закончился подъём этой кассы.
  ///
  /// Считается один раз и запоминается: перезагрузка страницы не имеет права
  /// заново прогонять подъём кассы, которая уже открыта. Память живёт здесь, а
  /// не у транспорта, и это пережило снятие HTTP: пока транспорта было два,
  /// памятка на каждый из них подняла бы кассу дважды на машине, где есть оба.
  Future<AppInitStatus> boot() async =>
      _bootResult ??= await _bootstrap.start(onProgress: (_, _) {});

  /// Одноразовые вопросы, включая `auth.login` и `auth.logout` — их логика
  /// целиком в [_auth] (`LocalAuthRepository`), здесь только перевод кадра.
  ///
  /// Карта строится один раз: обработчики держат состояние (память о подъёме),
  /// и пересобирать их на каждое обращение значило бы раздать разным читателям
  /// разные замыкания над одним и тем же объектом — работает, но выглядит как
  /// две реализации, а их здесь быть не должно.
  late final Map<String, WireHandler> askHandlers = {
    TillOps.startupBoot.name: (_, [_, _]) async => {
      'status': (await boot()).name,
    },

    TillOps.setupFirstLaunch.name: (_, [_, _]) async => {
      'result': (await _requireFirstLaunch().determineResult()).name,
    },

    TillOps.setupBackups.name: (_, [_, _]) async => {
      'backups': (await _requireFirstLaunch().findAvailableBackups())
          .map((backup) => backup.toJson())
          .toList(),
    },

    TillOps.setupNewPos.name: (_, [_, _]) async => {
      'posKey': await _requireFirstLaunch().startNewPos(),
    },

    // Весь черновик едет одним обменом, потому что фиксация — одна
    // транзакция: касса со счетами и без пользователей не может ни принять
    // деньги, ни быть донастроенной.
    TillOps.setupComplete.name: (body, [_, _]) async {
      await _setup.completeSetup(setupDraftFromJson(body));
      return {'ok': true};
    },

    TillOps.deviceBindingSave.name: (body, [_, _]) async {
      final terminalId = _requireInt(body, 'terminalId');
      final raw = body['binding'];
      if (raw is! Map<String, dynamic>) {
        // Задача 2б, отложенная в задачу 10: `WireRefusal`, а не
        // `ArgumentError` — тот же перевод, что и у `_requireInt` ниже и у
        // `terminalRename`/`terminalRegister` выше. `ArgumentError` доезжал
        // бы до терминала только именем типа (`safeErrorText`,
        // `lib/core/errors/safe_error_text.dart`) — «ожидался объект
        // привязки» до человека не доходило вовсе.
        throw const WireRefusal('bad_request', 'ожидался объект привязки');
      }
      // Тот же разбор, которым пользуется читающая сторона: `save` заменяет
      // привязку того же класса, а не добавляет вторую строку.
      await _deviceBindings.save(
        terminalId,
        deviceBindingFromWireJson(raw, terminalId: terminalId),
      );
      return {'ok': true};
    },

    TillOps.terminalRename.name: (body, [_, _]) async {
      final name = (body['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        throw const WireRefusal('bad_request', 'имя обязательно');
      }
      await _terminals.rename(_requireInt(body, 'terminalId'), name);
      return {'ok': true};
    },

    // Задача 15: набор видов оплаты — свойство рабочего места. Обработчик
    // не содержит ни одной строки решения о деньгах: он переводит кадр в
    // довод. Сам запрет действует не здесь, а в `LocalPaymentService`, —
    // потому что там он один на оба пути, и десктопная касса, зовущая
    // контракт напрямую, минуя провод, подчиняется ему тоже.
    // Третий довод `_` дописан при слиянии: `WireHandler` получил
    // `AuthSession? session` на цепочке продажи, а эта задача
    // отпочковалась раньше. Расхождение молчаливое — конфликта здесь не
    // было, сборка легла у анализатора.
    TillOps.terminalSetPaymentTypes.name: (body, [_, _]) async {
      final terminalId = _requireInt(body, 'terminalId');
      // **Поле обязано быть, и это не придирка** (находка прохода
      // `anti-gaps`). На чтении терминала отсутствующий набор — законное
      // «пусто», то есть «все виды»: касса старше задачи 15 его не шлёт, и
      // читать это как «всё разрешено» правильно. На **записи** то же
      // умолчание значило бы, что кадр, забывший поле, молча снимает с
      // рабочего места весь запрет — расширение прав из-за опечатки
      // клиента, и притом с ответом «ok». Снять ограничение можно, но
      // только назвав это вслух: пустым списком.
      final raw = body['allowedPaymentTypes'];
      if (raw is! List) {
        throw const WireRefusal(
          'bad_request',
          'allowedPaymentTypes обязателен списком имён; пустой список '
              'означает «все виды»',
        );
      }
      await _terminals.setAllowedPaymentTypes(
        terminalId,
        // Незнакомое имя вида — отказ разбора, а не выброшенное поле: см.
        // `paymentTypesFromNames`. Разбирается тем же читателем, что и
        // остальной провод, а не вторым, написанным здесь.
        paymentTypesFromWire(raw, terminalId: terminalId),
      );
      return {'ok': true};
    },

    // Единственная сессия, читающая `sessionId` затем, чтобы **запомнить**
    // терминал, а не только прочитать (`terminalSelfEnsure` ниже — второй) —
    // см. докстринг [_sessionTerminals].
    TillOps.terminalRegister.name: (body, [sessionId, _]) async {
      // Пустое имя отклоняет и сам репозиторий; проверка здесь — чтобы отказ
      // назывался «имя обязательно», а не приходил из глубины drift.
      final name = (body['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        throw const WireRefusal('bad_request', 'имя обязательно');
      }
      // Задача 6 плана «знакомство терминала с кассой» (шаг 3 спеки): гейт —
      // здесь, а не в сторожа (докстринг [EnrolmentAccess], `wire_access
      // .dart`, объясняет почему). До проверки уборки ниже: непроверенный
      // запрос не имеет права трогать базу, даже уборкой чужих строк.
      //
      // `_invites == null` — регистрация недоступна вовсе (докстринг поля
      // [_invites]), не то же самое, что «код неверный», но терминалу это
      // не сообщается отдельным кодом: с его стороны нечем отличить кассу
      // без настроенного привязчика от кассы, которой не предъявили код —
      // оба раза единственное действие одно и то же: получить код на кассе.
      final code = body['code'] as String?;
      if (_invites == null || !_invites.redeem(code)) {
        throw const WireRefusal(
          'pairing_code_invalid',
          'нужен действующий код привязки — заведите его на кассе '
              '(«Привязка терминала») и повторите',
        );
      }
      // Довесок фазы 3/4 закрытия долга, часть Б: то самое место, где строки
      // и копятся (F5 вкладки заводит новый терминал на каждую перезагрузку,
      // пункт 6 фазы 3/4 не даёт переиспользовать старый) — здесь же их и
      // убирают, тем же приёмом, что `SessionRegistry.mint()`/`LoginThrottle`
      // зовут свою уборку первой строкой операции, а не по будильнику. До
      // проверки потолка [_terminals.register] — свежее место обязано
      // засчитаться до того, как потолок откажет новой регистрации.
      await _pruneUnusedTerminals();
      final enrollment = await _terminals.register(name: name);
      final terminal = enrollment.terminal;
      if (sessionId != null) {
        // Та же сессия уже сидела на другом терминале и заводит замену, не
        // закрывшись, — например, `login_controller.dart` после
        // `UnknownTerminalException` сбрасывает кэш и зовёт `register` снова
        // на той же QUIC-сессии. Прежний терминал осиротел прямо сейчас, и
        // без этой строки [_terminalIdleSince] узнала бы об этом только на
        // `SessionClosed`, если он вообще случится раньше, чем вкладку
        // закроют совсем.
        final previous = _sessionTerminals[sessionId];
        if (previous != null && previous != terminal.id) {
          _terminalIdleSince[previous] = _clock();
          // Круг правки 1 задачи 10: чек прежнего места иначе стал бы
          // невидимым — см. [_rescueOrphanedCart].
          await _rescueOrphanedCart(previous);
        }
        _sessionTerminals[sessionId] = terminal.id;
      }
      // Секрет едет в ответе значением — единственный обмен на всём проводе,
      // которому это разрешено (докстринг `terminalEnrollmentToWireJson`,
      // `terminal_wire.dart`). Задача 4 — выдача и хранение: кто на другом
      // конце сохранит его и предъявит обратно на новой сессии — задача 5,
      // ниже (`terminalResume`).
      return terminalEnrollmentToWireJson(enrollment);
    },

    // Второй и последний писатель [_sessionTerminals] — после
    // `terminalRegister` выше (`terminalSelfEnsure` перестал им быть в круге
    // правки 4 задачи 19). Задача 5 плана «знакомство терминала с кассой»,
    // шаг 2 спеки. Вкладка, пережившая F5 или закрытие/повторное
    // открытие, предъявляет секрет, который получила от `terminalRegister`
    // единственный раз, вместо того чтобы заводить новую строку заново.
    //
    // `_terminals.resume` сама решает, свой это секрет или чужой
    // ([TerminalSecret.matches] — константное время, докстринг там), и сама
    // бросает [WireRefusal] на любой из трёх поводов (id не существует,
    // отпечатка нет, секрет не сходится) — обработчику здесь сверять уже
    // нечего, только перевести кадр в довод и исход в кадр, тем же приёмом,
    // что и у соседних обработчиков.
    //
    // Уборки (`_pruneUnusedTerminals`) здесь нет намеренно, в отличие от
    // `terminalRegister`: эта ветка не вставляет новую строку — освобождать
    // место не для чего, — а звать её означало бы рисковать убрать именно
    // тот терминал, который эта же операция сейчас возвращает к жизни (гонка
    // с [_terminalIdleSince], закрытая ниже явным `remove`, а не порядком
    // вызовов).
    TillOps.terminalResume.name: (body, [sessionId, _]) async {
      final terminalId = _requireInt(body, 'terminalId');
      final secret = body['secret'] as String? ?? '';
      final terminal = await _terminals.resume(
        terminalId: terminalId,
        secret: secret,
      );
      if (sessionId != null) {
        // Та же сессия уже сидела на другом терминале — тот же довод, что и
        // у `terminalRegister`: прежний терминал осиротел прямо сейчас, а не
        // когда (и если) эта сессия когда-нибудь закроется.
        final previous = _sessionTerminals[sessionId];
        if (previous != null && previous != terminal.id) {
          _terminalIdleSince[previous] = _clock();
          // Круг правки 1 задачи 10: чек прежнего места иначе стал бы
          // невидимым — см. [_rescueOrphanedCart].
          await _rescueOrphanedCart(previous);
        }
        _sessionTerminals[sessionId] = terminal.id;
      }
      // Терминал живой снова — если [forgetSession] прошлой QUIC-сессии уже
      // отметила его осиротевшим, эта запись обязана уйти немедленно, а не
      // ждать следующего прохода [_pruneUnusedTerminals]: без этой строки
      // терминал, возвращённый ровно сейчас, мог бы быть убран уборкой,
      // запущенной следующим `terminals.register` другой вкладки раньше, чем
      // истечёт [_terminalIdleGrace] — грубее, но той же по сути гонки,
      // которую комментарий выше называет прямо.
      _terminalIdleSince.remove(terminal.id);
      return {'terminal': terminalToWireJson(terminal)};
    },

    // Существование, каскад привязок и запрет на `isSelf` — забота
    // `TerminalRepository.delete` (тот же приём, что у `terminalRegister`
    // выше: потолок и дедупликация по имени решает репозиторий, а не
    // обработчик). `isSelf` — не то же самое, что «терминал вкладки,
    // приславшей этот кадр»: строку самой кассы вызывающая вкладка почти
    // никогда не видит, а свою собственную — видит всегда.
    //
    // Запрет «не удаляй терминал вкладки» (задача 9 закрытия долга) до
    // задачи 10 жил здесь же, обработчиком, вторым доводом `WireHandler` —
    // единственная причина, по которой тот довод вообще существовал. Задача
    // 10 забрала эту сверку в сторож (`SessionAccess.ownTerminal:
    // TerminalOwnership.different`, `till_ops.dart`) вместе с четырьмя
    // соседними дырами, которых у `terminals.delete` не было: обработчику
    // сверять больше нечего, и второй довод снят целиком
    // (`lib/data/transport/till_wire.dart`). Ниже остался только вызов
    // репозитория — `_terminals.delete` сам отказывает `isSelf`-терминалу.
    TillOps.terminalDelete.name: (body, [_, _]) async {
      await _terminals.delete(_requireInt(body, 'terminalId'));
      return {'ok': true};
    },

    // Больше не писатель [_sessionTerminals] (круг правки 4, разбор внутри).
    // Настоящему
    // десктопу это не грозит и не помогает: он не ходит по проводу вовсе
    // (`ownsData == true` зовёт `LocalTerminalRepository`/`LocalAuthRepository`
    // напрямую, в обход `TillWire` целиком) — сюда доходят только браузеры, у
    // которых `self()` отдаёт терминал самой кассы (`isSelf`), не терминал
    // сессии.
    //
    // **Запоминания здесь больше нет — круг правки 4 задачи 19**, разбор у
    // самого места реза ниже. Довод, которым оно держалось («без записи
    // `deviceCheck` тут же после `selfEnsure` на новой вкладке остался бы
    // без места»), был неверен уже тогда: `deviceCheck` берёт `terminalId`
    // **из тела**. А цена была та, что `access: OpenAccess()` работал и на
    // нечестного клиента — `selfEnsure` не спрашивает ни кода привязки, ни
    // секрета, и доводил до `auth.login` с сессией, привязанной к терминалу
    // самой кассы (`isSelf`, `pointMode: cashier` по умолчанию — самый
    // широкий режим). Теперь этот путь до входа не доходит вовсе.
    // Разобрано и оставлено открытым сознательно волной финальных правок
    // 2026-08-23 (не регрессия — до задачи 6 `register()` была открыта тем
    // же путём и короче) — полный довод и почему закрыть условием не вышло
    // эмпирически (сеанс/петля/`ownsData`) — раздел «Границы»,
    // `docs/internal/superpowers/specs/2026-08-23-terminal-enrolment-design.md`.
    TillOps.terminalSelfEnsure.name: (_, [sessionId, _]) async {
      try {
        final terminal = await _terminals.self();
        // **Привязки здесь больше нет — круг правки 4 задачи 19.**
        //
        // Она была третьим писателем [_sessionTerminals] и открывала строку
        // самой кассы (`isSelf`) любой сессии: `selfEnsure` не спрашивает ни
        // кода привязки, ни секрета. Пока запись стояла, на этой строке
        // сидели вдвоём — и черновик возврата там был общим. Проба разбора
        // круга 4, кадрами провода:
        //
        //   сессия 1: selfEnsure + вход младшего  → токен на строке кассы
        //   сессия 2: selfEnsure + вход старшего  → сеанс младшего ЖИВ
        //   сессия 2: refund.startWithoutReceipt  → черновик заведён
        //   сессия 1 (у младшего НЕТ opRefundWithoutReceipt):
        //             addProduct 10×500, complete → остаток +10, касса −5000
        //
        // Круг 3 пробовал лечить это `putIfAbsent`, круг 2 — исключением
        // `isSelf` из гашения; оба были заплатами вокруг причины. Причина —
        // сама запись, и она **не нужна ни одному живому читателю**.
        //
        // **Читателей [_sessionTerminals] четыре — поимённо, круг правки 5.**
        // Круг 4 назвал три и на этом обосновал рез; четвёртый был пропущен,
        // и довод оказался увереннее заслуженного. Полный список:
        //
        //   1. `auth.login` — берёт терминал сеанса;
        //   2. обработчики возврата (через [_cartTerminal] — общий
        //      источник места, к которому их свело слияние);
        //   3. уборка неиспользуемых терминалов ([_pruneUnusedTerminals]);
        //   4. [terminalForSessionKey] — и у него **два боевых
        //      потребителя**: сторож провода (`WireGuard._boundTerminalId`,
        //      подключён в `main.dart`) и журнал событий безопасности
        //      (`buildWireDeniedJournalHandler`, `security_journal.dart`).
        //
        // Рез корректен и для четвёртого: журнал раньше приписывал
        // браузерной вкладке строку самой кассы — то есть врал точнее, — а
        // теперь падает на `body.terminalId`.
        //
        // Операции устройств (`deviceCheck`, `deviceBindings`,
        // `deviceBindingSave`, `terminals.rename`) в список не входят: они
        // берут `terminalId` **из тела** (`_requireInt(body, 'terminalId')`),
        // а не из привязки. Довод
        // «`deviceCheck` сразу после `selfEnsure` на новой вкладке остался бы
        // без места», которым запись обосновывалась, был неверен уже тогда.
        //
        // Следствие названо прямо: вкладка, позвавшая **только**
        // `selfEnsure`, войти больше не может — `auth.login` ответит
        // `unknown_terminal`. Это и есть закрытие той дыры, которую докстринг
        // ниже описывал открытой: войти по проводу теперь можно лишь на
        // месте, которое сессия доказала кодом привязки (`register`) или
        // секретом (`resume`).
        return {'terminal': terminalToWireJson(terminal)};
      } on InstallationNotConfiguredException {
        // Значением, а не кадром отказа: «мастер ещё не проходил» — обычное
        // состояние свежей установки, и отличать его от настоящей поломки по
        // тексту ошибки пришлось бы строкой.
        return {'terminal': null};
      }
    },

    TillOps.deviceDiscovery.name: (body, [_, _]) async =>
        deviceDiscoveryResultToJson(
          await _requireDiscovery().find(_requireDeviceClass(body)),
        ),

    TillOps.deviceCheck.name: (body, [_, _]) async => deviceCheckOutcomeToJson(
      await _requireCheck().check(
        terminalId: _requireInt(body, 'terminalId'),
        deviceClass: _requireDeviceClass(body),
      ),
    ),

    // Пункт 2 фазы 3/4 закрытия долга: `terminalId` больше не берётся из
    // тела кадра — тело кассир может набрать сам, `sessionId` подделать не
    // может (его назначает `rk_quic` на своей стороне, до разбора кадра —
    // см. докстринг [WireHandler]). Берётся из [_sessionTerminals]: что эта
    // же QUIC-сессия сама завела через `terminals.register`/`terminals
    // .resume` до этого запроса. Тело всё ещё несёт `terminalId` —
    // десктопный `AuthAttempt` (`LocalAuthRepository.login`, вызывается в
    // обход провода) продолжает использовать его как раньше; здесь оно
    // читается только диагностики ради ниже, в тексте отказа.
    //
    // Без предварительной регистрации на этой сессии входа нет —
    // `unknown_terminal`, тот же код, что раньше отвечал на несуществующий
    // id. `WtAuthRepository` (`lib/web/wt_auth_repository.dart`) уже
    // переводит его в `UnknownTerminalException`, и `login_controller.dart`
    // уже на него реагирует повторной заводкой — эта ветка не заводит нового
    // клиентского пути, только делает существующий обязательным.
    TillOps.authLogin.name: (body, [sessionId, _]) async {
      final pin = body['pin'] as String? ?? '';
      final userId = body['userId'] as int?;

      final boundTerminalId = sessionId == null
          ? null
          : _sessionTerminals[sessionId];
      if (boundTerminalId == null) {
        throw WireRefusal(
          'unknown_terminal',
          'эта сессия ещё не завела терминал через terminals.register '
              '(с кодом привязки) или terminals.resume (с секретом) — тело '
              'называло terminalId=${body['terminalId']}',
        );
      }

      // Защита не от подделки (сессия уже доказала владение регистрацией),
      // а от гонки: терминал этой же сессии успели удалить
      // (`terminals.delete`) между регистрацией и входом.
      final terminals = await _terminals.list();
      if (!terminals.any((terminal) => terminal.id == boundTerminalId)) {
        throw WireRefusal(
          'unknown_terminal',
          'терминала с таким id не существует: $boundTerminalId',
        );
      }

      final outcome = await _auth.login(
        AuthAttempt(
          pin: pin,
          terminalId: boundTerminalId,
          userId: userId,
          // Правка А БЛОКЕРА закрытия долга безопасности (2026-08-22):
          // ключ справедливости для `Pbkdf2Gate` — та же QUIC-сессия,
          // которую уже проверил `boundTerminalId` выше, а не сырой
          // `userId` (его нападающий выбирает свободно — это имя жертвы, не
          // его собственное). См. докстринг `AuthAttempt.sessionKey`.
          sessionKey: sessionId,
        ),
      );
      // Задача 19, круг правки 1 (C1): за рабочее место сел человек — всё,
      // что на нём было начато до входа, начато не им. Черновик возврата
      // лежит под ключом рабочего места и только его, поэтому без этой
      // строки кассир, которому возврат без чека закрыт правом, наполнял
      // бы чужой безчековый черновик и отдавал по нему деньги: право
      // `op.refundWithoutReceipt` охраняло бы только первое нажатие.
      // Разбор, измерения и предел — докстринг [RefundService.abandon].
      //
      // **Только на состоявшемся входе.** Отвергнутый PIN за место никого
      // не посадил, и стирать по нему чужую работу значило бы дать любому,
      // кто дотянулся до кассы, способ сносить чужие черновики неверным
      // PIN-ом.
      //
      // Не `unawaited`: уборка обязана случиться **до** того, как ответ с
      // сеансом уедет вкладке, — иначе её первая же команда возврата
      // успела бы прийти раньше уборки и была бы стёрта уже после
      // применения.
      // **Предел: уборка знает только возврат.** Черновик продажи с
      // браузера (задачи 7–13) сегодня живёт в `Sales` под тем же ключом
      // рабочего места и унаследуется на пересменке ровно тем же способом,
      // каким унаследовался бы возврат без этой строки. Когда он поедет по
      // проводу, здесь обязана появиться вторая уборка — или общая,
      // объявленная списком того, что вход обнуляет.
      if (outcome is AuthSession) await _refund?.abandon(boundTerminalId);
      // Обработчик не содержит ни одной строки логики входа: он переводит
      // кадр в довод и исход в кадр. Проверка PIN живёт в одном месте на всю
      // систему — в `LocalAuthRepository`.
      return authOutcomeToWireJson(outcome);
    },

    TillOps.authLogout.name: (body, [_, _]) async {
      await _auth.logout(body['token'] as String? ?? '');
      return {'ok': true};
    },

    // Задача 19 закрытия долга безопасности: экран списка сеансов
    // (`sessions_screen.dart`) не имел вызывающего для отзыва — этот
    // обработчик и есть недостающий путь, зовёт `revokeSession` (по
    // терминалу, не по токену — см. докстринг `TillOps.authSessionRevoke`).
    // Не тот же метод, что `SessionRegistry.revokeAll()` (существовал с
    // задачи 9, ни разу не был вызван рабочим кодом, снят задачей 21) —
    // тот гасил всю кассу разом, этот — один терминал.
    TillOps.authSessionRevoke.name: (body, [_, _]) async => {
      'ok': await _requireSessionAdmin().revokeSession(
        _requireInt(body, 'terminalId'),
      ),
    },

    // Задача «сетевые настройки по проводу» (спека 2026-08-24): шесть
    // обработчиков, каждый — перевод кадра в довод и исход в кадр поверх
    // `_requireNetwork()`, без логики здесь — она вся в
    // `NetworkRepositoryLocal`/`SysdClient`.
    TillOps.networkStatus.name: (_, [_, _]) async =>
        networkStatusToWireJson(await _requireNetwork().status()),

    TillOps.networkWifiScan.name: (_, [_, _]) async => {
      'networks': (await _requireNetwork().wifiScan())
          .map(wifiNetworkToWireJson)
          .toList(),
    },

    TillOps.networkWifiConnect.name: (body, [_, _]) async {
      final ssid = (body['ssid'] as String? ?? '').trim();
      if (ssid.isEmpty) {
        throw const WireRefusal('bad_request', 'ssid обязателен');
      }
      final res = await _requireNetwork().wifiConnect(
        ssid,
        body['password'] as String?,
      );
      return {'success': res.success, 'message': res.message};
    },

    TillOps.networkWifiDisconnect.name: (_, [_, _]) async => {
      'ok': await _requireNetwork().wifiDisconnect(),
    },

    TillOps.networkEthernetStatus.name: (_, [_, _]) async =>
        await _requireNetwork().ethernetStatus(),

    TillOps.networkEthernetConfigure.name: (body, [_, _]) async {
      final iface = (body['iface'] as String? ?? '').trim();
      if (iface.isEmpty) {
        throw const WireRefusal('bad_request', 'iface обязателен');
      }
      final network = _requireNetwork();
      final mode = body['mode'] as String? ?? 'dhcp';
      final ({bool success, String mode}) res;
      if (mode == 'static') {
        final ipCidr = (body['ipCidr'] as String? ?? '').trim();
        if (ipCidr.isEmpty) {
          throw const WireRefusal(
            'bad_request',
            'ipCidr обязателен для статического режима',
          );
        }
        res = await network.ethernetConfigureStatic(
          iface,
          ipCidr: ipCidr,
          gateway: body['gateway'] as String?,
          dns: body['dns'] as String?,
        );
      } else {
        res = await network.ethernetConfigureDhcp(iface);
      }
      return {'success': res.success, 'mode': res.mode};
    },

    // ── настройка оплаты по QR (решение заказчика 2026-09-18) ────────────
    //
    // «Это не граница, а пробел — в браузере должно работать то же, что в
    // приложении». Экран настройки QR жил только на кассе; владелец с
    // планшетом вместо кассы включить оплату по QR не мог ничем.
    //
    // Здесь нет ни одной строки работы и не должно быть — тем же правилом,
    // что у приёма аванса: пишет настройку **та же стойка**, что читает её,
    // собираясь звонить провайдеру (`QrProviderSetupRepository`,
    // `_requireQrProviderSetup`). Появись здесь хоть одна проверка, которой
    // нет у кассового экрана, у настройки стало бы два свода правил.
    //
    // Рабочего места операции не читают и не называют: провайдер один на
    // кассу, а не на рабочее место. В карту продажи они поэтому не кладутся
    // — общий запрет `terminal_in_body` там про **чек**, а чека здесь нет.
    //
    // Право `settings.accounts` сторож проверил до этой строки.
    TillOps.qrProviderSettings.name: (_, [_, _]) async =>
        qrProviderViewToWireJson(await _requireQrProviderSetup().read()),

    // Ключ провайдера едет **сюда** и никогда обратно: ответ — `{'ok': true}`,
    // а снимок настройки (`qr.providerSettings`) поля ключа не имеет вовсе.
    TillOps.qrProviderSave.name: (body, [_, _]) async {
      final ask = qrProviderSaveFromWireJson(body);
      await _requireQrProviderSetup().save(
        baseUrl: ask.baseUrl,
        code: ask.code,
        patience: ask.patience,
        newApiKey: ask.newApiKey,
        clearApiKey: ask.clearApiKey,
      );
      return const {'ok': true};
    },

    TillOps.qrProviderClear.name: (_, [_, _]) async {
      await _requireQrProviderSetup().clear();
      return const {'ok': true};
    },

    TillOps.qrProviderKind.name: (body, [_, _]) async {
      await _requireQrProviderSetup().setKindActive(
        qrKindActiveFromWireJson(body),
      );
      return const {'ok': true};
    },

    // ── шаблон чека (решение заказчика 2026-09-18) ───────────────────────
    //
    // «Это не граница, а пробел — в браузере должно работать то же, что в
    // приложении». Шапку и подвал чека правили только на кассе: оба экрана
    // шаблона ходили в `AppDatabase` напрямую, а `lib/data/` в браузерную
    // сборку не собирается вовсе.
    //
    // Работы здесь нет ни строки, и это то же правило, что у `qr.*` и у
    // приёма аванса: пишет и читает шаблон **та же служба печати**, которая
    // им печатает (`_requireReceiptTemplates`). Появись здесь хоть одна
    // проверка, которой нет у кассового экрана, у шаблона стало бы два
    // свода правил.
    //
    // Рабочего места операции не читают и не называют: принтер и шаблон —
    // свойство кассы, а не рабочего места. В карту продажи они поэтому не
    // кладутся — общий запрет `terminal_in_body` там про **чек**, а чека
    // здесь нет.
    //
    // Право `settings.printer` сторож проверил до этой строки.
    TillOps.receiptTemplates.name: (_, [_, _]) async =>
        receiptTemplateCatalogToWireJson(
          await _requireReceiptTemplates().read(),
        ),

    TillOps.receiptTemplateSave.name: (body, [_, _]) async {
      final ask = receiptTemplateSaveFromWireJson(body);
      // Безымянный шаблон — **отказ, а не подстановка умолчания**. Экран
      // проверяет то же самое, чтобы избавить от круга, но запрет обязан
      // держать касса: кадр можно собрать и мимо экрана, и строка «» в
      // списке шаблонов неотличима от строки, которую забыли отрисовать.
      if (ask.name.isEmpty) {
        throw const WireRefusal(
          receiptTemplateNamelessCode,
          'у шаблона чека обязано быть название',
        );
      }
      await _requireReceiptTemplates().save(
        id: ask.id,
        name: ask.name,
        optionsJson: ask.optionsJson,
      );
      return const {'ok': true};
    },

    TillOps.receiptTemplateSelect.name: (body, [_, _]) async {
      await _requireReceiptTemplates().select(
        receiptTemplateIdFromWireJson(body),
      );
      return const {'ok': true};
    },

    TillOps.receiptTemplateDelete.name: (body, [_, _]) async {
      await _requireReceiptTemplates().remove(
        receiptTemplateIdFromWireJson(body),
      );
      return const {'ok': true};
    },

    // Предпросмотр: касса собирает настоящие байты ESC/POS **тем же кодом,
    // каким печатает**, разбирает их обратно в текст своей единственной
    // функцией и отдаёт строку. Вкладка о раскладке не знает ничего —
    // разбор в докстринге `receipt_template_setup.dart`.
    TillOps.receiptTemplatePreview.name: (body, [_, _]) async =>
        receiptTemplatePreviewToWireJson(
          await _requireReceiptTemplates().preview(
            receiptTemplateOptionsFromWireJson(body),
          ),
        ),

    // Пробная печать. `ok: false` — принтер не взял задание; это не отказ
    // операции, а её честный исход: кассир увидит «не напечаталось», а не
    // красный экран.
    TillOps.receiptTemplateTestPrint.name: (_, [_, _]) async => {
      'ok': await _requireReceiptTemplates().testPrint(),
    },

    // ── смена (решение заказчика 2026-09-18) ─────────────────────────────
    //
    // Замерено живьём в тот же день: смена старше суток запирает продажу
    // окном «закройте смену на кассе», а с планшета закрыть её было нечем.
    //
    // Работы здесь нет ни строки: и уборку начатых чеков, и выбор суммы, и
    // запись расхождения, и само закрытие делает **одна процедура на кассу**
    // (`LocalShiftDesk`), которую с этого дня зовёт и кассовый экран.
    // Напиши обработчик своё закрытие рядом — касса закрывала бы смену одним
    // способом, планшет другим, и расходились бы они **в деньгах**.
    //
    // Вкладка задаёт ровно одно число — пересчитанные деньги; `null` значит
    // «не считали», а не ноль. Разбор — в докстринге
    // `lib/domain/shift/shift_desk.dart`.
    //
    // Право `nav.shift` сторож проверил до этой строки.
    TillOps.shiftClose.name: (body, [_, session]) async {
      await _shiftDeskFor(
        session,
      ).close(counted: shiftCountedFromWireJson(body));
      return const {'ok': true};
    },

    // Кассир — **из сеанса**, никогда из тела (И162): именем смены подписан
    // Z-отчёт и вся её выручка. Тело несёт только деньги, положенные в ящик
    // на начало.
    TillOps.shiftOpen.name: (body, [_, session]) async {
      await _shiftDeskFor(
        session,
      ).open(openingCash: shiftCountedFromWireJson(body));
      return const {'ok': true};
    },

    // ── диагностика оборудования (план 2026-09-19, пункт «достижимость с
    // браузерного терминала») ────────────────────────────────────────────
    //
    // Обмен с фискальным оператором — **вопрос**, в отличие от соседней
    // подписки на задания печати: сигнала изменения у очереди фискализации
    // касса не держит, и заводить его ради экрана, который наладчик и так
    // обновляет потягиванием вниз, значило бы строить подписку под
    // поверхность, а не под событие.
    //
    // Тело запроса к оператору форматирует **касса**, с отступами, и едет
    // оно строкой: этот текст сверяют с тем, что ждёт оператор, и второй
    // форматировщик во вкладке разошёлся бы с первым ровно там, где его
    // читают.
    //
    // Право `settings.hardware` сторож проверил до этой строки.
    TillOps.diagnosticsFiscal.name: (_, [_, _]) async =>
        fiscalDiagnosticsToWireJson(await _requireDiagnostics().fiscal()),

    // Продажа и оплата — двадцать три вопроса, все под общим запретом
    // называть рабочее место в теле. См. [_saleAskHandlers].
    ..._saleAskHandlers,
  };

  /// Вопросы продажи — задача 10 плана «Продажа с браузерного терминала»,
  /// и с ним пять денежных операций оплаты (задача 14): восемнадцать плюс
  /// пять, двадцать три записи. Оплата попала сюда при слиянии — см.
  /// довод у блока `── оплата (задача 14)` ниже.
  ///
  /// # Почему отдельная карта, а не двадцать три записи в [askHandlers]
  ///
  /// Ради **структурного** запрета, а не повторяемого вручную. Контракт
  /// корзины (`lib/domain/sale/cart_service.dart`, правило 1) требует:
  /// имя рабочего места берётся из сеанса, а кадр, в котором оно названо
  /// телом, **отвергается** — «отвергать, а не игнорировать» решение
  /// заказчика, перекрывающее бриф задачи 10 в этой части. Позвать проверку
  /// первой строкой в каждом из двадцати трёх обработчиков значило бы
  /// двадцать три места, где её можно забыть, — и забытая она не краснеет
  /// ничем, кроме теста, который тоже надо не забыть.
  ///
  /// Здесь она навешивается **на карту целиком** ([_refusingTerminalInBody]
  /// ниже), то есть на всё, что в неё положат, включая операцию, которой ещё
  /// нет. Ровно это и случилось при слиянии: пять операций оплаты,
  /// написанных на своей ветви со своим `_payTerminal`, легли под общий
  /// запрет одним переносом строк, и он оказался строже собственного —
  /// тот сверял ключ буквально `terminalId`. Проба «ни одна операция
  /// продажи не принимает `terminalId` телом» перебирает `SaleOps.all` —
  /// закрытый список, — и потому не может отстать от карты; для оплаты то
  /// же утверждает `test/backend/pay_operations_test.dart`.
  ///
  /// # Тела ответов собираются парами кодеков, а не литералом
  ///
  /// Ни один обработчик ниже не пишет имени поля руками: снимок корзины
  /// уезжает через `cartViewToWireJson`, выдача поиска — через
  /// `searchResultsToWireJson`, пул отложенных — через
  /// `deferredListToWireJson` (`lib/domain/wire/cart_codec.dart`). Причина
  /// измерена задачей 9: `decode` терминала ищет свой конверт по имени и на
  /// чужом имени отдаёт **пустой список** — «пул пуст» и «ничего не
  /// найдено», неотличимые от честного ответа. Семнадцать команд, каждая со
  /// своей сборкой снимка, — это семнадцать мест для такой опечатки;
  /// [_cartCommand] сводит их в одно.
  late final Map<String, WireHandler>
  _saleAskHandlers = _refusingTerminalInBody({
    // Наименьший возможный обмен продажи (задача 1 плана «Продажа с
    // браузерного терминала»): штрихкод туда, товар обратно, без единого
    // побочного действия — заведён ради замера круга, прежде чем строить
    // остальные операции фазы 1. Тот же путь поиска, что и у экрана
    // «дополнительно» (`additional_screen.dart:_lookup`): `productInfoDao`
    // для товара, `productPriceDao` для цены — второго пути не изобретаем.
    //
    // Единственная операция продажи, которая не спрашивает ни корзины, ни
    // рабочего места: она и заведена затем, чтобы мерить провод, ничего не
    // трогая.
    SaleOps.salePing.name: (body, [_, _]) async {
      final barcode = body['barcode'] as String? ?? '';
      final product = await _db.productInfoDao.findByBarcode(barcode);
      if (product == null) {
        // Ключей `name`/`price` здесь нет вовсе, а не `null` под ними:
        // `ProductProbe` читает их как `as String?`, то есть отсутствие и
        // пустое значение для него одно и то же, а денежный ключ с `null`
        // под ним сторож денег (круг правки 2 задачи 9) обязан считать
        // нарушением — и правильно делает, отличить «цены нет» от «цену
        // забыли положить дверью» он не может.
        return const {'found': false};
      }
      final price = await _db.productPriceDao.findByUcode(product.ucode);
      // Двойной `?.`: строки цены нет и тогда, когда у товара нет строки в
      // `product_prices` (`price == null`), и тогда, когда строка есть, но
      // `sellingPrice` в ней сама `null`.
      final selling = price?.sellingPrice;
      return {
        'found': true,
        'name': product.name,
        // **Круг правки 2 задачи 9: через дверь.** До неё здесь стоял
        // `selling?.toString()` — значение верное, но мимо [wireMoney] и
        // мимо сторожа, а `lib/backend/` не знал о двери ни одной строкой.
        // Задача 10 не написала рядом ни одного денежного поля руками —
        // все они уехали парами кодеков (докстринг карты выше), — но дверь
        // осталась единственной и здесь.
        if (selling != null) 'price': wireMoney(selling),
      };
    },

    // Поиск — единственный вопрос продажи, не трогающий ни корзины, ни
    // рабочего места (`CartService.search` не знает ни того, ни другого:
    // предел контракта, названный задачей 7 — цена в выдаче всегда
    // розничная). Отсюда и отсутствие метки команды: повторять поиск
    // безопасно, сверять версию не с чем.
    SaleOps.search.name: (body, [_, _]) async => searchResultsToWireJson(
      await _requireCart().search(_requireText(body, 'query')),
    ),

    // Единственная команда, которой разрешено звать себя «с холода»:
    // `meta.receiptNo == null` значит «я не знаю, что у меня в работе»
    // (`CartService.start`). Именно поэтому она первая в порядке терминала
    // — и именно поэтому её тело так и просится назвать рабочее место
    // самому; отвергается общим запретом карты.
    //
    // **Признака опта у неё нет — круг правки 1.** Он был обходом права:
    // `sale.setWholesale` требует `op.editPrice`, `sale.start` — только
    // `nav.sale`, а результат тот же самый. Довод снят из каталога
    // (докстринг `SaleOps.start`), и чек здесь всегда начинается
    // розничным; опт включается отдельной командой со своим правом.
    SaleOps.start.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) {
        // Названный опт — отказ, а не тихая розница: тем же правилом, что и
        // названное рабочее место. Молча проигнорированный признак означал
        // бы «я просил опт, получил розницу и не узнал об этом», а
        // клиенту, оставшемуся на старой форме кадра, — необъяснимые
        // розничные цены в оптовом чеке.
        if (body.containsKey('wholesale')) {
          throw const WireRefusal(
            'wholesale_in_start',
            'чек начинается розничным; опт включается sale.setWholesale — '
                'у него своё право',
          );
        }
        return cart.start(terminalId: terminalId, wholesale: false, meta: meta);
      },
    ),

    SaleOps.addByBarcode.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) =>
          cart.addByBarcode(terminalId, _requireText(body, 'barcode'), meta),
    ),

    SaleOps.addProduct.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) => cart.addProduct(
        terminalId,
        _requireInt(body, 'productId'),
        _requireDecimal(body, 'quantity'),
        meta,
      ),
    ),

    SaleOps.setQuantity.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) => cart.setQuantity(
        terminalId,
        _requireText(body, 'lineId'),
        _requireDecimal(body, 'quantity'),
        meta,
      ),
    ),

    SaleOps.increment.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) =>
          cart.increment(terminalId, _requireText(body, 'lineId'), meta),
    ),

    SaleOps.decrement.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) =>
          cart.decrement(terminalId, _requireText(body, 'lineId'), meta),
    ),

    // Условия правки строки — задача 44. Полномочия, по которым читается
    // предел, — **из сеанса**, тем же [_authorityOf], что у команд уступки
    // ниже: вкладка, назвавшая роль сама, получила бы чужой предел. Тело
    // кадра не читается вовсе.
    SaleOps.editTerms.name: (_, [_, session]) async => saleEditTermsToWireJson(
      await _requireEditTerms().read(by: _authorityOf(session)),
    ),

    // Быстрые товары — задача 45. Касса владеет каталогом; тела у категорий
    // нет, у товаров — только `categoryId`, и ключ обязателен: пропущенный
    // ключ и корень (`null`) — разные вопросы.
    SaleOps.quickCategories.name: (_, [_, _]) async =>
        quickCategoriesToWireJson(await _requireQuickProducts().categories()),
    SaleOps.quickItems.name: (body, [_, _]) async {
      // Модуль — первым, тем же порядком, что у `sale.search`: касса без
      // продажи отвечает `no_sale_module` на любое тело, а не разбирает его.
      final catalog = _requireQuickProducts();
      if (!body.containsKey(quickItemsCategoryKey)) {
        throw const WireRefusal(
          'bad_request',
          'sale.quickItems: нет поля categoryId (null — корень)',
        );
      }
      final categoryId = body[quickItemsCategoryKey];
      if (categoryId != null && categoryId is! int) {
        throw const WireRefusal(
          'bad_request',
          'sale.quickItems: categoryId — целое число или null',
        );
      }
      return quickItemsToWireJson(
        await catalog.items(categoryId: categoryId as int?),
      );
    },

    // Правила чтения штрихкода — задача 45. Лежит в карте продажи ради
    // общего запрета на имя рабочего места в теле; тела у неё нет вовсе.
    TillOps.scannerRules.name: (_, [_, _]) async =>
        scannerRulesToWireJson(await _requireScannerRules().read()),

    // Запись тех же правил — пункт 11 ревизии 2026-09-19. Право
    // `settings.hardware` сторож проверил до этой строки (I162), поэтому
    // здесь его нет: проверка права **внутри** обработчика означала бы, что
    // сторож не единственный, и разойтись они могли бы молча.
    //
    // Негодная тройка (min > max, отрицательный зазор) становится отказом
    // **значением**, а не падением: разбор кадра зовёт конструктор
    // `ScannerRules`, тот бросает `ArgumentError`, и здесь он превращается
    // в `bad_request` с текстом для человека. Записать к этому моменту
    // ничего не успели — разбор идёт до `save`.
    TillOps.scannerRulesSave.name: (body, [_, _]) async {
      final ScannerRules rules;
      try {
        rules = scannerRulesFromWireJson(body);
      } on ArgumentError catch (e) {
        throw WireRefusal('bad_request', '${e.message}');
      } on FormatException catch (e) {
        // Пропущенный ключ. Кодек считает его отказом разбора нарочно:
        // «поля нет» и «поле есть и равно null» — разные вещи, и вторая
        // означает «правило снято», то есть запись.
        throw WireRefusal('bad_request', e.message);
      } on TypeError {
        throw const WireRefusal(
          'bad_request',
          'scanner.saveRules: правила — целые числа или null',
        );
      }
      await _requireScannerRules().save(rules);
      return {'ok': true};
    },

    // Просрочена ли партия этого товара — пункт 11 ревизии 2026-09-19.
    // Лежит в карте продажи по тому же поводу, что и правила сканера выше:
    // общий запрет называть рабочее место в теле. Рабочее место здесь и не
    // нужно — срок годности партии свойство склада кассы, а не стойки.
    TillOps.saleExpiryWarning.name: (body, [_, _]) async => {
      'expired': await _requireExpiryWarning().isPickedBatchExpired(
        _requireInt(body, 'productId'),
      ),
    },

    // Три команды уступки — задача 12. Полномочия строятся **из сеанса**,
    // выписанного этой кассой, и ни одного ключа из тела кадра сюда не
    // попадает: тем же правилом, что и `terminalId` (докстринг
    // `CartService`), полномочия, названные клиентом, полномочиями не
    // являются. Сторож провода при этом свою проверку не теряет — он стоит
    // **до** обработчика (I162), и это отдельное свойство: право проверено
    // дважды не по недосмотру, а потому что это две разные защиты.
    SaleOps.setDiscountPercent.name: (body, [sessionId, session]) =>
        _cartCommand(
          body,
          sessionId,
          (cart, terminalId, meta) => cart.setDiscountPercent(
            terminalId,
            _requireText(body, 'lineId'),
            _requireDecimal(body, 'percent'),
            meta,
            by: _authorityOf(session),
          ),
        ),

    SaleOps.setDiscountAmount.name: (body, [sessionId, session]) =>
        _cartCommand(
          body,
          sessionId,
          (cart, terminalId, meta) => cart.setDiscountAmount(
            terminalId,
            _requireText(body, 'lineId'),
            _requireDecimal(body, 'amount'),
            meta,
            by: _authorityOf(session),
          ),
        ),

    SaleOps.updatePrice.name: (body, [sessionId, session]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) => cart.updatePrice(
        terminalId,
        _requireText(body, 'lineId'),
        _requireDecimal(body, 'price'),
        meta,
        by: _authorityOf(session),
      ),
    ),

    SaleOps.setMark.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) => cart.setMark(
        terminalId,
        _requireText(body, 'lineId'),
        _requireText(body, 'mark'),
        meta,
      ),
    ),

    SaleOps.removeLine.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) =>
          cart.removeLine(terminalId, _requireText(body, 'lineId'), meta),
    ),

    SaleOps.clear.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) => cart.clear(terminalId, meta),
    ),

    SaleOps.defer.name: (body, [sessionId, session]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) =>
          cart.defer(terminalId, meta, by: _authorityOf(session)),
    ),

    // `deferredReceiptNo`, а не `receiptNo`: в метке едет номер чека,
    // который у рабочего места **уже есть**, а поднимаемый — отдельный
    // довод (докстринг `CartService.loadDeferred`; имя ключа выбрано
    // задачей 9 ровно затем, чтобы одно не затёрло другое при слиянии
    // карт). Прочитать здесь `receiptNo` значило бы поднять «тот чек, что и
    // так у меня в работе» и получить `cart_wrong_receipt` на ровном месте.
    //
    // **Подъём ОПТОВОГО чека требует того же ключа, что и переключение
    // опта, — круг правки 2.** Измерено: обладатель `op.editPrice` сделал
    // оптовый чек и отложил его; кассир **без** этого права поднял его и
    // добавил строку — цена 400 при рознице 500. То есть «опт включается
    // только под своим правом» было верно для включения и неверно для
    // продолжения, а `op.deferSale` у роли кассира есть по умолчанию, тогда
    // как `op.editPrice` сознательно нет. Спасение чека
    // ([_rescueOrphanedCart]) этот путь ещё и расширило: оно само кладёт
    // незавершённые оптовые чеки в общий пул.
    SaleOps.loadDeferred.name: (body, [sessionId, session]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) => cart.loadDeferred(
        terminalId,
        _requireInt(body, 'deferredReceiptNo'),
        meta,
        by: _authorityOf(session),
      ),
    ),

    SaleOps.setAgent.name: (body, [sessionId, _]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) =>
          cart.setAgent(terminalId, _optionalInt(body, 'agentId'), meta),
    ),

    SaleOps.setWholesale.name: (body, [sessionId, session]) => _cartCommand(
      body,
      sessionId,
      (cart, terminalId, meta) => cart.setWholesale(
        terminalId,
        _requireBool(body, 'wholesale'),
        meta,
        by: _authorityOf(session),
      ),
    ),

    // ── оплата (задача 14) ───────────────────────────────────────────────
    //
    // Шесть операций (пять денежных задачи 14 и `pay.troubles` задачи
    // 16), и правило отбора одно: **едет то, что меняет правду о
    // деньгах или трогает железо** (I163). Пятнадцать остальных операций
    // экрана оплаты — клавиатура, активное поле, «без сдачи», раскладка
    // номиналов — по проводу не едут вовсе.
    //
    // Имя рабочего места ни одна из них не берёт из тела, и с днём слияния
    // запрет у них **общий с командами корзины**, а не свой. На ветви
    // задачи 14 его сторожил собственный `_payTerminal`: он сверял ключ
    // строкой `terminalId` и отвечал `bad_request`. Задача 10 к тому
    // времени уже измерила, что такой сверки мало (`terminal_id`,
    // `TerminalId`, имя во вложенном объекте проходили молча) и завела
    // [_refusingTerminalInBody] на всю карту продажи — с кодом
    // `terminal_in_body`, у которого есть перевод для кассира. Две
    // проверки одного правила под разными именами оставлять нельзя, и
    // выбрана строгая: пять денежных операций теперь под тем же запретом,
    // что и шестнадцать команд корзины, а место берётся [_cartTerminal] —
    // той же половиной `_payTerminal`, что осталась нужна.
    PayOps.accounts.name: (_, [_, _]) async =>
        accountsToWireJson(await _requirePayments().accounts()),

    // Тумблер кассы «продажа в кредит» — задача 16. Запрет держится не
    // этим ответом, а отказом `debt_not_sold_here` на `pay.complete`:
    // здесь касса только избавляет кассира от работы, которая всё равно
    // кончится отказом.
    PayOps.sellsInDebt.name: (_, [_, _]) async =>
        sellsInDebtToWireJson(await _requirePayments().sellsInDebt()),

    PayOps.loyalty.name: (body, [_, _]) async => loyaltyToWireJson(
      await _requirePayments().findLoyalty(body['phone'] as String? ?? ''),
    ),

    PayOps.bonus.name: (body, [_, _]) async => bonusToWireJson(
      await _requirePayments().reserveBonus(
        _requireInt(body, 'customerId'),
        _requireMoney(body, 'amount'),
      ),
    ),

    // Вход в зачёт аванса и в гашение сертификата. Обе операции — вопросы
    // об остатке, денег не двигают, рабочего места не читают: сальдо
    // покупателя и тираж бумажек одни на кассу. Отказы (вид выключен,
    // нет счёта, не тот ПИН) — значением из `PaymentService`, тем же
    // словом, каким ответило бы `pay.complete`.
    PayOps.prepayment.name: (body, [_, _]) async => prepaymentToWireJson(
      await _requirePayments().prepaymentBalance(
        _requireInt(body, 'customerId'),
      ),
    ),

    // Приём аванса — требование заказчика 2026-09-18. **Не оплата чека**:
    // разбор, почему это отдельная операция и почему у неё постоянное
    // второе право, — в докстринге `PayOps.prepaymentIntake`. Право
    // `op.creditRepay` сверх `nav.sale` проверил сторож до этой строки.
    //
    // Здесь нет ни одной строки работы и не должно быть: деньги пишет тот
    // же `CustomerPaymentUseCase`, что зовёт кассовый диалог, и всё, что
    // делает обработчик, — переводит кадр в довод и исход в кадр.
    // Появись здесь хоть одна проверка, которой нет у диалога, — у денег
    // стало бы два пути с разными правилами.
    //
    // Рабочего места операция не называет и не читает: сальдо покупателя
    // одно на кассу, как и у соседней `pay.prepayment`.
    PayOps.prepaymentIntake.name: (body, [_, _]) async =>
        prepaymentIntakeOutcomeToWireJson(
          await _requirePrepaymentIntake().acceptPrepayment(
            prepaymentIntakeFromWireJson(body),
          ),
        ),

    // Выдача аванса деньгами — решение заказчика 2026-09-18, вторая
    // половина той же работы, что приём строкой выше. **Не возврат чека**:
    // разбор, почему это отдельная операция, — в докстринге
    // `PayOps.prepaymentRefund`. Право `op.creditRepay` сверх `nav.sale`
    // проверил сторож до этой строки.
    //
    // Здесь нет ни одной строки работы и не должно быть: деньги выдаёт тот
    // же `CustomerPaymentUseCase`, что зовёт кассовый экран
    // `/prepayment-refund`. Появись здесь хоть одна проверка, которой нет у
    // экрана, — у денег, выходящих из кассы, стало бы два пути с разными
    // правилами.
    //
    // Рабочего места операция не называет и не читает: сальдо покупателя
    // одно на кассу.
    PayOps.prepaymentRefund.name: (body, [_, _]) async =>
        prepaymentRefundOutcomeToWireJson(
          await _requirePrepaymentRefund().payOutPrepayment(
            prepaymentRefundFromWireJson(body),
          ),
        ),

    // Замок перебора — до вопроса кассе, после разбора тела: кадр не той
    // формы (`bad_request`) и касса без оплаты (`payments_unavailable`)
    // отвечают своим словом и счёта не трогают. Разбор замка —
    // `certificate_throttle.dart`.
    PayOps.certificate.name: (body, [sessionId, session]) async {
      final payments = _requirePayments();
      final ask = certificateAskFromWireJson(body);
      return certificateToWireJson(
        await _guardCertificates(sessionId, session, [
          ask.number,
        ], () => payments.findCertificate(ask.number, pin: ask.pin)),
      );
    },

    PayOps.card.name: (body, [sessionId, _]) async => cardChargeToWireJson(
      await _requirePayments().chargeCard(
        _cartTerminal(sessionId),
        _requireMoney(body, 'amount'),
        cartCommandMetaFromWireJson(body),
      ),
    ),

    // Оплата по QR/СБП — три операции входа. Рабочее место — из сеанса:
    // намерение принадлежит тому, кто показал код, и чужая вкладка не
    // опросит, не отменит и не закроет им свой чек. Ответ собирает кодек
    // `pay_ops.dart`, и в нём нет ни адреса провайдера, ни ключа — у
    // `QrTender` этих полей нет вовсе (докстринг `qrTenderToWireJson`).
    PayOps.qrStart.name: (body, [sessionId, _]) async => qrTenderToWireJson(
      await _requirePayments().startQr(
        _cartTerminal(sessionId),
        _requireMoney(body, 'amount'),
        cartCommandMetaFromWireJson(body),
      ),
    ),

    PayOps.qrPoll.name: (body, [sessionId, _]) async => qrTenderToWireJson(
      await _requirePayments().pollQr(
        _cartTerminal(sessionId),
        qrIntentKeyFromWireJson(body),
      ),
    ),

    // Готовность QR — вопрос о кассе, а не о чеке: рабочего места не читает,
    // денег не двигает (докстринг `PaymentService.qrUnavailableReason`).
    PayOps.qrReadiness.name: (_, [_, _]) async =>
        qrReadinessToWireJson(await _requirePayments().qrUnavailableReason()),

    PayOps.qrCancel.name: (body, [sessionId, _]) async => qrTenderToWireJson(
      await _requirePayments().cancelQr(
        _cartTerminal(sessionId),
        qrIntentKeyFromWireJson(body),
      ),
    ),

    // Сертификаты в заявке — под тем же замком, что `pay.certificate`:
    // `pay.complete` проверяет номер и ПИН тем же `lookup`, и без замка здесь
    // перебор ушёл бы в соседнюю дверь. Заявка без сертификатов замка не
    // касается вовсе — наличная оплата не платит за чужой перебор.
    PayOps.complete.name: (body, [sessionId, session]) async {
      final terminalId = _cartTerminal(sessionId);
      final payments = _requirePayments();
      final request = paymentRequestFromWireJson(body);
      final meta = cartCommandMetaFromWireJson(body);
      Future<SaleOutcome> pay() => payments.complete(terminalId, request, meta);
      final numbers = [for (final c in request.certificates) c.number];
      return saleOutcomeToWireJson(
        numbers.every((n) => n.trim().isEmpty)
            ? await pay()
            : await _guardCertificates(sessionId, session, numbers, pay),
      );
    },

    // Выпуск сертификата — задача 21. **Не оплата товара, а выпуск**:
    // разбор, почему это отдельная операция, а не поле `pay.complete`, —
    // в докстринге `PayOps.certificateIssue`. Право `op.issueCertificate`
    // сверх `nav.sale` проверил сторож до этой строки.
    //
    // Рабочего места операция не называет и не читает: обязательство
    // берёт на себя **касса**, а не терминал, и `terminalId` ей не нужен
    // ни одной веткой.
    //
    // # Кассир — ИЗ СЕАНСА, и это правка хвоста 2026-09-19
    //
    // До неё обработчик не передавал `userId` вовсе, хотя `issue` его
    // принимает, а соседний путь — экран `certificate_issue_screen.dart` —
    // передаёт (`ref.read(currentUserIdProvider)`). Следствие было
    // денежным, а не косметическим: у **всех** бумажек, выпущенных с
    // планшета, `issued_by_user_id` оставался пуст, и блок «СЕРТИФИКАТЫ
    // (НЕ ВЫРУЧКА)» X/Z-отчёта (`CertificateDao.issuedNominalBetween`)
    // вынужден был отбирать мягко — иначе печатал бы ноль на смене, где
    // бумажки выпускались. Мягкий отбор значит, что выпуск **чужой
    // смены** попадал в строку этой.
    //
    // Тело кассира не называет и назвать не может: имя берётся там же,
    // где его берут смена (`_shiftDeskFor`) и предел скидки
    // (`_authorityOf`), — из `AuthSession`. Иначе вкладка выписывала бы
    // бумажки за чужой подписью.
    //
    // Сеанса нет (`session == null`) — поле остаётся пустым, как у строк
    // до этой правки. Такой путь живёт только в пробах: до `askHandlers`
    // дело без сеанса не доходит (`WireDenied.unauthorized`, докстринг
    // на строке 522).
    // **Полномочия едут доводом** — ревизия второго фронта 2026-09-19. Тем
    // же [_authorityOf], что у команд корзины: сторож проверил право до этой
    // строки, а сам выпуск проверяет его ещё раз и своим кодом. Две защиты,
    // каждая достаточна; вторая — единственная для кассового экрана, у
    // которого провода нет.
    PayOps.certificateIssue.name: (body, [_, session]) async {
      final ask = certificateIssueFromWireJson(body);
      return certificateToWireJson(
        await _requireCertificates().issue(
          by: _authorityOf(session),
          number: ask.number,
          nominal: ask.nominal,
          pin: ask.pin,
          expiresAt: ask.expiresAt,
          receiptNo: ask.receiptNo,
          userId: session?.userId,
        ),
      );
    },

    // Повтор печати слипа — решение заказчика 2026-09-18. **Под тем же
    // замком**, что `pay.certificate`: внутри стоит тот же `lookup`, он же
    // отличает «нет такого номера» от «не тот ПИН», и без замка эта операция
    // была бы дверью в соседнюю — перебирай здесь, пользуйся там.
    //
    // Кассир — **из сеанса**, а не из тела: слип уходит в очередь печати с
    // именем того, кто его заказал, и назвать вместо себя другого кадр права
    // не имеет. Рабочего места операция не читает: печатает та касса, к
    // которой подключён принтер.
    PayOps.certificateSlip.name: (body, [sessionId, session]) async {
      final ask = certificateAskFromWireJson(body);
      return certificateToWireJson(
        await _guardCertificates(
          sessionId,
          session,
          [ask.number],
          () => _requireCertificateSlips().reprint(
            number: ask.number,
            pin: ask.pin,
            userId: session?.userId,
          ),
        ),
      );
    },

    // Беды железа спрашиваются **после** успеха оплаты (докстринг
    // `PayOps.troubles`), поэтому эта операция не удлиняет круг, за
    // который платит покупатель.
    //
    // Рабочее место берётся **из сеанса**, как у остальных денежных
    // операций: беда чека отдаётся тому, кто его оплачивал, а не любому,
    // кто назовёт номер. Номера чеков последовательны по кассе, и
    // перебрать их ничего не стоит. Источник — `_cartTerminal`, а не
    // снятый при слиянии `_payTerminal`: запрет называть место телом
    // навешен на карту целиком (`_refusingTerminalInBody`).
    PayOps.troubles.name: (body, [sessionId, _]) async => troublesToWireJson(
      await _requirePayments().hardwareTroubles(
        _cartTerminal(sessionId),
        (body['receiptNo'] as num).toInt(),
      ),
    ),

    // ── возврат: задача 19 плана «Продажа с браузерного терминала» ───────
    //
    // Пять вопросов и одна подписка (`refund.view`, в `watchHandlers`
    // ниже). Каждый обработчик — перевод кадра в довод и исход в кадр:
    // логики здесь нет ни строки, она вся в `LocalRefundService` (задача
    // 18). Тела **разбираются и собираются парами кодеков**
    // (`refund_codec.dart`), а не литералом руками, как сделан сосед
    // `sale.ping` выше: снимок возврата с нулевой версией и пустым списком
    // строк — это законный ответ «черновика нет», и опечатка в имени поля
    // дала бы его вместо настоящего, ничем не отличимо.
    //
    // Имя рабочего места у всех шести берётся из сеанса, и кадр, в котором
    // оно названо, отвергается. Источник — [_cartTerminal], а не свой
    // `_refundTerminal`: при слиянии выяснилось, что задачи 14 и 19 завели
    // по собственному помощнику с одной и той же половинной проверкой
    // (буквальный ключ `terminalId`, код `bad_request`), тогда как задача 10
    // уже сделала запрет структурным на всю карту продажи
    // (`_refusingTerminalInBody`: имя ищется по написанию и на любой
    // глубине, код `terminal_in_body`, у которого есть перевод для кассира).
    // Три проверки одного правила под тремя именами оставлять нельзя.
    RefundOps.loadReceipt.name: (body, [sessionId, _]) async {
      final terminalId = _cartTerminal(sessionId);
      final request = receiptKeyFromWireJson(body);
      return refundViewToWireJson(
        await _requireRefund().loadReceipt(
          terminalId,
          request.receiptNo,
          request.posId,
          request.meta,
        ),
      );
    },

    RefundOps.startWithoutReceipt.name: (body, [sessionId, _]) async {
      final terminalId = _cartTerminal(sessionId);
      return refundViewToWireJson(
        await _requireRefund().startWithoutReceipt(
          terminalId,
          refundCommandMetaFromWireJson(body),
        ),
      );
    },

    RefundOps.addProduct.name: (body, [sessionId, _]) async {
      final terminalId = _cartTerminal(sessionId);
      final request = refundLineRequestFromWireJson(body);
      return refundViewToWireJson(
        await _requireRefund().addProduct(
          terminalId,
          request.productId,
          request.quantity,
          request.meta,
        ),
      );
    },

    RefundOps.setLine.name: (body, [sessionId, _]) async {
      final terminalId = _cartTerminal(sessionId);
      final request = refundLineQuantityFromWireJson(body);
      return refundViewToWireJson(
        await _requireRefund().setLineQuantity(
          terminalId,
          request.lineId,
          request.quantity,
          request.meta,
        ),
      );
    },

    RefundOps.complete.name: (body, [sessionId, _]) async {
      final terminalId = _cartTerminal(sessionId);
      return refundOutcomeToWireJson(
        await _requireRefund().complete(
          terminalId,
          refundCommandMetaFromWireJson(body),
        ),
      );
    },

    // Беды железа возврата — близнец `PayOps.troubles` выше и по тем же
    // доводам: спрашиваются после успеха, рабочее место — из сеанса, беда
    // отдаётся тому месту, которое возврат проводило.
    RefundOps.troubles.name: (body, [sessionId, _]) async => troublesToWireJson(
      await _requireRefund().hardwareTroubles(
        _cartTerminal(sessionId),
        (body['refundLocalId'] as num).toInt(),
      ),
    ),
  });

  /// Общая часть шестнадцати команд: рабочее место из сеанса, метка из тела
  /// готовой половиной пары, ответ — снимок корзины той же парой.
  ///
  /// Порядок здесь — не украшение. Рабочее место берётся **до** обращения к
  /// корзине: кадр без сеанса или с названным телом рабочим местом обязан
  /// получить отказ, ничего не тронув, а не после того, как касса сходила в
  /// базу.
  Future<Map<String, Object?>> _cartCommand(
    Map<String, Object?> body,
    int? sessionId,
    Future<CartView> Function(
      CartService cart,
      int terminalId,
      CartCommandMeta meta,
    )
    run,
  ) async {
    final terminalId = _cartTerminal(sessionId);
    final cart = _requireCart();
    // Готовая половина пары, а не разбор на месте: `key`/`baseVersion`/
    // `receiptNo` читаются одним вызовом одинаково для всех шестнадцати
    // команд, и снисходительность к пропущенным ключам описана там же
    // (`cartCommandMetaFromWireJson`), а не размазана по обработчикам.
    return cartViewToWireJson(
      await run(cart, terminalId, cartCommandMetaFromWireJson(body)),
    );
  }

  /// Оплата на этой кассе доступна?
  ///
  /// `null` — **не** та же осторожная деградация, что у
  /// [_deviceDiscovery]/[_network]: там отсутствие порта отключает деталь, а
  /// операция всё равно отвечает по существу. Здесь отсутствие означает, что
  /// принять деньги нечем, и отказ обязан быть названным, а не «пустым
  /// ответом, похожим на успех». Так стоит голый процесс
  /// `bin/telepos_backend.dart` — он не строит ни подготовку чека, ни
  /// `SaleUseCase`.
  /// Выпускающий сертификаты — или названный отказ.
  ///
  /// Тот же приём и тот же довод, что у [_requirePayments]: касса,
  /// собранная без контейнера зависимостей, обязана сказать «этого я не
  /// умею», а не изобразить выпуск обязательства.
  CertificateIssuer _requireCertificates() {
    final certificates = _certificates;
    if (certificates == null) {
      throw const WireRefusal(
        'certificates_unavailable',
        'эта касса не выпускает подарочные сертификаты по проводу',
      );
    }
    return certificates;
  }

  /// Стойка QR как порт настройки — или названный отказ.
  ///
  /// # Почему порт берётся у оплаты, а не отдельным сотрудником кассы
  ///
  /// Разбор целиком — в докстринге [QrProviderSetupHost]; коротко: настройку
  /// провайдера обязан читать **ровно один** класс (сторож
  /// `qr_secret_never_reaches_terminal_test`), и отдельный необязательный
  /// довод позволил бы собрать кассу, у которой деньги берёт одна стойка, а
  /// настройку правит другая. Здесь порт снимается с той самой раскладки
  /// оплаты, которую касса уже получила, — разойтись им негде.
  ///
  /// Проверка родом (`is`) — цена этого решения, названная вслух: контракт
  /// `PaymentService` о настройке ничего не знает и знать не должен (это
  /// оплата чека, а не настройка кассы), поэтому способность заявляется
  /// **вторым** интерфейсом. Реализация, его не объявившая (браузерная
  /// половина, подделка в пробе), честно получает отказ, а не молчаливый
  /// успех.
  QrProviderSetupRepository _requireQrProviderSetup() {
    // Образцом, а не `is` с продвижением: [QrProviderSetupHost] не наследник
    // `PaymentService`, и продвижения по такой проверке в Dart нет вовсе.
    final setup = switch (_payments) {
      final QrProviderSetupHost host => host.qrProviderSetup,
      _ => null,
    };
    if (setup == null) {
      throw const WireRefusal(
        qrSetupUnavailableCode,
        'эта касса не держит настройки провайдера QR',
      );
    }
    return setup;
  }

  /// Стойка смены на **этот** запрос.
  ///
  /// # Почему новая на каждый вызов, а не поле кассы
  ///
  /// Потому что у неё есть действующий: `LocalShiftDesk.actorUserId` — тот,
  /// чьим сеансом пришла заявка, и на кого открывается смена. Поле кассы
  /// пришлось бы либо оставить без действующего (и тогда открыть смену по
  /// проводу было бы нечем), либо принимать кассира доводом метода — то есть
  /// из тела кадра, где его подменит любой (И162).
  ///
  /// Своего состояния у стойки нет: это несколько запросов над той же базой,
  /// которую касса и так держит. Дорогого в постройке здесь нет ничего.
  ///
  /// Отказа «нет службы» у этой стойки не бывает, и это не недосмотр: база —
  /// обязательный довод `TillOperations` (касса без неё не собирается
  /// вовсе), а службу смены стойка собирает себе сама над той же базой —
  /// разбор в её конструкторе. Необязательного сотрудника, который мог бы
  /// молча не приехать, здесь нет.
  LocalShiftDesk _shiftDeskFor(AuthSession? session) =>
      LocalShiftDesk(db: _db, actorUserId: session?.userId);

  /// Шаблон чека — или названный отказ.
  ///
  /// Тот же приём и почти тот же довод, что у [_requireQrProviderSetup]:
  /// порт снимается с раскладки оплаты, потому что печатает чек она же.
  /// Разница в том, **почему** это обязательно: шаблон кассы кэширован
  /// внутри службы печати, и сбросить кэш надо у того экземпляра, который
  /// напечатает следующий чек. Порт, взятый отдельным доводом, мог бы
  /// сбрасывать кэш **другой** службы печати — владелец правил бы подвал и
  /// получал из принтера прежний. Разбор — в докстринге
  /// [ReceiptTemplateSetupHost].
  ///
  /// Проверка родом (`is`) — та же цена, названная там же: контракт
  /// `PaymentService` о шаблоне чека ничего не знает и знать не должен.
  ReceiptTemplateSetupRepository _requireReceiptTemplates() {
    final templates = switch (_payments) {
      final ReceiptTemplateSetupHost host => host.receiptTemplates,
      _ => null,
    };
    if (templates == null) {
      throw const WireRefusal(
        receiptTemplatesUnavailableCode,
        'эта касса не держит шаблонов чека',
      );
    }
    return templates;
  }

  /// Диагностика оборудования — или названный отказ.
  ///
  /// Тот же приём, что у [_requirePrepaymentIntake], но довод **свой**:
  /// пустой список здесь хуже, чем у соседей. «Касса ничего не отправляла в
  /// принтер» — законный ответ исправной кассы, и отдать его вместо «спросить
  /// не у кого» значило бы отправить наладчика искать беду в принтере,
  /// которого никто не спрашивал. Отказ называет, что диагностики у этой
  /// сборки нет вовсе.
  HardwareDiagnosticsRepository _requireDiagnostics() {
    final diagnostics = _diagnostics;
    if (diagnostics == null) {
      throw const WireRefusal(
        diagnosticsUnavailableCode,
        'эта касса не отдаёт диагностику оборудования',
      );
    }
    return diagnostics;
  }

  /// Приёмщик аванса — или названный отказ.
  ///
  /// Тот же приём и тот же довод, что у [_requireCertificates]: касса,
  /// собранная без контейнера зависимостей, обязана сказать «этого я не
  /// умею». Молчаливый успех здесь был бы худшим из возможного — кассир
  /// взял бы у покупателя деньги, а записи о них не появилось бы нигде.
  PrepaymentIntakeService _requirePrepaymentIntake() {
    final intake = _prepaymentIntake;
    if (intake == null) {
      throw const WireRefusal(
        prepaymentIntakeUnavailableCode,
        'эта касса не принимает аванс покупателя по проводу',
      );
    }
    return intake;
  }

  /// Перепечатывающий слип — или названный отказ.
  ///
  /// Код **существующий** (`certificates_unavailable`), а не новый: беда та
  /// же самая — «в этой сборке сертификатов нет вовсе», — и её фраза уже
  /// переведена на пять языков. Новое слово на ту же беду потребовало бы
  /// пяти словарных строк и дало бы кассиру два разных текста в зависимости
  /// от того, выпускает он бумажку или перепечатывает её слип.
  CertificateSlipReprinter _requireCertificateSlips() {
    final slips = _certificateSlips;
    if (slips == null) {
      throw const WireRefusal(
        'certificates_unavailable',
        'эта касса не печатает слипы подарочных сертификатов по проводу',
      );
    }
    return slips;
  }

  /// Выдающий аванс — или названный отказ.
  ///
  /// Тот же приём и тот же довод, что у [_requirePrepaymentIntake], и цена
  /// молчаливого успеха здесь выше: кассир прочёл бы «выдано», а денег
  /// покупателю не отдал бы никто.
  PrepaymentRefundService _requirePrepaymentRefund() {
    final refund = _prepaymentRefund;
    if (refund == null) {
      throw const WireRefusal(
        prepaymentRefundUnavailableCode,
        'эта касса не выдаёт аванс покупателя по проводу',
      );
    }
    return refund;
  }

  /// Проверка сертификата под замком перебора.
  ///
  /// Кассир — из сеанса ([AuthSession.userId]); рабочее место — то, что
  /// сессия сама доказала ([_sessionTerminals]), а без него — терминал
  /// сеанса. Ни одно из двух не берётся из тела: имя, названное кадром,
  /// нападающий менял бы на каждой попытке.
  Future<T> _guardCertificates<T>(
    int? sessionId,
    AuthSession? session,
    Iterable<String> numbers,
    Future<T> Function() check,
  ) => _certificateThrottle.guard(
    userId: session?.userId,
    sessionKey: sessionId,
    terminalId:
        (sessionId == null ? null : _sessionTerminals[sessionId]) ??
        session?.terminalId,
    numbers: numbers,
    check: check,
  );

  PaymentService _requirePayments() {
    final payments = _payments;
    if (payments == null) {
      throw const WireRefusal(
        'payments_unavailable',
        'эта касса не умеет принимать оплату по проводу',
      );
    }
    return payments;
  }

  /// Денежное поле кадра. Строкой, никогда числом (I159) — и отказом, а не
  /// исключением из глубины `Decimal.parse`, если пришло не то.
  static Decimal _requireMoney(Map<String, Object?> body, String field) {
    final raw = body[field];
    final value = raw is String ? Decimal.tryParse(raw) : null;
    if (value == null) {
      throw WireRefusal('bad_request', 'ожидалась сумма строкой в поле $field');
    }
    return value;
  }

  /// Ленивая уборка неиспользуемых строк `terminals` — довесок фазы 3/4
  /// закрытия долга, часть Б. Тот же приём, что `SessionRegistry._forget()`/
  /// `LoginThrottle._forget()` (докстринги там): чистка на обращении, без
  /// второго процесса и без будильника — зовётся первой строкой
  /// [TillOps.terminalRegister], то самое место, где строки и копятся
  /// (каждая перезагрузка вкладки — честная новая строка, пункт 2 фазы 3/4;
  /// переиспользования нет нарочно, пункт 6 — отчёт `phase34-fix-report.md`).
  ///
  /// Убирает терминал, только если верны **все** условия разом — брошенная
  /// строка не значит ничья строка, а по брифу «сомневаешься — не убирай»:
  ///
  /// - **не `isSelf`.** Терминал самой кассы неприкосновенен по
  ///   определению — `LocalTerminalRepository.delete` откажет и сам, но
  ///   проверка здесь тоже есть: без неё один отказ прервал бы уборку
  ///   остальных кандидатов в этом же проходе, а `isSelf` — не то, ради чего
  ///   стоит останавливать всю уборку.
  /// - **нет ни одной привязки устройства** (`TerminalDeviceBindings`).
  ///   Терминал с настроенным принтером/сканером — это чья-то настоящая
  ///   рабочая станция, а не мусор от F5, даже если на ней сейчас никто не
  ///   сидит: смена кончилась, касса выключена на ночь, привязка осталась.
  /// - **нет `secretFingerprint`.** Финальная правка закрытия долга: до
  ///   задачи 5 всякая строка была честным мусором от F5 — вкладка всё равно
  ///   регистрировалась бы заново на следующей загрузке, терять было нечего.
  ///   С задачи 5 у терминала, прошедшего привязку по одноразовому коду,
  ///   есть личность («личность переживает перезагрузку» — шаг 2 спеки), и
  ///   удаление строки эту личность уничтожает: планшет, закрытый на ночь,
  ///   терял бы привязку в тот самый момент, когда утром рядом заводят
  ///   другое устройство, и требовал бы нового кода у оператора без всякой
  ///   на то причины. Секрет не протухает — раз выданный, он либо ещё
  ///   действителен, либо явно отозван через `terminals.delete` — так что это
  ///   условие не «пока», а окончательное: такую строку эта уборка не тронет
  ///   никогда.
  /// - **на него не выписан живой `AuthSession`** ([_sessions],
  ///   [TerminalSessionCheck]). Критично для самого сценария, ради которого
  ///   пишется уборка: F5 заводит НОВУЮ QUIC-сессию и НОВЫЙ `terminalId`
  ///   (пункт 6 фазы 3/4 — переиспользования нет), но токен в
  ///   `SessionTokenStorage` переживает перезагрузку и восстанавливает
  ///   СТАРЫЙ сеанс через `_restoreSession()` (`login_controller.dart`) —
  ///   сеанс, выписанный на СТАРЫЙ `terminalId`. У старой строки в этот
  ///   момент одновременно и «QUIC-сессия закрыта» (следующее условие это
  ///   разрешит), и «под живым сеансом кассира, который прямо сейчас
  ///   работает» — убрать её значило бы вышибить терминал из-под
  ///   работающего человека, ровно то, что бриф запрещает первым делом.
  /// - **её QUIC-сессия закрыта, и с тех пор прошло не меньше
  ///   [_terminalIdleGrace].** «Закрыта» здесь означает «эта строка есть в
  ///   [_terminalIdleSince]» — строка, которую в памяти этого процесса
  ///   никогда не видели осиротевшей (свежая регистрация; сессия ещё
  ///   открыта; терминал заведён вручную из настроек, минуя `register()`;
  ///   или касса перезапускалась и память потеряна вместе со всеми
  ///   остальными сеансами — то же решение, что у `SessionRegistry`), не
  ///   трогается вовсе — тот же довод «сомневаешься — не убирай». Сама
  ///   задержка — не защита от найденной гонки (переиспользования
  ///   `terminalId` не бывает, значит и обратно завладеть той же строкой
  ///   никто не попытается), а дешёвый запас осторожности: проблема, которую
  ///   чинит уборка, копится часами (сотни F5 за смену), а не секундами, так
  ///   что несколько минут задержки не мешают эффективности и оставляют
  ///   время утихнуть любой гонке, которую этот разбор не нашёл.
  ///
  /// [_sessions] отсутствует (см. докстринг конструктора) → уборка не
  /// делает ничего вовсе, а не что-то по неполным данным: без порта, умеющего
  /// ответить про живой сеанс, третье условие недоказуемо, а угадывать его
  /// значило бы разменять «лучше лишняя строка» на «лучше отрезанный
  /// кассир».
  Future<void> _pruneUnusedTerminals() async {
    final sessions = _sessions;
    if (sessions == null || _terminalIdleSince.isEmpty) return;

    final cutoff = _clock().subtract(_terminalIdleGrace);
    final candidates = [
      for (final entry in _terminalIdleSince.entries)
        if (!entry.value.isAfter(cutoff)) entry.key,
    ];

    for (final terminalId in candidates) {
      // Терминал этого id снова под живой QUIC-сессией — тем же приёмом
      // защищена и версия, где `terminalId` теоретически переиспользовался
      // бы: сегодня это недостижимый путь (пункт 6), но проверка дешевле,
      // чем довод о том, почему она не нужна.
      if (_sessionTerminals.containsValue(terminalId)) continue;

      final row = await _db.terminalDao.findById(terminalId);
      if (row == null) {
        // Терминал уже убран другим путём (`terminals.delete` из настроек) —
        // бухгалтерии больше не за чем следить.
        _terminalIdleSince.remove(terminalId);
        continue;
      }
      if (row.isSelf) {
        // **Достижимо, в отличие от того, что здесь стояло раньше.** Прежняя
        // редакция говорила «не должно случаться — `terminalSelfEnsure` не
        // пишет [_terminalIdleSince] намеренно»; с круга правки 2 задачи 10
        // плана «Продажа с браузерного терминала» пишет: он метит осиротевшим
        // **прежнее место сессии** (докстринг [forgetSession] и сам
        // обработчик `TillOps.terminalSelfEnsure`). Помеченным при этом
        // становится прежнее место, а не терминал самой кассы, — так что
        // строка с `isSelf` сюда по-прежнему попадает только если её пометил
        // кто-то другой. Ветка остаётся тем же, чем была: терминал самой
        // кассы не убирается ни при каких условиях, и снимается с учёта
        // сразу, а не рассматривается заново каждый проход.
        _terminalIdleSince.remove(terminalId);
        continue;
      }
      if (row.secretFingerprint != null) {
        // Терминал прошёл привязку по одноразовому коду (задача 5) — у него
        // есть личность, которая обязана пережить простой и перезапуск кассы
        // (шаг 2 спеки: «личность переживает перезагрузку»). До задачи 5
        // брошенная строка без секрета была честным мусором от F5 — теперь
        // это может быть планшет, выключенный на ночь. Секрет не протухает,
        // так что строка не выйдет из этого исключения сама — раз и навсегда
        // снимаем её с учёта, а не откладываем то же решение на каждый
        // следующий проход.
        _terminalIdleSince.remove(terminalId);
        continue;
      }

      final bindings = await _db.terminalDao.deviceBindingsFor(terminalId);
      if (bindings.isNotEmpty) continue; // настоящая станция — не мусор.

      if (sessions.hasLiveSession(terminalId)) continue; // кассир работает.

      try {
        await _terminals.delete(terminalId);
      } on Object {
        // Уборка — любезность, не обещание: гонка (кто-то удалил ту же
        // строку между `findById` выше и этим вызовом) или любой другой
        // отказ репозитория не имеют права сорвать `terminals.register`,
        // ради которого эта уборка вообще позвана.
      }
      _terminalIdleSince.remove(terminalId);
    }
  }

  /// Подписки, включая `auth.users` и `auth.session` — то самое, ради чего
  /// менялся транспорт.
  ///
  /// Каждая отдаёт **бесконечный** поток: состояние не «заканчивается», и
  /// завершившийся поток означал бы для терминала «дальше изменений не будет»,
  /// то есть окончательность, которой нет. Снимаются они уходом подписчика —
  /// см. `TillSubscriptions`.
  late final Map<String, WireWatchHandler> watchHandlers = {
    TillOps.setupState.name: (_, [_, _]) =>
        watchSetupStateOf(_db).map(setupStateToWireJson),

    // Состояние смены — подписка, а не вопрос, и это половина работы
    // 2026-09-18: дом браузерного терминала показывал «Смена открыта»
    // зелёным значком часами после того, как смену закрыли, потому что
    // состояние приезжало один раз в `AuthSession` при входе. Вопрос чинил
    // бы это только в миг постройки экрана, а вкладку держат открытой всю
    // смену.
    //
    // Сеанса здесь нет и не нужно: состояние смены — свойство кассы, а не
    // того, кто спрашивает. Открытие смены, которому кассир нужен, —
    // отдельная операция выше.
    TillOps.shiftState.name: (_, [_, _]) =>
        _shiftDeskFor(null).watch().map(shiftDeskViewToWireJson),

    TillOps.terminalsList.name: (_, [_, _]) => _terminals.watchAll().map(
      (terminals) => {'terminals': terminals.map(terminalToWireJson).toList()},
    ),

    // `null` уезжает кадром с `terminal: null`, а не отказом: свежая
    // установка, где мастер ещё не проходил, — обычное состояние, и экран
    // мастера обязан открыться именно на нём.
    TillOps.terminalSelf.name: (_, [_, _]) => _terminals.watchSelf().map(
      (terminal) => {
        'terminal': terminal == null ? null : terminalToWireJson(terminal),
      },
    ),

    TillOps.deviceBindings.name: (body, [_, _]) {
      // Идентификатор читается **до** подписки, а не внутри `map`: плохой
      // довод обязан стать кадром отказа сразу, а не подпиской, которая
      // заведётся и упадёт на первом же обновлении.
      final terminalId = _requireInt(body, 'terminalId');
      return _deviceBindings
          .watchForTerminal(terminalId)
          .map(
            (bindings) => {
              // `terminalId` едет в ответе — его ждёт `_decodeBindings` в
              // `till_ops.dart` ради текста отказа при нераспознанном классе.
              'terminalId': terminalId,
              'bindings': bindings.map(deviceBindingToWireJson).toList(),
            },
          );
    },

    TillOps.authUsers.name: (_, [_, _]) => _auth.watchUsers().map(
      (users) => {'users': users.map(authUserToWireJson).toList()},
    ),

    TillOps.authSession.name: (body, [_, _]) {
      // Токен читается до подписки, как и `terminalId` в deviceBindings:
      // плохой довод обязан стать кадром отказа сразу.
      final token = body['token'] as String? ?? '';
      return _auth
          .watchSession(token)
          .map(
            (session) => {
              'session': session == null
                  ? null
                  : authSessionToWireJson(session),
            },
          );
    },

    // Задача 19 закрытия долга безопасности: экран списка живых сеансов.
    // Подписка, тем же доводом, что у `authUsers`/`authSession` рядом —
    // чужой вход и чужой отзыв обязаны дойти в момент события.
    TillOps.authSessions.name: (_, [_, _]) =>
        _requireSessionAdmin().watchLiveSessions().map(
          (sessions) => {
            'sessions': sessions.map(liveSessionToWireJson).toList(),
          },
        ),

    // Диагностика печати — подписка, а не вопрос, и это не украшение
    // (пункт «Достижимость с браузерного терминала» плана 2026-09-19).
    // Наладчик держит вкладку открытой и печатает пробный чек с соседнего
    // экрана: вопрос был бы верен ровно в миг постройки экрана, и пробный
    // чек не появился бы на нём вовсе.
    //
    // Рабочее место в теле не называется — его выбирает **касса по себе**
    // (`LocalHardwareDiagnostics.watchPrinter`, `TerminalRepository.self`).
    // Прими подписка чужой `terminalId` с планшета, вкладка читала бы чеки
    // соседнего рабочего места (И29), а право `settings.hardware` этого не
    // закрывает.
    //
    // Работы здесь нет ни строки, и разбор байтов тоже не здесь: чек
    // разбирает та же единственная функция дерева, которой собран
    // предпросмотр шаблона (докстринг
    // `lib/domain/diagnostics/hardware_diagnostics.dart`).
    //
    // Право `settings.hardware` сторож проверил до этой строки.
    TillOps.diagnosticsPrinter.name: (_, [_, _]) =>
        _requireDiagnostics().watchPrinter().map(printerDiagnosticsToWireJson),

    // Ящик, дисплей покупателя и весы — пункт 4 того же плана. До него на
    // планшете этих трёх вкладок не было вовсе: журналы ящика и дисплея
    // живут в памяти процесса кассы, показание весов — в живом порте.
    //
    // Подписки все три, и у ящика с дисплеем довод дословно принтерный:
    // наладчик держит вкладку открытой и жмёт кнопку на кассе. У весов довод
    // сильнее — вопрос там неверен по предмету: смотрят не число, а то, как
    // оно **едет**, пока груз ложится на чашу.
    //
    // Работы здесь нет ни строки, и прореживания кадров весов здесь тоже
    // нет: прореживает кассовая реализация порта, до провода
    // (`LocalHardwareDiagnostics.watchScales`). Сделай это обработчик, и
    // кассовая вкладка получала бы непрореженный поток, а планшет
    // прореженный — то есть две поверхности показывали бы разное про один
    // прибор.
    //
    // Право `settings.hardware` сторож проверил до этих строк.
    TillOps.diagnosticsDrawer.name: (_, [_, _]) =>
        _requireDiagnostics().watchDrawer().map(drawerDiagnosticsToWireJson),

    TillOps.diagnosticsDisplay.name: (_, [_, _]) =>
        _requireDiagnostics().watchDisplay().map(displayDiagnosticsToWireJson),

    TillOps.diagnosticsScales.name: (_, [_, _]) =>
        _requireDiagnostics().watchScales().map(scalesDiagnosticsToWireJson),

    // Остатки кассы изменились — пункт 12 ревизии 2026-09-19. Подписка, а
    // не вопрос: вкладку держат открытой всю смену, и продажа соседнего
    // рабочего места обязана доехать в момент события. Рабочее место в
    // теле не называется — остаток свойство кассы, а не стойки, — поэтому
    // подписка лежит здесь, а не в карте продажи: ей не нужен ни сеанс, ни
    // его терминал.
    // Третий довод игнорируется тем же приёмом, что у прочих подписок: он
    // нужен только `sale.deferredList`, которой полномочия кассира требуются
    // обязательным доводом. Остатку не нужен ни сеанс, ни его терминал.
    TillOps.stockRevision.name: (_, [_, _]) =>
        _requireStockChanges().watch().map((n) => {'revision': n}),

    // Продажа — две подписки, обе под тем же запретом называть рабочее
    // место в теле, что и вопросы. См. [_saleWatchHandlers].
    ..._saleWatchHandlers,
  };

  /// Подписки продажи — задача 10.
  ///
  /// Их две, и они разной природы, хотя лежат рядом: `sale.cart` — корзина
  /// **этого** рабочего места, `sale.deferredList` — общий пул **всей**
  /// кассы (решение 3 спеки). Первая обязана узнать рабочее место, вторая
  /// не обязана; запрет называть его телом одинаков для обеих, потому что
  /// правило контракта — про кадр, а не про то, пригодилось ли значение.
  ///
  /// Отдельной картой по той же причине, что и [_saleAskHandlers]: запрет
  /// навешен на карту целиком, а не переписан в каждой подписке.
  late final Map<String, WireWatchHandler>
  _saleWatchHandlers = _refusingTerminalInBodyWatch({
    // Рабочее место — из сеанса, и до этой задачи у подписки не было
    // способа его узнать вовсе: `WireWatchHandler` не получал сессии
    // (`till_wire.dart`, второй довод заведён здесь же). Единственным
    // доступным источником оставалось тело — ровно то, что контракт
    // требует отвергать.
    SaleOps.cart.name: (body, [sessionId, _]) =>
        _requireCart().watch(_cartTerminal(sessionId)).map(cartViewToWireJson),

    // Пул общий: рабочее место не спрашивается вовсе. Чек, отложенный
    // соседом, обязан появиться в списке сразу, а поднятый — исчезнуть,
    // иначе двое поднимают один чек и второй узнаёт об этом отказом
    // посреди работы.
    //
    // **Полномочия — из сеанса, задача 10 ревизии 2026-09-19.** Тем же
    // [_authorityOf], что у команд уступки и у `sale.editTerms`: тело кадра
    // сюда не попадает ни одним ключом. Сторож провода свою проверку
    // `op.deferSale` при этом не теряет — он стоит **до** обработчика
    // (I162), и это две разные защиты, а не одна, написанная дважды:
    // вторая — единственная у экрана кассы, у которого провода нет.
    SaleOps.deferredList.name: (_, [_, session]) => _requireCart()
        .watchDeferred(by: _authorityOf(session))
        .map(deferredListToWireJson),
    // Задача 19 плана «Продажа с браузерного терминала»: первая подписка,
    // которой **нельзя** брать имя рабочего места из тела — ради неё
    // `WireWatchHandler` и получил второй, необязательный довод (докстринг
    // там, `till_wire.dart`). Имя читается **до** подписки, тем же приёмом,
    // что `terminalId` у `deviceBindings` и токен у `authSession` выше:
    // плохой довод обязан стать кадром отказа сразу, а не подпиской, которая
    // заведётся и упадёт на первом же обновлении.
    RefundOps.view.name: (body, [sessionId, _]) {
      final terminalId = _cartTerminal(sessionId);
      return _requireRefund().watch(terminalId).map(refundViewToWireJson);
    },
  });

  /// Длинные работы. Обе идут минутами, и до провода канала для хода
  /// выполнения у них не было вовсе.
  late final Map<String, WireRunHandler> runHandlers = {
    TillOps.setupRestore.name: (body) async* {
      final firstLaunch = _requireFirstLaunch();
      final messageId = _requireInt(body, 'messageId');
      final backup = await findBackup(firstLaunch, messageId);
      if (backup == null) {
        // Отказ до первого кадра хода выполнения. `TillWire` превратит его в
        // кадр отказа: полоса, которая начала двигаться и остановилась, хуже
        // полосы, которая не начиналась. `WireRefusal` — та же болезнь, что
        // и у остальных мест этой задачи: текст называет копию по
        // `messageId` для человека, а не для лога, и общий `run_failed` его
        // прятал бы за именем типа исключения.
        throw WireRefusal(
          'backup_not_found',
          'копии с messageId=$messageId нет',
        );
      }
      yield* _withProgress(
        (onProgress) =>
            firstLaunch.restoreFromBackup(backup, onProgress: onProgress),
      );
    },

    TillOps.setupLoadGlobalData.name: (_) async* {
      final firstLaunch = _requireFirstLaunch();
      yield* _withProgress(
        (onProgress) => firstLaunch.loadGlobalData(onProgress: onProgress),
      );
    },
  };

  /// Превращает работу, которая сообщает о себе обратным вызовом, в поток
  /// кадров.
  ///
  /// [DoneFrame] уходит **только** при успешном возврате. Работа, бросившая
  /// исключение, заканчивается отказом без него: «готово» здесь означает целый
  /// магазин, и выдать незавершённое за завершённое дороже, чем показать
  /// причину.
  Stream<WireFrame> _withProgress(
    Future<bool> Function(BootProgress onProgress) work,
  ) {
    final frames = StreamController<WireFrame>();

    // Работа начинается сразу, а не с очередного оборота цикла событий:
    // `Future(...)` отложил бы её на событие, и первый кадр хода выполнения
    // приходил бы позже, чем есть что сказать. Слушатель уже есть — этот поток
    // возвращается изнутри генератора, которого слушают.
    Future<void> pump() async {
      try {
        final ok = await work((value, message) {
          if (frames.isClosed) return;
          // Число за краем — признак того, что его выдумали. Приёмник такой
          // кадр отвергает целиком, поэтому здесь оно приводится к отрезку:
          // окончание работы удостоверяет [DoneFrame], а не полоса, и врать о
          // завершении число не может.
          frames.add(ProgressFrame(value.clamp(0.0, 1.0).toDouble(), message));
        });
        frames.add(DoneFrame({'ok': ok}));
      } on Object catch (error, stackTrace) {
        // Отказ уезжает ошибкой потока, и `TillWire` делает из неё кадр
        // отказа **без** [DoneFrame].
        frames.addError(error, stackTrace);
      } finally {
        await frames.close();
      }
    }

    unawaited(pump());
    return frames.stream;
  }

  DeviceDiscovery _requireDiscovery() {
    final discovery = _deviceDiscovery;
    if (discovery == null) {
      // Свой код, а не `bad_request`: тело запроса тут ни при чём, отказывает
      // сама касса — на голом Dart-процессе (`bin/telepos_backend.dart`) нет
      // ни одного драйвера. «Искать было нечем» и «ничего не нашлось» для
      // оператора разные вещи, и код обязан их не путать так же, как текст.
      throw const WireRefusal(
        'no_drivers',
        'эта касса не умеет искать устройства (нет драйверов)',
      );
    }
    return discovery;
  }

  DeviceCheck _requireCheck() {
    final check = _deviceCheck;
    if (check == null) {
      // Тот же код, что у `_requireDiscovery`, и по тому же доводу: «искать
      // было нечем» и «ничего не нашлось» — разные вещи для `deviceCheck`
      // ровно так же, как для `deviceDiscovery` — держать их одним кодом
      // было бы расхождением на ровном месте.
      throw const WireRefusal(
        'no_drivers',
        'эта касса не умеет проверять устройства (нет драйверов)',
      );
    }
    return check;
  }

  /// Задача «сетевые настройки по проводу» (спека 2026-08-24). Свой код, не
  /// `no_drivers`: это не отсутствие драйвера железа, а процесс, для которого
  /// сеть кассы вовсе не заводили (докстринг поля [_network]) — отдельная
  /// причина заслуживает отдельного имени, а не переиспользования соседнего.
  NetworkRepository _requireNetwork() {
    final network = _network;
    if (network == null) {
      throw const WireRefusal(
        'no_network_module',
        'эта касса не умеет управлять сетью',
      );
    }
    return network;
  }

  /// Кассовая половина возврата — задача 19. Свой код, не `no_drivers` и не
  /// `no_network_module`: причина третья — не отсутствие железа и не
  /// отсутствие демона сети, а процесс, который не собирал контейнер
  /// зависимостей вовсе (`bin/telepos_backend.dart`). Отдельная причина
  /// заслуживает отдельного имени, а не переиспользования соседнего — тот же
  /// довод, что уже привёл [_requireNetwork] к своему коду.
  RefundService _requireRefund() {
    final refund = _refund;
    if (refund == null) {
      throw const WireRefusal(
        'no_refund_service',
        'эта касса не проводит возврат по проводу',
      );
    }
    return refund;
  }

  /// Сколько символов присланного имени класса едет обратно в отказе.
  ///
  /// Терминал, приславший строку длиннее этого, получает свою же строку,
  /// но обрезанную — не потому что более длинное имя опасно само по себе, а
  /// потому что нет предела длине, которую доверенный протокол не проверяет:
  /// `deviceClass` в теле запроса читается как `Object?` и раньше уезжало в
  /// кадр отказа без единой проверки формы.
  static const _deviceClassNameLimit = 64;

  /// Читает класс устройства по имени.
  ///
  /// Нераспознанное имя — отказ, а не ближайший знакомый класс: угаданный
  /// класс отправил бы кассу искать не то железо и рапортовать о нём как о
  /// запрошенном.
  static DeviceClass _requireDeviceClass(Map<String, Object?> body) {
    final raw = body['deviceClass'];
    for (final value in DeviceClass.values) {
      if (value.name == raw) return value;
    }
    // Довод сужен до `String?` прежде, чем попасть в текст отказа: `raw` —
    // непроверенный `Object?` с провода, и терминал волен прислать туда
    // `Map`, число или строку любой длины. Кадр отказа не место для чужого
    // JSON целиком — только имя, которое реально пробовали, и с пределом
    // длины.
    final display = switch (raw) {
      String s when s.length > _deviceClassNameLimit =>
        '${s.substring(0, _deviceClassNameLimit)}…',
      String s => s,
      _ => 'не строка',
    };
    // `bad_request`, а не свой код: причина в теле запроса, ровно как у
    // пустого имени — терминал прислал класс устройств, которого касса не
    // знает, а не касса чего-то не умеет.
    throw WireRefusal(
      'bad_request',
      'этой кассе неизвестен такой класс устройств: $display',
    );
  }

  /// Порт списка сеансов и их отзыва — задача 19 закрытия долга
  /// безопасности. Тот же приём и тот же довод, что у [_requireDiscovery]/
  /// [_requireCheck] выше: на настоящей кассе он всегда есть, а тесты, у
  /// которых его нет, узнают об этом названной причиной, а не молчаливой
  /// пустотой.
  SessionAdmin _requireSessionAdmin() {
    final sessionAdmin = _sessionAdmin;
    if (sessionAdmin == null) {
      throw const WireRefusal(
        'no_session_registry',
        'эта касса не умеет показывать и отзывать сеансы (реестр сеансов '
            'не собран)',
      );
    }
    return sessionAdmin;
  }

  FirstLaunchRepository _requireFirstLaunch() {
    final firstLaunch = _firstLaunch;
    if (firstLaunch == null) {
      // Свой код, тем же доводом, что у `_requireDiscovery`: транспорта нет —
      // состояние самой кассы (офлайновое развёртывание), а не испорченное
      // тело запроса.
      throw const WireRefusal(
        'no_backup_transport',
        'на этой установке нет транспорта резервных копий (офлайновое '
            'развёртывание)',
      );
    }
    return firstLaunch;
  }

  /// Отправляет чек осиротевшего рабочего места в общий пул отложенных —
  /// круг правки 1 задачи 10.
  ///
  /// # Что было измерено
  ///
  /// Вкладка получает **новый** номер места, не закрывая QUIC-сессию:
  /// неудавшееся возобновление по секрету (`localStorage` очищен, терминал
  /// удалён на кассе) сразу переходит в новую регистрацию — путь живой,
  /// `login_controller.dart` идёт им сам. Её чек остаётся за **старым**
  /// местом:
  ///
  /// ```
  /// чек места 7: receiptNo=1;  корзина места 9: пусто
  /// Sales: receiptNo=1 terminalId=7 state=0;  пул отложенных: 0
  /// ```
  ///
  /// Номер сожжён, новая корзина пуста, в пуле чека нет, поднять нечем.
  /// Уборка неиспользуемых мест ([_pruneUnusedTerminals]) его тоже не
  /// заберёт — у зарегистрированного места есть `secretFingerprint`, и это
  /// исключение окончательное. То есть набранный чек пропадал бы совсем.
  ///
  /// # Почему в пул, а не «перевесить на новое место»
  ///
  /// Перевесить было бы точнее по намерению, но у контракта корзины нет
  /// команды смены владельца, а заводить её здесь значило бы менять
  /// контракт, которым уже пользуются две соседние ветки. Пул — то самое
  /// место, которое продукт держит для чека без нынешнего хозяина: чек
  /// виден всем рабочим местам, поднимается штатной командой
  /// `sale.loadDeferred`, и кассир возвращается к своей работе тем же
  /// действием, каким он поднимает чек, отложенный на обед.
  ///
  /// # Спасение — любезность, не обещание
  ///
  /// Любой отказ здесь глотается тем же приёмом и по тому же доводу, что в
  /// [_pruneUnusedTerminals]: регистрация терминала не имеет права
  /// сорваться из-за чужого чека. Пустой чек не откладывается вовсе
  /// (`cart_empty` от самой корзины) — откладывать нечего.
  ///
  /// Цена решения, названная прямо: чек уходит в **общий** пул, то есть
  /// становится виден и доступен другим кассирам этой кассы. Это слабее,
  /// чем было (чек принадлежал одному месту), и сильнее, чем
  /// альтернатива, — а альтернатива здесь не «оставить как было», а
  /// «потерять».
  /// Полномочия спасения — **самой кассы**, а не человека (задача 28).
  ///
  /// С задачи 28 `CartService.defer` требует `op.deferSale` доводом. У
  /// спасения нет вошедшего: чек перекладывает касса при регистрации нового
  /// места. `DiscountAuthority.none` здесь выглядел бы осторожно, а на деле
  /// выключил бы спасение **молча** — отказ по праву тонет в `on Object`
  /// ниже, и набранный чек снова пропадал бы, ровно то, от чего спасение
  /// заведено. Право одно и названо поимённо: ни скидки, ни цены.
  static const _rescueAuthority = DiscountAuthority(
    roleIndex: -1,
    permissions: {PermissionKeys.opDeferSale},
  );

  Future<void> _rescueOrphanedCart(int terminalId) async {
    final cart = _cart;
    if (cart == null) return;
    try {
      // Первое значение подписки — текущий снимок; подписка тут же
      // снимается (`first`). Отдельного «прочитать корзину» у контракта
      // нет, и заводить его ради одного читателя не стоит.
      //
      // **Срок — круг правки 2.** Перехват ниже глотает отказ, но не
      // зависание: реализация корзины, чья подписка не отдаст первого кадра,
      // повесила бы **вторую регистрацию навсегда**, и вкладка не получила бы
      // ни ответа, ни отказа. С нынешней `LocalCartService` такого не бывает
      // (`watchTables` отдаёт первое значение сразу), но обещание было
      // «регистрация не имеет права сорваться из-за чужого чека», а без срока
      // выходило «регистрация может на чужом чеке повиснуть» — другое
      // обещание и хуже прежнего. Срок щедрый: он не рассчитан на медленную
      // базу, он ловит именно неотвечающую реализацию.
      final view = await cart.watch(terminalId).first.timeout(_rescueDeadline);
      if (view.receiptNo == null || view.lines.isEmpty) return;
      await cart.defer(
        terminalId,
        CartCommandMeta(
          // Ключ повтора этой команды не приходит ни от какого терминала —
          // её никто не повторит, — но он обязан быть своим: совпади он с
          // ключом настоящей команды, честный повтор той команды получил бы
          // отказ (слот один на чек, докстринг [CartService]).
          key: 'rescue:$terminalId:${view.receiptNo}:${view.version}',
          baseVersion: view.version,
          receiptNo: view.receiptNo,
        ),
        by: _rescueAuthority,
      );
    } on Object {
      // Гонка (сосед отложил или поднял тот же чек между чтением и
      // командой), пустой чек, любой отказ корзины, истёкший
      // [_rescueDeadline] — всё это не повод сорвать регистрацию терминала,
      // ради которой спасение и позвано. `on Object` ловит и
      // `TimeoutException`.
    }
  }

  /// Полномочия на уступку — из сеанса, и только из него (задача 12).
  ///
  /// Роль в [AuthSession] лежит **именем** (`'cashier'`), а предел ищется по
  /// индексу `UserRole` — перевод делается здесь, один раз. Имя, которого
  /// перечисление не знает, даёт «роль неизвестна» и попадает на строку
  /// умолчания: отказать по неузнанному имени значило бы остановить кассу
  /// на опечатке в чужой записи, а тихо выдать полный предел — соврать.
  /// Умолчание — единственный честный ответ: оно объявлено, видно на экране
  /// и изменяемо.
  ///
  /// Сеанса нет вовсе — [DiscountAuthority.none]: прав ноль, и корзина
  /// откажет по праву. Такой кадр до обработчика доходить не должен вовсе
  /// (сторож провода требует `op.sellDiscount`), и именно поэтому здесь
  /// стоит отказ, а не выдумка: две защиты, каждая из которых достаточна.
  static DiscountAuthority _authorityOf(AuthSession? session) {
    if (session == null) return DiscountAuthority.none;
    final role = UserRole.values
        .where((r) => r.name == session.role)
        .firstOrNull;
    return DiscountAuthority(
      roleIndex: role?.index ?? -1,
      permissions: session.permissions,
      // Из сеанса, выписанного кассой, — **никогда из тела кадра**. Тем же
      // правилом, что права и `terminalId`: аудит, записавший того, кем
      // вкладка себя назвала, аудитом не является.
      userId: session.userId,
    );
  }

  /// Сколько спасение ждёт корзину, прежде чем бросить попытку.
  ///
  /// Не про медленную базу, а про неотвечающую реализацию — см. довод в
  /// [_rescueOrphanedCart]. Чек при истечении срока остаётся там же, где был
  /// (за прежним местом), то есть худший исход — тот, что был до круга
  /// правки 1, а не новый.
  final Duration _rescueDeadline;

  /// Корзина этой кассы — задача 10. Отказ, а не пустая корзина: см.
  /// докстринг довода конструктора `cart`.
  CartService _requireCart() {
    final cart = _cart;
    if (cart == null) {
      // Свой код, не `no_drivers` и не `no_network_module`: это не
      // отсутствие железа и не отсутствие демона сети, а процесс, который не
      // собрал реализацию продажи вовсе. Отдельная причина — отдельное имя,
      // тем же правилом, каким заведён `no_network_module` рядом.
      throw const WireRefusal(
        'no_sale_module',
        'эта касса не умеет вести корзину (реализация продажи не собрана)',
      );
    }
    return cart;
  }

  /// Быстрые товары — задача 45. Тот же код, что у [_requireEditTerms].
  QuickProductCatalog _requireQuickProducts() {
    final catalog = _quickProducts;
    if (catalog == null) {
      throw const WireRefusal(
        'no_sale_module',
        'эта касса не умеет вести продажу (быстрые товары не собраны)',
      );
    }
    return catalog;
  }

  /// Правила сканера — задача 45. Тот же код, что у [_requireEditTerms].
  /// Изменения остатков — пункт 12 ревизии 2026-09-19. Тот же код, что у
  /// [_requireExpiryWarning]: причина одна — продажа в этом процессе не
  /// собрана.
  StockChanges _requireStockChanges() {
    final changes = _stockChanges;
    if (changes == null) {
      throw const WireRefusal(
        'no_sale_module',
        'эта касса не умеет вести продажу (изменения остатков не собраны)',
      );
    }
    return changes;
  }

  /// Предупреждение о просроченной партии — пункт 11 ревизии 2026-09-19.
  /// Тот же код, что у [_requireScannerRules].
  ExpiryWarningReader _requireExpiryWarning() {
    final reader = _expiryWarning;
    if (reader == null) {
      throw const WireRefusal(
        'no_sale_module',
        'эта касса не умеет вести продажу (учёт партий не собран)',
      );
    }
    return reader;
  }

  ScannerRulesRepository _requireScannerRules() {
    final rules = _scannerRules;
    if (rules == null) {
      throw const WireRefusal(
        'no_sale_module',
        'эта касса не умеет вести продажу (правила сканера не собраны)',
      );
    }
    return rules;
  }

  /// Условия правки строки — задача 44. Тот же код, что у [_requireCart]:
  /// причина одна — продажа в этом процессе не собрана.
  SaleEditTermsReader _requireEditTerms() {
    final terms = _editTerms;
    if (terms == null) {
      throw const WireRefusal(
        'no_sale_module',
        'эта касса не умеет вести продажу (условия правки строки не собраны)',
      );
    }
    return terms;
  }

  /// Код отказа кадру, который назвал рабочее место сам.
  ///
  /// Свой код, а не `bad_request`: терминалу это лечится **правкой
  /// собственного кода**, а не другим значением поля, и различать это по
  /// подстроке в тексте отказа он не обязан (тот же довод, по которому
  /// `cart_stale` отделён от `cart_wrong_receipt` в контракте корзины).
  static const _terminalInBodyCode = 'terminal_in_body';

  /// Обёртка карты вопросов продажи: каждый кадр сначала проверяется на то,
  /// что рабочее место в нём не названо, и только потом доходит до
  /// обработчика.
  ///
  /// Возвращает **новую** карту, а не правит исходную: то, что попало сюда,
  /// иначе как через проверку наружу не выходит.
  Map<String, WireHandler> _refusingTerminalInBody(
    Map<String, WireHandler> handlers,
  ) => handlers.map(
    (name, handler) => MapEntry(name, (body, [sessionId, session]) async {
      _refuseTerminalInBody(body);
      return handler(body, sessionId, session);
    }),
  );

  /// То же для подписок.
  Map<String, WireWatchHandler> _refusingTerminalInBodyWatch(
    Map<String, WireWatchHandler> handlers,
  ) => handlers.map(
    (name, handler) => MapEntry(name, (body, [sessionId, session]) {
      // Бросается **до** возврата потока, а не внутри него: `TillWire
      // ._subscribe` ловит [WireRefusal] вокруг вызова обработчика и
      // отвечает кадром отказа. Отказ изнутри потока доехал бы позже и
      // выглядел бы как оборвавшаяся подписка.
      _refuseTerminalInBody(body);
      return handler(body, sessionId, session);
    }),
  );

  /// Кадр продажи не имеет права называть рабочее место — контракт корзины
  /// (`lib/domain/sale/cart_service.dart`, правило 1) требует именно
  /// **отвергать** такой кадр.
  ///
  /// «Отвергать, а не игнорировать» — решение заказчика (круг правки 5
  /// задачи 7), прямо перекрывающее бриф задачи 10, который говорил «поле
  /// тела игнорируется». Довод там же: названное чужое имя — либо ошибка
  /// клиента, либо попытка; молчаливое игнорирование прячет обе, и первая
  /// всплывает как необъяснимое «команды уходят не туда», а вторая не
  /// всплывает вовсе.
  ///
  /// Ключ проверяется на **наличие**, а не на значение: `terminalId: null`
  /// — такое же называние, как `terminalId: 9`, и пропустить его значило бы
  /// оставить форму, которая проходит мимо запрета.
  ///
  /// **Круг правки 1: имя ищется по написанию, а не побуквенно, и на любой
  /// глубине.** Первая версия сверяла ключ строкой `'terminalId'`, и
  /// `terminal_id`, `TerminalId`, `terminalID` и имя во вложенном объекте
  /// проходили молча. Дырой это не было — ни одна операция продажи не
  /// читает место из тела ни под каким написанием, — но объявленный смысл
  /// запрета был именно «ошибка клиента всплывает, а не прячется», а на
  /// ошибшемся клиенте она как раз пряталась: он видел бы, что команды
  /// уходят не туда, и не получал бы ни слова о причине.
  static void _refuseTerminalInBody(Map<String, Object?> body) {
    if (_namesTerminal(body)) {
      throw const WireRefusal(
        _terminalInBodyCode,
        'рабочее место не называется в теле команды продажи (ни под каким '
        'написанием) — касса берёт его из сеанса',
      );
    }
  }

  /// Есть ли в [value] ключ, называющий рабочее место, в любом написании и
  /// на любой достижимой глубине.
  ///
  /// Написание сводится к одному виду: регистр снимается, подчёркивания
  /// убираются — так `terminalId`, `terminal_id`, `TerminalID` и
  /// `TERMINAL_ID` становятся одним именем. Обход рекурсивный, потому что
  /// вложенный объект — самая естественная форма ошибки у клиента, который
  /// собрал кадр по чужому образцу.
  ///
  /// [depth] ограничена: тело кадра продажи плоское по построению (каталог
  /// не кладёт в него ни одного объекта), и обходить неограниченно чужой
  /// JSON значило бы отдать глубину обхода на выбор присылающему.
  ///
  /// **Предел, названный кругом правки 2:** глубже четвёртого уровня имя
  /// проходит молча. Дырой это не является по той же причине, по которой ею
  /// не было и каноническое написание — место не читается из тела ни на
  /// какой глубине, — но обещание «ошибка клиента всплывает» на пятом
  /// уровне вложенности не выполняется. Такой формы у кадра продажи не
  /// бывает; предел записан, а не закрыт.
  static bool _namesTerminal(Object? value, {int depth = 4}) {
    if (depth <= 0) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is String &&
            key.toLowerCase().replaceAll('_', '') == 'terminalid') {
          return true;
        }
        if (_namesTerminal(entry.value, depth: depth - 1)) return true;
      }
      return false;
    }
    if (value is List) {
      return value.any((e) => _namesTerminal(e, depth: depth - 1));
    }
    return false;
  }

  /// Рабочее место этой QUIC-сессии — то, что она сама завела через
  /// `terminals.register`/`terminals.resume`/`terminals.selfEnsure`.
  ///
  /// Источник — [_sessionTerminals], та же карта, из которой берёт терминал
  /// `auth.login`, а не `AuthSession.terminalId`. Разница между ними
  /// измерима и не теоретическая: токен переживает F5, а QUIC-сессия — нет,
  /// так что вкладка, восстановившая сеанс на новой сессии после
  /// перерегистрации, имеет в сеансе **старый** номер места, а в этой карте
  /// — новый. Корзину ведёт то место, за которым вкладка сидит сейчас, то
  /// есть новое.
  ///
  /// **Цена этого выбора измерена и названа, а не подразумевается (круг
  /// правки 1).** Смена номера места означает, что чек, набранный до неё,
  /// остаётся за старым местом и становится вкладке недоступен: номер
  /// сожжён, новая корзина пуста, в пуле отложенных чека нет. Замерено:
  ///
  /// ```
  /// чек места 7: receiptNo=1;  корзина места 9: пусто
  /// Sales: receiptNo=1 terminalId=7 state=0;  пул отложенных: 0
  /// ```
  ///
  /// Выбор источника от этого не меняется — брать место из сеанса значило
  /// бы вести корзину места, за которым вкладка уже не сидит, — а сам чек
  /// спасается отправкой в общий пул: [_rescueOrphanedCart], зовётся из
  /// `terminals.register`/`terminals.resume` в тот самый момент, когда
  /// старое место осиротело.
  ///
  /// **Что этим НЕ закрыто:** сторож (`SessionAccess.ownTerminal`) сверяет
  /// тело с `session.terminalId`, то есть со **вторым** из двух источников.
  /// Сегодня столкновения нет — ни у одной операции продажи `ownTerminal`
  /// не объявлен, и объявлять его нечему (тело места не называет вовсе), —
  /// но припиши его когда-нибудь команде корзины, и две проверки будут
  /// говорить о разных вещах под одним именем.
  ///
  /// Код отказа `unknown_terminal` — **четвёртый производитель**, счёт
  /// получен поиском (`grep -rn "'unknown_terminal'" lib/`), а не по
  /// памяти: два в `auth.login` (сессия ничего не заводила; заведённое
  /// успели удалить) и один в `LocalTerminalRepository.resume`. Смысл тот
  /// же самый — «эта сессия не связана с рабочим местом», — и терминал уже
  /// умеет на него отвечать перезаводкой (`login_controller.dart`).
  int _cartTerminal(int? sessionId) {
    final terminalId = sessionId == null ? null : _sessionTerminals[sessionId];
    if (terminalId == null) {
      throw const WireRefusal(
        'unknown_terminal',
        'эта сессия ещё не завела рабочее место через terminals.register/'
            'terminals.resume/terminals.selfEnsure — корзину вести некому',
      );
    }
    return terminalId;
  }

  /// Читает обязательную непустую строку.
  ///
  /// Пустая отвергается наравне с отсутствующей: пустой `lineId` не найдёт
  /// строки, а пустой `barcode` — товара, и оба доехали бы до терминала
  /// отказом по существу (`line_not_found`, `product_not_found`), уводя
  /// разбор в корзину с испорченного тела.
  static String _requireText(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value is String && value.isNotEmpty) return value;
    throw WireRefusal('bad_request', 'ожидалась непустая строка: $field');
  }

  static bool _requireBool(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value is bool) return value;
    // Умолчания нет намеренно: `wholesale` без значения — это выбор ценовой
    // колонки, сделанный за кассира кассой, и «розница по умолчанию» здесь
    // была бы решением о деньгах, принятым молчанием.
    throw WireRefusal('bad_request', 'ожидалось true или false: $field');
  }

  /// Читает необязательное целое: ключа нет или под ним `null` — значит
  /// `null`, и это утверждение, а не пропуск.
  ///
  /// Единственный читатель — `sale.setAgent`, где `null` означает «агента
  /// снять» (докстринг `cartCommandMetaToWireJson` про ту же форму).
  /// Значение неверного типа отвергается, а не превращается в `null`: снять
  /// агента и не понять присланного — разные исходы.
  static int? _optionalInt(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value == null) return null;
    if (value is int) return value;
    throw WireRefusal('bad_request', 'ожидалось целое или пусто: $field');
  }

  /// Читает денежное значение — **строкой и только строкой** (инвариант
  /// I159).
  ///
  /// Число здесь отвергается, а не приводится: `double` теряет разряды
  /// молча, и приняв `10.1` числом, касса записала бы в чек не то, что
  /// набрал кассир. Отказ называет причину прямо, потому что клиент,
  /// приславший число, чинится одной строкой у себя, а не гаданием.
  static Decimal _requireDecimal(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value is String) {
      final parsed = Decimal.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw WireRefusal(
      'bad_request',
      'ожидалось десятичное число строкой (не числом): $field',
    );
  }

  /// Читает обязательное целое, не доверяя типу.
  ///
  /// Не подставляет умолчание: незаметно подменённый идентификатор терминала
  /// записал бы привязку устройства не туда, и увидеть это можно было бы
  /// только по неработающему принтеру у другого кассира.
  ///
  /// Задача 2б, отложенная в задачу 10: бросает `WireRefusal`, а не
  /// `ArgumentError`. `ArgumentError` доезжал бы до терминала только именем
  /// типа (`safeErrorText`, `lib/core/errors/safe_error_text.dart`) —
  /// «ожидалось целое: terminalId» до человека не доходило вовсе, и звалась
  /// эта функция шестью с лишним обработчиками.
  static int _requireInt(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value is int) return value;
    throw WireRefusal('bad_request', 'ожидалось целое: $field');
  }

  /// Состояние установки — обе таблицы разом.
  ///
  /// Форма — [setupStateToWireJson], та же самая, которую читает
  /// [setupStateFromWireJson].
  Future<Map<String, Object?>> setupState() => readSetupState(_db);
}

/// Собирает [SetupState] этой установки в форму провода.
///
/// Сама сборка живёт в [readSetupStateOf] (`lib/data/setup/setup_state_source.dart`)
/// вместе со своей потоковой половиной: читателей у неё два — подписка провода
/// и локальный `StartupStateRepository` десктопной кассы, — а был и третий,
/// HTTP-маршрут, и однажды они уже разошлись (маршрут не писал `hasUsers`,
/// хотя читатель его читал, и браузерный терминал вечно получал «пользователей
/// нет»). Здесь остался только перевод в форму провода.
Future<Map<String, Object?>> readSetupState(AppDatabase db) async =>
    setupStateToWireJson(await readSetupStateOf(db));

/// Находит копию по идентификатору сообщения.
///
/// Копию ищет сама касса — у неё уже есть их список, — и по проводу едет один
/// идентификатор, а не вся копия. `null` означает «такой копии нет», и
/// решение, чем это назвать, принимает вызывающий: HTTP отвечает 404, провод —
/// кадром отказа.
Future<FoundBackup?> findBackup(
  FirstLaunchRepository firstLaunch,
  int messageId,
) async {
  final backups = await firstLaunch.findAvailableBackups();
  return backups.where((backup) => backup.messageId == messageId).firstOrNull;
}
