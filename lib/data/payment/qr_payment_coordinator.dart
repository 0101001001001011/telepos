import 'dart:async';

import 'package:decimal/decimal.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_payment_provider.dart';

/// Ожидание оплаты по QR как **состояние кассы, а не состояние экрана**.
///
/// # Что здесь происходит и почему это не сводится к «спросить провайдера»
///
/// QR — единственный вид оплаты, у которого между вопросом и ответом
/// проходит время, и всё сложное здесь именно про это время:
///
/// 1. **Пока кассир ждёт**, он видит код и кнопку «Отмена»; ждать он
///    может ровно [patience], после чего касса **сдаётся сама** —
///    бесконечное ожидание не прерывается ничем и запирает рабочее место.
/// 2. **Кассир прерывает** ожидание [abandon]: касса просит провайдера
///    отменить и **проверяет ответ**. Ответ «уже оплачено» — не ошибка, а
///    самый важный исход: деньги списаны.
/// 3. **Подтверждение после отмены** оставляет намерение оплаченным и
///    неразобранным ([PaymentIntent.isOrphanMoney]) — видимым на экране
///    разбора, а не забытым.
/// 4. **Связь пропала** — намерение **не** объявляется провалившимся:
///    транзиентный отказ означает «не знаю», а не «нет». Строка остаётся
///    неразобранной, и [reconcile] спросит снова.
/// 5. **Повтор** не создаёт второго намерения ни у нас (уникальный ключ
///    таблицы), ни у провайдера (тот же [PaymentIntent.intentKey]).
///
/// # Почему опрос, а не вебхук
///
/// Вебхук требует адреса кассы, доступного провайдеру снаружи. У кассы в
/// магазине такого адреса нет — она за NAT, за роутером хозяина, и часто
/// вовсе без внешнего IP. Опрос работает везде; вебхук работал бы на
/// стенде и не работал бы в магазине, а разница обнаружилась бы на
/// деньгах покупателя.
///
/// # Почему [reconcile] зовётся при старте
///
/// Потому что «касса перезагрузилась, пока покупатель платил» — не
/// экзотика, а вечер пятницы. Строки в состояниях `created`/`pending`
/// — это в точности «подтвердить могли, пока нас не было», и спросить
/// про них надо **до** того, как кассир начнёт новый чек.
class QrPaymentCoordinator {
  QrPaymentCoordinator({
    required AppDatabase db,
    required QrPaymentProvider provider,
    this.patience = const Duration(minutes: 3),
    this.pollEvery = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _db = db,
       _provider = provider,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final QrPaymentProvider _provider;
  final DateTime Function() _now;

  /// Сколько касса согласна ждать покупателя.
  ///
  /// **Предел с названным ответом на вопрос «а что при достижении»**:
  /// касса ставит `abandonedAt`, отменяет намерение у провайдера и
  /// говорит кассиру словами. Предел без такого ответа — дверь, за
  /// которой рабочее место заперто навсегда.
  final Duration patience;

  final Duration pollEvery;

  /// Завести намерение — **или вернуть уже заведённое**.
  ///
  /// Идемпотентность здесь двухслойная, и оба слоя нужны:
  ///
  /// * **у нас** — уникальный ключ `payment_intents.intent_key`: вторая
  ///   вкладка получает ту же строку, а не вторую;
  /// * **у провайдера** — тот же [intentKey] в запросе: провайдер
  ///   возвращает прежнее намерение.
  ///
  /// Одного слоя мало. Без первого две вкладки завели бы две строки и
  /// построили бы две строки `Payments`. Без второго касса, потерявшая
  /// ответ на создании и повторившая запрос, получила бы у провайдера
  /// **два** намерения, и покупатель мог бы заплатить по обоим.
  Future<QrBeginResult> begin({
    required String intentKey,
    required Decimal amount,
    int? posId,
    int? receiptNo,
    int? terminalId,
  }) async {
    final (row, created) = await _db.paymentIntentDao.claim(
      intentKey: intentKey,
      providerCode: _provider.code,
      amount: amount,
      createdAt: _now(),
      posId: posId,
      receiptNo: receiptNo,
      terminalId: terminalId,
    );

    // Строка уже была и уже знает ид провайдера — второй раз создавать
    // намерение **не надо**, и это не оптимизация: второе создание с
    // потерянным ключом и есть механизм двойного взятия денег.
    if (!created && row.providerIntentId != null) {
      return QrBeginResult.ok(row, createdNow: false);
    }

    final reply = await _provider.create(
      intentKey: intentKey,
      amount: amount,
      orderNo: receiptNo?.toString(),
    );
    if (!reply.isOk) {
      final refusal = reply.refusal!;
      // **Транзиентный отказ не хоронит намерение.** Провайдер мог
      // завести его и не донести ответ; строка остаётся `created`, и
      // [reconcile] спросит про неё по нашему ключу.
      if (!refusal.isTransient) {
        await _db.paymentIntentDao.applyState(
          id: row.id,
          status: QrIntentStatus.failed,
          refusalCode: refusal.code,
          refusalMessage: refusal.message,
        );
      }
      return QrBeginResult.refused(refusal, (await _reload(row.id))!);
    }

    final creation = reply.value!;
    await _db.paymentIntentDao.attachProviderIntent(
      id: row.id,
      providerIntentId: creation.providerIntentId,
      status: creation.status,
      qrPayload: creation.qrPayload,
      expiresAt: creation.expiresAt,
    );
    return QrBeginResult.ok(
      (await _reload(row.id))!,
      createdNow: created && !creation.alreadyExisted,
    );
  }

  /// Ждать ответа, пока хватает терпения.
  ///
  /// Возвращается по одной из четырёх причин, и **каждая названа**:
  /// провайдер сказал последнее слово; терпение кончилось; кассир нажал
  /// «Отмена» ([cancelSignal] завершился); отказ, который временем не
  /// лечится.
  ///
  /// **Транзиентный отказ опроса не прерывает ожидания.** Связь пропала
  /// ровно тогда, когда покупатель платит, — обычнейший случай, и
  /// объявить по нему намерение провалившимся значит закрыть чек при
  /// живых деньгах на той стороне.
  Future<QrWaitOutcome> awaitOutcome(
    int intentId, {
    Future<void>? cancelSignal,
  }) async {
    var cancelled = false;
    unawaited(cancelSignal?.then((_) => cancelled = true));

    final deadline = _now().add(patience);
    QrRefusal? lastRefusal;

    while (true) {
      final round = await step(
        intentId,
        deadline: deadline,
        cancel: cancelled,
        lastRefusal: lastRefusal,
      );
      final outcome = round.outcome;
      if (outcome != null) return outcome;
      lastRefusal = round.refusal;
      await Future<void>.delayed(pollEvery);
    }
  }

  /// **Один круг** ожидания — тело [awaitOutcome], вынутое наружу.
  ///
  /// # Зачем круг, а не цикл
  ///
  /// Потому что на браузерном терминале ждать некому. Вкладка не может
  /// держать кадр провода три минуты, пока покупатель ищет очки: кадр
  /// рвётся, вкладку закрывают, планшет засыпает. Поэтому вкладка **спрашивает
  /// кругами** (`pay.qrPoll`), а каждый её вопрос — это ровно один такой
  /// круг на кассе: прочитать строку, решить, сдаться ли, спросить
  /// провайдера один раз.
  ///
  /// **Второй копии цикла не заведено**: [awaitOutcome] — те же круги
  /// подряд с паузой. Две копии одних условий «когда сдаваться» разошлись
  /// бы на первой же правке, и касса с экраном кассы сдавались бы по
  /// одним правилам, а с браузера — по другим.
  ///
  /// [deadline] — **решение кассы**, а не вызывающего: цикл берёт его от
  /// своего начала, провод — от `createdAt` строки плюс терпение из
  /// настройки кассы. Вкладка сказать «жду ещё» не может ничем.
  ///
  /// Возвращает итог, если ожидание кончилось, и последний транзиентный
  /// отказ — в любом случае.
  Future<QrStep> step(
    int intentId, {
    required DateTime deadline,
    bool cancel = false,
    QrRefusal? lastRefusal,
  }) async {
    var refusal = lastRefusal;

    final current = await _reload(intentId);
    if (current == null) {
      return (
        outcome: const QrWaitOutcome(reason: QrWaitReason.gone),
        refusal: refusal,
      );
    }
    if (current.status.isTerminal) {
      return (
        outcome: QrWaitOutcome(
          reason: current.status == QrIntentStatus.paid
              ? QrWaitReason.paid
              : QrWaitReason.settledByProvider,
          intent: current,
        ),
        refusal: refusal,
      );
    }
    if (cancel) {
      final after = await abandon(intentId, why: QrGiveUp.cashier);
      return (
        outcome: QrWaitOutcome(
          reason: after.status.holdsMoney
              ? QrWaitReason.paidAfterGiveUp
              : QrWaitReason.cashierCancelled,
          intent: after,
        ),
        refusal: refusal,
      );
    }
    if (!_now().isBefore(deadline)) {
      final after = await abandon(intentId, why: QrGiveUp.patience);
      return (
        outcome: QrWaitOutcome(
          reason: after.status.holdsMoney
              ? QrWaitReason.paidAfterGiveUp
              : QrWaitReason.patienceSpent,
          intent: after,
          refusal: refusal,
        ),
        refusal: refusal,
      );
    }

    final providerIntentId = current.providerIntentId;
    if (providerIntentId == null) {
      // Создание не доехало. Пробуем ещё раз тем же ключом — это и есть
      // то, ради чего ключ придуман нами, а не взят у провайдера.
      final retry = await begin(
        intentKey: current.intentKey,
        amount: current.amount,
        posId: current.posId,
        receiptNo: current.receiptNo,
        terminalId: current.terminalId,
      );
      if (!retry.isOk) refusal = retry.refusal;
    } else {
      final reply = await _provider.poll(providerIntentId);
      if (reply.isOk) {
        await _absorb(current, reply.value!);
        refusal = null;
      } else {
        refusal = reply.refusal;
        if (!reply.refusal!.isTransient) {
          await _db.paymentIntentDao.applyState(
            id: intentId,
            status: QrIntentStatus.failed,
            refusalCode: reply.refusal!.code,
            refusalMessage: reply.refusal!.message,
          );
          return (
            outcome: QrWaitOutcome(
              reason: QrWaitReason.refused,
              intent: await _reload(intentId),
              refusal: reply.refusal,
            ),
            refusal: refusal,
          );
        }
      }
    }
    return (outcome: null, refusal: refusal);
  }

  /// Касса перестала ждать: кассир нажал «Отмена» или кончилось терпение.
  ///
  /// **Отмена у провайдера обязательна, и её ответ обязателен к чтению.**
  /// Отменить, не спросив что вышло, — способ оставить покупателя без
  /// денег и без товара: он мог заплатить ровно в эту секунду.
  ///
  /// `abandonedAt` ставится **всегда** — и когда отмена удалась, и когда
  /// оказалось оплачено. Это отметка про нас («мы перестали ждать»), а не
  /// про провайдера.
  Future<PaymentIntent> abandon(int intentId, {required QrGiveUp why}) async {
    final current = await _reload(intentId);
    if (current == null) {
      throw StateError('намерение $intentId исчезло');
    }
    await _db.paymentIntentDao.markAbandoned(intentId, _now());

    final providerIntentId = current.providerIntentId;
    if (providerIntentId == null) {
      // Провайдер про это намерение не знает — отменять нечего. Строка
      // остаётся неразобранной: [reconcile] спросит по ключу.
      return (await _reload(intentId))!;
    }

    final reply = await _provider.cancel(providerIntentId);
    if (reply.isOk) {
      await _absorb(current, reply.value!);
    } else if (!reply.refusal!.isTransient) {
      await _db.paymentIntentDao.applyState(
        id: intentId,
        status: QrIntentStatus.cancelled,
        refusalCode: reply.refusal!.code,
        refusalMessage: reply.refusal!.message,
      );
    }
    // Транзиентный отказ отмены **не** переводит состояние: не дозвонились
    // — значит не знаем, отменено ли, и объявлять отменённым нельзя.
    return (await _reload(intentId))!;
  }

  /// Спросить провайдера про все неразобранные намерения.
  ///
  /// Зовётся **при старте кассы** и после возвращения связи. Это и есть
  /// весь ответ на «подтверждение пришло, пока касса была выключена»:
  /// подтверждение никуда не делось, оно лежит у провайдера, и спросить
  /// про него — единственный способ узнать.
  ///
  /// Возвращает те намерения, у которых **деньги есть, а чека нет**: их
  /// показывает экран разбора.
  Future<List<PaymentIntent>> reconcile() async {
    final pending = await _db.paymentIntentDao.unresolved();
    for (final intent in pending) {
      final providerIntentId = intent.providerIntentId;
      if (providerIntentId == null) {
        // Ид провайдера не доехал — спрашиваем **тем же ключом**.
        // Провайдер ответит прежним намерением, если оно у него есть.
        final reply = await _provider.create(
          intentKey: intent.intentKey,
          amount: intent.amount,
          orderNo: intent.receiptNo?.toString(),
        );
        if (reply.isOk) {
          final creation = reply.value!;
          await _db.paymentIntentDao.attachProviderIntent(
            id: intent.id,
            providerIntentId: creation.providerIntentId,
            status: creation.status,
            qrPayload: creation.qrPayload,
            expiresAt: creation.expiresAt,
          );
          final state = await _provider.poll(creation.providerIntentId);
          if (state.isOk) {
            await _absorb((await _reload(intent.id))!, state.value!);
          }
        }
        continue;
      }
      final reply = await _provider.poll(providerIntentId);
      if (reply.isOk) {
        await _absorb(intent, reply.value!);
      }
      // Отказ опроса при разборе — молчание, а не порча: строка остаётся
      // неразобранной и попадёт в следующий разбор.
    }
    return _db.paymentIntentDao.orphanMoney();
  }

  /// Деньги без чека — оплачено, а строки в `Payments` нет.
  Future<List<PaymentIntent>> orphanMoney() =>
      _db.paymentIntentDao.orphanMoney();

  /// Вернуть деньги покупателю.
  ///
  /// План, шаг 5: **может быть неподдержан — тогда отказ значением**.
  /// Молчание здесь худшее из трёх исходов: кассир решил бы, что вернул.
  Future<QrProviderReply<PaymentIntent>> reverse(int intentId) async {
    final current = await _reload(intentId);
    if (current == null) {
      return const QrProviderReply.refused(
        QrRefusal(qrUnknownIntentCode, 'намерения нет в базе кассы'),
      );
    }
    final providerIntentId = current.providerIntentId;
    if (providerIntentId == null) {
      return const QrProviderReply.refused(
        QrRefusal(
          qrUnknownIntentCode,
          'намерение не доехало до провайдера — возвращать нечего',
        ),
      );
    }
    final reply = await _provider.reverse(providerIntentId, current.money);
    if (!reply.isOk) {
      return QrProviderReply.refused(reply.refusal!);
    }
    await _absorb(current, reply.value!);
    return QrProviderReply.ok((await _reload(intentId))!);
  }

  /// Записать деньги намерения в чек — **один раз и только один**.
  ///
  /// Условная запись по `settled_at IS NULL` в базе, а не проверка в коде:
  /// проверка в коде — это гонка с собой, и два подтверждения, приехавшие
  /// вместе, прошли бы её условие оба.
  ///
  /// `false` — «эти деньги уже в чеке»; вызывающий обязан **не** строить
  /// вторую строку `Payments`.
  Future<bool> settle(int intentId, int receiptNo) => _db.paymentIntentDao
      .markSettled(id: intentId, receiptNo: receiptNo, at: _now());

  Future<PaymentIntent?> _reload(int id) => _db.paymentIntentDao.byId(id);

  /// Принять то, что сказал провайдер.
  ///
  /// Подтверждение считается **новым** только когда состояние перешло в
  /// `paid` впервые: опрос зовётся многократно, и наращивать счётчик на
  /// каждом круге значило бы сделать его счётчиком опросов.
  Future<void> _absorb(PaymentIntent current, QrIntentState state) async {
    final becamePaid =
        state.status == QrIntentStatus.paid && !current.status.holdsMoney;
    await _db.paymentIntentDao.applyState(
      id: current.id,
      status: state.status,
      paidAmount: state.paidAmount,
      confirmedAt: state.confirmedAt,
      refusalCode: state.status == QrIntentStatus.failed
          ? qrRejectedCode
          : null,
      refusalMessage: state.message,
      countConfirmation: becamePaid,
    );
  }
}

/// Итог одного круга [QrPaymentCoordinator.step]: `outcome` пуст, пока
/// ждать ещё есть смысл; `refusal` — последний транзиентный отказ.
typedef QrStep = ({QrWaitOutcome? outcome, QrRefusal? refusal});

/// Почему касса перестала ждать.
enum QrGiveUp {
  /// Кассир нажал «Отмена».
  cashier,

  /// Кончилось терпение кассы.
  patience,
}

/// Чем кончилось ожидание.
enum QrWaitReason {
  /// Оплачено, и касса ещё ждала.
  paid,

  /// **Оплачено после того, как касса сдалась.** Деньги списаны, чек
  /// закрыт другим способом или не закрыт вовсе. Ровно тот исход, ради
  /// которого заведена таблица.
  paidAfterGiveUp,

  /// Провайдер сказал последнее слово, и оно не «оплачено».
  settledByProvider,

  /// Кассир прервал ожидание.
  cashierCancelled,

  /// Терпение кассы кончилось.
  patienceSpent,

  /// Отказ, который временем не лечится.
  refused,

  /// Строки намерения больше нет.
  gone,
}

/// Итог ожидания.
class QrWaitOutcome {
  const QrWaitOutcome({required this.reason, this.intent, this.refusal});

  final QrWaitReason reason;
  final PaymentIntent? intent;
  final QrRefusal? refusal;

  /// Деньги пришли — независимо от того, дождалась ли их касса.
  bool get holdsMoney => intent?.status.holdsMoney ?? false;

  @override
  String toString() => 'QrWaitOutcome($reason, $intent)';
}

/// Итог создания намерения.
class QrBeginResult {
  const QrBeginResult.ok(PaymentIntent this.intent, {required this.createdNow})
    : refusal = null;

  const QrBeginResult.refused(QrRefusal this.refusal, this.intent)
    : createdNow = false;

  final PaymentIntent? intent;
  final QrRefusal? refusal;

  /// Намерение заведено **этим** вызовом. `false` у повтора — и это то
  /// самое утверждение, которым доказывается идемпотентность.
  final bool createdNow;

  bool get isOk => refusal == null;
}
