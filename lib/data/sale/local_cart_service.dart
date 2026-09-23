import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/domain/tax/tax_resolution.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/database/watch_source.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/data/shift/shift_age_rule.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/deferred_claim_port.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/product_search_result.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
// Каталожный `ProductSearchResult` этого юзкейса — не тот, что отдаёт
// `CartService.search()` (см. докстринг `lib/domain/sale/
// product_search_result.dart`); префикс разводит два имени, а не прячет
// одно из них.
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart'
    as catalog;
import 'package:telepos/domain/usecases/sale/deferred_sale_service.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_round_option_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/data/catalog/local_selling_hours.dart';
import 'package:telepos/domain/catalog/selling_hours.dart';

/// Кассовая реализация [CartService] — задача 7, шаг 3 спеки.
///
/// # Откуда взялась логика
///
/// Целиком перенесена из `SaleNotifier` (`lib/presentation/controllers/sale/
/// sale_controller.dart:536-1018`): цены, акции, округления и правила
/// скидок те же, до знака. Изобретений здесь три, и они названы в брифе:
/// владелец (`terminalId` в каждом запросе), сверка [CartCommandMeta
/// .baseVersion] с `Sales.cartVersion` с отказом [cartStaleCode], и запись
/// `Sales.lastCommandKey` **в той же транзакции**, что и само изменение.
///
/// # Правда о корзине одна: база
///
/// Каждая команда пишет строку в `SaleProducts` немедленно, а не копит
/// корзину в памяти до откладывания. Три довода спеки (шаг 3): чек в
/// работе переживает перезапуск кассы (сегодня теряется); «отложить»
/// перестаёт быть вторым путём записи — пакетная вставка из
/// `deferSale()` уходит вместе с дублем; правды становится одна вместо
/// «память кассы плюс база при откладывании».
///
/// # Как корзина лежит в двух колонках цены — и почему именно так
///
/// У `SaleProducts` нет колонки скидки: есть `priceBefore` и `price`.
/// Договор этой реализации:
///
/// - **`priceBefore`** — цена единицы, какой её видит кассир (из
///   каталога или после `updatePrice`);
/// - **`price`** — цена единицы после **ручной** скидки строки;
/// - **ручная скидка строки** = `(priceBefore - price) * quantity`,
///   округлённая до S3 при чтении.
///
/// Деление скидки на единицу берётся с запасом по разрядам
/// ([_perUnitScale] = 10), а не с денежными тремя. Иначе скидка, не
/// делящаяся нацело на количество, возвращалась бы кассиру искажённой на
/// каждой команде: ввёл 10 при трёх штуках — `(300-10)/3 = 96.667`, обратно
/// `(100-96.667)*3 = 9.999`. С десятью разрядами обратный ход даёт
/// `9.9999999999`, и округление до S3 возвращает ровно 10.000.
///
/// **Акции в базе не хранятся — они считаются при сборке снимка.** У
/// `SaleItem` в контроллере был флаг `promoApplied`: он нужен был, чтобы
/// отличить подаренную акцией скидку от назначенной кассиром и снять
/// первую перед пересчётом. Колонки под такой флаг нет, и заводить её
/// (миграция v38 ради флага) не нужно: если в базе лежит **ручная**
/// скидка, то акционная — чистая функция от строк и таблицы `Promotions`,
/// и пересчитывается при каждой сборке снимка тем же самым
/// [_applyPromotions]. Это не смена правил, а выбор точки хранения: в
/// контроллере флаг существовал ровно потому, что тот хранил ручную и
/// акционную скидку слитыми в одно поле. Побочно закрывается дефект,
/// который иначе воспроизвёлся бы здесь: акция, снятая уменьшением
/// количества ниже порога, остаётся снятой, а не остаётся подарком
/// навсегда.
///
/// Акционную скидку в `price` впечатывает **завершение продажи**, и
/// задача 9 нашла, что делать это было некому: писал её
/// `SaleCheckoutService.finalize`, а его звал только
/// `SaleNotifier.completeSale`, у которого вызывающих ноль. То есть
/// подарок акции был виден кассиру в корзине и **исчезал из проданного
/// чека** — а для фискального оператора это был отказ кодом 9 на каждой
/// такой продаже, «деньги взяты, документа нет».
///
/// Теперь строки переписывает транзакция `SaleUseCase.perform` — тем же
/// оборотом, которым чек перестаёт быть корзиной. Точка хранения от этого
/// не изменилась: акции в базе по-прежнему не лежат, они по-прежнему
/// считаются при каждой сборке снимка, и всё сказанное выше остаётся в
/// силе.
class LocalCartService implements CartService {
  LocalCartService({
    required AppDatabase db,
    required Talker logger,
    required SaleInitiationUseCase initiation,
    required DeferredSaleService deferred,
    required SaleRoundOptionUseCase rounding,
    required FindByBarcodeUseCase findByBarcode,
    required catalog.SearchProductInfoUseCase searchProducts,
    DiscountPolicy? discountPolicy,
    // Занятие отложенного чека соседней кассы. `null` — обмена на этой
    // кассе нет, и подъём чужого чека отказывается: исключительность
    // негарантируема, а продать корзину дважды хуже, чем не поднять.
    // Свой отложенный чек поднимается без него, как и раньше.
    DeferredClaimPort? claim,
  }) : _db = db,
       _claim = claim,
       _logger = logger,
       _initiation = initiation,
       _deferred = deferred,
       _rounding = rounding,
       _findByBarcode = findByBarcode,
       _searchProducts = searchProducts,
       _shiftAge = ShiftAgeRule(db: db),
       // Пределы лежат в **той же базе**, что и корзина, и читаются тем же
       // соединением — это не поиск службы, а собственная таблица. Довод
       // оставлен подменяемым ради проб, но обязательным не сделан: тогда
       // это была бы церемония, а не защита. Защиту здесь несёт
       // `DiscountAuthority` — довод **команды**, забыть который не даёт
       // сборка.
       _policy = discountPolicy ?? LocalDiscountPolicy(db);

  final AppDatabase _db;
  final DeferredClaimPort? _claim;
  final DiscountPolicy _policy;
  final Talker _logger;
  final SaleInitiationUseCase _initiation;
  final DeferredSaleService _deferred;
  final SaleRoundOptionUseCase _rounding;
  final FindByBarcodeUseCase _findByBarcode;
  final catalog.SearchProductInfoUseCase _searchProducts;

  /// Потолок возраста смены — задача 27: то же правило, что у оплаты
  /// (`LocalPaymentService._requireShiftNotOverAge`), над той же базой.
  final ShiftAgeRule _shiftAge;

  /// Разряды, с которыми ручная скидка кладётся в цену единицы. Не
  /// денежные S3 намеренно — см. докстринг класса.
  static const _perUnitScale = 10;

  static const _stateDeferred = 3;

  static final _hundred = Decimal.fromInt(100);

  // ── подписки ──────────────────────────────────────────────────────────

  @override
  Stream<CartView> watch(int terminalId) => watchTables(_db, [
    _db.sales,
    _db.saleProducts,
    _db.saleProductMarks,
  ], () => currentView(terminalId));

  /// Право проверяется **при заведении подписки**, а не при каждом
  /// обновлении, и это не экономия: полномочия сеанса за время одной
  /// подписки не меняются (сменились — сеанс переподписывается заново), а
  /// проверка в теле потока отказывала бы посреди работы кассира, которому
  /// в первый раз разрешили.
  ///
  /// Отказ уходит **исключением подписчику**, а не пустым списком: пустой
  /// пул — законное состояние кассы, и подменять им запрет значит сказать
  /// кассиру «отложенных нет» там, где их просто не показывают. На проводе
  /// то же исключение становится кадром отказа (`TillWire._subscribe` ловит
  /// [WireRefusal] уже при вызове обработчика), на кассе — `AsyncError`,
  /// который диалог рисует названной причиной.
  @override
  Stream<List<DeferredCart>> watchDeferred({required DiscountAuthority by}) {
    _requireRight(by, PermissionKeys.opDeferSale, 'список отложенных');
    return watchTables(_db, [_db.sales, _db.saleProducts], _deferredCards);
  }

  /// Снимок корзины рабочего места сейчас — то же чтение, которым отвечает
  /// [watch] (правило `watchTables`: вопрос и подписка не имеют права
  /// читать по-разному).
  Future<CartView> currentView(int terminalId) async {
    final sale = await _myCart(terminalId);
    if (sale == null) return _emptyView(terminalId);
    return _viewOf(sale);
  }

  /// Снимок **названного** чека — тот же расчёт, что у [currentView], но
  /// без вопроса «чей он».
  ///
  /// Заведён задачей 8 для `LocalSaleCheckoutService`: сведение корзины в
  /// чек обязано брать цены строк ровно оттуда же, откуда их берёт экран,
  /// — иначе кассир видит один итог, а в базу уезжает другой. Не на
  /// контракте [CartService] намеренно: контракт отвечает на «что в работе
  /// у этого места», а завершение продажи спрашивает про конкретный чек по
  /// ключу, и такого вопроса у корзины нет.
  ///
  /// `null` — чека с таким ключом на кассе нет.
  Future<CartView?> viewOfReceipt(int receiptNo, int posId) async {
    final sale = await _db.saleDao.findByKey(receiptNo, posId);
    if (sale == null) return null;
    return _viewOf(sale);
  }

  /// Чек в работе этого места **на этой кассе**.
  ///
  /// Единственная точка, через которую эта реализация спрашивает «что у
  /// меня в работе»: круг правки 3 нашёл, что довода `posId` не хватало в
  /// самом запросе (`SaleDao.findInProgress` — там же разбор), и повторять
  /// пару доводов в шести местах значит завести шесть мест, где её можно
  /// собрать по-разному.
  Future<Sale?> _myCart(int terminalId) async =>
      _db.saleDao.findInProgress(posId: await _posId(), terminalId: terminalId);

  /// Снимок рабочего места без чека в работе: версия ноль — та самая, с
  /// которой сверяется `baseVersion` первой команды нового чека.
  Future<CartView> _emptyView(int terminalId) async => CartView(
    posId: await _posId(),
    terminalId: terminalId,
    version: 0,
    lines: const [],
    wholesale: false,
  );

  // ── команды ───────────────────────────────────────────────────────────

  /// Круг правки 2: `start` был **единственной** командой, оставшейся
  /// снаружи правки круга 1 — читал чек и сверял ключ вне транзакции, а
  /// версию не сверял вовсе. Цена измерена пробой разбора: два
  /// одновременных `start` с одним ключом заводили **два** чека, сжигали
  /// два номера и оставляли рабочему месту две продажи в работе — а
  /// какую из них продолжит кассир, не знал никто (`findInProgress` брал
  /// `limit(1)` без порядка; порядок задан там же тем же кругом).
  ///
  /// # Круг правки 3: два дефекта, и оба нашлись у одного оператора
  ///
  /// **Опт снимался молча.** Путь возобновления
  /// (`SaleInitiationUseCaseImpl.initiate` при уже начатом чеке) пишет
  /// `isWholesale` в существующую строку, а от этого флага зависит, какая
  /// цена берётся строкой. Проба разбора: опт был включён, `start
  /// (wholesale: false)` от законного снимка его выключил, **версия
  /// осталась прежней** — то есть сторож версии этого не видел по
  /// построению, и терминал не узнал бы, что деньги в его корзине
  /// изменились. Правка по существу, а не комментарием: на пути
  /// возобновления вниз не передаётся **ничего** — `initiate` там просто
  /// не зовётся. Смена режима опта это изменение корзины, у неё есть своя
  /// команда [setWholesale], и она идёт общим путём, с версией.
  ///
  /// Побочно уходит и второй такой же путь: тот же `initiate` при
  /// возобновлении переписывал типы округления из настроек кассы, а они
  /// тоже меняют цены строк — и тоже без версии. Названное изменение
  /// поведения: у чека, начатого до правки настроек округления, правила
  /// теперь остаются те, с которыми он начат.
  ///
  /// **Пустой номер в метке значит «не знаю», а не «у меня нет».** Круг
  /// правки 2 сделал опознание строгим для всех команд разом, и `start`
  /// стал отказывать там, где раньше работал: вторая вкладка того же
  /// терминала или вкладка, переподключившаяся до первого кадра подписки,
  /// зовёт `start` с холода — номера у неё нет — и получала отказ на самом
  /// естественном вызове. Выбран мягкий вариант: `meta.receiptNo == null`
  /// в `start` означает «я не знаю, что у меня», и касса отвечает тем, что
  /// есть; номер и версия сверяются строго, только если номер назван. Это
  /// безопасно **по построению** и только для `start`: после правки выше
  /// он корзину не меняет вовсе — ни одной колонки, кроме ключа повтора, —
  /// поэтому «слепой» вызов не может ничего испортить. Ни одна другая
  /// команда такой поблажки не имеет и иметь не может.
  @override
  Future<CartView> start({
    required int terminalId,
    required bool wholesale,
    required CartCommandMeta meta,
  }) => _db.transaction(() async {
    final existing = await _myCart(terminalId);
    if (existing != null && existing.lastCommandKey == meta.key) {
      return _viewOf(existing);
    }

    // Смена старше суток — чек не начинается и не возобновляется (задача
    // 27). Правило держал **клиент** (`SaleNotifier._ensureShiftNotOverAge`),
    // и в браузере, где `ShiftService` не привязан, оно молча пропускалось.
    // Касса проверяет сама, тем же правилом, что и оплата. Повтор уже
    // применённого `start` выше — не новое начало, отказывать ему не за что.
    await _shiftAge.require();

    // Названный номер — строгая сверка, как у прочих команд; пустой —
    // «не знаю, что у меня» (см. докстринг). Версия имеет смысл только
    // вместе с номером: без номера сверять её не с чем.
    if (meta.receiptNo != null) {
      _checkAddressedTo(existing, meta);
      final currentVersion = existing?.cartVersion ?? 0;
      if (currentVersion != meta.baseVersion) {
        throw _stale(currentVersion, meta);
      }
    }

    if (existing != null) {
      // Возобновление не пишет в чек **ничего**, включая ключ повтора.
      //
      // Круг правки 4: ключ раньше переписывался и здесь — и сжигал слот
      // повтора соседней вкладки. Проба: вкладка A применила команду и не
      // дождалась ответа; вкладка B позвала холодный `start`; честный
      // повтор A получил отказ вместо своего снимка. Слот на чек один
      // (см. предел в докстринге контракта), и механизм, заведённый ради
      // двух вкладок, сам же ломал правило повтора между ними.
      // Возобновлению ключ и не нужен: оно ничего не меняет, а значит
      // повторить его безвредно сколько угодно раз.
      return _viewOf(existing);
    }

    // Опт с первого кадра — **тот же оптовый прейскурант**, что включает
    // [setWholesale], и закрыт он той же настройкой кассы (ревизия
    // 2026-09-19). Найдено не чтением плана, а вопросом «чем ещё чек
    // становится оптовым»: `sale_controller._start` передаёт сюда
    // `state.mode == SaleMode.wholesale`, а режим переживает завершённый
    // чек — значит владелец, выключивший тумблер при открытом оптовом чеке,
    // получал следующий чек снова оптовым, мимо [setWholesale] и мимо её
    // проверки. Закрыть одну команду и оставить этот вход значило бы
    // покрасить набор и оставить дыру в продукте.
    //
    // Проверка стоит **после** ветки возобновления намеренно: возобновление
    // не пишет в чек ничего и [wholesale] не читает вовсе, а отказ на нём
    // запер бы уже начатый оптовый чек (тот же довод, что у `value == false`
    // в [setWholesale]).
    //
    // Права здесь не спрашивается, и это честно названный предел: у [start]
    // нет довода [DiscountAuthority] ни на одном фронте, а завести его —
    // правка каждого вызывающего и отдельная работа. На проводе вход закрыт
    // раньше и целиком (`TillOperations`: «чек начинается розничным; опт
    // включается sale.setWholesale»), так что незакрытой остаётся только
    // касса и только правом, не настройкой.
    if (wholesale) {
      await _requirePriceEditingEnabled(
        what: 'оптовый прейскурант закрыт вместе с правкой цены',
      );
    }

    // Начало чека — не «вставить строку», а решение с отказами: касса не
    // настроена, смена не открыта (задача 5). Отказ там приходит
    // значением, здесь становится броском: контракт возвращает снимок, а
    // не пару «снимок или причина», и на проводе бросок снова станет
    // значением (`till_wire.dart` ловит WireRefusal отдельно).
    final result = await _initiation.initiate(
      terminalId: terminalId,
      isWholesale: wholesale,
    );
    final sale = result.sale;
    if (sale == null) {
      throw result.refusal ??
          const WireRefusal(
            'sale_not_started',
            'чек не начат — причина не названа кассой',
          );
    }

    // `result.sale` — доменная сущность, версии корзины в ней нет; чек
    // перечитывается строкой базы, той же, из которой соберётся снимок.
    final started = await _myCart(terminalId);
    if (started == null || started.receiptNo != sale.receiptNo) {
      throw StateError(
        'LocalCartService.start: чек ${sale.receiptNo} начат, но чеком в '
        'работе места $terminalId не значится',
      );
    }
    return _writeStartKey(started, meta);
  });

  /// Запоминает ключ `start` и отдаёт снимок чека.
  ///
  /// Версия не растёт: после правки круга 3 `start` корзину не меняет
  /// вовсе — ни на начатом чеке (там он только помечается ключом), ни на
  /// новом (там версия и так рождается нулём). Обесценивать чужие команды
  /// в полёте ему не за что.
  Future<CartView> _writeStartKey(Sale sale, CartCommandMeta meta) async {
    // Условие на версию в самой записи — та же страховка, что в
    // [_writeVersion], и с той же оговоркой: на одном соединении ветка
    // `changed == 0` недостижима, прогоном не покрыта и покрыта быть не
    // может — она на случай, когда довод про одно соединение перестанет
    // быть верным.
    final changed =
        await (_db.update(_db.sales)..where(
              (s) =>
                  s.receiptNo.equals(sale.receiptNo) &
                  s.posId.equals(sale.posId) &
                  s.cartVersion.equals(sale.cartVersion),
            ))
            .write(SalesCompanion(lastCommandKey: Value(meta.key)));
    if (changed == 0) throw _staleOnWrite(sale.cartVersion, meta);

    return _viewOf(sale);
  }

  @override
  Future<List<ProductSearchResult>> search(String query) async {
    if (query.isEmpty) return const [];

    // Перенос `SaleNotifier.search` (`sale_controller.dart:536-591`) без
    // задержки ввода: 300 мс debounce — свойство экрана (кассир печатает),
    // а не кассы, и остаётся у экрана.
    final isNumeric = int.tryParse(query) != null;
    final effectiveQuery = isNumeric ? query : '%$query%';

    final found = await _searchProducts.search(
      query: effectiveQuery,
      limit: 50,
    );

    final results = <ProductSearchResult>[];
    for (final r in found) {
      final price = await _db.productPriceDao.findByUcode(r.ucode);
      final info = await _db.productInfoDao.findByUcode(r.ucode);
      results.add(
        ProductSearchResult(
          id: r.ucode,
          name: r.name,
          price: price?.sellingPrice ?? Decimal.zero,
          barcode: r.barcode.toString(),
          stock: info?.quantity,
          isDeleted: info?.isDeleted ?? r.isDeleted,
          measure: info?.measure ?? r.measure,
        ),
      );
    }
    return results;
  }

  @override
  Future<CartView> addByBarcode(
    int terminalId,
    String barcode,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    final found = await _findByBarcode.find(barcode.trim());
    if (found == null) {
      // В тексте едет **сам штрихкод и только он** — он и есть довод
      // словарной фразы (`error.product_not_found` → «Товар не найден:
      // {details}», `sale_refusal_keys.dart`, `withMessage: true`), тот же
      // уговор, что у `mark_required` и `insufficient_stock`, где текстом
      // едет имя товара.
      //
      // До приёмки 2026-09-17 здесь стояло целое предложение — «товар со
      // штрихкодом $barcode не найден», — и кассир читал его внутри
      // словарной фразы: «Товар не найден: товар со штрихкодом
      // 4870000000103 не найден». Фраза повторяла сама себя, а в казахском
      // интерфейсе вторая её половина оставалась русской.
      throw WireRefusal(cartProductNotFoundCode, barcode);
    }
    if (found.isDeleted) {
      // Тот же ход, что в контроллере: пробитый товар возвращается в
      // каталог, иначе следующая же продажа его снова не найдёт.
      await _db.productInfoDao.restoreProduct(found.ucode);
    }
    // Цена спрашивается ЗАНОВО, хотя `found.price` уже есть: поиск по
    // штрихкоду отдаёт `?? Decimal.zero` и тем стирает разницу между
    // «цена ноль» и «цены нет». Это путь СКАНЕРА, то есть самый частый:
    // товар без цены уходил покупателю даром именно здесь.
    final foundPrice = await _db.productPriceDao.findByUcode(found.ucode);
    if (foundPrice?.sellingPrice == null &&
        foundPrice?.wholesalePrice == null) {
      throw WireRefusal(cartProductHasNoPriceCode, found.name ?? barcode);
    }
    await _refuseIfBanned(found.categoryId, found.name ?? barcode);
    await _addOrMerge(
      sale,
      ucode: found.ucode,
      // `ProductWithPrice.price` — цена продажи, `minPrice` — оптовая
      // (`find_by_barcode_use_case_impl.dart`: `minPrice:
      // productPrice?.wholesalePrice`).
      sellingPrice: found.price,
      wholesalePrice: found.minPrice,
      barcode: found.barcode,
      quantity: Decimal.one,
      measure: found.measure,
    );
  });

  @override
  Future<CartView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    if (quantity <= Decimal.zero) {
      throw const WireRefusal(
        cartInvalidAmountCode,
        'количество должно быть больше нуля',
      );
    }
    final info = await _db.productInfoDao.findByUcode(productId);
    if (info == null) {
      // Тот же уговор, что строкой выше: текстом едет довод словарной
      // фразы — здесь код товара, потому что штрихкода на этом пути нет.
      throw WireRefusal(cartProductNotFoundCode, '$productId');
    }
    if (info.isDeleted) await _db.productInfoDao.restoreProduct(productId);
    final price = await _db.productPriceDao.findByUcode(productId);
    // Цены НЕТ — не то же, что цена ноль. Прежде оба случая сводились в
    // `?? Decimal.zero`, и товар без цены уходил покупателю даром.
    if (price?.sellingPrice == null) {
      throw WireRefusal(cartProductHasNoPriceCode, info.name ?? '$productId');
    }
    await _refuseIfBanned(info.categoryId, info.name ?? '$productId');
    await _addOrMerge(
      sale,
      ucode: productId,
      sellingPrice: price!.sellingPrice!,
      wholesalePrice: price.wholesalePrice,
      barcode: info.barcode,
      quantity: quantity,
      measure: info.measure,
    );
  });

  @override
  Future<CartView> setQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    final row = await _lineOrRefuse(sale, lineId);
    // Перенос `updateQuantity`: количество, упавшее до нуля, — это
    // удаление строки, а не строка с нулём.
    if (quantity <= Decimal.zero) {
      await _deleteLine(row.id);
      return;
    }
    await _writeQuantity(row, quantity);
  });

  @override
  Future<CartView> increment(
    int terminalId,
    String lineId,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    final row = await _lineOrRefuse(sale, lineId);
    await _writeQuantity(row, row.quantity + Decimal.one);
  });

  @override
  Future<CartView> decrement(
    int terminalId,
    String lineId,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    final row = await _lineOrRefuse(sale, lineId);
    final next = row.quantity - Decimal.one;
    if (next <= Decimal.zero) {
      await _deleteLine(row.id);
      return;
    }
    await _writeQuantity(row, next);
  });

  @override
  Future<CartView> setDiscountPercent(
    int terminalId,
    String lineId,
    Decimal percent,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) {
    final audit = <_DiscountAttempt>[];
    return _auditing(
      audit,
      () => _command(terminalId, meta, (sale) async {
        if (percent < Decimal.zero || percent > _hundred) {
          throw const WireRefusal(
            cartInvalidAmountCode,
            'скидка процентом бывает от нуля до ста',
          );
        }
        final row = await _lineOrRefuse(sale, lineId);
        // Тот же расчёт, что `setDiscountPercent` контроллера, включая
        // потолок: скидка не бывает больше строки.
        final discount = (row.priceBefore * row.quantity * percent / _hundred)
            .toDecimal();
        await _authorizeDiscount(
          by: by,
          percent: percent,
          stage: audit,
          sale: sale,
          saleProductId: row.id,
          amount: discount,
        );
        await _writeLine(
          row,
          quantity: row.quantity,
          base: row.priceBefore,
          discount: discount,
        );
      }),
    );
  }

  @override
  Future<CartView> setDiscountAmount(
    int terminalId,
    String lineId,
    Decimal amount,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) {
    final audit = <_DiscountAttempt>[];
    return _auditing(
      audit,
      () => _command(terminalId, meta, (sale) async {
        if (amount < Decimal.zero) {
          throw const WireRefusal(
            cartInvalidAmountCode,
            'скидка суммой не бывает отрицательной',
          );
        }
        final row = await _lineOrRefuse(sale, lineId);
        // Сумма меряется тем же пределом, что и процент, — через **долю
        // строки**. Иначе предел был бы театром: «20 % нельзя», а «скидка 500
        // из 500» можно.
        await _authorizeDiscount(
          by: by,
          percent: _shareOf(amount, row.priceBefore * row.quantity),
          stage: audit,
          sale: sale,
          saleProductId: row.id,
          amount: amount,
        );
        await _writeLine(
          row,
          quantity: row.quantity,
          base: row.priceBefore,
          discount: amount,
        );
      }),
    );
  }

  @override
  Future<CartView> updatePrice(
    int terminalId,
    String lineId,
    Decimal price,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) {
    final audit = <_DiscountAttempt>[];
    return _auditing(
      audit,
      () => _command(terminalId, meta, (sale) async {
        if (price < Decimal.zero) {
          throw const WireRefusal(
            cartInvalidAmountCode,
            'цена не бывает отрицательной',
          );
        }
        // Право — раньше строки и предела (задача 28): у кассира без права
        // код обязан быть про право, тем же порядком, что у скидки.
        _requireRight(by, PermissionKeys.opEditPrice, 'правку цены');
        // Настройка кассы — сразу за правом и **раньше строки**: она не
        // зависит ни от строки, ни от нового значения, и её отказ обязан
        // быть одним и тем же при любом `lineId`. См. разбор «право кассира
        // и настройка кассы — две разные величины» в докстринге
        // `CartService.updatePrice` и [_requirePriceEditingEnabled] ниже.
        await _requirePriceEditingEnabled();
        final row = await _lineOrRefuse(sale, lineId);
        await _authorizePriceDecrease(
          by: by,
          row: row,
          price: price,
          stage: audit,
          sale: sale,
        );
        // Скидка строки сохраняется суммой — тем же смыслом, что в
        // контроллере (`updatePrice` менял только `price`, `discount`
        // оставался прежним). Потолок применит `_writeLine`.
        await _writeLine(
          row,
          quantity: row.quantity,
          base: price,
          discount: _manualDiscount(row),
        );
        // Задача 8, находка 2 (вторая половина): «две строки одного товара с
        // одинаковой видимой ценой, и слить их нечем». Правка цены — тот самый
        // ход, которым кассир их и получает: развёл строки оптом или ручной
        // ценой (круг правки 5 задачи 7), потом вернул цену обратно — и в чеке
        // два одинаковых ряда, а команды «слить» в контракте нет и не будет:
        // слияние это не решение кассира, а свойство корзины. Здесь оно
        // доводится до конца там же, где строки сошлись.
        await _mergeTwinOf(sale, row.id);
      }),
    );
  }

  @override
  Future<CartView> setMark(
    int terminalId,
    String lineId,
    String mark,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    final row = await _lineOrRefuse(sale, lineId);
    await _db.saleProductDao.deleteMarksBySaleProduct(row.id);
    final trimmed = mark.trim();
    if (trimmed.isNotEmpty) {
      await _db.saleProductDao.insertMark(row.id, trimmed);
    }
  });

  @override
  Future<CartView> removeLine(
    int terminalId,
    String lineId,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    final row = await _lineOrRefuse(sale, lineId);
    await _deleteLine(row.id);
  });

  @override
  Future<CartView> clear(int terminalId, CartCommandMeta meta) =>
      _command(terminalId, meta, (sale) async {
        await _db.saleProductDao.deleteBySale(sale.receiptNo, sale.posId);
      });

  @override
  Future<CartView> defer(
    int terminalId,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) async {
    _requireRight(by, PermissionKeys.opDeferSale, 'отложенную продажу');
    // `null` из транзакции означает «чека в работе у места больше нет» —
    // и успешное откладывание, и его повтор дают один и тот же ответ.
    final result = await _db.transaction<CartView?>(() async {
      final sale = await _myCart(terminalId);

      if (sale == null) {
        // Чека в работе нет — либо повтор уже применённого откладывания
        // (тогда ключ лежит на отложенном чеке), либо команда без корзины.
        final byKey = await _db.saleDao.findByCommandKey(
          await _posId(),
          meta.key,
        );
        if (byKey != null && byKey.state == _stateDeferred) return null;
        throw const WireRefusal(
          cartNotStartedCode,
          'чек не начат — откладывать нечего',
        );
      }

      if (sale.lastCommandKey == meta.key) return _viewOf(sale);
      _checkAddressedTo(sale, meta);
      if (sale.cartVersion != meta.baseVersion) {
        throw _stale(sale.cartVersion, meta);
      }

      final lines = await _db.saleProductDao.countBySale(
        sale.receiptNo,
        sale.posId,
      );
      if (lines == 0) {
        throw const WireRefusal(cartEmptyCode, 'пустой чек не откладывается');
      }

      // Сумма уже поддержана каждой командой — здесь она только
      // перечитывается; пакетной вставки строк, как в `deferSale()`
      // контроллера, больше нет: строки лежат в базе с первой команды.
      final view = await _viewOf(sale);
      final changed = await _writeVersion(sale, meta, amount: view.total);
      if (changed == 0) throw _staleOnWrite(sale.cartVersion, meta);
      await _deferred.deferSale(receiptNo: sale.receiptNo);
      _logger.info(
        'Cart: deferred receipt=${sale.receiptNo} terminal=$terminalId',
      );
      return null;
    });

    return result ?? _emptyView(terminalId);
  }

  @override
  Future<CartView> loadDeferred(
    int terminalId,
    int receiptNo,
    CartCommandMeta meta, {
    required DiscountAuthority by,
    int? deferredPosId,
  }) => _db.transaction(() async {
    _requireRight(by, PermissionKeys.opDeferSale, 'отложенную продажу');
    final posId = await _posId();

    final mine = await _myCart(terminalId);
    if (mine != null && mine.lastCommandKey == meta.key) {
      // Повтор: чек уже поднят этим рабочим местом.
      return _viewOf(mine);
    }

    // Круг правки 1: версия сверяется и здесь. Раньше эта команда
    // единственная из всех не читала `baseVersion` вовсе — правило,
    // объявленное в докстринге контракта для **каждой** изменяющей
    // команды, держали не все, а «почти все». У рабочего места без чека в
    // работе текущая версия — ноль, ровно та, которую отдаёт [watch]
    // пустым снимком; сравнивать есть с чем и в этом случае.
    _checkAddressedTo(mine, meta);
    final currentVersion = mine?.cartVersion ?? 0;
    if (currentVersion != meta.baseVersion) throw _stale(currentVersion, meta);

    // Чек соседней кассы ищется по ЕЁ номеру, а не по нашему. Номера
    // выдаются сквозным `MAX(receipt_no)` по всей таблице, и чужие строки в
    // ней лежат штатно — но пока чек соседа к нам не доехал, обе кассы
    // могут выдать один номер. Поэтому пара `{receiptNo, posId}`, а не
    // номер в одиночку.
    final fromPosId = deferredPosId ?? posId;
    final target = await _db.saleDao.findByKey(receiptNo, fromPosId);
    if (target == null) {
      throw WireRefusal(
        cartDeferredNotFoundCode,
        fromPosId == posId
            ? 'отложенного чека $receiptNo на этой кассе нет'
            : 'отложенного чека $receiptNo кассы $fromPosId здесь нет',
      );
    }
    if (target.state != _stateDeferred) {
      throw WireRefusal(
        cartDeferredTakenCode,
        'чек $receiptNo уже поднят другим рабочим местом',
      );
    }
    // Продолжение опта — то же право, что его включение (круг правки 2
    // задачи 10). До задачи 28 это требование жило на проводе
    // (`TillOperations._requireRightToContinueWholesale`) и касалось только
    // браузера: касса поднимала оптовый чек кассиру без правки цены.
    if (target.isWholesale) {
      _requireRight(
        by,
        PermissionKeys.opEditPrice,
        'подъём оптового чека — продолжение опта то же право, что его '
        'включение',
      );
    }

    if (mine != null) {
      final lines = await _db.saleProductDao.countBySale(
        mine.receiptNo,
        mine.posId,
      );
      if (lines > 0) {
        // Освободить место — решение **этого** слоя, и оно названо
        // отказом. До задачи 17 то же самое молча делала `undeferSale`,
        // удаляя чек в работе: приём времён, когда рабочее место было
        // одно, а корзина жила в памяти. Теперь строки лежат в базе с
        // первой команды, и молчаливое удаление уносило бы настоящий
        // набранный чек.
        throw const WireRefusal(
          cartNotEmptyCode,
          'сначала отложите или завершите свой чек',
        );
      }
      await _db.saleProductDao.deleteBySale(mine.receiptNo, mine.posId);
      await _db.saleDao.deleteSale(mine.receiptNo, mine.posId);
    }

    // ── чек соседней кассы ───────────────────────────────────────────────
    //
    // Он не продолжается, а **переносится к нам**: поднять чужую строку
    // значило бы оставить чек кассой-владельцем, и выручка ушла бы не туда.
    // Деньги получает та касса, которая пробьёт (решение заказчика
    // 2026-09-19), значит и чек обязан стать её чеком — со своим номером.
    //
    // Порядок шагов не переставим: сначала занять на сервере, потом
    // трогать базу. Займёшь после — две кассы успеют поднять одну корзину
    // и продать её дважды.
    if (fromPosId != posId) {
      return _raiseForeign(
        terminalId: terminalId,
        target: target,
        meta: meta,
        ownPosId: posId,
      );
    }

    // Подъём — один ход и одно место: `undeferSale` условным обновлением
    // по `state = 3` меняет состояние и владельца. Задача 17 свела сюда
    // вторую правду о подъёме — своё такое же обновление стояло прямо
    // здесь, а `undeferSale` жила рядом со своей догадкой о владельце и
    // молчаливым удалением чека в работе. Симметрия с [defer], который
    // так же зовёт `deferSale`.
    //
    // **Честно о ветке `raised == null`: она не покрыта прогоном и
    // покрыта быть не может** — тем же доводом, что и условие версии в
    // [_writeVersion]. На единственном соединении кассы транзакции не
    // перемежаются, поэтому второй поднимающий видит `state != 3` уже
    // проверкой выше и до условного обновления не доходит (это измерено
    // пробой «одновременный подъём одного чека» в
    // `deferred_pool_test.dart`: отказ приходит из проверки, а не
    // отсюда). Ветка — страховка на случай, когда довод про одно
    // соединение перестанет быть верным, а не проверенное поведение.
    final raised = await _deferred.undeferSale(
      receiptNo: receiptNo,
      terminalId: terminalId,
    );
    if (raised == null) {
      throw WireRefusal(
        cartDeferredTakenCode,
        'чек $receiptNo уже поднят другим рабочим местом',
      );
    }

    // Версия и ключ повтора — дело контракта корзины, а не подъёма:
    // `undeferSale` про них не знает, как не знает и `deferSale`.
    await (_db.update(_db.sales)
          ..where((s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId)))
        .write(
          SalesCompanion(
            cartVersion: Value(target.cartVersion + 1),
            lastCommandKey: Value(meta.key),
          ),
        );

    _logger.info('Cart: undeferred receipt=$receiptNo terminal=$terminalId');
    final taken = await _db.saleDao.findByKey(receiptNo, posId);
    return _viewOf(taken!);
  });

  @override
  Future<CartView> setAgent(
    int terminalId,
    int? agentId,
    CartCommandMeta meta,
  ) => _command(terminalId, meta, (sale) async {
    // Агент лежит там же, куда его кладёт завершение продажи:
    // `SaleUseCaseImpl.perform` пишет `agentLocalId` в
    // `Sales.customerLocalId` (`sale_use_case_impl.dart:64`). Своей
    // колонки у агента нет, и заводить вторую правду о нём незачем.
    await (_db.update(_db.sales)..where(
          (s) =>
              s.receiptNo.equals(sale.receiptNo) & s.posId.equals(sale.posId),
        ))
        .write(SalesCompanion(customerLocalId: Value(agentId)));
  });

  @override
  Future<CartView> setWholesale(
    int terminalId,
    bool value,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) => _command(terminalId, meta, (sale) async {
    _requireRight(by, PermissionKeys.opEditPrice, 'опт');
    // Настройка кассы — тем же «и» и тем же порядком «кому → где → сколько»,
    // что у [updatePrice] (разбор в докстринге `CartService.updatePrice`).
    // **Только на включение**: разбор асимметрии — в докстринге
    // [_requirePriceEditingEnabled], раздел «Почему возврат в розницу не
    // закрыт».
    if (value) {
      await _requirePriceEditingEnabled(
        what: 'оптовый прейскурант закрыт вместе с правкой цены',
      );
    }
    await _db.saleDao.setIsWholesale(sale.receiptNo, sale.posId, value);
  });

  /// Право команды — **из довода**, отказ [cartForbiddenCode] — задача 28.
  ///
  /// Тот же приём, что у скидки ([_decideDiscount]): полномочия приходят
  /// обязательным доводом, и проверяет их корзина, куда сходятся оба фронта
  /// — провод (довод из сеанса) и экран кассы (довод из `AppState`). Сторож
  /// провода по-прежнему проверяет те же ключи раньше; это вторая защита, и
  /// единственная для экрана кассы, у которого провода нет.
  static void _requireRight(DiscountAuthority by, String key, String what) {
    if (by.permissions.contains(key)) return;
    throw WireRefusal(cartForbiddenCode, 'нет права на $what ($key)');
  }

  /// Настройка кассы «правка цены» (`ThisPosEntries.editPrice`) — отказ
  /// [cartDeniedPolicyCode], задача 9 ревизии 2026-09-19.
  ///
  /// # Почему это не дубль [_requireRight]
  ///
  /// Право и настройка — **разные величины с одинаковым именем**, и на этом
  /// сходстве дыра и держалась. Право отвечает «кому можно» и приходит
  /// доводом из сеанса; настройка отвечает «можно ли здесь вообще» и лежит в
  /// базе этой кассы. Кассир с правом на кассе с выключенной настройкой
  /// править цену не должен — значит одной проверки мало, нужны обе.
  /// Складываются они «и»: разбор в докстринге `CartService.updatePrice`.
  ///
  /// # Что было измерено
  ///
  /// Единственным читателем настройки был экран кассы
  /// (`sale_screen._showEditDialog`, `!policy.editPrice`). Обработчик провода
  /// `SaleOps.updatePrice` и эта реализация её не читали вовсе — с планшета
  /// цена правилась вопреки настройке, выставленной на кассе. Это ровно
  /// случай I162 «спрятанная кнопка правом не является»: проверка стояла там,
  /// где рисуется интерфейс, а не там, где исполняется операция.
  ///
  /// # Про ветку «строки настроек нет»
  ///
  /// Через [updatePrice] она **недостижима**, и это измерено, а не
  /// предположено: команда идёт внутри [_command], а тот спрашивает номер
  /// кассы ([_posId]) и отказывает `till_not_configured` раньше, чем дело
  /// доходит сюда (проба «касса не настроена — отказ приходит раньше
  /// политики», `cart_price_policy_test.dart`). Она написана не «на всякий
  /// случай», а затем, чтобы умолчание здесь совпадало с экранным —
  /// `LocalSaleEditTerms._policy` на пустой базе отдаёт `editPrice: true`.
  /// Два читателя одной настройки, отвечающие по-разному на одно состояние
  /// базы, отправили бы первый же разбор расхождения искать дефект не там.
  ///
  /// # Второй и третий читатели: опт ([setWholesale], [start]) — ревизия
  /// 2026-09-19
  ///
  /// До неё здесь было написано обратное: «оптовый прейскурант этой
  /// настройкой не закрыт». Это была не оговорка, а **названная открытой
  /// дверь**, и ревизия второго фронта её закрыла. Опт — это выбор другой
  /// цены для новых строк, то есть ровно «продать дешевле розничной», и
  /// касса, где владелец выключил правку цены, продолжала отдавать товар по
  /// оптовой: кассиру с правом `op.editPrice` (а оно у старших есть)
  /// достаточно было переключить режим чека. Настройка «Политика продаж»
  /// выглядела запретом на цену ниже розничной и им не была.
  ///
  /// Входов в опт на кассе **два**, и закрыты оба: команда [setWholesale] и
  /// `start(wholesale: true)`, которым экран продажи начинает чек, если
  /// режим остался оптовым с прошлого. Второй найден не планом, а вопросом
  /// «чем ещё чек становится оптовым»; закрой первый и оставь второй —
  /// набор позеленел бы, а деньги продолжали бы уходить.
  ///
  /// # Почему возврат в розницу НЕ закрыт
  ///
  /// [setWholesale] спрашивает настройку только при `value == true`, а
  /// [start] — только на **новом** чеке, не на возобновлении. Это решение, а
  /// не недосмотр. Розница — цена каталога, состояние по умолчанию;
  /// запретить возврат к ней значило бы **запереть** чек, ставший оптовым до
  /// того, как владелец щёлкнул тумблером, — кассир получал бы отказ на
  /// единственном действии, которым он мог бы беду исправить. Дыры в
  /// асимметрии нет по построению: с выключенной настройкой оптовым чек
  /// стать не может вовсе, значит и выключать в нём нечего, кроме случая
  /// «настройку сменили при открытом чеке».
  ///
  /// **Чего это НЕ доказывает.** Что цена строки не изменится другим путём:
  /// акции считаются при сборке снимка и через команду не проходят вовсе, а
  /// оптовая цена **уже набранных** строк этой правкой не трогается — опт
  /// действует на строки, добавленные после него (докстринг
  /// `CartService.setWholesale`), и чек, набранный оптом до выключения
  /// тумблера, доедет до оплаты по оптовым ценам. Так и задумано: деньги,
  /// названные покупателю, задним числом не меняются.
  ///
  /// Не доказывает и того, что опт закрыт **правом** на кассе целиком:
  /// [start] довода [DiscountAuthority] не принимает ни на одном фронте, и
  /// `op.editPrice` при начале чека не спрашивается. На проводе этого входа
  /// нет вовсе (`TillOperations` отказывает `sale.start` с оптом), на кассе
  /// он остаётся — названо намеренно, следующая ревизия начинает отсюда.
  Future<void> _requirePriceEditingEnabled({
    String what = 'правка цены строки выключена',
  }) async {
    final pos = await _db.thisPosDao.get();
    if (pos == null || pos.editPrice) return;
    throw WireRefusal(
      cartDeniedPolicyCode,
      'на этой кассе $what (Настройки → Политика продаж)',
    );
  }

  // ── общий ход изменяющей команды ──────────────────────────────────────

  /// Владелец, ключ повтора, версия, изменение и запись версии с ключом —
  /// один порядок для всех команд, чтобы забыть его в одной из
  /// восемнадцати было негде.
  ///
  /// # Круг правки 1: обе гарантии стояли снаружи транзакции и не работали
  ///
  /// Первая версия читала чек и сверяла ключ с версией **до** входа в
  /// транзакцию, полагаясь на то, что очередь транзакций drift разведёт
  /// команды. Она разводит только сами транзакции — чтение перед ними не
  /// защищено ничем, и разбор доказал это двумя пробами на
  /// одновременность (последовательные тесты не видели ни одной):
  ///
  /// - две одновременные `addByBarcode` с **одним** ключом: обе прочитали
  ///   ещё пустой `lastCommandKey`, обе применились — строка одна,
  ///   количество **два**, версии обеих `1`. То есть терминал, не
  ///   дождавшийся ответа и повторивший запрос, получал второй товар в
  ///   чеке — ровно то, ради чего ключ и заведён.
  /// - две **разные** команды от одной версии: обе прочитали
  ///   `cartVersion = 0`, обе применились, `cart_stale` не сработал, а в
  ///   базе осталось `cartVersion = 1` при двух изменениях — счётчик
  ///   разошёлся с правдой, и врали бы все последующие сверки.
  ///
  /// Правка двойная, и обе половины нужны:
  /// 1. **чтение и обе сверки — внутрь транзакции**: на единственном
  ///    соединении кассы этого достаточно, транзакции не перемежаются
  ///    (тот же довод, что у `ReceiptNumbers.withNext`);
  /// 2. **запись версии — условная**, `WHERE cart_version = <та, что
  ///    прочитали>` ([_writeVersion]), и ноль затронутых строк — отказ
  ///    `cart_stale` с откатом всей транзакции. Это то, что остаётся
  ///    верным, даже если довод про единственное соединение когда-нибудь
  ///    перестанет быть верным (второе соединение, другой драйвер): база
  ///    сама не даст применить изменение поверх уехавшей версии.
  Future<CartView> _command(
    int terminalId,
    CartCommandMeta meta,
    Future<void> Function(Sale sale) apply,
  ) => _db.transaction(() async {
    final sale = await _myCart(terminalId);
    if (sale == null) {
      throw const WireRefusal(
        cartNotStartedCode,
        'чек не начат на этом рабочем месте',
      );
    }

    // Ключ раньше версии — см. докстринг `CartService`: повтор приходит с
    // уже устаревшей версией, и обратный порядок отказывал бы каждому
    // честному повтору вместо того, чтобы его обслужить.
    if (sale.lastCommandKey == meta.key) return _viewOf(sale);
    _checkAddressedTo(sale, meta);
    if (sale.cartVersion != meta.baseVersion) {
      throw _stale(sale.cartVersion, meta);
    }

    await apply(sale);

    // Снимок собирается **один раз**: он же уходит вызывающему. Прежняя
    // версия строила его дважды — внутри транзакции ради суммы и заново
    // после неё ради ответа, — и замер разбора показал, что команда стоила
    // ровно двух снимков (16.7 мс против 7.1 мс). Половина цены даром при
    // бюджете 150 мс на круг с планшета.
    //
    // Строка чека перечитывается — это один запрос по первичному ключу, а
    // не второй снимок: дорого в снимке не оно, а строки корзины с их
    // товарами и марками. Перечитать обязательно: `setAgent` и
    // `setWholesale` меняют саму строку `Sales`, и снимок, собранный из
    // прочитанной до них копии, вернул бы прежнего агента — то есть
    // молча соврал бы, что команда не сработала (поймано тестом «агент и
    // опт живут в базе», а не рассуждением).
    final nextVersion = sale.cartVersion + 1;
    final fresh = await _db.saleDao.findByKey(sale.receiptNo, sale.posId);
    if (fresh == null) {
      // Круг правки 2: раньше здесь стояло `?? sale` — молчаливый откат
      // ровно к тому устаревшему чтению, ради которого правка круга 1 и
      // делалась. Ветка недостижима (строку читаем внутри своей же
      // транзакции сразу после записи в неё), и именно поэтому она
      // обязана быть громкой: тихая подстановка старого значения на
      // «невозможном» пути — это способ узнать о невозможном через год и
      // через испорченные данные.
      throw StateError(
        'LocalCartService: чек ${sale.receiptNo}/${sale.posId} исчез '
        'внутри собственной транзакции',
      );
    }
    final view = await _viewOf(fresh, version: nextVersion);

    // Сумма чека, версия и ключ — той же транзакцией, что и само
    // изменение: иначе авария между ними оставила бы применённое
    // изменение с прежним ключом, и повтор применил бы его второй раз.
    final changed = await _writeVersion(sale, meta, amount: view.total);
    if (changed == 0) throw _staleOnWrite(sale.cartVersion, meta);

    return view;
  });

  /// Условная запись версии, ключа и суммы: применяется, только если
  /// `cart_version` в базе всё ещё та, от которой посчитана команда.
  /// Ноль затронутых строк означает, что корзина уехала вперёд между
  /// чтением и записью, — вызывающий обязан отказать, а не сделать вид,
  /// что записал.
  ///
  /// **Честно о том, чем это доказано: ничем, и доказано быть не может.**
  /// Условие — вторая половина правки круга 1, страховка **на случай**,
  /// когда чтение внутри транзакции перестанет разводить команды: второе
  /// соединение к той же базе, другой драйвер, другая платформа. Пока
  /// соединение одно, транзакции не перемежаются, и до записи с уехавшей
  /// версией дойти неоткуда — ветка `changed == 0` не покрыта прогоном и
  /// покрыта быть не может тем же способом, каким проверено всё
  /// остальное. Она проверена только чтением, и следующий читатель не
  /// должен принимать её за подтверждённую прогоном защиту (тот же
  /// разбор и та же оговорка, что у ветки повтора в `ReceiptNumbers`).
  Future<int> _writeVersion(
    Sale sale,
    CartCommandMeta meta, {
    required Decimal amount,
  }) =>
      (_db.update(_db.sales)..where(
            (s) =>
                s.receiptNo.equals(sale.receiptNo) &
                s.posId.equals(sale.posId) &
                s.cartVersion.equals(sale.cartVersion),
          ))
          .write(
            SalesCompanion(
              amount: Value(amount),
              cartVersion: Value(sale.cartVersion + 1),
              lastCommandKey: Value(meta.key),
            ),
          );

  /// Команда адресована тому чеку, который у места сейчас в работе?
  ///
  /// [sale] — чек в работе (или `null`, если его нет). Сверяется с
  /// [CartCommandMeta.receiptNo]: `null` в команде значит «чека у меня не
  /// было», и совпадает только с отсутствием чека здесь.
  ///
  /// Круг правки 2, проба разбора: команда, посчитанная от чека №1 версии
  /// 0, задержалась в проводе; чек №1 отложили, начали чек №2 — версия у
  /// него тоже 0 — и запоздавшая команда легла в **чужой** чек, потому что
  /// версия совпала. Версия отвечает на «каким я его видел», а не на
  /// «какой это был», и вторая половина вопроса тут задаётся отдельно.
  void _checkAddressedTo(Sale? sale, CartCommandMeta meta) {
    if (meta.receiptNo == sale?.receiptNo) return;
    _logger.warning(
      'Cart: wrong receipt key=${meta.key} '
      'addressed=${meta.receiptNo} current=${sale?.receiptNo}',
    );
    throw const WireRefusal(
      cartWrongReceiptCode,
      'команда адресована другому чеку — обновите корзину',
    );
  }

  WireRefusal _stale(int currentVersion, CartCommandMeta meta) {
    _logger.warning(
      'Cart: stale command key=${meta.key} '
      'base=${meta.baseVersion} current=$currentVersion',
    );
    return const WireRefusal(
      cartStaleCode,
      'корзина уже изменилась — обновите её и повторите',
    );
  }

  /// Тот же отказ, но от **условной записи**, а не от сверки прочитанного.
  ///
  /// Отдельный построитель, потому что в этой ветке текущая версия
  /// **неизвестна**: запись отвергнута базой, а не сравнением, и второй
  /// раз строку никто не читал. [_stale] здесь писал бы в журнал
  /// `base=N current=N` — то самое число, ради расхождения с которым
  /// ветка и существует, и разбор живого случая по такой записи ничего
  /// бы не сказал. Круг правки 3: предел пишется правилом, а не от того
  /// случая, который его породил.
  WireRefusal _staleOnWrite(int readVersion, CartCommandMeta meta) {
    _logger.warning(
      'Cart: conditional write rejected key=${meta.key} '
      'base=${meta.baseVersion} read=$readVersion '
      '(текущая версия не читалась — её изменил кто-то между чтением и '
      'записью)',
    );
    return const WireRefusal(
      cartStaleCode,
      'корзина уже изменилась — обновите её и повторите',
    );
  }

  // ── строки ────────────────────────────────────────────────────────────

  Future<SaleProduct> _lineOrRefuse(Sale sale, String lineId) async {
    final id = int.tryParse(lineId);
    final rows = await _db.saleProductDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );
    for (final row in rows) {
      if (row.id == id) return row;
    }
    throw WireRefusal(cartLineNotFoundCode, 'строки $lineId в чеке нет');
  }

  // ── полномочия на уступку (задача 12) ─────────────────────────────────

  /// Одно место на четыре команды: право, политика кассы, предел,
  /// подтверждение.
  ///
  /// # Порядок отказов — от дешёвого к дорогому, и он проверяем
  ///
  /// 1. **нет права** → [cartForbiddenCode]. Дешевле всего и лечится не
  ///    здесь: право даёт администратор.
  /// 2. **тумблер кассы** → [cartDeniedPolicyCode]. Лечится в настройках
  ///    кассы.
  /// 3. **предел роли** → [cartDeniedLimitCode] с числом и источником в
  ///    тексте.
  /// 4. **порог подтверждения** → [cartApprovalRequiredCode].
  ///
  /// Порядок — не украшение: у кассира без права и со скидкой за пределом
  /// код обязан быть про право, иначе он пойдёт просить поднять предел, имея
  /// беду в другом месте. Проверяется пробой «нет права — отказ приходит
  /// раньше предела».
  ///
  /// **Существующий потолок «скидка не больше стоимости строки» остаётся
  /// последним и не заменяется** ([_writeLine]): он про арифметику, а не про
  /// право, и снять его значило бы разрешить строке уйти в минус тому, кому
  /// уступать разрешено без предела.
  Future<void> _authorizeDiscount({
    required DiscountAuthority by,
    required Decimal percent,
    required List<_DiscountAttempt> stage,
    Sale? sale,
    int? saleProductId,
    Decimal? amount,
  }) async {
    // Чей предел решил — узнаётся **внутри** решения и обязано пережить
    // отказ: именно у отказа этот вопрос и задают. Через держатель, а не
    // полем `WireRefusal`: тот тип едет по проводу, и дописывать в него
    // поле ради журнала кассы значило бы отправлять терминалу то, что его
    // не касается.
    final capHolder = <String>[];
    try {
      await _decideDiscount(by: by, percent: percent, capSource: capHolder);
    } on WireRefusal catch (refusal) {
      // **Попытка откладывается, а не пишется здесь.** Команда корзины идёт
      // внутри транзакции ([_command]), и отказ её откатывает — вместе с
      // любой записью, сделанной внутри. Первая редакция писала аудит
      // прямо тут, и три отказанные попытки давали **ноль** строк журнала:
      // аудит, откатывающийся вместе с тем, что он записывает, аудитом не
      // является. Измерено пробой, а не вычитано.
      //
      // Запись идёт в [_auditing], в `finally`, после того как транзакция
      // закончилась в любую сторону.
      stage.add(
        _DiscountAttempt(
          by: by,
          receiptNo: sale?.receiptNo,
          posId: sale?.posId,
          saleProductId: saleProductId,
          customerLocalId: sale?.customerLocalId,
          amount: amount ?? Decimal.zero,
          percent: percent,
          allowed: false,
          refusalCode: refusal.code,
          capSource: capHolder.isEmpty ? null : capHolder.first,
        ),
      );
      rethrow;
    }

    // Снятие скидки уступкой не является и в аудит не идёт: `percent <= 0`
    // — это возврат строки к своей цене. Писать его значило бы разбавить
    // журнал попыток событиями, где денег никому не отдавали, и первый же
    // проверяющий перестал бы его читать.
    if (percent <= Decimal.zero) return;

    stage.add(
      _DiscountAttempt(
        by: by,
        receiptNo: sale?.receiptNo,
        posId: sale?.posId,
        saleProductId: saleProductId,
        customerLocalId: sale?.customerLocalId,
        amount: amount ?? Decimal.zero,
        percent: percent,
        allowed: true,
        capSource: capHolder.isEmpty ? null : capHolder.first,
      ),
    );
  }

  /// Выполнить команду и **записать отложенные попытки скидки после неё** —
  /// в любую сторону, успехом или отказом.
  ///
  /// Список свой у каждого вызова, а не поле службы: `LocalCartService`
  /// один на кассу, и два одновременных терминала делили бы поле.
  Future<CartView> _auditing(
    List<_DiscountAttempt> staged,
    Future<CartView> Function() body,
  ) async {
    try {
      return await body();
    } finally {
      for (final a in staged) {
        await _db.saleDiscountDao.recordAttempt(
          userId: a.by.userId,
          roleIndex: a.by.roleIndex,
          receiptNo: a.receiptNo,
          posId: a.posId,
          saleProductId: a.saleProductId,
          customerLocalId: a.customerLocalId,
          amount: a.amount,
          percent: a.percent,
          allowed: a.allowed,
          refusalCode: a.refusalCode,
          capSource: a.capSource,
        );
      }
    }
  }

  /// Решение по уступке — без записи. Кладёт в [capSource] то, **чей предел
  /// решил**, теми же словами, которыми `DiscountCap.source` объясняет их
  /// кассиру.
  ///
  /// Отделено от [_authorizeDiscount] затем, чтобы аудит писался ровно на
  /// двух выходах — «прошло» и «отказ», — а не на каждом `throw` по
  /// отдельности. Пропущенный `throw` был бы дырой в журнале, которую
  /// нечем заметить: журнал молчит одинаково и когда события не было, и
  /// когда его забыли записать.
  Future<void> _decideDiscount({
    required DiscountAuthority by,
    required Decimal percent,
    required List<String> capSource,
  }) async {
    if (!by.permissions.contains(PermissionKeys.opSellDiscount)) {
      throw const WireRefusal(
        cartForbiddenCode,
        'нет права на скидку (op.sellDiscount)',
      );
    }

    // Ноль процентов — это снятие скидки, а не уступка. Мерить его пределом
    // значило бы запретить **убирать** скидку там, где предел ноль.
    if (percent <= Decimal.zero) return;

    final pos = await _db.thisPosDao.get();
    if (pos != null && !pos.sellInDiscount) {
      throw const WireRefusal(
        cartDeniedPolicyCode,
        'на этой кассе продажа со скидкой выключена '
        '(Настройки → Политика продаж)',
      );
    }

    final cap = await _policy.capFor(by.roleIndex);
    // Записывается **до** первого отказа, который на него ссылается.
    capSource.add(cap.source);
    if (percent > cap.maxPercent) {
      throw WireRefusal(
        cartDeniedLimitCode,
        'скидка ${_say(percent)} % больше разрешённых '
        '${_say(cap.maxPercent)} % (${cap.source})',
      );
    }

    final approvalAbove = cap.approvalAbove;
    if (approvalAbove != null && percent > approvalAbove) {
      throw WireRefusal(
        cartApprovalRequiredCode,
        'скидка выше ${_say(approvalAbove)} % требует подтверждения '
        'старшего (${cap.source})',
      );
    }
  }

  /// Понижение цены — та же уступка, только другим входом.
  ///
  /// # Заслонка на двух дверях
  ///
  /// `ThisPosEntries.isKassaPriceDecreasingBlocked` закрывает **эту** дверь
  /// и только её: включённый запрет снижения цены при пределе скидки в сто
  /// процентов скидку по-прежнему разрешает. Это записано пробой как факт —
  /// она краснеет, если кто-то свяжет две настройки молча, — и сказано
  /// словами на экране пределов, чтобы владелец не считал, что закрыл обе.
  ///
  /// # Отсчёт от каталожной цены, а не от цены строки
  ///
  /// Иначе предел режется ломтями: два понижения по 10 % от предыдущей цены
  /// — это 19 % от каталожной, и каждое по отдельности проходит. Каталожная
  /// берётся тем же выражением, каким её берёт [_addOrMerge] (оптовая, если
  /// чек оптовый и она задана ненулевой; иначе розничная), — второго
  /// источника цены не заводим.
  Future<void> _authorizePriceDecrease({
    required DiscountAuthority by,
    required SaleProduct row,
    required Decimal price,
    required List<_DiscountAttempt> stage,
    Sale? sale,
  }) async {
    final catalogue = await _cataloguePriceOf(row);
    if (catalogue == null || price >= catalogue) return;

    final pos = await _db.thisPosDao.get();
    if (pos != null && pos.isKassaPriceDecreasingBlocked) {
      throw WireRefusal(
        cartDeniedPolicyCode,
        'на этой кассе запрещено снижать цену ниже каталожной '
        '(${_say(catalogue)})',
      );
    }

    await _authorizeDiscount(
      by: by,
      stage: stage,
      sale: sale,
      saleProductId: row.id,
      // Деньгами — на строку целиком, а не на единицу: аудит меряет то,
      // что покупателю отдали, а отдали ему разницу, умноженную на
      // количество.
      amount: (catalogue - price) * row.quantity,
      percent: _shareOf(catalogue - price, catalogue),
    );
  }

  /// Каталожная цена товара строки — `null`, если её в базе нет вовсе.
  ///
  /// `null` означает «мерить не от чего», и тогда понижения не существует:
  /// отказать было бы честнее по букве, но остановило бы продажу товара, у
  /// которого просто нет строки цен, — а это обычное состояние каталога, а
  /// не попытка обойти предел.
  Future<Decimal?> _cataloguePriceOf(SaleProduct row) async {
    final price = await _db.productPriceDao.findByUcode(row.ucode);
    if (price == null) return null;
    final sale = await _db.saleDao.findByKey(row.receiptNo!, row.posId!);
    final wholesale = price.wholesalePrice;
    if ((sale?.isWholesale ?? false) &&
        wholesale != null &&
        wholesale > Decimal.zero) {
      return wholesale;
    }
    return price.sellingPrice;
  }

  /// Какую долю (в процентах) составляет [part] от [whole], **не больше ста**.
  ///
  /// Деньги через `double` здесь не проходят: [Decimal] делится точной
  /// дробью ([Rational]) и приводится к десятичной только на последнем шаге
  /// — с запасом разрядов, чтобы 1/3 не превратилась в «ровно предел».
  ///
  /// # Почему потолок в сто, а не «сколько получилось»
  ///
  /// Существующий арифметический потолок — «скидка не больше стоимости
  /// строки» ([_writeLine]) — остаётся **последним и не заменяется**: он про
  /// арифметику, а не про право. Без этой обрезки он оказался бы **первым**:
  /// «скидка 900 на строку в 500» — это 180 %, и при умолчании в сто
  /// процентов касса отвечала бы `denied_limit` вместо того, чтобы, как
  /// вчера, срезать скидку до стоимости строки. То есть миграция тихо
  /// ужесточила бы кассу ровно там, где обещала не ужесточать (I165), и
  /// нашлось это пробой «скидка больше строки не уводит чек в минус»,
  /// которая была зелёной до задачи 12 и покраснела на первом прогоне.
  ///
  /// С обрезкой порядок правильный: при пределе 100 % запрос на 180 %
  /// проходит и обрезается арифметикой; при пределе 20 % — отклоняется
  /// правилом. Оба потолка на месте, и каждый делает своё.
  static Decimal _shareOf(Decimal part, Decimal whole) {
    if (whole <= Decimal.zero) return Decimal.zero;
    final share = (part * _hundred / whole).toDecimal(
      scaleOnInfinitePrecision: _perUnitScale,
    );
    return share > _hundred ? _hundred : share;
  }

  /// Число для человека: без хвоста нулей у целого предела («20», не «20.0»).
  static String _say(Decimal value) => value == value.truncate()
      ? value.truncate().toString()
      : value.toString();

  /// Ручная скидка строки, восстановленная из двух колонок цены и
  /// округлённая до денежных S3 (см. докстринг класса).
  Decimal _manualDiscount(SaleProduct row) {
    final diff = (row.priceBefore - row.price) * row.quantity;
    if (diff <= Decimal.zero) return Decimal.zero;
    return DecimalUtil.roundMoney(diff);
  }

  /// Удаляет строку **вместе со всем, что на ней висит**.
  ///
  /// # Круг правки 1 задачи 8: марки было мало
  ///
  /// Здесь снималась только маркировка. На строке чека висят ещё два
  /// хвоста, и оба привязаны к её номеру, а не к товару:
  ///
  /// - `SaleProductModifiers.saleProductId` — модификаторы блюда
  ///   («без лука», «двойной сыр»), они же меняют цену
  ///   (`priceAdjustment`);
  /// - `GuestSplits.saleProductId` — доля гостя в позиции при разделении
  ///   счёта.
  ///
  /// Строка удаляется четырьмя путями (`setQuantity` в ноль, `decrement`
  /// до нуля, `removeLine`, слияние в [_mergeTwinOf]), и после каждого
  /// осиротевшая запись осталась бы указывать на номер, который база
  /// переиспользует под следующую строку: `SaleProducts.id` —
  /// `autoIncrement`, но `clear` + новый набор в том же чеке номера
  /// возвращает. Тогда чужой модификатор всплыл бы на чужом блюде — с
  /// чужой доплатой к цене.
  ///
  /// Половина этого унаследована от задачи 7 (три пути были и там), но
  /// четвёртый — слияние — заведён задачей 8, и заказ ресторана попадает
  /// в эту корзину именно теперь, через переписанный путь
  /// `loadFromRestaurantOrder`.
  Future<void> _deleteLine(int id) async {
    await _db.saleProductDao.deleteMarksBySaleProduct(id);
    await _db.modifierDao.deleteBySaleProductId(id);
    await _db.guestSplitDao.deleteBySaleProductId(id);
    await (_db.delete(_db.saleProducts)..where((sp) => sp.id.equals(id))).go();
  }

  /// Меняет **только количество**, не трогая цену единицы.
  ///
  /// # Круг правки 1 задачи 8, находка I2
  ///
  /// Прежде смена количества шла через [_writeLine] с *абсолютной* скидкой
  /// строки — и растягивала её на большее количество: скидка 10% с 500
  /// давала 450, а после «плюса» — 950, то есть 5%. Ручная **цена** смену
  /// количества переживала (она хранится поштучно), ручная **скидка** —
  /// нет. Ровно та асимметрия, ради снятия которой заведена находка 3, но
  /// на втором наборе путей.
  ///
  /// Цена единицы в базе уже несёт ручную скидку (`price = priceBefore -
  /// скидка/количество`, докстринг класса), поэтому «сохранить скидку
  /// поштучно» и «не трогать цену» — одно и то же действие. Деления здесь
  /// нет вовсе, значит и потерять на нём нечего.
  ///
  /// Потолок скидки [_writeLine] здесь не нужен: цена единицы не меняется,
  /// а она уже неотрицательна — строка не может уйти в минус от того, что
  /// её стало больше или меньше.
  Future<void> _writeQuantity(SaleProduct row, Decimal quantity) =>
      (_db.update(_db.saleProducts)..where((sp) => sp.id.equals(row.id))).write(
        SaleProductsCompanion(quantity: Value(quantity)),
      );

  /// Записывает строку так, чтобы [discount] читался обратно без потерь.
  ///
  /// Потолок скидки — стоимость строки: тот же, что у обоих способов
  /// назначить скидку в контроллере (`discountAmount > item.subtotal ?
  /// item.subtotal : discountAmount`). Здесь он общий для всех команд, а
  /// не повторён в каждой: `setQuantity`/`updatePrice` меняют стоимость
  /// строки, и без потолка прежняя скидка могла бы её пережить, уводя
  /// строку в минус.
  Future<void> _writeLine(
    SaleProduct row, {
    required Decimal quantity,
    required Decimal base,
    required Decimal discount,
  }) async {
    final subtotal = base * quantity;
    final capped = discount > subtotal ? subtotal : discount;
    // Ветка нулевого количества — страховка от деления на ноль, а не
    // рабочий путь: каждый вызывающий, у которого количество упало до
    // нуля, удаляет строку и сюда не приходит вовсе. Она не покрыта
    // прогоном, и это сказано прямо, а не спрятано: следующий читатель не
    // должен принять её за проверенное поведение.
    final perUnit = quantity > Decimal.zero
        ? (capped / quantity).toDecimal(scaleOnInfinitePrecision: _perUnitScale)
        : Decimal.zero;

    await (_db.update(
      _db.saleProducts,
    )..where((sp) => sp.id.equals(row.id))).write(
      SaleProductsCompanion(
        quantity: Value(quantity),
        priceBefore: Value(base),
        price: Value(base - perUnit),
      ),
    );
  }

  /// Добавление товара: тот же ход, что `addProduct` контроллера — товар,
  /// уже лежащий в корзине, увеличивает количество своей строки, а не
  /// заводит вторую.
  /// Цена строки выбирается признаком опта у **чека**:
  /// `isWholesale && wholesalePrice > 0 ? wholesalePrice : sellingPrice`.
  /// **Нулевая оптовая цена считается незаданной** — круг правки 1 задачи
  /// 10, довод в теле метода. Политика для кассира и её пределы — в
  /// докстринге `CartService.setWholesale`, там их прочтут авторы
  /// браузерной реализации.
  ///
  /// **Круг правки 4, пробел самой задачи 7.** Первая версия брала
  /// `found.price` и `price.sellingPrice` и признак опта не смотрела
  /// вовсе: чек, начатый оптовым, набирался по розничным ценам, а команда
  /// `setWholesale` меняла флаг, поднимала версию и **не делала ничего** —
  /// оптовая цена с браузерного терминала была недостижима. Пробел был
  /// невидим потому, что теста на две цены не было ни одного.
  ///
  /// **Круг правки 5: обоснование этого правила было ложным.** Здесь
  /// стояло «тем же выражением, что у пути, который кладёт строки
  /// сегодня — `SaleProductCreationUseCaseImpl.create`». Тот путь
  /// **мёртв**: регистрация в `service_locator` — его единственное
  /// упоминание во всём `lib/`, вызывающих ноль. Тогдашний путь кассы
  /// (`sale_controller.completeSale`, удалён задачей 9) опт не смотрел
  /// вовсе, а
  /// переключателя режима на кассе нет. Значит правило не перенесено, а
  /// **заведено здесь впервые**; выражение взято из мёртвого кода как из
  /// образца, а не как из работающего продукта. Функция нужная (опт в
  /// объёме работы по решению заказчика), обоснование было неверным — тот
  /// же класс, что чинился кругом 3 у докстринга `DeferredCart`.

  /// Отказать, если категория товара сейчас под запретом продажи.
  ///
  /// # Почему здесь, а не на экране
  ///
  /// Экранов продажи два — кассовый и браузерный, — и проверять запрет на
  /// каждом значило бы завести две записи одного правила. Здесь же он
  /// закрывает и путь сканера, и путь поиска, и провод.
  ///
  /// Механизм запрета в продукте БЫЛ (таблица `category_restrictions`, DAO,
  /// договор `IsCategoryBlockedUseCase`) — и его не звал НИКТО. Проверка
  /// была объявлена и не выполнялась ни разу, ни в одной стране.
  Future<void> _refuseIfBanned(int? categoryId, String productName) async {
    if (categoryId == null) return;
    final bans = await LocalSellingHours(_db).bansForCategory(categoryId);
    if (bans.isEmpty) return;
    final ban = activeBan(bans, DateTime.now());
    if (ban == null) return;
    // Довод отказа — имя товара И окно: кассир обязан узнать, до какого
    // часа ждать, иначе он будет пробовать снова каждую минуту.
    throw WireRefusal(cartSellingHoursBannedCode, '$productName|${ban.label}');
  }

  Future<void> _addOrMerge(
    Sale sale, {
    required int ucode,
    required Decimal sellingPrice,
    required Decimal? wholesalePrice,
    required int? barcode,
    required Decimal quantity,
    required int measure,
  }) async {
    // **Круг правки 1 задачи 10: ноль — это НЕ заданная оптовая цена.**
    // Задача 7 записала обратное пределом («опт применяется по признаку
    // "оптовая цена задана", а не "задана и осмысленна"») и оставила его
    // открытым ровно потому, что опт был тогда недостижим: на кассе
    // переключателя нет, а по проводу не было обработчика. Задача 10
    // обработчик написала — предел стал достижимым путём, и цена его
    // измерена до конца: строка с ценой 0 → подготовка чека отдаёт сумму 0
    // без отказа → фискальный провайдер пишет цену без единой проверки на
    // ноль (проверка есть только у скидки и наценки). Чек на ноль уезжает
    // в ОФД как обычный.
    //
    // И это не редкость данных: `ProductPrices.wholesalePrice` получает
    // ноль **штатным** импортом каталога при отсутствующей закупочной цене.
    // То есть без этой строки обычный магазин, включивший опт, раздавал бы
    // бесплатно весь товар, заведённый массовым импортом.
    //
    // Ноль трактуется ровно так же, как отсутствие: берётся розничная цена.
    // Отказом это быть не может — «у товара нет оптовой цены» не ошибка
    // команды, а обычное состояние каталога, и отказ остановил бы продажу
    // всего оптового чека из-за одной позиции.
    //
    // **Предел, записанный кругом правки 2 и не чинимый здесь:** сторожится
    // только ноль и ниже. Оптовая цена **выше** розничной применяется как
    // есть — опечатка каталога вверх (500 вместо 50) пройдёт и продаст
    // дороже розницы. Это тоже дефект каталога, но у него другая цена
    // (кассир увидит завышенную цену в чеке и остановится сам) и другое
    // место починки: проверка цен при импорте, которой в дереве нет вовсе.
    final wholesaleSet =
        wholesalePrice != null && wholesalePrice > Decimal.zero;
    final price = sale.isWholesale && wholesaleSet
        ? wholesalePrice
        : sellingPrice;
    final rows = await _db.saleProductDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );
    final target = await _mergeTarget(
      sale,
      rows: rows,
      ucode: ucode,
      price: price,
      measure: measure,
    );
    if (target != null) {
      await _writeLine(
        target,
        quantity: target.quantity + quantity,
        base: target.priceBefore,
        // Ручной скидки у цели слияния нет по правилу [_mergeTarget] —
        // ноль здесь не умолчание, а следствие условия отбора.
        discount: Decimal.zero,
      );
      return;
    }

    await _db
        .into(_db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(sale.receiptNo),
            posId: Value(sale.posId),
            ucode: ucode,
            barcode: Value(barcode),
            quantity: quantity,
            price: price,
            priceBefore: price,
          ),
        );
  }

  /// Строка, в которую новые единицы [ucode] по цене [price] ложатся
  /// **молча** — или `null`, если такой нет и нужна отдельная строка.
  ///
  /// Три условия, и каждое закрывает измеренный дефект.
  ///
  /// 1. **Та же видимая цена, а не тот же `priceBefore`** — задача 8,
  ///    находка 2. Круг правки 5 задачи 7 завёл разведение строк по цене и
  ///    сравнивал **неокруглённую** цену, а кассир видит округлённую
  ///    ([_roundedUnitPrice]). При включённом округлении весового товара
  ///    (`weightProductRoundType != 0`) две строки с ценами 100.4 и 100.6
  ///    показываются одинаково — «100» и «100», — не сливаются никогда, и
  ///    объяснить кассиру это нечем: ключ слияния в снимок не выведен и
  ///    выводить его туда незачем. Правильный ход обратный — сделать ключом
  ///    то, что человек видит.
  ///
  ///    Округление берётся с `hasDiscount: false` намеренно: ключ отвечает
  ///    на «сколько стоит **обычная** единица этого товара в этом чеке», а
  ///    акционный подарок приходит и уходит вместе с количеством
  ///    ([_applyPromotions] считается при каждой сборке снимка) — ключ,
  ///    зависящий от него, менялся бы под руками у кассира.
  ///
  /// 2. **Ручная скидка не разбавляется** — задача 8, находка 3. Скидка
  ///    строки хранится абсолютной суммой (докстринг класса), поэтому
  ///    добавление единиц в строку со скидкой растягивало ту же сумму на
  ///    больший товар: скидка 100 на одной штуке из 500 после второго
  ///    скана становилась скидкой 100 на двух штуках из 1000 — кассир
  ///    назвал одну цену, а чек посчитал другую. Ручная **цена** от этого
  ///    была защищена с круга правки 5, ручная **скидка** — нет; асимметрия
  ///    непреднамеренная, и здесь она снята: обе правки кассира одинаково
  ///    делают строку неприкосновенной, новые единицы ложатся своей.
  ///
  /// 3. **Маркированная строка не сливается.** Марка (Data Matrix)
  ///    принадлежит **экземпляру** товара, а не строке: слив две единицы в
  ///    одну строку с одной маркой, касса напечатала бы чек, в котором две
  ///    единицы маркируемого товара едут под одним кодом. `setMark`
  ///    хранит одну марку на строку (`deleteMarksBySaleProduct` перед
  ///    вставкой — докстринг DAO), значит развести их можно только
  ///    строками.
  Future<SaleProduct?> _mergeTarget(
    Sale sale, {
    required List<SaleProduct> rows,
    required int ucode,
    required Decimal price,
    required int measure,
    int? exceptId,
  }) async {
    final visible = _visibleUnitPrice(sale, price, measure);
    for (final row in rows) {
      if (row.ucode != ucode) continue;
      if (row.id == exceptId) continue;
      if (_manualDiscount(row) > Decimal.zero) continue;
      if (_visibleUnitPrice(sale, row.priceBefore, measure) != visible) {
        continue;
      }
      if (await _hasAttachments(row.id)) continue;
      return row;
    }
    return null;
  }

  /// Сливает строку [lineId] в **более раннюю** строку того же товара с той
  /// же видимой ценой, если такая нашлась.
  ///
  /// Зовётся из [updatePrice] — единственного места, где две уже
  /// существующие строки могут сойтись в одну. Выживает **ранняя** строка:
  /// она стоит в чеке выше, кассир смотрит на неё, и её номер не меняется
  /// от правки соседней.
  ///
  /// Марки и здесь разводят строки ([_mergeTarget], условие 3): слияние
  /// удаляет строку, а вместе с ней ушла бы и её марка.
  Future<void> _mergeTwinOf(Sale sale, int lineId) async {
    final rows = await _db.saleProductDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );
    SaleProduct? edited;
    for (final row in rows) {
      if (row.id == lineId) edited = row;
    }
    if (edited == null) return;
    if (_manualDiscount(edited) > Decimal.zero) return;
    if (await _hasAttachments(edited.id)) return;

    final info = await _db.productInfoDao.findByUcode(edited.ucode);
    final twin = await _mergeTarget(
      sale,
      rows: rows,
      ucode: edited.ucode,
      price: edited.priceBefore,
      measure: info?.measure ?? 0,
      exceptId: edited.id,
    );
    if (twin == null) return;

    // **Слияние идёт в обе стороны** (круг правки 1, находка I1). Здесь
    // стояло `if (twin.id > edited.id) return;` — то есть сливалось только
    // когда кассир правил цену **поздней** строки. Правка цены ранней
    // строки под позднюю оставляла две строки одного товара с одной
    // видимой ценой и без способа их свести — дословно то, что находка 2
    // называла «слить нечем», только с другой стороны.
    //
    // Выживает **ранняя** строка независимо от того, какую правили: она
    // стоит в чеке выше, кассир смотрит на неё, и её номер не должен
    // меняться от правки соседней. Цену выжившей берём у **правленой**:
    // это то число, которое кассир только что назвал.
    final survivor = twin.id < edited.id ? twin : edited;
    final victim = twin.id < edited.id ? edited : twin;

    await _writeLine(
      survivor,
      quantity: survivor.quantity + victim.quantity,
      base: edited.priceBefore,
      discount: Decimal.zero,
    );
    await _deleteLine(victim.id);
  }

  /// На строке висит что-то, привязанное к её номеру?
  ///
  /// Марка, модификаторы блюда, доля гостя — всё принадлежит **строке**, а
  /// не товару: слив две такие строки в одну, касса напечатала бы чек, где
  /// две единицы едут под одной маркой, с чужими модификаторами и с
  /// потерянным разделением счёта. Такие строки не сливаются вовсе — и это
  /// то же правило, по которому [_deleteLine] уносит хвосты с собой.
  Future<bool> _hasAttachments(int lineId) async {
    final marks = await _db.saleProductDao.findMarksBySaleProduct(lineId);
    if (marks.isNotEmpty) return true;
    final modifiers = await _db.modifierDao.getSelectedModifiers(lineId);
    if (modifiers.isNotEmpty) return true;
    final splits = await _db.guestSplitDao.findBySaleProductId(lineId);
    return splits.isNotEmpty;
  }

  /// Цена единицы, какой её увидит кассир у строки **без скидки**, — тем же
  /// [_shownPrice], что и снимок. Ключ слияния строк.
  Decimal _visibleUnitPrice(Sale sale, Decimal price, int measure) =>
      _shownPrice(
        price,
        measure: measure,
        hasDiscount: false,
        weightRound: sale.weightProductRoundType ?? 0,
        discountRound: sale.discountsRoundType ?? 0,
      );

  // ── снимок ────────────────────────────────────────────────────────────

  /// [version] — версия, с которой снимок уходит вызывающему. Довод нужен
  /// команде: она собирает снимок **после** своего изменения, но **до**
  /// того, как новая версия записана в строку `sale`, из которой снимок и
  /// строится. Без него пришлось бы перечитывать чек и собирать снимок
  /// второй раз — то, что круг правки 1 из этой команды и убрал.
  Future<CartView> _viewOf(Sale sale, {int? version}) async {
    final rows = await _db.saleProductDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );

    final weightRound = sale.weightProductRoundType ?? 0;
    final discountRound = sale.discountsRoundType ?? 0;

    final bases = <_LineBase>[];
    for (final row in rows) {
      final info = await _db.productInfoDao.findByUcode(row.ucode);
      final marks = await _db.saleProductDao.findMarksBySaleProduct(row.id);
      final manual = _manualDiscount(row);
      bases.add(
        _LineBase(
          id: row.id,
          ucode: row.ucode,
          name: info?.name ?? '#${row.ucode}',
          quantity: row.quantity,
          price: row.priceBefore,
          discount: manual,
          // Показанная цена считается **до** акций: правило округления
          // спрашивает «есть ли у строки скидка», и на этом шаге скидка
          // только ручная. Строке, получившей подарок, цена пересчитается
          // внутри [_applyPromotions] — там же, где подарок и назначается.
          shown: _shownPrice(
            row.priceBefore,
            measure: info?.measure ?? 0,
            hasDiscount: manual > Decimal.zero,
            weightRound: weightRound,
            discountRound: discountRound,
          ),
          measure: info?.measure ?? 0,
          barcode: row.barcode?.toString(),
          mark: marks.isEmpty ? null : marks.first.mark,
        ),
      );
    }

    await _applyPromotions(bases, weightRound, discountRound);

    // Налоговая настройка — один снимок на корзину.
    //
    // Один, а не по строке: правила, прочитанные в разные мгновения, могут
    // разойтись между строками одного чека, и итог перестанет объясняться
    // строками.
    //
    // Дата — сегодняшняя: корзина в работе пробивается сегодня. Чек,
    // перепечатанный задним числом, считает сборка чека, и своей датой.
    final taxConfig = await _db.taxSettingsDao.load();
    final taxOn = DateTime.now();
    final thisPos = await _db.thisPosDao.get();
    // Вывод по товару, а не по строке: один товар может лежать в корзине
    // двумя строками, и считать ему ставку дважды незачем.
    final resolvedTax = <int, ResolvedTax>{};
    if (taxConfig.isConfigured) {
      for (final b in bases) {
        if (resolvedTax.containsKey(b.ucode)) continue;
        final info = await _db.productInfoDao.findByUcode(b.ucode);
        resolvedTax[b.ucode] = taxConfig.resolve(
          categoryId: info?.taxCategoryId,
          on: taxOn,
        );
      }
    }

    final lines = bases
        .map(
          (b) => CartLine(
            id: b.id.toString(),
            productId: b.ucode,
            name: b.name,
            quantity: b.quantity,
            price: b.shown,
            discounts: b.discount <= Decimal.zero
                ? const <CartDiscount>[]
                : [
                    b.promotionId == null
                        ? CartDiscount.manual(b.discount)
                        : CartDiscount.promotion(
                            amount: b.discount,
                            promotionId: b.promotionId!,
                          ),
                  ],
            barcode: b.barcode,
            mark: b.mark,
            taxRatePercent: resolvedTax[b.ucode]?.totalRatePercent,
            isTaxExempt: resolvedTax[b.ucode]?.isExempt ?? false,
          ),
        )
        .toList();

    return CartView(
      posId: sale.posId,
      terminalId: sale.terminalId ?? 0,
      version: version ?? sale.cartVersion,
      lines: lines,
      wholesale: sale.isWholesale,
      receiptNo: sale.receiptNo,
      agentId: sale.customerLocalId,
      // Уклад — в снимок: корзина ездит по проводу, и браузерный терминал
      // обязан считать итог теми же правилами, не имея доступа к настройке.
      taxTreatment: TaxTreatment.values[thisPos?.taxTreatment ?? 0],
    );
  }

  /// Цена единицы, **какой её видит кассир**: округления чека применены.
  ///
  /// Перенос `SaleState.roundedUnitPrice` (`sale_controller.dart:171-182`),
  /// включая ранний выход: оба вида округления выключены — цена как есть,
  /// без похода в юзкейс.
  ///
  /// **Единственная формула показанной цены во всей реализации** (круг
  /// правки 1 задачи 8). До неё их было две: снимок округлял, а расчёт
  /// акций и ключ слияния брали сырую цену из базы — и подарок,
  /// посчитанный по сырой цене, не сходился со строкой, которую видит
  /// кассир. Замер разбора: цена 100, скидка 100.6, итог 199.4 вместо 200.
  Decimal _shownPrice(
    Decimal price, {
    required int measure,
    required bool hasDiscount,
    required int weightRound,
    required int discountRound,
  }) {
    if (weightRound == 0 && discountRound == 0) return price;
    return _rounding.roundPrice(
      price: price,
      isWeightProduct: measure != 0,
      hasDiscount: hasDiscount,
      weightProductRoundType: weightRound,
      discountsRoundType: discountRound,
    );
  }

  /// Акции чека: сколько подарочных единиц заработано и на какие строки они
  /// легли.
  ///
  /// Перенос `SaleNotifier._applyPromotions` (`sale_controller.dart:719-759`)
  /// — с той разницей, что снимать нечего (в [bases] лежит ручная скидка,
  /// акционная считается заново каждый раз, см. докстринг класса), и с
  /// **другим правилом раздачи**.
  ///
  /// # Задача 8, находка 1: подарок раздавался по порядку набора
  ///
  /// Контроллер, а за ним и первая версия этого метода, шли по строкам в
  /// порядке вставки и отдавали подарок первой подходящей. Пока товар лежал
  /// в чеке одной строкой, это было незаметно. С круга правки 5 задачи 7
  /// один товар лежит **несколькими** строками с разными ценами (опт,
  /// ручная цена) — и цена подарка стала зависеть от того, в каком порядке
  /// кассир нажимал кнопки: подарок ценой розничной строки и подарок ценой
  /// оптовой отличаются на разницу цен, а набор один и тот же. Замерено на
  /// наборе «одна единица розницей, две оптом»: тот же чек давал два разных
  /// итога.
  ///
  /// **Правило: подарок — самая дешёвая из подходящих единиц.** Строки
  /// сортируются по цене единицы (при равной — по номеру строки, чтобы
  /// порядок был полным), и подарочные единицы снимаются с головы. Это
  /// единственный порядок, который (а) не зависит от порядка набора вовсе,
  /// (б) не даёт кассиру и покупателю раздавать дорогой товар, меняя
  /// последовательность нажатий, и (в) совпадает с тем, как «N+1» понимают
  /// в рознице — бесплатной уходит наименее ценная единица.
  ///
  /// # Строка с ручной скидкой не участвует, и это правило, а не пропуск
  ///
  /// Скидка кассира и подарок акции не складываются: строка, которой уже
  /// назначили скидку руками, из раздачи исключена целиком — её единицы не
  /// считаются подходящими и подарка не получают. Заработанные подарочные
  /// единицы при этом **не пропадают в никуда**: они уходят следующей по
  /// цене подходящей строке — не «перепрыгивают» через соседа случайно, как
  /// было, а достаются ей по тому же правилу «самая дешёвая единица».
  /// Подходящих строк не осталось — подарок сгорает, потому что подарить
  /// его нечему.
  ///
  /// Условие срабатывания акции (`triggerQty` штук товара в чеке) при этом
  /// считается по **всем** строкам, включая скидочные: покупатель принёс
  /// нужное количество товара, и то, что кассир уступил ему на одной из
  /// строк, права на акцию не отменяет.
  Future<void> _applyPromotions(
    List<_LineBase> bases,
    int weightRound,
    int discountRound,
  ) async {
    if (bases.isEmpty) return;

    final List<Promotion> promotions;
    try {
      promotions = await _db.promotionDao.getEnabled();
    } catch (_) {
      // Тот же ход, что в контроллере: акции — не повод не продать.
      return;
    }
    if (promotions.isEmpty) return;

    final qtyByProduct = <int, Decimal>{};
    for (final b in bases) {
      qtyByProduct[b.ucode] =
          (qtyByProduct[b.ucode] ?? Decimal.zero) + b.quantity;
    }

    final freeUnits = <int, int>{};
    // Какая акция дала подарок этому товару. Первая сработавшая, а не
    // последняя: подарки одного товара от двух акций складываются в одно
    // число, и разделить их на источники нечем — числа `freeUnits` уже
    // сложены. Названо честно, а не спрятано: указать вторую значило бы
    // соврать про первую с той же вероятностью.
    final promoIdFor = <int, int>{};
    for (final promo in promotions) {
      final have = qtyByProduct[promo.triggerUcode] ?? Decimal.zero;
      final need = Decimal.fromInt(promo.triggerQty);
      if (promo.triggerQty <= 0 || have < need) continue;
      final times = (have.toBigInt() ~/ BigInt.from(promo.triggerQty)).toInt();
      if (times <= 0) continue;
      freeUnits[promo.rewardUcode] =
          (freeUnits[promo.rewardUcode] ?? 0) + times * promo.rewardQty;
      promoIdFor[promo.rewardUcode] ??= promo.id;
    }
    if (freeUnits.isEmpty) return;

    // Раздача по правилу, а не по порядку набора (см. докстринг).
    // `eligible` — только строки без ручной скидки; сортировка по
    // **показанной** цене, при равной — по номеру строки, чтобы порядок был
    // полным и от порядка вставки не зависел даже при совпадающих ценах.
    final eligible = bases.where((b) => b.discount <= Decimal.zero).toList()
      ..sort((a, b) {
        final byPrice = a.shown.compareTo(b.shown);
        return byPrice != 0 ? byPrice : a.id.compareTo(b.id);
      });

    for (final b in eligible) {
      final free = freeUnits[b.ucode] ?? 0;
      if (free <= 0) continue;
      final lineQty = b.quantity.toBigInt().toInt();
      final applied = free > lineQty ? lineQty : free;
      if (applied <= 0) continue;
      freeUnits[b.ucode] = free - applied;

      // **Подарок стоит ровно столько, сколько показано в строке** (круг
      // правки 1). Здесь стояло `b.price` — сырая цена из базы, — и при
      // включённом округлении подарок не сходился с тем, что видит кассир:
      // строка показывала 100, подарок снимал 100.6, чек не складывался
      // сам с собой. Тот самый дефект «цены не складываются в свой же
      // итог», который задача 8 убрала из контроллера, был переехавшим
      // сюда, а не снятым.
      //
      // Показанная цена одаряемой строки пересчитывается: у неё появилась
      // скидка, а от этого зависит правило округления. Пересчёт
      // устойчив — округление к целому и к пятёрке/десятке идемпотентно,
      // поэтому второго круга не требуется.
      b.shown = _shownPrice(
        b.price,
        measure: b.measure,
        hasDiscount: true,
        weightRound: weightRound,
        discountRound: discountRound,
      );
      final discount = b.shown * Decimal.fromInt(applied);
      final subtotal = b.shown * b.quantity;
      b.discount = discount > subtotal ? subtotal : discount;
      // Происхождение записывается **там же, где скидка назначается**
      // (задача 13). Вывести его потом нечем: к моменту, когда чек
      // продан, от подарка остаётся та же разность цен, что и от уступки
      // кассира.
      b.promotionId = promoIdFor[b.ucode];
    }
  }

  // ── отложенные ────────────────────────────────────────────────────────

  /// Поднять отложенный чек соседней кассы — заняв его и перенеся к себе.
  ///
  /// # Почему перенос, а не продолжение
  ///
  /// `undeferSale` меняет `state` у существующей строки и оставляет её
  /// чеком кассы-владельца. Для своего чека это верно, для чужого —
  /// денежная ошибка: чек, пробитый у нас, попал бы в смену, ящик и
  /// X/Z-отчёт соседа. Поэтому корзина переносится на **наш** номер, а
  /// чужая строка удаляется: она своё отслужила.
  ///
  /// # Занятие — первым, и без связи подъёма нет
  ///
  /// Исключительность даёт только сервер (`DeferredClaimPort`). Нет порта
  /// или нет связи — отказ: попросить покупателя вернуться к своей кассе
  /// дешевле, чем продать корзину дважды.
  Future<CartView> _raiseForeign({
    required int terminalId,
    required Sale target,
    required CartCommandMeta meta,
    required int ownPosId,
  }) async {
    final port = _claim;
    if (port == null) {
      throw const WireRefusal(
        cartDeferredTakenCode,
        'чек другой кассы поднять нечем: обмен не настроен',
      );
    }

    final winner = await port.claim(
      receiptNo: target.receiptNo,
      posId: target.posId,
      byPosId: ownPosId,
    );
    if (winner != null) {
      throw WireRefusal(
        cartDeferredTakenCode,
        winner == 0
            ? 'чек ${target.receiptNo} кассы ${target.posId} занять не вышло: '
                  'нет связи с обменом'
            : 'чек ${target.receiptNo} уже поднят кассой $winner',
      );
    }

    final lines = await _db.saleProductDao.findBySale(
      target.receiptNo,
      target.posId,
    );
    final started = await _initiation.initiate(
      terminalId: terminalId,
      isWholesale: target.isWholesale,
    );
    final fresh = started.sale;
    if (fresh == null) {
      throw started.refusal ??
          const WireRefusal(
            'sale_not_started',
            'чек не начат — причина не названа кассой',
          );
    }
    final receiptNo = fresh.receiptNo;

    for (final line in lines) {
      await _db
          .into(_db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              ucode: line.ucode,
              quantity: line.quantity,
              price: line.price,
              priceBefore: line.priceBefore,
              receiptNo: Value(receiptNo),
              posId: Value(ownPosId),
              barcode: Value(line.barcode),
              categoryId: Value(line.categoryId),
            ),
          );
    }

    // Чужая строка больше не нужна: её документ занят нами, и соседняя
    // касса уберёт её из своего пула следующим обменом.
    await _db.saleProductDao.deleteBySale(target.receiptNo, target.posId);
    await _db.saleDao.deleteSale(target.receiptNo, target.posId);

    await (_db.update(_db.sales)..where(
          (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(ownPosId),
        ))
        .write(
          SalesCompanion(
            amount: Value(target.amount),
            isWholesale: Value(target.isWholesale),
            lastCommandKey: Value(meta.key),
          ),
        );

    _logger.info(
      'Cart: поднят чек ${target.receiptNo} кассы ${target.posId} '
      'как $receiptNo terminal=$terminalId',
    );
    final taken = await _db.saleDao.findByKey(receiptNo, ownPosId);
    return _viewOf(taken!);
  }

  Future<List<DeferredCart>> _deferredCards() async {
    final posId = await _posId();
    final sales = await _db.saleDao.findByState(_stateDeferred);

    final cards = <DeferredCart>[];
    for (final sale in sales) {
      // Чеки соседних касс отсюда БОЛЬШЕ НЕ отсекаются — решение заказчика
      // 2026-09-19. Покупатель отложил корзину на первой кассе, вернулся, а
      // там очередь; он идёт ко второй, и она обязана эту корзину увидеть.
      //
      // Своё от чужого отличает `DeferredCart.posId`: он и так в карточке
      // был, просто до этой правки всегда совпадал со своей кассой.
      // Поднять чужой можно лишь заняв его на сервере — разбор в
      // `CouchDbDocumentMapper.claimedByPosId`; без связи подъём чужого
      // отказывается, чтобы корзина не продалась дважды.
      final rows = await _db.saleProductDao.findBySale(
        sale.receiptNo,
        sale.posId,
      );
      String? firstLineName;
      if (rows.isNotEmpty) {
        final info = await _db.productInfoDao.findByUcode(rows.first.ucode);
        firstLineName = info?.name;
      }
      final user = await _db.userDao.findById(sale.userId);
      cards.add(
        DeferredCart(
          receiptNo: sale.receiptNo,
          posId: sale.posId,
          total: sale.amount,
          lineCount: rows.length,
          userId: sale.userId,
          userName: user?.name,
          firstLineName: firstLineName,
          foreign: sale.posId != posId,
        ),
      );
    }

    // Номер чека растёт последовательно — сортировка по нему и есть
    // хронология (см. докстринг `DeferredCart`: своего времени у
    // незавершённого чека нет).
    cards.sort((a, b) => b.receiptNo.compareTo(a.receiptNo));
    return cards;
  }

  /// Номер этой кассы — или **названный отказ**, если её не настроили.
  ///
  /// Единая политика номера кассы (`ThisPosDao.requireId`, круг правки 4):
  /// ноль не подставляется — ноль это настоящий номер кассы, и запрос с
  /// ним не падает, а находит чужие строки.
  ///
  /// **Круг правки 5: перевод броска обратно в отказ значением.** Круг 4,
  /// заводя единую политику, сломал то, что аккуратно сделала задача 5:
  /// ненастроенная касса отвечала `till_not_configured` **значением**, и
  /// у экрана под этот код уже есть ключ. После круга 4 `start` первым
  /// делом звал номер кассы и бросал, не доходя до места, где отказ
  /// формулируется, — на провод уехала бы безымянная внутренняя ошибка
  /// (`safeErrorText` отдаёт для чужих исключений только имя типа), и
  /// терминал не смог бы сказать человеку, что именно не так.
  ///
  /// Перевод стоит здесь, на границе провода, а не в `requireId`:
  /// политика «ноль не подставляется» общая для всех, а «отказ приходит
  /// значением» (I144) — правило именно этого, провод-обращённого слоя.
  Future<int> _posId() async {
    try {
      return await _db.thisPosDao.requireId();
    } on TillNotConfigured {
      throw const WireRefusal('till_not_configured', 'касса не настроена');
    }
  }
}

/// Строка корзины до округления — рабочая форма сборки снимка.
///
/// [discount] изменяемо намеренно: [LocalCartService._applyPromotions]
/// дописывает в него акционную часть поверх ручной, как это делал
/// `_applyPromotions` контроллера через `copyWith`.
class _LineBase {
  _LineBase({
    required this.id,
    required this.ucode,
    required this.name,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.shown,
    required this.measure,
    required this.barcode,
    required this.mark,
  });

  final int id;
  final int ucode;
  final String name;
  final Decimal quantity;

  /// Цена единицы как она лежит в базе — до округлений чека.
  final Decimal price;

  Decimal discount;

  /// Какая акция дала скидку этой строке; `null` — скидка ручная либо её
  /// нет вовсе.
  ///
  /// Задача 13: разность `priceBefore − price` не помнит, откуда взялась,
  /// и подарок акции в проданном чеке был неотличим от уступки кассира.
  /// Ручная и акционная скидки на одной строке **не встречаются** —
  /// [LocalCartService._applyPromotions] раздаёт подарки только строкам без
  /// ручной скидки, — поэтому одного поля хватает, и оно честно: два
  /// источника на строке потребовали бы списка, а списка на этом шаге не
  /// из чего собрать.
  int? promotionId;

  /// Цена единицы **как её видит кассир** — после округлений
  /// ([LocalCartService._shownPrice]).
  ///
  /// Изменяемо намеренно: правило округления зависит от того, есть ли у
  /// строки скидка, а подарок акции скидку создаёт — значит показанная цена
  /// у одаряемой строки пересчитывается после раздачи
  /// ([LocalCartService._applyPromotions]).
  Decimal shown;

  final int measure;
  final String? barcode;
  final String? mark;
}

/// Отложенная попытка скидки — то, что напишет аудит **после** транзакции
/// команды.
///
/// Собирается внутри транзакции (там известны и чек, и строка, и предел), а
/// пишется снаружи: отказ откатывает транзакцию, и запись, сделанная
/// внутри, исчезла бы вместе с ним.
class _DiscountAttempt {
  const _DiscountAttempt({
    required this.by,
    required this.amount,
    required this.percent,
    required this.allowed,
    this.receiptNo,
    this.posId,
    this.saleProductId,
    this.customerLocalId,
    this.refusalCode,
    this.capSource,
  });

  final DiscountAuthority by;
  final int? receiptNo;
  final int? posId;
  final int? saleProductId;
  final int? customerLocalId;
  final Decimal amount;
  final Decimal percent;
  final bool allowed;
  final String? refusalCode;
  final String? capSource;
}
