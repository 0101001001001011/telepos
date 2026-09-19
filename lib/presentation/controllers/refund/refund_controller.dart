import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/named_refusal.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble;
import 'package:telepos/domain/sale/command_key.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/controllers/app/money_ledger_revision.dart';

enum RefundMode { byReceipt, withoutReceipt }

enum RefundReason { defective, notSuitable, cashierError, other }

@immutable
class RefundItem {
  // ignore: prefer_const_constructors_in_immutables - Decimal не поддерживает const
  RefundItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.maxQuantity,
    this.barcode,
    this.originalSaleId,
    this.isSelected = false,
    RefundReason? reason,
  }) : reason = reason ?? RefundReason.other;

  /// Идентификатор **строки черновика**, а не товара.
  ///
  /// В возврате по чеку это номер строки чека, в возврате без чека —
  /// `p<код товара>` (докстринг `RefundLine.id`). До задачи 20 здесь стоял
  /// выдуманный `refund_1`, растущий счётчиком экрана, и адресовать им кассе
  /// было нечего.
  final String id;

  final int productId;

  final String name;

  final Decimal price;

  final Decimal quantity;

  /// Сколько было продано — потолок. `null` в возврате без чека: там потолка
  /// нет, потому что нет и чека, с которым сверяться.
  final Decimal? maxQuantity;

  final String? barcode;

  final String? originalSaleId;

  /// Строка сейчас в черновике кассы.
  ///
  /// **Не украшение экрана.** Снять выделение — значит отправить кассе ноль
  /// и убрать строку из черновика; поставить обратно — отправить количество.
  /// Правило контракта (`RefundService.setLineQuantity`): касса обязана
  /// узнать итог выделения **до** того, как отдаст деньги, а не в момент
  /// нажатия «вернуть».
  final bool isSelected;

  final RefundReason reason;

  Decimal get total => price * quantity;

  RefundItem copyWith({
    String? id,
    int? productId,
    String? name,
    Decimal? price,
    Decimal? quantity,
    Decimal? maxQuantity,
    String? barcode,
    String? originalSaleId,
    bool? isSelected,
    RefundReason? reason,
  }) {
    return RefundItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      barcode: barcode ?? this.barcode,
      originalSaleId: originalSaleId ?? this.originalSaleId,
      isSelected: isSelected ?? this.isSelected,
      reason: reason ?? this.reason,
    );
  }
}

@immutable
class ReceiptInfo {
  const ReceiptInfo({
    required this.receiptNo,
    required this.posId,
    this.posName,
  });

  final int receiptNo;
  final int posId;

  /// Имя кассы, если терминал его знает. По проводу оно не едет: снимок
  /// возврата (`RefundView`) везёт номер кассы, а не её название — экран
  /// показывает `POS-<номер>`, когда имени нет.
  final String? posName;
}

@immutable
class RefundState {
  const RefundState({
    this.mode = RefundMode.byReceipt,
    this.items = const [],
    this.selectedItemId,
    this.receiptInfo,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
    this.isLoading = false,
    this.error,
    this.version = 0,
    this.draftNo,
    this.posId,
    this.sessionLost,
    this.connectionLost = false,
    this.destinations = const [],
  });

  /// Куда уйдут деньги — ответ кассы из снимка черновика (задача 26).
  /// Экран его показывает до подтверждения и ничего не пересчитывает.
  final List<RefundDestination> destinations;

  final RefundMode mode;

  final List<RefundItem> items;

  final String? selectedItemId;

  final ReceiptInfo? receiptInfo;

  final String searchQuery;

  final List<RefundSearchResult> searchResults;

  final bool isSearching;

  final bool isLoading;

  final String? error;

  /// Версия снимка черновика — то, с чем сверяется касса (I161).
  final int version;

  /// Номер черновика возврата на кассе. `null` — черновика нет.
  final int? draftNo;

  /// Касса, которой принадлежит черновик.
  final int? posId;

  /// Сеанс кончился — вкладке нечего делать на этом экране.
  ///
  /// **Отдельное поле, а не [error], и это блокер, найденный кругом
  /// правки.** До него `_enqueue` ловил `SessionLost` голым `catch` и
  /// превращал в `error.save_failed:${safeErrorText(error)}`, а тот для
  /// чужого исключения отдаёт **имя типа**: кассир видел «Ошибка
  /// сохранения: SessionLost» и оставался на экране, где после этого не
  /// работало ничего. Тупик, из которого выход только закрытием вкладки —
  /// ровно то, что чинилось переводом `unknown_terminal`, но починка
  /// кончалась на границе службы.
  ///
  /// Полем, а не броском наружу: команды пущены из `onPressed` и никем не
  /// ожидаются — поймать бросок там некому. Экран слушает это поле и зовёт
  /// `handleSessionLost` — ту же единственную реакцию, что уже стоит в
  /// `hardware_settings_screen.dart` и `print_price_tag_dialog.dart`.
  final SessionLost? sessionLost;

  /// Подписка на черновик оборвалась — состояние с кассы больше не приходит.
  ///
  /// **Не то же самое, что «черновика нет».** Живой прогон 2026-09-07,
  /// шаг 8: после F5 экран показал «Нет товаров для возврата», а в консоли
  /// лежало `WireRefusal(stream_ended: подписка оборвалась — состояние
  /// больше не приходит)`. Кассир видел **утверждение о чеке** там, где на
  /// самом деле **не было ответа кассы**.
  ///
  /// Тот же класс, что «Ошибка сохранения: SessionLost» и молчащая кнопка:
  /// молчание выдано за ответ. Спека называет требуемое поведение прямо
  /// (шаг 10): терминал показывает названное состояние — «связь с кассой
  /// потеряна», — а по возвращении получает корзину подпиской и продолжает.
  final bool connectionLost;

  bool get started => draftNo != null;

  int get selectedCount => items.where((i) => i.isSelected).length;

  bool get allSelected => items.isNotEmpty && items.every((i) => i.isSelected);

  bool get noneSelected => items.every((i) => !i.isSelected);

  Decimal get selectedTotal => items
      .where((i) => i.isSelected)
      .fold(Decimal.zero, (sum, item) => sum + item.total);

  Decimal get total =>
      items.fold(Decimal.zero, (sum, item) => sum + item.total);

  RefundItem? get selectedItem {
    if (selectedItemId == null) return null;
    try {
      return items.firstWhere((i) => i.id == selectedItemId);
    } catch (_) {
      return null;
    }
  }

  bool get hasItems => items.isNotEmpty;

  bool get canRefund => items.any((i) => i.isSelected);

  RefundState copyWith({
    RefundMode? mode,
    List<RefundItem>? items,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    ReceiptInfo? receiptInfo,
    bool clearReceiptInfo = false,
    String? searchQuery,
    List<RefundSearchResult>? searchResults,
    bool? isSearching,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? version,
    int? draftNo,
    bool clearDraftNo = false,
    int? posId,
    SessionLost? sessionLost,
    bool clearSessionLost = false,
    bool? connectionLost,
    List<RefundDestination>? destinations,
  }) {
    return RefundState(
      destinations: destinations ?? this.destinations,
      mode: mode ?? this.mode,
      items: items ?? this.items,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      receiptInfo: clearReceiptInfo ? null : (receiptInfo ?? this.receiptInfo),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      version: version ?? this.version,
      draftNo: clearDraftNo ? null : (draftNo ?? this.draftNo),
      posId: posId ?? this.posId,
      sessionLost: clearSessionLost ? null : (sessionLost ?? this.sessionLost),
      connectionLost: connectionLost ?? this.connectionLost,
    );
  }
}

@immutable
class RefundSearchResult {
  const RefundSearchResult({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
  });

  final int id;
  final String name;
  final Decimal price;
  final String? barcode;
}

/// Экран возврата над доменным контрактом — задача 20 плана «Продажа с
/// браузерного терминала».
///
/// # Что изменилось и почему это не косметика
///
/// До задачи 20 контроллер держал возврат **в памяти экрана** и сам ходил в
/// базу: `loadReceipt` читал `Sales`, `SaleProducts`, `ProductInfos` и
/// `ThisPos`, а `processRefund` звал `RefundInitiationUseCase`/`RefundUseCase`
/// напрямую. Это работало ровно на одном хосте — на кассе. С браузерного
/// терминала тот же код выполнить нечем: база тянет `dart:ffi`, которого в
/// вебе нет, и веб-сборка на нём не компилировалась вовсе.
///
/// Теперь возврат живёт за `RefundService`: на кассе это `LocalRefundService`
/// (задача 18), в браузере — `WtRefundService` поверх провода (эта же
/// задача). Экран один и тот же, под ним меняется только реализация.
///
/// # Выделение строк — это команда кассе, а не свойство виджета
///
/// Снять выделение значит отправить `setLineQuantity(id, 0)`: строка уходит
/// из черновика кассы. Поставить обратно — отправить количество. Экран
/// помнит **весь набор** строк, который он видел ([_known]), и потому
/// показывает снятую строку невыделенной, а не теряет её.
///
/// Цена названа контрактом честно: пакетной формы у команды нет, поэтому
/// «выделить всё» на чеке в тридцать строк — тридцать кругов по проводу при
/// правиле «одна команда в полёте» (I161). На кассе это тридцать локальных
/// вызовов и незаметно; на планшете — заметно, и мерить это надо живьём
/// (задача 21), а не рассуждать о нём здесь.
///
/// # Чего этот контроллер больше не делает
///
/// - **не открывает смену молча** — касса отказывает `shift_not_open`;
/// - **не срезает количество молча.** Прежний `updateQuantity` тихо резал
///   введённое до `maxQuantity`, и кассир видел одно, а возвращалось другое.
///   Касса отвечает `invalid_amount` с текстом, и экран его показывает;
/// - **не печатает чек возврата.** Печать — железо кассы, и она осталась
///   кассой (`LocalRefundService.complete`, шаг 7 спеки). Терминал её
///   запускает и получает исход, а не собирает чек по своей базе.
class RefundNotifier extends Notifier<RefundState> {
  Timer? _searchDebounce;
  Timer? _reconnect;
  StreamSubscription<RefundView>? _draftSubscription;

  /// Подъём подписки, который уже идёт, — чтобы второй вызов к нему
  /// присоединился, а не завёл свою (разбор — на [_listenToDraft]).
  Future<void>? _listening;

  int? _terminalId;

  /// Метка сеанса экрана — половина ключа повтора. Тот же приём, что у
  /// `SaleNotifier`: ключ обязан быть новым у каждого экрана и повторяемым
  /// внутри одной команды.
  final String _session = newCommandSessionTag();

  int _commandSeq = 0;

  /// Хвост очереди: следующая команда ждёт предыдущую (I161).
  Future<void> _inFlight = Future<void>.value();

  bool _disposed = false;

  /// Всё, что экран видел в этом черновике, по идентификатору строки.
  ///
  /// Снятая строка исчезает из черновика кассы, но не из этой карты — иначе
  /// «снять выделение» означало бы «потерять строку с экрана», и вернуть её
  /// было бы нечем. Карта чистится при смене черновика.
  final _known = <String, RefundItem>{};

  int? _knownDraftNo;

  RefundService get _refunds => GetIt.I<RefundService>();

  @override
  RefundState build() {
    ref.onDispose(() {
      _disposed = true;
      _searchDebounce?.cancel();
      _reconnect?.cancel();
      _draftSubscription?.cancel();
    });
    Future.microtask(_listenToDraft);
    return const RefundState();
  }

  // ── метка команды ─────────────────────────────────────────────────────

  CartCommandMeta _meta() => CartCommandMeta(
    key: '$_session:${_commandSeq++}',
    baseVersion: state.version,
    receiptNo: state.draftNo,
  );

  /// Рабочее место, от имени которого идут команды.
  ///
  /// Читается через домен — `TerminalIdentity` (что этот клиент запомнил о
  /// себе), а если ещё не запомнил — `TerminalRepository.self()`. Тот же
  /// путь, что у экрана продажи: `terminalDao.self()` из базы не годится,
  /// у браузерного терминала своё имя.
  Future<int?> _resolveTerminalId() async {
    final known = _terminalId;
    if (known != null) return known;
    try {
      final remembered = await GetIt.I<TerminalIdentity>().currentId();
      if (remembered != null) return _terminalId = remembered;
      final self = await GetIt.I<TerminalRepository>().self();
      return _terminalId = self.id;
    } catch (e) {
      talker.warning('Refund: terminal id unresolved: $e');
      return null;
    }
  }

  /// Вернуться к кассе самому.
  ///
  /// Обрыв случается, когда кассир **уже на экране**, и ждать от него ухода
  /// и возвращения — значит просить чинить провод руками. Корзина живёт на
  /// кассе (решение 2 спеки), поэтому терминалу достаточно подписаться
  /// заново: по возвращении связи он получит черновик тем же путём, каким
  /// получил бы его при первом заходе.
  ///
  /// Пауза, а не немедленный повтор: оборванная касса не отвечает и через
  /// микросекунду, а очередь повторов без паузы — это тот же обрыв, только
  /// в цикле.
  void _scheduleReconnect() {
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      unawaited(_listenToDraft());
    });
  }

  /// Поднять подписку, если её нет, и забыть кончившийся сеанс.
  ///
  /// Зовётся экраном при каждом заходе на него. **Не украшение, а починка
  /// измеренного тупика:** провайдер возврата не `autoDispose`, никем не
  /// `invalidate` и живёт всю жизнь вкладки, а `_listenToDraft()` звался
  /// ровно один раз из [build]. Значит после кончившегося сеанса —
  /// «получил отказ → ушёл на вход → вошёл → вернулся на возврат» —
  /// подписка на черновик оставалась мёртвой **навсегда**: экран показывал
  /// снимок, снятый до отказа, и не узнавал ни об изменениях с кассы, ни о
  /// второй вкладке. Лечилось только F5.
  ///
  /// На кассе этого не бывает: там нет ни истёкшего сеанса провода, ни
  /// перезахода без пересоздания дерева.
  ///
  /// Идемпотентна: живая подписка при незакончившемся сеансе не трогается.
  Future<void> ensureWatching() async {
    if (_draftSubscription != null &&
        state.sessionLost == null &&
        !state.connectionLost) {
      return;
    }
    _emit(state.copyWith(clearSessionLost: true));
    await _listenToDraft();
  }

  /// Подписка на черновик: возврат, изменённый где угодно, доезжает сам.
  ///
  /// Изменяющих у черновика больше одного: сам экран, вторая вкладка того же
  /// места и касса, которая забывает черновик на входе другого кассира
  /// (`RefundService.abandon`). Без подписки экран показывал бы возврат,
  /// которого на кассе уже нет.
  ///
  /// # Один подъём за раз — находка приёмки 2026-09-17
  ///
  /// Первый заход на экран звал этот метод **дважды**: микрозадачей из
  /// [build] и из `ensureWatching` экрана. Оба ждали [_resolveTerminalId],
  /// и живая проверка `_draftSubscription != null` в `ensureWatching` в этом
  /// окне ничего не видела. Вторая подписка отменяла первую, у которой поток
  /// провода уже открывался, — и на каждый первый заход касса получала поток,
  /// брошенный в момент рождения.
  ///
  /// Брошенный поток сам по себе безвреден. Вредным его делал `rk_quic` до
  /// 0.2.2: касса отвечала в брошенный поток отказом, запись получала
  /// `peerGone`, а `QuicServer` раздавал ответы **по порядку прихода, а не по
  /// вызову** — и тот же `peerGone` получала первая запись снимка в живую
  /// подписку рядом. `TillSubscriptions.deliver` честно закрывал её, и
  /// терминал видел `stream_ended` — «связь с кассой потеряна» при живой
  /// связи, ровно один раз и только на первом заходе (на повторных провайдер
  /// уже жив и `ensureWatching` выходит сразу). Причина починена в пакете
  /// (`packages/rk_quic`, `_CommandChannel`, проба
  /// `concurrent_commands_test.dart`); здесь снят повод: подписка, которую
  /// некому держать, не заводится вовсе.
  Future<void> _listenToDraft() =>
      _listening ??= _startListening().whenComplete(() => _listening = null);

  Future<void> _startListening() async {
    final terminalId = await _resolveTerminalId();
    if (terminalId == null || _disposed) {
      if (!_disposed) {
        _emit(state.copyWith(error: 'error.till_not_configured'));
      }
      return;
    }

    _draftSubscription?.cancel();
    _draftSubscription = _refunds
        .watch(terminalId)
        .listen(
          _applyView,
          onError: (Object e) {
            if (_disposed) return;
            // Кончившийся сеанс — не отказ операции: он лечится входом
            // заново, и показывать его текстом значило бы оставить кассира
            // на экране, где после этого не работает ничего.
            if (e is SessionLost) {
              talker.warning('Refund: session lost on draft watch');
              _emit(state.copyWith(sessionLost: e));
              return;
            }
            // Отказ подписки — это в том числе «нет права op.refund»
            // (сторож кассы отвечает на открытии потока) и обрыв провода.
            // Показать его обязаны **состоянием**, а не только всплывающей
            // строкой: снимок, которого нет, — это не «товаров нет».
            talker.warning('Refund: draft watch error: $e');
            _emit(state.copyWith(connectionLost: true, error: _errorKeyOf(e)));
            _scheduleReconnect();
          },
        );
  }

  void _emit(RefundState next) {
    if (_disposed) return;
    state = next;
  }

  /// Снимок кассы → состояние экрана, с сохранением снятых строк.
  void _applyView(RefundView view) {
    if (_disposed) return;

    // Другой черновик — другой набор строк. Помнить снятые от прежнего
    // значило бы показать в новом возврате чужой товар.
    if (view.draftNo != _knownDraftNo) {
      _known.clear();
      _knownDraftNo = view.draftNo;
    }

    final inDraft = {for (final line in view.lines) line.id: line};

    for (final line in view.lines) {
      final previous = _known[line.id];
      _known[line.id] = RefundItem(
        id: line.id,
        productId: line.productId,
        name: line.name,
        price: line.price,
        quantity: line.quantity,
        maxQuantity: line.maxQuantity,
        barcode: line.barcode,
        originalSaleId: view.saleReceiptNo == null
            ? null
            : 'sale_${view.saleReceiptNo}',
        isSelected: true,
        reason: previous?.reason,
      );
    }

    final items = [
      for (final item in _known.values)
        inDraft.containsKey(item.id) ? item : item.copyWith(isSelected: false),
    ];

    final selected = state.selectedItemId;
    _emit(
      state.copyWith(
        // Снимок пришёл — значит связь есть; состояние обязано смениться
        // само, а не ждать нажатия.
        connectionLost: false,
        items: items,
        destinations: view.destinations,
        version: view.version,
        draftNo: view.draftNo,
        clearDraftNo: view.draftNo == null,
        posId: view.posId,
        isLoading: false,
        mode: view.byReceipt ? RefundMode.byReceipt : state.mode,
        receiptInfo: view.saleReceiptNo == null
            ? null
            : ReceiptInfo(
                receiptNo: view.saleReceiptNo!,
                posId: view.salePosId ?? view.posId,
              ),
        clearReceiptInfo: view.saleReceiptNo == null,
        clearSelectedItemId:
            selected != null && !items.any((i) => i.id == selected),
      ),
    );
  }

  /// Одна команда в полёте плюс перевод отказа в ключ для человека.
  Future<bool> _enqueue(Future<void> Function() body) {
    // Прошлый отказ гасится **здесь**, а не в каждой команде порознь.
    //
    // Экран молчит, когда текст ошибки не изменился (`next == previous`), а
    // два нажатия на одну неисправность дают его **дословно одинаковым**.
    // Чистка стояла в трёх местах и **не стояла** в общем ходе команды —
    // значит повторное нажатие «изменить количество» на том же чеке уже
    // отвечало молчанием. Одно место вместо четырёх: забыть его теперь
    // негде.
    _emit(state.copyWith(clearError: true));

    final next = _inFlight.then((_) async {
      if (_disposed) return false;
      try {
        await body();
        return true;
      } on SessionLost catch (error) {
        // **Не в общий катч.** `SessionLost` — не `WireRefusal`, и голый
        // `catch` ниже отдавал бы `error.save_failed:SessionLost`: имя типа
        // вместо действия. Сеанс кончился, лечится он входом заново, и
        // сказать об этом обязан экран — полем, а не текстом ошибки.
        talker.warning('Refund: session lost on command');
        _emit(state.copyWith(isLoading: false, sessionLost: error));
        return false;
      } catch (e, stack) {
        if (e is! WireRefusal) {
          talker.error('Refund: command failed: $e', e, stack);
        }
        _emit(state.copyWith(isLoading: false, error: _errorKeyOf(e)));
        return false;
      }
    });
    _inFlight = next.then((_) {});
    return next;
  }

  /// Отказ кассы → ключ, который экран умеет показать **назван­ным**.
  ///
  /// Возврат — место, где отказ по праву обычен: количество больше
  /// проданного, чек уже возвращён, смена закрыта, права на возврат без чека
  /// нет. Прежний экран показывал на всё это «Ошибка», и половина работы
  /// кассы была для него неразличима.
  ///
  /// # Код, а не текст кассы (2026-09-15)
  ///
  /// До этого дня ключ нёс `WireRefusal.message` — фразу, написанную кассой
  /// по-русски для журнала, — и кассир с казахским интерфейсом читал её
  /// буквами. Теперь ключ несёт `namedRefusalText` (`refusal(<код>): …`), и
  /// `ErrorLocalizer` показывает фразу словаря под код
  /// (`saleRefusalErrorKeys`); код, которого там нет, — «Возврат не
  /// выполнен: неизвестная причина (код …)», без текста кассы.
  ///
  /// [_refundOwnKeys] — коды, общие с корзиной, чья фраза корзины на
  /// возврате неверна.
  String _errorKeyOf(Object error) {
    if (error is! NamedRefusal) {
      return 'error.save_failed:${safeErrorText(error)}';
    }
    final own = _refundOwnKeys[error.code];
    if (own != null) return own;
    return 'error.refund_refused:${namedRefusalText(error)}';
  }

  /// Коды, показываемые на возврате не фразой общей карты.
  ///
  /// `receipt_not_found` экран возврата называет своей фразой
  /// (`_refundErrorMessage`), `till_not_configured` — фразой входа в продажу
  /// не годится. `invalid_amount` общий с корзиной
  /// (`refundInvalidAmountCode`), но фраза корзины — про скидку больше
  /// 100 %, а на возврате это «больше проданного».
  static const _refundOwnKeys = <String, String>{
    refundReceiptNotFoundCode: 'error.receipt_not_found',
    'till_not_configured': 'error.till_not_configured',
    refundInvalidAmountCode: 'error.refund_invalid_amount',
  };

  /// Команда возврата: рабочее место, метка, ответ снимком.
  Future<bool> _command(
    Future<RefundView> Function(int terminalId, CartCommandMeta meta) run,
  ) => _enqueue(() async {
    final terminalId = await _resolveTerminalId();
    if (terminalId == null) {
      throw const WireRefusal('till_not_configured', 'касса не настроена');
    }
    if (_disposed) return;
    _applyView(await run(terminalId, _meta()));
  });

  // ── команды экрана ────────────────────────────────────────────────────

  /// Переключение вида возврата.
  ///
  /// «Без чека» — **команда кассе**, а не режим экрана: у неё своё право
  /// (`op.refundWithoutReceipt`), и проверяет его касса в момент нажатия. До
  /// задачи 20 этот ключ не читала ни одна строка `lib/`.
  ///
  /// «По чеку» черновика не заводит — его заведёт [loadReceipt]. Прежний код
  /// на этом месте стирал строки экрана; теперь стирать нечего: строки живут
  /// на кассе, и пока чек не выбран, там остаётся прежний черновик.
  Future<void> setMode(RefundMode mode) async {
    _searchDebounce?.cancel();
    _emit(
      state.copyWith(
        mode: mode,
        searchQuery: '',
        searchResults: const [],
        isSearching: false,
        clearError: true,
      ),
    );
    if (mode == RefundMode.withoutReceipt) {
      await _command(
        (terminalId, meta) => _refunds.startWithoutReceipt(terminalId, meta),
      );
    }
  }

  Future<void> loadReceipt(int receiptNo, int posId) async {
    _emit(state.copyWith(isLoading: true, clearError: true));
    await _command(
      (terminalId, meta) =>
          _refunds.loadReceipt(terminalId, receiptNo, posId, meta),
    );
    _emit(state.copyWith(isLoading: false));
  }

  /// Поиск товара для возврата без чека.
  ///
  /// Идёт через `CartService.search` — тот же поиск, что у экрана продажи, а
  /// не третий свой. В браузерном терминале контракт корзины появляется
  /// задачей 13 того же плана; пока его нет, поиск называет это, а не падает
  /// «объект не зарегистрирован» (И144).
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
      if (!GetIt.I.isRegistered<CartService>()) {
        // Тот же случай: отказ ставится мимо очереди, а текст у него один
        // на любой запрос. Второй ввод без этой чистки отвечает молчанием —
        // а это **живой шаг 10** прогона возврата без чека.
        _emit(state.copyWith(clearError: true));
        _emit(
          state.copyWith(
            isSearching: false,
            error: 'error.refund_search_unavailable',
          ),
        );
        return;
      }
      try {
        final found = await GetIt.I<CartService>().search(query);
        final results = found
            .map(
              (r) => RefundSearchResult(
                id: r.id,
                name: r.name,
                price: r.price,
                barcode: r.barcode,
              ),
            )
            .toList();

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

  /// Кладёт товар в возврат без чека по каталожной цене.
  ///
  /// Складывать с уже лежащей строкой здесь больше нечего: сведение строк —
  /// правило кассы (`LocalCartService._mergeTarget`, то же в возврате), и
  /// повторять его на экране значило бы завести второе мнение о цене.
  Future<void> addProduct(
    RefundSearchResult product, {
    Decimal? quantity,
  }) async {
    await _command(
      (terminalId, meta) => _refunds.addProduct(
        terminalId,
        product.id,
        quantity ?? Decimal.one,
        meta,
      ),
    );
    _emit(state.copyWith(searchQuery: '', searchResults: []));
  }

  void selectItem(String? itemId) {
    _emit(
      state.copyWith(
        selectedItemId: itemId,
        clearSelectedItemId: itemId == null,
      ),
    );
  }

  /// Снять или вернуть строку — команда кассе, а не галочка на экране.
  Future<void> toggleItemSelection(String itemId) async {
    RefundItem? current;
    for (final item in state.items) {
      if (item.id == itemId) {
        current = item;
        break;
      }
    }
    if (current == null) return;

    if (current.isSelected) {
      await _setLine(itemId, Decimal.zero);
      return;
    }

    // Вернуть снятую строку. В возврате **по чеку** касса помнит, что чек
    // позволяет вернуть, и берёт строку оттуда. В возврате **без чека**
    // такой памяти нет — там `setLineQuantity` ответит «нет такой строки», и
    // товар кладётся заново (докстринг `RefundService.setLineQuantity`,
    // «обратный ход работает только в возврате по чеку»).
    if (state.receiptInfo == null) {
      final product = current.productId;
      final quantity = current.quantity;
      await _command(
        (terminalId, meta) =>
            _refunds.addProduct(terminalId, product, quantity, meta),
      );
      return;
    }
    await _setLine(itemId, current.quantity);
  }

  /// Выделить всё — построчно.
  ///
  /// Пакетной операции у контракта нет, и заведена она не была осознанно
  /// (докстринг `RefundOps.setLine`): её цена меряется на проводе, а до
  /// задачи 20 возврат по проводу никто не звал. Здесь она наконец
  /// зовётся — и если чек в тридцать строк окажется медленным, это и есть
  /// то измерение, ради которого операцию отложили.
  Future<void> selectAll() async {
    for (final item in state.items.where((i) => !i.isSelected).toList()) {
      await toggleItemSelection(item.id);
    }
  }

  Future<void> deselectAll() async {
    for (final item in state.items.where((i) => i.isSelected).toList()) {
      await _setLine(item.id, Decimal.zero);
    }
  }

  /// Ставит строке количество.
  ///
  /// Больше проданного касса не примет и **скажет об этом**. Прежний код
  /// молча срезал введённое до `maxQuantity`: на экране это было почти
  /// незаметно, а по проводу молчаливая правка неотличима от успеха.
  Future<void> updateQuantity(String itemId, Decimal quantity) =>
      _setLine(itemId, quantity, forget: quantity <= Decimal.zero);

  /// Ставит строке количество и, если строку убирают **насовсем**, забывает
  /// её.
  ///
  /// Кассе обе формы выглядят одинаково — `setLineQuantity(id, 0)`, строка
  /// уходит из черновика. Разница целиком экранная и существенная: снятое
  /// выделение обязано остаться видимым, иначе вернуть его нечем, а
  /// удалённая строка обязана исчезнуть, иначе кнопка «убрать» ничего не
  /// убирает.
  Future<bool> _setLine(
    String itemId,
    Decimal quantity, {
    bool forget = false,
  }) async {
    final applied = await _command(
      (terminalId, meta) =>
          _refunds.setLineQuantity(terminalId, itemId, quantity, meta),
    );
    if (applied && forget) {
      _known.remove(itemId);
      _emit(
        state.copyWith(
          items: state.items.where((i) => i.id != itemId).toList(),
          clearSelectedItemId: state.selectedItemId == itemId,
        ),
      );
    }
    return applied;
  }

  void setReason(String itemId, RefundReason reason) {
    final index = state.items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;

    final updated = state.items[index].copyWith(reason: reason);
    _known[itemId] = updated;
    final newItems = [...state.items];
    newItems[index] = updated;
    _emit(state.copyWith(items: newItems));
  }

  Future<void> removeItem(String itemId) =>
      _setLine(itemId, Decimal.zero, forget: true);

  Future<void> removeSelectedItem() async {
    final id = state.selectedItemId;
    if (id == null) return;
    await removeItem(id);
  }

  /// Забыть возврат на экране.
  ///
  /// Зовётся после успешного завершения, когда касса черновик уже очистила
  /// сама (`RefundService.complete`). Своей команды «очистить черновик» у
  /// контракта нет, и выдумывать её здесь нечем: одна строка снимается
  /// [removeItem].
  void clear() {
    _searchDebounce?.cancel();
    _known.clear();
    _knownDraftNo = null;
    _emit(RefundState(mode: state.mode, posId: state.posId));
  }

  /// Завершает возврат: деньги покупателю, товар на остаток, чек — кассой.
  ///
  /// Сверять здесь нечего: черновик кассы **и есть** выделенное — снятие
  /// выделения уехало командой в момент нажатия, а не копится до этой
  /// минуты. Именно поэтому касса знает итог выделения до того, как отдаёт
  /// деньги, и «что показано» не расходится с «что вернули».
  /// Возврат, проведённый последним, и рабочее место, которое его провело, —
  /// чтобы спросить у кассы беды железа ([hardwareTroubles]).
  int? _lastRefundLocalId;
  int? _lastTerminalId;

  /// Беды железа последнего проведённого возврата — пока это ящик.
  ///
  /// Приёмка 2026-09-17: касса открывает ящик после возврата с наличной
  /// частью и называет беду, если ящик не открылся
  /// (`RefundService.hardwareTroubles`), — но экран её не спрашивал, и беда
  /// жила только в журнале кассы. Тот же приём, что у оплаты
  /// (`PaymentNotifier.hardwareTroubles`): спрашивать **после** успеха, тем
  /// же рабочим местом, каким проводили; чтение разрушающее.
  Future<List<CompletionTrouble>> hardwareTroubles() async {
    final refundLocalId = _lastRefundLocalId;
    final terminalId = _lastTerminalId;
    if (refundLocalId == null || terminalId == null) return const [];
    return _refunds.hardwareTroubles(terminalId, refundLocalId);
  }

  Future<bool> processRefund() async {
    // **Третий путь к молчанию, найденный разбором круга.** Это был
    // единственный выход всего пути подтверждения, не производивший
    // **ничего**: ни команды, ни успеха, ни отказа, ни строки в журнале.
    //
    // И он достижим не только «кассир снял всё сам»: `canRefund` требует
    // выделенного, а снимки приходят подпиской **пока диалог открыт** —
    // касса забыла черновик (вход другого кассира), вторая вкладка, второе
    // рабочее место. К моменту «Подтвердить» выделенного может не быть, и
    // тогда кассир видел закрывшийся диалог и больше ничего. Ровно картина
    // живого прогона на шаге 9.
    //
    // Молчать здесь нельзя: человек нажал кнопку денег.
    if (!state.canRefund) {
      // **Две строки, а не одна, и это измерено.** Отказ ставится здесь
      // напрямую, мимо `_enqueue`, — то есть мимо чистки, которая делает
      // повторный отказ видимым. Без первой строки два подтверждения подряд
      // дают дословно один текст, экран молчит на втором (`next ==
      // previous`), и починка «кнопка не молчит» воспроизводит ровно тот
      // дефект, ради которого затевалась.
      //
      // Одним вызовом не выйдет: признак `clearError` в `copyWith` бьёт по
      // полю ошибки и погасил бы отказ, который ставится тем же вызовом.
      _emit(state.copyWith(clearError: true));
      _emit(
        state.copyWith(
          isLoading: false,
          error: 'error.refund_nothing_selected',
        ),
      );
      return false;
    }

    _emit(state.copyWith(isLoading: true, clearError: true));

    final done = await _enqueue(() async {
      final terminalId = await _resolveTerminalId();
      if (terminalId == null) {
        throw const WireRefusal('till_not_configured', 'касса не настроена');
      }
      final outcome = await _refunds.complete(terminalId, _meta());
      _lastRefundLocalId = outcome.refundLocalId;
      _lastTerminalId = terminalId;
      // Соседние экраны узнают о деньгах **числом**, а не по имени своих
      // провайдеров: `ref.invalidate(shiftControllerProvider)` — это импорт
      // экрана смены, а он тянет базу и через неё `dart:ffi`, которого в
      // браузере нет. Измерено сборкой веба, докстринг
      // `MoneyLedgerRevision`.
      ref.read(moneyLedgerRevisionProvider.notifier).bump();
    });

    _emit(state.copyWith(isLoading: false));
    return done;
  }
}

final refundControllerProvider = NotifierProvider<RefundNotifier, RefundState>(
  RefundNotifier.new,
);

final refundSelectedTotalProvider = Provider<Decimal>((ref) {
  return ref.watch(refundControllerProvider.select((s) => s.selectedTotal));
});

final canRefundProvider = Provider<bool>((ref) {
  return ref.watch(refundControllerProvider.select((s) => s.canRefund));
});
