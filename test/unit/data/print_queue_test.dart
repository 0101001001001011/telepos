import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_job_store_drift.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/hardware/printer/printer_manager.dart' show PrintResult;

/// Момент, от которого отсчитывается всё в этих тестах. Дробная часть не
/// круглая намеренно — по той же причине, что и в `print_job_store_test.dart`:
/// хранилище, срезающее миллисекунды, означало бы другой срок.
final _t0 = DateTime.utc(2026, 7, 31, 14, 31, 37, 123);

/// Чеки разных касс, все с национальными символами: на латинице «напечатали
/// нужный чек» и «напечатали какой-то чек» выглядят одинаково, а на
/// многобайтовом UTF-8 подмена или перемешивание видны в самих байтах.
///
/// Длины **разные и нечётные** — поддельный принтер режет чек пополам, и на
/// одинаковых длинах перемешивание могло бы дать случайно правильную сумму
/// байтов.
const _receiptKz = 'Чек №101 · Дүкен «Ысык-Көл» · итого 1 234,567 ₸ · КАССА 7';
const _receiptRu = 'Чек №102 · Отменён кассиром · Кассаүй · 0,0005 ₸';
const _receiptUz = 'Chek #103 · Toshkent filiali · jami 87,50';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// Поддельный принтер, который **записывает то, что до него дошло**.
///
/// Пишет чек двумя частями с уступкой цикла событий между ними — ровно так
/// ведёт себя настоящий сокет (`socket.add` + `await socket.flush()`), и только
/// поэтому перемешивание вообще способно проявиться в [received]. Принтер,
/// пишущий чек одной неделимой операцией, сделал бы тест на перемешивание
/// зелёным при любой реализации очереди, то есть бессмысленным.
class _RecordingPrinter {
  /// Байты в том порядке, в каком они дошли до принтера. Главное доказательство
  /// неделимости — здесь, а не в счётчиках.
  final List<int> received = <int>[];

  /// По одной записи на каждую отправку — чтобы «не напечатал второй раз»
  /// отличалось от «напечатал второй раз то же самое».
  final List<Uint8List> calls = <Uint8List>[];

  /// Сколько отправок шло одновременно в пике. Проверка **вспомогательная**:
  /// она доказывает форму, а не результат.
  int maxInFlight = 0;

  /// Останавливать ли запись на середине до разрешения теста.
  bool pauseMidWrite = false;

  /// Чем кончается отправка номер `callIndex`. `null` — всегда успехом.
  bool Function(int callIndex)? succeeds;

  /// Чеки, которые принтер отказывается печатать, — **по содержимому, а не по
  /// номеру отправки**. «Обречённое задание» узнаётся по чеку, и тест про
  /// порядок очереди не должен зависеть от того, каким по счёту его отправят:
  /// ровно этот порядок он и проверяет.
  final Set<String> refuses = <String>{};

  /// Причина отказа, которую принтер называет очереди.
  String failureMessage = 'В принтере закончилась бумага';

  final List<Completer<void>> _gates = <Completer<void>>[];
  int _inFlight = 0;

  Future<PrintResult> send(Uint8List payloadBytes) async {
    final index = calls.length;
    calls.add(Uint8List.fromList(payloadBytes));

    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;

    final half = payloadBytes.length ~/ 2;
    received.addAll(payloadBytes.sublist(0, half));

    if (pauseMidWrite) {
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    } else {
      await Future<void>.delayed(Duration.zero);
    }

    received.addAll(payloadBytes.sublist(half));
    _inFlight--;

    final refused = refuses.contains(
      utf8.decode(payloadBytes, allowMalformed: true),
    );
    final ok = !refused && (succeeds?.call(index) ?? true);
    return ok
        ? PrintResult.ok(bytesSent: payloadBytes.length)
        : PrintResult.error(failureMessage);
  }

  int get pausedWrites => _gates.length;

  /// Отпускает самую старую остановленную запись.
  void releaseOldestWrite() {
    expect(
      _gates,
      isNotEmpty,
      reason: 'отпускать нечего — ни одна запись не остановлена',
    );
    _gates.removeAt(0).complete();
  }

  /// Отпускает всё остановленное. Нужен уборке теста: упавшая проверка не
  /// должна оставить очередь ждать разрешения, которого уже никто не даст.
  void releaseAllWrites() {
    pauseMidWrite = false;
    while (_gates.isNotEmpty) {
      _gates.removeAt(0).complete();
    }
  }
}

/// Хранилище, у которого [jobs] отказывает, пока [jobsFail] истинно.
///
/// Именно [jobs] — это первое, что делает проход очереди, и через него же
/// очередь выясняет, чего ждать дальше. Отказ ровно здесь и уносил раньше весь
/// проход, включая заводку будильника.
class _FlakyStore implements PrintJobStore {
  _FlakyStore(
    this._inner, {
    this.jobsFail = false,
    this.failNextJobsCalls = 0,
    this.failNextStartCalls = 0,
  });

  final PrintJobStore _inner;

  /// Отказывать, пока не выключат.
  bool jobsFail;

  /// Отказать столько ближайших вызовов [failInterruptedPrinting] — то есть
  /// столько ближайших запусков очереди. Отдельно от [failNextJobsCalls]
  /// потому, что отказ **на старте** имеет свою цену: пока он кешировался,
  /// он выключал приём заданий целиком.
  int failNextStartCalls;

  /// Сколько раз очередь бралась восстанавливать прерванную печать.
  ///
  /// Считается затем, что «попробовала снова» и «вернула запомненный отказ»
  /// со стороны [PrintQueue.submit] выглядят одинаково: и там и там ответ
  /// один. Различает их только этот счётчик.
  int startCalls = 0;

  /// Отказать столько ближайших вызовов и дальше работать. Нужен, чтобы
  /// отличить два разных отказа: «упал проход» и «упал даже вопрос о том,
  /// чего ждать». Заводить будильник обязано и то и другое, но заводит он
  /// разное.
  int failNextJobsCalls;

  @override
  Future<List<PrintJob>> jobs({int? terminalId, bool activeOnly = false}) async {
    if (failNextJobsCalls > 0) {
      failNextJobsCalls--;
      throw StateError('база печати недоступна');
    }
    if (jobsFail) throw StateError('база печати недоступна');
    return _inner.jobs(terminalId: terminalId, activeOnly: activeOnly);
  }

  @override
  Future<void> put(PrintJob job) => _inner.put(job);

  @override
  Future<PrintJob?> jobById(String jobId) => _inner.jobById(jobId);

  @override
  Future<bool> isConfirmedPrinted(String jobId) =>
      _inner.isConfirmedPrinted(jobId);

  @override
  Stream<List<PrintJob>> watchJobs({int? terminalId, bool activeOnly = false}) =>
      _inner.watchJobs(terminalId: terminalId, activeOnly: activeOnly);

  @override
  Future<List<PrintJob>> failInterruptedPrinting(String reason) async {
    startCalls++;
    if (failNextStartCalls > 0) {
      failNextStartCalls--;
      throw StateError('база печати недоступна');
    }
    return _inner.failInterruptedPrinting(reason);
  }

  @override
  Future<int> removeFinishedBefore(DateTime cutoff) =>
      _inner.removeFinishedBefore(cutoff);

  @override
  Future<int> forgetExpiredConfirmations(DateTime now) =>
      _inner.forgetExpiredConfirmations(now);
}

/// Крутит цикл событий, пока [condition] не станет истинным.
///
/// Возвращает управление и при исчерпании оборотов: «условие не наступило» —
/// это то, что проверяет вызывающий, а не повод упасть здесь с чужой причиной.
Future<void> _pumpUntil(bool Function() condition, {int turns = 200}) async {
  for (var i = 0; i < turns && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _pumpEventLoop({int turns = 60}) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory tempDir;
  late String dbPath;
  final openDatabases = <AppDatabase>[];
  final openQueues = <PrintQueueLocal>[];

  /// Часы очереди и хранилища — одни и те же и подвижные: срок наступает по
  /// часам, и тест, который ждал бы настоящих тридцати секунд, проверял бы
  /// терпение, а не срок.
  late DateTime now;
  DateTime clock() => now;

  late _RecordingPrinter printer;

  /// **Файловая** база, а не `NativeDatabase.memory()`: одна из проверок — про
  /// задание, застигнутое перезапуском процесса, и база в памяти не может
  /// доказать этого по построению.
  AppDatabase openDb() {
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    openDatabases.add(db);
    return db;
  }

  PrintJobStore openStore([AppDatabase? db]) =>
      DriftPrintJobStore(db ?? openDb(), clock: clock);

  PrintQueueLocal openQueue(
    PrintJobStore store, {
    int maxAttemptsPerOpportunity = 4,
    Duration firstBackoff = Duration.zero,
  }) {
    final queue = PrintQueueLocal(
      store: store,
      transport: printer.send,
      clock: clock,
      maxAttemptsPerOpportunity: maxAttemptsPerOpportunity,
      // Ноль по умолчанию в тестах: отступ проверяется отдельным тестом, а
      // всем остальным он добавил бы только ожидание.
      firstBackoff: firstBackoff,
      maxBackoff: firstBackoff > Duration.zero
          ? firstBackoff * 8
          : Duration.zero,
    );
    openQueues.add(queue);
    return queue;
  }

  /// Сколько заданий уже собрано в этом тесте.
  ///
  /// Нужен затем, что порядок очереди — это порядок **создания** заданий
  /// ([PrintJobStore.jobs]), а не порядок вставки. Задания, собранные одним и
  /// тем же `_t0`, легли бы в очередь по идентификатору, и проверка порядка
  /// печати проверяла бы алфавит. Каждое следующее задание поэтому создаётся на
  /// миллисекунду позже предыдущего — ровно так, как их выбивает касса.
  var made = 0;

  /// Задание, каким его сдаёт живой путь: стоящее в очереди, с владельцем и
  /// сроком.
  PrintJob job(
    String id, {
    required String receipt,
    int terminalId = 7,
    int posId = 3,
    Duration age = Duration.zero,
    Duration lifetime = const Duration(seconds: 30),
    PrintJobState state = PrintJobState.queued,
    int attempts = 0,
    String? failureReason,
  }) {
    final createdAt = _t0
        .subtract(age)
        .add(Duration(milliseconds: made++));
    return PrintJob(
      id: id,
      terminalId: terminalId,
      posId: posId,
      payloadBytes: _bytes(receipt),
      createdAt: createdAt,
      expiresAt: createdAt.add(lifetime),
      state: state,
      attempts: attempts,
      failureReason: failureReason,
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('telepos_print_queue');
    dbPath = '${tempDir.path}${Platform.pathSeparator}print_queue.sqlite';
    now = _t0;
    made = 0;
    printer = _RecordingPrinter();
  });

  tearDown(() async {
    // Порядок обязателен: очередь останавливается до закрытия базы, иначе
    // текущее задание дописывалось бы в закрытую базу. А до того отпускается
    // всё остановленное на принтере — иначе упавшая проверка оставила бы
    // очередь ждать вечно, и настоящая причина падения утонула бы в
    // тайм-аутах.
    printer.releaseAllWrites();
    for (final queue in openQueues) {
      await queue.dispose();
    }
    openQueues.clear();
    for (final db in openDatabases) {
      try {
        await db.close();
      } catch (_) {
        // Уже закрыта тестом — это нормально.
      }
    }
    openDatabases.clear();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // Windows иногда держит файл ещё мгновение после close().
    }
  });

  group('неделимость: между байтами одного чека не встаёт чужой', () {
    test('два задания, сданные разом, доходят до принтера целыми и подряд', () async {
      final store = openStore();
      final queue = openQueue(store);
      printer.pauseMidWrite = true;

      final first = job('sale-7-000101', receipt: _receiptKz);
      final second = job(
        'sale-42-000201',
        receipt: _receiptUz,
        terminalId: 42,
        posId: 9,
      );

      // Оба сдаются одновременно — именно так это выглядит с двух касс. Сдача
      // по очереди перемешивания не проверяет: гонка возникает при
      // одновременности.
      final outcomes = await Future.wait([
        queue.submit(first),
        queue.submit(second),
      ]);
      expect(outcomes.map((o) => o.status), everyElement(PrintSubmitStatus.accepted));

      await _pumpUntil(() => printer.pausedWrites > 0);
      await _pumpEventLoop();

      // Вот проверка неделимости: пока первый чек не дописан, второй не начат.
      // Не «замок взят», а «чужих байтов на приёмнике нет».
      expect(
        printer.calls,
        hasLength(1),
        reason:
            'пока байты первого задания уходят в принтер, второе задание не '
            'может начаться (И29, раздел 8 архитектуры)',
      );
      final firstBytes = _bytes(_receiptKz);
      expect(
        printer.received,
        orderedEquals(firstBytes.sublist(0, firstBytes.length ~/ 2)),
        reason:
            'на приёмнике ровно начало первого чека и ни одного чужого байта',
      );

      printer.releaseOldestWrite();
      await _pumpUntil(() => printer.pausedWrites > 0);
      printer.releaseOldestWrite();
      await queue.whenIdle();

      expect(
        printer.received,
        orderedEquals(<int>[..._bytes(_receiptKz), ..._bytes(_receiptUz)]),
        reason:
            'один чек целиком, следом второй целиком — перемешанные байты '
            'здесь и есть тот отказ, который архитектура называет прямо',
      );
      expect(
        printer.maxInFlight,
        1,
        reason: 'вспомогательная проверка формы: писатель ровно один',
      );
    });

    test('чужое задание между двумя своими не разрывает ни одно из трёх', () async {
      final store = openStore();
      final queue = openQueue(store);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.submit(
        job('sale-42-000201', receipt: _receiptUz, terminalId: 42, posId: 9),
      );
      await queue.submit(job('sale-7-000102', receipt: _receiptRu));
      await queue.whenIdle();

      expect(
        printer.received,
        orderedEquals(<int>[
          ..._bytes(_receiptKz),
          ..._bytes(_receiptUz),
          ..._bytes(_receiptRu),
        ]),
        reason:
            'порядок — тот, в каком чеки выбиты; каждый чек целиком, включая '
            'тот, что пришёл с другой кассы',
      );
    });
  });

  group('идемпотентность: подтверждённое задание не печатается второй раз', () {
    test('повтор сдачи с тем же идентификатором отвечает duplicate и не печатает', () async {
      final store = openStore();
      final queue = openQueue(store);

      final first = await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      expect(first.status, PrintSubmitStatus.accepted);
      expect(printer.calls, hasLength(1));

      final again = await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();

      expect(
        again.status,
        PrintSubmitStatus.duplicate,
        reason:
            'корректный повтор после потерянного подтверждения — это успех '
            'вызывающего, а не отказ',
      );
      expect(
        printer.calls,
        hasLength(1),
        reason: 'второй чек покупателю не выдаётся ни при каких условиях',
      );
    });

    test('повтор узнан и после того, как само задание убрано уборкой', () async {
      final store = openStore();
      final queue = openQueue(store);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();

      // Уборка выполненных заданий — та самая, которая **не** трогает память
      // подтверждений. Если бы трогала, идемпотентность жила бы до первой
      // уборки.
      final removed = await store.removeFinishedBefore(
        now.add(const Duration(days: 1)),
      );
      expect(removed, 1);
      expect(await store.jobById('sale-7-000101'), isNull);

      final again = await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();

      expect(again.status, PrintSubmitStatus.duplicate);
      expect(printer.calls, hasLength(1));
    });

    test('ручной повтор подтверждённого задания тоже не печатает второй раз', () async {
      final store = openStore();
      final queue = openQueue(store);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();

      final outcome = await queue.retry(
        'sale-7-000101',
        extendBy: const Duration(minutes: 5),
      );
      await queue.whenIdle();

      expect(outcome.status, PrintSubmitStatus.duplicate);
      expect(printer.calls, hasLength(1));
    });

    test('ручной повтор после уборки задания тоже узнан по памяти подтверждений', () async {
      final store = openStore();
      final queue = openQueue(store);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      await store.removeFinishedBefore(now.add(const Duration(days: 1)));

      final outcome = await queue.retry(
        'sale-7-000101',
        extendBy: const Duration(minutes: 5),
      );
      await queue.whenIdle();

      expect(
        outcome.status,
        PrintSubmitStatus.duplicate,
        reason:
            'строки задания уже нет — ответ «печаталось ли» даёт только память '
            'подтверждений; «неизвестно» здесь означало бы второй чек по '
            'кнопке «повторить»',
      );
      expect(printer.calls, hasLength(1));
    });

    test('задание, подтверждённое чужой записью, выпадает из очереди и в принтер не уходит', () async {
      // Что именно здесь доказано, названо честно: подтверждение делает
      // задание терминальным, и очередь его больше не берёт. Проверку
      // подтверждения **внутри** [_runOne] это не доказывает — она защищает от
      // подтверждения, случившегося уже после выбора задания, а при
      // единственном писателе такого случиться некому. Написать «эта проверка
      // проверяет ту строку» значило бы завести зелёный тест, который ничего
      // не держит.
      final store = openStore();
      final queue = openQueue(store);
      printer.pauseMidWrite = true;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.submit(job('sale-7-000102', receipt: _receiptRu));
      await _pumpUntil(() => printer.pausedWrites > 0);

      // Пока печатается первое, второе объявляется напечатанным мимо очереди.
      final second = await store.jobById('sale-7-000102');
      await store.put(second!.confirmPrinted());

      printer.releaseOldestWrite();
      await queue.whenIdle();

      expect(
        printer.calls.map((c) => utf8.decode(c)),
        [_receiptKz],
        reason: 'второе задание уже подтверждено — в принтер оно не уходит',
      );
    });
  });

  group('срок: задание становится видимой проблемой и перестаёт повторяться', () {
    test('исчерпав попытки, задание ждёт срока, а не крутит принтер', () async {
      final store = openStore();
      final queue = openQueue(store, maxAttemptsPerOpportunity: 2);
      printer.succeeds = (_) => false;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();

      expect(
        printer.calls,
        hasLength(2),
        reason: 'ровно столько отправок, сколько разрешено одной возможности',
      );
      final failed = await store.jobById('sale-7-000101');
      expect(failed!.state, PrintJobState.failed);
      expect(failed.attempts, 2);
      expect(failed.failureReason, 'В принтере закончилась бумага');

      await queue.sweep();
      expect(
        printer.calls,
        hasLength(2),
        reason: 'исчерпавшее попытки задание ждёт следующей возможности',
      );
    });

    test('после срока задание переходит в expired, сохраняет причину и больше не идёт в принтер', () async {
      final store = openStore();
      final queue = openQueue(store, maxAttemptsPerOpportunity: 2);
      printer.succeeds = (_) => false;

      await queue.submit(
        job('sale-7-000101', receipt: _receiptKz, lifetime: const Duration(seconds: 30)),
      );
      await queue.whenIdle();
      expect(printer.calls, hasLength(2));

      now = _t0.add(const Duration(seconds: 31));
      await queue.sweep();

      final expired = await store.jobById('sale-7-000101');
      expect(
        expired!.state,
        PrintJobState.expired,
        reason: '«висит вечно» и «тихо выброшено» одинаково неверны (И29)',
      );
      expect(
        expired.failureReason,
        'В принтере закончилась бумага',
        reason: 'оператору нужна причина, а не только факт истечения',
      );
      expect(printer.calls, hasLength(2));

      now = _t0.add(const Duration(minutes: 5));
      await queue.sweep();
      expect(
        printer.calls,
        hasLength(2),
        reason: 'истёкшее задание само себя больше не повторяет',
      );
    });

    test('задание, до которого очередь не дошла, тоже истекает — а не ждёт вечно', () async {
      // Третий вход в «висит вечно»: не printing (перезапуск) и не failed
      // (была попытка), а просто queued — задание, у которого срок вышел
      // раньше, чем до него дошла очередь. Двигать его тоже некому, кроме
      // очереди: у хранилища такого метода нет.
      final store = openStore();
      final queue = openQueue(store);

      final outcome = await queue.submit(
        job(
          'sale-7-000101',
          receipt: _receiptKz,
          age: const Duration(minutes: 2),
          lifetime: const Duration(seconds: 30),
        ),
      );
      await queue.whenIdle();

      expect(
        outcome.status,
        PrintSubmitStatus.accepted,
        reason:
            'задание принимается и становится видимой проблемой; отказ при '
            'сдаче не оставил бы вызывающему ничего',
      );
      final expired = await store.jobById('sale-7-000101');
      expect(expired!.state, PrintJobState.expired);
      expect(expired.attempts, 0);
      expect(
        printer.calls,
        isEmpty,
        reason: 'печатать чек, чей срок вышел, уже поздно',
      );

      await queue.sweep();
      expect(printer.calls, isEmpty);
    });

    test('истёкшее задание видно в потоке очереди вместе с причиной', () async {
      final store = openStore();
      final queue = openQueue(store, maxAttemptsPerOpportunity: 1);
      printer.succeeds = (_) => false;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      now = _t0.add(const Duration(seconds: 31));
      await queue.sweep();

      final seen = await queue.watch(terminalId: 7).first;
      expect(seen.map((j) => j.id), contains('sale-7-000101'));
      expect(seen.single.state, PrintJobState.expired);
      expect(seen.single.failureReason, 'В принтере закончилась бумага');
    });

    test('поток очереди одной кассы не показывает задания другой', () async {
      final store = openStore();
      final queue = openQueue(store);
      printer.succeeds = (_) => false;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.submit(
        job('sale-42-000201', receipt: _receiptUz, terminalId: 42, posId: 9),
      );
      await queue.whenIdle();

      final mine = await queue.watch(terminalId: 7).first;
      expect(
        mine.map((j) => j.id),
        ['sale-7-000101'],
        reason:
            'без чужого задания в наборе проверка не отличала бы «нашёл своё» '
            'от «вернул всё»',
      );
      final all = await queue.watch().first;
      expect(all.map((j) => j.id), ['sale-7-000101', 'sale-42-000201']);
    });

    test('удачная печать открывает новую возможность исчерпавшему попытки', () async {
      final store = openStore();
      final queue = openQueue(store, maxAttemptsPerOpportunity: 1);
      printer.succeeds = (index) => index > 0;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      expect(printer.calls, hasLength(1));
      expect((await store.jobById('sale-7-000101'))!.state, PrintJobState.failed);

      // Другой чек печатается успешно — значит принтер жив, и это новая
      // возможность для того, кто ждал.
      await queue.submit(job('sale-7-000102', receipt: _receiptRu));
      await queue.whenIdle();

      expect(
        (await store.jobById('sale-7-000101'))!.state,
        PrintJobState.printed,
        reason: 'ожидание следующей возможности, а не отказ навсегда',
      );
      expect(
        printer.received,
        orderedEquals(<int>[
          ..._bytes(_receiptKz),
          ..._bytes(_receiptRu),
          ..._bytes(_receiptKz),
        ]),
        reason:
            'неудачная отправка тоже дошла до принтера целиком: транспорт '
            'не рвёт чек, он лишь не подтверждает его',
      );
    });

    test('чек покупателя у кассы не ждёт за повтором обречённого задания', () async {
      // Удачная печать открывает новую возможность тем, кто исчерпал попытки.
      // Обречённое задание при этом почти всегда **старше** только что
      // выбитого чека, и в один проход выбора оно вставало бы перед ним при
      // каждой продаже.
      final store = openStore();
      final queue = openQueue(store, maxAttemptsPerOpportunity: 1);
      printer.refuses.add(_receiptRu);

      await queue.submit(job('sale-7-000001', receipt: _receiptRu));
      await queue.whenIdle();
      expect(
        printer.calls.map(utf8.decode),
        [_receiptRu],
        reason: 'обречённое задание исчерпало свою единственную попытку',
      );

      // Следующий чек печатается и **держит принтер**, пока идёт запись.
      printer.pauseMidWrite = true;
      await queue.submit(job('sale-7-000002', receipt: _receiptKz));
      await _pumpUntil(() => printer.pausedWrites > 0);

      // Покупатель у кассы: его чек сдан, пока печатается предыдущий. Значит к
      // моменту, когда очередь освободится, в ней будут стоять оба — оживлённое
      // обречённое (старше) и этот (свежее).
      await queue.submit(job('sale-7-000003', receipt: _receiptUz));
      printer.pauseMidWrite = false;
      printer.releaseOldestWrite();
      await queue.whenIdle();

      expect(
        printer.calls.map(utf8.decode).toList(),
        [_receiptRu, _receiptKz, _receiptUz, _receiptRu],
        reason:
            'после удачной печати обречённое задание оживает, но встаёт '
            'позади чека, которого ещё не пробовали; иначе покупатель ждёт, '
            'пока принтер ещё раз провалит то, что уже провалил',
      );
    });

    test('отступ между попытками растёт и не даёт крутить принтер', () async {
      final store = openStore();
      final queue = openQueue(
        store,
        maxAttemptsPerOpportunity: 3,
        firstBackoff: const Duration(seconds: 2),
      );
      printer.succeeds = (_) => false;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      expect(
        printer.calls,
        hasLength(1),
        reason: 'вторая попытка ждёт отступа, а не идёт сразу следом',
      );

      now = _t0.add(const Duration(seconds: 2));
      await queue.sweep();
      expect(printer.calls, hasLength(2));

      now = _t0.add(const Duration(seconds: 3));
      await queue.sweep();
      expect(
        printer.calls,
        hasLength(2),
        reason: 'второй отступ вдвое длиннее первого — четырёх секунд ещё нет',
      );

      now = _t0.add(const Duration(seconds: 6));
      await queue.sweep();
      expect(printer.calls, hasLength(3));
    });
  });

  group('перезапуск процесса: задание, застигнутое на середине записи', () {
    test('поднимается из printing и доводится до печати', () async {
      final store = openStore();
      await store.put(
        job(
          'sale-7-000101',
          receipt: _receiptKz,
          state: PrintJobState.printing,
          attempts: 1,
          lifetime: const Duration(minutes: 10),
        ),
      );

      // Новая очередь поверх той же базы — это и есть перезапуск процесса.
      final queue = openQueue(store);
      await queue.start();
      await queue.whenIdle();

      final recovered = await store.jobById('sale-7-000101');
      expect(
        recovered!.state,
        PrintJobState.printed,
        reason:
            'задание в printing не терминально (уборка его не тронет) и не '
            'повторяемо (renewedUntil откажет) — без подъёма оно висит вечно',
      );
      expect(printer.calls.map(utf8.decode), [_receiptKz]);
    });

    test('поднятое задание с уже вышедшим сроком становится expired с причиной обрыва', () async {
      final store = openStore();
      await store.put(
        job(
          'sale-7-000101',
          receipt: _receiptKz,
          state: PrintJobState.printing,
          attempts: 3,
          age: const Duration(minutes: 2),
          lifetime: const Duration(seconds: 30),
        ),
      );

      final queue = openQueue(store);
      await queue.start();
      await queue.whenIdle();

      final recovered = await store.jobById('sale-7-000101');
      expect(recovered!.state, PrintJobState.expired);
      expect(
        recovered.failureReason,
        PrintQueueLocal.interruptedByRestartReason,
        reason:
            'в журнале остаётся, что именно произошло, а не тихо появившееся '
            'заново задание',
      );
      expect(
        printer.calls,
        isEmpty,
        reason: 'задание с вышедшим сроком в принтер не уходит',
      );
    });

    test('очередь, у которой забыли позвать start, всё равно поднимает застрявшее', () async {
      final store = openStore();
      await store.put(
        job(
          'sale-7-000101',
          receipt: _receiptKz,
          state: PrintJobState.printing,
          attempts: 1,
          lifetime: const Duration(minutes: 10),
        ),
      );

      final queue = openQueue(store);
      // Никакого start() — только обычная сдача нового задания.
      await queue.submit(job('sale-7-000102', receipt: _receiptRu));
      await queue.whenIdle();

      expect(
        (await store.jobById('sale-7-000101'))!.state,
        PrintJobState.printed,
        reason: 'очередь без восстановления молча не печатала бы застрявшее',
      );
    });
  });

  group('ручной повтор: длительность, а не момент', () {
    test('новый срок строится часами очереди, а не часами вызывающего', () async {
      final store = openStore();
      final queue = openQueue(store, maxAttemptsPerOpportunity: 1);
      printer.succeeds = (_) => false;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      now = _t0.add(const Duration(seconds: 31));
      await queue.sweep();
      expect((await store.jobById('sale-7-000101'))!.state, PrintJobState.expired);

      // Часы вызывающего здесь не участвуют вовсе: по проводу едет
      // длительность. Браузер с отстающими часами не может прислать срок,
      // который на кассе уже прошёл.
      now = _t0.add(const Duration(minutes: 10));
      final outcome = await queue.retry(
        'sale-7-000101',
        extendBy: const Duration(minutes: 5),
      );
      await queue.whenIdle();

      expect(outcome.status, PrintSubmitStatus.accepted);
      final renewed = await store.jobById('sale-7-000101');
      expect(
        renewed!.expiresAt.isAtSameMomentAs(
          _t0.add(const Duration(minutes: 15)),
        ),
        isTrue,
        reason:
            'срок = часы очереди + extendBy; получилось '
            '${renewed.expiresAt.toIso8601String()}',
      );
      expect(
        printer.calls,
        hasLength(2),
        reason: 'повтор — новая возможность: счётчик попыток начинается заново',
      );
    });

    test('неположительная длительность отвергается с названной причиной', () async {
      final store = openStore();
      final queue = openQueue(store);
      printer.succeeds = (_) => false;
      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();

      for (final extendBy in [Duration.zero, const Duration(seconds: -5)]) {
        final outcome = await queue.retry('sale-7-000101', extendBy: extendBy);
        expect(outcome.status, PrintSubmitStatus.rejected);
        expect(outcome.message, contains('просрочить'));
      }
    });

    test('неизвестное задание отвергается с названной причиной, а не молча', () async {
      final store = openStore();
      final queue = openQueue(store);

      final outcome = await queue.retry(
        'нет-такого-задания',
        extendBy: const Duration(minutes: 1),
      );

      expect(outcome.status, PrintSubmitStatus.rejected);
      expect(outcome.message, contains('неизвестно'));
    });

    test('отменённое задание не повторяется и причина названа', () async {
      final store = openStore();
      final queue = openQueue(store);
      printer.succeeds = (_) => false;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      expect(await queue.cancel('sale-7-000101'), isTrue);

      final outcome = await queue.retry(
        'sale-7-000101',
        extendBy: const Duration(minutes: 1),
      );
      await queue.whenIdle();

      expect(outcome.status, PrintSubmitStatus.rejected);
      expect(outcome.message, contains('отменено'));
      expect(
        (await store.jobById('sale-7-000101'))!.state,
        PrintJobState.cancelled,
      );
    });

    test('печатающееся сейчас задание не повторяется и причина названа', () async {
      final store = openStore();
      final queue = openQueue(store);
      printer.pauseMidWrite = true;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await _pumpUntil(() => printer.pausedWrites > 0);

      final outcome = await queue.retry(
        'sale-7-000101',
        extendBy: const Duration(minutes: 1),
      );
      expect(outcome.status, PrintSubmitStatus.rejected);
      expect(outcome.message, contains('печатается'));

      printer.releaseOldestWrite();
      await queue.whenIdle();
      expect(printer.calls, hasLength(1));
    });
  });

  group('сдача задания и отмена', () {
    test('сдача не бросает, а отвечает отказом с причиной', () async {
      final store = openStore();
      final queue = openQueue(store);

      // Задание, пришедшее не стоящим в очереди: очередь не бросает — исключение
      // отсюда попало бы на путь продажи (И30).
      final outcome = await queue.submit(
        job(
          'sale-7-000101',
          receipt: _receiptKz,
          state: PrintJobState.failed,
          failureReason: 'придумано вызывающим',
        ),
      );

      expect(outcome.status, PrintSubmitStatus.rejected);
      expect(outcome.message, contains('failed'));
      expect(printer.calls, isEmpty);
    });

    test('отменённое задание не печатается вовсе', () async {
      final store = openStore();
      final queue = openQueue(store);
      printer.pauseMidWrite = true;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.submit(job('sale-7-000102', receipt: _receiptRu));
      await _pumpUntil(() => printer.pausedWrites > 0);

      expect(await queue.cancel('sale-7-000102'), isTrue);
      printer.releaseOldestWrite();
      await queue.whenIdle();

      expect(
        printer.received,
        orderedEquals(_bytes(_receiptKz)),
        reason: 'отменённый чек до принтера не доходит ни одним байтом',
      );
    });

    test('отмена печатающегося сейчас задания отклоняется', () async {
      final store = openStore();
      final queue = openQueue(store);
      printer.pauseMidWrite = true;

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await _pumpUntil(() => printer.pausedWrites > 0);

      expect(
        await queue.cancel('sale-7-000101'),
        isFalse,
        reason:
            'наполовину вышедшую бумагу отозвать нельзя — отмена сказала бы '
            'неправду',
      );

      printer.releaseOldestWrite();
      await queue.whenIdle();
      expect((await store.jobById('sale-7-000101'))!.state, PrintJobState.printed);
    });

    test('отмена неизвестного и уже завершённого задания возвращает false', () async {
      final store = openStore();
      final queue = openQueue(store);

      expect(await queue.cancel('нет-такого-задания'), isFalse);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();
      expect(await queue.cancel('sale-7-000101'), isFalse);
    });

    test('транспорт, бросивший исключение, не оставляет задание в printing', () async {
      final store = openStore();
      final queue = PrintQueueLocal(
        store: store,
        transport: (_) => throw StateError('принтер оторвался'),
        clock: clock,
        maxAttemptsPerOpportunity: 1,
        firstBackoff: Duration.zero,
        maxBackoff: Duration.zero,
      );
      openQueues.add(queue);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle();

      final stuck = await store.jobById('sale-7-000101');
      expect(stuck!.state, PrintJobState.failed);
      expect(stuck.failureReason, contains('принтер оторвался'));
    });
  });

  group('упавший проход не оставляет очередь без будильника', () {
    test('упавший проход всё равно заводит будильник на срок задания', () async {
      final store = _FlakyStore(openStore());
      final queue = openQueue(store);

      // Пустой удачный проход, чтобы очередь была заведомо без будильника, и
      // задание кладётся **мимо очереди** — иначе её собственный проход
      // напечатал бы его прежде, чем что-либо успело упасть.
      await queue.start();
      await queue.whenIdle();
      await store.put(
        job(
          'sale-7-000101',
          receipt: _receiptKz,
          lifetime: const Duration(seconds: 30),
        ),
      );

      // Без этой проверки тест доказывал бы ничего: будильник, заведённый
      // раньше, пережил бы упавший проход и выглядел бы как заведённый им.
      // Первая версия была именно такой, и мутация прошла её насквозь.
      expect(
        queue.nextWakeAt,
        isNull,
        reason: 'до отказа будильника нет — значит его заведёт именно отказ',
      );

      store.failNextJobsCalls = 1;
      await queue.sweep().then<void>((_) {}, onError: (Object _) {});

      expect(printer.calls, isEmpty, reason: 'проход упал до отправки');
      expect(
        queue.nextWakeAt,
        isNotNull,
        reason:
            'очередь без будильника не заметит ни одного срока — это и есть '
            '«висит вечно», которое И29 запрещает, добытое той самой машиной, '
            'что его предотвращает',
      );
      expect(
        queue.nextWakeAt!.isAtSameMomentAs(_t0.add(const Duration(seconds: 30))),
        isTrue,
        reason:
            'спросить у базы, чего ждать, вышло — будильник на срок задания; '
            'получилось ${queue.nextWakeAt!.toIso8601String()}',
      );
    });

    test('когда не вышло даже спросить, чего ждать, будильник всё равно есть', () async {
      final store = _FlakyStore(openStore(), jobsFail: true);
      final queue = openQueue(store);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle().then<void>((_) {}, onError: (Object _) {});

      expect(
        queue.nextWakeAt,
        isNotNull,
        reason: 'возвращаемся через известный срок, а не никогда',
      );
      expect(
        queue.nextWakeAt!.isAtSameMomentAs(
          _t0.add(PrintQueueLocal.wakeAfterFailure),
        ),
        isTrue,
        reason: 'получилось ${queue.nextWakeAt!.toIso8601String()}',
      );
    });

    test('отказ прохода виден тому, кто дождался простоя, а не проглочен', () async {
      final store = _FlakyStore(openStore(), jobsFail: true);
      final queue = openQueue(store);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));

      await expectLater(
        queue.whenIdle(),
        throwsA(isA<StateError>()),
        reason: 'отказ не выбрасывается из submit (И30), но и не теряется',
      );
    });

    test('оправившись, очередь доводит задание до печати', () async {
      final store = _FlakyStore(openStore(), jobsFail: true);
      final queue = openQueue(store);

      await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      await queue.whenIdle().then<void>((_) {}, onError: (Object _) {});
      expect(printer.calls, isEmpty);

      store.jobsFail = false;
      await queue.sweep();

      expect(
        printer.calls.map(utf8.decode),
        [_receiptKz],
        reason: 'задание пережило отказ прохода — ради этого очередь и есть',
      );
    });
  });

  group('отказ при старте не выключает печать до перезапуска программы', () {
    test('после упавшего старта следующий чек принимается и печатается', () async {
      final store = _FlakyStore(openStore(), failNextStartCalls: 1);
      final queue = openQueue(store);

      // Первый чек теряется, и это честная цена отказа базы: задание некуда
      // записать. Проверяется он затем, что без него тест не отличал бы
      // «старт упал» от «старт не понадобился».
      final lost = await queue.submit(job('sale-7-000101', receipt: _receiptKz));
      expect(
        lost.status,
        PrintSubmitStatus.rejected,
        reason: 'база отказала — задание записать было некуда',
      );
      expect(store.startCalls, 1);

      // Второй чек — уже после того, как база оправилась. Он обязан пройти:
      // очередь, запомнившая отказавший старт, отвечала бы отказом каждому
      // следующему чеку до перезапуска программы, то есть воспроизводила бы
      // ровно тот дефект, ради устранения которого написана.
      final next = await queue.submit(job('sale-7-000102', receipt: _receiptRu));
      expect(
        next.status,
        PrintSubmitStatus.accepted,
        reason:
            'кешированный отказ старта выключил бы приём заданий целиком: '
            '${next.message}',
      );
      expect(
        store.startCalls,
        2,
        reason:
            'очередь обязана попробовать восстановление заново, а не отдать '
            'запомненный отказ — со стороны submit это неразличимо',
      );

      await queue.whenIdle();

      expect(
        printer.calls.map(utf8.decode),
        [_receiptRu],
        reason: 'после отказа старта печать работает, а не ждёт перезапуска',
      );
      expect(
        (await store.jobById('sale-7-000102'))!.state,
        PrintJobState.printed,
      );
    });
  });

  group('настройки повтора отвергают бессмысленное', () {
    test('ноль попыток и отрицательный отступ не выражаются', () {
      final store = openStore();
      expect(
        () => PrintQueueLocal(
          store: store,
          transport: printer.send,
          maxAttemptsPerOpportunity: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => PrintQueueLocal(
          store: store,
          transport: printer.send,
          firstBackoff: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
      expect(
        () => PrintQueueLocal(
          store: store,
          transport: printer.send,
          firstBackoff: const Duration(seconds: 5),
          maxBackoff: const Duration(seconds: 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
