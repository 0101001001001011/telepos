/// Вызываемые отказы эмулятора WebKassa и карта кодов при них.
///
/// # Зачем это отдельным файлом
///
/// **Эмулятор, который не умеет отказать, бесполезен: ветка отказа
/// недостижима, и её сторожа зелены впустую.** Тринадцать веток
/// `WebKassaProvider._mapError`, обе транзиентные ветки
/// `OfflineQueueingProvider._isTransient` и вся машина очереди с повтором до
/// появления этого файла не проходились ни одной живой проверкой: их можно
/// было пройти набором, собрав `WebKassaResponse` руками, — и это доказывало
/// карту соответствий, а не конвейер.
///
/// [kEmulatedCodes] — единственное место, где эмулятор объявляет, что он
/// умеет произвести. Сторож `emulator_test.dart` вынимает числовые `case` из
/// исходника `webkassa_provider.dart` и требует, чтобы каждый нашёлся здесь.
/// Новый код, добавленный в карту продукта и не заведённый тут, красит
/// сторожа в тот же день.
///
/// # Чего этот файл НЕ доказывает
///
/// Что настоящая WebKassa отвечает **этими** кодами на **эти** случаи. Коды
/// сняты с нашей карты разбора, а не с чужого протокола; случаи, при которых
/// эмулятор их выдаёт, придуманы здесь. Совпадение с действительностью
/// проверяется только прогоном по `devkkm.webkassa.kz`.
library;

/// Как отказ вызывается: сам собой по состоянию, или пультом.
enum FaultTrigger {
  /// Возникает из состояния эмулятора без пульта: неверный пароль, истёкший
  /// токен, повтор ключа, нехватка денег, расхождение сумм.
  natural,

  /// Требует пульта `/_emul/*` — иначе случай не воспроизвести.
  console,
}

/// Один вызываемый отказ.
class EmulatedFault {
  const EmulatedFault({
    required this.code,
    required this.text,
    required this.trigger,
    required this.how,
    required this.opens,
  });

  /// Код в конверте `{"Errors":[{"Code": …}]}`. Отрицательные коды в конверт
  /// не едут: их производит **транспорт**, а не тело ответа.
  final int code;

  final String text;
  final FaultTrigger trigger;

  /// Как этот отказ вызвать — дословно, чтобы читалось из README.
  final String how;

  /// Что он открывает в нашем коде.
  final String opens;
}

/// Тринадцать отказов — по одному на каждую ветку `_mapError`, включая
/// `default`.
///
/// Три последних требуют **не ответа, а его отсутствия**, и без них ветки
/// `WebKassaApiClient.post`'s `on SocketException` / `on TimeoutException` /
/// `catch (e)` не достижимы вовсе.
const List<EmulatedFault> kEmulatedFaults = [
  EmulatedFault(
    code: 1,
    text: 'Неверный логин или пароль',
    trigger: FaultTrigger.natural,
    how:
        'POST /api/v4/Authorize с логином или паролем, отличным от --login/--password',
    opens:
        'badCredentials → authorize → FiscalResult.failure → FiscalState.failed',
  ),
  EmulatedFault(
    code: 2,
    text: 'Токен не найден',
    trigger: FaultTrigger.natural,
    how: 'любой путь с Token, которого эмулятор не выдавал (или пустым)',
    opens: 'tokenExpired → _withReauthRetry перевыпуск И постановка в очередь',
  ),
  EmulatedFault(
    code: 3,
    text: 'Срок действия токена истёк',
    trigger: FaultTrigger.natural,
    how: 'подождать --token-ttl (по умолчанию 30 с) и позвать любой путь',
    opens:
        'tokenExpired — та же пара веток, но естественным путём, а не пультом',
  ),
  EmulatedFault(
    code: 6,
    text: 'Касса с таким заводским номером не найдена',
    trigger: FaultTrigger.natural,
    how: 'CashboxUniqueNumber, отличный от --cashbox',
    opens: 'cashboxNotFound — нетранзиентный отказ, очередь его не берёт',
  ),
  EmulatedFault(
    code: 7,
    text: 'Касса заблокирована',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/block {"on": true}',
    opens: 'cashboxBlocked — нетранзиентный отказ',
  ),
  EmulatedFault(
    code: 8,
    text: 'Недостаточно денег в ящике',
    trigger: FaultTrigger.natural,
    how: 'MoneyOperation с OperationType 1 и Sum больше, чем в ящике',
    opens: 'notEnoughMoney → отказ moneyOut',
  ),
  EmulatedFault(
    code: 9,
    text: 'Ошибка проверки документа',
    trigger: FaultTrigger.natural,
    how:
        'чек, у которого сумма позиций не равна сумме оплат (или НДС не сошёлся при --vat)',
    opens:
        'validation — пересчёт денег, потерянная копейка скидки, бонус мимо оплат',
  ),
  EmulatedFault(
    code: 11,
    text: 'Смена не может быть открыта',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/shift {"locked": true}, затем любой чек',
    opens: 'shiftError',
  ),
  EmulatedFault(
    code: 12,
    text: 'Смена открыта более 24 часов',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/shift {"stale": true}, затем любой чек',
    opens: 'shiftError',
  ),
  EmulatedFault(
    code: 13,
    text: 'Нет открытой смены',
    trigger: FaultTrigger.natural,
    how:
        'ZReport при закрытой смене (или после POST /_emul/shift {"open": false})',
    opens: 'shiftError на Z-отчёте',
  ),
  EmulatedFault(
    code: 14,
    text: 'Документ с таким ExternalCheckNumber уже зарегистрирован',
    // Два входа, и оба нужны. Естественный (повтор ключа) — единственный,
    // который доказывает **память оператора**: документ действительно лежит
    // у него, и признак у него есть. Пультовой нужен там, где памяти не
    // хватает: первая отправка до оператора не дошла в этом процессе (её
    // съел `/_emul/kill`), а ответить надо так, как ответил бы оператор,
    // у которого она всё-таки легла.
    trigger: FaultTrigger.natural,
    how:
        'повторить check или MoneyOperation с тем же ExternalCheckNumber; '
        'либо POST /_emul/fault {"path": "/api/v4/check", "code": 14}',
    opens:
        '_failure → _mapError(14) → duplicate, нетранзиентный: первая линия '
        '→ чек помечен непрофискализованным с названной причиной; '
        'replay/retryFailed → строка переводится в failed с той же причиной '
        'и ждёт человека (признак по ключу не дозапрашивается — протокол '
        'такого пути не имеет)',
  ),
  EmulatedFault(
    code: 15,
    text: 'Нет открытой смены для X-отчёта',
    trigger: FaultTrigger.natural,
    how: 'XReport при закрытой смене',
    opens: 'shiftError на X-отчёте',
  ),
  EmulatedFault(
    code: 18,
    text: 'Превышен лимит автономных документов',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/offline {"on": true, "limit": 1}, затем два чека',
    opens: 'offlineLimitExceeded — нетранзиентный отказ',
  ),
  EmulatedFault(
    code: 1013,
    text: 'Автономный режим не разрешён этой кассе',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/offline {"on": true, "supported": false}',
    opens: 'offlineNotSupported',
  ),
  EmulatedFault(
    code: 999,
    text: 'Неизвестная ошибка оператора',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/fault {"path": "/api/v4/check", "code": 999}',
    opens: 'default: → FiscalErrorCode.unknown — четырнадцатая ветка _mapError',
  ),
  EmulatedFault(
    code: -1,
    text: 'сокет закрыт без ответа',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/kill {"count": 1}',
    // Измерено 2026-09-15: закрытый без ответа сокет даёт у клиента
    // `HttpException` («Connection closed before full header was
    // received»), а не `SocketException`. До правки он падал в общий
    // `catch` как −3; теперь его берёт ветка `on IOException` → −1.
    opens:
        'HttpException (IOException) в _defaultSend → network → ВСЯ '
        'очередь: _enqueue, replay, stoppedOnNetwork',
  ),
  EmulatedFault(
    code: -2,
    text: 'молчание дольше тайм-аута клиента',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/latency {"ms": 31000} — клиент ждёт 30 с',
    opens: 'TimeoutException → network, тот же вход в очередь',
  ),
  EmulatedFault(
    code: -3,
    text: 'ответ не JSON',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/malformed {"count": 1}',
    opens:
        'WebKassaResponse.parse: json == null и HTTP < 400 → errorCode -3 → network',
  ),
  EmulatedFault(
    code: -4,
    text: 'запрос не собран кассой',
    // Эмулятор этот код не отвечает и ответить не может: отказ случается
    // ДО сокета. Производит его адрес эмулятора, вписанный в настройки без
    // узла, — то есть тот же прибор, взятый неправильно. Достижимость
    // доказывает `test/data/fiscal/cyrillic_receipt_fiscalized_test.dart`.
    trigger: FaultTrigger.natural,
    how: 'baseUrl «http://» (без узла) или «ftp://…» в фискальных настройках',
    opens:
        'ArgumentError/FormatException до сокета → requestNotBuilt → НЕ '
        'очередь: строка failed с причиной на экране нефискализованных чеков',
  ),
  EmulatedFault(
    code: -5,
    text: 'HTTP 5xx/408/429 с телом не-JSON',
    trigger: FaultTrigger.console,
    how: 'POST /_emul/http {"status": 503, "count": 1}',
    opens:
        'WebKassaResponse.parse: статус 5xx/408/429 без кода оператора → '
        'operatorUnavailable → очередь (до правки: unknown, мимо очереди)',
  ),
  EmulatedFault(
    code: -6,
    text: 'TLS не сошёлся',
    // Как и −4, производится не ответом эмулятора, а тем же прибором,
    // взятым неправильно: адрес `https://` к его порту без TLS.
    trigger: FaultTrigger.natural,
    how: 'baseUrl «https://127.0.0.1:<порт эмулятора>» в фискальных настройках',
    opens:
        'HandshakeException (TlsException) → tlsRejected → НЕ очередь (до '
        'правки: −3 → network → «в очереди»)',
  ),
];

/// Коды разбора, которые **сокет произвести не может** — и где их
/// достижимость доказана вместо эмулятора.
///
/// Заведено, чтобы сторож `emulator_test.dart` не пришлось обманывать:
/// записать такой код в [kEmulatedFaults] значило бы утверждать, что эмулятор
/// его производит. −7 — исключение, не являющееся вводом-выводом (сбой кода
/// кассы); ни одним поведением сервера оно не вызывается, и проба подменяет
/// `send:` — названо в самой пробе.
const Map<int, String> kCodesNotProducibleBySocket = {
  -7: 'test/data/fiscal/webkassa_failure_classification_test.dart',
};

/// Множество кодов, которые эмулятор умеет произвести. Читается сторожем.
Set<int> get kEmulatedCodes => {for (final f in kEmulatedFaults) f.code};

/// Отказ, поставленный пультом `/_emul/fault` в очередь на конкретный путь.
class PendingFault {
  PendingFault({
    required this.path,
    required this.code,
    required this.text,
    required this.count,
    required this.afterN,
  });

  final String path;
  final int code;
  final String text;

  /// Сколько раз ещё отвечать этим кодом.
  int count;

  /// Сколько успешных вызовов пропустить прежде.
  int afterN;

  Map<String, Object?> toJson() => {
    'path': path,
    'code': code,
    'text': text,
    'count': count,
    'afterN': afterN,
  };
}
