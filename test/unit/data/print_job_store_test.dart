import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_job_store_drift.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';

/// Момент, от которого отсчитывается всё в этих тестах. Дробная часть —
/// **не** круглая намеренно: колонка, хранящая секунды (drift-овский
/// `dateTime()` по умолчанию именно такова), срезала бы `.123`, и срок,
/// прочитанный обратно, означал бы другой момент.
final _t0 = DateTime.utc(2026, 7, 31, 14, 31, 37, 123);

/// Часы того, кто открывает базу заново. **Намеренно не совпадают с [_t0]** и
/// вообще ни с одним моментом создания заданий.
///
/// Совпадение здесь молча обесценивает проверку: реализация, пересчитывающая
/// срок как «длительность от сейчас», при часах, равных `createdAt`, выдаёт
/// случайно верное значение, и тест остаётся зелёным. Один раз это уже
/// произошло — и во второй раз пережило исправление первого, потому что
/// местное `DateTime(2026, 7, 31, 14, 31, 37, 123)` под `TZ=UTC` (то есть на
/// обычном CI) — это ровно [_t0].
final _readerClock = _t0.add(const Duration(days: 3));

/// Чек с кириллицей всех нужных стран. Нужен затем, чтобы «прочитали нужное
/// задание» отличалось от «прочитали какое-то задание»: на латинице обе
/// ошибки выглядят одинаково, а на многобайтовом UTF-8 подмена байтов или
/// потеря кодировки видна сразу.
const _receiptKz = 'Чек №7 · Дүкен «Ысык-Көл» · итого 1 234,567 ₸';
const _receiptRu = 'Чек №9 · Отменён кассиром · Кассаүй';
const _receiptLatin = 'Receipt #201 · Toshkent filiali';

/// Байты, которые не являются текстом вовсе: ESC/POS-инициализация, нулевой
/// байт и 0xFF. Ловят реализацию, которая где-то по дороге сделала бы из чека
/// строку.
final _binaryPayload = Uint8List.fromList([0x1b, 0x40, 0x00, 0xff, 0x0a, 0x1d]);

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// Набор заданий: две кассы, оба терминальных и нетерминальных состояния,
/// кириллица и двоичные байты, порядок создания заведомо не совпадает с
/// порядком вставки.
///
/// Общий на весь файл — набор, переписанный в каждом тесте заново, разошёлся
/// бы, и половина проверок описывала бы другой мир (скилл `qa-depth`,
/// «правило нуля»).
List<PrintJob> _seedJobs() => [
  PrintJob(
    id: 'sale-7-000101',
    terminalId: 7,
    posId: 3,
    payloadBytes: _bytes(_receiptKz),
    createdAt: _t0,
    expiresAt: _t0.add(const Duration(seconds: 30)),
  ),
  PrintJob(
    id: 'sale-7-000102',
    terminalId: 7,
    posId: 3,
    payloadBytes: _bytes('Чек №8 · Дүкен №2 · 0.0005 ₸'),
    createdAt: _t0.add(const Duration(seconds: 1)),
    expiresAt: _t0.add(const Duration(seconds: 31)),
    attempts: 2,
    state: PrintJobState.failed,
    failureReason: 'Принтер не отвечает',
  ),
  PrintJob(
    id: 'sale-42-000201',
    terminalId: 42,
    posId: 9,
    payloadBytes: _bytes(_receiptLatin),
    createdAt: _t0.add(const Duration(seconds: 2)),
    expiresAt: _t0.add(const Duration(seconds: 32)),
  ),
  PrintJob(
    id: 'sale-42-000202',
    terminalId: 42,
    posId: 9,
    payloadBytes: _binaryPayload,
    createdAt: _t0.add(const Duration(seconds: 3)),
    expiresAt: _t0.add(const Duration(seconds: 33)),
    attempts: 1,
    state: PrintJobState.printed,
  ),
  PrintJob(
    id: 'sale-42-000203',
    terminalId: 42,
    posId: 9,
    payloadBytes: _bytes(_receiptRu),
    createdAt: _t0.add(const Duration(seconds: 4)),
    expiresAt: _t0.add(const Duration(seconds: 34)),
    state: PrintJobState.cancelled,
    failureReason: 'Отменено оператором',
  ),
];

void main() {
  late Directory tempDir;
  late String dbPath;
  final openDatabases = <AppDatabase>[];

  /// Открывает **файловую** базу. Не `NativeDatabase.memory()`: весь смысл
  /// задачи в том, что задание переживает перезапуск процесса, а база в
  /// памяти этого проверить не может по построению — она исчезает вместе с
  /// объектом.
  AppDatabase openDb() {
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    openDatabases.add(db);
    return db;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('telepos_print_job_store');
    dbPath = '${tempDir.path}${Platform.pathSeparator}print_queue.sqlite';
  });

  tearDown(() async {
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
      // Windows иногда держит файл ещё мгновение после close(); каталог
      // временный и будет убран системой.
    }
  });

  group('задание переживает перезапуск процесса', () {
    test('сданные задания читаются после закрытия и повторного открытия базы', () async {
      final first = openDb();
      final writer = DriftPrintJobStore(first, clock: () => _t0);
      for (final job in _seedJobs().reversed) {
        await writer.put(job);
      }
      await first.checkpointWal();
      await first.close();

      // Другой объект базы и другой объект хранилища поверх того же файла —
      // это и есть «перезапуск процесса» в пределах теста.
      final reopened = DriftPrintJobStore(openDb(), clock: () => _t0);
      final jobs = await reopened.jobs();

      expect(
        jobs.map((j) => j.id).toList(),
        [
          'sale-7-000101',
          'sale-7-000102',
          'sale-42-000201',
          'sale-42-000202',
          'sale-42-000203',
        ],
        reason:
            'все пять заданий обязаны найтись, и в порядке создания — '
            'вставлялись они в обратном',
      );
    });

    test('после перезапуска возвращается именно то задание, а не какое-то', () async {
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await writer.put(job);
      }
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _t0);
      final job = await reopened.jobById('sale-7-000102');

      expect(job, isNotNull);
      // Сверка с литералами, а не с объектом, который тест сам же собрал:
      // сравнение с собственным входом доказало бы только, что у нас есть
      // этот объект.
      expect(utf8.decode(job!.payloadBytes), 'Чек №8 · Дүкен №2 · 0.0005 ₸');
      expect(job.terminalId, 7);
      expect(job.posId, 3);
      expect(job.attempts, 2);
      expect(job.state, PrintJobState.failed);
      expect(job.failureReason, 'Принтер не отвечает');
    });

    test('двоичные байты чека переживают запись и чтение без искажения', () async {
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await writer.put(job);
      }
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _t0);
      final job = await reopened.jobById('sale-42-000202');

      expect(
        job!.payloadBytes,
        orderedEquals(<int>[0x1b, 0x40, 0x00, 0xff, 0x0a, 0x1d]),
        reason:
            'нулевой байт и 0xFF ловят реализацию, где-то сделавшую из чека '
            'строку',
      );
    });
  });

  group('причина неудачи снимается, а не накапливается', () {
    test('причина, снятая переходом, читается как её отсутствие', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      final failed = PrintJob(
        id: 'sale-7-000500',
        terminalId: 7,
        posId: 3,
        payloadBytes: _bytes(_receiptKz),
        createdAt: _t0,
        expiresAt: _t0.add(const Duration(seconds: 30)),
      ).failWith('Нет бумаги');
      await store.put(failed);
      expect((await store.jobById('sale-7-000500'))!.failureReason, 'Нет бумаги');

      // beginAttempt() снимает причину: идёт новая попытка, и прошлая причина
      // текущего состояния больше не объясняет.
      await store.put(failed.beginAttempt());

      final afterRetry = await store.jobById('sale-7-000500');
      expect(
        afterRetry!.failureReason,
        isNull,
        reason:
            'колонка, в которую можно только дописать, унесла бы «Нет бумаги» '
            'в напечатанный чек — это и был исправленный дефект',
      );
      expect(afterRetry.state, PrintJobState.printing);

      // И обратно: снятая причина ставится заново.
      await store.put(afterRetry.failWith('Принтер не отвечает'));
      expect(
        (await store.jobById('sale-7-000500'))!.failureReason,
        'Принтер не отвечает',
      );
    });

    test('снятая причина остаётся снятой после перезапуска', () async {
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      final job = PrintJob(
        id: 'sale-7-000501',
        terminalId: 7,
        posId: 3,
        payloadBytes: _bytes(_receiptKz),
        createdAt: _t0,
        expiresAt: _t0.add(const Duration(seconds: 30)),
      ).failWith('Нет бумаги');
      await writer.put(job);
      await writer.put(job.beginAttempt().confirmPrinted());
      await openDatabases.first.checkpointWal();
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _t0);
      final readBack = await reopened.jobById('sale-7-000501');

      expect(readBack!.state, PrintJobState.printed);
      expect(readBack.failureReason, isNull);
    });
  });

  group('задание, прерванное перезапуском', () {
    test('задание в printing после перезапуска объявляется неудачным', () async {
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await writer.put(job);
      }
      // Процесс умер ровно здесь: строка осталась в printing.
      await writer.put(
        (await writer.jobById('sale-7-000101'))!.beginAttempt(),
      );
      await openDatabases.first.checkpointWal();
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _t0);
      final recovered = await reopened.failInterruptedPrinting(
        'Прервано перезапуском',
      );

      expect(recovered.map((j) => j.id), ['sale-7-000101']);
      final job = await reopened.jobById('sale-7-000101');
      expect(job!.state, PrintJobState.failed);
      expect(job.failureReason, 'Прервано перезапуском');
      expect(
        job.attempts,
        1,
        reason: 'попытка была и должна остаться сосчитанной',
      );
    });

    test('после восстановления задание снова можно повторить', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      final job = PrintJob(
        id: 'sale-7-000601',
        terminalId: 7,
        posId: 3,
        payloadBytes: _bytes(_receiptKz),
        createdAt: _t0,
        expiresAt: _t0.add(const Duration(seconds: 30)),
      );
      await store.put(job.beginAttempt());

      // До восстановления повтор невозможен — это и есть смысл прохода через
      // неудачу с названной причиной.
      expect(
        () => job.beginAttempt().renewedUntil(
          _t0.add(const Duration(minutes: 5)),
          now: _t0,
        ),
        throwsA(isA<StateError>()),
      );

      final recovered = await store.failInterruptedPrinting('Прервано');
      final renewed = recovered.single.renewedUntil(
        _t0.add(const Duration(minutes: 5)),
        now: _t0,
      );
      await store.put(renewed);

      final readBack = await store.jobById('sale-7-000601');
      expect(readBack!.state, PrintJobState.queued);
      expect(readBack.failureReason, isNull);
      expect(
        readBack.expiresAt.isAtSameMomentAs(_t0.add(const Duration(minutes: 5))),
        isTrue,
      );
    });

    test('восстановление не трогает задания в других состояниях', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      final recovered = await store.failInterruptedPrinting('Прервано');

      expect(
        recovered,
        isEmpty,
        reason: 'в наборе нет ни одного задания в printing',
      );
      expect(
        (await store.jobById('sale-7-000102'))!.failureReason,
        'Принтер не отвечает',
        reason: 'чужая причина не должна быть переписана',
      );
      expect(
        (await store.jobById('sale-42-000202'))!.state,
        PrintJobState.printed,
      );
    });

    test('пустая причина обрыва отвергается', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      expect(
        () => store.failInterruptedPrinting('   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('срок — момент времени, а не длительность', () {
    test('срок после перезапуска означает ровно тот же момент', () async {
      final createdAt = DateTime.utc(2026, 7, 31, 14, 31, 37, 123);
      final expiresAt = DateTime.utc(2026, 7, 31, 14, 32, 07, 456);
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      await writer.put(
        PrintJob(
          id: 'sale-7-000900',
          terminalId: 7,
          posId: 3,
          payloadBytes: _bytes(_receiptKz),
          createdAt: createdAt,
          expiresAt: expiresAt,
        ),
      );
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _readerClock);
      final job = await reopened.jobById('sale-7-000900');

      expect(
        job!.expiresAt.millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 31, 14, 32, 07, 456).millisecondsSinceEpoch,
        reason:
            'срок обязан читаться как «14:32:07.456 того дня», а не как '
            '«тридцать секунд от открытия приложения»',
      );
      expect(job.expiresAt.isAtSameMomentAs(expiresAt), isTrue);
      expect(job.createdAt.isAtSameMomentAs(createdAt), isTrue);
    });

    test('миллисекунды срока не срезаются', () async {
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      await writer.put(
        PrintJob(
          id: 'sale-7-000901',
          terminalId: 7,
          posId: 3,
          payloadBytes: _bytes(_receiptKz),
          createdAt: DateTime.utc(2026, 12, 31, 23, 59, 59, 001),
          expiresAt: DateTime.utc(2026, 12, 31, 23, 59, 59, 987),
        ),
      );
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _readerClock);
      final job = await reopened.jobById('sale-7-000901');

      expect(
        job!.expiresAt.millisecond,
        987,
        reason:
            'колонка, хранящая секунды, срезала бы дробную часть и вернула бы '
            'момент на 987 мс раньше — на переходе года это ещё и другой год',
      );
      expect(job.createdAt.millisecond, 1);
    });

    test('уже истёкший срок остаётся истёкшим после перезапуска', () async {
      // Срок в прошлом, оба момента в прошлом. Реализация, хранящая
      // длительность и пересчитывающая её от момента открытия, выдала бы
      // заданию свежие тридцать секунд — то самое «висит вечно».
      final createdAt = DateTime.utc(2020, 1, 1, 0, 0, 0);
      final expiresAt = DateTime.utc(2020, 1, 1, 0, 0, 30);
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      await writer.put(
        PrintJob(
          id: 'sale-7-000902',
          terminalId: 7,
          posId: 3,
          payloadBytes: _bytes(_receiptKz),
          createdAt: createdAt,
          expiresAt: expiresAt,
        ),
      );
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _readerClock);
      final job = await reopened.jobById('sale-7-000902');

      expect(job!.hasExpiredAt(DateTime.utc(2020, 1, 1, 0, 0, 31)), isTrue);
      expect(
        job.expiresAt.year,
        2020,
        reason: 'срок принадлежит 2020 году, а не моменту открытия хранилища',
      );
    });

    test('момент, записанный по местному времени, читается тем же моментом', () async {
      final localCreatedAt = DateTime(2026, 7, 31, 14, 31, 37, 123);
      final localExpiresAt = DateTime(2026, 7, 31, 14, 32, 07, 456);
      final writer = DriftPrintJobStore(openDb(), clock: () => _t0);
      await writer.put(
        PrintJob(
          id: 'sale-7-000903',
          terminalId: 7,
          posId: 3,
          payloadBytes: _bytes(_receiptKz),
          createdAt: localCreatedAt,
          expiresAt: localExpiresAt,
        ),
      );
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: () => _readerClock);
      final job = await reopened.jobById('sale-7-000903');

      expect(
        job!.expiresAt.isAtSameMomentAs(localExpiresAt),
        isTrue,
        reason: 'часовой пояс записавшего не должен сдвигать момент',
      );
    });
  });

  group('память о подтверждённых заданиях живёт отдельно', () {
    test('подтверждённый идентификатор известен после уборки выполненных', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(openDb(), clock: clock.call);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      clock.now = _t0.add(const Duration(hours: 1));
      final removed = await store.removeFinishedBefore(
        _t0.add(const Duration(minutes: 30)),
      );

      expect(removed, 2, reason: 'напечатанное и отменённое — терминальные');
      expect(
        await store.jobById('sale-42-000202'),
        isNull,
        reason: 'само задание убрано — это и есть уборка',
      );
      expect(
        await store.isConfirmedPrinted('sale-42-000202'),
        isTrue,
        reason:
            'память о подтверждении обязана пережить уборку задания: без неё '
            'повтор после потерянного подтверждения печатает второй чек',
      );
    });

    test('память о подтверждении переживает и уборку, и перезапуск', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(openDb(), clock: clock.call);
      for (final job in _seedJobs()) {
        await store.put(job);
      }
      clock.now = _t0.add(const Duration(hours: 1));
      await store.removeFinishedBefore(_t0.add(const Duration(minutes: 30)));
      await openDatabases.first.checkpointWal();
      await openDatabases.first.close();

      final reopened = DriftPrintJobStore(openDb(), clock: clock.call);

      expect(await reopened.isConfirmedPrinted('sale-42-000202'), isTrue);
      expect(
        await reopened.isConfirmedPrinted('sale-42-000203'),
        isFalse,
        reason:
            'отменённое задание тоже терминально и тоже убрано — но '
            'подтверждённым оно никогда не было',
      );
      expect(
        await reopened.isConfirmedPrinted('sale-7-000101'),
        isFalse,
        reason: 'запись, которая не должна попасть в результат',
      );
    });

    test('подтверждённое задание нельзя вернуть в очередь', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      final sameIdAgain = PrintJob(
        id: 'sale-42-000202',
        terminalId: 42,
        posId: 9,
        payloadBytes: _binaryPayload,
        createdAt: _t0.add(const Duration(minutes: 5)),
        expiresAt: _t0.add(const Duration(minutes: 6)),
      );

      expect(
        () => store.put(sameIdAgain),
        throwsA(isA<StateError>()),
        reason: 'вернуть подтверждённое задание в очередь — значит выдать '
            'покупателю второй фискальный чек',
      );
      expect(
        (await store.jobById('sale-42-000202'))!.state,
        PrintJobState.printed,
        reason: 'отказ не должен был ничего переписать',
      );
    });

    test('подтверждённое задание нельзя переписать как отменённое', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      // `cancelled` — состояние терминальное, поэтому проверка вида
      // «отказывать только нетерминальным» его пропускала. Второго чека это
      // не давало, но журнал начинал утверждать, что оператор отменил чек,
      // который физически напечатан.
      final cancelledAfterPrinting = PrintJob(
        id: 'sale-42-000202',
        terminalId: 42,
        posId: 9,
        payloadBytes: _binaryPayload,
        createdAt: _t0.add(const Duration(seconds: 3)),
        expiresAt: _t0.add(const Duration(seconds: 33)),
        state: PrintJobState.cancelled,
        failureReason: 'Отменено оператором',
      );

      expect(
        () => store.put(cancelledAfterPrinting),
        throwsA(isA<StateError>()),
        reason:
            'напечатанный чек не может быть отменённым — это неправда в '
            'фискальной записи, и выглядит она достоверно',
      );
      final stored = await store.jobById('sale-42-000202');
      expect(stored!.state, PrintJobState.printed);
      expect(stored.failureReason, isNull);
    });

    test('подтверждённое задание нельзя переписать как истёкшее', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      final expiredAfterPrinting = PrintJob(
        id: 'sale-42-000202',
        terminalId: 42,
        posId: 9,
        payloadBytes: _binaryPayload,
        createdAt: _t0.add(const Duration(seconds: 3)),
        expiresAt: _t0.add(const Duration(seconds: 33)),
        state: PrintJobState.expired,
      );

      expect(
        () => store.put(expiredAfterPrinting),
        throwsA(isA<StateError>()),
      );
      expect(
        (await store.jobById('sale-42-000202'))!.state,
        PrintJobState.printed,
      );
    });

    test('повторная запись того же подтверждения по-прежнему разрешена', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      final printed = _printedJob('sale-7-000710', _t0);
      await store.put(printed);

      // Отказ распространяется на любое состояние, кроме `printed`, — сама
      // повторная запись подтверждения обязана остаться возможной, иначе
      // очередь не сможет повторно сохранить то, что уже сохранила.
      await store.put(printed);

      expect((await store.jobById('sale-7-000710'))!.state, PrintJobState.printed);
    });

    test('повторное подтверждение не сдвигает момент первого', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(
        openDb(),
        clock: clock.call,
        confirmationRetention: const Duration(days: 10),
      );
      final printed = PrintJob(
        id: 'sale-7-000700',
        terminalId: 7,
        posId: 3,
        payloadBytes: _bytes(_receiptKz),
        createdAt: _t0,
        expiresAt: _t0.add(const Duration(seconds: 30)),
        state: PrintJobState.printed,
      );
      await store.put(printed);

      clock.now = _t0.add(const Duration(days: 5));
      await store.put(printed);

      final forgotten = await store.forgetExpiredConfirmations(
        _t0.add(const Duration(days: 11)),
      );

      expect(
        forgotten,
        1,
        reason:
            'срок отсчитывается от первого подтверждения; иначе строку, '
            'которую регулярно перезаписывают, не забыли бы никогда',
      );
      expect(await store.isConfirmedPrinted('sale-7-000700'), isFalse);
    });
  });

  group('правило хранения подтверждений', () {
    test('подтверждение старше срока забывается, более молодое — нет', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(
        openDb(),
        clock: clock.call,
        confirmationRetention: const Duration(days: 10),
      );
      await store.put(_printedJob('old-1', _t0));
      clock.now = _t0.add(const Duration(days: 9));
      await store.put(_printedJob('young-1', clock.now));

      final forgotten = await store.forgetExpiredConfirmations(
        _t0.add(const Duration(days: 11)),
      );

      expect(forgotten, 1);
      expect(await store.isConfirmedPrinted('old-1'), isFalse);
      expect(await store.isConfirmedPrinted('young-1'), isTrue);
    });

    test('потолок выбрасывает самые старые, а не случайные', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(
        openDb(),
        clock: clock.call,
        confirmationRetention: const Duration(days: 3650),
        maxRememberedConfirmations: 3,
      );
      for (var i = 0; i < 5; i++) {
        clock.now = _t0.add(Duration(minutes: i));
        await store.put(_printedJob('conf-$i', clock.now));
      }

      final forgotten = await store.forgetExpiredConfirmations(
        _t0.add(const Duration(minutes: 10)),
      );

      expect(forgotten, 2);
      expect(await store.isConfirmedPrinted('conf-0'), isFalse);
      expect(await store.isConfirmedPrinted('conf-1'), isFalse);
      for (final kept in ['conf-2', 'conf-3', 'conf-4']) {
        expect(
          await store.isConfirmedPrinted(kept),
          isTrue,
          reason: '$kept моложе выброшенных и обязан остаться',
        );
      }
    });

    test('без переопределений действует правило из контракта', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(openDb(), clock: clock.call);
      await store.put(_printedJob('default-policy', _t0));

      await store.forgetExpiredConfirmations(_t0.add(const Duration(days: 89)));
      expect(
        await store.isConfirmedPrinted('default-policy'),
        isTrue,
        reason: 'через 89 дней подтверждение ещё помнится',
      );

      await store.forgetExpiredConfirmations(_t0.add(const Duration(days: 91)));
      expect(
        await store.isConfirmedPrinted('default-policy'),
        isFalse,
        reason: 'через 91 день — уже нет; умолчание берётся из PrintJobStore',
      );
      expect(PrintJobStore.confirmationRetention, const Duration(days: 90));
      expect(PrintJobStore.maxRememberedConfirmations, 100000);
    });

    test('уборка заданий и уборка подтверждений — разные операции', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(openDb(), clock: clock.call);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      final removedJobs = await store.removeFinishedBefore(
        _t0.add(const Duration(days: 1)),
      );
      final forgotten = await store.forgetExpiredConfirmations(
        _t0.add(const Duration(days: 1)),
      );

      expect(removedJobs, 2);
      expect(
        forgotten,
        0,
        reason:
            'подтверждению один день — уборка заданий не имеет к нему '
            'никакого отношения',
      );
      expect(await store.isConfirmedPrinted('sale-42-000202'), isTrue);
    });
  });

  group('уборка работает на таблице, которая переросла предел SQLite', () {
    // Предел SQLite на число связанных параметров в одном запросе — 32 766.
    // Реализация, удаляющая по списку идентификаторов, отказывает ровно
    // тогда, когда уборка нужнее всего, и починить себя не может: сократить
    // таблицу способна только та уборка, которая на ней и падает.
    const beyondSqliteVariableLimit = 40000;

    test('потолок срабатывает на сорока тысячах подтверждений', () async {
      final db = openDb();
      final store = DriftPrintJobStore(
        db,
        clock: () => _t0,
        confirmationRetention: const Duration(days: 3650),
        maxRememberedConfirmations: 1000,
      );
      await db.batch((batch) {
        batch.insertAll(db.printJobConfirmations, [
          for (var i = 0; i < beyondSqliteVariableLimit; i++)
            PrintJobConfirmationsCompanion.insert(
              jobId: 'conf-${i.toString().padLeft(6, '0')}',
              confirmedAtEpochMs: _t0.millisecondsSinceEpoch + i,
            ),
        ]);
      });

      final forgotten = await store.forgetExpiredConfirmations(
        _t0.add(const Duration(days: 1)),
      );

      expect(
        forgotten,
        beyondSqliteVariableLimit - 1000,
        reason:
            'лишних строк 39 000 — то есть больше, чем SQLite принимает '
            'параметров в один запрос; правило обязано сработать всё равно',
      );
      expect(await store.isConfirmedPrinted('conf-000000'), isFalse);
      expect(
        await store.isConfirmedPrinted('conf-039999'),
        isTrue,
        reason: 'выброшены самые старые, а тысяча самых новых осталась',
      );
    });

    test('удаление по сроку не откатывается из-за потолка', () async {
      final db = openDb();
      final store = DriftPrintJobStore(
        db,
        clock: () => _t0,
        confirmationRetention: const Duration(days: 10),
        maxRememberedConfirmations: 1000,
      );
      // Старых строк намеренно немного: после удаления по сроку остаться
      // должно **больше** 32 766 сверх потолка, иначе вторая граница
      // уложилась бы в предел SQLite и откат нечем было бы вызвать.
      const oldRows = 5000;
      await db.batch((batch) {
        batch.insertAll(db.printJobConfirmations, [
          for (var i = 0; i < beyondSqliteVariableLimit; i++)
            PrintJobConfirmationsCompanion.insert(
              jobId: 'conf-${i.toString().padLeft(6, '0')}',
              confirmedAtEpochMs: i < oldRows
                  ? _t0.millisecondsSinceEpoch + i
                  : _t0.add(const Duration(days: 20)).millisecondsSinceEpoch + i,
            ),
        ]);
      });

      final forgotten = await store.forgetExpiredConfirmations(
        _t0.add(const Duration(days: 15)),
      );

      expect(
        forgotten,
        beyondSqliteVariableLimit - 1000,
        reason:
            'обе границы работают в одной транзакции: отказ второй откатывал '
            'бы первую, и не срабатывала бы ни одна',
      );
      final remaining = await db
          .customSelect('SELECT COUNT(*) AS c FROM print_job_confirmations')
          .getSingle();
      expect(
        remaining.read<int>('c'),
        1000,
        reason: 'после уборки в таблице ровно потолок',
      );
    });

    test('уборка заданий не упирается в число заданий', () async {
      final db = openDb();
      final store = DriftPrintJobStore(db, clock: () => _t0);
      await db.batch((batch) {
        batch.insertAll(db.printJobs, [
          for (var i = 0; i < beyondSqliteVariableLimit; i++)
            PrintJobsCompanion.insert(
              jobId: 'job-${i.toString().padLeft(6, '0')}',
              terminalId: 7,
              posId: 3,
              payloadBytes: _bytes(_receiptKz),
              createdAtEpochMs: _t0.millisecondsSinceEpoch + i,
              expiresAtEpochMs:
                  _t0.add(const Duration(seconds: 30)).millisecondsSinceEpoch + i,
              updatedAtEpochMs: _t0.millisecondsSinceEpoch + i,
              // Терминальных заведомо больше 32 766 — иначе список
              // идентификаторов уложился бы в предел SQLite и проверка
              // ничего не сказала бы. Остальные нетерминальны: заодно
              // проверяется, что предикат в SQL отбирает то же самое, что
              // отобрал бы `isTerminal`.
              state: i < 35000
                  ? PrintJobState.printed.name
                  : PrintJobState.queued.name,
            ),
        ]);
      });

      final removed = await store.removeFinishedBefore(
        _t0.add(const Duration(days: 1)),
      );

      expect(removed, 35000);
      expect(
        (await store.jobs()).map((j) => j.state).toSet(),
        {PrintJobState.queued},
        reason: 'нетерминальные обязаны остаться все до одного',
      );
    });
  });

  group('уборка заданий смотрит на момент изменения, а не создания', () {
    test('давно созданное, только что напечатанное задание не убирается', () async {
      final clock = _MutableClock(_t0);
      final store = DriftPrintJobStore(openDb(), clock: clock.call);
      final job = PrintJob(
        id: 'sale-7-000800',
        terminalId: 7,
        posId: 3,
        payloadBytes: _bytes(_receiptKz),
        createdAt: _t0,
        expiresAt: _t0.add(const Duration(seconds: 30)),
      );

      // Задание создано тридцать дней назад, а подтверждено только что.
      clock.now = _t0.add(const Duration(days: 30));
      await store.put(job.beginAttempt().confirmPrinted());

      final removed = await store.removeFinishedBefore(
        _t0.add(const Duration(days: 1)),
      );

      expect(
        removed,
        0,
        reason:
            'уборка отбирает по updated_at; по created_at это задание уехало '
            'бы в мусор через секунду после того, как его напечатали',
      );
      expect(await store.jobById('sale-7-000800'), isNotNull);
    });
  });

  group('выборка заданий', () {
    test('касса видит свои задания и не видит чужие', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      final ofSeven = await store.jobs(terminalId: 7);

      expect(ofSeven.map((j) => j.id), ['sale-7-000101', 'sale-7-000102']);
      expect(
        ofSeven.map((j) => j.terminalId).toSet(),
        {7},
        reason: 'задания терминала 42 в набор входят и попасть сюда не должны',
      );
    });

    test('activeOnly не отдаёт терминальные задания', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      final active = await store.jobs(activeOnly: true);

      expect(active.map((j) => j.id), [
        'sale-7-000101',
        'sale-7-000102',
        'sale-42-000201',
      ]);
      expect(
        active.map((j) => j.state),
        isNot(contains(PrintJobState.printed)),
      );
      expect(
        active.map((j) => j.state),
        contains(PrintJobState.failed),
        reason: 'failed означает «повторим» и терминальным не является',
      );
    });

    test('поток отдаёт новое значение при появлении задания', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      final seen = <List<String>>[];
      final subscription = store
          .watchJobs(terminalId: 7)
          .listen((jobs) => seen.add(jobs.map((j) => j.id).toList()));
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      for (final job in _seedJobs()) {
        await store.put(job);
      }
      await pumpEventQueue();

      expect(seen.first, isEmpty);
      expect(seen.last, ['sale-7-000101', 'sale-7-000102']);
    });

    test('два задания, сданные одновременно, оба сохраняются', () async {
      final store = DriftPrintJobStore(openDb(), clock: () => _t0);
      final jobs = _seedJobs();

      await Future.wait([store.put(jobs[0]), store.put(jobs[2])]);

      expect((await store.jobs()).map((j) => j.id), [
        'sale-7-000101',
        'sale-42-000201',
      ]);
    });
  });

  group('миграция v28 → v29 на установке с данными', () {
    test('таблицы очереди появляются, а прежние данные остаются', () async {
      // Установка, какой она была до этой задачи: схема v28, обычные данные,
      // ни одной из двух новых таблиц.
      final fresh = openDb();
      await fresh
          .into(fresh.categories)
          .insert(
            CategoriesCompanion.insert(
              id: const Value(77),
              createTime: DateTime.utc(2026, 7, 1),
            ),
          );
      await fresh.checkpointWal();
      await fresh.close();
      openDatabases.clear();

      final downgraded = AppDatabase(
        NativeDatabase(
          File(dbPath),
          setup: (raw) {
            raw.execute('DROP TABLE IF EXISTS print_jobs');
            raw.execute('DROP TABLE IF EXISTS print_job_confirmations');
            raw.execute('PRAGMA user_version = 28');
          },
        ),
      );
      openDatabases.add(downgraded);

      // Первое же обращение поднимает миграцию: сработать должна ровно ветка
      // `if (from < 29)` — все младшие уже пройдены (`from` = 28).
      final store = DriftPrintJobStore(downgraded, clock: () => _t0);
      for (final job in _seedJobs()) {
        await store.put(job);
      }

      expect(
        (await store.jobs()).map((j) => j.id),
        hasLength(5),
        reason: 'таблица print_jobs создана миграцией, а не onCreate',
      );
      expect(await store.isConfirmedPrinted('sale-42-000202'), isTrue);
      expect(
        (await downgraded.select(downgraded.categories).get()).single.id,
        77,
        reason: 'миграция не имеет права трогать данные, которые уже были',
      );
    });
  });

  test('строка с неизвестным состоянием — громкая ошибка, а не пропуск', () async {
    final db = openDb();
    final store = DriftPrintJobStore(db, clock: () => _t0);
    await store.put(_seedJobs().first);
    await db.customStatement(
      "UPDATE print_jobs SET state = 'teleported' WHERE job_id = 'sale-7-000101'",
    );

    expect(
      () => store.jobs(),
      throwsA(isA<FormatException>()),
      reason:
          'пропустить такую строку значило бы, что чек исчез молча — ровно '
          'тот дефект, ради которого это хранилище существует',
    );
  });

  test('испорченная строка не запирает уборку', () async {
    final db = openDb();
    final store = DriftPrintJobStore(db, clock: () => _t0);
    for (final job in _seedJobs()) {
      await store.put(job);
    }
    await db.customStatement(
      "UPDATE print_jobs SET state = 'teleported' WHERE job_id = 'sale-7-000101'",
    );

    final removed = await store.removeFinishedBefore(
      _t0.add(const Duration(days: 1)),
    );

    expect(
      removed,
      2,
      reason:
          'уборка отбирает строки предикатом в SQL и разбором строк не '
          'занимается; иначе одна испорченная строка запирала бы уборку '
          'навсегда — а убрать эту строку могла бы только она',
    );
    expect(await store.isConfirmedPrinted('sale-42-000202'), isTrue);
  });

  group('хранилище отказывается от бессмысленной настройки', () {
    test('нулевой срок хранения подтверждений отвергается', () {
      expect(
        () => DriftPrintJobStore(
          openDb(),
          confirmationRetention: Duration.zero,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('нулевой потолок подтверждений отвергается', () {
      expect(
        () => DriftPrintJobStore(openDb(), maxRememberedConfirmations: 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

PrintJob _printedJob(String id, DateTime createdAt) => PrintJob(
  id: id,
  terminalId: 7,
  posId: 3,
  payloadBytes: _bytes(_receiptKz),
  createdAt: createdAt,
  expiresAt: createdAt.add(const Duration(seconds: 30)),
  state: PrintJobState.printed,
);

/// Часы, которые тест двигает руками. Ждать девяносто дней в прогоне нельзя,
/// а проверить правило хранения — нужно.
class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  DateTime call() => now;
}
