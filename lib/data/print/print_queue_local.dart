import 'package:talker/talker.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/hardware/printer/printer_manager.dart' show PrintResult;

/// Всё, что очередь умеет делать с принтером: отдать ему готовый чек целиком.
///
/// **Отдаёт байты ровно один раз.** Транспорт (`WifiPrinterManager.writeRaw`,
/// `LinuxPrinterManager`) повторяет только *соединение* — соединение, которое
/// не удалось, ничего не напечатало, а полезная нагрузка, однажды сданная в
/// сокет, повторно отправлена быть не может: TCP не говорит, сколько из неё
/// дошло до бумаги, и повтор печатает хвост чека, а следом целый чек. Повтор
/// **задания** — дело очереди, потому что ключ идемпотентности живёт здесь
/// (И29).
///
/// Тип намеренно не свой, а `PrintResult` из `printer_manager.dart`: второй
/// результат печати рядом с существующим — это две реализации одного понятия,
/// что в этом проекте запрещено. Привязка к живому принтеру поэтому
/// однострочная: `(bytes) => printerManager.printReceipt(bytes)`.
typedef PrintTransport = Future<PrintResult> Function(Uint8List payloadBytes);

/// [PrintQueue] с единственным писателем на принтер.
///
/// ## Что здесь гарантируется
///
/// **Неделимость — это единственный писатель, а не «обычно по очереди».** Пока
/// задание пишется в принтер, второе начаться не может: за всю печать отвечает
/// один цикл ([_pumpLoop]), и вход в него закрыт, пока предыдущий не вышел
/// ([_running]). Два кассира, чьи чеки перемешались, — это отказ, названный
/// архитектурой прямо (docs/system-architecture.md, раздел 8, «Общий принтер —
/// это очередь, а не общий доступ»).
///
/// **Срок делает проблему видимой.** Задание, не напечатанное к
/// [PrintJob.expiresAt], переводится в [PrintJobState.expired] — оно остаётся в
/// очереди с причиной и **перестаёт повторяться**. «Висит вечно» и «тихо
/// выброшено» одинаково неверны (И29).
///
/// **Идемпотентность живёт здесь.** Подтверждённое задание не отправляется
/// второй раз, что бы ни просил вызывающий: перед каждой отправкой очередь
/// спрашивает [PrintJobStore.isConfirmedPrinted], и это же условие проверяется
/// **до** каждой записи в хранилище — а не ловится как исключение. Хранилище
/// действительно бросает [StateError] на возврате подтверждённого задания в
/// нетерминальное состояние, но исключение как способ управления потоком стёрло
/// бы разницу между «так и задумано» и «хранилище сломалось».
///
/// ## Чего здесь нет, и почему это решение
///
/// **`getStatus()` через очередь не проходит, и это сознательно.** Опрос
/// состояния пишет в тот же сокет, что и чеки, но правило единственного писателя
/// на него не распространяется. Причин две. Первая: у опроса нет ничего, из чего
/// состоит задание, — ни владельца, ни идентификатора идемпотентности, ни срока;
/// поставить его в очередь заданий значит завести второй, безымянный вид
/// задания. Вторая, важнее: очередь заставила бы опрос ждать за чеками, а чек —
/// ждать за опросом, и второе нарушает И30 прямо («печать никогда не уступает
/// опросу состояния»). Гонка между опросом и записью настоящая, и она закрыта
/// там, где обе стороны видны одновременно, — замком на сокете внутри драйвера
/// (`wifi_printer.dart`, `_socketLock`, задача 4). Очередь охраняет *задания*,
/// драйвер охраняет *сокет*; ни одно из двух не заменяет другое.
///
/// **Отступ повтора не хранится на диске.** [PrintJob.attempts] хранится — он
/// ответ оператору на вопрос «сколько раз пытались». А вот «когда пробовать
/// снова» и «сколько попыток сделано в эту возможность» живут в памяти процесса
/// ([_retryNotBefore], [_tried]): перезапуск программы — это и есть новая
/// возможность, и задание, исчерпавшее попытки до перезапуска, обязано
/// получить свежие после него.
class PrintQueueLocal implements PrintQueue {
  /// [transport] — единственный путь байтов к принтеру.
  ///
  /// [clock] вносится, а не берётся из `DateTime.now` внутри: срок наступает по
  /// часам, и тест, проверяющий истечение срока, не должен ждать реального
  /// срока. Те же часы обязаны стоять и в [PrintJobStore] — иначе задание,
  /// записанное одними часами, убиралось бы по другим.
  ///
  /// Бросает [ArgumentError] на непозволительных настройках повтора: ноль
  /// попыток — это очередь, которая не печатает, отрицательный отступ — это
  /// отсутствие отступа под видом настройки.
  PrintQueueLocal({
    required PrintJobStore store,
    required PrintTransport transport,
    Talker? logger,
    DateTime Function()? clock,
    int maxAttemptsPerOpportunity = defaultMaxAttemptsPerOpportunity,
    Duration firstBackoff = defaultFirstBackoff,
    Duration maxBackoff = defaultMaxBackoff,
    Duration finishedRetention = defaultFinishedRetention,
    Duration housekeepingInterval = defaultHousekeepingInterval,
  }) : _store = store,
       _transport = transport,
       _logger = logger,
       _clock = clock ?? DateTime.now,
       _maxAttempts = maxAttemptsPerOpportunity,
       _firstBackoff = firstBackoff,
       _maxBackoff = maxBackoff,
       _finishedRetention = finishedRetention,
       _housekeepingInterval = housekeepingInterval {
    if (_maxAttempts <= 0) {
      throw ArgumentError.value(
        _maxAttempts,
        'maxAttemptsPerOpportunity',
        'очередь, которой разрешён ноль попыток, не печатает ничего',
      );
    }
    if (_firstBackoff < Duration.zero) {
      throw ArgumentError.value(
        _firstBackoff.toString(),
        'firstBackoff',
        'отрицательный отступ повтора — это отсутствие отступа, записанное '
            'как настройка',
      );
    }
    if (_maxBackoff < _firstBackoff) {
      throw ArgumentError.value(
        _maxBackoff.toString(),
        'maxBackoff',
        'потолок отступа меньше первого отступа: первый же повтор нарушил бы '
            'собственный потолок (firstBackoff=$_firstBackoff)',
      );
    }
    if (_housekeepingInterval <= Duration.zero) {
      throw ArgumentError.value(
        _housekeepingInterval.toString(),
        'housekeepingInterval',
        'уборка на каждом проходе очереди — это уборка вместо печати',
      );
    }
  }

  /// Сколько раз задание отправляется в принтер за одну **возможность**.
  ///
  /// **Сколько это стоит по времени, сказано числом, а не «немного», и число
  /// названо для обоих проводов.** Одна отправка — это один `writeRaw`, и он
  /// ограничен собственным сроком провода, внутри которого уже лежат все его
  /// попытки *соединения*:
  ///
  /// | Провод | `retryBudgetMs` | Одна возможность |
  /// | --- | --- | --- |
  /// | Wi-Fi (`WifiPrinterManager`) | 2500 | 4 × 2,5 + 7 = **17 с** |
  /// | USB/serial (`LinuxPrinterManager`) | 3000 | 4 × 3 + 7 = **19 с** |
  ///
  /// Опубликованная граница — **19 секунд**: она обязана быть верна на худшем
  /// из проводов, а не на том, по которому её однажды посчитали. Полезная
  /// нагрузка при этом уходит не более одного раза за вызов (см.
  /// [PrintTransport]), поэтому числа не перемножаются: четыре попытки очереди
  /// — это **четыре** отправки чека, а не двенадцать. Отступы между ними —
  /// 1 + 2 + 4 с. Ни одна из этих секунд не лежит на пути продажи (И30).
  ///
  /// **Одна отправка = один срок, и это держится контрактом, а не удачей.**
  /// `PrinterManager.writeRaw` подключается сам; вызывающий (`print_module
  /// .printToBoundPrinter`) отдельного `connect()` не делает. Пока делал,
  /// каждая попытка платила два срока — на Wi-Fi выходило 4 × 5 + 7 = 27 с
  /// против написанных 17, и написанное выглядело точным.
  ///
  /// Пять попыток очереди поверх трёх попыток транспорта дали бы пятнадцать
  /// отправок и полминуты — это поймал обзор задачи 4 до того, как оно
  /// уехало, и число здесь выбрано так, чтобы сумма называлась вслух.
  static const int defaultMaxAttemptsPerOpportunity = 4;

  static const Duration defaultFirstBackoff = Duration(seconds: 1);

  /// Потолок отступа: удвоение без потолка превратило бы «ждать дольше» в
  /// «не пробовать больше никогда», а срок задания и без того ограничен.
  static const Duration defaultMaxBackoff = Duration(seconds: 8);

  /// Сколько выполненное задание лежит в базе, прежде чем его уберёт уборка.
  ///
  /// Сутки — это смена и запас: оператор, разбирающийся утром с тем, что было
  /// вечером, должен увидеть, чем кончилось. Память о **подтверждённых**
  /// идентификаторах этой уборкой не трогается вовсе и живёт по своему, куда
  /// более длинному правилу ([PrintJobStore.confirmationRetention]).
  static const Duration defaultFinishedRetention = Duration(days: 1);

  static const Duration defaultHousekeepingInterval = Duration(hours: 1);

  /// Через сколько очередь возвращается к себе, если не смогла даже спросить
  /// у хранилища, чего ждать.
  ///
  /// Тридцать секунд — это заметно меньше самого короткого осмысленного срока
  /// задания и заметно больше, чем длится обычная недоступность базы (замок
  /// на время чужой транзакции). Смысл числа не в точности, а в том, что оно
  /// **есть**: очередь, оставшаяся без будильника, не замечает сроков вообще.
  static const Duration wakeAfterFailure = Duration(seconds: 30);

  /// Причина, с которой очередь поднимает задание, застигнутое перезапуском
  /// процесса на середине записи в принтер.
  ///
  /// Видна оператору как есть, поэтому написана по-человечески, а не кодом.
  static const String interruptedByRestartReason =
      'Печать прервана перезапуском программы';

  final PrintJobStore _store;

  /// Журнал — **единственное место, где остаётся исключение** (задача 16,
  /// круг правки 3).
  ///
  /// До неё у очереди журнала не было вовсе, и текст исключения жил
  /// только в сообщении исхода. Круг правки 2 завернул это сообщение в
  /// `safeErrorText` (утечка нутра на провод, сторож
  /// `no_raw_exception_on_wire_test`) — и вместе с утечкой унёс бы
  /// сведения: `safeErrorText` отдаёт **имя типа**, а вызывающий на
  /// ветке отказа пишет сообщение без исключения и стека
  /// (`LocalPaymentService._printReceipt`). Кассе осталась бы строка
  /// «Очередь печати не приняла задание: StateError» — и больше нигде
  /// ничего. Здесь исключение и стек остаются целиком: журнал кассы —
  /// её собственный процесс, а не кадр на проводе.
  ///
  /// `null` — записывать некуда (проба без журнала); тот же приём
  /// осторожной деградации, что у остальных необязательных портов.
  final Talker? _logger;
  final PrintTransport _transport;
  final DateTime Function() _clock;
  final int _maxAttempts;
  final Duration _firstBackoff;
  final Duration _maxBackoff;
  final Duration _finishedRetention;
  final Duration _housekeepingInterval;

  /// Сколько отправок сделано по заданию и **в какую возможность**.
  ///
  /// Не то же самое, что [PrintJob.attempts]: тот считает попытки за всю жизнь
  /// задания и хранится, этот ограничивает одну возможность и живёт в памяти.
  ///
  /// Номер возможности хранится вместе со счётчиком, а не стирается вместе с
  /// ним, и это не бухгалтерия. Новая возможность обязана вернуть заданию
  /// бюджет попыток — но не обязана делать вид, что задание никогда не падало.
  /// Пока запись просто стиралась, обречённое задание выглядело свежим и,
  /// будучи старше, вставало **впереди чека покупателя, стоящего у кассы**:
  /// тот ждал за повтором, который уже провалился и провалится снова. См.
  /// [_pickNext].
  final Map<String, ({int opportunity, int attempts})> _tried =
      <String, ({int opportunity, int attempts})>{};

  /// Номер текущей возможности. Растёт от любого признака того, что принтер
  /// жив: удачной печати любого задания ([_runOne]) или ручного повтора
  /// ([retry]). Перезапуск процесса — тоже новая возможность, и он обнуляет
  /// [_tried] целиком.
  int _opportunity = 0;

  /// Сколько отправок сделано по заданию **в текущую возможность**.
  int _attemptsIn(String jobId) {
    final made = _tried[jobId];
    if (made == null || made.opportunity != _opportunity) return 0;
    return made.attempts;
  }

  /// Пробовали ли это задание хоть когда-нибудь в этом процессе.
  ///
  /// Не то же, что `_attemptsIn(id) > 0`: новая возможность возвращает бюджет,
  /// но не стирает того, что задание уже падало, — и ровно это отличие ставит
  /// ещё не пробованный чек впереди повтора.
  bool _wasTried(String jobId) => _tried.containsKey(jobId);

  /// Не раньше этого момента задание пробуется снова. См. [_backoffAfter].
  final Map<String, DateTime> _retryNotBefore = <String, DateTime>{};

  Future<void>? _startFuture;

  /// Текущий проход очереди, `null` — когда очередь без работы.
  ///
  /// **Это и есть единственность писателя.** Не «замок вокруг записи в сокет»,
  /// а «второй проход не начинается»: пока это поле не `null`, [_kick] только
  /// помечает, что нужен ещё один проход, и возвращается.
  Future<void>? _running;

  /// Кто-то попросил очередь поработать, и эта просьба ещё не отработана.
  ///
  /// Не «начать проход» (проход может уже идти), а именно «нужен ещё один
  /// осмотр очереди». Флаг **снимается в начале осмотра, а не в конце**: иначе
  /// задание, сданное во время осмотра, обнулилось бы вместе с просьбой и
  /// дождалось бы только будильника. Так это и было найдено — тестом на
  /// перемешивание, где оба задания сдавались разом и ни одно не печаталось.
  bool _wanted = false;

  bool _disposed = false;
  Timer? _wakeTimer;
  DateTime? _nextWakeAt;
  DateTime? _lastHousekeepingAt;

  /// Когда очередь сама вернётся к себе, или `null`, если возвращаться не за
  /// чем (активных заданий нет).
  ///
  /// Диагностика: сама очередь на это значение не смотрит. Но **отсутствие**
  /// будильника при живых заданиях и есть «висит вечно», поэтому значение
  /// открыто наружу — чтобы это состояние можно было увидеть и проверить, а
  /// не выводить из молчания.
  DateTime? get nextWakeAt => _nextWakeAt;

  /// Отказ, случившийся в проходе, которого никто не ждал.
  ///
  /// [_kick] намеренно не ожидается ([submit] обязан вернуться сразу — И30),
  /// поэтому отказ хранилища внутри прохода некому поймать: он стал бы
  /// необработанной асинхронной ошибкой. Проглотить его тоже нельзя — это
  /// заглушка, молча вернувшая правдоподобное. Поэтому он запоминается и
  /// выбрасывается первому, кто дождётся простоя ([whenIdle], [sweep]).
  Object? _pendingFailure;
  StackTrace? _pendingFailureStack;

  /// Поднимает задания, застигнутые перезапуском процесса на середине записи, и
  /// берётся за то, что стоит в очереди.
  ///
  /// **Вызывается один раз при старте, до того как что-либо будет напечатано.**
  /// Строка в [PrintJobState.printing] означает ровно одно: процесс умер, пока
  /// байты уходили в принтер. Такое задание не терминально, поэтому уборка его
  /// не тронет, и не повторяемо ([PrintJob.renewedUntil] отказывает
  /// `printing` намеренно), поэтому само оно не поедет — то есть оно висит
  /// вечно, ровно то, что И29 запрещает. Задача 2 написала
  /// [PrintJobStore.failInterruptedPrinting] и оставила её без вызывающего,
  /// назвав это в отчёте; вызывающий — здесь.
  ///
  /// Повторный вызов безвреден: восстановление идемпотентно, а [submit] и
  /// [retry] дожидаются его сами — очередь, у которой забыли позвать [start],
  /// не должна молча не печатать.
  ///
  /// **Запоминается только удачный старт.** Пока здесь стояло
  /// `_startFuture ??= _start()`, один-единственный отказ базы в момент
  /// запуска (замок на время чужой транзакции, ошибка ввода-вывода) оставлял в
  /// поле **отказавший** `Future` навсегда. Дальше каждый [submit] дожидался
  /// его, ловил исключение своим `catch` и отвечал
  /// [PrintSubmitStatus.rejected] — то есть чек не попадал даже в базу. Деньги
  /// взяты, бумаги нет, задания нет; ровно то состояние, ради устранения
  /// которого написана эта очередь, только включённое одной неудачей при
  /// старте и снимаемое одним перезапуском программы. Поэтому отказ поле
  /// очищает: следующий вызывающий пробует заново.
  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    try {
      await _store.failInterruptedPrinting(interruptedByRestartReason);
    } catch (_) {
      // Отказавший старт не запоминается — см. доку [start]. Очистка стоит до
      // `rethrow`, поэтому тот, кто уже ждёт этот `Future`, всё равно получит
      // отказ с причиной, а следующий начнёт с чистого места.
      _startFuture = null;
      rethrow;
    }
    _kick();
  }

  @override
  Future<PrintSubmitOutcome> submit(PrintJob job) async {
    // Ни одна ветка отсюда не бросает: исключение попало бы на путь продажи,
    // где его ловит `try/catch` экрана оплаты, и всё вернулось бы к сегодняшнему
    // положению, при котором неудачная печать теряется вместе с локальными
    // переменными.
    try {
      await start();

      if (job.state != PrintJobState.queued) {
        return PrintSubmitOutcome.rejected(
          job.id,
          'Задание сдаётся в очередь стоящим в ней, а пришло в состоянии '
          '"${job.state.name}"',
        );
      }

      // Порядок важен: подтверждение переживает само задание, поэтому «уже
      // печаталось» спрашивается у памяти подтверждений, а не у строки задания.
      if (await _store.isConfirmedPrinted(job.id)) {
        return PrintSubmitOutcome.duplicate(job.id);
      }
      if (await _store.jobById(job.id) != null) {
        return PrintSubmitOutcome.duplicate(job.id);
      }

      await _store.put(job);
      _kick();
      return PrintSubmitOutcome.accepted(job.id);
    } catch (e, st) {
      _logger?.error('PrintQueue: задание ${job.id} не принято', e, st);
      return PrintSubmitOutcome.rejected(
        job.id,
        'Очередь печати не приняла задание: ${safeErrorText(e)}',
      );
    }
  }

  @override
  Stream<List<PrintJob>> watch({int? terminalId}) =>
      _store.watchJobs(terminalId: terminalId);

  @override
  Future<PrintSubmitOutcome> retry(
    String jobId, {
    required Duration extendBy,
  }) async {
    try {
      await start();

      if (extendBy <= Duration.zero) {
        return PrintSubmitOutcome.rejected(
          jobId,
          'Продлить задание на ${extendBy.inMilliseconds} мс нельзя: '
          'повторить и сразу просрочить — не просьба',
        );
      }

      if (await _store.isConfirmedPrinted(jobId)) {
        return PrintSubmitOutcome.duplicate(jobId);
      }

      final job = await _store.jobById(jobId);
      if (job == null) {
        return PrintSubmitOutcome.rejected(
          jobId,
          'Задание $jobId очереди печати неизвестно — повторять нечего',
        );
      }

      // Каждый отказ называет причину. Молчаливый отказ на экране повтора
      // выглядит как сработавшая кнопка, после которой ничего не произошло.
      switch (job.state) {
        case PrintJobState.printed:
          // Строка ещё цела, а память подтверждения уже забыта по сроку
          // хранения. Ответ обязан остаться прежним: второго чека не будет.
          return PrintSubmitOutcome.duplicate(jobId);
        case PrintJobState.cancelled:
          return PrintSubmitOutcome.rejected(
            jobId,
            'Задание $jobId отменено оператором: напечатать отменённый чек '
            'нельзя. Нужен такой же чек — заводится новое задание с новым '
            'идентификатором',
          );
        case PrintJobState.printing:
          return PrintSubmitOutcome.rejected(
            jobId,
            'Задание $jobId прямо сейчас печатается — второй его экземпляр в '
            'очереди и есть то перемешивание, которое очередь запрещает',
          );
        case PrintJobState.queued:
        case PrintJobState.failed:
        case PrintJobState.expired:
          break;
      }

      // Момент строит владелец очереди, теми же часами, которыми он меряет
      // истечение срока. Абсолютный момент, приехавший по проводу от браузера
      // с отстающими часами, пришёл бы уже просроченным, и касса отказала бы в
      // повторе исправного задания с причиной, выглядящей правильной.
      final now = _clock();
      await _store.put(job.renewedUntil(now.add(extendBy), now: now));

      // Ручной повтор — новая возможность: и счётчик попыток этой возможности,
      // и отступ начинаются заново.
      _forget(jobId);
      _kick();
      return PrintSubmitOutcome.accepted(jobId);
    } catch (e, st) {
      _logger?.error('PrintQueue: повтор задания $jobId не удался', e, st);
      return PrintSubmitOutcome.rejected(
        jobId,
        'Очередь печати не смогла повторить задание $jobId: ${safeErrorText(e)}',
      );
    }
  }

  @override
  Future<bool> cancel(String jobId) async {
    final job = await _store.jobById(jobId);
    if (job == null || job.isTerminal) return false;

    // Задание, чьи байты прямо сейчас уходят в принтер, отменить нельзя, и это
    // не строгость ради строгости: отменить — значит сказать, что документа
    // быть не должно, а он уже печатается, и отозвать наполовину вышедшую
    // бумагу невозможно. То же правило уже записано в домене —
    // `PrintJob.renewedUntil` отказывается трогать `printing` — и здесь оно
    // просто не нарушается. Контракт `PrintQueue.cancel` называет `false` для
    // неизвестного и терминального; это третий случай, и он назван здесь, а не
    // умолчан.
    if (job.state == PrintJobState.printing) return false;

    await _store.put(job.cancelled());
    _forget(jobId);
    return true;
  }

  /// Прогоняет очередь сейчас: применяет сроки и берётся за то, что готово.
  ///
  /// Нужен затем, что срок наступает по часам, а не по событию: задание,
  /// у которого вышел срок, пока никто ничего не сдавал, обязано стать видимой
  /// проблемой само. Изнутри это зовёт таймер ([_scheduleWake]); снаружи —
  /// экран очереди и тесты.
  Future<void> sweep() async {
    await start();
    _kick();
    await whenIdle();
  }

  /// Ждёт, пока очередь не останется без работы, которую можно сделать сейчас.
  ///
  /// Не «пока всё не напечатано»: задание, ждущее отступа или срока, работой
  /// «сейчас» не является.
  Future<void> whenIdle() async {
    var running = _running;
    while (running != null) {
      await running;
      running = _running;
    }
    final failure = _pendingFailure;
    if (failure != null) {
      final stack = _pendingFailureStack;
      _pendingFailure = null;
      _pendingFailureStack = null;
      Error.throwWithStackTrace(failure, stack ?? StackTrace.current);
    }
  }

  /// Останавливает очередь: снимает таймер и дожидается текущего задания.
  ///
  /// Задание не бросается на середине — [_runOne] доводится до конца и его
  /// исход попадает в хранилище. Смена длится двенадцать часов, и таймер,
  /// переживший свою очередь, — это утечка.
  Future<void> dispose() async {
    _disposed = true;
    _cancelWake();
    await whenIdle();
  }

  /// Просит очередь поработать. **Второй проход не начинается**, пока идёт
  /// первый, — это и есть единственный писатель.
  void _kick() {
    if (_disposed) return;
    _wanted = true;
    if (_running != null) return;

    // `_running` выставляется **до** запуска прохода, а снимается внутри него
    // же, в том обороте цикла событий, в котором проход решил, что работы
    // больше нет. Сделать это в `whenComplete` нельзя: тот выполняется
    // отдельной микрозадачей, и между решением «работы нет» и снятием флага
    // открывалась бы щель, в которую попадала бы просьба поработать — она
    // видела бы «проход идёт», а проход её уже не увидел бы.
    final done = Completer<void>();
    _running = done.future;
    unawaited(_pumpLoop(done));
  }

  Future<void> _pumpLoop(Completer<void> done) async {
    try {
      while (_wanted && !_disposed) {
        // Снимается здесь, в начале осмотра: всё, что придёт дальше, — это уже
        // повод осмотреть очередь ещё раз.
        _wanted = false;
        try {
          await _drainOnce();
          await _housekeep();
        } catch (error, stack) {
          // Никто не ждёт этот проход: [submit] обязан вернуться сразу (И30).
          // Отказ поэтому не выбрасывается отсюда — он попал бы в
          // необработанные асинхронные ошибки, — а запоминается и достаётся
          // первому, кто дождётся простоя.
          _rememberFailure(error, stack);
        }

        // **Будильник заводится и после отказа, и это не перестраховка.**
        // Ловушка стояла снаружи цикла, и исключение из [_drainOnce] выносило
        // проход целиком, минуя эту строку. Дальше не происходило ничего:
        // будильник не заведён, значит срок заданий некому заметить, значит
        // задание висит вечно — ровно то состояние, которое запрещает И29 и
        // ради недопущения которого вся эта машина и построена. Отказ базы на
        // одном задании не должен отменять срок у остальных.
        await _scheduleWake();
      }
    } finally {
      _running = null;
      done.complete();
    }
  }

  /// Запоминает **первый** отказ прохода: он объясняет остальные, а не
  /// наоборот.
  void _rememberFailure(Object error, StackTrace stack) {
    if (_pendingFailure != null) return;
    _pendingFailure = error;
    _pendingFailureStack = stack;
  }

  Future<void> _drainOnce() async {
    while (!_disposed) {
      final now = _clock();
      final active = await _store.jobs(activeOnly: true);

      // Срок — первым делом, до любой отправки: задание, чей срок вышел,
      // становится видимой проблемой и больше не повторяется.
      //
      // **Это делается здесь, а не в хранилище, и охватывает все три входа.**
      // «Висит вечно» приходит тремя разными дорогами: задание, застигнутое
      // перезапуском на середине записи (`printing` → его поднимает [start],
      // и следующей же строкой оно попадает сюда); задание, до которого ни
      // разу не дошла очередь (`queued`); задание, уже упавшее и ждущее
      // повтора (`failed`). Правило срока для всех трёх одно, поэтому оно и
      // написано один раз — над списком активных, а не по состояниям.
      // Хранилище такого метода не имеет и иметь не будет: истечение срока —
      // решение очереди, а не свойство строки в базе.
      final live = <PrintJob>[];
      for (final job in active) {
        if (job.state == PrintJobState.printing) {
          // Мы единственный писатель, и своё задание мы доводим до конца, так
          // что строка в этом состоянии — след умершего процесса. Её поднимает
          // [start]; трогать её здесь значило бы завести второй путь
          // восстановления.
          continue;
        }
        if (job.hasExpiredAt(now)) {
          await _putUnlessConfirmed(job.expireAt(now));
          _forget(job.id);
          continue;
        }
        live.add(job);
      }

      final next = _pickNext(live, now);
      if (next == null) return;
      await _runOne(next);
    }
  }

  /// Следующее задание к отправке — или `null`, если сейчас делать нечего.
  ///
  /// **Два прохода, и это главное здесь.** Сначала берутся чеки, которых в
  /// этом процессе ещё **не пробовали**, и только когда таких нет — повторы.
  /// Внутри каждого прохода порядок остаётся порядком создания
  /// ([PrintJobStore.jobs]): чеки печатаются в том порядке, в каком их выбили.
  ///
  /// Одного прохода мало, и цена ровно та, что видна с той стороны прилавка.
  /// Удачная печать открывает новую возможность всем, кто исчерпал попытки, —
  /// а обречённое задание, как правило, **старше** только что выбитого чека.
  /// В один проход оно вставало бы перед ним при каждой продаже: покупатель у
  /// кассы ждал бы, пока принтер ещё раз попробует то, что уже провалилось и
  /// провалится снова. Очередь существует затем, чтобы чек дошёл до
  /// покупателя, а не затем, чтобы соблюсти хронологию любой ценой.
  PrintJob? _pickNext(List<PrintJob> jobs, DateTime now) =>
      _firstEligible(jobs, now, retries: false) ??
      _firstEligible(jobs, now, retries: true);

  PrintJob? _firstEligible(
    List<PrintJob> jobs,
    DateTime now, {
    required bool retries,
  }) {
    for (final job in jobs) {
      if (job.state != PrintJobState.queued &&
          job.state != PrintJobState.failed) {
        continue;
      }
      if (_wasTried(job.id) != retries) continue;
      if (_attemptsIn(job.id) >= _maxAttempts) {
        // Попытки этой возможности исчерпаны: задание ждёт следующей — удачной
        // печати другого задания, ручного повтора или собственного срока, —
        // а не крутит принтер.
        continue;
      }
      final notBefore = _retryNotBefore[job.id];
      if (notBefore != null && now.isBefore(notBefore)) continue;
      return job;
    }
    return null;
  }

  Future<void> _runOne(PrintJob job) async {
    // Идемпотентность проверяется здесь, а не только в [submit]: между сдачей и
    // отправкой задание могло быть подтверждено (например, повтором после
    // потерянного подтверждения). Подтверждённое задание не отправляется
    // второй раз, что бы ни просил вызывающий.
    if (await _store.isConfirmedPrinted(job.id)) {
      await _store.put(job.confirmPrinted());
      _forget(job.id);
      return;
    }

    final started = job.beginAttempt();
    if (!await _putUnlessConfirmed(started)) {
      // Подтверждение появилось между проверкой выше и этой записью. Задание
      // закрывается напечатанным, а не остаётся в очереди: оставить его —
      // значит вернуться сюда на следующем же проходе и крутиться вечно.
      await _store.put(job.confirmPrinted());
      _forget(job.id);
      return;
    }
    final attemptsThisRun = _attemptsIn(job.id) + 1;
    _tried[job.id] = (opportunity: _opportunity, attempts: attemptsThisRun);

    PrintResult result;
    try {
      result = await _transport(job.payloadBytes);
    } catch (e) {
      // Транспорт, бросивший исключение, оставил бы задание в `printing`
      // навсегда — состоянии, из которого само оно не выйдет.
      result = PrintResult.error('транспорт печати бросил исключение: $e');
    }

    if (result.success) {
      await _store.put(started.confirmPrinted());
      _forget(job.id);
      // Принтер только что напечатал — значит он жив, и это новая возможность
      // для всех, кто исчерпал свои попытки, пока он им не был.
      //
      // Возможность меняется **номером**, а не забыванием: бюджет попыток
      // возвращается, а память о том, что задание уже падало, остаётся, и в
      // очереди оно встаёт позади чека, которого ещё не пробовали (см.
      // [_pickNext]).
      _opportunity++;
      _retryNotBefore.clear();
      return;
    }

    final reason = (result.errorMessage ?? '').trim();
    final failed = started.failWith(
      reason.isEmpty ? 'Печать не удалась, принтер не назвал причину' : reason,
    );
    if (!await _putUnlessConfirmed(failed)) {
      // Как и выше: задание не остаётся в `printing`, из которого само оно не
      // выйдет до следующего запуска программы.
      await _store.put(started.confirmPrinted());
      _forget(job.id);
      return;
    }
    _retryNotBefore[job.id] = _clock().add(_backoffAfter(attemptsThisRun));
  }

  /// Отступ после [attemptsMade]-й отправки: удвоение от [_firstBackoff] до
  /// [_maxBackoff].
  Duration _backoffAfter(int attemptsMade) {
    var backoff = _firstBackoff;
    for (var i = 1; i < attemptsMade; i++) {
      backoff *= 2;
      if (backoff >= _maxBackoff) return _maxBackoff;
    }
    return backoff;
  }

  /// Пишет задание, если это не вернёт подтверждённое задание в очередь.
  ///
  /// Условие проверяется, а не ловится: [PrintJobStore.put] действительно
  /// бросит [StateError] на такой записи, но исключение как способ управления
  /// потоком не отличает «так и задумано» от «хранилище сломалось».
  ///
  /// Условие — [PrintJobStore.contradictsConfirmation], а не своё, написанное
  /// здесь теми же словами. Своё уже было: оно проверяло «нетерминальное
  /// состояние», хранилище к тому времени проверяло «не `printed`», и
  /// расхождение никого не уронило только потому, что записать подтверждённое
  /// задание как `cancelled` очередь пока не умеет.
  ///
  /// **Проверка и запись не атомарны, и держит их вместе не хранилище, а
  /// правило единственного писателя выше** ([_running]). Полностью это
  /// разобрано в доке [PrintJobStore.put] — там, где его прочитает тот, кто
  /// заведёт второго писателя.
  Future<bool> _putUnlessConfirmed(PrintJob job) async {
    if (PrintJobStore.contradictsConfirmation(job) &&
        await _store.isConfirmedPrinted(job.id)) {
      return false;
    }
    await _store.put(job);
    return true;
  }

  void _forget(String jobId) {
    _tried.remove(jobId);
    _retryNotBefore.remove(jobId);
  }

  /// Уборка обеих памятей хранилища — единственный её вызывающий в живом коде.
  ///
  /// Реже, чем раз в [_housekeepingInterval], очередь этим не занимается: два
  /// удаления на каждый чек — это уборка вместо печати.
  Future<void> _housekeep() async {
    final now = _clock();
    final last = _lastHousekeepingAt;
    if (last != null && now.difference(last) < _housekeepingInterval) return;
    _lastHousekeepingAt = now;
    await _store.removeFinishedBefore(now.subtract(_finishedRetention));
    await _store.forgetExpiredConfirmations(now);
  }

  /// Заводит будильник на ближайший момент, когда очереди снова будет что
  /// делать: чей-то срок или конец чьего-то отступа.
  ///
  /// Без него задание, у которого вышел срок в тишине, оставалось бы `failed`
  /// до следующей продажи — то есть срок, который никто не смотрит, а он и есть
  /// то, что делает проблему видимой.
  /// **Никогда не бросает.** Отказ отсюда вынес бы проход, а вместе с ним и
  /// сам будильник — то есть ровно то, что этот метод существует не допустить.
  Future<void> _scheduleWake() async {
    _cancelWake();
    if (_disposed) return;

    DateTime? at;
    try {
      final active = await _store.jobs(activeOnly: true);
      for (final job in active) {
        at = _earlier(at, job.expiresAt);
        final notBefore = _retryNotBefore[job.id];
        if (notBefore != null && _attemptsIn(job.id) < _maxAttempts) {
          at = _earlier(at, notBefore);
        }
      }
    } catch (error, stack) {
      // Не удалось даже спросить у базы, чего ждать. Остаться без будильника
      // всё равно нельзя: без него срок заданий не наступит ни для кого.
      // Возвращаемся через известный срок и спрашиваем заново.
      _rememberFailure(error, stack);
      _armWake(wakeAfterFailure);
      return;
    }

    if (at == null || _disposed) return;
    _armWake(at.difference(_clock()));
  }

  void _armWake(Duration delay) {
    final safe = delay < Duration.zero ? Duration.zero : delay;
    _nextWakeAt = _clock().add(safe);
    _wakeTimer = Timer(safe, () {
      _wakeTimer = null;
      _nextWakeAt = null;
      _kick();
    });
  }

  void _cancelWake() {
    _wakeTimer?.cancel();
    _wakeTimer = null;
    _nextWakeAt = null;
  }

  static DateTime? _earlier(DateTime? a, DateTime b) =>
      a == null || b.isBefore(a) ? b : a;
}
