import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_submission.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_document_id.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/fiscal/vat_calculator.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/receipt_builder.dart';

/// Собирает чеки и **сдаёт их в очередь печати**, а не пишет в принтер.
///
/// ## Что здесь изменилось и почему это вся задача
///
/// До этой правки `_print` писала готовые байты прямо в `PrinterManager`.
/// Неудача возвращалась как `false`, экран оплаты ловил её, показывал
/// предупреждение — и **задание исчезало вместе с локальными переменными
/// асинхронной функции**: деньги взяты, чек в базе, бумаги нет, повторить
/// нечего. Теперь единственный путь байтов к принтеру — [PrintQueue]:
/// недоступный принтер оставляет задание в хранилище, которое переживает
/// перезапуск программы.
///
/// **Второго, прямого пути для чеков нет.** Не «режим очереди рядом с обычным
/// режимом»: любой чек, отчёт, пречек и квитанция уходят через [_submit], и
/// другого места, откуда сюда попадают байты чека, в этом файле не осталось.
/// Мимо очереди идут ровно две вещи, и обе — не документы: опрос состояния
/// ([isPrinterAvailable]) и импульс денежного ящика ([openCashDrawer]);
/// обоснование у каждой на месте.
class ReceiptPrintServiceImpl implements ReceiptPrintService {
  ReceiptPrintServiceImpl({this.charWidth = 32, Talker? logger})
    : _logger = logger,
      _submission = PrintSubmission(logger: logger);

  /// Срок задания — общий для всех документов, обоснование на
  /// [PrintSubmission.documentLifetime].
  static const Duration documentLifetime = PrintSubmission.documentLifetime;

  final int charWidth;

  final Talker? _logger;

  /// Единственная дорога байтов в очередь — та же самая, которой пользуется
  /// служба квитанций кассовых операций.
  final PrintSubmission _submission;

  ReceiptOptions? _optionsCache;

  Future<ReceiptOptions> _resolveOptions() async {
    if (_optionsCache != null) return _optionsCache!;
    try {
      if (GetIt.I.isRegistered<AppDatabase>()) {
        final dao = GetIt.I<AppDatabase>().receiptTemplateDao;
        await dao.seedDefaults();
        _optionsCache = await dao.getSelectedOptions();
        return _optionsCache!;
      }
    } catch (e) {
      _logger?.debug('[ReceiptPrintService] options fallback to default: $e');
    }
    return _optionsCache = ReceiptOptions.kzDefault;
  }

  void invalidateOptionsCache() => _optionsCache = null;

  @override
  void invalidateReceiptOptionsCache() => invalidateOptionsCache();

  @override
  String renderSalePreviewText(SaleReceiptData data, ReceiptOptions options) {
    return _PreviewTextRenderer(
      options.paperWidth.charWidth,
    ).renderSale(data, options);
  }

  @override
  String renderZReportPreview({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashStart,
    required Decimal cashEnd,
    required Decimal cashIncome,
    required Decimal cashExpense,
  }) {
    return _decodeReceipt(
      _buildZReport(
        storeName: storeName,
        posName: posName,
        cashierName: cashierName,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        saleCount: saleCount,
        saleTotal: saleTotal,
        refundCount: refundCount,
        refundTotal: refundTotal,
        cashStart: cashStart,
        cashEnd: cashEnd,
        cashIncome: cashIncome,
        cashExpense: cashExpense,
      ),
    );
  }

  @override
  String renderXReportPreview({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime dateTime,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashInDrawer,
  }) {
    return _decodeReceipt(
      _buildXReport(
        storeName: storeName,
        posName: posName,
        cashierName: cashierName,
        dateTime: dateTime,
        saleCount: saleCount,
        saleTotal: saleTotal,
        refundCount: refundCount,
        refundTotal: refundTotal,
        cashInDrawer: cashInDrawer,
      ),
    );
  }

  String _decodeReceipt(ReceiptBuilder receipt) {
    final bytes = receipt.build();
    final sb = StringBuffer();
    var i = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b == 0x1B) {
        final cmd = i + 1 < bytes.length ? bytes[i + 1] : 0;
        switch (cmd) {
          case 0x40:
          case 0x69:
          case 0x6D:
            i += 2;
          case 0x70:
            i += 5;
          case 0x42:
            i += 4;
          default:
            i += 3;
        }
        continue;
      }
      if (b == 0x1D) {
        i += 3;
        continue;
      }
      if (b == 0x0A) {
        sb.write('\n');
        i++;
        continue;
      }
      if (b < 0x20) {
        i++;
        continue;
      }
      sb.write(_decodeCp866Byte(b));
      i++;
    }
    return sb.toString();
  }

  String _decodeCp866Byte(int b) {
    if (b < 0x80) return String.fromCharCode(b);
    if (b >= 0x80 && b <= 0x9F) return String.fromCharCode(b - 0x80 + 0x410);
    if (b >= 0xA0 && b <= 0xAF) return String.fromCharCode(b - 0xA0 + 0x430);
    if (b >= 0xE0 && b <= 0xEF) return String.fromCharCode(b - 0xE0 + 0x440);
    if (b == 0xF0) return 'Ё';
    if (b == 0xF1) return 'ё';
    if (b == 0xFC) return '№';
    return '?';
  }

  int _charWidthFor(ReceiptOptions options) => options.paperWidth.charWidth;

  @override
  Future<PrintSubmitOutcome> printSaleReceipt(SaleReceiptData data) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.sale,
        number: '${data.receiptNo}',
        // Дубликат — **другая копия того же чека**, а не повтор оригинала:
        // иначе «печать дубликата» из истории вернула бы `duplicate` и не
        // выдала бы бумаги вовсе.
        copyIndex: data.isDuplicate ? 1 : 0,
        posIdHint: data.posId,
      );
      final options = await _resolveOptions();
      return await _submit(_buildSaleReceipt(data, options), documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.sale, e);
    }
  }

  @override
  Future<PrintSubmitOutcome> printSampleReceipt(SaleReceiptData data) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.sample,
        // Момент запроса, а не `receiptNo`: у образца он фиксированный (1024),
        // то есть по идентификатору образец столкнулся бы с настоящим чеком
        // №1024 той же кассы и той же смены, и один из двух не напечатался бы.
        number: '${data.dateTime.millisecondsSinceEpoch}',
        copyIndex: 0,
        posIdHint: data.posId,
      );
      final options = await _resolveOptions();
      return await _submit(_buildSaleReceipt(data, options), documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.sample, e);
    }
  }

  @override
  Future<PrintSubmitOutcome> printRefundReceipt(RefundReceiptData data) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.refund,
        number: '${data.refundId}',
        copyIndex: data.isDuplicate ? 1 : 0,
        posIdHint: data.posId,
      );
      final options = await _resolveOptions();
      return await _submit(_buildRefundReceipt(data, options), documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.refund, e);
    }
  }

  @override
  Future<PrintSubmitOutcome> printSaleDuplicate(SaleReceiptData data) async {
    final duplicateData = SaleReceiptData(
      receiptNo: data.receiptNo,
      posId: data.posId,
      posName: data.posName,
      storeName: data.storeName,
      dateTime: data.dateTime,
      cashierName: data.cashierName,
      products: data.products,
      payments: data.payments,
      totalAmount: data.totalAmount,
      change: data.change,
      customerName: data.customerName,
      customerPhone: data.customerPhone,
      fiscalNumber: data.fiscalNumber,
      isDuplicate: true,
      tableName: data.tableName,
      zoneName: data.zoneName,
      guestCount: data.guestCount,
      waiterName: data.waiterName,
      serviceChargeAmount: data.serviceChargeAmount,
    );
    return printSaleReceipt(duplicateData);
  }

  @override
  Future<PrintSubmitOutcome> printRefundDuplicate(
    RefundReceiptData data,
  ) async {
    final duplicateData = RefundReceiptData(
      refundId: data.refundId,
      originalReceiptNo: data.originalReceiptNo,
      posId: data.posId,
      posName: data.posName,
      storeName: data.storeName,
      dateTime: data.dateTime,
      cashierName: data.cashierName,
      products: data.products,
      payments: data.payments,
      totalAmount: data.totalAmount,
      customerName: data.customerName,
      fiscalNumber: data.fiscalNumber,
      isDuplicate: true,
    );
    return printRefundReceipt(duplicateData);
  }

  @override
  Future<PrintSubmitOutcome> printXReport({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime dateTime,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashInDrawer,
  }) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.xReport,
        // X-отчёт — снимок смены на момент [dateTime]. Номера у него нет, и
        // два снимка, снятые в разные моменты, — разные документы: повторный
        // X-отчёт обязан напечататься, а не сойтись с предыдущим.
        number: '${dateTime.millisecondsSinceEpoch}',
        copyIndex: 0,
      );
      final receipt = _buildXReport(
        storeName: storeName,
        posName: posName,
        cashierName: cashierName,
        dateTime: dateTime,
        saleCount: saleCount,
        saleTotal: saleTotal,
        refundCount: refundCount,
        refundTotal: refundTotal,
        cashInDrawer: cashInDrawer,
      );
      return await _submit(receipt, documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.xReport, e);
    }
  }

  ReceiptBuilder _buildXReport({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime dateTime,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashInDrawer,
  }) {
    final receipt = ReceiptBuilder(charWidth: charWidth)..init();
    if (storeName.isNotEmpty) receipt.addCentered(storeName, bold: true);
    if (posName.isNotEmpty) receipt.addCentered(posName);
    receipt
      ..addEmptyLine()
      ..addCentered('X-ОТЧЁТ', bold: true, doubleSize: true)
      ..addCentered('ПРОМЕЖУТОЧНЫЙ (без гашения)')
      ..addEmptyLine()
      ..addRow('Дата:', _formatDateTime(dateTime))
      ..addRow('Кассир:', cashierName)
      ..addLine()
      ..addLeft('ПРОДАЖИ')
      ..addRow('Количество:', '$saleCount')
      ..addRow('Сумма:', _formatDecimal(saleTotal))
      ..addLine()
      ..addLeft('ВОЗВРАТЫ')
      ..addRow('Количество:', '$refundCount')
      ..addRow('Сумма:', _formatDecimal(refundTotal))
      ..addDoubleLine()
      ..addRow('ИТОГО В КАССЕ:', _formatDecimal(cashInDrawer), bold: true)
      ..addNewLines(3)
      ..cut();
    return receipt;
  }

  @override
  Future<PrintSubmitOutcome> printZReport({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashStart,
    required Decimal cashEnd,
    required Decimal cashIncome,
    required Decimal cashExpense,
  }) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.zReport,
        // Момент открытия смены, взятый из строки смены, — он долговечен и
        // один на смену. Z-отчёт по определению один на смену, поэтому повтор
        // с тем же номером — это и есть повтор того же документа.
        number: '${shiftStart.millisecondsSinceEpoch}',
        copyIndex: 0,
      );
      final receipt = _buildZReport(
        storeName: storeName,
        posName: posName,
        cashierName: cashierName,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        saleCount: saleCount,
        saleTotal: saleTotal,
        refundCount: refundCount,
        refundTotal: refundTotal,
        cashStart: cashStart,
        cashEnd: cashEnd,
        cashIncome: cashIncome,
        cashExpense: cashExpense,
      );
      return await _submit(receipt, documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.zReport, e);
    }
  }

  ReceiptBuilder _buildZReport({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashStart,
    required Decimal cashEnd,
    required Decimal cashIncome,
    required Decimal cashExpense,
  }) {
    final receipt = ReceiptBuilder(charWidth: charWidth)..init();
    if (storeName.isNotEmpty) receipt.addCentered(storeName, bold: true);
    if (posName.isNotEmpty) receipt.addCentered(posName);
    receipt
      ..addEmptyLine()
      ..addCentered('Z-ОТЧЁТ', bold: true, doubleSize: true)
      ..addCentered('ЗАКРЫТИЕ СМЕНЫ')
      ..addEmptyLine()
      ..addRow('Кассир:', cashierName)
      ..addRow('Начало:', _formatDateTime(shiftStart))
      ..addRow('Окончание:', _formatDateTime(shiftEnd))
      ..addDoubleLine()
      ..addLeft('ПРОДАЖИ')
      ..addRow('Количество:', '$saleCount')
      ..addRow('Сумма:', _formatDecimal(saleTotal))
      ..addLine()
      ..addLeft('ВОЗВРАТЫ')
      ..addRow('Количество:', '$refundCount')
      ..addRow('Сумма:', _formatDecimal(refundTotal))
      ..addLine()
      ..addLeft('ДЕНЕЖНЫЕ ОПЕРАЦИИ')
      ..addRow('На начало:', _formatDecimal(cashStart))
      ..addRow('Внесения:', _formatDecimal(cashIncome))
      ..addRow('Изъятия:', _formatDecimal(cashExpense))
      ..addDoubleLine()
      ..addRow('ИТОГО В КАССЕ:', _formatDecimal(cashEnd), bold: true)
      ..addNewLines(3)
      ..cut();
    return receipt;
  }

  /// Открывает ящик **мимо очереди** — обоснование на
  /// `ReceiptPrintService.openCashDrawer`.
  ///
  /// Коротко: очередь заставила бы импульс ящика ждать за застрявшим чеком, а
  /// это отказ принтера, не дающий выдать сдачу, — прямое нарушение И30.
  @override
  Future<bool> openCashDrawer() async {
    try {
      final bytes = (ReceiptBuilder(
        charWidth: charWidth,
      )..openDrawer()).build();
      final result = await _writeDirect(bytes);
      if (!result.success) {
        _logger?.warning(
          '[ReceiptPrintService] Не удалось открыть ящик: '
          '${result.errorMessage}',
        );
      }
      return result.success;
    } catch (e) {
      _logger?.warning('[ReceiptPrintService] Ошибка денежного ящика: $e');
      return false;
    }
  }

  @override
  Future<bool> isPrinterAvailable() async {
    try {
      if (!GetIt.I.isRegistered<PrinterManager>()) {
        _logger?.debug('[ReceiptPrintService] PrinterManager not registered');
        return false;
      }

      final printerManager = GetIt.I<PrinterManager>();

      if (!printerManager.isConnected) {
        final result = await printerManager.connect();
        if (!result.success) {
          _logger?.debug(
            '[ReceiptPrintService] Printer connection failed: ${result.errorMessage}',
          );
          return false;
        }
      }

      final status = await printerManager.getStatus();

      if (!status.isReady) {
        _logger?.debug(
          '[ReceiptPrintService] Printer not ready: '
          'online=${status.isOnline}, paper=${status.isPaperPresent}, '
          'cover=${status.isCoverClosed}',
        );
        return false;
      }

      return true;
    } catch (e) {
      _logger?.warning('[ReceiptPrintService] Printer check failed: $e');
      return false;
    }
  }

  ReceiptBuilder _buildSaleReceipt(
    SaleReceiptData data,
    ReceiptOptions options,
  ) {
    final width = _charWidthFor(options);
    final receipt = ReceiptBuilder(charWidth: width)..init();
    final cur = data.currencySymbol;

    if (data.isDuplicate) {
      receipt
        ..addCentered('*** ДУБЛИКАТ ***', bold: true)
        ..addEmptyLine();
    }

    if (options.headerText != null && options.headerText!.trim().isNotEmpty) {
      receipt.addCentered(options.headerText!.trim());
    }
    _addSellerHeader(
      receipt,
      storeName: data.storeName,
      seller: data.seller,
      isVatPayer: data.isVatPayer,
      options: options,
    );

    receipt.addLine();

    receipt.addRow('Касса', _cashboxId(data.fiscal, data.posName));
    receipt.addRow('Чек №', '${data.receiptNo}');
    if (options.showCashier) {
      receipt.addRow('Кассир:', data.cashierName);
    }
    if (data.tableName != null) {
      final tableInfo = data.zoneName != null
          ? '${data.tableName} (${data.zoneName})'
          : data.tableName!;
      receipt.addRow('Стол:', tableInfo);
    }
    if (data.waiterName != null) {
      receipt.addRow('Официант:', data.waiterName!);
    }
    if (data.guestCount != null) {
      receipt.addRow('Гостей:', '${data.guestCount}');
    }
    if (data.customerName != null) {
      receipt.addRow('Клиент:', data.customerName!);
    }
    receipt
      ..addCentered(_formatDateTime(data.dateTime))
      ..addCentered('ПРОДАЖА', bold: true);

    receipt.addLine();

    _addItemLines(receipt, data.products, options);

    receipt.addLine();

    if (data.totalDiscount > Decimal.zero) {
      receipt
        ..addRow('Подытог:', _formatDecimal(data.subtotal))
        ..addRow('Скидка:', '-${_formatDecimal(data.totalDiscount)}');
    }
    if (data.serviceChargeAmount != null &&
        data.serviceChargeAmount! > Decimal.zero) {
      receipt.addRow(
        'Сервисный сбор:',
        _formatDecimal(data.serviceChargeAmount!),
      );
    }
    receipt.addRow(
      'ИТОГО:',
      '=${_formatDecimal(data.totalAmount)}',
      bold: true,
    );

    for (final payment in data.payments) {
      receipt.addRow(
        _paymentLabel(payment),
        '=${_formatDecimal(payment.amount)}',
      );
    }
    if (data.change != null && data.change! > Decimal.zero) {
      receipt.addRow('Сдача:', '${_formatDecimal(data.change!)} $cur');
    }
    _addVatLines(
      receipt,
      data.isVatPayer,
      data.vatRatePercent,
      data.vatAmount,
      data.totalAmount,
      options,
    );

    _addFiscalBlock(
      receipt,
      fiscal: data.fiscal,
      fallbackFiscalNumber: data.fiscalNumber,
      isFiscal: data.isFiscal,
      customerBin: null,
      options: options,
    );

    _addFooter(receipt, options);

    return receipt;
  }

  ReceiptBuilder _buildRefundReceipt(
    RefundReceiptData data,
    ReceiptOptions options,
  ) {
    final width = _charWidthFor(options);
    final receipt = ReceiptBuilder(charWidth: width)..init();

    if (data.isDuplicate) {
      receipt
        ..addCentered('*** ДУБЛИКАТ ***', bold: true)
        ..addEmptyLine();
    }

    if (options.headerText != null && options.headerText!.trim().isNotEmpty) {
      receipt.addCentered(options.headerText!.trim());
    }
    _addSellerHeader(
      receipt,
      storeName: data.storeName,
      seller: data.seller,
      isVatPayer: data.isVatPayer,
      options: options,
    );

    receipt.addLine();

    receipt.addRow('Касса', _cashboxId(data.fiscal, data.posName));
    receipt.addRow('Возврат №', '${data.refundId}');
    if (data.originalReceiptNo != null) {
      receipt.addRow('Чек продажи №', '${data.originalReceiptNo}');
    }
    if (options.showCashier) {
      receipt.addRow('Кассир:', data.cashierName);
    }
    if (data.customerName != null) {
      receipt.addRow('Клиент:', data.customerName!);
    }
    receipt
      ..addCentered(_formatDateTime(data.dateTime))
      ..addCentered('ВОЗВРАТ', bold: true);

    receipt.addLine();

    _addItemLines(receipt, data.products, options);

    receipt.addLine();

    receipt.addRow(
      'ИТОГО:',
      '=${_formatDecimal(data.totalAmount)}',
      bold: true,
    );
    for (final payment in data.payments) {
      receipt.addRow(
        _paymentLabel(payment),
        '=${_formatDecimal(payment.amount)}',
      );
    }
    _addVatLines(
      receipt,
      data.isVatPayer,
      data.vatRatePercent,
      data.vatAmount,
      data.totalAmount,
      options,
    );

    _addFiscalBlock(
      receipt,
      fiscal: data.fiscal,
      fallbackFiscalNumber: data.fiscalNumber,
      isFiscal: data.isFiscal,
      customerBin: null,
      options: options,
    );

    _addFooter(receipt, options);

    return receipt;
  }

  String _cashboxId(ReceiptFiscalInfo? fiscal, String posName) {
    if (fiscal?.znm?.isNotEmpty ?? false) return fiscal!.znm!;
    return posName;
  }

  String _paymentLabel(ReceiptPaymentLine payment) {
    if (payment.isCash) return 'НАЛИЧНЫМИ';
    final name = payment.name.trim();
    return name.isEmpty ? 'КАРТА' : name.toUpperCase();
  }

  void _addItemLines(
    ReceiptBuilder receipt,
    List<ReceiptProductLine> products,
    ReceiptOptions options,
  ) {
    var index = 0;
    for (final product in products) {
      index++;
      final namePrefix = options.showItemNumbers ? '$index. ' : '';
      receipt.addLeft('$namePrefix${product.name}');
      final qtyPrice =
          '${_formatDecimal(product.quantity)} шт x ${_formatDecimal(product.price)}';
      receipt.addRow(qtyPrice, '=${_formatDecimal(product.total)}');
      if (product.hasDiscount) {
        receipt.addRow(
          '  Скидка:',
          '-${_formatDecimal(product.discountAmount)}',
        );
      }
    }
  }

  void _addVatLines(
    ReceiptBuilder receipt,
    bool isVatPayer,
    int vatRatePercent,
    Decimal? vatAmount,
    Decimal total,
    ReceiptOptions options,
  ) {
    if (!options.showVat || !isVatPayer) return;
    final vat = vatAmount ?? VatCalculator.extractVatFromGross(total);
    receipt
      ..addRow('ПО НАЛОГУ А:', '$vatRatePercent%')
      ..addRow('НДС-$vatRatePercent%:', '=${_formatDecimal(vat)}');
  }

  void _addSellerHeader(
    ReceiptBuilder receipt, {
    required String storeName,
    required ReceiptSellerInfo? seller,
    required bool isVatPayer,
    required ReceiptOptions options,
  }) {
    if (storeName.isNotEmpty) {
      receipt.addCentered(storeName, bold: true);
    }
    if (options.showBin && (seller?.binIin?.isNotEmpty ?? false)) {
      receipt.addCentered('БИН/ИИН: ${seller!.binIin}');
    }
    if (options.showAddress && (seller?.address?.isNotEmpty ?? false)) {
      receipt.addCentered(seller!.address!);
    }
  }

  void _addFiscalBlock(
    ReceiptBuilder receipt, {
    required ReceiptFiscalInfo? fiscal,
    required String? fallbackFiscalNumber,
    required bool isFiscal,
    required String? customerBin,
    required ReceiptOptions options,
  }) {
    if (!isFiscal || fiscal == null) {
      receipt
        ..addLine()
        ..addCentered('НЕФИСКАЛЬНЫЙ ЧЕК', bold: true);
      return;
    }

    receipt.addLine(char: '*');
    if (fiscal.ofdName?.isNotEmpty ?? false) {
      receipt.addCentered('ОФД ${fiscal.ofdName}');
    }
    if (fiscal.fiscalSign?.isNotEmpty ?? false) {
      receipt.addRow('ФИСК. ПРИЗНАК:', fiscal.fiscalSign!);
    }
    final fn = fiscal.fiscalNumber ?? fallbackFiscalNumber;
    if (fn != null && fn.isNotEmpty) {
      receipt.addRow('ФН:', fn);
    }
    if (fiscal.rnm?.isNotEmpty ?? false) {
      receipt.addRow('РНМ:', fiscal.rnm!);
    }
    if (fiscal.znm?.isNotEmpty ?? false) {
      receipt.addRow('ЗНМ:', fiscal.znm!);
    }
    receipt.addRow('ВРЕМЯ:', _formatDateTime(DateTime.now()));
    if (customerBin != null && customerBin.isNotEmpty) {
      receipt.addRow('ИИН покупателя:', customerBin);
    }
    if (fiscal.isOffline) {
      receipt.addCentered('*** ОФФЛАЙН ***', bold: true);
    }
    final ticketUrl = fiscal.ticketUrl;
    if (ticketUrl != null && ticketUrl.isNotEmpty) {
      receipt
        ..addEmptyLine()
        ..addCentered('Для проверки чека зайдите на')
        ..addCentered(ticketUrl);
    }

    receipt.addCentered('ФИСКАЛЬНЫЙ ЧЕК', bold: true);

    if (options.showQr && ticketUrl != null && ticketUrl.isNotEmpty) {
      receipt
        ..addEmptyLine()
        ..qr(ticketUrl);
    }
  }

  void _addFooter(ReceiptBuilder receipt, ReceiptOptions options) {
    receipt.addEmptyLine();
    if (options.footerText.trim().isNotEmpty) {
      receipt.addCentered(options.footerText.trim());
    }
    for (final line in options.extraFooterLines) {
      if (line.trim().isNotEmpty) receipt.addCentered(line.trim());
    }
    receipt
      ..addNewLines(3)
      ..cut();
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }

  @override
  Future<PrintSubmitOutcome> printPreCheck(PreCheckData data) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.preCheck,
        // Номера у пречека нет: гость просит счёт столько раз, сколько
        // захочет, и каждая просьба — свой документ. Стол в номере стоит
        // затем, чтобы два стола, попросивших счёт в одну и ту же
        // миллисекунду, не сложились в один.
        number:
            '${_sanitizeNumber(data.tableName)}'
            '@${data.dateTime.millisecondsSinceEpoch}',
        copyIndex: 0,
      );
      return await _submit(_buildPreCheck(data), documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.preCheck, e);
    }
  }

  @override
  Future<PrintSubmitOutcome> printServiceIntake(ServiceReceiptData data) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.serviceIntake,
        number: _sanitizeNumber(data.orderNumber),
        copyIndex: 0,
      );
      return await _submit(_buildServiceIntake(data), documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.serviceIntake, e);
    }
  }

  @override
  Future<PrintSubmitOutcome> printServiceCompletion(
    ServiceReceiptData data,
  ) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.serviceCompletion,
        number: _sanitizeNumber(data.orderNumber),
        copyIndex: 0,
      );
      return await _submit(_buildServiceCompletion(data), documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.serviceCompletion, e);
    }
  }

  ReceiptBuilder _buildPreCheck(PreCheckData data) {
    final receipt = ReceiptBuilder(charWidth: charWidth)..init();

    receipt
      ..addCentered(data.storeName, bold: true)
      ..addEmptyLine()
      ..addCentered('PRE-CHEK', bold: true, doubleSize: true)
      ..addEmptyLine();

    final tableInfo = data.zoneName != null
        ? '${data.tableName} (${data.zoneName})'
        : data.tableName;
    receipt
      ..addRow('Stol:', tableInfo)
      ..addRow('Oficiant:', data.waiterName)
      ..addRow('Gostej:', '${data.guestCount}')
      ..addRow('Data:', _formatDateTime(data.dateTime))
      ..addLine();

    for (final product in data.products) {
      receipt.addLeft(product.name);
      final qtyPrice =
          '${_formatDecimal(product.quantity)} x ${_formatDecimal(product.price)}';
      receipt.addRow(qtyPrice, _formatDecimal(product.total));
    }

    receipt.addLine();

    if (data.serviceChargeAmount != null &&
        data.serviceChargeAmount! > Decimal.zero) {
      receipt.addRow(
        'Servisnyj sbor:',
        _formatDecimal(data.serviceChargeAmount!),
      );
    }

    receipt
      ..addRow('ITOGO:', _formatDecimal(data.totalAmount), bold: true)
      ..addEmptyLine()
      ..addCentered('Eto ne fiskalnyj chek')
      ..addNewLines(3)
      ..cut();

    return receipt;
  }

  ReceiptBuilder _buildServiceIntake(ServiceReceiptData data) {
    final receipt = ReceiptBuilder(charWidth: charWidth)..init();

    receipt
      ..addCentered(data.storeName, bold: true)
      ..addCentered(data.posName)
      ..addEmptyLine()
      ..addCentered('PRIYOM V SERVIS', bold: true, doubleSize: true)
      ..addEmptyLine()
      ..addRow('Zakaz:', data.orderNumber)
      ..addRow('Data:', _formatDateTime(data.intakeDate))
      ..addRow('Kassir:', data.cashierName)
      ..addLine()
      ..addRow('Klient:', data.clientName);

    if (data.clientPhone != null) {
      receipt.addRow('Telefon:', data.clientPhone!);
    }

    receipt.addLine();

    if (data.deviceDescription != null) {
      receipt.addRow('Ustrojstvo:', data.deviceDescription!);
    }
    if (data.serialNumber != null) {
      receipt.addRow('S/N:', data.serialNumber!);
    }
    if (data.complaint != null) {
      receipt
        ..addLeft('Zhaloba:')
        ..addLeft(data.complaint!);
    }

    receipt.addLine();

    if (data.estimatedDate != null) {
      receipt.addRow('Srok:', _formatDateTime(data.estimatedDate!));
    }
    if (data.estimatedAmount != null) {
      receipt.addRow('Predv. stoimost:', _formatDecimal(data.estimatedAmount!));
    }
    if (data.prepaidAmount != null && data.prepaidAmount! > Decimal.zero) {
      receipt.addRow('Predoplata:', _formatDecimal(data.prepaidAmount!));
    }

    receipt
      ..addEmptyLine()
      ..addCentered('Podpis klienta: ____________')
      ..addNewLines(3)
      ..cut();

    return receipt;
  }

  ReceiptBuilder _buildServiceCompletion(ServiceReceiptData data) {
    final receipt = ReceiptBuilder(charWidth: charWidth)..init();

    receipt
      ..addCentered(data.storeName, bold: true)
      ..addCentered(data.posName)
      ..addEmptyLine()
      ..addCentered('AKT VYPOLNENNYKH RABOT', bold: true)
      ..addEmptyLine()
      ..addRow('Zakaz:', data.orderNumber)
      ..addRow('Data priema:', _formatDateTime(data.intakeDate))
      ..addRow('Kassir:', data.cashierName)
      ..addLine()
      ..addRow('Klient:', data.clientName);

    if (data.clientPhone != null) {
      receipt.addRow('Telefon:', data.clientPhone!);
    }

    if (data.deviceDescription != null) {
      receipt.addRow('Ustrojstvo:', data.deviceDescription!);
    }

    receipt
      ..addLine()
      ..addLeft('VYPOLNENNYE RABOTY:');

    for (final mark in data.marks) {
      if (mark.cost != null && mark.cost! > Decimal.zero) {
        receipt.addRow(mark.description, _formatDecimal(mark.cost!));
      } else {
        receipt.addLeft(mark.description);
      }
    }

    receipt.addDoubleLine();

    if (data.totalCost != null) {
      receipt.addRow('ITOGO:', _formatDecimal(data.totalCost!), bold: true);
    }
    if (data.prepaidAmount != null && data.prepaidAmount! > Decimal.zero) {
      receipt.addRow('Predoplata:', _formatDecimal(data.prepaidAmount!));
    }
    if (data.remainingAmount != null && data.remainingAmount! > Decimal.zero) {
      receipt.addRow(
        'K oplate:',
        _formatDecimal(data.remainingAmount!),
        bold: true,
      );
    }

    receipt
      ..addEmptyLine()
      ..addCentered('Podpis klienta: ____________')
      ..addNewLines(3)
      ..cut();

    return receipt;
  }

  String _formatDecimal(Decimal value) {
    return value.toStringAsFixed(2);
  }

  /// **Шов.** Выше этой строки — логика документа, ниже — транспорт.
  ///
  /// [receipt] здесь уже собран целиком: время проставлено, фискальные
  /// реквизиты внутри. Дальше остаётся отдать эти байты очереди — и **только
  /// очереди**; как именно, написано в [PrintSubmission.submit], и это тот же
  /// код, которым сдаёт квитанцию кассовая операция.
  Future<PrintSubmitOutcome> _submit(
    ReceiptBuilder receipt,
    PrintDocumentId documentId,
  ) => _submission.submit(receipt.build(), documentId);

  /// Личность документа, который сейчас печатается. См.
  /// [PrintSubmission.identify].
  Future<PrintDocumentId> _identify({
    required PrintDocumentKind kind,
    required String number,
    required int copyIndex,
    int? posIdHint,
  }) => _submission.identify(
    kind: kind,
    number: number,
    copyIndex: copyIndex,
    posIdHint: posIdHint,
  );

  PrintSubmitOutcome _cannotIdentify(PrintDocumentKind kind, Object error) =>
      _submission.cannotIdentify(kind, error);

  static String _sanitizeNumber(String raw) =>
      PrintSubmission.sanitizeNumber(raw);

  /// Прямая запись в принтер — **не для чеков**.
  ///
  /// Единственный вызывающий — [openCashDrawer]; обоснование того, почему
  /// импульс ящика не проходит через очередь, записано на
  /// `ReceiptPrintService.openCashDrawer`. Ни один чек, отчёт, пречек или
  /// квитанция сюда не попадают: их путь — [_submit], и другого у них нет.
  Future<PrintResult> _writeDirect(Uint8List bytes) async {
    if (!GetIt.I.isRegistered<PrinterManager>()) {
      return PrintResult.error('На этом терминале не настроен чековый принтер');
    }

    final printerManager = GetIt.I<PrinterManager>();
    if (!printerManager.isConnected) {
      final connectionResult = await printerManager.connect();
      if (!connectionResult.success) {
        _logger?.warning(
          '[ReceiptPrintService] Соединение не установилось, попытка записи '
          'всё равно будет сделана: ${connectionResult.errorMessage}',
        );
      }
    }
    return printerManager.printReceipt(bytes);
  }
}

class _PreviewTextRenderer {
  _PreviewTextRenderer(this.width);

  final int width;
  final StringBuffer _sb = StringBuffer();

  String renderSale(SaleReceiptData data, ReceiptOptions options) {
    _sb.clear();
    final cur = data.currencySymbol;

    if (data.isDuplicate) {
      _center('*** ДУБЛИКАТ ***');
      _empty();
    }

    if (options.headerText != null && options.headerText!.trim().isNotEmpty) {
      _center(options.headerText!.trim());
    }
    if (data.storeName.isNotEmpty) _center(data.storeName);
    if (options.showBin && (data.seller?.binIin?.isNotEmpty ?? false)) {
      _center('БИН/ИИН: ${data.seller!.binIin}');
    }
    if (options.showAddress && (data.seller?.address?.isNotEmpty ?? false)) {
      _center(data.seller!.address!);
    }

    _divider();

    _row(
      'Касса',
      (data.fiscal?.znm?.isNotEmpty ?? false)
          ? data.fiscal!.znm!
          : data.posName,
    );
    _row('Чек №', '${data.receiptNo}');
    if (options.showCashier) _row('Кассир:', data.cashierName);
    if (data.customerName != null) _row('Клиент:', data.customerName!);
    _center(_fmtDt(data.dateTime));
    _center('ПРОДАЖА');

    _divider();
    var index = 0;
    for (final p in data.products) {
      index++;
      final prefix = options.showItemNumbers ? '$index. ' : '';
      _left('$prefix${p.name}');
      _row('${_fmt(p.quantity)} шт x ${_fmt(p.price)}', '=${_fmt(p.total)}');
      if (p.hasDiscount) _row('  Скидка:', '-${_fmt(p.discountAmount)}');
    }
    _divider();

    if (data.totalDiscount > Decimal.zero) {
      _row('Подытог:', _fmt(data.subtotal));
      _row('Скидка:', '-${_fmt(data.totalDiscount)}');
    }
    if (data.serviceChargeAmount != null &&
        data.serviceChargeAmount! > Decimal.zero) {
      _row('Сервисный сбор:', _fmt(data.serviceChargeAmount!));
    }
    _row('ИТОГО:', '=${_fmt(data.totalAmount)}');
    for (final pay in data.payments) {
      _row(
        pay.isCash ? 'НАЛИЧНЫМИ' : pay.name.toUpperCase(),
        '=${_fmt(pay.amount)}',
      );
    }
    if (data.change != null && data.change! > Decimal.zero) {
      _row('Сдача:', '${_fmt(data.change!)} $cur');
    }
    if (options.showVat && data.isVatPayer) {
      final vat =
          data.vatAmount ?? VatCalculator.extractVatFromGross(data.totalAmount);
      _row('ПО НАЛОГУ А:', '${data.vatRatePercent}%');
      _row('НДС-${data.vatRatePercent}%:', '=${_fmt(vat)}');
    }

    final f = data.fiscal;
    if (data.isFiscal && f != null) {
      _sb.writeln('*' * width);
      if (f.ofdName?.isNotEmpty ?? false) _center('ОФД ${f.ofdName}');
      if (f.fiscalSign?.isNotEmpty ?? false)
        _row('ФИСК. ПРИЗНАК:', f.fiscalSign!);
      final fn = f.fiscalNumber ?? data.fiscalNumber;
      if (fn != null && fn.isNotEmpty) _row('ФН:', fn);
      if (f.rnm?.isNotEmpty ?? false) _row('РНМ:', f.rnm!);
      if (f.znm?.isNotEmpty ?? false) _row('ЗНМ:', f.znm!);
      _row('ВРЕМЯ:', _fmtDt(DateTime.now()));
      if (f.isOffline) _center('*** ОФФЛАЙН ***');
      if (f.ticketUrl?.isNotEmpty ?? false) {
        _empty();
        _center('Для проверки чека зайдите на');
        _wrap(f.ticketUrl!);
      }
      _center('ФИСКАЛЬНЫЙ ЧЕК');
      if (options.showQr && (f.ticketUrl?.isNotEmpty ?? false)) {
        _empty();
        _center('[ QR ]');
      }
    } else {
      _divider();
      _center('НЕФИСКАЛЬНЫЙ ЧЕК');
    }

    _empty();
    if (options.footerText.trim().isNotEmpty)
      _center(options.footerText.trim());
    for (final line in options.extraFooterLines) {
      if (line.trim().isNotEmpty) _center(line.trim());
    }

    return _sb.toString();
  }

  void _center(String text) {
    final t = text.length > width ? text.substring(0, width) : text;
    final pad = (width - t.length) ~/ 2;
    _sb.writeln(' ' * pad + t);
  }

  void _left(String text) {
    _sb.writeln(text.length > width ? text.substring(0, width) : text);
  }

  void _wrap(String text) {
    var rest = text;
    while (rest.length > width) {
      _sb.writeln(rest.substring(0, width));
      rest = rest.substring(width);
    }
    if (rest.isNotEmpty) _sb.writeln(rest);
  }

  void _row(String left, String right) {
    final maxLeft = width - right.length - 1;
    final l = left.length > maxLeft && maxLeft > 0
        ? left.substring(0, maxLeft)
        : left;
    final pad = width - l.length - right.length;
    _sb.writeln(l + ' ' * (pad > 0 ? pad : 1) + right);
  }

  void _divider() => _sb.writeln('-' * width);

  void _empty() => _sb.writeln();

  String _fmt(Decimal v) => v.toStringAsFixed(2);

  String _fmtDt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }
}
