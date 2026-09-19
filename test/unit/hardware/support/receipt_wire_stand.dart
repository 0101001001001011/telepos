import 'dart:io';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/di/print_module.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

import '../../../emulators/escpos/emulator.dart';
import '../../../emulators/escpos/faults.dart';
import '../../../emulators/escpos/render.dart';

/// Стенд «касса → очередь → сетевой ESC/POS-принтер» для проб ширины ленты и
/// шаблона чека.
///
/// Приёмник — **эмулятор принтера** (`test/emulators/escpos/emulator.dart`),
/// а не свой сокет: он разбирает поток тем же разборщиком, что и живой стенд,
/// и отдаёт задание целиком. Порт — из диапазона 18500–18599 (правило машины:
/// 9100 чужой), первый свободный.
///
/// Всё, что касса читает при печати, заведено так же, как в приложении:
/// установка (`ThisPos`), свой терминал, привязка чекового принтера, сохранённая
/// **репозиторием привязок** — тем же путём, каким её сохраняет экран
/// «Настройки принтера», — и очередь из `print_module.dart`.
class ReceiptWireStand {
  ReceiptWireStand._(this.db, this.emulator, this.terminalId, this.printer);

  final AppDatabase db;
  final EscPosEmulator emulator;
  final int terminalId;
  final WifiPrinterManager printer;

  static const String networkProfileId = 'printer.escpos.80mm';

  /// Поднимает стенд и регистрирует снос в `addTearDown`.
  ///
  /// [paperWidthMm] — что оператор выбрал на экране принтера; `null` — опция
  /// не выбиралась вовсе.
  static Future<ReceiptWireStand> boot({int? paperWidthMm}) async {
    final emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false);
    await _startInRange(emulator);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.thisPosDao.insertInitialConfig(
      companyName: 'ТОО ТестПОС',
      iinbin: '123456789012',
      cashBoxName: 'Касса 1',
      countryCode: 0,
      currencyCode: 0,
      currencySymbol: '₸',
      currencyNameShort: 'KZT',
      // Мастер выбрал узкую ленту — ровно так начинается жалоба: потом
      // оператор поменял ширину на экране принтера.
      paperWidth: 32,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );
    await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
        .write(const ThisPosEntriesCompanion(id: Value(1)));

    final catalog = BuiltinDeviceProfileCatalog();
    final terminals = LocalTerminalRepository(db);
    final terminal = await terminals.self();
    final bindings = LocalDeviceBindingRepository(db, catalog);

    final printer = WifiPrinterManager(
      host: InternetAddress.loopbackIPv4.address,
      port: emulator.port,
      timeout: const Duration(seconds: 5),
      retryBudget: const Duration(seconds: 20),
      retryBackoff: const Duration(milliseconds: 20),
    );

    GetIt.I
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<TerminalRepository>(terminals)
      ..registerSingleton<DeviceProfileCatalog>(catalog)
      ..registerSingleton<DeviceBindingRepository>(bindings)
      ..registerSingleton<PrinterManager>(printer);
    registerPrintQueue(GetIt.I);

    final stand = ReceiptWireStand._(db, emulator, terminal.id, printer);
    await stand.choosePaperWidth(paperWidthMm);

    addTearDown(() async {
      await GetIt.I.reset();
      await printer.disconnect();
      await emulator.stop();
      await db.close();
    });
    return stand;
  }

  static Future<void> _startInRange(EscPosEmulator emulator) async {
    SocketException? last;
    for (var port = 18500; port <= 18599; port++) {
      try {
        await emulator.start(InternetAddress.loopbackIPv4.address, port);
        return;
      } on SocketException catch (e) {
        last = e;
      }
    }
    throw StateError('в 18500–18599 нет свободного порта: $last');
  }

  /// То, что делает экран «Настройки принтера» кнопкой «Сохранить».
  Future<void> choosePaperWidth(int? paperWidthMm) async {
    await GetIt.I<DeviceBindingRepository>().save(
      terminalId,
      DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: networkProfileId,
        parameters: {
          'ipAddress': InternetAddress.loopbackIPv4.address,
          'port': '${emulator.port}',
        },
        options: {
          if (paperWidthMm != null) 'paperWidthMm': '$paperWidthMm',
        },
      ),
    );
  }

  /// Ждёт, пока очередь отдаст принтеру следующее задание, и возвращает его
  /// байты.
  Future<List<int>> nextJob(
    Future<PrintSubmitOutcome> Function() print,
  ) async {
    final before = emulator.jobs.length;
    final outcome = await print();
    expect(
      outcome.status,
      PrintSubmitStatus.accepted,
      reason: 'задание не принято очередью: ${outcome.message}',
    );
    final queue = GetIt.I<PrintQueue>();
    if (queue is PrintQueueLocal) await queue.whenIdle();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (emulator.jobs.length <= before) {
      if (DateTime.now().isAfter(deadline)) {
        fail('эмулятор принтера не получил задания за 20 с');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return emulator.jobs[before];
  }
}

/// Строки бумаги, как их разобрал эмулятор: текст между переводами строки.
List<String> printedLines(List<int> job) {
  final lines = <String>[];
  final current = StringBuffer();
  for (final e in parseEscPos(job)) {
    switch (e.kind) {
      case 'text':
        current.write(e.text);
      case 'newline':
        lines.add(current.toString());
        current.clear();
    }
  }
  if (current.isNotEmpty) lines.add(current.toString());
  return lines;
}

/// Ширина чека в символах — самая длинная строка. Разделители и строки
/// «подпись … сумма» добиваются пробелами до полной ширины, поэтому максимум
/// равен числу колонок, которым чек собран.
int printedColumns(List<int> job) =>
    printedLines(job).map((l) => l.length).fold(0, math.max);

/// Одна запись бумаги: строка текста с оформлением, действовавшим на ней, или
/// событие без текста (`qr`, `cut`, `feed`, `init`, `codepage`, `unknown`).
class PaperEntry {
  PaperEntry(
    this.kind,
    this.text, {
    this.align = alignLeft,
    this.bold = false,
    this.size = sizeNormal,
  });

  static const String alignLeft = 'по левому краю';
  static const String alignCenter = 'по центру';
  static const String alignRight = 'по правому краю';
  static const String sizeNormal = 'обычный размер';
  static const String sizeDouble = 'двойной размер';

  final String kind;
  final String text;
  final String align;
  final bool bold;
  final String size;

  bool get isLine => kind == 'line';

  @override
  String toString() => isLine
      ? 'line[$align${bold ? ', жирный' : ''}, $size]: $text'
      : '$kind: $text';
}

/// Бумага, как её разобрал эмулятор: строки с оформлением **по состоянию
/// принтера** в момент их печати, а не по присутствию команд в потоке.
List<PaperEntry> paperOf(List<int> job) {
  var align = PaperEntry.alignLeft;
  var bold = false;
  var size = PaperEntry.sizeNormal;
  final out = <PaperEntry>[];
  final text = StringBuffer();
  String? lineAlign;
  bool? lineBold;
  String? lineSize;

  void capture() {
    lineAlign ??= align;
    lineBold ??= bold;
    lineSize ??= size;
  }

  for (final e in parseEscPos(job)) {
    switch (e.kind) {
      case 'align':
        align = e.text;
      case 'bold':
        bold = e.text == 'жирный вкл';
      case 'size':
        size = e.text;
      case 'text':
        capture();
        text.write(e.text);
      case 'newline':
        capture();
        out.add(
          PaperEntry(
            'line',
            text.toString(),
            align: lineAlign!,
            bold: lineBold!,
            size: lineSize!,
          ),
        );
        text.clear();
        lineAlign = null;
        lineBold = null;
        lineSize = null;
      default:
        out.add(PaperEntry(e.kind, e.text));
    }
  }
  return out;
}

// ─── Данные документов ───────────────────────────────────────────────────────

SaleReceiptData wireSale({bool duplicate = false}) => SaleReceiptData(
  receiptNo: 77,
  posId: 1,
  posName: 'Касса 1',
  storeName: 'ТОО ТестПОС',
  dateTime: DateTime(2026, 9, 15, 12, 30),
  cashierName: 'Иванова А.',
  products: [
    ReceiptProductLine(
      name: 'Хлеб Бородинский',
      quantity: Decimal.fromInt(2),
      price: Decimal.parse('250.00'),
      total: Decimal.parse('500.00'),
    ),
  ],
  payments: [
    ReceiptPaymentLine(
      name: 'Наличные',
      amount: Decimal.parse('500.00'),
      isCash: true,
    ),
  ],
  totalAmount: Decimal.parse('500.00'),
  isDuplicate: duplicate,
  seller: const ReceiptSellerInfo(
    binIin: '123456789012',
    address: 'г. Алматы, ул. Абая 10',
  ),
  fiscal: const ReceiptFiscalInfo(
    fiscalNumber: '987654321',
    fiscalSign: '12345678',
    rnm: 'RNM-001122',
    znm: 'ZNM-7788',
    ofdName: 'WebKassa',
    ticketUrl: 'https://consumer.oofd.kz/ticket/7f3ab9c2202609151230',
  ),
);

RefundReceiptData wireRefund({bool duplicate = false}) => RefundReceiptData(
  refundId: 12,
  originalReceiptNo: 77,
  posId: 1,
  posName: 'Касса 1',
  storeName: 'ТОО ТестПОС',
  dateTime: DateTime(2026, 9, 15, 12, 40),
  cashierName: 'Иванова А.',
  products: [
    ReceiptProductLine(
      name: 'Хлеб Бородинский',
      quantity: Decimal.one,
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
  isDuplicate: duplicate,
);
