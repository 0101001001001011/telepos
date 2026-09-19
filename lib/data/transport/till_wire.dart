/// Кассовая половина провода: кадры на входе, те же обработчики на выходе.
///
/// # Что здесь есть и чего здесь нет
///
/// Здесь нет ни одного обращения к базе, репозиторию или железу — и это
/// главное свойство файла. `TillWire` получает готовую карту обработчиков и
/// умеет ровно три вещи: разобрать кадр, найти обработчика по имени операции и
/// написать ответ в тот поток, из которого пришёл вопрос. Кто такой
/// «обработчик», решает `lib/backend/till_operations.dart` — там же, где эти
/// зависимости уже собраны, и оттуда же они берутся сюда. Второй реализации
/// бизнес-логики не заводится: до 2026-08-05 второй была четырнадцать
/// маршрутов `/api/*`, и они сняты именно поэтому.
///
/// # Ответ уходит в поток, а не по идентификатору
///
/// Соответствие ответа вопросу даёт сам двунаправленный поток — отвечать
/// некуда, кроме как в него. Поэтому книги учёта идентификаторов нет: её нечем
/// было бы проверить, и она была бы ещё одним местом, где два конца расходятся
/// молча.
///
/// # `StreamClosed` — не отписка, и читать его так нельзя
///
/// Касса читает сообщение до конца, прежде чем оно станет событием (иначе
/// половина сообщения выглядела бы как целое). Значит запрос она видит только
/// после того, как терминал закрыл свою половину отправки, — и `streamClosed`
/// приходит **сразу за запросом**, одинаково для одноразового вопроса и для
/// часовой подписки. Снимать по нему подписку значило бы снимать её немедленно
/// после создания. Как узнаётся настоящий уход — см. [TillSubscriptions].
///
/// # Молчания не бывает
///
/// На любой вход — ответ. Неизвестная операция, нечитаемый кадр, упавший
/// обработчик: везде уходит [ErrorFrame] с названным кодом, и поток
/// закрывается. Молчащий поток неотличим от зависшей кассы, и терминал будет
/// ждать ответа, которого не будет, до предела простоя сессии (И153).
library;

import 'dart:async';

import 'package:rk_quic/rk_quic.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/transport/till_subscriptions.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Одноразовый вопрос: тело запроса на входе, тело ответа на выходе.
///
/// Бросить исключение обработчику не запрещено — оно станет [ErrorFrame] с
/// кодом `handler_failed`. Запрещено ронять кассу: касса, упавшая на запросе
/// терминала, не может принять деньги (И144).
///
/// # Почему один довод, а не два
///
/// Задача 9 закрытия долга ненадолго провела сюда второй, необязательный
/// довод — сеанс вызывающей вкладки, — потому что `terminals.delete` сверял
/// `terminalId` из тела с `session.terminalId` сам, обработчиком. Задача 10
/// забрала эту сверку в сторож целиком: `WireGuard.check` теперь получает
/// тело запроса (`SessionAccess.ownTerminal`, `wire_access.dart`) и решает
/// вопрос владения терминалом раньше, чем вызовет хоть один обработчик — как
/// и всё остальное, что решает [WireVerdict]. Обработчику после этого
/// сверять уже нечего, и второй довод снят: непрочитанный параметр —
/// это шов, который через месяц прочитают как разрешение проверять владение
/// где попало, а единственный прежний читатель проверял ровно то же самое,
/// что теперь делает сторож, и ничего сверх.
///
/// # Второй, необязательный [sessionId] — пункт 2 фазы 3/4 закрытия долга
///
/// Не то же самое, что сеанс выше: это идентификатор QUIC-сессии, который
/// есть у любого запроса, даже у `OpenAccess`-операций без токена вовсе —
/// `auth.login`, `terminals.register`, `terminals.selfEnsure`. **Не сырой**
/// с правки 3 волны закрытия долга безопасности (2026-08-22) — то, что
/// приходит от `_server`, проходит через [_sessionKey] прежде, чем попасть
/// сюда: см. докстринг [listenerId] про то, почему сырого недостаточно
/// (`loopback` — два листенера с независимыми счётчиками `sessionId`).
/// Заведён затем, что до этой правки касса верила `terminalId` из тела
/// `auth.login` как есть: кассир с собственным действительным PIN мог
/// назваться чужим терминалом, просто подставив его id в кадр — терминал
/// никогда его не регистрировал и не подтверждал. Три обработчика
/// (`terminals.register`, `terminals.selfEnsure`, `auth.login`,
/// `till_operations.dart`) читают этот довод: первые два запоминают, какая
/// сессия какой терминал завела, третий берёт `terminalId` оттуда, а не из
/// тела. Остальные его игнорируют — `[_]` в их сигнатурах, не второй
/// обязательный параметр: 21 операция не обязана знать про сессию только
/// потому, что трём она нужна.
///
/// # Третий, необязательный [session] — круг правки 2 задачи 10
///
/// Тот самый сеанс, который уже нашёл сторож ([WireAllowed.session]): не
/// второй поиск, а передача найденного. Задача 10 закрытия долга сняла этот
/// довод отсюда с прямым доводом — «непрочитанный параметр это шов, который
/// через месяц прочитают как разрешение проверять владение где попало», — и
/// довод был верен: единственный тогдашний читатель проверял ровно то, что
/// теперь делает сторож.
///
/// Вернулся он с читателем, которого сторож обслужить **не может**:
/// `sale.loadDeferred` требует права правки цены, **если поднимаемый чек
/// оптовый**. Право здесь зависит от состояния чека в базе, а не от кадра;
/// сторож живёт в `lib/domain/` и содержимого чека не видит ни в каком
/// виде. Это ровно тот случай, для которого исключение и оговаривалось.
///
/// Правило прежнее и не ослаблено: **всё, что решается по кадру и сеансу,
/// решает сторож.** Обработчику этот довод дан не для того, чтобы завести
/// вторую проверку прав рядом с первой, а для тех решений, которые зависят
/// от данных кассы.
typedef WireHandler =
    Future<Map<String, Object?>> Function(
      Map<String, Object?> body, [
      int? sessionId,
      AuthSession? session,
    ]);

/// Подписка: первое значение — текущее, дальнейшие — изменения.
///
/// Поток живёт, пока жив подписчик. Кончившийся источник закрывает обмен, но
/// [DoneFrame] не шлёт: подписка не «завершается успехом», ей просто больше
/// нечего сказать, и это другое событие, чем законченная работа.
///
/// # Второй, необязательный [sessionId] — задачи 10 и 19 плана «Продажа с
/// браузерного терминала»
///
/// Тот же довод, того же вида и с тем же значением, что у [WireHandler]
/// выше: составной ключ сессии ([_sessionKey]), а не сырой. Спрашивают его
/// **две** подписки, и пришли они с разных ветвей — `sale.cart` (задача
/// 10) и `refund.view` (задача 19); прочие его игнорируют (`[_]` в
/// сигнатурах) тем же приёмом и по той же причине, что и у [WireHandler]:
/// остальные не обязаны знать про сессию потому, что она нужна двум.
///
/// **Довод у обеих один и тот же, и он контрактный.** Контракт корзины
/// (`lib/domain/sale/cart_service.dart`, правило 1) и контракт возврата
/// (`RefundService`, правило 1) требуют брать имя рабочего места из сеанса
/// и **отвергать** кадр, в котором оно названо телом. До этой пары правок
/// у подписок не было ни одного способа узнать сессию — то есть
/// единственным доступным источником имени было бы тело, ровно то, что оба
/// контракта запрещают. Готовый механизм владения
/// (`SessionAccess.ownTerminal`) здесь не подходит: он это имя в теле,
/// наоборот, **требует**, и с контрактами несовместим.
///
/// **Дельты безопасности у этого выбора не измерено, и приписывать её ему
/// не надо** (круг правки 1 задачи 19). `ownTerminal` пускает не только
/// терминал сеанса, но и терминал самой кассы (регрессия фазы 3/4,
/// [WireGuard.check]), а `terminals.selfEnsure` тогда ещё и привязывал эту
/// строку к любой сессии без кода привязки и без секрета — так что «две
/// вкладки делили бы один черновик» воспроизводилось и **с** механизмом
/// владения. Сам чёрный ход круг правки 4 закрыл (`selfEnsure` места не
/// привязывает, разбор — `till_operations.dart`), но контрактный довод от
/// этого не изменился, а приписанной дельты у него так и не появилось.
/// # Третий, необязательный [session] — задача 10 ревизии 2026-09-19
///
/// Тот же довод, того же вида и с тем же значением, что третий у
/// [WireHandler]: сеанс, найденный **сторожем**, а не тело кадра. Спрашивает
/// его одна подписка — `sale.deferredList`, — и по той же причине, по какой
/// его спрашивают команды уступки: контракт корзины требует полномочия
/// **доводом** (`CartService.watchDeferred`, задача 10 ревизии), а построить
/// их можно только из сеанса. Прочие игнорируют его `[_]` тем же приёмом.
///
/// **Это не вторая проверка права рядом с первой.** Право `op.deferSale`
/// сторож проверяет раньше и по своему словарю; довод нужен затем, чтобы
/// **касса**, у которой сторожа нет вовсе, получала ту же проверку в том же
/// месте — в корзине. Свойство провода от этого не меняется: полномочия
/// строятся из сеанса, выписанного кассой, и никогда из тела кадра.
typedef WireWatchHandler =
    Stream<Map<String, Object?>> Function(
      Map<String, Object?> body, [
      int? sessionId,
      AuthSession? session,
    ]);

/// Длинная работа: [ProgressFrame] столько раз, сколько есть что сказать, и
/// один [DoneFrame] в конце.
///
/// Отдаёт кадры, а не тела, потому что род кадра здесь несёт смысл: «идёт» и
/// «кончилось» — разные вещи, и решает это работа, а не транспорт. Оборванная
/// работа [DoneFrame] не шлёт вовсе — см. [TillWire._runWork].
typedef WireRunHandler = Stream<WireFrame> Function(Map<String, Object?> body);

class TillWire {
  TillWire(
    this._server,
    Map<String, WireHandler> handlers, {
    Map<String, WireWatchHandler> watchHandlers = const {},
    Map<String, WireRunHandler> runHandlers = const {},
    required WireGuard guard,
    TillSubscriptions? subscriptions,
    this.onSessionClosed,
    this.onDenied,
    this.listenerId = 0,
  }) : _handlers = handlers,
       _watchHandlers = watchHandlers,
       _runHandlers = runHandlers,
       _guard = guard,
       _subscriptions = subscriptions ?? TillSubscriptions() {
    // Одно имя в двух картах — молчаливая подмена рода обмена: терминал ждал
    // подписку, а получил один ответ и закрытый поток. Ловится здесь, потому
    // что в поле это выглядит как «экран перестал обновляться», и искать будут
    // не в разборе имён.
    assert(() {
      final names = <String>[
        ..._handlers.keys,
        ..._watchHandlers.keys,
        ..._runHandlers.keys,
      ];
      return names.toSet().length == names.length;
    }(), 'имя операции объявлено в двух картах сразу');
  }

  final QuicServer _server;
  final Map<String, WireHandler> _handlers;
  final Map<String, WireWatchHandler> _watchHandlers;
  final Map<String, WireRunHandler> _runHandlers;
  final WireGuard _guard;
  final TillSubscriptions _subscriptions;

  /// Который слушатель этой кассы держит этот `TillWire` — правка 3 волны
  /// закрытия долга безопасности (2026-08-22).
  ///
  /// `everywhere` — один сокет, один `TillWire`, `listenerId` остаётся 0 и
  /// ничего не меняет: `_sessionKey` ниже с нулём — тождество. `loopback` —
  /// два сокета (`main.dart`, петля по `webTransport.servers`), у каждого
  /// свой `TillWire`, и здесь имеет значение: `rk_quic` заводит `sessionId`
  /// независимым счётчиком **на каждый листенер**
  /// (`packages/rk_quic/rust/src/transport.rs`, `next_session` —
  /// `AtomicU64::new(1)` внутри функции подъёма, не статика процесса), так
  /// что `sessionId=1` существует на обоих одновременно и сам по себе не
  /// отличает вкладку на одном слушателе от вкладки на другом.
  ///
  /// Обработчики (`WireHandler`'s `sessionId`, `onSessionClosed`) видят не
  /// сырой `sessionId`, а результат [_sessionKey] — уникальный на кассу, а
  /// не на слушателя. Это и требовалось: `TillOperations._sessionTerminals`
  /// — одна карта на все листенеры разом (`TillOperations`, как и вся
  /// касса, — один объект на развёртывание, `main.dart`), а не по одной на
  /// каждый.
  ///
  /// Решено на стороне кассы, не в `rk_quic`: пакет ничего не знает, сколько
  /// листенеров подняла касса и как они между собой соотносятся — это факт
  /// того, кто их поднимал (`startWebTransport`, `webtransport_endpoint.dart`),
  /// а не факт одного сокета. Здесь он уже известен (`main.dart` знает индекс
  /// в цикле по `webTransport.servers`) и стоит одной строки; в `rk_quic`
  /// пришлось бы либо заводить статический счётчик на процесс (сломал бы
  /// независимость тестов, поднимающих по несколько эндпоинтов подряд в
  /// одном прогоне — `dual_stack.rs` уже это делает), либо протаскивать номер
  /// листенера через FFI-границу третьим числом там, где сегодня два.
  final int listenerId;

  /// Отдаёт `sessionId`, уникальный на кассу, а не на слушателя, которому он
  /// сырым достался от `rk_quic`. См. докстринг [listenerId].
  ///
  /// Сдвиг на 40 бит, не конкатенация строкой: `sessionId` — `u64` в Rust,
  /// `int` в Dart — 64-битный, с запасом на знак. Счётчик листенера начинает
  /// с 1 и растёт на каждое новое соединение; 2^40 (более триллиона) сессий
  /// на одном листенере кассе не грозит никогда, а `listenerId` в проде — 0
  /// или 1 (`loopback` — ровно два сокета, `quicAddressesFor`,
  /// `webtransport_endpoint.dart`), так что до переполнения обоих полей друг
  /// в друга дистанция astronomical.
  ///
  /// Не трогает то, чем `TillWire` отвечает и закрывает поток
  /// (`_server.sendOn`/`_server.closeStream` ниже) — тем нужен настоящий,
  /// сырой `sessionId`, который понимает конкретный `_server` этого
  /// слушателя, а не составной ключ, которого `rk_quic` никогда не видел.
  int _sessionKey(int rawSessionId) =>
      listenerId == 0 ? rawSessionId : (listenerId << 40) | rawSessionId;

  /// Сессия ушла — QUIC сказал `SessionClosed`. Пункт 2 фазы 3/4 закрытия
  /// долга: `TillOperations` держит карту «какая сессия какой терминал
  /// завела» ([WireHandler]'s `sessionId`) и обязана забыть запись, когда
  /// сессия закрылась — иначе карта растёт без предела на весь срок жизни
  /// кассы, тем же пороком, что уже чинили `SessionRegistry._forget()` и
  /// `LoginThrottle._forget()`. `TillWire` не знает, что делает с этим её
  /// вызывающий — только зовёт, если он вообще задан.
  final void Function(int sessionId)? onSessionClosed;

  /// Сторож отказал — задача 21 закрытия долга безопасности (журнал событий
  /// безопасности).
  ///
  /// `void`, не `Future<void>`, тем же приёмом, что и [onSessionClosed]:
  /// `TillWire` не ждёт запись в журнал и не даёт ей задержать ответ
  /// терминалу или уронить `_onRequest` — вызывающий (`main.dart`, через
  /// `buildWireDeniedJournalHandler`, `lib/backend/security_journal.dart`)
  /// сам отвечает за то, чтобы его собственная асинхронная работа не текла
  /// наружу исключением. `sessionKey` — уже [_sessionKey], тот же составной
  /// ключ, что видят обработчики и [onSessionClosed], не сырой `sessionId`.
  final void Function(
    String op,
    WireDenied denied,
    int sessionKey,
    Map<String, Object?> body,
  )?
  onDenied;

  StreamSubscription<QuicEvent>? _events;

  /// Длинные работы, идущие прямо сейчас.
  ///
  /// Держатся отдельно от подписок намеренно, и это не оформление. Подписка
  /// снимается, когда подписчик ушёл, — она ему и принадлежала. Восстановление
  /// из копии принадлежит кассе: прервать его на середине значило бы оставить
  /// магазин наполовину восстановленным ради того, чтобы не писать в поток,
  /// которого больше нет. Поэтому здесь их держат только затем, чтобы
  /// остановить всё разом в [stop], когда останавливается сама касса.
  final Set<StreamSubscription<WireFrame>> _runs = {};

  /// Сколько подписок живо. Наблюдаемая величина: подписки, живущие дольше
  /// экранов, которые их завели, — именно тот отказ, который иначе не видно.
  int get liveSubscriptions => _subscriptions.live;

  void start() {
    _events ??= _server.events.listen(_onEvent);
  }

  Future<void> stop() async {
    await _events?.cancel();
    _events = null;
    await _subscriptions.removeAll();
    final runs = _runs.toList();
    _runs.clear();
    for (final run in runs) {
      await run.cancel();
    }
  }

  void _onEvent(QuicEvent event) {
    switch (event) {
      case StreamData(:final sessionId, :final streamId, :final message):
        // Не `await`: каждый обмен идёт своим чередом, и медленный обработчик
        // одного экрана не имеет права задерживать вопросы остальных.
        unawaited(_onRequest(sessionId, streamId, message));
      case SessionClosed(:final sessionId):
        // Вкладку закрыли, крышку опустили, сеть пропала. Единственное
        // событие, по которому уход терминала виден без попытки записи.
        //
        // `_subscriptions` — сырой `sessionId`: она принадлежит этому
        // `TillWire`, то есть этому листенеру, и коллизии с другим
        // слушателем у неё нет структурно. `onSessionClosed` — составной
        // ключ [_sessionKey]: он уходит в `TillOperations`, общую на все
        // листенеры разом (правка 3 волны закрытия долга безопасности,
        // 2026-08-22, докстринг [listenerId]).
        unawaited(_subscriptions.removeSession(sessionId));
        onSessionClosed?.call(_sessionKey(sessionId));
      case StreamOpened():
      case StreamClosed():
        // Открытие потока — ещё не вопрос; закрытие приходит сразу за вопросом
        // и об уходе терминала не говорит. Отвечать нечем и незачем.
        break;
      default:
        break;
    }
  }

  Future<void> _onRequest(int sessionId, int streamId, String message) async {
    final frame = WireFrame.decode(message);
    if (frame is! RequestFrame) {
      // `decode` не бросает и уже назвал причину, если кадр нечитаем. Если же
      // он читаем, но запросом не является, причину называем здесь: принять
      // такое молча значило бы оставить поток открытым навсегда.
      await _refuse(
        sessionId,
        streamId,
        frame is ErrorFrame
            ? frame
            : const ErrorFrame('not_a_request', 'кадр не является запросом'),
      );
      return;
    }

    // Единственная точка проверки на весь провод. Стоит до выбора рода
    // обмена, поэтому накрывает `Ask`, `Watch` и `Run` разом; проверка внутри
    // каждой карты дала бы двадцать одно место, где можно забыть.
    final WireVerdict verdict;
    try {
      verdict = await _guard.check(
        frame.op,
        frame.body,
        frame.token,
        // Составной ключ ([_sessionKey]) — тот же, которым эта сессия
        // называется обработчикам и `onSessionClosed`: сторож сверяет по
        // нему место сеанса с местом, привязанным к сессии сейчас
        // (`WireGuard._boundTerminalId`).
        sessionKey: _sessionKey(sessionId),
      );
    } on Object catch (error) {
      // Сторож не имеет права промолчать: упавшая проверка (например, база
      // настройки закрыта или заперта — `isTillConfigured` читает её) не
      // повод пустить запрос. Отказывать надо закрыто, а не открыто, и,
      // как у соседних отказов, значением, а не тишиной: молчащий поток
      // неотличим от зависшей кассы (шапка файла, «Молчания не бывает»).
      //
      // Пункт 7 брифа закрытия долга безопасности (2026-08-22): до этой
      // правки именно эта ветка не звала [onDenied] вовсе — «сторож упал —
      // отказ есть, записи нет», дыра в той же функции, что и обычный
      // `WireDenied` чуть ниже. `WireDenied('guard_failed', …)` собирается
      // здесь же, синтетически: сторож не вернул `WireDenied`, он бросил
      // исключение, но у журнала нет причины различать «сторож отказал
      // значением» от «сторож упал, не решив вовсе» — оба не пускают
      // запрос, и оба должны быть видны. `session: null` — на этом пути
      // сторож не успел найти сеанс (упал до или во время `check`), угадать
      // его нечем.
      onDenied?.call(
        frame.op,
        WireDenied('guard_failed', safeErrorText(error)),
        _sessionKey(sessionId),
        frame.body,
      );
      await _refuse(
        sessionId,
        streamId,
        ErrorFrame('guard_failed', safeErrorText(error)),
      );
      return;
    }
    if (verdict is WireDenied) {
      // Код называет сторож (`WireGuard.check`, `wire_guard.dart`) — он же
      // решает, какая из четырёх причин отказа сейчас сработала. Кассир,
      // которому не хватает права, не лечится входом заново, и слать ему тот
      // же код, что истёкшему сеансу, значило бы отправить его в круг «войди
      // — получи тот же отказ — войди снова».
      //
      // Задача 21 закрытия долга безопасности: до неё этот путь не звал ни
      // одного обращения к журналу событий безопасности вовсе (бриф задачи
      // 21, «сегодня отказ сторожа не логируется никуда»). [onDenied] —
      // единственная точка, из которой это теперь видно.
      onDenied?.call(frame.op, verdict, _sessionKey(sessionId), frame.body);
      await _refuse(
        sessionId,
        streamId,
        ErrorFrame(verdict.code, '${frame.op}: ${verdict.reason}'),
      );
      return;
    }

    final ask = _handlers[frame.op];
    if (ask != null) {
      // `verdict` — `WireAllowed` здесь наверняка: `WireDenied` уже вернул
      // раньше, а всё, что сторож решает **по кадру и сеансу** (включая
      // владение терминалом), решено до этой строки.
      //
      // Сеанс тем не менее передаётся третьим доводом, и это не шов: с круга
      // правки 2 задачи 10 у него есть читатель, которого сторож обслужить не
      // может — `sale.loadDeferred` требует права правки цены, **если
      // поднимаемый чек оптовый**, а это состояние базы кассы, а не кадра. См.
      // докстринг [WireHandler], раздел «Третий, необязательный [session]».
      // Прежняя редакция этой строки («обработчику передавать нечего сверх
      // `sessionId`») осталась от задачи 10 закрытия долга и утверждала о
      // механизме то, чего в нём уже не было.
      await _answer(
        sessionId,
        streamId,
        ask,
        frame.body,
        verdict is WireAllowed ? verdict.session : null,
      );
      return;
    }

    final watch = _watchHandlers[frame.op];
    if (watch != null) {
      // Сеанс передаётся тем же выражением и по тому же доводу, что в ветке
      // вопроса выше: `WireDenied` уже вернул раньше, значит здесь он
      // `WireAllowed` наверняка, а читатель у сеанса есть —
      // `sale.deferredList` строит из него полномочия для корзины (докстринг
      // [WireWatchHandler]).
      _subscribe(
        sessionId,
        streamId,
        watch,
        frame.body,
        verdict is WireAllowed ? verdict.session : null,
      );
      return;
    }

    final run = _runHandlers[frame.op];
    if (run != null) {
      _runWork(sessionId, streamId, run, frame.body);
      return;
    }

    // При нынешней сборке сторож отвечает первым: словарь доступа строится
    // из того же `TillOps.all`, что и карты обработчиков, и имя, которого нет
    // в словаре, получает `unknown_op` ещё в `_guard.check`
    // (`WireDenied.unknownOp`, `wire_guard.dart`) — сюда оно не доходит.
    // Ветка остаётся страховкой на случай, если словарь доступа и карты
    // обработчиков разойдутся: операция объявлена (сторож её пропустил), а
    // обработчика для неё нет. Тот же код здесь и там — расхождение каталога
    // и обработчиков не про сеанс ни в одном из двух мест. Имя операции едет
    // в отказе: без него в логе останется «что-то не нашлось», и искать будут
    // наугад.
    await _refuse(
      sessionId,
      streamId,
      ErrorFrame(
        'unknown_op',
        'операция не объявлена на этой кассе: ${frame.op}',
      ),
    );
  }

  Future<void> _answer(
    int sessionId,
    int streamId,
    WireHandler handler,
    Map<String, Object?> body,
    AuthSession? session,
  ) async {
    WireFrame reply;
    try {
      // Составной ключ ([_sessionKey]), не сырой `sessionId` — обработчику
      // передаётся то же, чем `onSessionClosed` называет ту же сессию (см.
      // `_onEvent`), иначе запись, заведённая на входе, не нашлась бы на
      // выходе (правка 3 волны закрытия долга безопасности, 2026-08-22).
      reply = OkFrame(await handler(body, _sessionKey(sessionId), session));
    } on WireRefusal catch (refusal) {
      // Отказ, который написал сам обработчик, — его текст безопасен по
      // построению (см. `WireRefusal`), поэтому едет как есть, без
      // `safeErrorText`: чистить тут нечего, а код называет причину точнее,
      // чем общий `handler_failed`.
      reply = ErrorFrame(refusal.code, refusal.message);
    } on Object catch (error) {
      // `on Object`, а не `on Exception`: `TypeError` из разбора чужого тела —
      // тоже отказ, и он обязан доехать значением. Своей причины падать от
      // вопроса терминала у кассы нет ни одной.
      reply = ErrorFrame('handler_failed', safeErrorText(error));
    }
    await _send(sessionId, streamId, reply);
    await _server.closeStream(sessionId, streamId);
  }

  void _subscribe(
    int sessionId,
    int streamId,
    WireWatchHandler handler,
    Map<String, Object?> body,
    AuthSession? session,
  ) {
    final Stream<Map<String, Object?>> source;
    try {
      // Составной ключ ([_sessionKey]), не сырой `sessionId` — ровно тем же
      // выражением и по той же причине, что в [_answer]: обработчику
      // передаётся то же, чем `onSessionClosed` называет ту же сессию, и
      // подписка ищет рабочее место в той же карте `TillOperations`,
      // которую заполнил `terminals.register` на входе. Она общая на все
      // листенеры, и сырым ключом запись, заведённая регистрацией, не
      // нашлась бы.
      source = handler(body, _sessionKey(sessionId), session);
    } on WireRefusal catch (refusal) {
      unawaited(
        _refuse(sessionId, streamId, ErrorFrame(refusal.code, refusal.message)),
      );
      return;
    } on Object catch (error) {
      // Подписка, которую не удалось даже завести, обязана назвать причину:
      // молча оставленный открытым поток выглядит как подписка без событий.
      unawaited(
        _refuse(
          sessionId,
          streamId,
          ErrorFrame('handler_failed', safeErrorText(error)),
        ),
      );
      return;
    }

    late final StreamSubscription<Map<String, Object?>> subscription;
    subscription = source.listen(
      (value) {
        // `pause` с будущим вместо голого `unawaited`: порядок обновлений
        // обязан совпадать с порядком событий, иначе экран покажет
        // предпоследнее состояние как последнее. Источник придерживается,
        // пока запись не легла.
        subscription.pause(
          _subscriptions.deliver(
            _server,
            sessionId: sessionId,
            streamId: streamId,
            frame: UpdateFrame(value),
          ),
        );
      },
      onError: (Object error) {
        // Отказ источника — не отказ подписчика: он обязан узнать причину, а
        // не просто перестать получать обновления. `WireRefusal` — та же
        // логика, что в _answer/_subscribe выше: текст безопасен по
        // построению, и его код точнее общего `handler_failed`.
        final frame = error is WireRefusal
            ? ErrorFrame(error.code, error.message)
            : ErrorFrame('handler_failed', safeErrorText(error));
        unawaited(
          _subscriptions
              .removeStream(sessionId, streamId)
              .then(
                (_) => _send(
                  sessionId,
                  streamId,
                  frame,
                ).then((_) => _server.closeStream(sessionId, streamId)),
              ),
        );
      },
      onDone: () {
        // Источник кончился сам — обновлений больше не будет, и держать поток
        // открытым значит заставить терминал ждать до предела простоя.
        //
        // **Кадр `done` перед закрытием — не украшение.** Живая приёмка
        // 2026-09-19 нашла, что без него планшет читал законный конец
        // подписки как обрыв: вкладки ящика и весов показывали «касса не
        // ответила: stream_ended» вместо названного состояния «прибора на
        // этой кассе нет». Касса отдаёт такому вопросу одно значение и
        // закрывает поток намеренно (И144, докстринг
        // `LocalHardwareDiagnostics.watchDrawer`), а у браузерной половины
        // тихое закрытие и оборванная сессия выглядели одинаково.
        //
        // Различать их обязана **касса**: только она знает, кончился
        // источник сам или порвалась связь. Отсюда кадр: `done` — «это
        // окончательное состояние», молчание — по-прежнему обрыв.
        unawaited(
          _subscriptions
              .removeStream(sessionId, streamId)
              .then(
                (_) => _send(
                  sessionId,
                  streamId,
                  const DoneFrame({}),
                ).then((_) => _server.closeStream(sessionId, streamId)),
              ),
        );
      },
      // Та же причина, что у длинной работы: `onDone` после `onError` закрыл
      // бы поток второй раз.
      cancelOnError: true,
    );
    _subscriptions.add(sessionId, streamId, subscription);
  }

  void _runWork(
    int sessionId,
    int streamId,
    WireRunHandler handler,
    Map<String, Object?> body,
  ) {
    final Stream<WireFrame> source;
    try {
      source = handler(body);
    } on WireRefusal catch (refusal) {
      unawaited(
        _refuse(sessionId, streamId, ErrorFrame(refusal.code, refusal.message)),
      );
      return;
    } on Object catch (error) {
      // Работа, не начавшаяся вовсе (копии с таким идентификатором нет),
      // обязана назвать причину: молчание оставит терминал с крутящейся
      // полосой до предела простоя сессии.
      unawaited(
        _refuse(
          sessionId,
          streamId,
          ErrorFrame('handler_failed', safeErrorText(error)),
        ),
      );
      return;
    }

    late final StreamSubscription<WireFrame> subscription;
    subscription = source.listen(
      // Придерживаем источник, пока кадр не записан: ход выполнения,
      // приехавший не в том порядке, показывает, что работа пошла назад.
      // Отказ записи работу **не** останавливает — см. поле [_runs].
      (frame) => subscription.pause(_send(sessionId, streamId, frame)),
      onError: (Object error) {
        // **Без [DoneFrame].** Восстановление, оборванное на середине, обязано
        // остаться оборванным: «готово» здесь означает целый магазин, и выдать
        // незавершённое за завершённое дороже, чем показать отказ.
        // `WireRefusal` — тот же случай, что в остальных местах отказа: код
        // обработчика точнее общего `run_failed`, а текст безопасен по
        // построению.
        final frame = error is WireRefusal
            ? ErrorFrame(error.code, error.message)
            : ErrorFrame('run_failed', safeErrorText(error));
        _runs.remove(subscription);
        unawaited(_refuse(sessionId, streamId, frame));
      },
      onDone: () {
        _runs.remove(subscription);
        unawaited(_server.closeStream(sessionId, streamId));
      },
      // Отказавшая работа кончена, и `onDone` после `onError` закрыл бы поток
      // второй раз. Дважды закрытый поток — не беда сам по себе, но второе
      // закрытие отвечает `unknownHandle`, и в логе это выглядит как сбой
      // транспорта там, где сбоя нет.
      cancelOnError: true,
    );
    _runs.add(subscription);
  }

  Future<void> _refuse(int sessionId, int streamId, ErrorFrame frame) async {
    await _send(sessionId, streamId, frame);
    await _server.closeStream(sessionId, streamId);
  }

  /// Пишет кадр и глотает статус: одноразовый обмен всё равно закрывается
  /// следующей строкой, и лечить отказ записи здесь нечем.
  Future<void> _send(int sessionId, int streamId, WireFrame frame) =>
      _server.sendOn(sessionId, streamId, frame.encode());
}
