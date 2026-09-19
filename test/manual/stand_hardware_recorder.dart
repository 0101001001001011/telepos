/// Записывающие заглушки железа кассы для стенда — задача 21, сценарий 6.
///
/// # Чего эти заглушки НЕ доказывают
///
/// **Ни одна из них не доказывает, что чек напечатался, и ни одна не
/// доказывает, что ОФД принял документ.** Принтера здесь нет, оператора нет,
/// сети до оператора нет. Всё, что здесь можно увидеть, — что касса **позвала
/// свой порт, и позвала его с верной продажей**: с тем номером чека, той
/// суммой, тем составом и теми видами оплаты, которые только что провёл
/// терминал. Это и есть проверяемое утверждение решения заказчика №1 —
/// «терминал продаёт полностью, но железо и база остаются кассой», — и
/// больше ничего.
///
/// Принять эти заглушки за проверку печати значило бы завести ровно тот
/// ложный зелёный, ради снятия которого они и написаны. Поэтому:
///
/// * зелёный журнал здесь **не закрывает** «чек напечатан» — это проверяется
///   только железом;
/// * зелёный журнал здесь **не закрывает** «документ фискализован» — это
///   проверяется только настоящим оператором;
/// * зелёный журнал здесь **закрывает** «касса собрала верный документ и
///   отдала его своему порту», и это то единственное, что вообще может
///   сломаться от переезда продажи на браузерный терминал.
///
/// # Почему заглушка, а не `null`
///
/// При `null` касса выходит из этих путей почти молча: `_print` и
/// `_openDrawer` возвращают `null`, и ни одна из этих веток не пишет в журнал
/// ни строки. Снаружи продажа выглядит успешной и «напечатанной», не
/// напечатав ничего. Разница между «не требовалось» и «не сделано» здесь
/// исчезает — а это как раз та разница, ради которой сценарий 6 существует.
///
/// **Задача 5 закрыла из трёх веток одну.** `_fiscalize` при `null` больше не
/// возвращает `SaleFiscalization.notRequired`: она возвращает
/// `FiscalState.fiscalModuleAbsent` и пишет `error` в журнал каждым чеком.
/// Печать и ящик остались молчаливыми, и поэтому заглушка здесь по-прежнему
/// нужна: своего `fiscalModuleAbsent` у принтера и у ящика нет.
///
/// # Почему запись довода, а не счётчика вызовов
///
/// «Позвана 1 раз» не отличает верный чек от чужого. Каждая запись поэтому
/// несёт **то, чем касса позвала порт**: номер чека, кассу, сумму, состав и
/// разбивку по видам оплаты. Сверять есть что, и подмена звена видна.
///
/// **Исключение, и оно про контракт, а не про заглушку:** у денежного ящика
/// доводов нет вовсе — `typedef CashDrawerOpener = Future<bool> Function()`.
/// Номер чека до него не доезжает (`_openDrawer(receiptNo)` его не передаёт),
/// поэтому про ящик записать можно ровно «позван», и это предел самого
/// контракта, а не упущение здесь.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';

import 'package:telepos/data/fiscal/offline_queueing_provider.dart'
    show FiscalQueueEntry, FiscalQueueStatus, FiscalQueueStore;
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/refund/refund_receipt_printer.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

/// Как заглушки обязаны себя вести. Меняется с петли (`stand/hardware-mode`).
///
/// Отказ нужен не для полноты: успешный оператор оставляет ветку
/// `_unfiscalized` непройденной, а именно она пишет «чек не фискализован —
/// оплата проведена» и кладёт строку в очередь бед. Без способа отказать
/// половина пути завершения оплаты не наблюдаема вовсе.
enum StandHardwareMode { ok, fail, crash }

/// Общий журнал всех портов железа кассы.
///
/// Один на стенд, а не по журналу на порт: порядок между фискализацией,
/// печатью и ящиком — сам по себе предмет проверки (фискальный номер обязан
/// попасть на бумагу, значит оператор обязан ответить раньше печати), и в
/// двух журналах порядок пришлось бы восстанавливать по часам.
class StandHardwareJournal {
  StandHardwareJournal({this.echo = true});

  /// Печатать ли каждую запись в консоль стенда. Выключается пробами: там
  /// журнал читают возвратом, а не глазами.
  final bool echo;

  final List<Map<String, Object?>> entries = <Map<String, Object?>>[];

  /// Поведение портов. Меняется снаружи — см. [StandHardwareMode].
  StandHardwareMode fiscalMode = StandHardwareMode.ok;
  StandHardwareMode printerMode = StandHardwareMode.ok;
  StandHardwareMode drawerMode = StandHardwareMode.ok;

  void record(String port, String call, Map<String, Object?> args) {
    final entry = <String, Object?>{
      'seq': entries.length + 1,
      'at': DateTime.now().toIso8601String(),
      'port': port,
      'call': call,
      ...args,
    };
    entries.add(entry);
    if (echo) {
      stdout.writeln('[стенд] железо  $port.$call ${jsonEncode(args)}');
    }
  }

  void clear() => entries.clear();

  /// Записи одного порта — чтобы проба сверяла состав, а не искала по списку.
  List<Map<String, Object?>> of(String port) =>
      entries.where((e) => e['port'] == port).toList();
}

/// Фискальный оператор, который ничего не фискализует и записывает, чем его
/// позвали. См. докстринг файла о том, чего это не доказывает.
class RecordingFiscalService implements FiscalService {
  RecordingFiscalService(this._journal);

  final StandHardwareJournal _journal;

  /// Оператор включён: иначе `isOfdSale` вернёт `false` ещё до
  /// `fiscalizeSale`, и путь снова окажется непройденным — только теперь по
  /// другой причине и так же молча.
  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  }) async {
    _journal.record('fiscal', 'fiscalizeSale', {
      'receiptNo': saleReceiptNo,
      'posId': salePosId,
      // Деньги строками — то же правило, что на проводе (I144): `double`
      // здесь превратил бы 0.1+0.2 в наблюдаемую ложь.
      'amount': amount.toString(),
      'cashAmount': cashAmount.toString(),
      'cardAmount': cardAmount.toString(),
      'mobileAmount': mobileAmount.toString(),
      'offsetAmount': offsetAmount.toString(),
      'offsetLayout': offsetLayout.name,
      'excludeCertificatePositions': excludeCertificatePositions,
      // Сам ИИН/БИН не записывается — только то, был ли он назван: это
      // персональные данные, а журнал стенда читается и пересылается.
      'customerBinGiven': customerBin != null && customerBin.isNotEmpty,
      'mode': _journal.fiscalMode.name,
    });
    return _answer('ФП-${saleReceiptNo.toString().padLeft(6, '0')}');
  }

  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal creditAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
  }) async {
    _journal.record('fiscal', 'fiscalizeRefund', {
      'refundLocalId': refundLocalId,
      'originalSaleReceiptNo': originalSaleReceiptNo,
      'amount': amount.toString(),
      'cashAmount': cashAmount.toString(),
      'cardAmount': cardAmount.toString(),
      'mobileAmount': mobileAmount.toString(),
      'bonusAmount': bonusAmount.toString(),
      'creditAmount': creditAmount.toString(),
      'excludeCertificatePositions': excludeCertificatePositions,
      'offsetAmount': offsetAmount.toString(),
      'offsetLayout': offsetLayout.name,
      'mode': _journal.fiscalMode.name,
    });
    return _answer('ФПВ-${refundLocalId.toString().padLeft(6, '0')}');
  }

  @override
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    _journal.record('fiscal', 'fiscalizePrepayment', {
      'operationId': operationId,
      'amount': amount.toString(),
      'paymentKind': paymentKind.name,
      'positionName': positionName,
      'mode': _journal.fiscalMode.name,
    });
    return _answer('ФПА-${operationId.toString().padLeft(6, '0')}');
  }

  FiscalResult _answer(String sign) {
    switch (_journal.fiscalMode) {
      case StandHardwareMode.ok:
        return FiscalResult(success: true, fiscalSign: sign);
      case StandHardwareMode.fail:
        return const FiscalResult(
          success: false,
          errorMessage: 'стенд: оператору велено отказать',
          errorCode: FiscalErrorCode.unknown,
        );
      case StandHardwareMode.crash:
        throw StateError('стенд: оператору велено упасть');
    }
  }

  /// Всё остальное — громко, а не тихо. Заглушка, отвечающая правдоподобным
  /// значением на метод, о котором её не спрашивали, была бы вторым изданием
  /// того же молчаливого `null`.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'стенд: ${invocation.memberName} у фискального оператора не поднят',
  );
}

/// Журнал стенда **поверх** службы печати, а не вместо неё.
///
/// # Что здесь изменилось 2026-09-18 и почему это был пробел, а не предел
///
/// До этого дня класс назывался «принтер, который ничего не печатает»: он
/// записывал довод и возвращал `accepted`, не собрав ни одного байта. Тем
/// самым из проверки выпадало ровно то, ради чего написан эмулятор ESC/POS:
/// ширина ленты, шапка и подвал шаблона, кодовая страница, рез и очередь
/// печати. Решение заказчика 2026-09-18 назвало это пробелом стенда —
/// «эмулятор Принтера мы делали именно для этого».
///
/// Теперь при заданном [inner] стенд собирает **настоящий**
/// `ReceiptPrintServiceImpl`, и байты уходят той же дорогой, что на кассе:
/// шаблон из базы → ширина из привязки принтера → `PrintQueue` →
/// `PrinterManager` → сокет эмулятора. Подстановка — **адресом**
/// (`ipAddress`/`port` привязки), как и задумано: ни одной правки в `lib/`
/// это не потребовало.
///
/// Журнал остался сверху и записывает то же, что записывал: журнальная
/// запись — это довод, которым касса позвала порт, а не доказательство
/// печати. Вторая запись `<вызов>/submitted` называет исход очереди — по ней
/// видно, приняла ли очередь задание и почему отказала.
///
/// # Что по-прежнему остаётся журналом, и это не забывчивость
///
/// * **Денежный ящик.** У стенда своя дверь беды ящика
///   (`stand/hardware?drawer=fail`), и на ней стоят живые проверки: импульс
///   ящика идёт через тот же принтер, но отличить «касса не позвала» от
///   «принтер не открыл» на эмуляторе нечем — соленоида нет. Дверь стенда
///   остаётся инструментом, и подменять её ответом эмулятора значило бы
///   потерять единственный способ показать кассиру беду.
/// * **Режимы `fail` и `crash`.** Отказ и падение принтера задаются дверью
///   стенда и до настоящей службы не доходят вовсе: `fail` — это проверка
///   «очередь не приняла», а не «эмулятор не ответил». Отказы самого
///   прибора — бумага, крышка, обрыв — задаются пультом эмулятора
///   (`POST /_emul/fault`), и они как раз проходят весь путь.
class RecordingPrinter implements ReceiptPrintService {
  RecordingPrinter(this._journal, {ReceiptPrintService? inner})
    : _inner = inner;

  final StandHardwareJournal _journal;

  /// Настоящая служба печати кассы. `null` — стенд поднят без принтера
  /// (привязки нет), и тогда класс ведёт себя как прежде: записывает довод и
  /// отвечает `accepted`, ничего не собрав.
  final ReceiptPrintService? _inner;

  @override
  Future<PrintSubmitOutcome> printSaleReceipt(SaleReceiptData data) =>
      _handle('printSaleReceipt', data, (s) => s.printSaleReceipt(data));

  @override
  Future<PrintSubmitOutcome> printSaleDuplicate(SaleReceiptData data) =>
      _handle('printSaleDuplicate', data, (s) => s.printSaleDuplicate(data));

  Future<PrintSubmitOutcome> _handle(
    String call,
    SaleReceiptData data,
    Future<PrintSubmitOutcome> Function(ReceiptPrintService) print,
  ) async {
    final refusal = _record(call, data);
    final inner = _inner;
    if (refusal.status != PrintSubmitStatus.accepted || inner == null) {
      return refusal;
    }
    final outcome = await print(inner);
    _journal.record('printer', '$call/submitted', {
      'jobId': outcome.jobId,
      'status': outcome.status.name,
      'message': outcome.message,
    });
    return outcome;
  }

  PrintSubmitOutcome _record(String call, SaleReceiptData data) {
    _journal.record('printer', call, {
      'receiptNo': data.receiptNo,
      'posId': data.posId,
      'totalAmount': data.totalAmount.toString(),
      // **Оба поля тут почти всегда пусты, и это не дефект печати.**
      // Измерено пробой этого файла 2026-09-07: `SaleReceiptComposer`
      // верхнее поле `fiscalNumber` не заполняет вовсе (оно остаётся
      // умолчанием конструктора), а `fiscal` собирает
      // `buildReceiptRequisites` из строки `FiscalReceipts` — то есть из
      // того, что записал **настоящий** оператор. Заглушка такой строки не
      // пишет и писать не должна: подделав её, она стала бы утверждать
      // «документ фискализован», чего здесь не происходит.
      //
      // Значит порядок «оператор ответил раньше печати» по этим полям на
      // стенде не проверяется — он проверяется номерами `seq` в журнале.
      // Читать пустоту здесь как «фискальный номер не попал на бумагу»
      // было бы ошибкой измерения.
      'fiscalNumber': data.fiscalNumber,
      'fiscalInfo': data.fiscal == null
          ? null
          : {
              'fiscalNumber': data.fiscal!.fiscalNumber,
              'fiscalSign': data.fiscal!.fiscalSign,
              'rnm': data.fiscal!.rnm,
              'znm': data.fiscal!.znm,
            },
      'products': [
        for (final p in data.products)
          {
            'name': p.name,
            'quantity': p.quantity.toString(),
            'price': p.price.toString(),
            'total': p.total.toString(),
          },
      ],
      'payments': [
        for (final p in data.payments)
          {'name': p.name, 'amount': p.amount.toString(), 'isCash': p.isCash},
      ],
      'mode': _journal.printerMode.name,
    });
    final jobId = 'stand-sale-${data.posId}-${data.receiptNo}';
    switch (_journal.printerMode) {
      case StandHardwareMode.ok:
        return PrintSubmitOutcome.accepted(jobId);
      case StandHardwareMode.fail:
        return PrintSubmitOutcome.rejected(
          jobId,
          'стенд: очереди печати велено не принять задание',
        );
      case StandHardwareMode.crash:
        throw StateError('стенд: принтеру велено упасть');
    }
  }

  @override
  Future<bool> openCashDrawer() async {
    _journal.record('drawer', 'openCashDrawer', {
      // Доводов у этого порта нет вовсе — см. докстринг файла.
      'mode': _journal.drawerMode.name,
    });
    return _journal.drawerMode == StandHardwareMode.ok;
  }

  /// Опрос прибора — у настоящей службы, если она есть.
  ///
  /// Дверь стенда здесь только запрещает: `crash` отвечает «нет» не спросив.
  /// Всё остальное спрашивается у эмулятора опросом `DLE EOT` — то есть
  /// «бумага кончилась» и «крышка открыта», заданные пультом эмулятора,
  /// доходят до кассы тем же путём, что от железа.
  @override
  Future<bool> isPrinterAvailable() async {
    if (_journal.printerMode == StandHardwareMode.crash) return false;
    return await _inner?.isPrinterAvailable() ?? true;
  }

  /// Ширина ленты — у настоящей службы, и это не удобство.
  ///
  /// Найдено живой приёмкой 2026-09-19: вкладка диагностики принтера на
  /// планшете показывала вечный спиннер. Причина была здесь —
  /// `noSuchMethod` бросал `UnimplementedError`, потому что ширину
  /// спрашивает `LocalHardwareDiagnostics.watchPrinter` **до первого
  /// кадра**, а стенд этого метода не поднимал. То есть стенд был обрезанной
  /// кассой ровно в том месте, которое и приехали проверять.
  ///
  /// Узкая лента при отсутствии службы — тем же доводом, что у
  /// `LocalHardwareDiagnostics._paperWidth`: узкий чек читается на любой
  /// ленте, широкий на узкой ломается переносами.
  @override
  Future<ReceiptPaperWidth> currentPaperWidth() async =>
      await _inner?.currentPaperWidth() ?? ReceiptPaperWidth.mm58;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'стенд: ${invocation.memberName} у принтера не поднят',
  );
}

/// Принтер чеков возврата — отдельный узкий контракт кассы
/// ([RefundReceiptPrinter]), а не метод принтера продажи.
class RecordingRefundPrinter implements RefundReceiptPrinter {
  RecordingRefundPrinter(this._journal);

  final StandHardwareJournal _journal;

  @override
  Future<void> printRefund({
    required RefundOutcome outcome,
    required List<RefundLine> lines,
    required int userId,
  }) async {
    _journal.record('refundPrinter', 'printRefund', {
      'refundLocalId': outcome.refundLocalId,
      'saleReceiptNo': outcome.saleReceiptNo,
      'salePosId': outcome.salePosId,
      'amount': outcome.amount.toString(),
      'lineCount': outcome.lineCount,
      'paymentCount': outcome.paymentCount,
      'userId': userId,
      'lines': [
        for (final l in lines)
          {
            'id': l.id,
            'productId': l.productId,
            'name': l.name,
            'quantity': l.quantity.toString(),
            'price': l.price.toString(),
          },
      ],
      'mode': _journal.printerMode.name,
    });
    if (_journal.printerMode == StandHardwareMode.crash) {
      throw StateError('стенд: принтеру возврата велено упасть');
    }
  }
}

/// Слип подарочного сертификата — выпуск при продаже и новая бумажка при
/// возврате.
///
/// Приёмка 2026-09-17 нашла, что стенд собирал `LocalCertificateIssuer` и
/// `RefundUseCaseImpl` **без** принтера слипов, хотя касса передаёт его обоим
/// (`service_locator.dart`). Порт необязательный, `null` — «печати нет», и
/// стенд молча не печатал слипов вовсе: шаг 8 приёмки проверять было нечем.
///
/// Записывается довод: номер, номинал, остаток, срок, возврат-источник и
/// **есть ли у бумажки ПИН** — сам ПИН (его хэш) в журнал не едет, как и на
/// слип.
class RecordingCertificateSlipPrinter implements CertificateSlipPrinter {
  RecordingCertificateSlipPrinter(this._journal);

  final StandHardwareJournal _journal;

  @override
  Future<void> printIssued({
    required GiftCertificate certificate,
    int? userId,
    int? refundLocalId,
    String? sourceNumber,
  }) async {
    _journal.record('printer', 'printCertificateSlip', {
      'number': certificate.number,
      'nominal': certificate.nominal.toString(),
      'balance': certificate.balance.toString(),
      'status': certificate.status.code,
      'expiresAt': certificate.expiresAt,
      'hasPin': certificate.pinHash != null,
      'userId': userId,
      'refundLocalId': refundLocalId,
      'sourceNumber': sourceNumber,
      'mode': _journal.printerMode.name,
    });
  }

  @override
  List<CertificateSlipTrouble> takeTroubles() => const [];

  @override
  Future<void> get pending async {}
}

/// Очередь фискальных бед. Достижима только по отказу оператора
/// (`_unfiscalized`), поэтому без [StandHardwareMode.fail] в журнале её не
/// будет — и это правда, а не пропуск.
class RecordingFiscalQueueStore implements FiscalQueueStore {
  RecordingFiscalQueueStore(this._journal);

  final StandHardwareJournal _journal;
  final Map<String, FiscalQueueEntry> _entries = {};

  @override
  Future<void> enqueue(FiscalQueueEntry entry) async {
    _journal.record('fiscalQueue', 'enqueue', {
      'idempotencyKey': entry.idempotencyKey,
      'opType': entry.opType.name,
      'status': entry.status.name,
      'payload': entry.payload,
    });
    _entries.putIfAbsent(entry.idempotencyKey, () => entry);
  }

  @override
  Future<List<FiscalQueueEntry>> pending() async => _entries.values
      .where((e) => e.status == FiscalQueueStatus.pending)
      .toList();

  @override
  Future<List<FiscalQueueEntry>> failed() async => _entries.values
      .where((e) => e.status == FiscalQueueStatus.failed)
      .toList();

  @override
  Future<void> update(FiscalQueueEntry entry) async {
    _entries[entry.idempotencyKey] = entry;
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    _entries.remove(idempotencyKey);
  }

  @override
  Future<int> pendingCount() async => (await pending()).length;

  @override
  Future<int> failedCount() async =>
      (await failed()).where((e) => e.writeOff == null).length;
}

/// Денежный ящик как отдельный порт оплаты (`CashDrawerOpener`).
///
/// Тот же журнал, что у [RecordingPrinter.openCashDrawer], и это не дубль:
/// `LocalPaymentService` зовёт **свой** довод `drawer`, а не принтер, и
/// перепутать их — настоящая ошибка сборки, которую видно только по тому,
/// какая из двух записей появилась.
///
/// Тот же порт получает и `LocalRefundService` (приёмка 2026-09-17: возврат с
/// наличной частью ящика не открывал), и запись у них одна и та же — ящик
/// у кассы один. Отличить продажу от возврата в журнале можно по соседним
/// записям (`printRefund` против `printSaleReceipt`).
Future<bool> recordingDrawer(StandHardwareJournal journal) async {
  journal.record('drawer', 'paymentDrawerPort', {
    'mode': journal.drawerMode.name,
  });
  return journal.drawerMode == StandHardwareMode.ok;
}
