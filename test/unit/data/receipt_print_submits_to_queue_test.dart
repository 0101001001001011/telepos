import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_job_store_drift.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

/// Живой путь печати сдаёт чек **в очередь**, а не пишет в принтер.
///
/// Это задача, ради которой существуют первые четыре задачи плана. До неё
/// неудачная печать теряла чек вместе с локальными переменными асинхронной
/// функции экрана оплаты: деньги взяты, чек в базе, бумаги нет, повторить
/// нечего.
///
/// Здесь всё настоящее и ничего не подменено заглушкой, кроме самого провода до
/// принтера:
///
/// * база — настоящая drift-схема в памяти, с настоящими таблицами заданий;
/// * хранилище — `DriftPrintJobStore`, тот же, что в приложении;
/// * очередь — `PrintQueueLocal`, тот же, что в приложении;
/// * служба — `ReceiptPrintServiceImpl`, та же;
/// * недоступный принтер — транспорт, который отвечает отказом. Это и есть
///   недоступный принтер: очередь другого способа узнать о нём не имеет.
///
/// Проверяется то, что видно **в базе**: строка задания с байтами чека. Ответ
/// самой очереди тут был бы слабым доказательством — он живёт в памяти ровно
/// столько, сколько живёт вызов.
void main() {
  late AppDatabase db;
  late _RecordingTransport transport;
  late PrintQueueLocal queue;

  /// Очередь с **одной** попыткой на возможность и заведомо длинным отступом.
  ///
  /// Не «чтобы было быстрее»: с умолчаниями (четыре попытки, отступы 1+2+4 с)
  /// прогон зависел бы от настоящих часов, а тест, ждущий семь секунд,
  /// проверяет расписание, а не сохранность чека. Одна попытка делает число
  /// обращений к принтеру наблюдаемым: если оно вдруг станет нулём — значит
  /// задание не поехало вовсе, и это видно, а не тонет в повторах.
  PrintQueueLocal buildQueue(PrintJobStore store) => PrintQueueLocal(
    store: store,
    transport: transport.call,
    maxAttemptsPerOpportunity: 1,
    firstBackoff: const Duration(minutes: 5),
    maxBackoff: const Duration(minutes: 5),
  );

  Future<void> registerAll({PrintQueueLocal? existing}) async {
    final store = DriftPrintJobStore(db);
    queue = existing ?? buildQueue(store);
    GetIt.I
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<TerminalRepository>(LocalTerminalRepository(db))
      ..registerSingleton<PrintJobStore>(store)
      ..registerSingleton<PrintQueue>(queue);
  }

  setUp(() async {
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transport = _RecordingTransport();

    // Настоящее имя кассы обязательно: без него `TerminalRepository.self()`
    // отказывается выдумывать терминал (`InstallationNotConfiguredException`),
    // и владельца у задания не будет.
    await db.thisPosDao.insertInitialConfig(
      companyName: 'ТОО ТестПОС',
      iinbin: '123456789012',
      cashBoxName: 'Касса-1',
      countryCode: 0,
      currencyCode: 0,
      currencySymbol: '₸',
      currencyNameShort: 'KZT',
      paperWidth: 48,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );
    await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
        .write(const ThisPosEntriesCompanion(id: Value(1)));

    await registerAll();
  });

  tearDown(() async {
    await queue.dispose();
    await GetIt.I.reset();
    await db.close();
  });

  Future<List<PrintJob>> storedJobs() => GetIt.I<PrintJobStore>().jobs();

  test(
    'принтер недоступен — чек остаётся заданием в хранилище, а не теряется',
    () async {
      transport.failWith = 'Принтер не отвечает';

      final service = ReceiptPrintServiceImpl();
      final outcome = await service.printSaleReceipt(_sale(receiptNo: 1042));

      expect(
        outcome.isRejected,
        isFalse,
        reason:
            'недоступный принтер — не отказ приёма: задание принято и будет '
            'напечатано, когда принтер сможет. Отказ здесь означал бы, что '
            'чек снова некуда положить (${outcome.message})',
      );

      await queue.whenIdle();

      expect(
        transport.calls,
        1,
        reason:
            'задание действительно поехало в принтер: ноль означал бы, что '
            'проверка ниже видит задание, до которого очередь и не дошла',
      );

      final jobs = await storedJobs();
      expect(
        jobs,
        hasLength(1),
        reason:
            'ЭТО ВСЯ ЗАДАЧА: чек, не ушедший в принтер, обязан остаться '
            'заданием в базе. Пустой список означает возврат к прежнему '
            'положению — деньги взяты, бумаги нет, повторить нечего',
      );

      final job = jobs.single;
      expect(job.id, outcome.jobId);
      expect(
        job.state,
        PrintJobState.failed,
        reason:
            'попытка была и не удалась; `queued` означало бы, что до принтера '
            'дело не дошло, `printed` — что неудачу записали как успех',
      );
      expect(
        job.failureReason,
        'Принтер не отвечает',
        reason: 'оператор должен увидеть, почему чек не вышел, а не «ошибку»',
      );
      expect(
        job.payloadBytes,
        transport.lastPayload,
        reason:
            'в задании лежат **те же** байты, что уезжали в принтер, — иначе '
            'повтор напечатает не тот чек',
      );
      expect(job.terminalId, greaterThan(0));
      expect(job.posId, 1);
    },
  );

  test('задание переживает перезапуск процесса и узнаётся по чеку', () async {
    transport.failWith = 'Принтер не отвечает';

    final outcome = await ReceiptPrintServiceImpl().printSaleReceipt(
      _sale(receiptNo: 1042),
    );
    await queue.whenIdle();
    expect(outcome.isRejected, isFalse);

    // Перезапуск программы: прежняя очередь и прежнее хранилище исчезают
    // вместе с процессом, база остаётся. Идентификатор, порождённый из
    // `DateTime.now()` — так была устроена удалённая задачей 1 очередь, — на
    // этом месте дал бы **новый** ключ, и покупатель получил бы второй чек.
    await queue.dispose();
    await GetIt.I.reset();
    transport = _RecordingTransport()..failWith = 'Принтер не отвечает';
    await registerAll();

    final again = await ReceiptPrintServiceImpl().printSaleReceipt(
      _sale(receiptNo: 1042),
    );
    await queue.whenIdle();

    expect(
      again.jobId,
      outcome.jobId,
      reason:
          'идентификатор — чистая функция того, чем чек является, и в новом '
          'процессе он тот же самый',
    );
    expect(
      again.status,
      PrintSubmitStatus.duplicate,
      reason: 'та же продажа после перезапуска — то же задание, а не второе',
    );
    expect(
      await storedJobs(),
      hasLength(1),
      reason: 'после перезапуска это по-прежнему одно задание, а не два',
    );
    // Ровно одна отправка — и это отправка **пережившего перезапуск** задания,
    // а не повторно сданного: сдача вернула `duplicate` и в принтер ничего не
    // клала. Перезапуск программы — новая возможность напечатать то, что
    // осталось со вчера (`PrintQueueLocal`: счётчик попыток возможности живёт
    // в памяти процесса).
    expect(transport.calls, 1);
    expect(
      transport.lastPayload,
      (await storedJobs()).single.payloadBytes,
      reason:
          'в принтер уехали байты того самого задания, что лежало в базе, а '
          'не заново собранный чек',
    );
  });

  test('тот же чек дважды — одно задание; дубликат — другое', () async {
    transport.failWith = 'Принтер не отвечает';
    final service = ReceiptPrintServiceImpl();

    final first = await service.printSaleReceipt(_sale(receiptNo: 77));
    await queue.whenIdle();
    final second = await service.printSaleReceipt(_sale(receiptNo: 77));
    await queue.whenIdle();

    expect(first.status, PrintSubmitStatus.accepted);
    expect(
      second.status,
      PrintSubmitStatus.duplicate,
      reason:
          'повторная печать того же чека не выдаёт покупателю второй — в этом '
          'весь смысл ключа идемпотентности',
    );
    expect(second.jobId, first.jobId);
    expect(await storedJobs(), hasLength(1));

    // А вот дубликат — **сознательно другой экземпляр того же чека**, и он
    // обязан напечататься. Без номера копии в идентификаторе он совпал бы с
    // оригиналом, и кнопка «печать дубликата» не выдавала бы бумаги вообще.
    final duplicate = await service.printSaleDuplicate(_sale(receiptNo: 77));
    await queue.whenIdle();

    expect(duplicate.status, PrintSubmitStatus.accepted);
    expect(duplicate.jobId, isNot(first.jobId));
    expect(await storedJobs(), hasLength(2));
  });

  test(
    'пробная печать не сталкивается с настоящим чеком того же номера',
    () async {
      // У образца с экрана настройки чека номер фиксированный (1024). Если бы он
      // шёл тем же путём, что и продажа, настоящий чек №1024 этой кассы и этой
      // смены получил бы тот же идентификатор — и один из двух не напечатался бы.
      transport.failWith = 'Принтер не отвечает';
      final service = ReceiptPrintServiceImpl();

      final real = await service.printSaleReceipt(_sale(receiptNo: 1024));
      await queue.whenIdle();
      final sample = await service.printSampleReceipt(
        _sale(receiptNo: 1024, at: DateTime(2026, 7, 31, 10, 15, 30)),
      );
      await queue.whenIdle();

      expect(real.status, PrintSubmitStatus.accepted);
      expect(
        sample.status,
        PrintSubmitStatus.accepted,
        reason:
            'пробная печать — событие проверки оборудования, а не чек №1024',
      );
      expect(sample.jobId, isNot(real.jobId));
      expect(await storedJobs(), hasLength(2));
    },
  );

  test(
    'без зарегистрированной очереди печать отказывает, а не пишет в принтер',
    () async {
      // Прямая запись «на всякий случай» здесь и была бы вторым путём: он
      // выглядел бы работающим ровно до первого недоступного принтера, на
      // котором чек снова потерялся бы молча.
      await queue.dispose();
      await GetIt.I.reset();
      GetIt.I
        ..registerSingleton<AppDatabase>(db)
        ..registerSingleton<TerminalRepository>(LocalTerminalRepository(db))
        ..registerSingleton<PrinterManager>(_AlwaysOkPrinter(transport));
      queue = buildQueue(DriftPrintJobStore(db));

      final outcome = await ReceiptPrintServiceImpl().printSaleReceipt(
        _sale(receiptNo: 5),
      );

      expect(outcome.isRejected, isTrue);
      expect(
        transport.calls,
        0,
        reason:
            'ни одного байта чека мимо очереди — даже когда принтер под рукой и '
            'ответил бы успехом',
      );
    },
  );
}

SaleReceiptData _sale({required int receiptNo, DateTime? at}) =>
    SaleReceiptData(
      receiptNo: receiptNo,
      posId: 1,
      posName: 'Касса-1',
      storeName: 'ТОО ТестПОС',
      dateTime: at ?? DateTime(2026, 7, 31, 12, 0),
      cashierName: 'Иванова А.',
      products: [
        ReceiptProductLine(
          name: 'Хлеб',
          quantity: Decimal.fromInt(1),
          price: Decimal.parse('250.00'),
          total: Decimal.parse('250.00'),
        ),
      ],
      payments: [
        ReceiptPaymentLine(
          name: 'Наличные',
          amount: Decimal.parse('250.00'),
          isCash: true,
        ),
      ],
      totalAmount: Decimal.parse('250.00'),
    );

/// Провод до принтера: считает отправки, помнит последнюю и отвечает так, как
/// велено.
class _RecordingTransport {
  int calls = 0;
  Uint8List? lastPayload;

  /// `null` — принтер напечатал; строка — принтер недоступен и назвал причину.
  String? failWith;

  Future<PrintResult> call(Uint8List payloadBytes) async {
    calls++;
    lastPayload = payloadBytes;
    final reason = failWith;
    if (reason != null) return PrintResult.error(reason);
    return PrintResult.ok(bytesSent: payloadBytes.length);
  }
}

/// Исправный принтер в DI — чтобы отказ последнего теста нельзя было объяснить
/// отсутствием железа.
class _AlwaysOkPrinter extends BufferedPrinterManager {
  _AlwaysOkPrinter(this._transport);

  final _RecordingTransport _transport;

  @override
  bool get isConnected => true;

  @override
  Future<PrinterConnectionResult> connect() async => PrinterConnectionResult.ok(
    const PrinterInfo(name: 'ok', address: 'test://ok'),
  );

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrinterStatus> getStatus() async => PrinterStatus.ok;

  @override
  Future<PrintResult> writeRaw(Uint8List data) => _transport.call(data);
}
