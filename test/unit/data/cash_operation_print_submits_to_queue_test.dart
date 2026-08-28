import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_job_store_drift.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/usecases/cash_operation/cash_operation_receipt_service_impl.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

/// Квитанция кассовой операции идёт **в очередь**, а не в принтер.
///
/// До этой правки `CashOperationReceiptServiceImpl.printReceipt` звала
/// `PrinterManager.writeRaw` напрямую. Это был второй писатель в один принтер —
/// то есть квитанция внесения, способная вклиниться между строками чека
/// покупателя (И29), — и единственная квитанция в системе, которая ещё
/// терялась на недоступном принтере: всё остальное к тому моменту переживало
/// его заданием в базе.
///
/// Здесь всё настоящее и ничего не подменено заглушкой, кроме самого провода до
/// принтера: настоящая drift-схема в памяти, настоящее `DriftPrintJobStore`,
/// настоящая `PrintQueueLocal`, настоящие обе службы печати. Недоступный
/// принтер — это транспорт, отвечающий отказом; другого способа узнать о нём у
/// очереди нет.
void main() {
  late AppDatabase db;
  late _RecordingTransport transport;
  late PrintQueueLocal queue;
  late CashOperationReceiptServiceImpl service;

  /// Очередь с **одной** попыткой на возможность и заведомо длинным отступом —
  /// так число обращений к принтеру наблюдаемо, а прогон не зависит от
  /// настоящих часов. Обоснование целиком — в парном файле
  /// `receipt_print_submits_to_queue_test.dart`.
  PrintQueueLocal buildQueue(PrintJobStore store) => PrintQueueLocal(
    store: store,
    transport: transport.call,
    maxAttemptsPerOpportunity: 1,
    firstBackoff: const Duration(minutes: 5),
    maxBackoff: const Duration(minutes: 5),
  );

  void registerAll() {
    final store = DriftPrintJobStore(db);
    queue = buildQueue(store);
    GetIt.I
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<Talker>(Talker())
      ..registerSingleton<TerminalRepository>(LocalTerminalRepository(db))
      ..registerSingleton<PrintJobStore>(store)
      ..registerSingleton<PrintQueue>(queue);
    service = CashOperationReceiptServiceImpl(db: db, logger: GetIt.I<Talker>());
  }

  /// Наполненный набор, а не пустая база (скилл `qa-depth`, правило нуля).
  ///
  /// Здесь лежат: операции всех трёх видов; кассиры с казахской и киргизской
  /// кириллицей и с латиницей; суммы, на которых видно направление округления;
  /// операция **чужой смены**, которая не должна попасть ни в одно задание; и
  /// граничный момент — последняя секунда суток.
  ///
  /// Возвращает идентификаторы операций по понятному имени.
  Future<Map<String, int>> seedOperations() async {
    Future<int> insert({
      required CashInOutType type,
      required Decimal amount,
      required String note,
      required int userId,
      required DateTime at,
    }) => db.cashOperationDao.insert(
      CashOperationsCompanion.insert(
        amount: amount,
        type: type.index,
        accountId: const Value(1),
        userId: Value(userId),
        note: Value(note),
        docTime: Value(at.millisecondsSinceEpoch ~/ 1000),
        state: const Value(1),
      ),
    );

    final ids = <String, int>{};
    ids['investment'] = await insert(
      type: CashInOutType.investment,
      amount: Decimal.parse('15000.500'),
      note: 'Размен на утро, Дүкен №2',
      userId: 1,
      at: DateTime(2026, 7, 31, 9, 5),
    );
    // Сумма ровно на границе округления вниз/вверх: 2.675 в `double` — это
    // 2.67499999999999982, и `toStringAsFixed(2)` дал бы «2.67». Проверяется
    // ниже по байтам квитанции.
    ids['rounding'] = await insert(
      type: CashInOutType.expense,
      amount: Decimal.parse('2.675'),
      note: 'Ысык-Көл, мелочь',
      userId: 2,
      at: DateTime(2026, 7, 31, 12, 30),
    );
    ids['dividend'] = await insert(
      type: CashInOutType.dividend,
      amount: Decimal.parse('100000.000'),
      note: 'Toshkent, izъятие',
      userId: 3,
      at: DateTime(2026, 7, 31, 23, 59, 59),
    );
    // Записи, которых в результате быть не должно: чужая операция, о которой
    // никто не просил. Без них тест не отличает «нашёл нужную» от «взял любую».
    ids['untouched'] = await insert(
      type: CashInOutType.investment,
      amount: Decimal.parse('777.000'),
      note: 'Кассаүй, не для печати',
      userId: 1,
      at: DateTime(2026, 7, 30, 8, 0),
    );
    return ids;
  }

  setUp(() async {
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transport = _RecordingTransport();

    // Настоящее имя кассы обязательно: без него `TerminalRepository.self()`
    // отказывается выдумывать терминал, и владельца у задания не будет.
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

    // Кассиры на трёх письменностях: казахская и киргизская кириллица ловит
    // ошибки сравнения строк, невидимые на латинице.
    for (final user in const [
      (1, 'Иванова А.'),
      (2, 'Әбенова Г.'),
      (3, 'Aliyev T.'),
    ]) {
      await db.userDao.insertUser(
        UsersCompanion.insert(id: Value(user.$1), name: Value(user.$2)),
      );
    }

    registerAll();
  });

  tearDown(() async {
    await queue.dispose();
    await GetIt.I.reset();
    await db.close();
  });

  Future<List<PrintJob>> storedJobs() => GetIt.I<PrintJobStore>().jobs();

  Future<int> openShift() => db.shiftDao.insertShift(
    ShiftsCompanion.insert(
      userId: 1,
      openTime: DateTime(2026, 7, 31, 8).millisecondsSinceEpoch ~/ 1000,
      isOpened: true,
      isSynced: false,
    ),
  );

  test(
    'принтер недоступен — квитанция остаётся заданием в хранилище, а не теряется',
    () async {
      transport.failWith = 'Принтер не отвечает';
      final ids = await seedOperations();

      final outcome = await service.printReceipt(ids['investment']!);

      expect(
        outcome.isRejected,
        isFalse,
        reason:
            'недоступный принтер — не отказ приёма: квитанция принята и будет '
            'напечатана, когда принтер сможет (${outcome.message})',
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
            'ЭТО ВСЯ ЗАДАЧА: квитанция, не ушедшая в принтер, обязана остаться '
            'заданием в базе. Пустой список означает возврат к прежнему '
            'положению — деньги записаны, бумаги нет, повторить нечего. Ровно '
            'одно задание — и это доказывает, что напечаталась запрошенная '
            'операция, а не все четыре из набора',
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
      expect(job.failureReason, 'Принтер не отвечает');
      expect(
        job.payloadBytes,
        transport.lastPayload,
        reason: 'в задании лежат те же байты, что уезжали в принтер',
      );
      expect(job.terminalId, greaterThan(0));
      expect(job.posId, 1);

      // Байты — это именно квитанция запрошенной операции, а не чья-то чужая.
      final text = _decodeAscii(job.payloadBytes);
      expect(text, contains('КВИТАНЦИЯ #${_receiptNo(ids['investment']!)}'));
      expect(
        text,
        isNot(contains('КВИТАНЦИЯ #${_receiptNo(ids['untouched']!)}')),
        reason:
            'соседняя операция из набора в задание попасть не могла; если '
            'попала — служба печатает «что нашла», а не то, о чём просили',
      );
    },
  );

  test(
    'сумма доезжает до бумаги как Decimal: на double это была бы другая цифра',
    () async {
      transport.failWith = 'Принтер не отвечает';
      final ids = await seedOperations();

      await service.printReceipt(ids['rounding']!);
      await queue.whenIdle();

      final text = _decodeAscii((await storedJobs()).single.payloadBytes);
      expect(
        text,
        contains('2.68'),
        reason:
            'ШЕСТОЕ ЗНАЧЕНИЕ (скилл qa-depth): 2.675 — граница округления. В '
            '`double` это 2.67499999999999982, и на бумагу вышло бы «2.67». '
            'Тест краснеет, если сумма где-то по дороге станет double',
      );
      expect(
        text,
        isNot(contains('2.67 ')),
        reason: 'округление вниз означало бы недостачу в кассовой книге',
      );

      // И заодно: сумма, прошедшая через базу, осталась той же самой.
      final stored = await db.cashOperationDao.findById(ids['rounding']!);
      expect(stored!.amount, Decimal.parse('2.675'));
    },
  );

  test(
    'квитанция и чек продажи одной смены не сталкиваются на идентификаторе',
    () async {
      // Номер квитанции и номер чека идут своими нумерациями, и совпадение
      // «операция №N и чек №N в одной смене» — обычное дело. Без вида
      // документа в идентификаторе один из двух вернул бы `duplicate` и не
      // выдал бы бумаги вовсе.
      transport.failWith = 'Принтер не отвечает';
      await openShift();
      final ids = await seedOperations();
      final sharedNumber = ids['investment']!;

      final cash = await service.printReceipt(sharedNumber);
      await queue.whenIdle();
      final sale = await ReceiptPrintServiceImpl().printSaleReceipt(
        _sale(receiptNo: sharedNumber),
      );
      await queue.whenIdle();

      expect(cash.isRejected, isFalse, reason: cash.message);
      expect(sale.isRejected, isFalse, reason: sale.message);
      expect(
        sale.jobId,
        isNot(cash.jobId),
        reason:
            'один идентификатор на два разных документа означает, что второй '
            'не напечатается никогда',
      );

      final jobs = await storedJobs();
      expect(
        jobs,
        hasLength(2),
        reason: 'два документа — два задания, а не одно проглоченное',
      );
      // Смена у обоих одна и та же — иначе тест доказывал бы разницу сменами,
      // а не видом документа.
      final shiftId = (await db.shiftDao.findOpenedShift())!.id;
      for (final job in jobs) {
        expect(job.id, contains('/s$shiftId/'));
      }
      expect(cash.jobId, contains('/cashOperation/'));
      expect(sale.jobId, contains('/sale/'));
      expect(transport.calls, 2);
    },
  );

  test('та же квитанция дважды — одно задание, а не вторая бумага', () async {
    transport.failWith = 'Принтер не отвечает';
    final ids = await seedOperations();

    final first = await service.printReceipt(ids['dividend']!);
    await queue.whenIdle();
    final second = await service.printReceipt(ids['dividend']!);
    await queue.whenIdle();

    expect(first.status, PrintSubmitStatus.accepted);
    expect(
      second.status,
      PrintSubmitStatus.duplicate,
      reason:
          'идентификатор — чистая функция того, чем квитанция является. '
          '`accepted` здесь означал бы идентификатор из часов: повтор получал '
          'бы новый ключ и печатал бы вторую бумагу на то же движение денег',
    );
    expect(second.jobId, first.jobId);
    expect(
      await storedJobs(),
      hasLength(1),
      reason: 'одно движение денег — одно задание',
    );
    expect(
      transport.calls,
      1,
      reason: 'второй сдачи в принтер не было — она и была бы вторым чеком',
    );
  });

  test(
    'квитанция несуществующей операции отвергается с причиной, а не молча',
    () async {
      transport.failWith = 'Принтер не отвечает';
      await seedOperations();

      final outcome = await service.printReceipt(999999);

      expect(outcome.isRejected, isTrue);
      expect(outcome.message, contains('999999'));
      expect(
        await storedJobs(),
        isEmpty,
        reason: 'задания на несуществующий документ не бывает',
      );
      expect(transport.calls, 0);
    },
  );

  test(
    'без зарегистрированной очереди печать отказывает, а не пишет в принтер',
    () async {
      // Прямая запись «на всякий случай» здесь и была бы вторым путём: он
      // выглядел бы работающим ровно до первого недоступного принтера.
      final ids = await seedOperations();
      await queue.dispose();
      await GetIt.I.reset();
      GetIt.I
        ..registerSingleton<AppDatabase>(db)
        ..registerSingleton<Talker>(Talker())
        ..registerSingleton<TerminalRepository>(LocalTerminalRepository(db))
        ..registerSingleton<PrinterManager>(_AlwaysOkPrinter(transport));
      queue = buildQueue(DriftPrintJobStore(db));

      final outcome = await CashOperationReceiptServiceImpl(
        db: db,
        logger: GetIt.I<Talker>(),
      ).printReceipt(ids['investment']!);

      expect(outcome.isRejected, isTrue);
      expect(
        transport.calls,
        0,
        reason:
            'ни одного байта квитанции мимо очереди — даже когда принтер под '
            'рукой и ответил бы успехом',
      );
    },
  );
}

SaleReceiptData _sale({required int receiptNo}) => SaleReceiptData(
  receiptNo: receiptNo,
  posId: 1,
  posName: 'Касса-1',
  storeName: 'ТОО ТестПОС',
  dateTime: DateTime(2026, 7, 31, 12, 0),
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

/// Читает из байтов квитанции то, что можно прочитать без таблицы кодировки:
/// ASCII как есть, CP866-кириллицу — в юникод. Нужна только для проверок вида
/// «на бумаге стоит эта сумма и этот номер».
String _decodeAscii(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    if (b >= 0x20 && b < 0x80) {
      sb.writeCharCode(b);
    } else if (b >= 0x80 && b <= 0x9F) {
      sb.writeCharCode(b - 0x80 + 0x410);
    } else if (b >= 0xA0 && b <= 0xAF) {
      sb.writeCharCode(b - 0xA0 + 0x430);
    } else if (b >= 0xE0 && b <= 0xEF) {
      sb.writeCharCode(b - 0xE0 + 0x440);
    } else if (b == 0x0A) {
      sb.write('\n');
    }
  }
  return sb.toString();
}

/// Номер квитанции так, как он печатается на бумаге:
/// `CashOperationReceiptDataBuilder` дополняет `CashOperations.id` нулями до
/// шести знаков.
String _receiptNo(int operationId) => '$operationId'.padLeft(6, '0');

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
