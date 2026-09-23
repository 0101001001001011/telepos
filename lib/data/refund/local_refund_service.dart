import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/refund/refund_plan.dart';
import 'package:telepos/data/sale/local_payment_service.dart'
    show CashDrawerOpener;
import 'package:telepos/domain/refund/refund_receipt_printer.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble, CompletionTroubleKind;
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/usecases/sale/can_sale_be_refunded_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Кассовая реализация [RefundService] — задача 18, шаг 9 спеки.
///
/// # Откуда взялась логика
///
/// Из `RefundNotifier` (`lib/presentation/controllers/refund/
/// refund_controller.dart`): загрузка чека — `loadReceipt:228`, набор
/// товара — `addProduct:351`, завершение — `processRefund:466`. Цены,
/// количества и состав `RefundProductEntry` те же, до знака. Изобретений
/// здесь три, и они те же, что в корзине: владелец (`terminalId` у каждой
/// команды), сверка версии с отказом [refundStaleCode] и ключ повтора.
///
/// # Где живёт черновик — и почему не в базе
///
/// **В памяти кассы, по одному на рабочее место.** Разбор записан в
/// докстринге [RefundService]: у `Refunds` нет ни колонки владельца, ни
/// версии, ни ключа повтора, а завести их значит миграцию v38, которая в
/// этом плане принадлежит задаче 15 и идёт сейчас в соседней ветке. Два
/// разных v38 — расхождение схемы у установленных касс, а не конфликт
/// слияния.
///
/// Это **не ухудшение против сегодняшнего дня**: черновик возврата и так
/// живёт в памяти — только не кассы, а экрана (`RefundState.items`), и
/// теряется от перехода по маршруту. Кассовая память переживает и уход с
/// экрана, и обрыв связи с терминалом, и получает то, чего у экрана не было
/// вовсе: владельца, версию и ключ повтора.
///
/// # Что заменяет транзакцию
///
/// У корзины все сверки стоят внутри транзакции drift, и это не
/// украшательство: круг правки 1 задачи 7 доказал пробой, что чтение
/// **перед** транзакцией разводит только сами транзакции — две команды с
/// одним ключом удваивали товар. Здесь черновик не в базе, и транзакции над
/// ним нет; её роль играет [_serial] — **одна общая очередь на весь
/// сервис**, через которую проходит каждая команда целиком: чтение, сверки,
/// изменение и запись ключа.
///
/// Очередь именно общая, а не по рабочему месту, и на это есть свой довод,
/// кроме простоты. `RefundInitiationUseCaseImpl.initiate` берёт
/// незавершённый возврат через `RefundDao.findWithState(0)`, а это
/// `getSingleOrNull` — **две** одновременно заведённые строки состояния 0
/// уронили бы его исключением, и уронили бы обоим. Пока [complete] на кассе
/// идёт по одному, такой пары не бывает: строка заводится и завершается
/// внутри одного прохода очереди. Цена — [addProduct] соседнего места ждёт
/// чужого [complete]; возвраты редки, и это дешевле, чем вторая правда о
/// том, чей сейчас незавершённый возврат.
///
/// **Честно о пределе довода — поправка круга правки 1.** Очередь разводит
/// вызовы **своего экземпляра**, и только их. Экранный путь возврата
/// (`RefundNotifier.processRefund`) зовёт `RefundInitiationUseCase` и
/// `RefundUseCase` напрямую, мимо неё, в том же изоляте — значит пара строк
/// состояния 0 сегодня достижима, и «очередь играет роль транзакции» верно
/// лишь наполовину. Отсюда перевод `StateError` в отказ [refundBusyCode] в
/// [complete]: пока живы оба пути, случай обязан приезжать значением, а не
/// сырым исключением. Довод станет полным, когда экран перейдёт на
/// контракт.
class LocalRefundService implements RefundService {
  LocalRefundService({
    required AppDatabase db,
    required Talker logger,
    required RefundInitiationUseCase initiation,
    required RefundUseCase refunds,
    required CanSaleBeRefundedUseCase canBeRefunded,
    required CashDrawerOpener drawer,
    RefundReceiptPrinter? printer,
  }) : _db = db,
       _logger = logger,
       _initiation = initiation,
       _refunds = refunds,
       _canBeRefunded = canBeRefunded,
       _drawer = drawer,
       _printer = printer;

  final AppDatabase _db;
  final Talker _logger;
  final RefundInitiationUseCase _initiation;
  final RefundUseCase _refunds;
  final CanSaleBeRefundedUseCase _canBeRefunded;

  /// Денежный ящик кассы — тот же порт [CashDrawerOpener], которым его
  /// открывает продажа (`LocalPaymentService`), и то же тело за ним
  /// (`_openCashDrawer` в `service_locator.dart`).
  ///
  /// # Почему обязательный, в отличие от [_printer]
  ///
  /// Потому что именно необязательностью этот дефект и жил. Приёмка
  /// 2026-09-17: возврат «сертификат 3000 + наличные 200» выдал кассиру
  /// маршрут «Наличными из ящика — 200», провёл фискальный возврат, напечатал
  /// документ — и ящика не открыл, потому что открывать его было нечем: ни
  /// довода, ни вызова. Никакая проба не краснела, стенд выглядел исправным.
  /// Довод `null` означал бы ровно то же самое — «ящика нет», молча, —
  /// поэтому забыть его теперь нельзя по сборке: и касса, и стенд, и каждая
  /// проба обязаны сказать, чем ящик открывается.
  ///
  /// Кассе без ящика здесь передают порт, отвечающий `false` (так делает и
  /// `_openCashDrawer`, когда ни последовательного порта, ни принтера нет), и
  /// кассир узнаёт об этом названной бедой — [hardwareTroubles], — а не
  /// тишиной.
  final CashDrawerOpener _drawer;

  /// Печать чека возврата. `null` — печати нет, и это не ошибка: возврат
  /// обязан проводиться и на кассе без принтера, а пробы этого файла не
  /// поднимают очередь печати ради проверки арифметики.
  ///
  /// Заведена задачей 20. До неё чек возврата собирал **экран**, читая базу
  /// сам, — и возврат, оформленный с браузерного терминала, не печатался бы
  /// вовсе: у планшета нет ни базы, ни принтера кассы.
  final RefundReceiptPrinter? _printer;

  /// Состояние `Refunds.state` у незавершённого возврата — та же цифра,
  /// которой пользуются `RefundInitiationUseCaseImpl` и `RefundUseCaseImpl`.
  static const _refundInProgress = 0;

  /// Состояния чека продажи, при которых он **не совершён**: корзина в
  /// работе и отложенный чек. Те же цифры, которыми пользуются
  /// `LocalCartService` и `SaleDao.findRecentCompleted`.
  static const _stateInProgress = 0;
  static const _stateDeferred = 3;

  /// Беды железа проведённых возвратов, ждущие своего читателя, — см.
  /// [hardwareTroubles]. Ключ — **рабочее место и номер возврата**, предел
  /// [_troublesKept] — тем же числом и по той же причине, что у продажи
  /// (`LocalPaymentService._troubles`): это сигнал одному вызывающему, а не
  /// хранилище исходов.
  final _troubles = <String, Future<List<CompletionTrouble>>>{};

  static const _troublesKept = 16;

  static String _troubleKey(int terminalId, int refundLocalId) =>
      '$terminalId/$refundLocalId';

  final _drafts = <int, _Draft>{};
  final _completed = <int, _Completed>{};
  final _buses = <int, StreamController<RefundView>>{};

  int _nextDraftNo = 1;

  /// Хвост общей очереди команд (см. докстринг класса).
  Future<void> _tail = Future<void>.value();

  // ── подписка ──────────────────────────────────────────────────────────

  @override
  Stream<RefundView> watch(int terminalId) {
    late final StreamController<RefundView> out;
    StreamSubscription<RefundView>? signal;

    out = StreamController<RefundView>(
      onListen: () {
        // Подписка на шину заводится **до** первого чтения: изменение,
        // случившееся между ними, иначе потерялось бы навсегда (то же
        // правило и тот же порядок, что в `watchTables`).
        signal = _busFor(terminalId).stream.listen(
          (view) {
            if (!out.isClosed) out.add(view);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!out.isClosed) out.addError(error, stackTrace);
          },
        );
        // Первое чтение идёт **через очередь команд**, а не мимо неё.
        // Иначе снимок, собранный до команды, мог бы прийти подписчику
        // после снимка, собранного командой, — и версия поехала бы назад.
        unawaited(
          _serial(() => currentView(terminalId)).then(
            (view) {
              if (!out.isClosed) out.add(view);
            },
            onError: (Object error, StackTrace stackTrace) {
              // Отказ чтения уезжает ошибкой потока, а не проглатывается:
              // ненастроенная касса обязана назвать причину подписчику
              // (`till_not_configured`), а не молчать.
              if (!out.isClosed) out.addError(error, stackTrace);
            },
          ),
        );
      },
      onCancel: () {
        final pending = signal;
        signal = null;
        if (pending != null) unawaited(pending.cancel());
      },
    );

    return out.stream;
  }

  /// Снимок черновика рабочего места сейчас — то же чтение, которым
  /// отвечает [watch] (правило `watchTables`: вопрос и подписка не имеют
  /// права читать по-разному).
  Future<RefundView> currentView(int terminalId) async {
    final draft = _drafts[terminalId];
    if (draft == null) return _emptyView(terminalId);
    return _viewOf(terminalId, draft);
  }

  StreamController<RefundView> _busFor(int terminalId) => _buses.putIfAbsent(
    terminalId,
    () => StreamController<RefundView>.broadcast(),
  );

  void _publish(int terminalId, RefundView view) {
    final bus = _buses[terminalId];
    if (bus != null && !bus.isClosed) bus.add(view);
  }

  // ── команды ───────────────────────────────────────────────────────────

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) => _change(terminalId, meta, (_) async {
    final sale = await _db.saleDao.findByKey(receiptNo, posId);
    if (sale == null) {
      throw WireRefusal(
        refundReceiptNotFoundCode,
        'чека $receiptNo кассы $posId на этой кассе нет',
      );
    }
    _checkCompleted(sale);

    final existing = await _db.refundDao.findBySale(receiptNo, posId);
    if (existing != null && (existing.state ?? 0) != _refundInProgress) {
      throw WireRefusal(
        refundAlreadyRefundedCode,
        'по чеку $receiptNo возврат уже сделан',
      );
    }

    // `CanSaleBeRefundedUseCase` сворачивает в своё `false` **две** разные
    // причины — «возврат уже есть» и «платили чужим эквайрингом», — и
    // первую из них перекрывает проверка выше, которая называет её точным
    // кодом. Поэтому юзкейс спрашивается только там, где строки возврата
    // нет вовсе: иначе брошенная строка состояния 0 (её
    // `RefundInitiationUseCase` переиспользует как черновую) навсегда
    // отвечала бы «нельзя» с неверной причиной.
    if (existing == null &&
        !await _canBeRefunded.canBeRefunded(
          receiptNo: receiptNo,
          posId: posId,
        )) {
      throw WireRefusal(
        refundNotRefundableCode,
        'чек $receiptNo вернуть на этой кассе нельзя',
      );
    }

    final lines = await _receiptLines(receiptNo, posId);
    if (lines.isEmpty) {
      throw WireRefusal(refundEmptyCode, 'в чеке $receiptNo нет строк');
    }

    _logger.info(
      'Refund: receipt loaded $receiptNo/$posId terminal=$terminalId '
      'lines=${lines.length}',
    );

    return _Draft(
      draftNo: _nextDraftNo++,
      saleReceiptNo: receiptNo,
      salePosId: posId,
      available: lines,
      lines: List.of(lines),
    );
  });

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) => _change(terminalId, meta, (_) async {
    // Право на возврат без чека проверяет касса **до** обработчика
    // (`opRefundWithoutReceipt`, задача 19). Здесь его не видно и не должно
    // быть видно: скрытая кнопка правом не является, но и сервис,
    // проверяющий право сам, увёл бы проверку из единственного места, где
    // её видит сторож провода.
    _logger.info('Refund: started without receipt terminal=$terminalId');
    return _Draft(
      draftNo: _nextDraftNo++,
      saleReceiptNo: null,
      salePosId: null,
      available: const [],
      lines: const [],
    );
  });

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _change(terminalId, meta, (draft) async {
    // `needsDraft: true` уже отказал, если черновика нет.
    final current = draft!;
    if (current.byReceipt) {
      // Круг правки 1: в возврате по чеку каталог не добавляют вовсе.
      throw WireRefusal(
        refundLineNotInReceiptCode,
        'по чеку ${current.saleReceiptNo} возвращают то, что в нём продано, '
        'а не товар из каталога',
      );
    }
    _checkQuantity(quantity);

    final id = 'p$productId';
    final source = quantity > Decimal.zero
        ? await _catalogLine(productId)
        : _findById(current.lines, id);

    return current.withLines(
      _writeLine(current.lines, id: id, source: source, quantity: quantity),
    );
  }, needsDraft: true);

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _change(terminalId, meta, (draft) async {
    final current = draft!;
    _checkQuantity(quantity);

    // Строка ищется в том, что чек **позволяет** вернуть, а не в текущем
    // наборе: снятую строку иначе было бы неоткуда вернуть обратно. В
    // возврате без чека такого списка нет — там строка живёт только в
    // наборе.
    final source =
        _findById(current.available, lineId) ??
        _findById(current.lines, lineId);
    if (source == null) {
      throw WireRefusal(
        refundLineNotFoundCode,
        'строки $lineId в возврате нет',
      );
    }
    final cap = source.maxQuantity;
    if (cap != null && quantity > cap) {
      throw WireRefusal(
        refundInvalidAmountCode,
        'по этой строке чека продано $cap — вернуть больше нельзя',
      );
    }

    return current.withLines(
      _writeLine(current.lines, id: lineId, source: source, quantity: quantity),
    );
  }, needsDraft: true);

  /// Задача 19, круг правки 1 (C1): вход на рабочее место начинает работу с
  /// чистого листа — иначе право `op.refundWithoutReceipt` охраняло бы
  /// только первое нажатие, а деньги уходили бы на одном `op.refund`
  /// (проба и разбор — докстринг [RefundService.abandon]).
  ///
  /// **Под общей очередью, как и всё остальное:** уборка посреди чужой
  /// команды оставила бы её применяться в черновик, которого уже нет, — а
  /// вход по проводу приходит на той же кассе и в том же изоляте, что и
  /// команда возврата.
  ///
  /// Снимок после уборки **публикуется**: подписчик обязан увидеть, что
  /// черновика больше нет, а не остаться при старом (`started == false` —
  /// законное значение, не отсутствие значения).
  @override
  Future<void> abandon(int terminalId) => _serial(() async {
    final had = _drafts.remove(terminalId) != null;
    _completed.remove(terminalId);
    if (had) _publish(terminalId, await _emptyView(terminalId));
  });

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) =>
      _serial(() async {
        // Ключ раньше всего — тем же порядком и по той же причине, что в
        // корзине: повтор приходит с версией, которая после первого
        // применения уже устарела.
        //
        // **Честный предел: слот, а не журнал.** Помнится **один**
        // последний завершённый возврат рабочего места. Успел кассир
        // начать и завершить следующий — повтор предыдущего опознан не
        // будет и получит отказ. Отказ безопасен (двойного возврата не
        // будет), буква правила 3 нарушена; журнал ключей закрыл бы это и
        // не заведён осознанно, пока терминал держит «одну команду в
        // полёте» (I161).
        final done = _completed[terminalId];
        if (done != null && done.key == meta.key) return done.outcome;

        final draft = _drafts[terminalId];
        if (draft == null) {
          throw const WireRefusal(
            refundNotStartedCode,
            'возврат не начат на этом рабочем месте',
          );
        }
        _checkAddressedTo(draft, meta);
        if (draft.version != meta.baseVersion) {
          throw _stale(draft.version, meta);
        }
        if (draft.lines.isEmpty) {
          throw const WireRefusal(
            refundEmptyCode,
            'в возврате нет ни одной строки',
          );
        }

        final posId = await _posId();
        final shift = await _db.shiftDao.findOpenedShift();
        if (shift == null) {
          // Тот же отказ и тем же кодом, каким отвечает начало продажи
          // (`SaleInitiationUseCaseImpl`): возврат — движение денег смены,
          // и без открытой смены его некуда записать.
          throw const WireRefusal(
            'shift_not_open',
            'смена не открыта — возврат не оформить',
          );
        }

        Sale? sale;
        if (draft.byReceipt) {
          sale = await _db.saleDao.findByKey(
            draft.saleReceiptNo!,
            draft.salePosId!,
          );
          if (sale == null) {
            throw WireRefusal(
              refundReceiptNotFoundCode,
              'чек ${draft.saleReceiptNo} исчез, пока шёл возврат',
            );
          }
          // Состояние сверяется **и здесь**, а не только при загрузке: чек
          // между загрузкой и завершением может уехать в работу или в
          // отложенные (`SaleDao.updateState`, подъём отложенного, слияние
          // при обмене), и деньги отдавать за него уже нельзя.
          _checkCompleted(sale);
          final existing = await _db.refundDao.findBySale(
            draft.saleReceiptNo!,
            draft.salePosId!,
          );
          if (existing != null && (existing.state ?? 0) != _refundInProgress) {
            throw WireRefusal(
              refundAlreadyRefundedCode,
              'по чеку ${draft.saleReceiptNo} возврат уже сделан',
            );
          }
        }

        final amount = DecimalUtil.roundMoney(draft.total);
        // **Нулевая сумма — не всегда ошибка, и это не поблажка, а разбор
        // круга правки 2.** Чек, целиком роздан по акции или под
        // стопроцентную скидку, стоит ноль, и вернуть его надо: товар
        // обязан лечь обратно на склад. `RefundUseCaseImpl._validateRefund`
        // этот случай **уже оговаривает** (`isTotalDiscountSale`), и
        // экранный путь такой возврат проводит, — то есть моя проверка была
        // регрессом против экрана, а не защитой. Условие взято оттуда до
        // знака: возврат **по чеку**, у которого каждая **возвращаемая**
        // строка продана по нулевой цене (не весь чек — подарок из платного
        // чека возвращается отдельно, и это законно). Отступишь от него —
        // `_validateRefund` бросит `InvalidRefundException`, и на провод
        // уедет одно имя типа.
        //
        // Честно о половине условия: `draft.byReceipt` сегодня **не
        // проверяем прогоном** — в возврате без чека нулевая цена
        // отвергается раньше, в `_catalogLine`, и до сюда с нулём не
        // доходит. Половина оставлена, потому что она есть в оговорке, у
        // которой мы одалживаем правило; исчезнет та проверка — исчезнет и
        // защита.
        final freeSale =
            draft.byReceipt &&
            draft.lines.every((line) => line.price == Decimal.zero);
        if (amount <= Decimal.zero && !freeSale) {
          throw const WireRefusal(
            refundInvalidAmountCode,
            'сумма возврата не бывает нулевой',
          );
        }

        // **Круг правки 1, I2: сырое исключение не имеет права уехать из
        // контракта.** `RefundInitiationUseCase` берёт незавершённый
        // возврат через `RefundDao.findWithState(0)` — `getSingleOrNull`,
        // — и две такие строки роняют его `StateError`. Очередь этого
        // сервиса такой пары не создаёт, но она разводит только **свои**
        // вызовы: экранный путь (`RefundNotifier.processRefund`) зовёт
        // `initiate` мимо неё, в том же изоляте. Пока живы оба пути,
        // случай достижим, и он обязан приезжать отказом значением (I144).
        //
        // Круг правки 2: причина называется **счётом**, а не поимкой
        // исключения. `initiate` бросает `StateError` по трём разным
        // поводам (две строки в работе, смена не открыта, касса не
        // настроена), и один перехват на все три врал бы в двух случаях из
        // трёх — пусть сегодня они и перекрыты проверками выше.
        final started = await _db.refundDao.countWithState(_refundInProgress);
        if (started > 1) {
          _logger.warning(
            'Refund: $started in-progress refund rows — refusing',
          );
          throw const WireRefusal(
            refundBusyCode,
            'на кассе уже есть незавершённый возврат — завершите или '
            'очистите его',
          );
        }

        final dynamic refund;
        try {
          refund = await _initiation.initiate(
            saleReceiptNo: draft.saleReceiptNo,
            salePosId: draft.salePosId,
          );
        } on StateError catch (error, stackTrace) {
          // Остаток после счёта выше: причина не названа, и притворяться,
          // что она известна, нельзя — код говорит ровно то, что случилось.
          _logger.warning('Refund: initiation failed', error, stackTrace);
          throw const WireRefusal(
            refundCannotStartCode,
            'возврат не удалось начать — проверьте смену и настройки кассы',
          );
        }
        if (refund == null) {
          // Круг правки 2: и эта ветка — отказом значением, а не броском.
          // Она недостижима (строка только что заведена и читается тем же
          // запросом), но сырое исключение в денежном пути это ровно та
          // форма, которую закрывал круг 1, — и «невозможно» не довод
          // оставлять её открытой.
          _logger.warning('Refund: the row was created but is not in progress');
          throw const WireRefusal(
            refundCannotStartCode,
            'возврат не удалось начать — проверьте смену и настройки кассы',
          );
        }
        final refundLocalId = refund.localId as int;

        final products = draft.lines
            .map(
              (line) => RefundProductEntry(
                ucode: line.productId,
                quantity: line.quantity,
                price: line.price,
                // Те же два поля и по тому же признаку, что в
                // `processRefund` контроллера: в возврате по чеку они
                // говорят, как товар был продан, в возврате без чека
                // говорить нечем.
                //
                // Круг правки 1: числа настоящие, а не усреднённые.
                // `line.price` — цена **этой строки чека**, `maxQuantity` —
                // сколько по ней продано; оба берутся из `SaleProducts` без
                // сведения строк с разной ценой. Это то, что уезжает в
                // фискальный документ возврата, и выдумывать там нечего.
                inSalePrice: draft.byReceipt ? line.price : null,
                inSaleQuantity: draft.byReceipt ? line.maxQuantity : null,
              ),
            )
            .toList();

        final result = await _refunds.perform(
          refundLocalId: refundLocalId,
          amount: amount,
          userId: shift.userId,
          saleReceiptNo: draft.saleReceiptNo,
          salePosId: draft.salePosId,
          customerLocalId: sale?.customerLocalId,
          products: products,
          // Карта возвращается через платёжный терминал **этого** рабочего
          // места — того, откуда пришла команда (задача 26).
          terminalId: terminalId,
        );

        final outcome = RefundOutcome(
          refundLocalId: result.refundLocalId,
          amount: result.amount,
          lineCount: result.productCount,
          paymentCount: result.paymentCount,
          saleReceiptNo: draft.saleReceiptNo,
          salePosId: draft.salePosId,
        );

        _drafts.remove(terminalId);
        _completed[terminalId] = _Completed(meta.key, outcome);
        _logger.info(
          'Refund: completed refund=$refundLocalId terminal=$terminalId '
          'amount=$amount lines=${result.productCount}',
        );
        _publish(
          terminalId,
          RefundView(
            posId: posId,
            terminalId: terminalId,
            version: 0,
            lines: const [],
          ),
        );

        // Ящик — тем же правилом, что у продажи: **только если из него
        // ушли деньги** и **отправляется, а не ожидается**. Разбор — в
        // [_openDrawer].
        _dispatchDrawer(terminalId, result.refundLocalId, result.drawerAmount);

        // Печать **отправляется, а не ожидается** — правило «оплата не ждёт
        // железа» (`project_telepos_rebrand_2026-07`), и по проводу оно
        // важнее вдвое: к задержке принтера добавилась бы ещё и сеть.
        // Строки берутся из черновика, который только что стал возвратом, —
        // то есть печатается ровно то, за что отданы деньги. До задачи 20
        // печатал экран **свой** набор строк, и совпадал он с кассовым лишь
        // потому, что путь был один.
        final printer = _printer;
        if (printer != null) {
          unawaited(
            printer
                .printRefund(
                  outcome: outcome,
                  lines: draft.lines,
                  userId: shift.userId,
                )
                // Контракт обещает «не бросает», но обещание — не механизм:
                // отправка **не ожидается**, поэтому исключение из неё
                // становится необработанной асинхронной ошибкой процесса, а
                // не отказом операции. Деньги к этому моменту отданы, товар
                // на остатке, и уронить этим кассу было бы худшим из
                // возможных исходов. Проверено пробой «отказ печати не
                // отменяет состоявшийся возврат».
                .catchError((Object error, StackTrace stackTrace) {
                  _logger.warning(
                    'Refund: receipt print threw despite the contract',
                    error,
                    stackTrace,
                  );
                }),
          );
        }

        return outcome;
      });

  // ── железо после проведения ──────────────────────────────────────────

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async {
    final pending = _troubles.remove(_troubleKey(terminalId, refundLocalId));
    if (pending == null) return const [];
    return await pending;
  }

  /// Открыть ящик после проведённого возврата — **если и только если** в
  /// нём была часть, выданная наличными из ящика.
  ///
  /// # Условие — деньги, а не вид оплаты чека
  ///
  /// Число берётся из раскладки, по которой юзкейс только что сделал
  /// проводки ([RefundResult.drawerAmount]), тем же доводом, каким продажа
  /// открывает ящик по `plan.cash`, а не по виду оплаты: чек «сертификат +
  /// наличные», возвращённый частично, может не отдать из ящика ни тенге
  /// (раскладка гасит сертификат первым), и открывать ящик тогда — звать
  /// кассира отдать деньги, которых по книгам не выдавали.
  ///
  /// # Почему не ждём
  ///
  /// Деньги по книгам уже выданы, документ ушёл, черновик забыт. Ящик на
  /// последовательном порту, который не отвечает, иначе держал бы ответ
  /// `refund.complete` — а за ним и общую очередь команд всех рабочих мест —
  /// на время таймаута порта. Беда поэтому не отказ, а запись для
  /// [hardwareTroubles].
  void _dispatchDrawer(int terminalId, int refundLocalId, Decimal cash) {
    if (cash <= Decimal.zero) return;
    final job = _openDrawer(
      refundLocalId,
    ).then((trouble) => trouble == null ? <CompletionTrouble>[] : [trouble]);
    _troubles[_troubleKey(terminalId, refundLocalId)] = job;
    while (_troubles.length > _troublesKept) {
      _troubles.remove(_troubles.keys.first);
    }
    unawaited(job);
  }

  /// Тело — дословно `LocalPaymentService._openDrawer`: `false` и бросок
  /// порта становятся бедой с причиной словами (I144), и ни то ни другое не
  /// выходит из метода исключением — оно стало бы необработанной асинхронной
  /// ошибкой процесса уже после того, как деньги выданы.
  Future<CompletionTrouble?> _openDrawer(int refundLocalId) async {
    try {
      if (await _drawer()) return null;
      _logger.warning(
        'Refund: денежный ящик не открылся, возврат $refundLocalId',
      );
      return CompletionTrouble(
        kind: CompletionTroubleKind.drawer,
        receiptNo: refundLocalId,
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
        'Refund: денежный ящик не открылся, возврат $refundLocalId — $safe',
        e,
        st,
      );
      return CompletionTrouble(
        kind: CompletionTroubleKind.drawer,
        receiptNo: refundLocalId,
        message: safe,
      );
    }
  }

  // ── общий ход изменяющей команды ──────────────────────────────────────

  /// Владелец, ключ повтора, опознание черновика, версия, изменение и
  /// запись ключа — один порядок для всех команд, чтобы забыть его в одной
  /// из них было негде.
  ///
  /// Порядок проверок **сначала ключ, потом номер черновика, потом
  /// версия** — разбор в докстринге [RefundService]. Весь ход целиком
  /// проходит через [_serial]: у черновика в памяти нет транзакции, и
  /// разводить команды обязана очередь, иначе повторится измеренная проба
  /// задачи 7 — две команды с одним ключом, обе прочитавшие пустой ключ,
  /// обе применившиеся.
  Future<RefundView> _change(
    int terminalId,
    CartCommandMeta meta,
    Future<_Draft> Function(_Draft? current) apply, {
    bool needsDraft = false,
  }) => _serial(() async {
    final current = _drafts[terminalId];
    if (needsDraft && current == null) {
      // Раньше опознания и версии — как `LocalCartService._command`
      // отвечает `cart_not_started` до всяких сверок: сверять номер
      // черновика, которого нет, значит назвать беду не тем именем.
      throw const WireRefusal(
        refundNotStartedCode,
        'возврат не начат на этом рабочем месте',
      );
    }
    if (current != null && current.lastCommandKey == meta.key) {
      return _viewOf(terminalId, current);
    }
    _checkAddressedTo(current, meta);
    final currentVersion = current?.version ?? 0;
    if (currentVersion != meta.baseVersion) {
      throw _stale(currentVersion, meta);
    }

    final next = await apply(current);

    // Условная замена по прочитанному черновику — то же место и та же роль,
    // что у `WHERE cart_version = ...` в `LocalCartService._writeVersion`,
    // и **та же честная оговорка**: на общей очереди эта ветка недостижима,
    // прогоном не покрыта и покрыта быть не может. Она на случай, когда
    // довод про одну очередь перестанет быть верным, а не проверенное
    // поведение.
    if (!identical(_drafts[terminalId], current)) {
      throw _staleOnWrite(currentVersion, meta);
    }

    // **Версия считает изменения этого черновика, а не команды рабочего
    // места**, — тем же смыслом, что `Sales.cartVersion` считает изменения
    // своего чека. Новый черновик поэтому начинается с нуля, и у двух
    // черновиков подряд версии совпадают постоянно: опознаёт их
    // [RefundView.draftNo], и без него запоздавшая команда от прежнего
    // черновика легла бы в новый молча (проба круга правки 2 задачи 7,
    // повторённая здесь тестом «запоздавшая команда не ложится в
    // черновик, начатый после неё»).
    next.version = (current != null && next.draftNo == current.draftNo)
        ? currentVersion + 1
        : 0;
    next.lastCommandKey = meta.key;
    if (next.draftNo != current?.draftNo) {
      // **Слот повтора завершения чистится вместе с черновиком — круг
      // правки 1.** Он не чистился никогда за жизнь процесса, и предел был
      // описан не в ту сторону: не «повтор старого ключа получит „возврат
      // не начат“», а «повтор старого ключа вернёт **старый исход**, не
      // выполнив новый возврат». Проба разбора: терминал получал успех с
      // чужой суммой (300 при ожидаемых 1500), товар не возвращался,
      // черновик оставался на месте. Теперь поздний честный повтор
      // получает `refund_wrong_draft` — отказ, а не подделку.
      _completed.remove(terminalId);
    }
    _drafts[terminalId] = next;

    final view = await _viewOf(terminalId, next);
    _publish(terminalId, view);
    return view;
  });

  /// Очередь команд: следующая начинается после предыдущей.
  ///
  /// Хвост держится **нормально завершающимся** будущим (`Completer`,
  /// закрываемый в `whenComplete`): пусти в него отказ команды — и его
  /// получила бы каждая следующая, то есть один `refund_stale` запирал бы
  /// рабочее место навсегда.
  Future<T> _serial<T>(Future<T> Function() body) {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return previous.then((_) => body()).whenComplete(gate.complete);
  }

  /// Команда адресована тому черновику, который у места сейчас в работе?
  ///
  /// `null` в [CartCommandMeta.receiptNo] значит «черновика у меня не
  /// было», и совпадает только с отсутствием черновика здесь. Разбор — в
  /// докстринге [RefundView.draftNo]: у возврата без чека номера чека нет,
  /// и опознавать по нему нечего.
  void _checkAddressedTo(_Draft? draft, CartCommandMeta meta) {
    if (meta.receiptNo == draft?.draftNo) return;
    _logger.warning(
      'Refund: wrong draft key=${meta.key} '
      'addressed=${meta.receiptNo} current=${draft?.draftNo}',
    );
    throw const WireRefusal(
      refundWrongDraftCode,
      'команда адресована другому возврату — обновите его',
    );
  }

  WireRefusal _stale(int currentVersion, CartCommandMeta meta) {
    _logger.warning(
      'Refund: stale command key=${meta.key} '
      'base=${meta.baseVersion} current=$currentVersion',
    );
    return const WireRefusal(
      refundStaleCode,
      'возврат уже изменился — обновите его и повторите',
    );
  }

  /// Тот же отказ, но от **условной замены**, а не от сверки прочитанного:
  /// текущая версия в этой ветке неизвестна, и писать её в журнал значило
  /// бы выдумать то число, ради расхождения с которым ветка существует
  /// (разбор — круг правки 3 задачи 7, `LocalCartService._staleOnWrite`).
  WireRefusal _staleOnWrite(int readVersion, CartCommandMeta meta) {
    _logger.warning(
      'Refund: conditional swap rejected key=${meta.key} '
      'base=${meta.baseVersion} read=$readVersion '
      '(текущая версия не читалась — черновик подменили между чтением и '
      'заменой)',
    );
    return const WireRefusal(
      refundStaleCode,
      'возврат уже изменился — обновите его и повторите',
    );
  }

  // ── строки ────────────────────────────────────────────────────────────

  /// Строки чека в виде строк возврата.
  ///
  /// **Сводятся только строки с совпадающей ценой — круг правки 1.** Ключ
  /// сведения это пара «товар и цена», ровно тот же приём, что у корзины
  /// (`LocalCartService._mergeTarget`, условие 1). Разные цены живут
  /// разными строками; идентификатором строки становится **номер строки
  /// чека** (`SaleProducts.id`) — наименьший в группе.
  ///
  /// Первая версия сводила по товару и считала цену средней: чек
  /// `3x100 + 1x90` давал одну строку по 97.5, и возврат одной штуки платил
  /// 97.5 — цену, которой не стоила ни одна проданная единица, — а в
  /// фискальный документ уходило «как продано: 4 x 97.5». Поштучная цена в
  /// базе есть, терять её было незачем; экран, который строки не сводит,
  /// такой ошибки и не делал, то есть это был регресс перевода на контракт.
  Future<List<RefundLine>> _receiptLines(int receiptNo, int posId) async {
    final rows = await _db.saleProductDao.findBySale(receiptNo, posId);

    final order = <String>[];
    final groups = <String, _ReceiptGroup>{};
    for (final row in rows) {
      final key = '${row.ucode}@${row.price}';
      final group = groups[key];
      if (group == null) {
        order.add(key);
        groups[key] = _ReceiptGroup(
          lineId: row.id,
          ucode: row.ucode,
          price: row.price,
          quantity: row.quantity,
          barcode: row.barcode?.toString(),
        );
        continue;
      }
      group.quantity += row.quantity;
      if (row.id < group.lineId) group.lineId = row.id;
    }

    final lines = <RefundLine>[];
    for (final key in order) {
      final group = groups[key]!;
      if (group.quantity <= Decimal.zero) continue;
      final info = await _db.productInfoDao.findByUcode(group.ucode);
      lines.add(
        RefundLine(
          id: group.lineId.toString(),
          productId: group.ucode,
          name: info?.name ?? '#${group.ucode}',
          quantity: group.quantity,
          price: group.price,
          maxQuantity: group.quantity,
          barcode: group.barcode ?? info?.barcode.toString(),
        ),
      );
    }
    return lines;
  }

  /// Строка возврата без чека: товар из каталога по цене продажи.
  Future<RefundLine> _catalogLine(int productId) async {
    final info = await _db.productInfoDao.findByUcode(productId);
    if (info == null) {
      throw WireRefusal(
        refundProductNotFoundCode,
        'товара с кодом $productId нет в каталоге',
      );
    }
    final price = await _db.productPriceDao.findByUcode(productId);
    final selling = price?.sellingPrice ?? Decimal.zero;
    if (selling <= Decimal.zero) {
      // `RefundUseCaseImpl._validateRefund` отвергает нулевую цену без
      // чека исключением; по проводу оно уехало бы одним именем типа. Тот
      // же запрет, названный кодом и на входе, а не в конце.
      throw WireRefusal(
        refundInvalidAmountCode,
        'у товара $productId нет цены продажи — вернуть его без чека нельзя',
      );
    }
    return RefundLine(
      // В возврате без чека строка у товара одна — цена берётся из каталога
      // и второй быть неоткуда, поэтому код товара и есть её имя.
      id: 'p$productId',
      productId: productId,
      name: info.name,
      quantity: Decimal.zero,
      price: selling,
      barcode: info.barcode.toString(),
    );
  }

  /// Чек **совершён**? Возвращают только совершённые.
  ///
  /// Круг правки 1, критическая находка. `loadReceipt` не смотрела на
  /// состояние вовсе, а `CanSaleBeRefundedUseCase` при пустом списке
  /// платежей отвечает «можно» — значит терминал с одним правом на возврат
  /// вынимал деньги за неоплаченную продажу. Пробы разбора: «возврат
  /// неоплаченного чека прошёл: 1000; касса 10000 -> 9000; остаток 100 ->
  /// 102» и «отложенный чек возвращён: 1000; касса 10000 -> 9000».
  ///
  /// Состояние 0 — это **корзина в работе**: с задачи 7 она лежит в тех же
  /// `Sales`/`SaleProducts` с первой команды, то есть возврат вынимал
  /// деньги за чужую живую корзину. Состояние 3 — отложенный чек.
  ///
  /// Условие — то же, которым тройка `SaleDao.findRecentCompleted`,
  /// `amountOfShift`, `sumAmountByCustomerLocalId` отделяет деньги от
  /// неденег: `state NOT IN (0, 3)`. Пустое состояние тоже не годится — в
  /// SQL `NULL NOT IN (...)` не истина, и здесь оно отвергается тем же
  /// смыслом, а не по недосмотру.
  void _checkCompleted(Sale sale) {
    final state = sale.state;
    if (state != null && state != _stateInProgress && state != _stateDeferred) {
      return;
    }
    _logger.warning(
      'Refund: sale ${sale.receiptNo}/${sale.posId} is not completed '
      '(state=$state) — refusing',
    );
    throw WireRefusal(
      refundSaleNotCompletedCode,
      'чек ${sale.receiptNo} не совершён — вернуть по нему нечего',
    );
  }

  void _checkQuantity(Decimal quantity) {
    if (quantity < Decimal.zero) {
      throw const WireRefusal(
        refundInvalidAmountCode,
        'количество возврата не бывает отрицательным',
      );
    }
  }

  RefundLine? _findById(List<RefundLine> lines, String id) {
    for (final line in lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  /// Новый набор строк, в котором строка [id] стоит в количестве
  /// [quantity]; ноль удаляет строку, а не оставляет строку с нулём — то же
  /// правило, каким `CartService.setQuantity` удаляет строку корзины.
  List<RefundLine> _writeLine(
    List<RefundLine> lines, {
    required String id,
    required RefundLine? source,
    required Decimal quantity,
  }) {
    final next = <RefundLine>[];
    var replaced = false;
    for (final line in lines) {
      if (line.id != id) {
        next.add(line);
        continue;
      }
      replaced = true;
      if (quantity > Decimal.zero) next.add(_withQuantity(source!, quantity));
    }
    if (!replaced && quantity > Decimal.zero) {
      next.add(_withQuantity(source!, quantity));
    }
    return next;
  }

  RefundLine _withQuantity(RefundLine line, Decimal quantity) => RefundLine(
    id: line.id,
    productId: line.productId,
    name: line.name,
    quantity: quantity,
    price: line.price,
    maxQuantity: line.maxQuantity,
    barcode: line.barcode,
  );

  // ── снимок ────────────────────────────────────────────────────────────

  /// Снимок черновика — **с тем, куда уйдут деньги** (задача 26).
  ///
  /// Раскладку считает тот же [RefundPlan], которым `RefundUseCaseImpl`
  /// проведёт возврат: экран кассы и браузерный терминал показывают ответ
  /// кассы, а не своё представление о нём.
  Future<RefundView> _viewOf(int terminalId, _Draft draft) async {
    final amount = DecimalUtil.roundMoney(draft.total);
    final destinations = amount > Decimal.zero
        ? (await RefundPlan.of(
            _db,
            amount: amount,
            receiptNo: draft.saleReceiptNo,
            posId: draft.salePosId,
          )).destinations
        : const <RefundDestination>[];
    return RefundView(
      posId: await _posId(),
      terminalId: terminalId,
      version: draft.version,
      lines: List.unmodifiable(draft.lines),
      draftNo: draft.draftNo,
      saleReceiptNo: draft.saleReceiptNo,
      salePosId: draft.salePosId,
      destinations: List.unmodifiable(destinations),
    );
  }

  Future<RefundView> _emptyView(int terminalId) async => RefundView(
    posId: await _posId(),
    terminalId: terminalId,
    version: 0,
    lines: const [],
  );

  /// Номер этой кассы — или **названный отказ**, если её не настроили.
  ///
  /// Перевод броска в отказ значением стоит здесь, на границе провода, а не
  /// в `requireId`: политика «ноль не подставляется» общая для всех слоёв,
  /// а «отказ приходит значением» (I144) — правило именно провод-обращённого
  /// (тот же разбор, что у `LocalCartService._posId`, круг правки 5 задачи
  /// 7).
  Future<int> _posId() async {
    try {
      return await _db.thisPosDao.requireId();
    } on TillNotConfigured {
      throw const WireRefusal('till_not_configured', 'касса не настроена');
    }
  }
}

/// Группа строк чека с одним товаром и одной ценой — рабочая форма сборки
/// строк возврата ([LocalRefundService._receiptLines]).
class _ReceiptGroup {
  _ReceiptGroup({
    required this.lineId,
    required this.ucode,
    required this.price,
    required this.quantity,
    required this.barcode,
  });

  int lineId;
  final int ucode;
  final Decimal price;
  Decimal quantity;
  final String? barcode;
}

/// Черновик возврата одного рабочего места.
class _Draft {
  _Draft({
    required this.draftNo,
    required this.saleReceiptNo,
    required this.salePosId,
    required this.available,
    required List<RefundLine> lines,
  }) : lines = List.of(lines);

  final int draftNo;
  final int? saleReceiptNo;
  final int? salePosId;

  /// Что чек вообще позволяет вернуть — неизменный набор, снятый при
  /// [LocalRefundService.loadReceipt].
  ///
  /// Отдельно от [lines] намеренно: кассир снимает выделение со строки
  /// ([LocalRefundService.setLineQuantity] с нулём), потом возвращает его
  /// обратно тем же вызовом с ненулевым количеством — и взять строку было
  /// бы неоткуда, если бы чек помнился только через текущий набор.
  ///
  /// Возврат **без чека** держит этот список пустым, и отсюда следует
  /// названный предел: снятую там строку `setLineQuantity` вернуть не
  /// может (её больше нет ни в одном списке), товар кладётся заново
  /// [LocalRefundService.addProduct]. `addProduct` на чековом черновике,
  /// наоборот, отказывает всегда — по чеку возвращают проданное, а не
  /// каталог.
  final List<RefundLine> available;

  /// Что вернут сейчас.
  final List<RefundLine> lines;

  int version = 0;
  String? lastCommandKey;

  bool get byReceipt => saleReceiptNo != null;

  Decimal get total => lines.fold(Decimal.zero, (s, l) => s + l.total);

  _Draft withLines(List<RefundLine> next) => _Draft(
    draftNo: draftNo,
    saleReceiptNo: saleReceiptNo,
    salePosId: salePosId,
    available: available,
    lines: next,
  );
}

/// Последний завершённый возврат рабочего места — слот под ключ повтора
/// [LocalRefundService.complete] (предел назван у самой команды).
class _Completed {
  const _Completed(this.key, this.outcome);

  final String key;
  final RefundOutcome outcome;
}
