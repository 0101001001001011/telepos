import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:talker/talker.dart';

import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/sale/offset_chain.dart';
import 'package:telepos/domain/payment/payment_kind_catalog.dart';
import 'package:telepos/data/shift/shift_age_rule.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/payment/local_credit_service.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
import 'package:telepos/data/payment/qr_payment_coordinator.dart' show QrGiveUp;
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/device/terminal_device_binding_resolver.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
// С префиксом: `FiscalQueueEntry` — имя и строки drift в
// `app_database.dart`, и записи очереди здесь; без префикса они
// сталкиваются.
import 'package:telepos/data/fiscal/offline_queueing_provider.dart' as fq;
import 'package:telepos/data/fiscal/ofd_policy.dart';
import 'package:telepos/data/sale/sale_receipt_composer.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/data/receipt/local_receipt_template_setup.dart';
import 'package:telepos/domain/sale/cart_service.dart' show cartStaleCode;
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/stock/stock_changes.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/usecases/agent/bonus_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_config.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_service.dart';

/// Открыть денежный ящик кассы — задача 16.
///
/// Порт, а не `CashDrawerService` доводом: тот класс живёт в
/// `lib/hardware/` и тянет `flutter_libserialport` (то есть `dart:ffi`), а
/// `lib/data/sale/` обязан оставаться собираемым для веба. Что именно
/// подставляется — последовательный порт с запасным путём через принтер —
/// решает сборка кассы (`service_locator.dart`), ровно как решала до
/// задачи 16 в `payment_screen._openCashDrawer`.
typedef CashDrawerOpener = Future<bool> Function();

/// Разговор с платёжным терминалом, отделённый от всего остального
/// доводом конструктора.
///
/// Не ради «чистоты»: `KaspiPosService` открывает настоящий сокет, и без
/// этого шва ни один тест оплаты картой не мог бы существовать, кроме как
/// с живым устройством на столе. Умолчание —
/// [LocalPaymentService.kaspiDriver] — то же самое, что делал
/// `PaymentNotifier.chargeCardViaTerminal` до этой задачи.
typedef CardTerminalDriver =
    Future<CardCharge> Function(
      KaspiPosConfig config, {
      required int amountTiyn,
      required String receiptNo,
    });

/// Кассовая реализация [PaymentService] — задача 14.
///
/// # Что перенесено и откуда
///
/// Из `PaymentNotifier` (`payment_controller.dart`, номера строк по
/// состоянию до правки):
///
/// | Перенесено | Откуда | Как легло |
/// | --- | --- | --- |
/// | список счетов | `paymentAccountsProvider`, `:785-812` | [accounts] |
/// | умолчание счёта | `_autoSelectBankAccount`/`_autoSelectPosAccount`, `:260-280` | [accounts] + `isDefault` |
/// | поиск клиента лояльности | `searchLoyaltyCustomer`, `:381-420` | [findLoyalty] |
/// | потолок бонуса | `setBonusToUse`, `:429-445` | [reserveBonus] + [complete] |
/// | привязка эквайринга | `_loadKaspiConfig`, `:469-497` | [_kaspiConfig] |
/// | оплата картой | `chargeCardViaTerminal`, `:499-565` | [chargeCard] |
/// | сбор платежей и завершение | `processPayment`, `:569-751` | [complete] |
/// | начисление кэшбэка | `_accrueCashback`, `:753-779` | [complete] |
///
/// # Три изменения смысла, названные, а не подразумеваемые
///
/// 1. **Сдачу считает касса.** Раньше её считал `PaymentState.change` на
///    экране и передавал в `completeSale`. Экран — это вкладка браузера,
///    и её число деньгами быть не может. Теперь считает [complete], а
///    присланное [PaymentRequest.claimedChange] только сверяется и, при
///    расхождении, пишется в журнал.
/// 2. **Эквайринг берётся у рабочего места, а не у кассы.**
///    `_loadKaspiConfig` спрашивал привязку через `TerminalRepository
///    .self()` — то есть всегда оборудование самой кассы. С [chargeCard]
///    имя рабочего места приходит доводом (а на проводе — из сеанса), и
///    браузерный терминал получает **свой** платёжный терминал.
/// 3. **Остатки больше не возвращаются перед каждой попыткой оплаты.**
///    Разбор этого места — ниже, у [complete]; коротко: с задачи 7 строки
///    чека лежат в базе с первой команды, и безусловный
///    `reverseSaleStock` перед подготовкой чека стал прибавлять остаток
///    товару, у которого его никто не отнимал.
///
/// # Почему она же — [QrProviderSetupHost]
///
/// Настройку провайдера правит **та самая стойка**, которой эта раскладка
/// берёт деньги по QR, и другого способа получить её у кассы нет: сторож
/// `qr_secret_never_reaches_terminal_test` требует единственного читателя
/// настройки, а отдельный сотрудник кассы позволил бы собрать её со второй
/// стойкой — правка адреса тогда не сбрасывала бы того клиента провайдера,
/// который на самом деле звонит. Разбор — в докстринге [QrProviderSetupHost].
/// # И она же — [ReceiptTemplateSetupHost]
///
/// Решение заказчика 2026-09-18. Довод **свой**, а не «по образцу соседа»:
/// шаблон чека кэшируется внутри службы печати (`_optionsCache`), и правка
/// обязана сбросить кэш того экземпляра, который напечатает следующий чек.
/// Отдельный сотрудник кассы позволил бы собрать её так, что печатает одна
/// служба печати, а кэш сбрасывает другая, — владелец правил бы подвал и
/// получал из принтера прежний. Здесь порт снимается с той самой раскладки,
/// которая чек и печатает. Разбор — в докстринге [ReceiptTemplateSetupHost].
class LocalPaymentService
    implements PaymentService, QrProviderSetupHost, ReceiptTemplateSetupHost {
  LocalPaymentService({
    required AppDatabase db,
    required SaleCheckoutService checkout,
    required SaleUseCase sale,
    required Talker logger,
    BonusService? bonuses,
    CardTerminalDriver? cardTerminal,
    required FiscalService fiscal,
    fq.FiscalQueueStore? fiscalQueue,
    ReceiptPrintService? printer,
    required CashDrawerOpener drawer,
    QrPaymentDesk? qr,
    StockChangeSink? stockChanges,
  }) : _db = db,
       _stockChanges = stockChanges,
       _checkout = checkout,
       _sale = sale,
       _logger = logger,
       _bonuses = bonuses,
       _cardTerminal = cardTerminal ?? kaspiDriver,
       _fiscal = fiscal,
       _fiscalQueue = fiscalQueue,
       _printer = printer,
       _drawer = drawer,
       _receipts = SaleReceiptComposer(db: db, logger: logger),
       _shiftAge = ShiftAgeRule(db: db),
       // Справочник видов оплаты собирается здесь, а не приходит
       // доводом: у него нет ни одного состояния, зависящего от
       // вызывающего, а требовать его от каждого стенда значило бы
       // сделать 40 проб зависимыми от детали, которая их не касается.
       _kinds = PaymentKindCatalogImpl(db),
       // Сертификаты — тем же приёмом и по тому же доводу, что
       // справочник видов строкой выше: своего состояния у выпускающего
       // нет, а требовать его от сорока стендов значило бы сделать их
       // зависимыми от детали, которая их не касается.
       _certificates = LocalCertificateIssuer(db: db, logger: logger),
       _credit = LocalCreditService(db: db, logger: logger),
       // Стойка QR — **необязательный довод с настоящим умолчанием**, а не
       // `null`: касса без довода получает рабочую стойку над своей же
       // базой, а не выключенный QR. Довод существует для DI (один
       // экземпляр на кассу, его же зовёт разбор при подъёме) и для проб
       // (часы, тайм-аут). Тот же приём, что у [_certificates], с одной
       // разницей: у стойки есть кэш провайдера, и двум экземплярам на
       // одной кассе делить нечего, но и ломаться не от чего.
       _qr = qr ?? QrPaymentDesk(db: db, logger: logger);

  final AppDatabase _db;

  /// Оплата по QR: настройка провайдера → координатор намерения.
  final QrPaymentDesk _qr;

  /// Настройка провайдера — **тот же экземпляр стойки**, что берёт деньги.
  /// Разбор, почему порт отдаётся отсюда, — в докстринге класса.
  @override
  QrProviderSetupRepository? get qrProviderSetup => _qr;

  /// Шаблон чека — над **той же службой печати**, которая печатает.
  ///
  /// `null`, когда печатать нечем: касса, собранная без очереди печати, не
  /// может ни напечатать образец, ни собрать предпросмотр из байтов (байты
  /// собирает она же). Ответить «сохранено» такой кассе было бы худшим из
  /// возможного — операция отказывает `receipt_templates_unavailable`.
  ///
  /// Собирается при первом обращении и держится: `LocalReceiptTemplateSetup`
  /// своего состояния не имеет, но новый экземпляр на каждое обращение
  /// означал бы новый объект на каждое нажатие клавиши в поле шапки —
  /// предпросмотр спрашивается с задержкой после каждой правки.
  ReceiptTemplateSetupRepository? _templates;

  @override
  ReceiptTemplateSetupRepository? get receiptTemplates {
    final printer = _printer;
    if (printer == null) return null;
    return _templates ??= LocalReceiptTemplateSetup(db: _db, printer: printer);
  }

  /// Выпуск и предъявление сертификата.
  ///
  /// Раскладка зовёт отсюда только [CertificateIssuer.lookup]: **гашение
  /// живёт не здесь**, а внутри транзакции продажи
  /// (`SaleUseCaseImpl.perform`). Разделение намеренное — списать до
  /// продажи значит подарить сертификат упавшему чеку, списать после —
  /// отдать товар даром.
  final CertificateIssuer _certificates;

  /// Рассрочка — задача 24. Заводится здесь, а не приходит доводом, по
  /// тому же образцу, что и [_certificates]: у службы нет состояния,
  /// кроме базы, и подменять её в пробах незачем — пробы ставят
  /// настоящие договоры в настоящую базу.
  final CreditService _credit;

  /// Справочник видов оплаты — **читатель, а не окно**.
  ///
  /// Существует затем, чтобы вид, выключенный оператором, был выключен и
  /// для кассы. Без такого читателя справочник был бы настройкой,
  /// которая ничего не меняет, — а на неё полагаются.
  final PaymentKindCatalog _kinds;
  final SaleCheckoutService _checkout;
  final SaleUseCase _sale;
  final Talker _logger;

  // ── три действия кассы по завершении оплаты (задача 16) ──────────────
  //
  // Решение заказчика №1: терминал продаёт полностью, но **железо и база
  // остаются кассой**. До задачи 16 два из трёх действий жили в
  // `payment_screen.dart` — то есть на терминале, у которого нет ни
  // принтера, ни ящика, ни базы. Касса без принтера или без ящика
  // продолжает торговать, а не останавливается. С задачи 41 ящик —
  // обязательный порт, и «ящика нет» — видимая беда, а не `null`; печать
  // пока необязательна, и это названо в
  // `test/architecture/absent_dependency_is_named_test.dart`.
  // Фискальный порт из этого ряда вышел задачей 3 — разбор ниже.

  /// Фискальный оператор — **необнуляемый и обязательный** довод.
  ///
  /// # Здесь сторожит компилятор, а не проба
  ///
  /// Забыть этот порт нельзя: `LocalPaymentService(...)` без `fiscal:` не
  /// собирается. Третьего сторожа под это писать не надо, и особенно —
  /// исходно-сканирующего, вида «нет полей `XxxService?`»: такая проба
  /// бывает зелена по построению (ничего не нашла — значит прошла) и
  /// обходится переименованием поля.
  ///
  /// # Почему обнуляемость пришлось убрать
  ///
  /// Она была не осторожной деградацией, а её видимостью. Из 14 мест
  /// сборки службы **8 не передавали довод вовсе** — измерено, а не
  /// выведено из чтения, — и ни одно из восьми не собиралось утверждать
  /// «фискального узла в кассе нет»: они про него попросту не думали.
  /// [_fiscalize] выходил первой же строкой, и чек объявлялся
  /// нефискальным по забывчивости строителя, а не по устройству кассы.
  ///
  /// Теперь «узла нет» — утверждение, а не умолчание: его пишут именем,
  /// `RefusingFiscalService`. Тот же приём, которым в августе закрыли
  /// авторизацию операций провода: требование, ставшее типом, нельзя
  /// обойти незаметно.
  ///
  /// [FiscalState.fiscalModuleAbsent] от этого не умер и не переехал в
  /// мёртвые: он отвечает именно на `RefusingFiscalService`, и как —
  /// разобрано в [_fiscalize].
  final FiscalService _fiscal;

  /// Очередь фискализации — **место для записи о беде**, а не для
  /// повтора. `null` — записать некуда, и тогда отказ живёт только в
  /// журнале; см. докстринг [SaleOutcome.fiscal].
  final fq.FiscalQueueStore? _fiscalQueue;

  /// Очередь печати. `null` — печатать нечем.
  final ReceiptPrintService? _printer;

  /// Денежный ящик — **обязательный** порт (задача 41).
  ///
  /// Прежде `null` значил «ящика нет» и давал тот же исход, что «ящик
  /// открылся»: касса, собранная без ящика, была неотличима от исправной. В
  /// сборке кассы порт передаётся всегда (`service_locator.dart`,
  /// `_openCashDrawer`), и что ящика в настройке нет, он отвечает сам —
  /// «не открылся», то есть бедой, которую видно на экране и в журнале.
  final CashDrawerOpener _drawer;

  /// «Остатки изменились» — пункт 12 ревизии 2026-09-19. `null` означает
  /// «некому сказать»: голый процесс без контейнера. Тишина здесь не
  /// дефект — счётчика просто нет, а продажа от этого не страдает.
  final StockChangeSink? _stockChanges;

  final SaleReceiptComposer _receipts;

  /// Отправленные, но ещё не доигранные действия железа — **только для
  /// проб**.
  ///
  /// Печать и ящик уходят [unawaited]: правило «оплата не ждёт железа»
  /// по проводу становится строже, потому что к задержке принтера
  /// прибавилась бы сеть. Значит у пробы нет другого способа дождаться
  /// их, кроме этой ручки; продукт её не читает и читать не должен —
  /// ожидание здесь и есть то, что задача убирает.
  Future<void> _sideEffects = Future<void>.value();

  /// См. [_sideEffects].
  @visibleForTesting
  Future<void> get pendingSideEffects => _sideEffects;

  /// Начисление кэшбэка. `null` — не начисляем вовсе: осторожная
  /// деградация тем же приёмом, что у необязательных портов
  /// `TillOperations`. Начисление и до этой задачи было необязательным —
  /// `_accrueCashback` ловила всё подряд и называла себя «non-blocking».
  final BonusService? _bonuses;

  /// Потолок возраста смены (I1) — **правило над базой кассы, а не порт**
  /// (задача 27). Прежде здесь стоял необязательный `ShiftService?`, и касса,
  /// собранная без него, брала деньги в смене любого возраста. Смена лежит в
  /// той же базе, что и чек: проверить есть чем всегда.
  final ShiftAgeRule _shiftAge;

  final CardTerminalDriver _cardTerminal;

  static const _stateInProgress = 0;

  /// `Sales.state` чека, **занятого под оплату**, — задача 8.
  ///
  /// # Зачем понадобилось состояние, а не один только ключ
  ///
  /// До задачи 8 условная запись «занять чек» писала **только**
  /// `lastCommandKey`, оставляя `state = 0`. Значит второй гонщик с
  /// другим ключом проходил её условие целиком — оно ничего не
  /// утверждало о том, что чек уже занят. Разводил двоих не этот заслон,
  /// а уникальный ключ `Payments` `{receiptNo, posId, payeeAccountId}` на
  /// вставке платежей, и стрелял он **после** того, как первый взял
  /// деньги, сырым `SqliteException(2067)`.
  ///
  /// **Замерено, а не выведено** (`payment_claim_race_test.dart`): двум
  /// гонщикам достаточно попасть на **разные** счета получателя —
  /// наличные на счёт кассы, карта на банковский, — и уникальный ключ
  /// молчит вовсе. С чека на 1000 собиралось 2000.
  ///
  /// # Почему `lastCommandKey IS NULL OR = :key` в одиночку не годится
  ///
  /// Спека предлагала ровно это условие. Оно ломает оплату целиком, и это
  /// тоже замер: `LocalCartService._writeVersion` пишет `lastCommandKey`
  /// **на каждую команду корзины**, поэтому к моменту оплаты он никогда
  /// не `NULL` и никогда не равен ключу команды оплаты. Занятость обязана
  /// жить в `state`; ключ отвечает на другой вопрос — **чьё** это
  /// занятие.
  ///
  /// # Значение 2
  ///
  /// Свободно: у `Sales` заняты 0 (в работе), 1 (ожидает отправки),
  /// 3 (отложен), 4 (синхронизирован) — измерено перечислением всех
  /// литералов состояния в `lib/`. Наружу кассы это состояние не уезжает:
  /// синхронизация берёт 1 и 4.
  ///
  /// # Что остаётся неприятным и названо прямо
  ///
  /// Занятие снимается [_releaseClaim] на **любой** неудаче записи денег,
  /// так что чек не запирается ни отказом, ни исключением. Не снимается
  /// оно только смертью процесса ровно между занятием и транзакцией
  /// `perform` (окно — одна транзакция drift). После такой смерти чек
  /// остаётся занятым, из `saleDao.findInProgress` (там `state = 0`)
  /// пропадает, и оплатить его может лишь повтор **с тем же ключом**.
  /// Это хуже прежнего поведения в одном этом случае и лучше в том,
  /// который случается всерьёз, — деньги не берутся дважды.
  static const _stateClaimedForPayment = 2;

  /// Тиыны/копейки в тенге — то же число, с которым `chargeCardViaTerminal`
  /// переводила сумму для эквайринга.
  static final _hundred = Decimal.fromInt(100);

  /// Память о проведённых картах: **рабочее место + чек + сумма + ключ**
  /// → её ответ.
  ///
  /// # Почему ключа команды мало — измерено, а не предположено
  ///
  /// Первая версия ключевала одним `meta.key` и отдавала запомненное
  /// **до всех проверок**. Круг правки 1 нашёл на этом две пробы, и обе
  /// про деньги:
  ///
  /// - тот же ключ с другой суммой (1000 → 400) возвращал ответ **на
  ///   1000**, к устройству не обращаясь;
  /// - тот же ключ на **другом чеке** отдавал чужое одобрение и чужую
  ///   сумму.
  ///
  /// Достижимо экраном, а не только рукописным кадром: ключ мнётся один
  /// раз на попытку оплаты и сбрасывается только на успехе, то есть
  /// переживает и отказ завершения, и правку корзины, и смену чека.
  /// Цепочка кончалась тем, что следующая оплата картой **не шла на
  /// устройство**, а чек считался оплаченным: товар отдан, банк не
  /// тронут.
  ///
  /// Поэтому ключ составной, и все четыре его части сверяются при выдаче
  /// (`_cardChargeKey`): совпал ключ команды, но разошлись чек или сумма
  /// — это **не повтор**, а новое проведение.
  ///
  /// # Пределы
  ///
  /// Память живёт в процессе кассы и перезапуск не переживает: настоящего
  /// места для неё нет — у проведённой карты в схеме нет своей строки до
  /// тех пор, пока чек не оплачен (`Payments` пишет только
  /// `SaleUseCase.perform`), а заводить под это миграцию — работа со
  /// своей спекой. Что защита закрывает: повтор запроса вкладкой, не
  /// дождавшейся ответа. Чего не закрывает: повтор после перезапуска
  /// кассы. Дублирующая защита самого платёжного терминала нам не
  /// принадлежит и на неё здесь не рассчитывают.
  ///
  /// **Хранится обещание, а не ответ** (круг правки 5). Прежняя версия
  /// клала в память **готовый** ответ — то есть читала запись, **ждала
  /// устройство**, и только потом писала. Два одновременных одинаковых
  /// запроса (двойное нажатие «Оплатить») проходили лукап оба и списывали
  /// карту **дважды**: `terminal.calls == [50000, 50000]`, два настоящих
  /// списания. Докстринг при этом обещал закрыть ровно «повтор запроса
  /// вкладкой, не дождавшейся ответа» — и не закрывал.
  ///
  /// Теперь место занимается **до** ожидания: между чтением памяти и
  /// записью в неё нет ни одного `await`, а второй запрос получает то же
  /// самое обещание и тот же ответ. Обещание, кончившееся ошибкой, из
  /// памяти снимается — иначе одна неудача устройства запирала бы ключ
  /// навсегда.
  ///
  /// Записи чека снимаются, когда он **оплачен** ([_forgetCharges]).
  ///
  /// **Предел, названный точно, а не обещанием:** это единственный способ,
  /// которым карта чистится. Чек, брошенный после проведения карты
  /// (кассир ушёл, вкладку закрыли, смена кончилась), оставляет свои
  /// записи до перезапуска кассы. Размер записи мал, а чистка по времени
  /// потребовала бы часов, которых у этого класса нет; названо здесь,
  /// чтобы следующий не принял «чистится» за «чистится всегда».
  final _cardCharges = <String, Future<CardCharge>>{};

  /// Составной ключ памяти о проведении карты — см. [_cardCharges].
  static String _cardChargeKey({
    required int terminalId,
    required int receiptNo,
    required Decimal amount,
    required String commandKey,
  }) => '$terminalId/$receiptNo/$amount/$commandKey';

  // ── счета ─────────────────────────────────────────────────────────────

  /// Счета, на которые касса принимает деньги, — и **граница
  /// безопасности**: [_bankAccountId] сверяет названный терминалом счёт
  /// именно с этим списком.
  ///
  /// **Предел, названный замером (круг правки 3):** признак умолчания
  /// помечает **каждый** кассовый счёт, а не тот, который назначен кассе
  /// (`ThisPos.accountId`). При двух видимых кассовых счетах экран выберет
  /// первый по выборке, и это может быть не тот, на который касса кладёт
  /// наличные. Деньгами это не грозит — наличная часть счёт из списка не
  /// читает вовсе ([_posAccountId]), — но кассиру показывается «умолчание»,
  /// которое умолчанием не является. Чинится сверкой с `ThisPos.accountId`
  /// здесь же; не сделано, потому что это меняет то, что видит кассир, а
  /// круг правки чинит найденное, а не улучшает соседнее.
  @override
  Future<List<PaymentAccount>> accounts() async {
    // Порядок тот же, что был у `paymentAccountsProvider`: счета кассы
    // первыми — умолчание для наличных. Разница одна: там пары «счета
    // кассы» и «банковские» собирались в обратном порядке
    // (`[...posAccounts, ...accounts]` при чтении банковских первыми), и
    // читать это приходилось дважды, чтобы убедиться, что умолчание не
    // уехало.
    // **По видимости — оба вида, а не половина** (круг правки 3). Круг 2
    // сделал этот список границей безопасности: `_bankAccountId` сверяет
    // названный счёт именно с ним. Кассовые счета шли мимо признака
    // видимости, и скрытый от кассы счёт предлагался браузеру — а значит
    // и принимался, — тогда как скрытый банковский в тех же условиях
    // отвергался.
    //
    // Названное следствие: счёт с `visibleToPos = null` (колонка
    // нулимая) в список не попадает. Это то же правило, по которому
    // банковская половина жила с самого начала, а не новое: «не помечен
    // видимым» и значит «скрыт». Наличную часть это не трогает вовсе —
    // её счёт берёт [_posAccountId] из `ThisPos.accountId`, а не отсюда.
    final pos = await _db.accountDao.findByTypeAndVisibility(
      AccountType.pos,
      true,
    );
    final bank = await _db.accountDao.findByTypeAndVisibility(
      AccountType.customBank,
      true,
    );
    return [
      for (final a in pos)
        PaymentAccount(
          id: a.id,
          name: a.name ?? 'Счёт ${a.id}',
          isDefault: true,
        ),
      for (final a in bank)
        PaymentAccount(id: a.id, name: a.name ?? 'Счёт ${a.id}'),
    ];
  }

  // ── продажа в долг: тумблер кассы ─────────────────────────────────────

  /// Первый читатель `ThisPosEntries.sellInDebt` — задача 16.
  ///
  /// Колонка существует с самого начала, пишется мастером настройки
  /// (`SetupRepositoryLocal`, `business.allowDebtSales`) и до этой задачи
  /// не читалась **ничем** во всём `lib/`. Читателя два, и оба здесь:
  /// этот отвечает экрану, [_requireDebtSoldHere] отвечает кадру.
  ///
  /// Нет строки настроек — `false`. Умолчание обязано быть тем, которое
  /// ничего не разрешает: касса до мастера настройки не торгует в кредит.
  @override
  Future<bool> sellsInDebt() async =>
      (await _db.thisPosDao.get())?.sellInDebt ?? false;

  // ── лояльность ────────────────────────────────────────────────────────

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) async {
    // Отсев коротких номеров остался на экране (`searchLoyaltyCustomer`
    // проверяла длину до обращения к базе) — кассир набирает номер по
    // цифре, и посылать по проводу каждую цифру значило бы платить кругом
    // сети за нажатие. Здесь — только то, что умеет одна касса.
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final asInt = int.tryParse(digits);
    if (asInt == null) return null;

    final agent = await _db.agentDao.findByPhone(asInt);
    if (agent == null) return null;

    return LoyaltyCustomer(
      id: agent.localId,
      phone: phone,
      name: agent.name ?? 'Клиент',
      bonusBalance: await _bonusBalanceOf(agent.cashbackAccountId),
    );
  }

  Future<Decimal> _bonusBalanceOf(int? cashbackAccountId) async {
    if (cashbackAccountId == null) return Decimal.zero;
    final account = await _db.accountDao.findById(cashbackAccountId);
    return account?.value ?? Decimal.zero;
  }

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) async {
    final agent = await _db.agentDao.findByLocalId(customerId);
    if (agent == null) {
      throw WireRefusal(
        payCustomerUnknownCode,
        'клиента $customerId нет в картотеке',
      );
    }
    if (amount <= Decimal.zero) return Decimal.zero;
    final balance = await _bonusBalanceOf(agent.cashbackAccountId);
    // Потолок один — остаток. Второй потолок (сумма чека) накладывает
    // [complete]: у этого метода нет ни рабочего места, ни чека, значит и
    // суммы (докстринг контракта).
    return amount > balance ? balance : amount;
  }

  // ── вход в зачёт аванса и гашение сертификата ─────────────────────────

  @override
  Future<Decimal> prepaymentBalance(int customerId) async {
    // Вид — первым: на кассе, где аванс не принимают, кассиру незачем
    // узнавать ни о покупателе, ни о его счёте. Та же проверка, которой
    // ответит [complete] (`payment_kind_inactive`), — и тем же словом.
    await _requireKindActive(SystemPaymentKindIds.prepayment);
    final agent = await _db.agentDao.findByLocalId(customerId);
    if (agent == null) {
      throw WireRefusal(
        payCustomerUnknownCode,
        'клиента $customerId нет в картотеке',
      );
    }
    final accountId = agent.mainAccountId;
    if (accountId == null) {
      throw const WireRefusal(
        payPrepaymentAccountMissingCode,
        'у покупателя нет расчётного счёта — аванса на нём быть не может',
      );
    }
    final value =
        (await _db.accountDao.findById(accountId))?.value ?? Decimal.zero;
    // Минус на расчётном счёте — долг покупателя, а не аванс.
    return value > Decimal.zero ? value : Decimal.zero;
  }

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) async {
    await _requireKindActive(SystemPaymentKindIds.certificate);
    final found = await _certificates.lookup(number: number, pin: pin);
    if (found.liabilityAccountId == null) {
      // Тот же отказ, которым ответила бы раскладка ([_plan]), — но
      // раньше, до того как кассир набрал остальную оплату.
      throw WireRefusal(
        certificateAccountMissingCode,
        'у сертификата ${found.number} нет счёта обязательства',
      );
    }
    return found;
  }

  // ── оплата по QR/СБП: вход ────────────────────────────────────────────

  @override
  Future<String?> qrUnavailableReason() async {
    // Те же две проверки и в том же порядке, что первые строки [startQr]:
    // экран обязан услышать при открытии ту причину, что услышал бы на
    // нажатии.
    try {
      await _requireKindActive(SystemPaymentKindIds.qr);
      await _qr.require();
      return null;
    } on WireRefusal catch (refusal) {
      return refusal.code;
    }
  }

  @override
  Future<QrTender> startQr(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) async {
    // Порядок отказов — от дешёвого к дорогому и от настройки к чеку: вид
    // и провайдер кассы не зависят от того, какой чек открыт.
    await _requireKindActive(SystemPaymentKindIds.qr);
    final desk = await _qr.require();

    final posId = await _posId();
    final sale = await _db.saleDao.findInProgress(
      posId: posId,
      terminalId: terminalId,
    );
    if (sale == null) {
      throw const WireRefusal(
        payReceiptNotFoundCode,
        'чек не начат на этом рабочем месте',
      );
    }
    if (amount <= Decimal.zero) {
      throw const WireRefusal(
        payInsufficientCode,
        'сумма к оплате по QR должна быть больше нуля',
      );
    }
    // Потолок — сумма чека, тот же, что у карты. Сдачи QR не даёт, и код
    // на сумму больше чека был бы приглашением заплатить деньги, которым
    // в чеке нет места.
    if (amount > sale.amount) {
      throw const WireRefusal(
        payAmountExceedsReceiptCode,
        'сумма по QR больше стоимости чека',
      );
    }

    // Ключ намерения — **из того, что знает касса**, и ключа попытки,
    // который прислал экран. Рабочее место и чек в нём затем, чтобы
    // одинаковый ключ попытки с двух вкладок не нашёл чужое намерение;
    // сумма — затем, чтобы правка суммы в той же попытке не вернула
    // прежний код на прежнюю сумму.
    final intentKey =
        'qr-$posId-$terminalId-${sale.receiptNo}-$amount-${meta.key}';

    // Брошенные коды — до проверки «на чеке уже ждёт»: иначе вкладка,
    // закрытая посреди ожидания, заперла бы свой чек до перезапуска кассы.
    await _qr.sweepStale(desk);
    final live = await _db.paymentIntentDao.liveForReceipt(
      posId: posId,
      receiptNo: sale.receiptNo,
    );
    final other = live.where((i) => i.intentKey != intentKey);
    if (other.isNotEmpty) {
      throw WireRefusal(
        payQrIntentLiveCode,
        'на чеке ${sale.receiptNo} уже ждёт код QR на ${other.first.amount}',
      );
    }

    final begun = await desk.coordinator.begin(
      intentKey: intentKey,
      amount: amount,
      posId: posId,
      receiptNo: sale.receiptNo,
      terminalId: terminalId,
    );
    _logger.info(
      'Payment: QR intent $intentKey amount=$amount '
      'created=${begun.createdNow} refusal=${begun.refusal?.code}',
    );
    return QrTender.of(
      begun.intent!,
      patience: desk.patience,
      now: _qr.now(),
      refusalCode: begun.refusal?.code,
    );
  }

  @override
  Future<QrTender> pollQr(int terminalId, String intentKey) async {
    final desk = await _qr.require();
    final intent = await _ownQrIntent(terminalId, intentKey);
    String? refusal;
    if (!intent.status.isTerminal) {
      if (intent.abandonedAt != null) {
        // **Касса уже сдалась, а отмена до провайдера не дошла**
        // (`cancelUnconfirmed`). Ждать тут нечего — повторяется отмена, и
        // её ответ читается: провайдер мог за это время принять оплату.
        // Отметка `abandonedAt` при этом не сдвигается (условная запись).
        await desk.coordinator.abandon(intent.id, why: QrGiveUp.cashier);
      } else {
        // Один круг. Срок — от заведения намерения плюс терпение
        // **кассы**; круг после срока отменяет код у провайдера сам.
        final round = await desk.coordinator.step(
          intent.id,
          deadline: intent.createdAt.add(desk.patience),
        );
        refusal = round.refusal?.code;
      }
    }
    return QrTender.of(
      (await _db.paymentIntentDao.byId(intent.id))!,
      patience: desk.patience,
      now: _qr.now(),
      refusalCode: refusal,
    );
  }

  @override
  Future<QrTender> cancelQr(int terminalId, String intentKey) async {
    final desk = await _qr.require();
    final intent = await _ownQrIntent(terminalId, intentKey);
    if (!intent.status.isTerminal) {
      // Отмена у провайдера **с чтением ответа** — `abandon` координатора.
      // «Уже оплачено» здесь не ошибка, а фаза `paidAfterGiveUp`.
      await desk.coordinator.abandon(intent.id, why: QrGiveUp.cashier);
    }
    final after = (await _db.paymentIntentDao.byId(intent.id))!;
    _logger.info(
      'Payment: QR intent $intentKey cancelled by cashier → '
      '${after.status.code} abandonedAt=${after.abandonedAt}',
    );
    return QrTender.of(after, patience: desk.patience, now: _qr.now());
  }

  /// Намерение этого рабочего места — или отказ, неотличимый от «нет».
  ///
  /// **Намерение без рабочего места не принадлежит никому** (пункт 10 C,
  /// 2026-09-15). Прежде проверка стояла только у намерений с `terminalId`,
  /// и строку без места опрашивал и отменял любой терминал, знающий ключ.
  /// `startQr` такой строки не заводит, но она достижима (засев стенда,
  /// ручная правка, будущий путь без довода `claim`); её деньги — «деньги
  /// без чека», и разбирает их человек (`orphanMoney`), а не вкладка.
  Future<PaymentIntent> _ownQrIntent(int terminalId, String intentKey) async {
    final intent = await _db.paymentIntentDao.byKey(intentKey);
    if (intent == null || intent.terminalId != terminalId) {
      throw WireRefusal(
        payQrIntentUnknownCode,
        'намерения QR «$intentKey» нет у этого рабочего места',
      );
    }
    return intent;
  }

  /// Вид оплаты [kindId] есть в справочнике и включён.
  ///
  /// Те же два отказа и тем же словом, что в проверке строк раскладки
  /// ([_plan]): экран, спросивший остаток, обязан услышать ту же причину,
  /// которую услышит оплата.
  Future<void> _requireKindActive(int kindId) async {
    final kind = await _kinds.byId(kindId);
    if (kind == null) {
      throw WireRefusal(
        payKindUnknownCode,
        'вида оплаты $kindId нет в справочнике кассы',
      );
    }
    if (!kind.isActive) {
      throw WireRefusal(
        payKindInactiveCode,
        'вид оплаты «${kind.name}» выключен в настройках кассы',
      );
    }
  }

  // ── карта ─────────────────────────────────────────────────────────────

  @override
  Future<CardCharge> chargeCard(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) async {
    // Проведение карты через эквайринг — это оплата картой, чем бы её ни
    // назвали в теле кадра. Проверка первой строкой, до чтения чека и до
    // разговора с устройством: отказ по настройке рабочего места не имеет
    // причин ждать, пока найдётся чек.
    await _requireAllowedTypes(terminalId, const {PaymentType.card});

    final posId = await _posId();
    final sale = await _db.saleDao.findInProgress(
      posId: posId,
      terminalId: terminalId,
    );
    if (sale == null) {
      throw const WireRefusal(
        payReceiptNotFoundCode,
        'чек не начат на этом рабочем месте',
      );
    }
    if (amount <= Decimal.zero) {
      throw const WireRefusal(
        payInsufficientCode,
        'сумма к оплате картой должна быть больше нуля',
      );
    }
    // Потолок ставит касса, а не вкладка: сумма чека посчитана из строк
    // в её базе и поддержана каждой командой корзины (задача 7). Молча
    // урезать было бы хуже отказа — кассир увидел бы на терминале не то,
    // что нажал, и не узнал бы почему.
    if (amount > sale.amount) {
      _logger.warning(
        'Payment: card charge above receipt total '
        'asked=$amount receipt=${sale.receiptNo} total=${sale.amount}',
      );
      throw const WireRefusal(
        payAmountExceedsReceiptCode,
        'сумма больше стоимости чека',
      );
    }

    // Память спрашивается **после** того, как выяснено, о каком чеке и о
    // какой сумме речь: ключ команды сам по себе не отвечает ни на один
    // из этих вопросов (см. докстринг [_cardCharges]).
    final memoKey = _cardChargeKey(
      terminalId: terminalId,
      receiptNo: sale.receiptNo,
      amount: amount,
      commandKey: meta.key,
    );
    final remembered = _cardCharges[memoKey];
    if (remembered != null) {
      _logger.info(
        'Payment: card charge repeat key=${meta.key} '
        'receipt=${sale.receiptNo} amount=$amount',
      );
      return remembered;
    }

    // **Между чтением памяти и записью в неё нет `await`** — в этом вся
    // правка круга 5: одновременный близнец увидит уже занятое место.
    // Запоминается **любой** исход, а не только одобрение: отказ
    // терминала — тоже событие, случившееся один раз.
    final pending = _runCharge(terminalId, amount, sale.receiptNo);
    _cardCharges[memoKey] = pending;
    return pending.catchError((Object error) {
      // Неудача не имеет права запереть ключ навсегда: устройство могло
      // быть занято, и следующая попытка обязана дойти до него.
      _cardCharges.remove(memoKey);
      throw error;
    });
  }

  /// Настоящее обращение к устройству — тело обещания из [_cardCharges].
  Future<CardCharge> _runCharge(
    int terminalId,
    Decimal amount,
    int receiptNo,
  ) async {
    final config = switch (await _terminalBinding(terminalId)) {
      _NoTerminal() => null,
      // Задача 41: сломанная привязка — ошибка настройки, и называется она
      // отказом, а не ручным путём.
      _BrokenBinding(:final reason) => throw WireRefusal(
        payTerminalMisconfiguredCode,
        reason,
      ),
      _BoundTerminal(:final config) => config,
    };
    if (config == null) {
      _logger.info(
        'Payment: no payment terminal bound to terminal=$terminalId — '
        'manual card path',
      );
      return const CardCharge(outcome: CardChargeOutcome.notConfigured);
    }

    final charge = await _cardTerminal(
      config,
      amountTiyn: (amount * _hundred).round().toBigInt().toInt(),
      receiptNo: '$receiptNo',
    );
    return CardCharge(
      outcome: charge.outcome,
      amount: amount,
      approvalCode: charge.approvalCode,
      cardMask: charge.cardMask,
      transactionId: charge.transactionId,
      message: charge.message,
    );
  }

  /// Что у **этого** рабочего места с платёжным терминалом — задача 41.
  ///
  /// Три исхода, а не «конфиг или `null`». Прежний `_kaspiConfig` отдавал
  /// `null` и на «привязки нет», и на «привязок больше одной», и на «у
  /// привязки нет адреса», и на «параметры не читаются» — и каждый вызывающий
  /// падал на ручной путь карты, где касса принимает код одобрения, не имея
  /// доказательства. «Нет терминала» — законный ручной путь; остальное —
  /// ошибка настройки, и называется она отказом [payTerminalMisconfiguredCode].
  Future<_TerminalBinding> _terminalBinding(int terminalId) async {
    try {
      final bindings = await resolveTerminalDeviceBindings(
        database: _db,
        terminalId: terminalId,
        catalog: BuiltinDeviceProfileCatalog(),
        deviceClass: DeviceClass.paymentTerminal,
      );
      // Резолвер **молча** пропускает строку, не прошедшую проверку профиля
      // (нет обязательного адреса, неизвестный профиль): «одна кривая строка
      // не должна останавливать остальные устройства». Для оплаты это та же
      // дыра, что и здесь до задачи 41: сломанная привязка неотличима от
      // «терминала нет». Поэтому сырые включённые строки считаются отдельно,
      // и расхождение с резолвером — отказ, а не ручной путь. Измерено
      // пробой «привязка без адреса…»: без этой сверки чек оплачивался.
      final rows = (await _db.terminalDao.deviceBindingsFor(terminalId))
          .where(
            (r) =>
                r.enabled && r.deviceClass == DeviceClass.paymentTerminal.name,
          )
          .length;
      if (rows == 0) return const _NoTerminal();
      if (bindings.length != rows) {
        return const _BrokenBinding(
          'привязка платёжного терминала не прошла проверку профиля — '
          'не указан обязательный параметр или профиль неизвестен',
        );
      }
      if (bindings.length > 1) {
        return _BrokenBinding(
          'к рабочему месту привязано платёжных терминалов: '
          '${bindings.length} — касса не выбирает за кассира',
        );
      }

      final binding = bindings.single;
      final host = binding.parameters['ipAddress']?.trim();
      if (host == null || host.isEmpty) {
        return const _BrokenBinding(
          'у привязки платёжного терминала не указан адрес',
        );
      }
      final port =
          int.tryParse(binding.parameters['port'] ?? '') ??
          KaspiPosConfig.defaultPort;
      final config = KaspiPosConfig(host: host, port: port, enabled: true);
      if (!config.isValid) {
        return const _BrokenBinding(
          'параметры привязки платёжного терминала неверны',
        );
      }
      return _BoundTerminal(config);
    } catch (e) {
      // Нечитаемые параметры привязки — та же ошибка настройки, что и
      // сломанная привязка, а не «терминала нет» (так было до задачи 41).
      _logger.warning('Payment: payment terminal binding unreadable: $e');
      return const _BrokenBinding(
        'привязка платёжного терминала не читается — проверьте настройки '
        'оборудования',
      );
    }
  }

  /// Настоящий разговор с платёжным терминалом Kaspi — умолчание
  /// [CardTerminalDriver].
  ///
  /// **Прогоном не покрыт и покрыт быть не может** тем же способом, что
  /// всё остальное в этом файле: `KaspiPosService` открывает сокет к
  /// устройству. Ровно поэтому он и отделён доводом конструктора — всё,
  /// что вокруг него (потолок суммы, память о повторе, привязка), под
  /// прогоном; непроверенным остаётся только перевод одного ответа в
  /// другой. Проверяется живьём, задача 21.
  static Future<CardCharge> kaspiDriver(
    KaspiPosConfig config, {
    required int amountTiyn,
    required String receiptNo,
  }) async {
    final service = KaspiPosService(config: config);
    try {
      final result = await service.requestPayment(
        amountKopeiki: amountTiyn,
        receiptNo: receiptNo,
      );
      if (result.success) {
        return CardCharge(
          outcome: CardChargeOutcome.approved,
          approvalCode: result.approvalCode,
          cardMask: result.cardMask,
          transactionId: result.transactionId,
        );
      }
      return CardCharge(
        outcome: CardChargeOutcome.declined,
        message: result.errorMessage,
      );
    } finally {
      service.dispose();
    }
  }

  // ── завершение оплаты ─────────────────────────────────────────────────

  /// Завершить оплату.
  ///
  /// # Повтор: чем он узнаётся и почему именно так
  ///
  /// Ключ команды пишется в `Sales.lastCommandKey` **после** того, как
  /// чек подготовлен, и в том же условном обновлении, которым чек
  /// «занимается» под оплату — а занятие с задачи 8 **переводит
  /// состояние** (`_stateClaimedForPayment`), а не пишет один ключ.
  /// Порядок выбран так, что ни одна авария не берёт деньги дважды:
  ///
  /// - авария **до** занятия — чек всё ещё в работе, повтор проходит
  ///   обычным путём и оплачивает его один раз;
  /// - авария **после** `perform` — чек оплачен, ключ записан, повтор
  ///   узнан и возвращает тот же итог;
  /// - авария **между** ними (занятие прошло, `perform` упал) — занятие
  ///   снимается [_releaseClaim], чек возвращается в работу, и повтор
  ///   проходит обычным путём **с любым ключом**: ключ провода мнётся на
  ///   каждую попытку заново, и требовать прежний значило бы запереть чек;
  /// - смерть **процесса** ровно между занятием и `perform` — снимать
  ///   занятие некому, и чек остаётся занятым до повтора **тем же
  ///   ключом**. Единственный случай, ставший от задачи 8 хуже, и он
  ///   назван прямо в докстринге [_stateClaimedForPayment].
  ///
  /// Единственный случай, который остаётся неприятным и назван прямо:
  /// `perform` **записал деньги, но упал после своей транзакции** — тогда
  /// ключ не записан, чек оплачен, и повтор получит
  /// [payAlreadyTakenCode]. Это отказ, а не вторая оплата: деньги взяты
  /// один раз, кассиру сказано словами. Сегодня этот путь недостижим —
  /// всё, что идёт после транзакции `perform` (фискализация, ЭСФ),
  /// ловит свои исключения само.
  ///
  /// # Остатки: чего здесь больше нет
  ///
  /// `completeSale` звал `SaleUseCase.reverseSaleStock` **перед каждой**
  /// подготовкой чека — наследство времён, когда корзина жила в памяти
  /// экрана и строки чека появлялись в базе только при завершении
  /// продажи: тогда `findBySale` возвращала строки **прошлой** попытки, и
  /// возврат остатков был честной отменой. С задачи 7 строки лежат в базе
  /// с первой команды, и тот же вызов стал прибавлять остаток товару, у
  /// которого его никто не отнимал: на удачном пути это +q и сразу −q
  /// (незаметно), а на **любом отказе подготовки** (маркируемый товар без
  /// марки, нехватка остатка, потолок суммы) прибавка оставалась
  /// навсегда. Здесь возврата остатков нет вовсе: единственный путь, на
  /// котором остаток действительно был списан, — отмена уже проведённой
  /// оплаты, а её круг правки 1 убрал целиком (докстринг
  /// [payAlreadyTakenCode]).
  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) {
    // **Место занимается до первого `await`** — тем же приёмом и по той же
    // измеренной причине, что у памяти о проведении карты
    // ([_cardCharges], круг правки 5 задачи 14).
    //
    // Найдено пробой задачи 16 на одновременность: два одинаковых
    // завершения, пущенных разом (двойное нажатие, вкладка, не дождавшаяся
    // ответа), проходили сверку «чек ещё в работе» **оба** — и второе
    // падало сырым `SqliteException(2067): UNIQUE constraint failed:
    // payments...` уже после того, как первое взяло деньги. То есть
    // терминалу приходило «не получилось» о том, что получилось, да ещё и
    // нутром sqlite наружу (I144).
    //
    // Ключ — рабочее место, чек и ключ команды: тот же ключ на другом чеке
    // повтором не является.
    final inFlight = '$terminalId/${meta.receiptNo}/${meta.key}';
    final running = _completions[inFlight];
    if (running != null) {
      _logger.info('Payment: complete joined in-flight $inFlight');
      return running;
    }
    final started = _complete(terminalId, request, meta);
    _completions[inFlight] = started;
    // Запись снимается и на ошибке: иначе одна неудача заперла бы ключ
    // навсегда, и повтор кассира не прошёл бы вовсе.
    return started.whenComplete(() => _completions.remove(inFlight));
  }

  /// Завершения, уже идущие прямо сейчас, — см. [complete].
  final _completions = <String, Future<SaleOutcome>>{};

  Future<SaleOutcome> _complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) async {
    // Вид оплаты, названный заявкой, — раньше всего остального: у отказа по
    // настройке рабочего места нет причин ждать ни чека, ни смены, ни
    // подготовки. Составные части смешанной и долга проверяются ниже, когда
    // касса посчитает их сама ([_plan]).
    //
    // **Смешанная и долг сюда не попадают.** Смешанная — форма, а не тендер
    // (круг правки 1); долг сторожит право `op.sellDebt`, а не набор (круг
    // правки 2). Полный разбор обоих — докстринг
    // [domain.tenderPaymentTypes].
    //
    // **Что уже записано к моменту второй проверки — названо честно (круг
    // правки 2).** Прежний комментарий на ней утверждал «ни одной записи до
    // этой точки ещё не сделано», и это была неправда: между этой строкой и
    // раскладкой стоит `_checkout.prepare`, которая снимает платежи прошлой
    // попытки (`paymentDao.deleteBySale`), переписывает цены строк на месте
    // и обновляет `sales.amount`. Порчей это не становится — подготовка
    // идемпотентна, чек остаётся в работе (`state = 0`), платежей у него
    // нет, а цены она приводит к тем же числам, из которых сама же и
    // считает итог, — но **отказ по виду оплаты приходит после её записей**,
    // и следующий читатель обязан знать это, а не верить обещанию. Раньше
    // подготовки эта проверка встать не может: наличная и безналичная
    // половины выводятся из суммы чека, а сумму даёт она.
    await _requireAllowedTypes(terminalId, {
      if (domain.tenderPaymentTypes.contains(request.type)) request.type,
    });

    final posId = await _posId();
    final receiptNo = meta.receiptNo;
    if (receiptNo == null) {
      throw const WireRefusal(
        payReceiptNotFoundCode,
        'команда оплаты не называет чек',
      );
    }

    final sale = await _db.saleDao.findByKey(receiptNo, posId);
    if (sale == null) {
      throw WireRefusal(
        payReceiptNotFoundCode,
        'чека $receiptNo на этой кассе нет',
      );
    }

    // «Занят под оплату» — это **чек в работе**, а не оплаченный, и
    // разбирается он до общей ветки «состояние не то» намеренно.
    // Отправить его туда значило бы ответить «чек уже оплачен» на чек,
    // за которым нет ни одной строки `Payments`, — подлог ровно того
    // рода, который эта работа убирает.
    if (sale.state == _stateClaimedForPayment) {
      if (sale.lastCommandKey != meta.key) {
        _logger.warning(
          'Payment: receipt $receiptNo claimed by key=${sale.lastCommandKey}, '
          'asked by key=${meta.key}',
        );
        throw WireRefusal(
          cartStaleCode,
          'чек $receiptNo занят другой оплатой — обновите его и повторите',
        );
      }
      // Свой же ключ: попытка, не дожившая до денег (смерть кассы между
      // занятием и транзакцией `perform`). Чек не оплачен, и повтор
      // проходит обычным путём — условная запись ниже перезанимает его
      // тем же ключом.
      _logger.info(
        'Payment: re-claim after crash key=${meta.key} receipt=$receiptNo',
      );
    } else if (sale.state != _stateInProgress) {
      if (sale.lastCommandKey == meta.key) {
        _logger.info(
          'Payment: complete repeat key=${meta.key} receipt=$receiptNo',
        );
        return _outcomeOf(sale, repeat: true);
      }
      // Второй оплаты уже оплаченного чека по проводу нет и не будет до
      // отдельной работы про отмену (докстринг [payAlreadyTakenCode]):
      // взять деньги дважды хуже, чем не взять их автоматически.
      throw WireRefusal(payAlreadyTakenCode, 'чек $receiptNo уже оплачен');
    }

    if (sale.terminalId != terminalId) {
      _logger.warning(
        'Payment: receipt $receiptNo belongs to terminal '
        '${sale.terminalId}, asked by $terminalId',
      );
      throw WireRefusal(
        payNotOwnerCode,
        'чек $receiptNo набирает другое рабочее место',
      );
    }
    if (sale.cartVersion != meta.baseVersion) {
      throw const WireRefusal(
        'cart_stale',
        'корзина уже изменилась — обновите её и повторите',
      );
    }

    // Потолок возраста смены — I1 круга правки 1. До задачи 14 оплата
    // шла через `SaleNotifier.completeSale`, где эта проверка стояла
    // (`_ensureShiftNotOverAge`); контракт унёс путь, а проверку с собой
    // не взял — и чек, начатый до рубежа, оплачивался после него. Стоит
    // здесь, а не на экране: экран это вкладка браузера, и «касса
    // проверяет сама» — то же правило, что и у сдачи.
    await _requireShiftNotOverAge();

    // Сумма чека — от кассы: подготовка сводит строки на месте и отдаёт
    // итог, посчитанный из базы (задача 8). Ни одно число терминала в
    // неё не входит.
    final prepared = await _checkout.prepare(
      receiptNo: receiptNo,
      posId: posId,
    );
    final refusal = prepared.refusal;
    if (refusal != null) throw refusal;
    final amount = prepared.amount!;

    final current = sale;
    final plan = await _plan(terminalId, request, amount, current);

    // I5 круга правки 1: касса **пользуется собственным доказательством**.
    // Она помнит, что провела карту ([_cardCharges]), но завершение об
    // этом не спрашивало — кадр с выдуманным кодом одобрения делал чек
    // полностью оплаченным, ни разу не обратившись к эквайрингу.
    await _requireCardProof(terminalId, current, request, plan);

    // Признак фискализации выводит **касса** и делает это один раз: тот
    // же ответ идёт и в фискальный документ, и в ЭСФ внутри `perform`.
    //
    // Спрашивается **до** занятия чека (задача 8), а не между занятием и
    // деньгами: это чтение настройки кассы, оно к занятию отношения не
    // имеет, а каждое обращение к базе внутри окна «занял — записал»
    // это окно удлиняет.
    final selectiveOfd = await _checkout.selectiveOfdDefault();

    // «Занять» чек под оплату: условная запись по состоянию и версии.
    // Ноль затронутых строк значит, что чек занял кто-то другой между
    // чтением и записью, — отказ, а не запись поверх.
    //
    // **Состояние переводится тем же `UPDATE`** (задача 8), и в этом всё
    // дело: пока запись меняла один `lastCommandKey`, оставляя
    // `state = 0`, условие было истинно и у второго гонщика — заслон
    // ничего не утверждал. Разбор, замер и оговорка про смерть процесса
    // — докстринг [_stateClaimedForPayment].
    //
    // Условие по ключу — не «ключ пуст», а «занято мною»: занятость
    // живёт в состоянии, ключ отвечает, чьё оно. Своя же попытка,
    // не дожившая до денег, перезанимает чек и идёт дальше; чужая
    // получает отказ.
    final claimed =
        await (_db.update(_db.sales)..where(
              (s) =>
                  s.receiptNo.equals(receiptNo) &
                  s.posId.equals(posId) &
                  s.cartVersion.equals(current.cartVersion) &
                  (s.state.equals(_stateInProgress) |
                      (s.state.equals(_stateClaimedForPayment) &
                          s.lastCommandKey.equals(meta.key))),
            ))
            .write(
              SalesCompanion(
                state: const Value(_stateClaimedForPayment),
                lastCommandKey: Value(meta.key),
                // Владельца чек **не теряет и не меняет**: занятие под
                // оплату — это те же несколько миллисекунд его работы, а
                // не другая жизнь (правило смысла `Sales.terminalId`).
                // Пишется явно, потому что сторож
                // `sale_state_owner_guard_test.dart` требует решения по
                // владельцу от каждой записи состояния — и потребовал
                // его от этой; чьё это рабочее место, уже проверено выше
                // отказом `pay_not_owner`.
                terminalId: Value(terminalId),
              ),
            );
    if (claimed == 0) {
      _logger.warning(
        'Payment: conditional claim rejected key=${meta.key} '
        'receipt=$receiptNo base=${meta.baseVersion} '
        '(чек занят другой оплатой или уехал между чтением и записью)',
      );
      throw const WireRefusal(
        cartStaleCode,
        'чек уже изменился — обновите его и повторите',
      );
    }

    try {
      await _sale.perform(
        receiptNo: receiptNo,
        posId: posId,
        amount: amount,
        // Формат завершённого чека, посчитанный подготовкой (задача 9):
        // цена единицы с вложенной акционной скидкой и округлённая до
        // денежных трёх знаков. Записывается **внутри** транзакции
        // `perform`, а не после неё, — потому и едет доводом, а не
        // отдельным вызовом следом. До задачи 9 записи не случалось
        // вовсе: писал её `SaleCheckoutService.finalize`, у которого
        // живых вызывающих не было.
        lines: prepared.lines,
        payments: plan.payments,
        change: plan.change,
        // I6 круга правки 1: **только от кассы**. Признак выборочной
        // фискализации приходил полем заявки и перебивал умолчание кассы
        // без права и без следа — то есть браузер решал, уедет ли чек к
        // фискальному оператору. Поле заявки снято, вопрос задаётся кассе.
        selectiveOfd: selectiveOfd,
        customerBin: request.customerBin,
        agentLocalId: plan.agentLocalId,
        credit: plan.credit,
      );
    } catch (_) {
      // Занятие живёт ровно столько, сколько идёт запись денег. Иначе
      // одна неудача заперла бы чек навсегда: ключ команды мнётся на
      // каждую попытку заново, и повтор кассира пришёл бы **с новым
      // ключом**, которому условие «занято мною» уже не подходит.
      await _releaseClaim(receiptNo, posId, meta.key, terminalId);
      rethrow;
    }

    _forgetCharges(receiptNo);

    // Намерение QR помечается разобранным **после** успешной записи чека
    // — разбор направления в докстринге `_PaymentPlan.qrIntentId`.
    //
    // Запись **условная** (`settled_at IS NULL` в базе), и её ответ
    // читается: `false` значит «эти деньги уже в другом чеке», и об этом
    // надо знать. Второй заслон впереди — отказ `qr_intent_already_settled`
    // в раскладке; этот — последний, и он про гонку, которую отказ
    // впереди пройти не может.
    final qrIntentId = plan.qrIntentId;
    if (qrIntentId != null) {
      final claimed = await _db.paymentIntentDao.markSettled(
        id: qrIntentId,
        receiptNo: receiptNo,
        at: DateTime.now(),
      );
      if (!claimed) {
        _logger.warning(
          'Payment: QR intent $qrIntentId was already settled elsewhere — '
          'receipt $receiptNo carries a payment row for money that another '
          'receipt claimed first',
        );
      }
    }

    await _accrueCashback(request, plan, receiptNo);

    // ── три действия кассы (задача 16) ──────────────────────────────
    //
    // Первое **ожидается**, два других — нет, и порядок этот выбран, а не
    // достался:
    //
    // - фискализация ожидается, потому что её ответ обязан попасть в
    //   печатаемый чек (фискальный признак) и в исход, который увидит
    //   терминал. Это не железо и не очередь: это разговор с фискальным
    //   оператором, у которого своя очередь на случай недоступности;
    // - печать и ящик **отправляются**. Правило «оплата не ждёт железа»
    //   стоило когда-то ~2,8 с на отсутствующем `/dev/usb/lp*` уже после
    //   того, как деньги взяты; по проводу к этой задержке прибавилась бы
    //   ещё и сеть.
    final fiscal = await _fiscalize(
      receiptNo: receiptNo,
      posId: posId,
      amount: amount,
      plan: plan,
      request: request,
      selectiveOfd: selectiveOfd,
    );

    // Остатки изменились — пункт 12 ревизии 2026-09-19.
    //
    // **Здесь, а не в экране**, и это и есть вся починка: завершение
    // продажи с любого рабочего места проходит через этот метод — кассир
    // за кассой, кассир за планшетом, — а `refreshAfterSaleCompleted`
    // поднимает счётчик только **своего** контейнера. Соседний экран о
    // проданном товаре не узнавал ничем.
    //
    // После `_persist`, до возврата исхода: остаток к этому моменту уже
    // списан, и подписанный, перечитавший себя, увидит новый, а не тот же
    // самый. Повторное завершение (`_outcomeOf(repeat: true)`) сюда не
    // доходит — оно ничего не двигало.
    _stockChanges?.stockChanged();

    _dispatchHardware(
      terminalId: terminalId,
      receiptNo: receiptNo,
      posId: posId,
      plan: plan,
      // Исход уже известен: фискализация **ожидается**, печать — нет.
      // Поэтому подвал чека может назвать причину, по которой документа
      // нет, вместо одинокого «НЕФИСКАЛЬНЫЙ ЧЕК» на три разные причины.
      fiscal: fiscal,
    );

    _logger.info(
      'Payment: receipt=$receiptNo pos=$posId amount=$amount '
      'paid=${plan.paid} change=${plan.change} debt=${plan.debt} '
      'type=${request.type.name} fiscal=${fiscal.state.name}',
    );

    return SaleOutcome(
      receiptNo: receiptNo,
      posId: posId,
      amount: amount,
      change: plan.change,
      paid: plan.paid,
      debt: plan.debt,
      fiscal: fiscal,
    );
  }

  // ── фискализация ──────────────────────────────────────────────────────

  /// Фискальный документ чека — **на кассе**.
  ///
  /// Жил в `SaleUseCaseImpl.perform` до задачи 16 и переехал сюда к двум
  /// другим действиям завершения. Переезд — не перестановка ради списка
  /// файлов: внутри `perform` исход ловился `catch`, уходил в
  /// `Talker.warning` и **никуда больше**, а вызывающий узнавал об отказе
  /// оператора ровно столько же, сколько об удаче, — ничего. Здесь исход
  /// становится значением ([SaleOutcome.fiscal]).
  ///
  /// Признак «нужен ли документ» считает общая политика
  /// ([isOfdSale]), а не копия её здесь: настройку `ThisPos.ofdSyncType`
  /// читают двое — фискальный документ и ЭСФ, — и разойтись они не имеют
  /// права.
  ///
  /// # Три «документа нет», а не одно (задача 5)
  ///
  /// До задачи 5 отсюда уходило одно [SaleFiscalization.notRequired] на
  /// три разные причины, и докстринг `FiscalState` это признавал прямо.
  /// Кассир видел одно и то же ничто в трёх положениях, лечащихся
  /// по-разному:
  ///
  /// * `_fiscal is RefusingFiscalService` — узла фискализации **нет в
  ///   собранной кассе**. Настройками не лечится, кассиром не
  ///   исправляется → [FiscalState.fiscalModuleAbsent].
  /// * `!fiscal.isEnabled()` — оператор у кассы **не настроен**
  ///   (`operatorType == none`). Настройка, а не поломка: касса торгует,
  ///   чеки печатаются → [FiscalState.operatorAbsent].
  /// * `!isOfdSale(...)` — политика чека вывела «не в этот раз».
  ///   Утверждение о **чеке**, а не о кассе → [FiscalState.notRequired].
  ///
  /// **Второго ответа на «нужен ли документ» здесь не заводится.**
  /// `isEnabled` спрашивается отдельно только затем, чтобы отличить
  /// «оператора нет» от «политика решила»; сама политика
  /// `ThisPos.ofdSyncType` по-прежнему живёт в одном месте, в
  /// [isOfdSale], и повторно здесь не считается. Порядок вопросов тот же,
  /// что внутри [isOfdSale], — она тоже смотрит `isEnabled` первым.
  ///
  /// **Отказ денег не отменяет.** Разбор решения — докстринг
  /// [SaleOutcome.fiscal].
  ///
  /// # Почему первый вопрос — про тип, а не про ноль (задача 3)
  ///
  /// Раньше здесь стояло `if (fiscal == null)`, и ноль приходил сюда
  /// двумя разными дорогами: из решения «касса собрана без фискального
  /// узла» и из забывчивости того, кто собирал службу и про довод не
  /// вспомнил. Восемь мест сборки из четырнадцати шли второй дорогой.
  /// Обе давали одинаковый ответ, и отличить их было нечем.
  ///
  /// Довод стал обязательным, и второй дороги не стало вовсе: она теперь
  /// ошибка компиляции. Осталась первая — и её надо было чем-то
  /// выразить, иначе [FiscalState.fiscalModuleAbsent] стал бы мёртвым
  /// членом перечисления, а три причины задачи 5 молча схлопнулись бы
  /// обратно в две. Выражает её тип: `RefusingFiscalService` нельзя
  /// получить молчанием, его имя надо написать.
  ///
  /// Проверка типа здесь — **не переехавший обнуляемый сторож**: ноль был
  /// значением по умолчанию, а этот тип — сказанным словом.
  ///
  /// **Чего эта ветвь НЕ доказывает.** Что состояние достижимо из
  /// продукта. Измерено: единственное место сборки службы в продукте —
  /// `service_locator.dart`, и `FiscalService` там регистрируется всегда,
  /// в той же функции и безусловно. То есть сегодня
  /// [FiscalState.fiscalModuleAbsent] достижим **только из проб**, и так
  /// стало ещё задачей 5 — задача 3 этого не создала. Разбор и решение —
  /// у тернарника в `service_locator.dart`.
  Future<SaleFiscalization> _fiscalize({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required _PaymentPlan plan,
    required PaymentRequest request,
    required bool selectiveOfd,
  }) async {
    final fiscal = _fiscal;
    if (fiscal is RefusingFiscalService) {
      // Каждый раз, а не однажды: собранная без узла фискализации касса
      // берёт деньги и не может выдать документ ни одному чеку.
      _logger.error(
        'Payment: чек $receiptNo — узла фискализации нет в собранной '
        'кассе. Документа не будет ни у одного чека этой сборки.',
      );
      return SaleFiscalization.fiscalModuleAbsent;
    }

    try {
      if (!await fiscal.isEnabled()) {
        return SaleFiscalization.operatorAbsent;
      }

      final needed = await isOfdSale(
        db: _db,
        fiscal: fiscal,
        payments: plan.payments,
        selectiveOfd: selectiveOfd,
      );
      if (!needed) return SaleFiscalization.notRequired;

      // Наличная и безналичная части — **по фискальной трактовке вида
      // оплаты** (задача 21); до неё считались по роду счёта получателя,
      // и разбор смены признака — ниже. Заявка терминала сюда не входит
      // ни в одном виде: у неё нет права диктовать, что уедет оператору.
      //
      // # ПРЕДЕЛ, НАЗВАННЫЙ И ИЗМЕРЕННЫЙ (задача 22)
      //
      // У конверта **три ведра** — `cashAmount`, `cardAmount`,
      // `bonusAmount`, — и «безналичное» в нём одно на всех. QR/СБП
      // ложится на счёт рода `customBank` и потому едет оператору
      // **картой**, хотя справочник говорит `FiscalTreatment.mobile`.
      //
      // Замер: `git grep -n "toFiscalKind" -- lib/` даёт **только
      // объявление** — у метода, переводящего трактовку на язык
      // оператора, нет ни одного вызывающего в продукте. Пока безналичный
      // вид был один, разницы не было; QR — первый вид, у которого
      // справочник и вывод по роду счёта **расходятся**.
      //
      // Почему не закрыто здесь: `FiscalService.fiscalizeSale` — общий
      // контракт, его реализуют и зовут десять файлов
      // (`webkassa_provider`, `kassa24_provider`, `direct_ofd_provider`,
      // `offline_queueing_provider`, `fiscal_service_impl`, …), и четвёртое
      // ведро — их работа, а не этой задачи. Расширять чужой контракт
      // молчком, пока двое соседей правят те же файлы, значит устроить
      // столкновение ради поля, которого никто ещё не просил.
      //
      // Что здесь сделано вместо: **вид оплаты доехал туда, где решение
      // уже принимается по нему** — `isOfdSale` спрашивает
      // `FiscalTreatment.isCashless`, а не сравнивает с картой. Без этого
      // чек, оплаченный телефоном, на кассе с выборочной фискализацией не
      // уезжал бы оператору **вовсе**. Это была настоящая беда; ведро —
      // неточность в названии вида. Замер «`toFiscalKind` без
      // вызывающих» с задачи 21 **устарел на половину**: трактовка вида
      // теперь читается здесь, ведром — по-прежнему нет.
      //
      // # Почему пришлось сменить признак
      //
      // Сертификат ложится на счёт обязательства
      // (`AccountType.certificateLiability`) — ни `pos`, ни `customBank`,
      // — и по роду счёта не попал бы **никуда**. Позиции при этом
      // строятся на полную сумму чека, и оператор получил бы «позиций на
      // 500, оплат на 0» — то есть код 9 и «деньги взяты, документа нет»
      // на каждой продаже с сертификатом. Ровно тот дефект, который
      // задача 7 нашла у бонуса, слово в слово.
      //
      // # Почему сертификат — платёж, а бонус — скидка
      //
      // Разница в том, **платил ли покупатель полную цену**. Бонус —
      // накопленное магазином: объявить его платежом значит сказать, что
      // покупатель заплатил полную цену, и завысить базу налога. За
      // сертификат покупатель (или даритель) заплатил деньгами и полную
      // цену — просто раньше; налог с товара берётся при гашении, с
      // полной цены. Поэтому бонус едет слагаемым скидки, а сертификат —
      // строкой оплаты.
      //
      // # Трактовка — **свойство вида в справочнике, а не число здесь**
      //
      // Ни одного `kindId == …` в этом цикле нет и быть не должно:
      // отдельного «сертификата» у оператора не существует (пять членов
      // `FiscalPaymentKind`), правильный ответ зависит от страны и
      // договора, и оператор меняет его настройкой вида. Меняется
      // настройка — меняется то, что уезжает, и без правки кода. Сторож
      // — `fiscal_envelope_balance_test`, случай «трактовка вида решает».
      //
      // # Поведение прежних видов не изменилось, и это проверено перебором
      //
      // `cash` → `pos` → наличные; `card` → `customBank` → карта;
      // `bonus`/`agent_settlement` → `notAPayment` → никуда;
      // `debt` → `credit` → никуда (как и по роду `agentMain`). Строка
      // без вида (до v41) классифицируется **по роду счёта**, как и
      // раньше: перевыводить трактовку ей неоткуда.
      //
      // # Что эта смена признака сломала у соседа — и как это чинится
      //
      // `prepayment` в справочнике тоже `FiscalTreatment.cash` (задача
      // 23, и по делу — разбор ниже). Пока цикл считал по роду счёта,
      // зачёт аванса лежал на `agentMain` и в вёдра **не попадал**,
      // поэтому задача 23 дописывала его руками строкой
      // `cash += plan.prepayment` **после** цикла. Со сменой признака
      // цикл стал брать ту же строку сам, и обе прибавки сложились:
      // на чеке 1000 при 600 наличными и 400 авансом оператор получал
      // `cashAmount = 1400` при позициях на 1000 — то есть код 9 на
      // каждом чеке со смешанным авансом. Ни один из двух наборов этого
      // не видел: у задачи 21 в дереве не было аванса, у задачи 23 —
      // трактовки.
      //
      // Разрешено **удалением ручной прибавки**, а не отказом от
      // трактовки: источник ответа обязан быть один, и справочник —
      // правильный из двух (оператор меняет настройкой, а не правкой
      // кода). Сторож — `fiscal_envelope_balance_test`, случай «аванс
      // считается один раз».
      // # Решения заказчика 2026-09-14 — ПРЕДЕЛ задачи 22 закрыт
      //
      // Вёдер живых денег теперь три (`mobile` — своё, `PaymentType 4`), и
      // четвёртое число — **зачёт** (`FiscalTreatment.offsetNotFiscal`):
      // гашение сертификата и зачёт аванса при фискализованном приёме. Зачёт
      // оплатой не едет никогда; разницу позиций и оплат закрывает раскладка
      // оператора (`OffsetFiscalLayout`). Разбор «наличными» ниже устарел —
      // он оставлен как история решения, которое заказчик отменил.
      //
      // Трактовка берётся **через сторож** `effectiveTreatment`, а не
      // голым полем справочника: сочетание «деньги уже фискализованы» +
      // «зачёт назван платежом» — двойная выручка по ККМ, и запрещено оно
      // построением.
      final offsetSettings = await _db.thisPosDao.offsetFiscalSettings();
      var cash = Decimal.zero;
      var card = Decimal.zero;
      var mobile = Decimal.zero;
      var offset = Decimal.zero;
      for (final p in plan.payments) {
        final kind = await _kinds.byId(p.kindId);
        if (kind != null) {
          switch (offsetSettings.effectiveTreatment(kind)) {
            case FiscalTreatment.cash:
              cash += p.amount;
            case FiscalTreatment.card:
              card += p.amount;
            case FiscalTreatment.mobile:
              mobile += p.amount;
            case FiscalTreatment.offsetNotFiscal:
              offset += p.amount;
            case FiscalTreatment.credit:
            case FiscalTreatment.tare:
            case FiscalTreatment.notAPayment:
              break;
          }
          continue;
        }
        final account = await _db.accountDao.findById(p.payeeAccountId);
        if (account == null) continue;
        if (account.type == AccountType.pos) {
          cash += p.amount;
        } else if (account.type == AccountType.customBank) {
          card += p.amount;
        }
      }

      // # Бонус: третье число, а не третья ветка этого цикла (задача 7)
      //
      // Бонусная строка оплаты идёт на бонусный счёт покупателя
      // (`AccountType.cashback` / `agentCashback`), и цикл выше её не
      // считает **ни наличными, ни картой** — правильно, потому что
      // деньги кассы она не двигает. До задачи 7 на этом всё и
      // кончалось: бонус не попадал в конверт никуда, позиции при этом
      // строились на полную сумму, и оператор отвергал чек кодом 9.
      //
      // Дописать сюда `else if (type == cashback) bonus += ...` было бы
      // ошибкой того самого класса, что задача 7 закрывает: бонус
      // приехал бы **строкой оплаты**, оператор увидел бы, что покупатель
      // заплатил полную цену, и налог посчитался бы с денег, которых не
      // брали. Подходящего вида в `FiscalPaymentKind`
      // (`{cash, card, credit, mobile, tare}`) нет, а `_paymentType` —
      // исчерпывающий `switch` без `default`: новый член сломал бы
      // сборку, и это правильно. Довод «в другой стране регулятор считает
      // иначе» верен и закрывается настройкой
      // (`PaymentKind.fiscalTreatment`, задача 14), а не кодом.
      //
      // Поэтому бонус едет **суммой**, а не строкой оплаты, и внутри
      // конверта становится слагаемым скидки позиций. Берётся он из
      // плана кассы (`_plan` наложил оба потолка — остаток счёта и сумму
      // чека), а не из заявки терминала.

      // # Аванс: наличными, и это РЕШЕНИЕ, а не «ближайшее по смыслу»
      //
      // Строка зачёта лежит на расчётном счёте покупателя, и цикл выше
      // её не считает ни наличными, ни картой. Оставить так значило бы
      // отправить оператору конверт, в котором позиции на 1000, а
      // платежей на 400: **код 9 и «деньги взяты, документа нет»** — то
      // самое, что задача 7 измерила на бонусе и закрыла.
      //
      // Но и повторить решение бонуса нельзя.
      // [FiscalTreatment.notAPayment] уводит сумму в **скидку позиции**
      // (`FiscalPositionBuilder.extraDiscount`), а это про бонус верно и
      // про аванс неверно: бонус кассе никто не приносил, налоговая база
      // на него и правда меньше, а товар по авансу продан **за полную
      // цену**, и объявить аванс скидкой значило бы занизить базу
      // налога — ровно та беда, от которой `notAPayment` бережёт, только
      // в другую сторону.
      //
      // Решение: **приём аванса и зачёт аванса — разные документы, и
      // выручку признаёт второй.** Приём — внесение денег на расчётный
      // счёт покупателя (`CustomerPaymentUseCase`, решение
      // `investment`): выручки нет, документ отдельный. Значит на чеке
      // отгрузки те же деньги признаются выручкой **впервые**, и назвать
      // их надо тем, чем покупатель платил, — наличными. Поэтому
      // `FiscalTreatment.cash` в справочнике у вида `prepayment` — не
      // заглушка, а посчитанный ответ.
      //
      // **Цена решения названа.** Если аванс был принят картой, конверт
      // назовёт его наличными: приём аванса сегодня не хранит, чем
      // платили. Это долг приёма, а не зачёта, и он записан в отчёте
      // задачи, а не спрятан за словом «ближайшее».
      //
      // Оператору аванс уезжает **суммой в наличной части**, а не
      // отдельной строкой: члена под зачёт в `FiscalPaymentKind` нет, а
      // `_paymentType` — исчерпывающий `switch` без `default`.
      //
      // **Прибавка стояла здесь и снята при слиянии с задачей 21.** Она
      // была верна ровно до того дня, когда цикл выше начал спрашивать
      // `kind.fiscalTreatment`: у вида `prepayment` она `cash`, значит
      // цикл кладёт зачёт в наличную часть сам, и вторая прибавка
      // удваивала его. Решение остаётся тем же — аванс едет наличными, —
      // изменилось только место, где оно записано: не число здесь, а
      // настройка вида в справочнике.

      // # Продажа сертификата — чек по настройке, по умолчанию нет (A1)
      //
      // Решение **по признаку позиции** (`ProductType.giftCertificate`), а
      // не по коду вида в цикле выше (правило задачи 14): сертификат в этом
      // чеке — то, что покупают, а не то, чем платят.
      //
      // Чек из одних сертификатов документа не даёт вовсе. Смешанный чек
      // даёт документ на товар: строки сертификатов в него не идут, а их
      // деньги вычитаются из живых — **наличные, затем карта, затем
      // телефон**. Порядок назван, а не выведен: у строки товара нет связи с
      // конкретной строкой оплаты, и какой из денег оплачен сертификат,
      // касса не знает. Вопрос бухгалтеру — в отчёте дорожки A.
      var excludeCertificates = false;
      if (!offsetSettings.fiscalizeCertificateSale) {
        var certificateLines = Decimal.zero;
        var allLines = Decimal.zero;
        for (final sp in await _db.saleProductDao.findBySale(
          receiptNo,
          posId,
        )) {
          final line = sp.quantity * sp.price;
          allLines += line;
          final product = await _db.productInfoDao.findByUcode(sp.ucode);
          if (product?.type == ProductType.giftCertificate.index) {
            certificateLines += line;
          }
        }
        if (certificateLines > Decimal.zero) {
          if (certificateLines >= allLines) {
            _logger.info(
              'Payment: чек $receiptNo — продажа сертификата, фискализация '
              'продажи сертификата выключена настройкой',
            );
            return SaleFiscalization.notRequired;
          }
          excludeCertificates = true;
          var rest = certificateLines;
          Decimal take(Decimal bucket) {
            final taken = bucket < rest ? bucket : rest;
            rest -= taken;
            return taken;
          }

          cash -= take(cash);
          card -= take(card);
          mobile -= take(mobile);
        }
      }

      // # Денежного расчёта нет — документа нет (решение (в) плана)
      //
      // Чек, целиком закрытый зачётом (сертификат, аванс при фискализованном
      // приёме), живых денег не принёс. Документ на ноль тенге — не
      // «сошлось», а утверждение о расчёте, которого не было. Действует при
      // обеих раскладках.
      if (cash + card + mobile == Decimal.zero && offset > Decimal.zero) {
        _logger.info(
          'Payment: чек $receiptNo закрыт зачётом целиком ($offset) — '
          'фискального документа нет',
        );
        return SaleFiscalization.notRequired;
      }

      final result = await fiscal.fiscalizeSale(
        saleReceiptNo: receiptNo,
        salePosId: posId,
        amount: amount,
        cashAmount: cash,
        cardAmount: card,
        mobileAmount: mobile,
        bonusAmount: plan.bonus,
        offsetAmount: offset,
        offsetLayout: offsetSettings.offsetLayout,
        excludeCertificatePositions: excludeCertificates,
        customerBin: request.customerBin,
      );

      if (result.success) {
        _logger.info(
          'Payment: receipt $receiptNo fiscalized '
          '${result.queued ? '(в очереди)' : 'ok'} sign=${result.fiscalSign}',
        );
        return SaleFiscalization(
          result.queued ? FiscalState.queued : FiscalState.done,
          sign: result.fiscalSign,
        );
      }

      // Код причины, а не `errorMessage`: тот написан по-русски
      // провайдером и оператором и доехал бы до кассира мимо словаря.
      // Текст остаётся в журнале (`FiscalServiceImpl._log`).
      final message = FiscalFailureReason.fromResult(result).encode();
      return await _unfiscalized(
        receiptNo: receiptNo,
        posId: posId,
        amount: amount,
        document: result.document,
        message: message,
      );
    } catch (e, st) {
      // Текст исключения наружу не уходит (I144) — только код причины.
      _logger.error('Payment: fiscalization threw for $receiptNo', e, st);
      return _unfiscalized(
        receiptNo: receiptNo,
        posId: posId,
        amount: amount,
        // Бросок пришёл **мимо** службы фискализации (её собственный
        // `catch` возвращает значение) — документа тут нет и быть не может.
        document: null,
        message: const FiscalFailureReason(
          FiscalFailureKind.clientFault,
        ).encode(),
      );
    }
  }

  /// Записать беду так, чтобы она **пережила перезапуск и поддавалась
  /// лечению рукой**, — и по-прежнему не обещать повтора, которого в
  /// дереве нет.
  ///
  /// Строка ложится в `FiscalQueueEntries` со состоянием
  /// `FiscalQueueStatus.failed`, а не `pending`, и это выбор, а не
  /// описка: `OfflineQueueingProvider.replay` читает только `pending`, и
  /// нетранзиентный отказ (неверные учётные данные, заблокированная
  /// касса, отвергнутый документ) слепым повтором не лечится. Положить
  /// сюда `pending` значило бы завести вечный цикл и второй раз солгать
  /// про лечение — разбор в докстринге [SaleOutcome.fiscal].
  ///
  /// # Три дефекта самой строки, закрытые задачей 11
  ///
  /// 1. **Ключ был чужой.** Строка ложилась под
  ///    `'sale-unfiscalized:$posId-$receiptNo'`, а провайдер ходил к
  ///    оператору под своим (тогда `'sale-$receiptNo-$posId'`, с
  ///    2026-09-18 — `FiscalIdempotency.sale`, ключ с эпохой). Довод
  ///    «это запись о беде, и столкнуться с
  ///    настоящим заданием очереди она не должна» звучал разумно и
  ///    оказался разрушительным: повтор такой строки оператор не узнал бы
  ///    как повтор, и на **одну продажу приехали бы два фискальных
  ///    документа**. Столкновение ключей — не беда, а ровно то, что
  ///    защищает: два ключа на один чек не могут сосуществовать по
  ///    построению, потому что чек один.
  /// 2. **Повторять было нечем.** В payload лежала записка
  ///    `{receiptNo, posId, amount}`. Теперь — сам документ,
  ///    `FiscalSaleRequest.toJson()`. Пересобрать его позже из базы чека
  ///    **запрещено**: пересборка уедет с другим ключом (и с другим
  ///    временем), то есть повторит дефект 1.
  /// 3. **Строки не убирались никогда.** Теперь их видит экран
  ///    нефискализованных чеков, и человек их либо повторяет, либо
  ///    списывает с названной причиной.
  ///
  /// **ИИН/БИН покупателя в строку не кладётся** — это персональные
  /// данные, а строка живёт до тех пор, пока её не разберёт человек.
  /// Вырезается здесь, на границе, за которой документ становится
  /// долговечным, а не в службе фискализации: в памяти он нужен целиком,
  /// иначе оператору уехал бы конверт без покупателя.
  ///
  /// [document] `null` — отказ случился раньше, чем конверт был собран.
  /// Тогда ложится строка **старого вида**: свой ключ, записка вместо
  /// документа. Повтору она не поддаётся, и экран показывает её с
  /// названной причиной и одной кнопкой «Списать».
  Future<SaleFiscalization> _unfiscalized({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required Map<String, dynamic>? document,
    required String message,
  }) async {
    _logger.error(
      'Payment: чек $receiptNo не фискализован — $message. Деньги взяты; '
      'автоматического повтора для этого отказа в дереве нет.',
    );
    final queue = _fiscalQueue;
    if (queue != null) {
      try {
        final key = document?['idempotencyKey'] as String?;
        final payload = document == null
            ? <String, dynamic>{
                'receiptNo': receiptNo,
                'posId': posId,
                'amount': amount.toString(),
              }
            : (Map<String, dynamic>.from(document)..remove('customer'));
        await queue.enqueue(
          fq.FiscalQueueEntry(
            idempotencyKey: key ?? 'sale-unfiscalized:$posId-$receiptNo',
            opType: fq.FiscalQueueOp.sale,
            payload: payload,
            occurredAt: DateTime.now(),
            status: fq.FiscalQueueStatus.failed,
            lastError: message,
          ),
        );
      } catch (e, st) {
        _logger.error('Payment: запись о нефискальном чеке не легла', e, st);
      }
    }
    return SaleFiscalization(FiscalState.failed, message: message);
  }

  // ── печать и ящик: отправляются, не ожидаются ─────────────────────────

  /// Отправить чек в печать и открыть ящик — **не дожидаясь ни того, ни
  /// другого**.
  ///
  /// Два задания, а не одно: ящик не имеет причины ждать принтера. Общий
  /// [_sideEffects] существует ради проб (см. [pendingSideEffects]) и
  /// собирает оба, чтобы «отправлено» можно было отличить от «не
  /// случилось».
  ///
  /// Ни одно исключение отсюда наружу не выходит: деньги уже взяты, и
  /// уронить завершение оплаты из-за принтера значило бы сделать ровно то,
  /// чего задача не допускает. Но и молча они не проходят — каждое
  /// называется в журнале вместе с номером чека.
  void _dispatchHardware({
    required int terminalId,
    required int receiptNo,
    required int posId,
    required _PaymentPlan plan,
    required SaleFiscalization fiscal,
  }) {
    final jobs = <Future<CompletionTrouble?>>[
      _printReceipt(receiptNo: receiptNo, posId: posId, fiscal: fiscal),
      // Ящик — только там, где в чеке есть наличные. То же правило, что
      // стояло на экране (`isCashPayment || isMixed`), но выведенное из
      // денег, а не из вида оплаты: наличная часть смешанной оплаты и
      // наличные при продаже в долг — те же наличные.
      if (plan.cash > Decimal.zero) _openDrawer(receiptNo),
    ];
    final joined = Future.wait(jobs);
    _remember(terminalId, receiptNo, joined);
    _sideEffects = joined.then((_) {});
    unawaited(joined);
  }

  /// Беды железа, ждущие своего читателя, — см. [hardwareTroubles].
  ///
  /// Читается один раз и снимается; без читателя вытесняется по
  /// [_troublesKept]. Предел назван числом, а не словом «немного»: это
  /// сигнал одному вызывающему, а не хранилище исходов, которого у
  /// оплаты нет и заводить которое эта задача не бралась.
  /// Ключ — **рабочее место и чек**: беду отдают владельцу, а не любому,
  /// кто назовёт номер (докстринг [PaymentService.hardwareTroubles]).
  final _troubles = <String, Future<List<CompletionTrouble>>>{};

  static const _troublesKept = 16;

  static String _troubleKey(int terminalId, int receiptNo) =>
      '$terminalId/$receiptNo';

  void _remember(
    int terminalId,
    int receiptNo,
    Future<List<CompletionTrouble?>> jobs,
  ) {
    _troubles[_troubleKey(terminalId, receiptNo)] = jobs.then(
      (found) => found.whereType<CompletionTrouble>().toList(),
    );
    while (_troubles.length > _troublesKept) {
      _troubles.remove(_troubles.keys.first);
    }
  }

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int receiptNo,
  ) async {
    final pending = _troubles.remove(_troubleKey(terminalId, receiptNo));
    if (pending == null) return const [];
    return await pending;
  }

  Future<CompletionTrouble?> _printReceipt({
    required int receiptNo,
    required int posId,
    required SaleFiscalization fiscal,
  }) async {
    final printer = _printer;
    if (printer == null) return null;
    try {
      final data = await _receipts.compose(
        receiptNo: receiptNo,
        posId: posId,
        fiscalState: fiscal.state,
      );
      if (data == null) return null;
      final outcome = await printer.printSaleReceipt(data);
      if (!outcome.isRejected) return null;
      // Очередь **не приняла** задание — значит чека не будет, пока
      // кассир не напечатает дубликат. Отказ очереди уже обязан называть
      // причину (`PrintSubmitOutcome.rejected`), и здесь она едет дальше
      // вместе с номером чека — и в журнал, и вызывающему.
      _logger.error(
        'Payment: чек $receiptNo не принят в очередь печати — '
        '${outcome.message}. Деньги взяты; чек можно напечатать '
        'повторно из истории.',
      );
      return CompletionTrouble(
        kind: CompletionTroubleKind.print,
        receiptNo: receiptNo,
        message: outcome.message,
      );
    } catch (e, st) {
      final safe = safeErrorText(e);
      _logger.error(
        'Payment: печать чека $receiptNo не состоялась — $safe. '
        'Деньги взяты; чек можно напечатать повторно из истории.',
        e,
        st,
      );
      return CompletionTrouble(
        kind: CompletionTroubleKind.print,
        receiptNo: receiptNo,
        message: safe,
      );
    }
  }

  Future<CompletionTrouble?> _openDrawer(int receiptNo) async {
    try {
      if (await _drawer()) return null;
      _logger.warning('Payment: денежный ящик не открылся, чек $receiptNo');
      return CompletionTrouble(
        kind: CompletionTroubleKind.drawer,
        receiptNo: receiptNo,
        // ПУСТО, а не подпись. Здесь стояло «денежный ящик не открылся» —
        // дословный повтор словарного заголовка, который экран и так
        // показывает, только по-русски: на английской кассе выходило «Cash
        // drawer did not open: денежный ящик не открылся». Поймано пробным
        // проходом главы 7 (2026-09-22).
        //
        // Подпись остаётся там, где она НЕСЁТ причину: «порт занят»,
        // «бумаги нет». Пустая означает «сверх заголовка сказать нечего».
        message: '',
      );
    } catch (e, st) {
      final safe = safeErrorText(e);
      _logger.error(
        'Payment: денежный ящик не открылся, чек $receiptNo — $safe',
        e,
        st,
      );
      return CompletionTrouble(
        kind: CompletionTroubleKind.drawer,
        receiptNo: receiptNo,
        message: safe,
      );
    }
  }

  /// Итог уже оплаченного чека, собранный **из базы**, а не из памяти.
  ///
  /// Повтор обязан вернуть то же, что вернул первый вызов, и единственный
  /// источник, который это гарантирует, — то, что первый вызов записал.
  /// Держать рядом второй, запомненный ответ значило бы завести два
  /// источника правды об одних и тех же деньгах.
  /// Снять занятие чека — но только своё (задача 8).
  ///
  /// Условие по ключу здесь не украшение: без него неудача одной попытки
  /// освобождала бы чек, занятый **другой**, и вся защита от двойного
  /// взятия денег снималась бы отказом соседа. Состояние возвращается в
  /// «в работе»; `lastCommandKey` остаётся — по нему узнаётся повтор.
  Future<void> _releaseClaim(
    int receiptNo,
    int posId,
    String key,
    int terminalId,
  ) async {
    final freed =
        await (_db.update(_db.sales)..where(
              (s) =>
                  s.receiptNo.equals(receiptNo) &
                  s.posId.equals(posId) &
                  s.state.equals(_stateClaimedForPayment) &
                  s.lastCommandKey.equals(key),
            ))
            .write(
              SalesCompanion(
                state: const Value(_stateInProgress),
                // Возврат в работу возвращает и владельца — тому же
                // рабочему месту, которое чек занимало. См. довод у
                // записи занятия.
                terminalId: Value(terminalId),
              ),
            );
    _logger.info(
      'Payment: claim released key=$key receipt=$receiptNo rows=$freed',
    );
  }

  Future<SaleOutcome> _outcomeOf(Sale sale, {required bool repeat}) async {
    final payments = await _db.paymentDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );
    final paid = payments.fold(Decimal.zero, (sum, p) => sum + p.amount);
    final debt = sale.amount - paid;
    return SaleOutcome(
      receiptNo: sale.receiptNo,
      posId: sale.posId,
      amount: sale.amount,
      change: sale.change ?? Decimal.zero,
      paid: paid,
      debt: debt > Decimal.zero ? debt : Decimal.zero,
      repeat: repeat,
      // Повтор ничего не делал заново — ни фискализации, ни печати, ни
      // ящика (задача 16), — и придумывать состояние ему не из чего:
      // `Sales` не хранит исхода фискализации, а сходить за ним к
      // оператору значило бы сделать то самое второе действие, которого
      // повтор обязан избежать.
      fiscal: repeat
          ? SaleFiscalization.unchanged
          : SaleFiscalization.notRequired,
    );
  }

  /// Раскладка денег: **весь** расчёт, который раньше делал экран.
  Future<_PaymentPlan> _plan(
    int terminalId,
    PaymentRequest request,
    Decimal amount,
    Sale sale,
  ) async {
    // Бонус: два потолка, оба кассы — остаток бонусного счёта и сумма
    // чека. Второй недостижим в [reserveBonus] (там нет чека) и потому
    // обязан быть здесь.
    var bonus = Decimal.zero;
    int? cashbackAccountId;
    final customerId = request.customerId;
    if (request.bonusUsed > Decimal.zero && customerId != null) {
      final agent = await _db.agentDao.findByLocalId(customerId);
      cashbackAccountId = agent?.cashbackAccountId;
      if (agent == null) {
        throw WireRefusal(
          payCustomerUnknownCode,
          'клиента $customerId нет в картотеке',
        );
      }
      if (cashbackAccountId == null) {
        throw const WireRefusal(
          payBonusAccountMissingCode,
          'у клиента нет бонусного счёта',
        );
      }
      final balance = await _bonusBalanceOf(cashbackAccountId);
      bonus = request.bonusUsed;
      if (bonus > balance) bonus = balance;
      // Второй потолок — сумма чека — ставит цепочка зачётов ниже
      // (`OffsetChain.split`), одна на кассу и экран.
    }

    // **QR/СБП: сумма читается из базы кассы, а не из заявки** — задача 22.
    //
    // Терминал называет ключ намерения, и только его. Сколько в намерении
    // денег, знает провайдер, а касса это уже записала; взять число из
    // кадра значило бы дать браузеру сказать, сколько покупатель заплатил
    // телефоном. Тот же довод, что у сдачи и у счёта-получателя.
    //
    // Три отказа, и каждый про своё: намерения нет; намерение есть, но не
    // оплачено; оплачено, но деньги уже в другом чеке. Слить их в один
    // код значило бы отправить кассира лечить не ту беду.
    var qr = Decimal.zero;
    PaymentIntent? qrIntent;
    final qrKey = request.qrIntentKey;
    if (qrKey != null) {
      qrIntent = await _db.paymentIntentDao.byKey(qrKey);
      // **Чужое рабочее место — как отсутствующее.** До входа в QR ключ
      // придумывал только набор проб, и владельца никто не сверял; с
      // `pay.qrStart` намерение заводит рабочее место, и соседняя вкладка
      // с `nav.sale`, назвавшая чужой ключ, закрыла бы своим чеком деньги,
      // которые покупатель платил за чужой. Намерение без владельца
      // (`terminalId IS NULL`, заведённое мимо провода) проходит как
      // прежде.
      if (qrIntent == null ||
          // Без рабочего места — ничьё (пункт 10 C, докстринг `_ownQrIntent`).
          qrIntent.terminalId != terminalId) {
        throw WireRefusal(
          payQrIntentUnknownCode,
          'намерения QR «$qrKey» нет в базе кассы',
        );
      }
      if (!qrIntent.status.holdsMoney) {
        throw WireRefusal(
          payQrNotPaidCode,
          'намерение QR не оплачено (${qrIntent.status.code})',
        );
      }
      if (qrIntent.settledAt != null) {
        throw WireRefusal(
          payQrAlreadySettledCode,
          'деньги этого намерения уже в чеке ${qrIntent.settledReceiptNo}',
        );
      }
      // Потолок — остаток чека после бонуса, и ставит его **касса**.
      // Намерение на 1200 в чеке на 1000 не имеет права дать строку на
      // 1200: сдачи QR не даёт (`givesChange = false` у вида), и лишнее
      // ушло бы в выручку смены деньгами, которых в кассе нет.
      // Потолок — остаток чека после бонуса — ставит цепочка зачётов ниже
      // (`OffsetChain.split`): одна функция на кассу и экран.
      qr = qrIntent.money;
    }

    // # Порядок: бонус → QR → сертификат → аванс. РЕШЕНИЕ слияния
    //
    // Задачи 22 (QR), 23 (аванс) и 21 (сертификат) шли параллельно и
    // друг друга не видели. **Все три** завели зачёт «остатка чека после
    // бонуса»: у QR это `room`, у аванса — `rest`, у сертификата —
    // довод `toPay: amount - bonus - certificate` внутри
    // `CertificateApplication.amountFor`. И все три считали его как
    // `amount - bonus`, каждая от своего нуля. Взять стороны механически
    // значило бы **выдать одну и ту же комнату трижды**: на чеке 1000
    // намерение QR на 600 и зачёт аванса на 600 дали бы
    // `toPay = 1000 - 600 - 600 = -400`, то есть кассу, которая должна
    // покупателю сдачу с денег, которых она не получала; сертификат на
    // 600 сверху довёл бы до −1000. Сторож `payment_unbalanced` это
    // поймал бы — но поймал бы **у клиента**, а не здесь.
    //
    // Поэтому потолок здесь считается **один раз и по цепочке**: каждый
    // следующий зачёт видит остаток, оставленный предыдущими, а не
    // `amount - bonus`. Третье повторение того же выражения снято при
    // слиянии задачи 21 — сертификат берёт `amount - bonus - qr -
    // certificate`, а не `amount - bonus - certificate`.
    //
    // Кто из четырёх идёт первым — не вкусовщина, потому что цена ошибки
    // несимметрична:
    //
    // * **Бонус сгорает.** Не отданный в этом чеке бонус клиент может
    //   потерять вовсе; поэтому он берёт комнату первым — так решила
    //   задача 21, и слияние с ней согласно.
    // * **QR — деньги, уже взятые.** Провайдер их держит
    //   (`status.holdsMoney`), сдачи QR не даёт (`givesChange = false`).
    //   Урезать строку QR ради аванса значит оставить часть уже
    //   заплаченного покупателем **вне чека**: деньги взяты, документа
    //   на них нет. Это ровно тот код 9, ради которого заведён экран
    //   разбора «деньги без чека», — и мы бы его порождали сами, на
    //   каждом смешанном чеке.
    // * **Сертификат — остаток, который может истечь.** Урезанная
    //   бумажка ничего не теряет сегодня: непогашенное остаётся на ней
    //   (`givesChange = false`, остаток живёт в `balanceMillis`). Но у
    //   бумажки есть `expiresAt`, и урезанное может не дожить до
    //   следующего чека.
    // * **Аванс — остаток, который не истекает.** Незачтённое остаётся
    //   кредитовым сальдо на расчётном счёте покупателя; срока у него
    //   нет ни одного, и следующий чек возьмёт его целиком.
    //
    // Отсюда весь порядок одним правилом — **первым берёт комнату тот,
    // кого урезать дороже**: сгорающий бонус, потом уже взятые деньги
    // QR, потом истекающий сертификат, потом бессрочный аванс. Обратный
    // порядок был бы формально «сбалансирован» и молча съедал бы то
    // чужие деньги, то чужой срок.

    // ── сертификаты — задача 21 ───────────────────────────────────────
    //
    // **Зачёт, а не деньги, и потому он вычитается из суммы к доплате
    // ровно как бонус.** Класс беды, ради которого проверка
    // `payment_unbalanced` была оставлена задачей 14 сторожем «следующего
    // вида оплаты», — это забытая здесь строка «вычесть из остатка»: тогда
    // строк оплаты стало бы на сумму сертификата больше суммы чека.
    //
    // Порядок «бонус, потом сертификат, потом деньги» выбран, а не достался:
    // бонус сгорает, сертификат — нет. Отдать первым то, что иначе пропадёт,
    // — единственная раскладка, при которой покупатель ничего не теряет.
    //
    // Потолок каждой бумажки — `min(остаток, сколько осталось доплатить)`.
    // Сдачи с сертификата нет (`givesChange = false`), остаток остаётся на
    // бумажке; полный разбор решения — докстринг `CertificateApplication`.
    //
    // Здесь бумажки только **проверяются** — отказы, счёт обязательства,
    // остаток. Сколько каждая покроет, решает цепочка зачётов ниже, когда
    // известен и аванс: потолок считается один раз и одной функцией.
    final presented = <({String number, int accountId, Decimal balance})>[];
    final seenCertificates = <String>{};
    for (final tender in request.certificates) {
      final number = tender.number.trim();
      if (number.isEmpty) continue;
      if (!seenCertificates.add(number)) {
        // **До раскладки, а не «сложить и списать один раз».** Две строки
        // по 300 с сертификата на 500 порознь проходят проверку остатка
        // (500 ≥ 300 обе), а вместе требуют 600 — и первым это заметил бы
        // условный `UPDATE` уже внутри транзакции продажи, сырым откатом
        // вместо названного отказа.
        throw WireRefusal(
          certificateDuplicateCode,
          'сертификат $number назван в этой оплате дважды',
        );
      }

      final found = await _certificates.lookup(number: number, pin: tender.pin);
      final accountId = found.liabilityAccountId;
      if (accountId == null) {
        // Достижимо сертификатом, перенесённым в базу мимо выпуска
        // (импорт тиража, ручная правка). Отказ, а не подстановка счёта:
        // подставленный счёт — это чужое обязательство, погашенное нашим
        // товаром.
        throw WireRefusal(
          certificateAccountMissingCode,
          'у сертификата $number нет счёта обязательства',
        );
      }

      presented.add((
        number: number,
        accountId: accountId,
        balance: found.balance,
      ));
    }

    // # Сертификатом за сертификат не платят — решение заказчика 2026-09-16
    //
    // Иначе получается **бесконечный цикл аванса**: старая бумажка
    // гасится, новая выпускается на ту же сумму, обязательство кассы
    // переписывается на новый срок, а живых денег не приходит ни разу.
    // Полный разбор — в докстринге [certificatePaysCertificateCode];
    // коротко: касса не получает ничего, а по счёту обязательства операция
    // проходит **сбалансированно** (гашение минус, выпуск плюс) и потому
    // не видна ни одной сверке по счёту.
    //
    // Решение **по признаку позиции** (`ProductType.giftCertificate`), а не
    // по виду оплаты в чеке, — то же правило, которым продажа сертификата
    // решает, идти ли ей в фискальный документ: сертификат в этом чеке —
    // то, что покупают, а не то, чем платят.
    //
    // Спрашивается только когда бумажки предъявлены: чек без сертификатов
    // в оплате не платит за лишнее чтение каталога.
    if (presented.isNotEmpty) {
      for (final sp in await _db.saleProductDao.findBySale(
        sale.receiptNo,
        sale.posId,
      )) {
        final product = await _db.productInfoDao.findByUcode(sp.ucode);
        if (product?.type == ProductType.giftCertificate.index) {
          _logger.warning(
            'Payment: receipt ${sale.receiptNo} sells a gift certificate and '
            'is paid by certificate — refused',
          );
          throw WireRefusal(
            certificatePaysCertificateCode,
            'сертификатом нельзя оплатить покупку другого сертификата',
          );
        }
      }
    }

    // # Аванс — второй зачёт, и он идёт следом за бонусом (задача 23)
    //
    // Форма та же, что у бонуса, и это не подражание, а следствие: оба
    // `PaymentSettlement.offset`, то есть уменьшают сумму к оплате, а не
    // заменяют собой способ её внести. Разница одна и она в том, откуда
    // берутся деньги: бонус кассе никто не приносил — он начислен ею
    // самой, а аванс **внесён покупателем раньше** и лежит кредитовым
    // сальдо на его расчётном счёте (`AccountType.agentMain`) — том же
    // самом, который уходит в минус при продаже в долг. Плюс —
    // покупатель внёс вперёд, минус — покупатель должен.
    //
    // Отсюда «ни своей таблицы, ни своего остатка» (спека, ярус 6):
    // второй остаток под то же число был бы второй правдой,
    // расходящейся с первой при первой же операции, которую забыли
    // продублировать.
    //
    // **Потолок здесь — не защита, а вежливость.** Он не даёт кассиру
    // зачесть больше внесённого, но между этим чтением и записью денег
    // есть окно, и в него помещается второй чек того же покупателя.
    // Настоящая защита — условная запись в `SaleUseCaseImpl.perform`
    // (`AccountDao.claimCredit`), внутри транзакции продажи.
    var prepayment = Decimal.zero;
    int? prepaymentAccountId;
    if (request.prepaymentUsed > Decimal.zero) {
      if (customerId == null) {
        throw const WireRefusal(
          payPrepaymentCustomerRequiredCode,
          'зачёт аванса требует названного покупателя',
        );
      }
      final agent = await _db.agentDao.findByLocalId(customerId);
      if (agent == null) {
        throw WireRefusal(
          payCustomerUnknownCode,
          'клиента $customerId нет в картотеке',
        );
      }
      prepaymentAccountId = agent.mainAccountId;
      if (prepaymentAccountId == null) {
        throw const WireRefusal(
          payPrepaymentAccountMissingCode,
          'у покупателя нет расчётного счёта — аванса на нём быть не может',
        );
      }
      final available =
          (await _db.accountDao.findById(prepaymentAccountId))?.value ??
          Decimal.zero;
      prepayment = request.prepaymentUsed;
      if (prepayment > available) prepayment = available;
    }

    // # Потолки по цепочке — один раз и одной функцией
    //
    // Каждый зачёт выше урезан только **своим** остатком (бонусный счёт,
    // деньги намерения, остаток бумажки, внесённый аванс). Урезать по
    // сумме чека и по соседям — работа [OffsetChain.split], и больше
    // ничья: её же зовёт экран оплаты, чтобы кассир **до** нажатия видел,
    // сколько спишется с бумажки и сколько зачтётся авансом. Две копии
    // этих потолков — ровно тот дефект, который слияние задач 21–23
    // измерило на «комнате, выданной трижды».
    //
    // Порядок в функции — «бонус → QR → сертификат → аванс», довод в блоке
    // «Порядок» выше. Аванс идёт последним и потому вычитает всё, что
    // вычли до него: зачесть авансом уже покрытое значит взять с
    // покупателя дважды.
    final split = OffsetChain.split(
      amount: amount,
      bonus: bonus,
      qr: qr,
      certificateBalances: [for (final p in presented) p.balance],
      prepayment: prepayment,
    );
    bonus = split.bonus;
    qr = split.qr;
    prepayment = split.prepayment;
    final certificate = split.certificate;

    final certificateLines = <PaymentEntry>[];
    for (var i = 0; i < presented.length; i++) {
      final paper = presented[i];
      final applied = split.certificates[i];
      if (applied <= Decimal.zero) {
        // Чек уже покрыт целиком: следующая бумажка не гасится ни на
        // тенге и **не пишется строкой**. Строка на ноль прошла бы
        // условное гашение мимо (ноль строк при `millis <= 0`) и осталась
        // бы в чеке ложью — «оплачено сертификатом», которого не
        // касались.
        _logger.info(
          'Payment: certificate ${paper.number} not applied — receipt '
          'already covered',
        );
        continue;
      }
      certificateLines.add(
        PaymentEntry(
          payeeAccountId: paper.accountId,
          amount: applied,
          kindId: SystemPaymentKindIds.certificate,
          customerLocalId: customerId,
          // **Номер — в `reference`, и это не украшение.** По нему и
          // только по нему гашение внутри транзакции находит бумажку, а
          // возврат — возвращает на неё долю. Строка оплаты без номера
          // сертификата непогасима и невозвратна.
          reference: paper.number,
        ),
      );
    }

    final toPay = split.toPay;

    final posAccountId = await _posAccountId();

    final payments = <PaymentEntry>[];
    var cash = Decimal.zero;
    var card = Decimal.zero;

    // **Сначала раскладка, потом достаточность** — порядок правки круга 2, а
    // не вкусовщина. Проверка вида оплаты идёт между ними, и до неё нехватка
    // наличных дойти не должна: `{card}` плюс смешанная на 400 картой и ноль
    // наличными отвечала `payment_insufficient` — «наличных меньше суммы» на
    // терминале, которому наличные запрещены вовсе. Кассир читает причину и
    // идёт её устранять, а устранять нечего: беда не в сумме.
    switch (request.type) {
      case PaymentType.cash:
        cash = toPay;
      case PaymentType.card:
        card = toPay;
      case PaymentType.mixed:
        // Та же формула, что была на экране: карта — сколько назвал
        // кассир (но не больше суммы к оплате), наличные — остаток.
        card = request.cardAmount > toPay ? toPay : request.cardAmount;
        cash = toPay - card;
      case PaymentType.debt:
        // Тумблер кассы — **до** раскладки денег, задача 16. Право
        // `op.sellDebt` (про человека) сторож провода уже проверил; здесь
        // проверяется место (про кассу), и сторож про него не знает
        // вовсе — он не читает базы кассы. Порядок не вкусовщина: беда
        // «здесь в кредит не торгуют» лечится настройками кассы, а не
        // выбором покупателя, и назвать её надо раньше, чем кассир
        // услышит «выберите покупателя» на кассе, где долга нет вообще.
        await _requireDebtSoldHere();
        // В долг платежи покрывают столько, сколько дали, — остаток
        // ложится на баланс покупателя.
        card = request.cardAmount > toPay ? toPay : request.cardAmount;
        final rest = toPay - card;
        cash = request.cashReceived > rest ? rest : request.cashReceived;
      case PaymentType.installment:
        // # Где рассрочка стоит в порядке раскладки — и почему НЕ в
        // цепочке зачётов
        //
        // Цепочка «бонус → QR → сертификат → аванс» разделяет **комнату**:
        // каждый её участник уменьшает сумму к доплате деньгами, которые
        // уже где-то лежат, и вопрос там один — кому достанется место,
        // если места на всех не хватает. Правило ответа названо слиянием:
        // первым берёт тот, кого урезать дороже.
        //
        // Рассрочка в этой цепочке не участвует **ни первой, ни
        // последней**: она не зачёт, а `PaymentSettlement.deferred` — она
        // не уменьшает сумму к доплате, а **заменяет собой способ её
        // внести**. Её сумма не выбирается и не урезается: она равна
        // тому, что осталось после всех зачётов и всех живых денег, до
        // единой тысячной. Урезать её нечем и не за чем — урезанная
        // рассрочка это просто рассрочка на меньшую сумму, а остаток чека
        // тогда не покрыт ничем.
        //
        // Отсюда её место — **та же ступень, что у долга: после всех**.
        // Формально: `principal = amount − (cash + card + bonus + qr +
        // prepayment + certificate)`, и это то же выражение, которым
        // считается долг, потому что вопрос тот же — «сколько осталось
        // не оплаченным».
        //
        // Проверка этого утверждения числом — в
        // `installment_with_neighbours_test`: аванс, сертификат и QR
        // урезают **тело договора**, а не друг друга, и каждый на свою
        // сумму.
        //
        // Тумблер кассы тот же, что у долга, и это не экономия: настройка
        // называется «здесь не торгуют в кредит», а рассрочка — кредит.
        // Второй тумблер рядом дал бы кассу, где кредит выключен, а
        // рассрочка работает.
        await _requireDebtSoldHere();
        // Первый взнос — обычные деньги, теми же двумя строками, что у
        // долга. Отдельного поля под него нет намеренно: «сколько
        // покупатель отдал сейчас» уже спрошено (`cashReceived`,
        // `cardAmount`), и второе поле под то же число разошлось бы с
        // первым.
        card = request.cardAmount > toPay ? toPay : request.cardAmount;
        final paidNow = toPay - card;
        cash = request.cashReceived > paidNow ? paidNow : request.cashReceived;
    }

    // Виды оплаты рабочего места — **по числам кассы**, а не по полям
    // заявки (задача 15). Здесь, внутри раскладки, а не после неё: наличная
    // и безналичная части уже посчитаны, а до отказов по достаточности ещё
    // не дошло.
    await _requireAllowedTypes(terminalId, {
      if (cash > Decimal.zero) PaymentType.cash,
      if (card > Decimal.zero) PaymentType.card,
    });

    // Достаточность наличных — после вида: см. довод выше.
    final needsCash = request.type == PaymentType.cash
        ? toPay
        : request.type == PaymentType.mixed
        ? cash
        : Decimal.zero;
    if (request.cashReceived < needsCash) {
      throw const WireRefusal(
        payInsufficientCode,
        'наличных меньше суммы к оплате',
      );
    }

    if (cash > Decimal.zero) {
      if (posAccountId == null) {
        throw const WireRefusal(
          payAccountMissingCode,
          'у кассы нет счёта для наличных',
        );
      }
      payments.add(
        PaymentEntry(
          payeeAccountId: posAccountId,
          amount: cash,
          kindId: SystemPaymentKindIds.cash,
          customerLocalId: customerId,
        ),
      );
    }
    if (card > Decimal.zero) {
      // Счёт спрашивается **здесь**, а не выше: `PaymentRequest.accountId`
      // читается только безналичной частью, и проверять поле на пути,
      // который его не читает, значило бы отвергать оплату из-за довода,
      // до которого дело не доходит. Круг правки 1 звал проверку
      // безусловно — и наличная оплата с умолчанием экрана (счёт кассы)
      // переставала проходить вовсе.
      final accountId = await _bankAccountId(request.accountId) ?? posAccountId;
      if (accountId == null) {
        // **Ветка мёртвая, и это замер, а не догадка** (круг правки 3):
        // [_bankAccountId] возвращает `null` только если бы вернул его
        // `createAcquiringAccount`, а тот возвращает `int`. Оставлена
        // потому, что тип говорит `int?`, и молчаливый `!` на «невозможном»
        // пути — способ узнать о невозможном через испорченные деньги.
        throw const WireRefusal(
          payAccountMissingCode,
          'у кассы нет счёта для безналичной оплаты',
        );
      }
      // **Здесь стоял отказ `payment_account_conflict`, и он снят
      // задачей 14.** Он существовал ровно потому, что существовал
      // старый уникальный ключ `{receiptNo, posId, payeeAccountId}`:
      // наличная и безналичная части, обе упавшие на счёт кассы,
      // сталкивались в базе сырым `SqliteException(2067)`. С ключом по
      // `seq` две строки на один счёт — законны и нужны: они различаются
      // **видом оплаты**, а не счётом, и вид у них теперь записан.
      //
      // Цена названа и уплачена той же задачей: отчёт смены суммировал
      // **по счёту** и слил бы две строки в одну — запрос получил второе
      // измерение `kindId`
      // (`CustomBankPaymentsSumUseCaseImpl`, `ReportDao.paymentsByKind`).
      payments.add(
        PaymentEntry(
          payeeAccountId: accountId,
          amount: card,
          kindId: SystemPaymentKindIds.card,
          customerLocalId: customerId,
          approvalCode: request.approvalCode,
          cardMask: request.cardMask,
          terminalTransactionId: request.transactionId,
        ),
      );
    }
    if (bonus > Decimal.zero) {
      payments.add(
        PaymentEntry(
          payeeAccountId: cashbackAccountId!,
          amount: bonus,
          kindId: SystemPaymentKindIds.bonus,
          customerLocalId: customerId,
        ),
      );
    }
    if (qr > Decimal.zero) {
      // Счёт — банковский, как у карты: деньги пришли на счёт в банке, а
      // не в денежный ящик. Класть их на счёт кассы значило бы завысить
      // наличные смены на сумму, которой в ящике нет, и разойтись с
      // инкассацией на первой же сверке.
      final accountId = await _bankAccountId(request.accountId) ?? posAccountId;
      if (accountId == null) {
        throw const WireRefusal(
          payAccountMissingCode,
          'у кассы нет счёта для безналичной оплаты',
        );
      }
      payments.add(
        PaymentEntry(
          payeeAccountId: accountId,
          amount: qr,
          kindId: SystemPaymentKindIds.qr,
          customerLocalId: customerId,
          // Оба поля заведены задачей 14 **ровно под этот случай**:
          // документ-основание и код провайдера. Без них подтверждение,
          // пришедшее снаружи, не с чем сверить — а сверять придётся,
          // потому что деньги ходят по чужому расписанию.
          reference: qrIntent!.intentKey,
          providerCode: qrIntent.providerCode,
          terminalTransactionId: qrIntent.providerIntentId,
        ),
      );
    }
    if (prepayment > Decimal.zero) {
      // Счёт-получатель — **расчётный счёт покупателя**, а не счёт
      // кассы: зачёт уменьшает обязательство кассы перед покупателем, а
      // живых денег не приносит. Положи он деньги в кассу — выручка
      // смены выросла бы второй раз на те же деньги, потому что первый
      // раз они пришли при приёме аванса.
      //
      // `reference` — единственное место, где чек называет документ,
      // по которому зачтено: своей таблицы у аванса нет.
      payments.add(
        PaymentEntry(
          payeeAccountId: prepaymentAccountId!,
          amount: prepayment,
          kindId: SystemPaymentKindIds.prepayment,
          customerLocalId: customerId,
          reference: request.prepaymentReference,
        ),
      );
    }
    // Строки сертификатов собраны выше, вместе с потолками; кладутся
    // здесь, чтобы порядок строк в чеке совпадал с порядком раскладки.
    //
    // **Место в списке — после аванса, хотя в раскладке сертификат идёт
    // до него.** Расхождение намеренное и стоит ноль: порядок строк
    // `Payments` ни на одно число не влияет (уникальный ключ —
    // `{receiptNo, posId, seq}`, суммы складываются), а собрать
    // `certificateLines` до цикла потолков нельзя — там ещё не известны
    // применённые суммы.
    payments.addAll(certificateLines);

    // Слагаемых **пять**, и это единственное место, где список полон:
    // `+ qr` — задача 22, `+ prepayment` — задача 23, `+ certificate` —
    // задача 21. Пропуск любого — выдуманный долг у покупателя, который
    // уже отдал: телефоном, авансом или бумажкой.
    final paid = cash + card + bonus + qr + prepayment + certificate;
    final debt = amount - paid;

    // Должник: кому записать остаток. Для трёх остальных видов оплаты
    // сюда идёт покупатель чека — и остаток у них ноль, так что баланс не
    // двигается (`perform` считает `amount - paymentSum`).
    //
    // **Клиент лояльности сюда НЕ подставляется, и это решение круга
    // правки 2, а не упущение.**
    //
    // **Главный довод — первым, потому что он и есть главный: это не новое
    // поведение, а возвращённое базовое.** На `4daacda`
    // `Payments.customerLocalId` уже писался на каждой строке оплаты
    // (`PaymentEntry.customerLocalId` ниже), а `Sales.customerLocalId`
    // клиентом лояльности — нет. Круг правки 1 завёл новое, круг правки 2
    // его снял; выбирать между двумя новыми поведениями не пришлось.
    //
    // Чек покупателя при этом не потерял: имя он берёт из строк оплаты.
    //
    // **Почему круг правки 1 был неправ — измерение.**
    //
    // Круг правки 1 подставил его (`sale.customerLocalId ?? customerId`),
    // чтобы чек назвал покупателя. На балансе самой продажи это
    // действительно ноль — `perform` двигает `amount - paymentSum`, а он
    // у неотложенных видов оплаты нулевой. Но следствие оказалось шире и
    // денежным, и измерено оно на возврате:
    //
    // - `refund_controller.dart:262` кладёт `sale.customerLocalId` в
    //   `ReceiptInfo`, `:507` отдаёт его в `RefundUseCase.perform`;
    // - `refund_use_case_impl.dart:111` —
    //   `if (customerLocalId != null) await _updateAgentBalance(...)`,
    //   **безусловно и независимо от вида оплаты**.
    //
    // То есть возврат обычной наличной продажи покупателю, чей телефон
    // кассир набрал ради бонусов, двигал бы ему расчётный счёт сверх
    // наличных, выданных из ящика. Условие срабатывания расширилось бы с
    // «привязать агента намеренно» до «набрать телефон», а экран возврата
    // — живой. Это чужая задача (фаза 7 плана), и расширять её условие
    // молчком нельзя.
    //
    // **Риск, названный, а не спрятанный.** «Ничто денежное не читает» —
    // верно только для живого кода. У `Payments.customerLocalId` есть
    // читатель `PaymentDao.sumAmountByCustomerLocalId`, и он **мёртв**:
    // его единственный вызывающий — `AgentBalanceServiceImpl`, у которого
    // во всём `lib/` нет ни одного резолва, кроме собственной регистрации
    // в `service_locator.dart:1134`. Разбудить его — и клиент лояльности
    // получит мнимый кредит на всю сумму чека, потому что суммой платежей
    // там считается «сколько клиент внёс». Это тот же класс риска, что
    // мёртвая ветка `isRefund`, и назван он здесь по той же причине.
    //
    // **Потеря, названная честно.** Клиент лояльности больше не попадает
    // в выгрузку: `couchdb_sync_coordinator.dart:422` отдаёт
    // `customer_local_id` **из `Sales`**, а строки оплаты в выгрузку не
    // едут вовсе. Это цена решения, а не его побочный подарок; лечится
    // отдельной колонкой чека под покупателя, которую возврат не читает,
    // — работой со своей спекой, не этой задачей.
    int? agentLocalId = sale.customerLocalId;
    CreditContractDraft? credit;
    // Долг и рассрочка — **одна ветка, и это не экономия строк**. Обе
    // отвечают на один вопрос: «кто остался должен и сколько». Разведи их
    // — и первое же расхождение (забытая проверка счёта, забытое
    // слагаемое в остатке) жило бы в одной половине и не жило бы в
    // другой. Различаются они ровно двумя вещами: видом строки оплаты и
    // тем, что у рассрочки сверх строки рождается договор.
    final isDeferredSale =
        request.type == PaymentType.debt ||
        request.type == PaymentType.installment;
    if (isDeferredSale) {
      final installment = request.type == PaymentType.installment;
      final debtorId = customerId ?? sale.customerLocalId;
      if (debtorId == null) {
        throw WireRefusal(
          payDebtorRequiredCode,
          installment
              ? 'продажа в рассрочку требует названного покупателя'
              : 'продажа в долг требует названного покупателя',
        );
      }
      final debtor = await _db.agentDao.findByLocalId(debtorId);
      if (debtor == null) {
        throw WireRefusal(
          payCustomerUnknownCode,
          'клиента $debtorId нет в картотеке',
        );
      }
      if (debtor.mainAccountId == null) {
        // `SaleUseCaseImpl._updateAgentBalance` на такой строке молча
        // возвращается — долг растворился бы без следа, товар отдан,
        // записи нет.
        throw const WireRefusal(
          payDebtorAccountMissingCode,
          'у покупателя нет расчётного счёта — долг записать некуда',
        );
      }
      agentLocalId = debtorId;

      // ── просрочка: заслон стоит ЗДЕСЬ, и это ответ на «что, если
      //    никто не смотрит» ────────────────────────────────────────────
      //
      // Просрочка вычисляемая (шаг 3 задачи 24): хранить её нечем —
      // фоновой работы, переживающей выключение питания, в дереве нет, а
      // хранимое значение на кассе, простоявшей неделю, врало бы ровно
      // неделю. Но «вычислить может кто угодно» на практике означает
      // «никто»: экран можно не открыть, отчёт — не построить.
      //
      // Поэтому у вычисления есть **обязательный читатель на денежном
      // пути**, и он здесь: касса отказывается выдать вторую рассрочку
      // тому, кто просрочил первую. Просрочку замечает не человек, а та
      // операция, которой она дороже всего обойдётся, — выдача товара
      // тому, кто не заплатил за прошлый.
      //
      // **Долг сюда намеренно не попал.** У продажи в долг нет ни срока,
      // ни графика: просрочить нечего, и спрашивать не о чем. Расширить
      // заслон на долг значило бы завести срок там, где его никто не
      // подписывал.
      if (installment && await _credit.hasOverdue(debtorId)) {
        _logger.warning(
          'Payment: customer $debtorId has an overdue contract — '
          'installment refused',
        );
        throw const WireRefusal(
          creditOverdueCode,
          'у покупателя просрочен другой договор рассрочки — новая '
          'рассрочка не выдаётся',
        );
      }

      // **Строка оплаты у долга — задача 14, и она главная в ней.**
      //
      // До неё долг не имел строки вовсе: он выводился разностью «сумма
      // чека минус сумма платежей». Замер, закреплённый задачей 16:
      // продажа в долг на 1000 с 300 наличными оставляла в `Payments`
      // **одну** строку на 300 — семисот не было ни одной строкой.
      // Инвариант «Σ строк оплаты == сумма чека» был нарушен у каждой
      // продажи в долг, и нарушен молча: чтобы его увидеть, надо было
      // знать, что смотреть.
      //
      // Строка ложится на **расчётный счёт покупателя** и несёт вид
      // `debt` (`PaymentSettlement.deferred`). Обычным движением по счёту
      // она не проводится — знак у рода `agentMain` не перевёрнут, и
      // `post(+700)` дал бы покупателю переплату вместо задолженности;
      // разбор и расчёт — в `SaleUseCaseImpl.perform`. Число остатка
      // остаётся тем же самым: −700 как и было.
      // `+ qr` — задача 22, `+ prepayment` — задача 23, `+ certificate`
      // — задача 21. Забыть здесь одно слагаемое значит записать
      // покупателю в долг деньги, которые он уже отдал — телефоном,
      // авансом или бумажкой: товар отдан, чек сошёлся бы по строкам, а
      // долг был бы выдуман. Ровно этот пропуск и ловит
      // `payment_unbalanced`. Список слагаемых обязан совпадать с `paid`
      // выше — при слиянии трёх задач разошлись бы именно здесь, и
      // сторож «сертификат + долг» меряет как раз это.
      //
      // **Рассрочка идёт по этому же выражению — задача 24.** Тело
      // договора и есть остаток чека: у обоих видов вопрос один, и
      // второе выражение рядом разошлось бы с первым на первом же новом
      // виде зачёта.
      final deferred =
          amount - (cash + card + bonus + qr + prepayment + certificate);
      if (deferred > Decimal.zero) {
        payments.add(
          PaymentEntry(
            payeeAccountId: debtor.mainAccountId!,
            amount: deferred,
            kindId: installment
                ? SystemPaymentKindIds.installment
                : SystemPaymentKindIds.debt,
            customerLocalId: debtorId,
            // Номер договора — **тот же, что напечатан**, и собирается он
            // из номера чека (`CreditContractNumber`). По нему строка
            // оплаты объясняет себя через три года, и по нему же
            // погашение находит договор. Строка рассрочки без номера
            // договора необъяснима.
            reference: installment
                ? CreditContractNumber.of(
                    receiptNo: sale.receiptNo,
                    posId: sale.posId,
                  )
                : null,
          ),
        );
      }

      if (installment) {
        if (deferred <= Decimal.zero) {
          // Чек, покрытый деньгами и зачётами целиком, рассрочкой не
          // является: договора на ноль не бывает. Отказ, а не молчаливое
          // «продали как обычно»: кассир выбрал рассрочку, покупатель
          // ждёт договор, и отдать вместо него обычный чек значит
          // разойтись с ожиданием обеих сторон без единого слова.
          throw const WireRefusal(
            creditPrincipalInvalidCode,
            'чек покрыт целиком — рассрочку не на что оформлять',
          );
        }

        // # Договор на этот чек уже есть — ветка НЕДОСТИЖИМА сегодня, и
        //   это ЗАМЕР, а не догадка
        //
        // Диверсия: `if (false && existing != null)` — набор
        // `test/data/sale/` остался **полностью зелёным** (315 проб).
        // Значит ни один путь дерева сюда не приводит, и честно это
        // назвать, а не выдать сторожа за проверенный.
        //
        // Так и должно быть по построению: чек, на котором уже есть
        // договор, оплачен, и повтор до раскладки не доходит вовсе —
        // `payment_already_taken` (чужой ключ) или прежний итог (свой
        // ключ) отвечают раньше, в `_complete`. Иными словами, дубль
        // здесь закрыт **состоянием чека**, а не этой проверкой.
        //
        // # Почему проверка всё равно остаётся
        //
        // Тот же довод, что у `payment_unbalanced` ниже, и он на этом
        // дереве уже сбылся дважды: она сторожит **следующую работу**.
        // Отмена оплаты (спека её называет отдельной задачей со своим
        // экраном) вернёт чек в состояние «в работе», не тронув
        // договора, — и вторая оплата пойдёт сюда с живым договором на
        // руках. Без этой ветки она получила бы сырой
        // `SqliteException(2067)` **внутри транзакции продажи**: отказ
        // без имени и уже после списания товара.
        //
        // Настоящий заслон при этом стоит в базе (уникальный ключ
        // `{receiptNo, posId}`), и он **проверен** —
        // `migration_v45_credit_test`, «уникальный ключ не даёт второй
        // договор на один чек». Разница между недостижимой веткой,
        // названной недостижимой, и веткой, про которую соврали, что она
        // проверена, — вся.
        final existing = await _credit.byReceipt(
          receiptNo: sale.receiptNo,
          posId: sale.posId,
        );
        if (existing != null) {
          throw WireRefusal(
            creditContractDuplicateCode,
            'на чек ${sale.receiptNo} уже оформлен договор '
            '${existing.contract.number}',
          );
        }

        final scheme = InstallmentScheme.byCode(request.installmentScheme);
        if (scheme == null) {
          // Подстановки нет и быть не может: схема уезжает в **печатный
          // договор**, и выдуманная была бы подписана покупателем как
          // своя.
          throw WireRefusal(
            creditSchemeUnknownCode,
            'схема рассрочки «${request.installmentScheme}» кассе '
            'неизвестна',
          );
        }
        final term = request.installmentTermMonths;
        if (term == null || !InstallmentScheduler.allowedTerms.contains(term)) {
          throw WireRefusal(
            creditTermInvalidCode,
            'срок рассрочки ${term ?? 'не назван'} — не из числа '
            'допустимых (${InstallmentScheduler.allowedTerms.join(', ')})',
          );
        }

        credit = CreditContractDraft(
          agentLocalId: debtorId,
          // **Снимок счёта, а не ссылка на живое поле** — шаг 4. Счёт
          // покупателя могут сменить; долг обязан остаться там, где
          // записан, иначе погашение договора трёхлетней давности
          // двинуло бы счёт, которого при подписи не существовало.
          receivableAccountId: debtor.mainAccountId!,
          principal: deferred,
          // Ноль, и это посчитанный ответ: надбавка вне суммы чека —
          // деньги без фискального документа. Разбор — в докстринге
          // `PaymentRequest`, раздел «Чего здесь НЕТ».
          feeTotal: Decimal.zero,
          downPayment: cash + card,
          termMonths: term,
          scheme: scheme,
        );
      }
    }

    // **Σ строк оплаты == сумма чека — проверяется, а не подразумевается.**
    //
    // Три нарушения этого инварианта жили в дереве годами именно потому,
    // что спросить было некому: у долга не было строки, а «сумма
    // платежей» нигде не сравнивалась с суммой чека. Отказ приходит **до
    // единой записи**.
    //
    // # Ветка недостижима сегодня, и это ЗАМЕР, а не догадка
    //
    // Диверсия: `if (false && tendered != amount)` — набор
    // `test/data/sale/` остался **полностью зелёным** (250 проб). Значит
    // ни один путь дерева сюда не приводит, и честно это назвать, а не
    // выдать сторожа за проверенный.
    //
    // Так и должно быть по построению: наличная часть равна остатку
    // (`cash = toPay - card`), долговая — недостаче
    // (`deferred = amount - (cash + card + bonus)`), а `Decimal` не
    // теряет копеек. Иными словами, равенство здесь держится
    // арифметикой, а не проверкой.
    //
    // # Почему проверка всё равно остаётся
    //
    // Она сторожит **следующий вид оплаты**. Сертификат, предоплата и
    // QR (виды 5–8 справочника, сегодня выключенные) добавятся в эту
    // самую раскладку, и первая же забытая строка «вычесть из остатка»
    // даст чек, у которого сумма строк меньше суммы. Без этой ветки он
    // уехал бы в базу и в ОФД молча; с ней — назовёт себя отказом
    // прежде, чем касса возьмёт деньги.
    //
    // Это не «сторож на веру»: разница между недостижимой веткой,
    // названной недостижимой, и веткой, про которую соврали, что она
    // проверена, — вся.
    //
    // # Предсказание сбылось, и оно ЗАМЕРЕНО — задача 23
    //
    // Аванс стал тем самым следующим видом. Диверсия ровно того вида,
    // ради которого ветку берегли: `toPay = amount - bonus`, без
    // вычитания зачтённого аванса, при том что строка зачёта в раскладку
    // всё равно кладётся.
    //
    // **Отказ пришёл — `payment_unbalanced`, «сумма строк оплаты (1600)
    // не равна сумме чека (1000)».** То есть ветка достижима, и с этой
    // задачи она больше не «недостижимая, названная таковой».
    //
    // Но у замера оказалась вторая половина, и она важнее первой:
    // **на наличном чеке до этой ветки дело не доходит**. Та же
    // диверсия там падает раньше и на другом отказе —
    // `payment_insufficient` («наличных меньше суммы к оплате»), потому
    // что достаточность наличных считается до сверки. Сторож сработал
    // только на безналичном чеке, где достаточности наличных не
    // спрашивают вовсе.
    //
    // Отсюда правило для следующего вида зачёта (сертификат, QR):
    // **проба обязана быть безналичной**, иначе она измеряет не этот
    // сторож, а соседний. `prepayment_offset_test.dart`, «зачёт вместе
    // с картой».
    //
    // Второй замер уточняет первый: диверсия в **потолке**, а не в
    // вычитании (`rest = amount` вместо `amount - bonus`, то есть аванс
    // зачитывает и то, что уже покрыто бонусом), доходит до сверки и на
    // наличном чеке — `сумма строк оплаты (1300) не равна сумме чека
    // (1000)`. Разница в том, что там наличная часть не выросла, а
    // выросла сумма строк. Значит правило точнее: соседний сторож
    // перехватывает не «всякую ошибку раскладки», а только ту, что
    // увеличивает **наличную** долю.
    final tendered = payments.fold<Decimal>(
      Decimal.zero,
      (sum, p) => sum + p.amount,
    );
    if (tendered != amount) {
      _logger.warning(
        'Payment: unbalanced plan — receipt $amount, tenders $tendered',
      );
      throw WireRefusal(
        payUnbalancedCode,
        'сумма строк оплаты ($tendered) не равна сумме чека ($amount)',
      );
    }

    // **Вид, выключенный оператором, выключен и для кассы.**
    //
    // Без этой проверки справочник был бы окном, в которое видно, но
    // через которое ничего не проходит: оператор снял бы галочку с
    // «Карты», а касса продолжала бы её принимать. Ровно тот класс
    // дефекта, ради которого в этом дереве заведено правило «таблица,
    // сторож и экран входят одной задачей»: настройка, ничего не
    // меняющая, хуже отсутствующей — на неё полагаются.
    //
    // Проверка **здесь**, а не в обработчике провода: сюда сходятся оба
    // пути — кадр из браузера и десктопная касса, зовущая контракт
    // напрямую. Тот же довод, что у [_requireAllowedTypes].
    //
    // Отличие от [_requireAllowedTypes] названо, чтобы их не спутали:
    // там — **рабочее место** («планшет в зале берёт только безнал»),
    // здесь — **касса целиком** («мы больше не принимаем бонусы»).
    for (final entry in payments) {
      final kind = await _kinds.byId(entry.kindId);
      if (kind == null) {
        throw WireRefusal(
          payKindUnknownCode,
          'вида оплаты ${entry.kindId} нет в справочнике кассы',
        );
      }
      if (!kind.isActive) {
        _logger.warning('Payment: kind ${kind.code} is switched off');
        throw WireRefusal(
          payKindInactiveCode,
          'вид оплаты «${kind.name}» выключен в настройках кассы',
        );
      }
    }

    // Сдача. Считает **касса**: разница между тем, что дали наличными, и
    // тем, что наличными нужно. Присланное терминалом число не участвует
    // в расчёте ни одной ветвью — оно только сверяется.
    final given = request.type == PaymentType.card
        ? Decimal.zero
        : request.cashReceived;
    final rawChange = given - cash;
    final change = rawChange > Decimal.zero ? rawChange : Decimal.zero;
    _noteChangeDisagreement(request, change);

    return _PaymentPlan(
      payments: payments,
      change: change,
      paid: paid,
      debt: debt > Decimal.zero ? debt : Decimal.zero,
      bonus: bonus,
      cash: cash,
      card: card,
      qrIntentId: qrIntent?.id,
      agentLocalId: agentLocalId,
      credit: credit,
    );
  }

  /// Разрешены ли [types] рабочему месту [terminalId] — задача 15, решение
  /// заказчика №5.
  ///
  /// # Почему проверка здесь, а не в обработчике провода
  ///
  /// Сюда сходятся **оба** пути: кадр из браузера
  /// (`TillOperations.askHandlers[pay.complete]`) и десктопная касса,
  /// зовущая контракт напрямую, минуя провод целиком. Проверка в
  /// обработчике закрыла бы только первый, и настройка рабочего места самой
  /// кассы не значила бы на ней ничего — тот же приём и тот же довод, что у
  /// `LocalTerminalRepository._requireName`/`delete`.
  ///
  /// Экран при этом волен прятать запрещённый вид — так удобнее кассиру, —
  /// но прячет он **для удобства**: доказательством запрета спрятанная
  /// кнопка не является (I162), и ни одна проба задачи 15 на неё не
  /// опирается.
  ///
  /// # Чего эта проверка не делает
  ///
  /// Терминала, которого нет в базе, она не находит и **пропускает**
  /// молча — но это не дыра: имя рабочего места берётся из сеанса
  /// (`TillOperations._payTerminal`), а сеанс без заведённого терминала
  /// получает `unknown_terminal` раньше, чем дело доходит сюда. Отказывать
  /// здесь по несуществующей строке значило бы останавливать десктопную
  /// кассу, у которой строки терминала ещё нет (мастер настройки не
  /// пройден), — а у неё и запрета никакого нет.
  Future<void> _requireAllowedTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {
    if (types.isEmpty) return;
    final row = await _db.terminalDao.findById(terminalId);
    if (row == null) return;
    // Разбор — той же парой, которой пишет и читает `LocalTerminalRepository`
    // (`storedPaymentTypes`/`paymentTypesFromStored`), а «пустое означает
    // все» — [domain.Terminal.allows]. Ни то, ни другое здесь не переписывается:
    // второй разбор того же формата был бы вторым ответом на вопрос «что
    // разрешено рабочему месту».
    final allowed = LocalTerminalRepository.paymentTypesFromStored(
      row.allowedPaymentTypes,
      terminalId: row.id,
    );
    final terminal = domain.Terminal(
      id: row.id,
      name: row.name,
      // Режим здесь ни при чём — читается только набор видов; форма
      // `Terminal` взята ради [domain.Terminal.allows].
      pointMode: domain.PointMode.cashier,
      allowedPaymentTypes: allowed,
    );

    final denied = types.where((type) => !terminal.allows(type)).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (denied.isEmpty) return;

    _logger.warning(
      'Payment: terminal $terminalId is not allowed to take '
      '${denied.map((t) => t.name).join(', ')} '
      '(allowed: ${domain.paymentTypeNames(allowed).join(', ')})',
    );
    throw WireRefusal(
      payTypeNotAllowedCode,
      'этому рабочему месту не разрешён такой вид оплаты: '
      '${denied.map(_typeLabel).join(', ')}',
    );
  }

  /// На этой кассе торгуют в долг — иначе названный отказ (задача 16).
  ///
  /// # Почему здесь, а не в обработчике провода и не на экране
  ///
  /// Тот же довод, что у [_requireAllowedTypes], и он стоил задаче 15
  /// круга правки. Сюда сходятся **оба** пути: кадр из браузера и
  /// десктопная касса, зовущая контракт напрямую, минуя провод целиком.
  /// Проверка в обработчике оставила бы тумблер бессмысленным на самой
  /// кассе; проверка на экране — бессмысленным для всякого, кто соберёт
  /// кадр руками (I44, I162).
  ///
  /// # Почему тумблер не заменяется правом `op.sellDebt`
  ///
  /// Право у роли администратора есть по должности и переносится с ним из
  /// магазина в магазин. Тумблер — свойство точки: «здесь в кредит не
  /// торгуют». Одно вместо другого означало бы, что администратор
  /// продаёт в долг там, где долга нет вовсе, — то есть отдаёт товар за
  /// запись в базе, которую владелец точки запретил.
  Future<void> _requireDebtSoldHere() async {
    if (await sellsInDebt()) return;
    _logger.warning(
      'Payment: debt sale refused — sellInDebt is off on this till',
    );
    throw const WireRefusal(
      payDebtNotSoldHereCode,
      'на этой кассе не торгуют в долг — продажа в кредит выключена в '
      'настройках кассы',
    );
  }

  static String _typeLabel(PaymentType type) => switch (type) {
    PaymentType.cash => 'наличные',
    PaymentType.card => 'карта',
    PaymentType.mixed => 'смешанная',
    PaymentType.debt => 'в долг',
    PaymentType.installment => 'рассрочка',
  };

  /// Терминал посчитал сдачу иначе, чем касса.
  ///
  /// Не отказ: касса и так вернёт своё число, и оплата от этого не
  /// становится неправильной. Но след обязателен — расхождение значит
  /// либо ошибку в экране, либо клиента, который нам не принадлежит, и
  /// обе беды не должны проходить молча.
  void _noteChangeDisagreement(PaymentRequest request, Decimal change) {
    final claimed = request.claimedChange;
    if (claimed == null || claimed == change) return;
    _logger.warning(
      'Payment: terminal claimed change $claimed, till computed $change '
      '— принято число кассы',
    );
  }

  /// Счёт кассы для наличных.
  ///
  /// Порядок тот же, что был в `processPayment`: `ThisPos.accountId`,
  /// иначе первый счёт типа «касса», иначе завести. Последнее — не
  /// удобство: без счёта кассы принять наличные негде вовсе, и отказать
  /// вместо заведения значило бы остановить торговлю на кассе, где мастер
  /// настройки прошёл криво.
  Future<int?> _posAccountId() async {
    final thisPos = await _db.thisPosDao.get();
    final known = thisPos?.accountId;
    if (known != null) return known;
    final pos = await _db.accountDao.findByType(AccountType.pos);
    if (pos.isNotEmpty) return pos.first.id;
    return _db.accountDao.createPosAccount(name: 'POS');
  }

  /// Счёт для безналичной части: названный кассиром, иначе первый
  /// видимый банковский, иначе заведённый.
  ///
  /// **Названный счёт проверяется против того самого списка, который
  /// касса отдаёт [accounts]** — C3 круга правки 1. Без проверки это была
  /// вторая дыра того же класса, что и сдача: браузер диктовал, **куда
  /// лягут деньги**. Пробы разбора увели выручку на расчётный счёт агента
  /// и уменьшили оплатой картой бонусный баланс покупателя — счёт брался
  /// как есть, без вопроса, существует ли он и предлагался ли он вообще.
  ///
  /// **Против всего списка, а не его половины** (круг правки 2). Первая
  /// версия сверяла только с банковскими счетами, а [accounts] отдаёт ещё
  /// и кассовые — и отвергала счёт, который сама же и предложила. Список
  /// берётся вызовом [accounts], а не вторым запросом рядом: пока это
  /// один и тот же вызов, «предложенное» и «принимаемое» не могут
  /// разойтись молча.
  ///
  /// Кассовый счёт под безналичную часть допускается тем же доводом, что
  /// и до всякой проверки: умолчание ниже уже падало на `posAccountId`,
  /// когда банковского счёта нет вовсе. Дыра C3 была не в этом, а в
  /// счетах, которых касса **не предлагала** — агентских и бонусных.
  Future<int?> _bankAccountId(int? asked) async {
    if (asked != null) {
      final offered = await accounts();
      if (!offered.any((account) => account.id == asked)) {
        _logger.warning('Payment: account $asked was not offered by the till');
        throw const WireRefusal(
          payAccountNotAllowedCode,
          'этот счёт касса для оплаты не предлагала',
        );
      }
      return asked;
    }
    final bank = await _db.accountDao.findByTypeAndVisibility(
      AccountType.customBank,
      true,
    );
    if (bank.isNotEmpty) return bank.first.id;
    return _db.accountDao.createAcquiringAccount(
      name: 'Bank (card)',
      acquirerId: 0,
    );
  }

  Future<void> _accrueCashback(
    PaymentRequest request,
    _PaymentPlan plan,
    int receiptNo,
  ) async {
    final bonuses = _bonuses;
    final customerId = request.customerId;
    if (bonuses == null || customerId == null) return;
    try {
      final agent = await _db.agentDao.findByLocalId(customerId);
      final phone = agent?.phone;
      if (phone == null) return;
      final base = plan.paid - plan.bonus;
      if (base <= Decimal.zero) return;
      final result = await bonuses.accrualBonuses(
        phone: phone,
        saleAmount: base,
        saleReceiptNo: receiptNo,
      );
      _logger.info(
        'Payment: cashback accrued ${result.accruedAmount} -> '
        '${result.newBalance}',
      );
    } catch (e, st) {
      // Начисление кэшбэка не блокирует оплату — так было и до провода
      // (`_accrueCashback`, «non-blocking»): деньги уже взяты, чек уже
      // проведён, и уронить всё из-за бонусной программы значило бы
      // сделать хуже, чем не начислить.
      _logger.warning('Payment: cashback accrual failed: $e', e, st);
    }
  }

  /// Смена не старше суток — иначе оплата не проходит (I1 круга правки 1).
  ///
  /// Тем же правилом и тем же кодом отказывает начало чека
  /// (`LocalCartService.start`) — одно правило на оба пути кассы. Ветки
  /// «проверить нечем» здесь больше нет: см. [_shiftAge].
  Future<void> _requireShiftNotOverAge() => _shiftAge.require();

  /// Код одобрения карты, который касса **не выдавала**, — отказ.
  ///
  /// Проверяется только там, где у кассы есть собственное доказательство:
  /// к рабочему месту привязан платёжный терминал, значит проведение
  /// обязано было пройти через [chargeCard] и лежит в [_cardCharges].
  ///
  /// **Предел назван, а не закрыт:** при ручном вводе карты (эквайринга у
  /// места нет — кассир проводит её на отдельном устройстве и переписывает
  /// код) доказательства у кассы нет ни в каком виде, и выдуманный код
  /// пройдёт. Это неустранимо, пока код вводится руками, и записано здесь,
  /// чтобы следующий не принял отсутствие проверки за упущение.
  Future<void> _requireCardProof(
    int terminalId,
    Sale sale,
    PaymentRequest request,
    _PaymentPlan plan,
  ) async {
    if (plan.card <= Decimal.zero) return;
    switch (await _terminalBinding(terminalId)) {
      case _BrokenBinding(:final reason):
        // Задача 41: прежде сломанная привязка давала тот же `null`, что
        // «терминала нет», и проверка выходила молча — чек оплачивался
        // выдуманным кодом там, где эквайринг был, но настроен неверно.
        throw WireRefusal(payTerminalMisconfiguredCode, reason);
      case _NoTerminal():
        // Ручной путь карты: предел назван в докстринге выше. Выход —
        // **записью**, а не молчанием: в журнале видно, какие чеки оплачены
        // кодом, которого касса не выдавала.
        _logger.info(
          'Payment: card approval entered by hand receipt=${sale.receiptNo} '
          'terminal=$terminalId — no payment terminal bound, no till proof',
        );
        return;
      case _BoundTerminal():
        break;
    }

    // По **составному ключу**, а не перебором значений (круг правки 2):
    // ключ памяти несёт рабочее место, чек и сумму ровно затем, чтобы
    // доказательство относилось к **этому** платежу. Перебор по одному
    // коду одобрения доказывал, что карта проводилась когда-то где-то:
    // проведение на 500 по чеку A на месте 7 оплачивало чек B на 2000 на
    // месте 8.
    //
    // Сумма в ключе — та, что ушла в эквайринг; здесь сверяется с
    // безналичной частью чека. Разошлись — отказ, и это правильно:
    // провели 1000, а в чек записали 800 значит 200 потерялись бы молча.
    final prefix = '$terminalId/${sale.receiptNo}/${plan.card}/';
    for (final entry in _cardCharges.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      // Обещание к этому моменту уже исполнено (завершение идёт после
      // проведения), так что ожидание здесь мгновенное; но ждать всё
      // равно надо — иначе доказательством считалось бы само наличие
      // записи, а не её исход.
      final charge = await entry.value;
      if (charge.isApproved &&
          charge.approvalCode != null &&
          charge.approvalCode == request.approvalCode) {
        return;
      }
    }

    _logger.warning(
      'Payment: unproven card approval receipt=${sale.receiptNo} '
      'terminal=$terminalId',
    );
    throw const WireRefusal(
      payChargeUnprovenCode,
      'карта не проводилась через платёжный терминал этой кассы',
    );
  }

  /// Забыть проведения оплаченного чека — иначе память растёт без предела.
  void _forgetCharges(int receiptNo) {
    _cardCharges.removeWhere(
      (key, _) => key.split('/').elementAtOrNull(1) == '$receiptNo',
    );
  }

  /// Номер этой кассы — или **названный отказ**, если её не настроили.
  ///
  /// Тот же перевод и на той же границе, что у `LocalCartService._posId`:
  /// политика «ноль не подставляется» общая для всех слоёв, а «отказ
  /// приходит значением» (I144) — правило провод-обращённого.
  Future<int> _posId() async {
    try {
      return await _db.thisPosDao.requireId();
    } on TillNotConfigured {
      throw const WireRefusal('till_not_configured', 'касса не настроена');
    }
  }
}

/// Раскладка денег одной оплаты — рабочая форма, наружу не уходит.
class _PaymentPlan {
  const _PaymentPlan({
    required this.payments,
    required this.change,
    required this.paid,
    required this.debt,
    required this.bonus,
    required this.cash,
    required this.card,
    required this.qrIntentId,
    required this.agentLocalId,
    required this.credit,
  });

  final List<PaymentEntry> payments;
  final Decimal change;
  final Decimal paid;
  final Decimal debt;
  final Decimal bonus;

  // # Поля `prepayment` здесь НЕТ — снято слиянием с задачей 21
  //
  // Оно везло зачтённый аванс отдельным числом, потому что конверт
  // оператора считал вёдра **по роду счёта**, а расчётный счёт
  // покупателя не отличим по роду от долга. Задача 21 сменила признак на
  // `PaymentKind.fiscalTreatment`, и вопрос отпал: у вида `prepayment`
  // трактовка `cash`, значит цикл конверта берёт строку сам. Оставить
  // поле значило бы держать второй ответ на вопрос, у которого уже есть
  // первый, — и он бы прибавился к первому (замер и разбор — у
  // `cash += plan.prepayment` в `_fiscalize`).
  //
  // [bonus] остаётся полем, и это не непоследовательность: его трактовка
  // `notAPayment`, цикл его не берёт **нарочно**, а конверту он нужен
  // третьим ведром. У аванса такого ведра нет.

  /// Наличная часть — посчитанная **кассой**, а не названная заявкой.
  ///
  /// Читают её двое, и пришли они с разных ветвей: проверка разрешённых
  /// видов оплаты (`_requireAllowedTypes`, задача 15) — смешанная оплата с
  /// запрещённой наличной половиной обязана отказать целиком; и денежный
  /// ящик (задача 16) — он открывается там, где в чеке есть наличные, по
  /// деньгам, а не по виду оплаты.
  ///
  /// **Имён при слиянии оказалось два, значение одно.** Задача 15 завела
  /// поле, задача 16 — производный геттер `paid - card - bonus`, и
  /// конфликта они не дали: разные места файла. Тождество проверено по
  /// коду — `paid = cash + card + bonus` (`_plan`), — так что геттер
  /// возвращал ровно это поле. Оставлено поле: оно прямое, а производное
  /// разошлось бы молча в тот день, когда `paid` сменит смысл. Задачи 22
  /// и 23 этот день и назначили — дважды и порознь:
  /// `paid = cash + card + bonus + qr + prepayment`. Геттер, доживи он до
  /// них, вернул бы наличными и зачтённый аванс, и оплату телефоном, и
  /// сделал бы это молча.
  final Decimal cash;

  /// Безналичная часть — её и обязана доказать касса (`_requireCardProof`).
  final Decimal card;

  /// Договор рассрочки, который родится вместе с чеком — задача 24.
  ///
  /// `null` у всех прочих видов оплаты.
  ///
  /// # Почему черновик едет доводом продажи, а не заводится рядом
  ///
  /// Потому что договор и чек обязаны появиться **одной транзакцией**.
  /// Завести его до продажи — и упавшая продажа оставляет покупателю долг
  /// за товар, которого он не получил. Завести после — и упавшее
  /// заведение оставляет чек, оплаченный рассрочкой без договора: товар
  /// отдан, обязательства нет, и чек при этом **сходится по строкам**,
  /// так что заметить это нечем.
  ///
  /// Тот же довод и то же место, что у гашения сертификата
  /// (`SaleUseCaseImpl.perform`).
  final CreditContractDraft? credit;

  /// Строка `payment_intents`, деньги которой ушли в этот чек — задача 22.
  ///
  /// Помечается разобранной **после** того, как чек записан, а не до, и
  /// направление здесь выбрано, а не досталось. Пометить до — и упавшая
  /// запись чека оставила бы намерение «в чеке», которого нет: деньги
  /// покупателя стали бы невидимыми. Пометить после — и обрыв между двумя
  /// шагами оставит намерение на экране разбора при уже готовом чеке:
  /// человек увидит лишнее, а не потеряет нужное.
  final int? qrIntentId;

  final int? agentLocalId;
}

/// Что у рабочего места с платёжным терминалом — задача 41; разбор в
/// `LocalPaymentService._terminalBinding`.
sealed class _TerminalBinding {
  const _TerminalBinding();
}

/// Терминал не привязан — законный ручной путь карты.
final class _NoTerminal extends _TerminalBinding {
  const _NoTerminal();
}

/// Привязан ровно один терминал с годными параметрами.
final class _BoundTerminal extends _TerminalBinding {
  const _BoundTerminal(this.config);

  final KaspiPosConfig config;
}

/// Привязка есть, но сломана — ошибка настройки, [reason] словами для журнала.
final class _BrokenBinding extends _TerminalBinding {
  const _BrokenBinding(this.reason);

  final String reason;
}
