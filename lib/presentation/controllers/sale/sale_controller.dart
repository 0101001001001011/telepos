import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/command_key.dart';
import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/sale/product_search_result.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';
import 'package:telepos/presentation/controllers/sale/sale_side_effects.dart';
import 'package:telepos/domain/shift/shift_status.dart';
import 'package:telepos/presentation/controllers/app/stock_revision.dart';

/// `ProductSearchResult` переехал в домен (`lib/domain/sale/
/// product_search_result.dart`, задача 7): его требует контракт
/// `CartService.search()`, а контракт — чистый Dart без Flutter, и
/// зависеть от презентационного слоя не может. Реэкспорт оставлен
/// намеренно: экраны и тесты знают это имя через контроллер
/// (`product_search.dart`, `quick_products_grid.dart`, `test/helpers/
/// mock_providers.dart` и другие), и переезд типа не повод править их все.
export 'package:telepos/domain/sale/product_search_result.dart'
    show ProductSearchResult;

const kShiftOverAgeError = 'error.shift_over_age';

const kShiftOverAgeMessage = 'смена открыта более 24ч — закройте смену';

enum SaleMode { retail, wholesale }

/// Строка чека, какой её показывает экран.
///
/// # Задача 8: это отображение снимка, а не хранилище
///
/// До задачи 8 `SaleItem` был **правдой** о корзине: контроллер держал
/// список в памяти, менял его сам и записывал в базу только при
/// откладывании и завершении. Теперь правда одна — база за контрактом
/// `CartService` (задача 7), а [SaleItem] строится из [CartLine] и
/// живёт до следующего снимка.
///
/// Отсюда — то, чего в нём больше нет и почему:
///
/// - **`discountPercent`, `promoApplied`** — оба существовали затем, чтобы
///   контроллер отличал скидку кассира от подарка акции внутри одного
///   поля. В базе они лежат раздельно (`priceBefore`/`price` — ручная
///   скидка; акционная считается при сборке снимка), и различать их
///   экрану больше нечем и незачем.
/// - **`measure`, `isWeightProduct`** — нужны были округлению цены, а
///   округление уехало в снимок ([price] приходит уже округлённой). Экран,
///   округлявший цену сам, был второй правдой о деньгах: таблица чека
///   показывала цену **без** округления, а итог считался **с** ним.
@immutable
class SaleItem {
  SaleItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    Decimal? discount,
    this.barcode,
    this.mark,
  }) : discount = discount ?? Decimal.zero;

  /// Строка [CartLine], собранная в форму экрана.
  factory SaleItem.fromLine(CartLine line) => SaleItem(
    id: line.id,
    productId: line.productId,
    name: line.name,
    price: line.price,
    quantity: line.quantity,
    discount: line.discount,
    barcode: line.barcode,
    mark: line.mark,
  );

  final String id;

  final int productId;

  final String name;

  /// Цена единицы, **уже округлённая** правилами чека.
  final Decimal price;

  final Decimal quantity;

  /// Скидка на строку целиком — ручная плюс акционная, как их посчитала
  /// касса.
  final Decimal discount;

  final String? barcode;

  final String? mark;

  Decimal get subtotal => price * quantity;

  Decimal get total => subtotal - discount;
}

/// Состояние экрана продажи.
///
/// # Что здесь живёт после задачи 8
///
/// Экранное — и только: **выбранная строка**, **строка поиска и её
/// результаты**, **предупреждение о сроке годности**, **ошибка**. Плюс
/// [agentName] — имя агента, которого касса в снимке не отдаёт (в чеке
/// лежит только идентификатор).
///
/// Всё остальное — [receiptNo], [posId], [version], [items], [mode],
/// [agentId] и все суммы — приходит снимком корзины [CartView] и
/// пересобирается целиком при каждом её изменении. Ни одно из этих полей
/// экран не меняет сам: изменение корзины — команда контракта, ответ на
/// неё — новый снимок.
@immutable
class SaleState {
  const SaleState({
    this.receiptNo,
    this.posId,
    this.version = 0,
    this.items = const [],
    this.selectedItemId,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
    this.mode = SaleMode.retail,
    this.agentId,
    this.agentName,
    this.error,
    this.warning,
    this.taxOnTop,
  });

  /// Снимок корзины в форме экрана.
  ///
  /// [agentName] и экранные поля не приходят из корзины и берутся из
  /// [previous]: смена снимка не имеет права стирать то, что человек
  /// печатает или видит.
  ///
  /// [keepError] — про **третьего снимателя отказа**, найденного кругом
  /// правки 2. Отказ снимают двое законных: `_emitError` перед повтором
  /// того же ключа и удавшаяся команда (`_applyView`, умолчание здесь —
  /// команда прошла, прежней причине больше не место). Третьим был
  /// **колбэк подписки на корзину**, и он не команда вовсе: чужая запись в
  /// `sales` — сервисным сбором ресторана, второй вкладкой, браузерным
  /// терминалом — снимала отказ с экрана асинхронно, без единого действия
  /// кассира. Проба на настоящей базе показывала `Expected:
  /// 'error.line_not_found', Actual: <null>`.
  ///
  /// Поэтому подписка зовёт это с `keepError: true`: она спрашивает «что в
  /// чеке», а не «применилась ли моя команда», и права гасить чужую
  /// причину у неё нет.
  factory SaleState.fromCart(
    CartView view, {
    required SaleState previous,
    bool keepError = false,
  }) {
    final items = view.lines.map(SaleItem.fromLine).toList();
    final selected = previous.selectedItemId;
    return SaleState(
      receiptNo: view.receiptNo,
      posId: view.posId,
      version: view.version,
      items: items,
      // Выбранная строка могла исчезнуть — её удалили, слили с соседней
      // (`CartService.updatePrice`) или чек сменился целиком. Держать
      // выбор на несуществующей строке значит показывать кассиру
      // включённые кнопки «количество» и «скидка», которые молча ничего
      // не делают.
      selectedItemId: items.any((i) => i.id == selected) ? selected : null,
      searchQuery: previous.searchQuery,
      searchResults: previous.searchResults,
      isSearching: previous.isSearching,
      mode: view.wholesale ? SaleMode.wholesale : SaleMode.retail,
      agentId: view.agentId,
      // Агента сняли — имя вместе с ним.
      agentName: view.agentId == null ? null : previous.agentName,
      warning: previous.warning,
      error: keepError ? previous.error : null,
      // Налог сверх цены — из снимка, а не пересчитанный здесь.
      //
      // Пересчитать значило бы завести второй расчёт денег рядом с
      // кассовым: на дубле урока 1.3 экран оплаты показал сдачу 2,21
      // доллара, а касса выдала 1,62 — экран считал итог без налога.
      taxOnTop: view.taxOnTop,
    );
  }

  final int? receiptNo;

  final int? posId;

  /// Версия снимка корзины: с ней уходит каждая команда
  /// ([CartCommandMeta.baseVersion]).
  final int version;

  final List<SaleItem> items;

  final String? selectedItemId;

  final String searchQuery;

  final List<ProductSearchResult> searchResults;

  final bool isSearching;

  final SaleMode mode;

  final int? agentId;

  final String? agentName;

  final String? error;

  final String? warning;

  int get itemCount => items.length;

  Decimal get totalQuantity =>
      items.fold(Decimal.zero, (sum, item) => sum + item.quantity);

  Decimal get subtotal =>
      items.fold(Decimal.zero, (sum, item) => sum + item.subtotal);

  Decimal get totalDiscount =>
      items.fold(Decimal.zero, (sum, item) => sum + item.discount);

  /// Итог чека. Считается из тех же цен, что показывает таблица строк —
  /// округление применено кассой один раз, при сборке снимка.
  /// Сумма позиций без налога сверху.
  Decimal get netTotal =>
      items.fold(Decimal.zero, (sum, item) => sum + item.total);

  /// Налог сверх цены — снимком из корзины. `null` при налоге в цене.
  ///
  /// Обнуляемое, а не ноль умолчанием: конструктор `const`, а
  /// `Decimal.zero` константой времени компиляции не является.
  final Decimal? taxOnTop;

  /// Налог сверх цены числом.
  Decimal get taxAdded => taxOnTop ?? Decimal.zero;

  /// Сколько платит покупатель — то же число, что возьмёт касса.
  Decimal get total => netTotal + taxAdded;

  SaleItem? get selectedItem {
    if (selectedItemId == null) return null;
    for (final item in items) {
      if (item.id == selectedItemId) return item;
    }
    return null;
  }

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  bool get hasError => error != null;

  SaleState copyWith({
    String? selectedItemId,
    bool clearSelectedItemId = false,
    String? searchQuery,
    List<ProductSearchResult>? searchResults,
    bool? isSearching,
    String? agentName,
    bool clearAgentName = false,
    String? error,
    bool clearError = false,
    String? warning,
    bool clearWarning = false,
  }) {
    return SaleState(
      receiptNo: receiptNo,
      posId: posId,
      version: version,
      items: items,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      mode: mode,
      agentId: agentId,
      agentName: clearAgentName ? null : (agentName ?? this.agentName),
      error: clearError ? null : (error ?? this.error),
      warning: clearWarning ? null : (warning ?? this.warning),
      // Налог переносится, как и остальные суммы снимка. [copyWith] здесь
      // меняет ТОЛЬКО экранное — выбор, поиск, отказ; потерять на нём
      // деньги значило бы показать кассиру другой итог после нажатия, не
      // изменившего чек.
      taxOnTop: taxOnTop,
    );
  }
}

/// Экран продажи — задача 8 плана «Продажа с браузерного терминала».
///
/// # Что здесь осталось и что ушло
///
/// Ушла **вся корзина**: цены, слияние строк, скидки, акции, округления,
/// откладывание и подъём отложенного живут за контрактом
/// [CartService] (задача 7) и одинаковы для кассы и браузера. Осталось
/// состояние экрана — выбранная строка, режим ввода (поиск), текст
/// предупреждения — и перевод отказов кассы в ключи для человека.
///
/// # Одна точка порождения команды
///
/// [_meta] — единственное место, где собирается [CartCommandMeta]. Ключ
/// повтора, версия снимка и номер чека берутся здесь и нигде больше:
/// восемнадцать команд, каждая со своим сбором метки, — это восемнадцать
/// мест, где можно забыть половину.
///
/// **Ключ уникален по кассе, а не по рабочему месту** (предел, названный
/// задачей 7): `Sales.lastCommandKey` ищется по номеру кассы, потому что у
/// отложенного чека владельца нет. Поэтому ключ несёт случайную метку
/// сеанса экрана, а не только счётчик — два экрана, начавшие счёт с
/// единицы, иначе выдали бы один и тот же ключ.
///
/// # Правило I161: одна команда в полёте
///
/// Команды выполняются по одной ([_inFlight]): вторая, посланная до
/// ответа на первую, считалась бы от той же версии снимка и получила бы
/// `cart_stale` — то есть кассир, нажавший «+» дважды подряд, увидел бы
/// отказ вместо двух единиц. Очередь здесь и есть соблюдение I161 со
/// стороны экрана.
class SaleNotifier extends Notifier<SaleState> {
  Timer? _searchDebounce;
  StreamSubscription<CartView>? _cartSubscription;

  int? _terminalId;

  /// Метка сеанса экрана — вторая половина ключа повтора (см. докстринг).
  final String _session = newCommandSessionTag();

  int _commandSeq = 0;

  /// Хвост очереди команд: следующая ждёт предыдущую (I161).
  Future<void> _inFlight = Future<void>.value();

  /// Экран закрыт, а команда ещё в полёте.
  ///
  /// Все команды теперь асинхронны — до задачи 8 половина из них меняла
  /// состояние прямо в обработчике нажатия. Значит между отправкой и
  /// ответом кассы экран может быть закрыт (кассир ушёл на оплату,
  /// вкладку выгрузили), и запись в `state` после этого — не гонка, а
  /// обычный ход событий, на котором Riverpod бросает «Ref … after it has
  /// been disposed». Ответ на закрытом экране просто выбрасывается: его
  /// некому показать, а корзина от этого не страдает — она в базе.
  bool _disposed = false;

  CartService get _cart => GetIt.I<CartService>();

  @override
  SaleState build() {
    ref.onDispose(() {
      _disposed = true;
      _searchDebounce?.cancel();
      _cartSubscription?.cancel();
    });
    // Задача 36: остаток написан в каждой строке выдачи поиска, и после
    // продажи (своей или инвентаризации) выдача обязана показать новый.
    ref.listen(stockRevisionProvider, (_, _) {
      unawaited(_refreshSearchAfterStockChange());
    });
    Future.microtask(_initSale);
    return const SaleState();
  }

  /// Остатки изменились — выдача перечитывается, если на экране есть запрос.
  ///
  /// Без дебаунса: это не набор текста, а один факт. Ответ, пришедший, когда
  /// кассир уже сменил запрос, не ложится поверх нового.
  Future<void> _refreshSearchAfterStockChange() async {
    final query = state.searchQuery;
    if (query.isEmpty || _disposed) return;
    try {
      final results = await _cart.search(query);
      if (_disposed || state.searchQuery != query) return;
      _emit(state.copyWith(searchResults: results));
    } catch (e) {
      talker.warning('Sale: search refresh after stock change: $e');
    }
  }

  // ── метка команды ─────────────────────────────────────────────────────

  CartCommandMeta _meta() => CartCommandMeta(
    key: '$_session:${_commandSeq++}',
    baseVersion: state.version,
    receiptNo: state.receiptNo,
  );

  /// Метка «я не знаю, что у меня в работе» — только для [CartService.start].
  ///
  /// # Задача 23: почему вход на экран обязан быть холодным
  ///
  /// `_initSale` — это «я открыл экран, скажи, что у меня в работе», а не
  /// «применить команду к чеку номер N». Пока метка входа несла
  /// `state.receiptNo`, вход после успешной оплаты **отказывал**: экран
  /// сбрасывается в пустое состояние, но между сбросом и построением метки
  /// есть асинхронные разрывы, и подписка на корзину успевала вернуть в
  /// состояние номер только что проведённого чека. `start` сверял названный
  /// номер строго (`_checkAddressedTo`), чека в работе уже не было — и
  /// приходил `cart_wrong_receipt`.
  ///
  /// Дефект жил не замеченным потому, что показывать отказы экран не умел
  /// вовсе: первый вход после оплаты молча проваливался, а чек начинал
  /// следующий вызов. Найден он ровно в тот день, когда отказ начали
  /// показывать, — и первым его увидел не человек, а два сквозных теста
  /// продажи, у которых полоса отказа съела «Оплата успешна».
  ///
  /// Холодная метка безопасна **по построению, и это сказано контрактом**:
  /// `meta.receiptNo == null` в `start` означает «я не знаю, что у меня», а
  /// сам `start` корзину не меняет ни одной колонкой (докстринг
  /// `CartService.start`). Поблажка есть только у него; всякая другая
  /// команда идёт с [_meta] и сверяется строго.
  CartCommandMeta _coldMeta() => CartCommandMeta(
    key: '$_session:${_commandSeq++}',
    baseVersion: 0,
    receiptNo: null,
  );

  // ── чек ───────────────────────────────────────────────────────────────

  /// Рабочее место, от имени которого идут команды.
  ///
  /// Читается **через домен**: `TerminalIdentity` — то, что этот клиент
  /// запомнил о себе (кассу туда кладёт вход, `login_controller
  /// ._resolveTerminalId`), а `TerminalRepository.self()` — терминал самой
  /// кассы, если запомнить ещё не успели. Прежний код брал `terminalDao
  /// .self()` прямо из базы и потому не мог быть общим с браузером: у
  /// браузерного терминала своё имя, и `self()` кассы — чужая для него
  /// строка.
  /// Рабочее место этого экрана — для соседних контроллеров.
  ///
  /// Заведён задачей 14: экран оплаты обязан назвать кассе то же рабочее
  /// место, что и корзина, а не резолвить его вторым, своим способом.
  /// Второй способ рано или поздно разошёлся бы с первым, и разошёлся бы
  /// молча — оплата ушла бы в чужой чек.
  Future<int?> currentTerminalId() => _resolveTerminalId();

  Future<int?> _resolveTerminalId() async {
    final known = _terminalId;
    if (known != null) return known;
    try {
      final remembered = await GetIt.I<TerminalIdentity>().currentId();
      if (remembered != null) return _terminalId = remembered;
      final self = await GetIt.I<TerminalRepository>().self();
      return _terminalId = self.id;
    } catch (e) {
      talker.warning('Sale: terminal id unresolved: $e');
      return null;
    }
  }

  /// Начать или возобновить чек.
  ///
  /// **Возраст смены экран не проверяет — задача 27.** Здесь стояла
  /// `_ensureShiftNotOverAge`: `GetIt.I<ShiftService>()` в `try`, а `catch`
  /// возвращал `true`. В браузере `ShiftService` не привязан, и продажа шла в
  /// смене любого возраста. Теперь отказывает касса (`LocalCartService.start`,
  /// код `shift_over_age`), и он приходит сюда тем же путём, что любой отказ
  /// корзины: `_enqueue` → `error.shift_over_age` → диалог экрана.
  Future<void> _initSale() async {
    final terminalId = await _resolveTerminalId();
    if (terminalId == null) {
      _emitError('error.till_not_configured_sale');
      return;
    }

    _listenToCart(terminalId);

    await _enqueue(() async {
      if (_disposed) return;
      final view = await _cart.start(
        terminalId: terminalId,
        wholesale: state.mode == SaleMode.wholesale,
        meta: _coldMeta(),
      );
      _applyView(view);
      ref.read(appStateProvider.notifier).setShift(ShiftStatus.open);
      refreshShiftAfterSaleStart(ref);
    });
  }

  /// Подписка на корзину: чек, начатый или изменённый где угодно, доезжает
  /// до экрана сам.
  ///
  /// До задачи 8 экран узнавал о корзине только от собственных действий —
  /// он же ею и был. Теперь корзина в базе, и у неё бывают другие
  /// изменяющие: сервисный сбор ресторана (`CalculateServiceChargeUseCase
  /// .applyToSale`), вторая вкладка того же терминала, а с задачи 12 —
  /// браузер.
  void _listenToCart(int terminalId) {
    _cartSubscription?.cancel();
    _cartSubscription = _cart
        .watch(terminalId)
        .listen(
          (view) {
            if (_disposed) return;
            // Снимок подписки может прийти **позже** ответа команды и
            // быть старше него (`watchTables` перечитывает по изменению
            // таблицы, а не по версии корзины). Откат версии назад
            // показал бы кассиру строку, которую он уже удалил.
            if (view.receiptNo == state.receiptNo &&
                view.version < state.version) {
              return;
            }
            // `keepError: true`: подписка — не команда, гасить причину, о
            // которой она не спрашивала, права у неё нет (докстринг
            // `SaleState.fromCart`).
            _emit(SaleState.fromCart(view, previous: state, keepError: true));
          },
          onError: (Object e) {
            talker.warning('Sale: cart watch error: $e');
          },
        );
  }

  /// Единственная запись состояния: после закрытия экрана — молча мимо.
  void _emit(SaleState next) {
    if (_disposed) return;
    state = next;
  }

  /// Отказ в состояние — так, чтобы **тот же самый второй раз подряд тоже
  /// был изменением**.
  ///
  /// # Задача 23: почему просто `copyWith(error: ...)` мало
  ///
  /// Экран показывает отказ по изменению `SaleState.error` (`ref.listen`
  /// в `sale_screen.dart`). Одинаковое значение изменением не считается —
  /// кассир, дважды нажавший ту же кнопку и дважды получивший тот же
  /// отказ, во второй раз не увидел бы ничего вовсе.
  ///
  /// Ноль и значение пишутся **в одном синхронном шаге**, а не «снимем в
  /// начале следующей команды»: тот порядок был написан и измерен —
  /// он открывает окно, в котором `SaleState.error` уже пуст, а новый
  /// отказ ещё не пришёл, и читатель из другого места видит `null`. Так и
  /// случилось: `sale_controller_refusal_test` увидел пустоту вместо
  /// причины, потому что второе (незавершённое) начало чека успело снять
  /// ошибку первого. Слушатели Riverpod срабатывают синхронно, поэтому
  /// промежуточный ноль видит экран — и не видит никакой асинхронный
  /// читатель вроде `PaymentNotifier.processPayment`.
  void _emitError(String key) {
    // Сторож `_disposed` стоит **до** чтения `state`, а не только внутри
    // `_emit`: у закрытого `Notifier` бросается сам геттер, и отказ команды,
    // догнавшей закрытие экрана, ронял бы тест чужой ошибкой Riverpod.
    if (_disposed) return;
    if (state.error == key) _emit(state.copyWith(clearError: true));
    _emit(state.copyWith(error: key));
  }

  void _applyView(CartView view) {
    _emit(SaleState.fromCart(view, previous: state));
  }

  /// Одна команда в полёте (I161) плюс перевод отказа в ключ для человека.
  ///
  /// Возвращает «прошла ли команда»: отказ здесь — значение, а не бросок
  /// наружу (I144), и вызывающему нужно уметь на него не наступить —
  /// например, не начинать следующий чек, если откладывание не состоялось.
  Future<bool> _enqueue(Future<void> Function() body) {
    final next = _inFlight.then((_) async {
      if (_disposed) return false;
      try {
        await body();
        return true;
      } on WireRefusal catch (refusal) {
        _emitError(_errorKeyOf(refusal));
        return false;
      } catch (e, stack) {
        talker.error('Sale: command failed: $e', e, stack);
        _emitError('error.save_failed:${safeErrorText(e)}');
        return false;
      }
    });
    // Очередь ждёт завершения, но не наследует его исхода.
    _inFlight = next.then((_) {});
    return next;
  }

  /// Отказ кассы → ключ, который умеет показать `ErrorLocalizer`.
  ///
  /// Карта переехала в `sale_refusal_keys.dart` и стала публичной — не ради
  /// красоты, а ради сторожа: приватный `switch` внутри контроллера
  /// проверить извне нечем, и именно поэтому семь кодов корзины из десяти
  /// прожили до задачи 23 без перевода.
  String _errorKeyOf(WireRefusal refusal) => saleRefusalErrorKeyOf(refusal);

  /// Команда корзины: рабочее место, метка, ответ снимком.
  Future<bool> _command(
    Future<CartView> Function(int terminalId, CartCommandMeta meta) run,
  ) => _enqueue(() async {
    final terminalId = await _resolveTerminalId();
    if (terminalId == null) {
      throw const WireRefusal('till_not_configured', 'касса не настроена');
    }
    if (_disposed) return;
    _applyView(await run(terminalId, _meta()));
  });

  Future<void> startNewSale() async {
    _searchDebounce?.cancel();
    _emit(const SaleState());
    await _initSale();
  }

  // ── поиск ─────────────────────────────────────────────────────────────

  /// Поиск товара. Задержка ввода — свойство экрана (кассир печатает), и
  /// осталась здесь; сам поиск ушёл в контракт.
  Future<void> search(String query) async {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _emit(
        state.copyWith(searchQuery: '', searchResults: [], isSearching: false),
      );
      return;
    }

    _emit(state.copyWith(searchQuery: query, isSearching: true));

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _cart.search(query);
        if (_disposed) return;
        // Запрос успел смениться, пока касса искала, — ответ на прежний
        // выбрасывается. Тот же довод и тот же приём, что у обновления
        // выдачи после движения остатка (`_refreshSearch` выше): выдача
        // принадлежит **текущему** запросу, а не тому, который её вызвал.
        //
        // Без этой строки опоздавший ответ открывал выдачу поверх уже
        // очищенного поля — ровно тот дефект, который ловит
        // `sale_search_dropdown_test.dart`, только со стороны кассы, а не
        // со стороны таймера.
        if (state.searchQuery != query) return;
        _emit(state.copyWith(searchResults: results, isSearching: false));
      } catch (e) {
        _emit(
          state.copyWith(
            isSearching: false,
            error: 'error.search_failed:${safeErrorText(e)}',
          ),
        );
      }
    });
  }

  // ── строки ────────────────────────────────────────────────────────────

  /// Скан: товар в чек, строка поиска — вон.
  ///
  /// # Почему очистка здесь, а не у поля ввода
  ///
  /// Поле поиска умело чиститься само (`product_search.dart`, `onSubmitted`:
  /// «нашёлся — `_controller.clear()`»), но **при сканировании этот путь не
  /// исполняется никогда**: `BarcodeScannerMixin._onHardwareKey` съедает
  /// `Enter` (возвращает `true`), и `onSubmitted` у поля не срабатывает
  /// вовсе. Цифры при этом миксин **не** съедает — они уходят и в чек, и в
  /// поле.
  ///
  /// Живой прогон 2026-09-07 (координатор, браузерный терминал): после двух
  /// сканов в поле стояло `48700012345674870007654321`, после десяти строка
  /// уходила за правый край. Товар распознавался верно — но кассир видел
  /// мусор, а ручной поиск после скана был сломан: следующий набор дописался
  /// бы к накопленному.
  ///
  /// Поэтому чистит **источник правды**, а не виджет: `addProduct` рядом
  /// делает ровно то же (`searchQuery: '', searchResults: []`), и после этой
  /// правки оба пути добавления заканчиваются одинаково. Поле следует за
  /// состоянием — `ProductSearch` слушает `searchQuery` и чистит свой
  /// контроллер, когда тот опустел.
  ///
  /// Только при успехе: ненайденный штрихкод оставляет набранное на месте,
  /// иначе кассир не увидит, что именно не нашлось.
  ///
  /// # Отложенный поиск гасится здесь же — приёмка 2026-09-17
  ///
  /// Чистки состояния было мало. Кассир набирает штрихкод руками и жмёт
  /// `Enter` раньше, чем истекут 300 мс задержки [search]: выдача ещё
  /// пуста, `onSubmitted` уходит этой дорогой (`product_search.dart`), товар
  /// встаёт в чек — а **взведённый таймер никто не снял**. Через 300 мс он
  /// срабатывает, касса отвечает списком из одного товара, и выдача
  /// открывается **поверх уже очищенного поля**, ловя следующее нажатие
  /// кассира.
  ///
  /// Живьём это дважды дало лишнюю позицию в чеке: кассир целился в
  /// «ОПЛАТИТЬ», попадал в открывшуюся выдачу, и товар добавлялся второй
  /// раз. Путь добавления по клику этой беды не знал не потому, что был
  /// написан правильнее, — он зовёт `search('')`, а тот таймер отменяет
  /// первой строкой.
  Future<bool> addByBarcode(String barcode) async {
    if (barcode.isEmpty) return false;
    final before = _quantitiesByLine();
    final ok = await _command(
      (t, m) => _cart.addByBarcode(t, barcode.trim(), m),
    );
    if (ok) {
      _selectChanged(before);
      _searchDebounce?.cancel();
      _emit(state.copyWith(searchQuery: '', searchResults: []));
      // Пункт 11 ревизии 2026-09-19: **этот путь не предупреждал вовсе**.
      // Проверка партии стояла только в [addProduct] — то есть при выборе
      // товара из выдачи поиска, — а скан штрихкода, главный путь кассира,
      // просроченную партию не называл ни на кассе, ни в браузере. Найдено
      // при переносе вопроса на кассу и починено здесь же.
      unawaited(_warnIfExpired());
    }
    return ok;
  }

  Future<void> addProduct(
    ProductSearchResult product, {
    Decimal? quantity,
  }) async {
    final before = _quantitiesByLine();
    final ok = await _command(
      (t, m) => _cart.addProduct(t, product.id, quantity ?? Decimal.one, m),
    );
    // Вопрос о партии уехал **за** команду — пункт 11 ревизии 2026-09-19.
    // Прежде он шёл `unawaited` параллельно с ней, и это была не
    // оптимизация, а две ошибки разом: кассир получал жёлтый снекбар о
    // товаре, который в чек мог и не встать (отказ политики, закрытая
    // смена, устаревший снимок), а просроченная партия у соседнего пути
    // ([addByBarcode]) не называлась вовсе.
    if (ok) {
      _selectChanged(before);
      unawaited(_warnIfExpired());
    }
    // Тот же снятый таймер, что и в [addByBarcode], и по той же причине:
    // этот метод зовут и мимо поля поиска (плитки быстрых товаров,
    // виртуальная клавиатура), а чистка состояния сама по себе взведённый
    // поиск не отменяет.
    _searchDebounce?.cancel();
    _emit(state.copyWith(searchQuery: '', searchResults: []));
  }

  Map<String, Decimal> _quantitiesByLine() => {
    for (final item in state.items) item.id: item.quantity,
  };

  /// Выбирает строку, которую пробитый товар изменил.
  ///
  /// **Не «последнюю» и не «строку этого товара».** Куда лягут новые
  /// единицы, решает касса, а не экран: слияние идёт в строку с той же
  /// **видимой** ценой, без ручной скидки и без марки
  /// (`LocalCartService._mergeTarget`), — то есть одна и та же кнопка то
  /// увеличивает существующую строку, то заводит новую, и угадать это
  /// снаружи нельзя. «Последняя» ошиблась бы ровно в случае слияния:
  /// кассир пробил товар, лежащий первой строкой, а подсветка уехала бы
  /// вниз чека.
  ///
  /// Поэтому выбор делается **сравнением снимков**: новая строка, а если
  /// новой нет — та, чьё количество выросло.
  void _selectChanged(Map<String, Decimal> before) {
    for (final item in state.items) {
      if (!before.containsKey(item.id)) {
        _emit(state.copyWith(selectedItemId: item.id));
        return;
      }
    }
    for (final item in state.items) {
      final was = before[item.id];
      if (was != null && item.quantity > was) {
        _emit(state.copyWith(selectedItemId: item.id));
        return;
      }
    }
  }

  void selectItem(String? itemId) {
    _emit(
      state.copyWith(
        selectedItemId: itemId,
        clearSelectedItemId: itemId == null,
      ),
    );
  }

  Future<void> updateQuantity(Decimal quantity) {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    return _command((t, m) => _cart.setQuantity(t, id, quantity, m));
  }

  Future<void> incrementQuantity() {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    return _command((t, m) => _cart.increment(t, id, m));
  }

  Future<void> decrementQuantity() {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    return _command((t, m) => _cart.decrement(t, id, m));
  }

  /// Полномочия вошедшего — задача 12.
  ///
  /// Читаются из `AppState`, куда их положил вход: там лежат уже
  /// **действующие** права (роль ∩ права режима терминала, посчитанные
  /// кассой при выписке сеанса) и индекс роли. Экран их не считает и не
  /// дополняет: решение принимает касса, и здесь только передача.
  ///
  /// Ни одного права нет — [DiscountAuthority.none]: касса откажет по праву.
  /// Это и есть закрытие второго фронта: до задачи 12 `op.sellDiscount` на
  /// кассе не проверял никто, а спрятанная кнопка правом не является (I44).
  DiscountAuthority get _authority => ref.read(saleAuthorityProvider);

  /// Условия правки строки: настройки кассы, предел скидки вошедшего —
  /// **тем же читателем, каким отказывает касса**, — и валюта.
  ///
  /// `null` — условия не прочитаны, и причина **уже** лежит в `state.error`
  /// названной (обрыв провода, истёкший сеанс, касса без модуля продажи).
  /// Диалог без условий не открывается: нарисовать предел, которого касса не
  /// давала, хуже, чем не открыть.
  ///
  /// # Зачем экрану предел
  ///
  /// Затем, что иначе кассир узнаёт о пределе только отказом: набрал 30 %,
  /// нажал «Применить», получил «больше разрешённых 15 %». Задача 18 требует
  /// обратного порядка — предел виден **до** ввода.
  ///
  /// # Почему это не второй источник
  ///
  /// `DiscountPolicy` зарегистрирован один на кассу (`service_locator.dart`)
  /// и **тот же объект** отдан `LocalCartService`, который им же и
  /// отказывает (`_authorizeDiscount`), и `LocalSaleEditTerms`, которым
  /// предел читается. Экран не считает предел и не смягчает его: он
  /// показывает то самое число. По проводу его читает та же касса
  /// (`sale.editTerms`), с полномочиями из сеанса.
  ///
  /// # Диалог — удобство, а не защита (I44)
  ///
  /// Ограничение ввода в диалоге не заменяет проверку кассы ни на минуту:
  /// вход у скидки не один (провод, отложенный чек), а спрятанная или
  /// подрезанная кнопка правом не является. Это записано пробой «предел
  /// на обоих фронтах» (`test/data/sale/discount_authority_test.dart`).
  ///
  /// # Задача 44: терминала, который предела не читает, больше нет
  ///
  /// Здесь стояла ветка `!GetIt.I.isRegistered<DiscountPolicy>()` с ответом
  /// «сто процентов, предел этим терминалом не прочитан». Правдоподобное
  /// тело для браузера, где читателя предела не было, — и недостижимое,
  /// потому что кнопку «Редактировать» там прятали. Браузер теперь читает
  /// условия у кассы; незаведённая привязка — ошибка сборки контейнера,
  /// её ловит `test/architecture/browser_routes_test.dart`.
  Future<SaleEditTerms?> editTerms() async {
    try {
      return await GetIt.I<SaleEditTermsReader>().read(by: _authority);
    } on WireRefusal catch (refusal) {
      _emitError(_errorKeyOf(refusal));
      return null;
    } catch (e, stack) {
      talker.error('Sale: edit terms failed: $e', e, stack);
      _emitError('error.save_failed:${safeErrorText(e)}');
      return null;
    }
  }

  Future<void> setDiscountPercent(Decimal percent) {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    final by = _authority;
    return _command(
      (t, m) => _cart.setDiscountPercent(t, id, percent, m, by: by),
    );
  }

  Future<void> setDiscountAmount(Decimal amount) {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    final by = _authority;
    return _command(
      (t, m) => _cart.setDiscountAmount(t, id, amount, m, by: by),
    );
  }

  Future<void> updatePrice(Decimal price) {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    final by = _authority;
    return _command((t, m) => _cart.updatePrice(t, id, price, m, by: by));
  }

  Future<void> setMark(String mark) {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    return _command((t, m) => _cart.setMark(t, id, mark, m));
  }

  Future<void> removeSelectedItem() {
    final id = state.selectedItemId;
    if (id == null) return Future<void>.value();
    return _command((t, m) => _cart.removeLine(t, id, m));
  }

  /// Очищает чек — строки уходят из базы, а не только с экрана.
  Future<void> clearSale() {
    _searchDebounce?.cancel();
    _emit(state.copyWith(searchQuery: '', searchResults: [], clearError: true));
    if (state.receiptNo == null) return Future<void>.value();
    return _command((t, m) => _cart.clear(t, m));
  }

  // ── режим, агент, откладывание ────────────────────────────────────────

  /// Переключает чек между розницей и оптом.
  ///
  /// # Задача 8, находка 4: опт на кассе теперь действительно работает
  ///
  /// До этой работы метод менял `SaleMode` в состоянии экрана — и всё:
  /// вызывающих у него не было ни одного (`git grep toggleMode` по `lib/`
  /// находил только объявление), а цена строки признак режима не смотрела
  /// вовсе. При этом панель итогов **показывала ярлык режима**
  /// (`sale_total_panel._ModeChip`), всегда «розница»: индикатор состояния,
  /// которое нельзя изменить.
  ///
  /// Теперь это команда контракта: `Sales.isWholesale` меняется с версией
  /// корзины, а цену по нему выбирает касса (`LocalCartService
  /// ._addOrMerge`). Уже набранные строки не переоцениваются — политика
  /// названа в докстринге `CartService.setWholesale`; новые единицы
  /// ложатся по цене нового режима отдельной строкой.
  Future<void> toggleMode() {
    final next = state.mode == SaleMode.retail;
    final by = _authority;
    return _command((t, m) => _cart.setWholesale(t, next, m, by: by));
  }

  Future<void> setAgent(int id, String name) async {
    await _command((t, m) => _cart.setAgent(t, id, m));
    if (state.agentId == id) _emit(state.copyWith(agentName: name));
  }

  Future<void> clearAgent() => _command((t, m) => _cart.setAgent(t, null, m));

  /// Откладывает чек и сразу начинает следующий.
  ///
  /// Две команды подряд, а не одна: `defer` отвечает пустой корзиной (у
  /// рабочего места после откладывания чека в работе нет), следующий чек
  /// начинает `start`. Сомнение 1 отчёта задачи 7 — «не лишний ли это круг
  /// по проводу» — здесь отвечено: на кассе круга нет вовсе, а для
  /// браузера склеить две команды в одну дешевле, чем разделить одну на
  /// две, если замер это потребует.
  /// Отвечает, **состоялось ли откладывание** — задача 10 ревизии
  /// 2026-09-19.
  ///
  /// До неё метод был `Future<void>`, и экран (`sale_screen._handleDefer`)
  /// звал его **не дожидаясь** ответа, после чего показывал «Чек отложен»
  /// всегда. Право `op.deferSale` касса проверяла (`LocalCartService.defer`,
  /// задача 28), то есть чек у кассира без права оставался в работе — а
  /// сказано ему было, что он отложен. Отказ при этом лежал в `state.error`
  /// названным и снизу тут же перекрывался ложным сообщением об успехе.
  ///
  /// `false` означает «не отложили»; причина **уже** в `state.error`, и
  /// показывает её общий слушатель экрана. Второго текста отказа здесь нет
  /// намеренно: он разошёлся бы со словарём.
  Future<bool> deferSale() async {
    if (state.isEmpty) return false;
    final by = _authority;
    final ok = await _command((t, m) => _cart.defer(t, m, by: by));
    if (!ok) return false;
    await _initSale();
    return true;
  }

  /// Поднять отложенный чек. [fromPosId] — касса, на которой он отложен;
  /// `null` — своя.
  ///
  /// Номер кассы несёт **карточка пула**, а не экран: чужой чек отличается
  /// от своего только им, и угадывать его по номеру чека нельзя — пока чек
  /// соседа не доехал, обе кассы могут выдать один номер.
  Future<void> loadDeferredSale(int receiptNo, {int? fromPosId}) {
    final by = _authority;
    return _command(
      (t, m) =>
          _cart.loadDeferred(t, receiptNo, m, by: by, deferredPosId: fromPosId),
    );
  }

  /// Подхватывает заказ ресторана как чек в работе.
  ///
  /// # Задача 8: это не второй способ набрать чек
  ///
  /// Заказ стола — обычный чек в работе того же рабочего места:
  /// `CreateTableOrderUseCaseImpl` кладёт `Sales.state = 0` и
  /// `terminalId = terminals.self()`, а строки заказа лежат в
  /// `SaleProducts`. Прежний код читал эти строки сам и складывал копию в
  /// память экрана — то есть заводил вторую правду о корзине ровно там,
  /// где задача 7 её убрала.
  ///
  /// Здесь заказ просто **продолжается** тем же `start`, что и любой чек:
  /// снимок приходит из базы вместе с сервисным сбором, который
  /// `CalculateServiceChargeUseCase.applyToSale` дописал строкой.
  ///
  /// **Честно о пределе.** Если у рабочего места открыто несколько столов
  /// сразу, `SaleDao.findInProgress` вернёт **самый ранний** из них по
  /// номеру чека, и экран скажет «не тот чек», а не подхватит названный.
  /// Это не регресс этой задачи и не её дефект: несколько чеков в работе у
  /// одного рабочего места ломают `findInProgress` сами по себе (правило
  /// смысла `Sales.terminalId`), и ресторан — отдельная спека. Названо
  /// здесь, чтобы следующий не искал причину в корзине.
  Future<void> loadFromRestaurantOrder({
    required int receiptNo,
    required int posId,
  }) async {
    await _initSale();
    if (state.receiptNo == receiptNo && state.posId == posId) return;
    talker.warning(
      'Sale: restaurant order $receiptNo/$posId is not the cart in progress '
      '(${state.receiptNo}/${state.posId})',
    );
    _emitError('error.order_not_found');
  }

  // ── предупреждения ────────────────────────────────────────────────────

  void clearWarning() {
    if (state.warning != null) _emit(state.copyWith(clearWarning: true));
  }

  /// Отказ показан кассиру — можно забыть.
  ///
  /// Заведён задачей 13 вместе с показом отказа на экране. До неё
  /// `state.error` заполнялся девятью местами этого файла и не читался
  /// **никем**, кроме `ref.listen` на единственный ключ
  /// `kShiftOverAgeError`: показать отказ было нечем, а раз нечем — то и
  /// снимать его было не с чего.
  ///
  /// **С экрана продажи не зовётся, и это решено при слиянии задач 13 и
  /// 23.** Задача 13 снимала отказ прямо из `ref.listen`, чтобы второй
  /// такой же отказ подряд был изменением состояния и показался. Задача 23
  /// перенесла ровно это в [_emitError] (ноль перед повтором того же
  /// ключа). Цена снятия с экрана, которую задача 23 называла вслух —
  /// `PaymentNotifier.processPayment` читает `error` после неудачного
  /// `completeSale`, — в слитом дереве **уже не действует**: задача 14
  /// увела завершение оплаты за контракт `PaymentService`, а задача 9
  /// удалила `completeSale` вовсе. Решение держит другое:
  /// снятие отсюда было бы **третьим** снимателем отказа, а третий
  /// измерен дефектом (см. `keepError` у [SaleState.fromCart]). Метод
  /// остаётся частью договора уведомителя (его
  /// держат подмены в `test/helpers/mock_providers.dart`), но законных
  /// снимателей отказа теперь двое, и оба внутри контроллера: [_emitError]
  /// и удавшаяся команда через `SaleState.fromCart`.
  void clearError() {
    if (state.error != null) _emit(state.copyWith(clearError: true));
  }

  /// Просроченная партия — предупреждение по **вставшей в чек** строке.
  ///
  /// # Что изменилось — пункт 11 ревизии 2026-09-19
  ///
  /// Раньше метод ходил в `BatchTrackingUseCase` и `WmsConfigUseCase` прямо
  /// через `GetIt.I.isRegistered`, а браузер их не привязывает: оба тянут
  /// базу кассы. Обе развилки стояли записью ОТКРЫТО в двух сторожах, и
  /// кассир за планшетом пробивал просроченный товар молча. Теперь вопрос
  /// один (`ExpiryWarningReader`), и за ним на кассе стоят те же два
  /// юзкейса, а в браузере — операция провода `sale.expiryWarning`.
  ///
  /// # Почему товар берётся из состояния, а не из довода
  ///
  /// Спрашивается **изменённая строка**, которую только что выбрал
  /// [_selectChanged]. Довод отпал вместе с прежним порядком вызова: у
  /// пути «скан штрихкода» имени товара до ответа кассы нет вовсе — его
  /// приносит сам чек. Одно место вместо двух, и оба пути спрашивают про
  /// то, что действительно легло в чек, а не про то, что кассир целил.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что кассир увидит снекбар до оплаты: ответ асинхронный и на планшете
  /// едет по сети. Предупреждение запретом не является — решение принимает
  /// кассир. Отказ провода гасится тишиной: «спросить не удалось» и «не
  /// просрочено» на экране сегодня одинаковы, и выдумывать предупреждение
  /// на отказе значило бы учить не верить жёлтому цвету.
  Future<void> _warnIfExpired() async {
    final line = state.selectedItem;
    if (line == null) return;
    try {
      final expired = await GetIt.I<ExpiryWarningReader>().isPickedBatchExpired(
        line.productId,
      );
      if (expired && !_disposed) _emit(state.copyWith(warning: line.name));
    } catch (e) {
      talker.warning('Sale: expiry warning: $e');
    }
  }
}

final saleControllerProvider = NotifierProvider<SaleNotifier, SaleState>(
  SaleNotifier.new,
);

/// Полномочия вошедшего — **один** источник на весь экран продажи.
///
/// Читаются из `AppState`, куда их положил вход: там лежат уже **действующие**
/// права (роль ∩ права режима терминала, посчитанные кассой при выписке
/// сеанса) и индекс роли. Экран их не считает и не дополняет: решение
/// принимает касса, и здесь только передача. Ни одного права нет —
/// полномочия пустые, и касса откажет по праву.
///
/// Провайдером, а не геттером [SaleNotifier], с задачи 10 ревизии
/// 2026-09-19: полномочия понадобились **второму** читателю — подписке на
/// пул отложенных ([deferredCartsProvider]), которая живёт вне контроллера.
/// Вторая копия этого выражения разъехалась бы с первой при первой же правке
/// состава полномочий, и разъехалась бы молча.
final saleAuthorityProvider = Provider<DiscountAuthority>((ref) {
  final app = ref.watch(appStateProvider);
  return DiscountAuthority(
    roleIndex: app.userRole ?? -1,
    permissions: app.permissions,
    userId: app.userId,
  );
});

/// Общий пул отложенных чеков кассы — подпиской контракта, а не запросом к
/// базе из виджета диалога (задача 8: `sale_screen._deferredSalesProvider`
/// читал `saleDao.findByState(3)` прямо из базы).
///
/// # Право `op.deferSale` — задача 10 ревизии 2026-09-19
///
/// До неё подписка звалась **без полномочий вовсе**, и это была вторая
/// половина той же дыры, что закрыла задача 9 для цены: на проводе
/// `sale.deferredList` закрыт правом (`SaleOps.deferredList`), а на самой
/// кассе — ничем. Кассир без `op.deferSale`, сидящий за кассой, видел чужой
/// пул целиком — номера, суммы и **имена** кассиров, отложивших чеки. То
/// есть касса была слабее планшета ровно там, где идёт основная торговля.
///
/// Полномочия идут `watch`, а не `read`: сменившиеся права обязаны
/// пересобрать подписку, иначе кассир, у которого право только что сняли,
/// продолжал бы смотреть в открытый пул до перезахода.
///
/// Отказ приходит `AsyncError` с отказом кассы кода `forbidden`; диалог
/// рисует его названной причиной (`deferred_sales_dialog.dart`, ветка
/// `hasError`).
final deferredCartsProvider = StreamProvider.autoDispose<List<DeferredCart>>((
  ref,
) {
  return GetIt.I<CartService>().watchDeferred(
    by: ref.watch(saleAuthorityProvider),
  );
});

final selectedSaleItemProvider = Provider<SaleItem?>((ref) {
  return ref.watch(saleControllerProvider.select((s) => s.selectedItem));
});

final saleTotalProvider = Provider<Decimal>((ref) {
  return ref.watch(saleControllerProvider.select((s) => s.total));
});
