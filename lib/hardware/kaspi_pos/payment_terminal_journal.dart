import 'dart:async';

/// Один обмен с терминалом оплаты: что ушло в сокет и что пришло обратно.
///
/// # Почему кадр показывается как есть
///
/// Тот же довод, что у тела запроса на вкладке фискального оператора:
/// диагностика обмена — это сверка с тем, что ждёт прибор, и приглаженное
/// представление врёт ровно там, где его читают. Кадр Kaspi — `STX`, текст,
/// `ETX`; наладчику нужен именно текст между ними, по нему видно и вид
/// операции, и сумму, и номер чека.
///
/// # Почему рядом с кадром лежит разбор продукта, а не наш собственный
///
/// [approved], [approvalCode] и [refusal] получены **тем же
/// `_parsePurchaseResponse`, которым продукт принимает решение о деньгах**.
/// Нарисовать их своим разбором значило бы завести вторую раскладку, которая
/// однажды разойдётся с первой молча, — у проекта уже был такой случай с
/// предпросмотром чека, и он разобран в докстринге `escpos_text_preview.dart`.
class PaymentTerminalExchange {
  const PaymentTerminalExchange({
    required this.at,
    required this.operation,
    required this.request,
    required this.address,
    this.response,
    this.approved = false,
    this.approvalCode,
    this.transactionId,
    this.refusal,
  });

  final DateTime at;

  /// Вид операции, снятый **с первого байта кадра**, а не переданный
  /// вызывающим: кадр — единственное, что на самом деле уходит в прибор, и
  /// подпись, разошедшаяся с кадром, хуже отсутствующей.
  final PaymentTerminalOperation operation;

  /// Текст кадра между `STX` и `ETX`.
  final String request;

  /// Куда шли: адрес терминала из привязки.
  final String address;

  /// Текст ответа. `null` — ответа не было вовсе (тайм-аут, обрыв).
  final String? response;

  final bool approved;

  /// Код авторизации. Есть только у одобренной операции.
  final String? approvalCode;

  final String? transactionId;

  /// Причина отказа — дословно от прибора либо названная кассой
  /// («ответа нет», «связь оборвана»).
  final String? refusal;
}

/// Вид операции по первому байту кадра. Числа сняты с продукта
/// (`_buildPurchaseCommand`, `_buildReversalCommand`, `requestRefund`).
enum PaymentTerminalOperation {
  purchase,
  reversal,
  refund,

  /// Кадр, первого байта которого мы не знаем. Не «прочее», а именно
  /// «неизвестно»: подписать чужой кадр покупкой значило бы соврать.
  unknown;

  static PaymentTerminalOperation ofFrame(String payload) =>
      switch (payload.isEmpty ? '' : payload[0]) {
        '1' => PaymentTerminalOperation.purchase,
        '3' => PaymentTerminalOperation.reversal,
        '4' => PaymentTerminalOperation.refund,
        _ => PaymentTerminalOperation.unknown,
      };
}

/// Память об обменах с терминалом оплаты — то, чего у кассы не было вовсе.
///
/// # Почему в памяти, а не в базе
///
/// Тот же довод, что у [CashDrawerJournal] (`cash_drawer_journal.dart`).
/// Вопрос, на который отвечает эта запись, — «разговаривает ли касса с
/// терминалом **сейчас**»: её читает наладчик при запуске и кассир, у
/// которого минуту назад не прошла карта. Для него хватает последних обменов
/// текущего запуска.
///
/// Вопрос «какие операции прошли по терминалу за смену» — **другой**, и
/// отвечать на него этой записью нельзя: это учётный вопрос, и у него свои
/// строки `Payments` с номером транзакции и кодом авторизации, своё право и
/// своё хранение. Завести здесь таблицу значило бы выдать диагностику за
/// учёт — и первый же спор о неприходе денег пошёл бы по записи, которая
/// теряется при перезапуске и ничего не доказывает.
///
/// # Почему у неё есть общий на процесс экземпляр
///
/// `KaspiPosService` не живёт в контейнере зависимостей: он создаётся заново
/// на каждую операцию, тремя разными местами (оплата, возврат, проверка связи
/// с экрана настроек), и ни одно из них не умеет доставать сотрудников. Общий
/// экземпляр — единственный способ, которым запись попадает в журнал со
/// **всех** путей сразу; иначе экран показывал бы оплату и молчал про
/// возвраты, а отличить это от «возвратов не было» было бы нечем.
///
/// Вторым источником правды он при этом не становится: продукт из журнала
/// **ничего не читает** — ни одна ветка оплаты, возврата или печати сюда не
/// заглядывает. Это память для глаз человека, и только.
///
/// # Чего этот журнал НЕ доказывает
///
/// **Что деньги списаны.** Одобрение — это слово терминала; банк за ним
/// стоит свой, и касса его не видит. И обратное: отсутствие записи означает
/// «касса не отправляла кадра», а не «терминал ничего не делал» — операцию
/// могли провести с самого терминала.
class PaymentTerminalJournal {
  PaymentTerminalJournal({this.limit = 50});

  /// Общий на процесс журнал — см. раздел докстринга выше.
  static final PaymentTerminalJournal shared = PaymentTerminalJournal();

  final int limit;
  final List<PaymentTerminalExchange> _exchanges = [];
  final StreamController<List<PaymentTerminalExchange>> _changes =
      StreamController<List<PaymentTerminalExchange>>.broadcast();

  /// Последние обмены, новые первыми.
  List<PaymentTerminalExchange> recent() =>
      List.unmodifiable(_exchanges.reversed);

  /// Поток для экрана диагностики: первым событием — то, что уже есть, иначе
  /// экран, открытый после оплаты, показал бы пустоту.
  Stream<List<PaymentTerminalExchange>> watch() async* {
    yield recent();
    yield* _changes.stream;
  }

  void record(PaymentTerminalExchange exchange) {
    _exchanges.add(exchange);
    if (_exchanges.length > limit) {
      _exchanges.removeRange(0, _exchanges.length - limit);
    }
    if (!_changes.isClosed) _changes.add(recent());
  }

  /// Забыть всё. Нужна набору: общий экземпляр переживает пробу, и вторая
  /// проба видела бы обмены первой.
  void clear() {
    _exchanges.clear();
    if (!_changes.isClosed) _changes.add(recent());
  }

  Future<void> dispose() => _changes.close();
}
