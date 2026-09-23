import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/data/services/receipt_strings.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/bound_receipt_paper_width.dart';
import 'package:telepos/data/print/print_submission.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_document_id.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/print/receipt_paper_width_source.dart';
import 'package:telepos/domain/sale/payment_service.dart' show FiscalState;
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/hardware/printer/escpos_text_preview.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/receipt_builder.dart';
import 'package:telepos/domain/tax/tax_amounts.dart';
import 'package:telepos/core/locale/till_conventions.dart';

/// Строка подвала под «НЕФИСКАЛЬНЫЙ ЧЕК», называющая **причину**.
///
/// До задачи 5 подвал говорил «НЕФИСКАЛЬНЫЙ ЧЕК» и умолкал — одна строка
/// на три разные причины, ровно тот же дефект, что жил в `FiscalState`,
/// только на бумаге. Покупатель и кассир не могли отличить «так
/// настроено» от «касса собрана без узла фискализации».
///
/// `null` — строки нет, и это не забывчивость:
///
/// * `null`-состояние — **«не спрашивали»** (дубликат из истории, чек,
///   собранный не оплатой). Печатать по незнанию утверждение о причине
///   значило бы соврать уверенно;
/// * [FiscalState.notRequired] — документ не положен **этому чеку** по
///   настройке кассы; «НЕФИСКАЛЬНЫЙ ЧЕК» уже сказал всё, и вторая строка
///   про политику покупателю ничего не добавит;
/// * [FiscalState.done] и [FiscalState.queued] сюда не доходят — у таких
///   чеков есть фискальный блок;
/// * [FiscalState.failed] и [FiscalState.unchanged] названы отдельно:
///   первое — беда (деньги взяты, документа нет), и молчать о ней на
///   бумаге нельзя.
///
/// Слова берутся из словаря печати ([ReceiptStringsResolver]) — как и
/// весь остальной подвал (`НЕФИСКАЛЬНЫЙ ЧЕК`, `ФИСК. ПРИЗНАК`,
/// `ОФФЛАЙН`). Довод необязателен: у фоновых вызовов резолвера нет, и
/// тогда берётся язык, выбранный в кассе.
String? noFiscalDocumentReason(
  FiscalState? state, {
  ReceiptStringsResolver? strings,
}) {
  final l10n = (strings ?? defaultReceiptStrings)();
  return switch (state) {
    null => null,
    FiscalState.notRequired => null,
    FiscalState.done => null,
    FiscalState.queued => null,
    FiscalState.operatorAbsent => l10n.rcpFiscalOperatorNotSet,
    FiscalState.fiscalModuleAbsent => l10n.rcpFiscalModuleUnavailable,
    FiscalState.failed => l10n.rcpDocumentNotIssued,
    FiscalState.unchanged => null,
  };
}

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
///
/// ## Ширина ленты
///
/// Каждый документ собирается в ширину, которую при **этой** печати отдаёт
/// [ReceiptPaperWidthSource] — привязка чекового принтера. Ни шаблон, ни
/// конструктор, ни литерал ширину не несут: до правки их было четыре, и
/// выбранная на экране принтера ширина не доходила ни до одного документа.
///
/// ## Шаблон чека
///
/// Шапка шаблона — первое, что выходит из принтера, подвал — последнее перед
/// протяжкой и резом. Между ними обязательная часть, которую шаблон не
/// выключает (см. [ReceiptOptions]). Предпросмотр на экране шаблона —
/// [renderSalePreviewText] — это **те же байты**, разобранные в текст, а не
/// вторая раскладка.
class ReceiptPrintServiceImpl implements ReceiptPrintService {
  ReceiptPrintServiceImpl({
    ReceiptPaperWidthSource? paperWidth,
    Talker? logger,
    ReceiptStringsResolver? strings,
  }) : _paperWidth = paperWidth ?? BoundReceiptPaperWidth(logger: logger),
       _logger = logger,
       _strings = strings ?? defaultReceiptStrings,
       _submission = PrintSubmission(logger: logger);

  /// Слова печатных документов на языке кассы.
  ///
  /// Доводом, а не обращением к глобальному состоянию: пробе нужно
  /// подменить язык, не влияя на соседние прогоны. Умолчание берёт язык,
  /// выбранный в кассе (`ReceiptLanguage`).
  final ReceiptStringsResolver _strings;

  /// Срок задания — общий для всех документов, обоснование на
  /// [PrintSubmission.documentLifetime].
  static const Duration documentLifetime = PrintSubmission.documentLifetime;

  final ReceiptPaperWidthSource _paperWidth;

  final Talker? _logger;

  /// Единственная дорога байтов в очередь — та же самая, которой пользуется
  /// служба квитанций кассовых операций.
  final PrintSubmission _submission;

  ReceiptOptions? _optionsCache;

  /// Шаблон чека кассы — выбранный в «Шаблонах чеков». Кэш сбрасывают экраны
  /// шаблонов ([invalidateReceiptOptionsCache]) при сохранении и выборе.
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
  Future<ReceiptPaperWidth> currentPaperWidth() => _paperWidth.current();

  /// Число колонок для документа, собираемого **сейчас**.
  Future<int> _columns() async => (await _paperWidth.current()).charWidth;

  @override
  String renderSalePreviewText(
    SaleReceiptData data,
    ReceiptOptions options, {
    required ReceiptPaperWidth paperWidth,
  }) {
    return renderEscPosAsText(
      _buildSaleReceipt(data, options, paperWidth.charWidth).build(),
      width: paperWidth.charWidth,
    );
  }

  @override
  String renderZReportPreview({
    required ReceiptPaperWidth paperWidth,
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
    required Decimal cashDiscrepancy,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  }) {
    return renderEscPosAsText(
      _buildZReport(
        width: paperWidth.charWidth,
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
        cashDiscrepancy: cashDiscrepancy,
        certificatesIssued: certificatesIssued,
        certificatesRedeemed: certificatesRedeemed,
      ).build(),
      width: paperWidth.charWidth,
    );
  }

  @override
  String renderXReportPreview({
    required ReceiptPaperWidth paperWidth,
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime dateTime,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashInDrawer,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  }) {
    return renderEscPosAsText(
      _buildXReport(
        width: paperWidth.charWidth,
        storeName: storeName,
        posName: posName,
        cashierName: cashierName,
        dateTime: dateTime,
        saleCount: saleCount,
        saleTotal: saleTotal,
        refundCount: refundCount,
        refundTotal: refundTotal,
        cashInDrawer: cashInDrawer,
        certificatesIssued: certificatesIssued,
        certificatesRedeemed: certificatesRedeemed,
      ).build(),
      width: paperWidth.charWidth,
    );
  }

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
      return await _submit(
        _buildSaleReceipt(data, options, await _columns()),
        documentId,
      );
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
      return await _submit(
        _buildSaleReceipt(data, options, await _columns()),
        documentId,
      );
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
      return await _submit(
        _buildRefundReceipt(data, options, await _columns()),
        documentId,
      );
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
      // Дубликат — КОПИЯ чека, а не другой документ. До 2026-09-21 эти поля
      // не переносились вовсе, и дубликат печатался с умолчаниями: без
      // продавца, без фискального блока и без единой строки налога
      // (`isVatPayer` по умолчанию `false`). Покупатель, которому выдали
      // дубликат вместо утерянного чека, получал бумагу, не совпадающую с
      // оригиналом ни по реквизитам, ни по налогу.
      seller: data.seller,
      fiscal: data.fiscal,
      isVatPayer: data.isVatPayer,
      vatAmount: data.vatAmount,
      vatRatePercent: data.vatRatePercent,
      taxTreatment: data.taxTreatment,
      hasFiscalisation: data.hasFiscalisation,
      currencySymbol: data.currencySymbol,
      fiscalState: data.fiscalState,
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
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
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
        width: await _columns(),
        storeName: storeName,
        posName: posName,
        cashierName: cashierName,
        dateTime: dateTime,
        saleCount: saleCount,
        saleTotal: saleTotal,
        refundCount: refundCount,
        refundTotal: refundTotal,
        cashInDrawer: cashInDrawer,
        certificatesIssued: certificatesIssued,
        certificatesRedeemed: certificatesRedeemed,
      );
      return await _submit(receipt, documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.xReport, e);
    }
  }

  ReceiptBuilder _buildXReport({
    required int width,
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime dateTime,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashInDrawer,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  }) {
    final l10n = _strings();
    final receipt = ReceiptBuilder(charWidth: width)..init();
    if (storeName.isNotEmpty) receipt.addCentered(storeName, bold: true);
    if (posName.isNotEmpty) receipt.addCentered(posName);
    receipt
      ..addEmptyLine()
      ..addCentered(l10n.rcpXReport, bold: true, doubleSize: true)
      ..addCentered(l10n.rcpInterim)
      ..addEmptyLine()
      ..addRow(l10n.rcpDate, _formatDateTime(dateTime))
      ..addRow(l10n.rcpCashier, cashierName)
      ..addLine()
      ..addLeft(l10n.rcpSales)
      ..addRow(l10n.rcpCount, '$saleCount')
      ..addRow(l10n.rcpAmount, _formatDecimal(saleTotal))
      ..addLine()
      ..addLeft(l10n.rcpRefunds)
      ..addRow(l10n.rcpCount, '$refundCount')
      ..addRow(l10n.rcpAmount, _formatDecimal(refundTotal));
    _addCertificateBlock(receipt, certificatesIssued, certificatesRedeemed);
    receipt
      ..addDoubleLine()
      ..addRow(l10n.rcpTotalInDrawer, _formatDecimal(cashInDrawer), bold: true)
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
    required Decimal cashDiscrepancy,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
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
        width: await _columns(),
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
        cashDiscrepancy: cashDiscrepancy,
        certificatesIssued: certificatesIssued,
        certificatesRedeemed: certificatesRedeemed,
      );
      return await _submit(receipt, documentId);
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.zReport, e);
    }
  }

  ReceiptBuilder _buildZReport({
    required int width,
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
    required Decimal cashDiscrepancy,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  }) {
    final l10n = _strings();
    final receipt = ReceiptBuilder(charWidth: width)..init();
    if (storeName.isNotEmpty) receipt.addCentered(storeName, bold: true);
    if (posName.isNotEmpty) receipt.addCentered(posName);
    receipt
      ..addEmptyLine()
      ..addCentered(l10n.rcpZReport, bold: true, doubleSize: true)
      ..addCentered(l10n.rcpShiftClose)
      ..addEmptyLine()
      ..addRow(l10n.rcpCashier, cashierName)
      ..addRow(l10n.rcpShiftStart, _formatDateTime(shiftStart))
      ..addRow(l10n.rcpShiftEnd, _formatDateTime(shiftEnd))
      ..addDoubleLine()
      ..addLeft(l10n.rcpSales)
      ..addRow(l10n.rcpCount, '$saleCount')
      ..addRow(l10n.rcpAmount, _formatDecimal(saleTotal))
      ..addLine()
      ..addLeft(l10n.rcpRefunds)
      ..addRow(l10n.rcpCount, '$refundCount')
      ..addRow(l10n.rcpAmount, _formatDecimal(refundTotal));
    _addCertificateBlock(receipt, certificatesIssued, certificatesRedeemed);
    receipt
      ..addLine()
      ..addLeft(l10n.rcpCashOps)
      ..addRow(l10n.rcpOpeningFloat, _formatDecimal(cashStart))
      ..addRow(l10n.rcpCashIn, _formatDecimal(cashIncome))
      ..addRow(l10n.rcpCashOut, _formatDecimal(cashExpense));
    // Строка печатается только при ненулевом расхождении: у сошедшейся
    // смены её нет, и «Излишек 0.00» не притворяется находкой.
    if (cashDiscrepancy != Decimal.zero) {
      receipt.addRow(
        cashDiscrepancy > Decimal.zero ? l10n.shiftSurplus : l10n.shiftShortage,
        _formatDecimal(cashDiscrepancy),
      );
    }
    receipt
      ..addDoubleLine()
      ..addRow(l10n.rcpTotalInDrawer, _formatDecimal(cashEnd), bold: true)
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
      // Импульс ящика — не текст: колонки ему не нужны, и ширину ленты ради
      // него не читают.
      final bytes = (ReceiptBuilder(
        charWidth: ReceiptPaperWidth.mm58.charWidth,
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

  /// Шапка шаблона — **до всего**, в том числе до отметки «ДУБЛИКАТ»: она
  /// выше обязательной части по определению. Пустая шапка не даёт ни байта.
  void _addTemplateHeader(ReceiptBuilder receipt, ReceiptOptions options) {
    if (options.header.isEmpty) return;
    receipt
      ..addTextBlock(options.header)
      ..addEmptyLine();
  }

  ReceiptBuilder _buildSaleReceipt(
    SaleReceiptData data,
    ReceiptOptions options,
    int width,
  ) {
    final receipt = ReceiptBuilder(charWidth: width)..init();
    final cur = data.currencySymbol;
    final l10n = _strings();

    _addTemplateHeader(receipt, options);

    if (data.isDuplicate) {
      receipt
        ..addCentered(l10n.rcpDuplicate, bold: true)
        ..addEmptyLine();
    }

    _addSellerHeader(
      receipt,
      storeName: data.storeName,
      seller: data.seller,
      options: options,
    );

    receipt.addLine();

    receipt.addRow(l10n.rcpTill, _cashboxId(data.fiscal, data.posName));
    receipt.addRow(l10n.rcpReceiptNo, '${data.receiptNo}');
    if (options.showCashier) {
      receipt.addRow(l10n.rcpCashier, data.cashierName);
    }
    if (data.tableName != null) {
      final tableInfo = data.zoneName != null
          ? '${data.tableName} (${data.zoneName})'
          : data.tableName!;
      receipt.addRow(l10n.rcpTable, tableInfo);
    }
    if (data.waiterName != null) {
      receipt.addRow(l10n.rcpWaiter, data.waiterName!);
    }
    if (data.guestCount != null) {
      receipt.addRow(l10n.rcpGuests, '${data.guestCount}');
    }
    if (data.customerName != null) {
      receipt.addRow(l10n.rcpCustomer, data.customerName!);
    }
    receipt
      ..addCentered(_formatDateTime(data.dateTime))
      ..addCentered(l10n.rcpSale, bold: true);

    receipt.addLine();

    _addItemLines(receipt, data.products, options);

    receipt.addLine();

    if (data.totalDiscount > Decimal.zero) {
      receipt
        ..addRow(l10n.rcpSubtotal, _formatDecimal(data.subtotal))
        ..addRow(l10n.rcpDiscount, '-${_formatDecimal(data.totalDiscount)}');
    }
    if (data.serviceChargeAmount != null &&
        data.serviceChargeAmount! > Decimal.zero) {
      receipt.addRow(
        l10n.rcpServiceFee,
        _formatDecimal(data.serviceChargeAmount!),
      );
    }
    // Налог сверху (США): подытог → налог → итог. Это не украшение формы,
    // а единственный способ показать покупателю, за что он платит сверх
    // ценника: на ценнике налога не было. При налоге, включённом в цену,
    // подытог с налогом совпал бы с итогом, и строка была бы шумом.
    if (data.taxTreatment == TaxTreatment.exclusive) {
      final groups = data.taxByRate;
      final totalTax = groups.fold<Decimal>(
        Decimal.zero,
        (sum, g) => sum + g.tax,
      );
      if (totalTax > Decimal.zero || groups.length > 1) {
        receipt.addRow(
          l10n.rcpSubtotal,
          _formatDecimal(data.totalAmount - totalTax),
        );
        // По строке на ставку: в одной корзине их бывает несколько, и одна
        // общая строка не даёт покупателю понять, с чего именно взят налог.
        // Освобождённая группа тоже печатается — «ноль» здесь утверждение,
        // а не пустота.
        for (final group in groups) {
          receipt.addRow(
            '${l10n.rcpSalesTax} ${group.ratePercent}%:',
            _formatDecimal(group.tax),
          );

          // Разбивка — под СВОЕЙ ставкой и с отступом: это объяснение
          // именно её, а не отдельные начисления.
          //
          // Под своей, а не одна на чек. Одна на чек и стояла, и на дубле
          // урока 1.3 это дало неправду на бумаге: под «Sales tax 6.25%»
          // печатался состав из четырёх долей, включая CO State 2.90%, —
          // а штат еду для дома не облагал вовсе, и 6,25 % складываются
          // без него.
          //
          // Доли группы, а если их нет — общие для чека: у кассы с одной
          // ставкой состав один, и старые сборщики его так и передают.
          final shares = group.jurisdictions.isNotEmpty
              ? group.jurisdictions
              : (groups.length == 1 ? data.taxJurisdictions : const []);
          for (final j in shares) {
            // Два знака после запятой у КАЖДОЙ доли, даже если она круглая.
            // `Decimal.toString()` срезает нули, и разбивка выходила рваной:
            // «2.9 / 5.15 / 1 / 0.1». На налоговом документе доли ставки
            // принято печатать в одной точности — иначе «1%» читается как
            // неточность, а не как ровно один процент.
            receipt.addRow(
              '  ${j.name}',
              '${j.ratePercent.toStringAsFixed(2)}%',
            );
          }
        }

        // Освобождённое — отдельной строкой, а не растворённым в итоге.
        if (data.exemptTotal > Decimal.zero) {
          receipt.addRow(l10n.rcpTaxExempt, _formatDecimal(data.exemptTotal));
        }
      }
    }

    receipt.addRow(
      l10n.rcpTotal,
      data.currencyBeforeAmount
          ? '$cur${_formatDecimal(data.totalAmount)}'
          : '=${_formatDecimal(data.totalAmount)}',
      bold: true,
    );

    for (final payment in data.payments) {
      receipt.addRow(
        _paymentLabel(payment),
        data.currencyBeforeAmount
            ? '$cur${_formatDecimal(payment.amount)}'
            : '=${_formatDecimal(payment.amount)}',
      );
    }
    if (data.change != null && data.change! > Decimal.zero) {
      // Знак валюты с той же стороны, что и у итога. До этой правки итог
      // печатался «$7.79», а сдача «2.21 $» — две стороны в одном чеке, и
      // ни одна из них не была решением: сдача просто не спрашивала
      // настройку.
      receipt.addRow(
        l10n.rcpChange,
        data.currencyBeforeAmount
            ? '$cur${_formatDecimal(data.change!)}'
            : '${_formatDecimal(data.change!)} $cur',
      );
    }
    // Извлечение налога из брутто осмысленно только там, где он в цену
    // включён. При налоге сверху он уже показан отдельной строкой выше, и
    // второй раз выводить его значит показать покупателю налог дважды.
    if (data.taxTreatment == TaxTreatment.inclusive) {
      _addVatLines(
        receipt,
        data.isVatPayer,
        data.vatRatePercent,
        data.vatAmount,
        data.totalAmount,
      );
    }

    _addFiscalBlock(
      receipt,
      fiscal: data.fiscal,
      fallbackFiscalNumber: data.fiscalNumber,
      isFiscal: data.isFiscal,
      customerBin: null,
      fiscalState: data.fiscalState,
      hasFiscalisation: data.hasFiscalisation,
    );

    _addFooter(receipt, options);

    return receipt;
  }

  ReceiptBuilder _buildRefundReceipt(
    RefundReceiptData data,
    ReceiptOptions options,
    int width,
  ) {
    final receipt = ReceiptBuilder(charWidth: width)..init();
    final l10n = _strings();

    _addTemplateHeader(receipt, options);

    if (data.isDuplicate) {
      receipt
        ..addCentered(l10n.rcpDuplicate, bold: true)
        ..addEmptyLine();
    }

    _addSellerHeader(
      receipt,
      storeName: data.storeName,
      seller: data.seller,
      options: options,
    );

    receipt.addLine();

    receipt.addRow(l10n.rcpTill, _cashboxId(data.fiscal, data.posName));
    receipt.addRow(l10n.rcpRefundNo, '${data.refundId}');
    if (data.originalReceiptNo != null) {
      receipt.addRow(l10n.rcpSaleReceiptNo, '${data.originalReceiptNo}');
    }
    if (options.showCashier) {
      receipt.addRow(l10n.rcpCashier, data.cashierName);
    }
    if (data.customerName != null) {
      receipt.addRow(l10n.rcpCustomer, data.customerName!);
    }
    receipt
      ..addCentered(_formatDateTime(data.dateTime))
      ..addCentered(l10n.rcpRefund, bold: true);

    receipt.addLine();

    _addItemLines(receipt, data.products, options);

    receipt.addLine();

    receipt.addRow(
      l10n.rcpTotal,
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
    );

    _addFiscalBlock(
      receipt,
      fiscal: data.fiscal,
      fallbackFiscalNumber: data.fiscalNumber,
      isFiscal: data.isFiscal,
      customerBin: null,
    );

    _addFooter(receipt, options);

    return receipt;
  }

  @override
  Future<PrintSubmitOutcome> printCertificateSlip(
    CertificateSlipData data,
  ) async {
    try {
      final documentId = await _identify(
        kind: PrintDocumentKind.certificateSlip,
        // Номер бумажки, а не чека: слип принадлежит сертификату и живёт
        // столько же, сколько он. Разделитель из номера убирается — иначе
        // бумажка `C-1/2` и бумажка `C-1` в копии 2 дали бы одну строку
        // идентификатора (`PrintDocumentId.separator`).
        number: _sanitizeNumber(data.number),
        copyIndex: data.isDuplicate ? 1 : 0,
        posIdHint: data.posId,
      );
      final options = await _resolveOptions();
      return await _submit(
        _buildCertificateSlip(data, options, await _columns()),
        documentId,
      );
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.certificateSlip, e);
    }
  }

  @override
  String renderCertificateSlipPreviewText(
    CertificateSlipData data,
    ReceiptOptions options, {
    required ReceiptPaperWidth paperWidth,
  }) {
    return renderEscPosAsText(
      _buildCertificateSlip(data, options, paperWidth.charWidth).build(),
      width: paperWidth.charWidth,
    );
  }

  /// Слип подарочного сертификата.
  ///
  /// # Номер — отдельной строкой, а не парой «подпись-значение»
  ///
  /// [ReceiptBuilder.addRow] отдаёт значению столько колонок, сколько в нём
  /// символов, и вычитает их из подписи: номер длиной с ленту оставил бы
  /// подписи отрицательную ширину. Номер — то единственное, ради чего
  /// бумажку хранят, поэтому он стоит своей строкой и **переносится по
  /// словам**, а не обрезается по 32 колонкам узкой ленты.
  ///
  /// # ПИН на бумагу не выходит ни одной веткой
  ///
  /// Печатается факт «ПИН задан», а не сам ПИН, и самого ПИНа у документа
  /// нет даже полем. Номер и ПИН рядом на одной бумажке — это найденная
  /// бумажка, отоваренная кем угодно; довод тот же, по которому `pinHash`
  /// не едет на провод.
  ///
  /// # Пометка «не фискальный» обязательна
  ///
  /// Без неё слип с суммой и номером предъявляют как чек. Фискального
  /// документа у выпуска нет: деньги за сертификат приходят обычной строкой
  /// оплаты того чека, которым его продали.
  ReceiptBuilder _buildCertificateSlip(
    CertificateSlipData data,
    ReceiptOptions options,
    int width,
  ) {
    final receipt = ReceiptBuilder(charWidth: width)..init();
    final l10n = _strings();

    _addTemplateHeader(receipt, options);

    if (data.isDuplicate) {
      receipt
        ..addCentered(l10n.rcpDuplicate, bold: true)
        ..addEmptyLine();
    }

    _addSellerHeader(
      receipt,
      storeName: data.storeName,
      seller: data.seller,
      options: options,
    );

    receipt
      ..addLine()
      ..addCentered(l10n.rcpGiftCertificate, bold: true)
      ..addEmptyLine()
      ..addCentered(l10n.rcpCertNo)
      ..addCenteredWrapped(data.number, bold: true)
      ..addEmptyLine()
      ..addRow(
        l10n.rcpCertFaceValue,
        '=${_formatDecimal(data.amount)}',
        bold: true,
      );

    // Срок — **словом**, а не молчанием: пустая строка читается как «срок
    // забыли напечатать», и спорить об этом придётся у кассы.
    final expiresAt = data.expiresAt;
    receipt.addRow(
      l10n.rcpCertValidUntil,
      expiresAt == null ? l10n.rcpCertNoExpiry : _formatDate(expiresAt),
    );

    if (data.hasPin) receipt.addCentered(l10n.rcpCertPinSet);

    // Бумажка, рождённая возвратом, обязана объяснить себя: старая погашена
    // навсегда (решение 2, 2026-09-16), и без этих строк покупатель придёт
    // со старой.
    final refundLocalId = data.refundLocalId;
    if (refundLocalId != null) {
      receipt
        ..addLine()
        ..addRow(l10n.rcpCertIssuedByRefund, '$refundLocalId');
      final source = data.sourceNumber;
      if (source != null && source.isNotEmpty) {
        receipt
          ..addCentered(l10n.rcpCertInsteadOf)
          ..addCenteredWrapped(source);
      }
    }

    receipt.addLine();
    receipt.addRow(l10n.rcpTillColon, data.posName);
    if (options.showCashier) receipt.addRow(l10n.rcpCashier, data.cashierName);
    receipt
      ..addCentered(_formatDateTime(data.dateTime))
      ..addLine()
      ..addCentered(l10n.rcpNotFiscalDocument, bold: true);

    _addFooter(receipt, options);

    return receipt;
  }

  /// Дата без времени — для срока годности бумажки: час и минута в нём
  /// ничего не значат, а на 32 колонках стоят места.
  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}';
  }

  String _cashboxId(ReceiptFiscalInfo? fiscal, String posName) {
    if (fiscal?.znm?.isNotEmpty ?? false) return fiscal!.znm!;
    return posName;
  }

  String _paymentLabel(ReceiptPaymentLine payment) {
    final l10n = _strings();
    if (payment.isCash) return l10n.rcpCash;
    final name = payment.name.trim();
    return name.isEmpty ? l10n.rcpCard : name.toUpperCase();
  }

  void _addItemLines(
    ReceiptBuilder receipt,
    List<ReceiptProductLine> products,
    ReceiptOptions options,
  ) {
    final l10n = _strings();
    var index = 0;
    for (final product in products) {
      index++;
      final namePrefix = options.showItemNumbers ? '$index. ' : '';
      receipt.addLeft('$namePrefix${product.name}');
      final qtyPrice =
          '${_formatDecimal(product.quantity)} ${l10n.rcpQuantityShort} '
          'x ${_formatDecimal(product.price)}';
      // Освобождённая позиция помечается коротко и у самой суммы: без
      // пометки покупатель не поймёт, почему налог меньше, чем он прикинул
      // по итогу чека.
      final mark = product.isTaxExempt ? ' ${l10n.rcpTaxExemptMark}' : '';
      receipt.addRow(qtyPrice, '=${_formatDecimal(product.total)}$mark');
      if (product.hasDiscount) {
        // Скидка называет **происхождение**, когда оно записано (задача
        // 13): «подарок акции», а не безымянное число. Покупатель,
        // которому пообещали «две пачки — третья даром», иначе не может
        // проверить по чеку, что акцию ему применили вовсе.
        //
        // Чеки, проданные до v40, происхождения не несут — там остаётся
        // прежнее «Скидка:». Выдумывать им имя нельзя.
        final label = product.discountLabel;
        receipt.addRow(
          label == null ? '  ${l10n.rcpDiscount}' : '  $label:',
          '-${_formatDecimal(product.discountAmount)}',
        );
      }
    }
  }

  /// НДС плательщика — обязательный реквизит: шаблон его не выключает.
  void _addVatLines(
    ReceiptBuilder receipt,
    bool isVatPayer,
    Decimal vatRatePercent,
    Decimal? vatAmount,
    Decimal total,
  ) {
    if (!isVatPayer) return;
    // Запасной расчёт — по ставке ЭТОГО чека и общей формулой продукта.
    // Здесь стоял `VatCalculator.extractVatFromGross`, считавший по
    // зашитым 16 % (4/29) независимо от того, что напечатано строкой
    // выше: чек мог объявить ставку 12 % и показать налог по 16 %.
    final vat = vatAmount ?? taxFromGross(total, vatRatePercent);
    receipt
      ..addRow(_strings().rcpTaxA, '$vatRatePercent%')
      ..addRow(
        '${_strings().rcpVat}-$vatRatePercent%:',
        '=${_formatDecimal(vat)}',
      );
  }

  /// Продавец: название и БИН/ИИН — всегда, адрес — по шаблону. Длинные
  /// название и адрес переносятся, а не обрезаются.
  void _addSellerHeader(
    ReceiptBuilder receipt, {
    required String storeName,
    required ReceiptSellerInfo? seller,
    required ReceiptOptions options,
  }) {
    if (storeName.isNotEmpty) {
      receipt.addCenteredWrapped(storeName, bold: true);
    }
    if (seller?.binIin?.isNotEmpty ?? false) {
      receipt.addCentered('${_strings().rcpBinIin} ${seller!.binIin}');
    }
    if (options.showAddress && (seller?.address?.isNotEmpty ?? false)) {
      receipt.addCenteredWrapped(seller!.address!);
    }
  }

  /// Фискальный блок — целиком обязательный: ни одна его строка не зависит
  /// от шаблона. QR печатается всегда, когда оператор дал ссылку проверки.
  void _addFiscalBlock(
    ReceiptBuilder receipt, {
    required ReceiptFiscalInfo? fiscal,
    required String? fallbackFiscalNumber,
    required bool isFiscal,
    required String? customerBin,
    FiscalState? fiscalState,
    bool hasFiscalisation = true,
  }) {
    final l10n = _strings();
    // Где фискализации нет как понятия (США), отметки о ней не печатаем
    // вовсе. «NON-FISCAL RECEIPT» покупатель читает как «чек
    // недействителен», а не как справку о чужом законе.
    if (!hasFiscalisation) return;
    if (!isFiscal || fiscal == null) {
      receipt
        ..addLine()
        ..addCentered(l10n.rcpNonFiscalReceipt, bold: true);
      final why = noFiscalDocumentReason(fiscalState, strings: _strings);
      if (why != null) receipt.addCenteredWrapped(why);
      return;
    }

    receipt.addLine(char: '*');
    if (fiscal.ofdName?.isNotEmpty ?? false) {
      receipt.addCenteredWrapped('${l10n.rcpOfdName} ${fiscal.ofdName}');
    }
    if (fiscal.fiscalSign?.isNotEmpty ?? false) {
      receipt.addRow(l10n.rcpFiscalSign, fiscal.fiscalSign!);
    }
    final fn = fiscal.fiscalNumber ?? fallbackFiscalNumber;
    if (fn != null && fn.isNotEmpty) {
      receipt.addRow(l10n.rcpFiscalFn, fn);
    }
    if (fiscal.rnm?.isNotEmpty ?? false) {
      receipt.addRow(l10n.rcpFiscalRnm, fiscal.rnm!);
    }
    if (fiscal.znm?.isNotEmpty ?? false) {
      receipt.addRow(l10n.rcpFiscalZnm, fiscal.znm!);
    }
    receipt.addRow(l10n.rcpFiscalTime, _formatDateTime(DateTime.now()));
    if (customerBin != null && customerBin.isNotEmpty) {
      receipt.addRow(l10n.rcpCustomerTaxId, customerBin);
    }
    if (fiscal.isOffline) {
      receipt.addCentered(l10n.rcpOffline, bold: true);
    }
    final ticketUrl = fiscal.ticketUrl;
    if (ticketUrl != null && ticketUrl.isNotEmpty) {
      receipt
        ..addEmptyLine()
        ..addCenteredWrapped(l10n.rcpVerifyAt)
        ..addCenteredWrapped(ticketUrl);
    }

    receipt.addCentered(l10n.rcpFiscalReceipt, bold: true);

    if (ticketUrl != null && ticketUrl.isNotEmpty) {
      receipt
        ..addEmptyLine()
        ..qr(ticketUrl);
    }
  }

  /// Подвал шаблона — после обязательной части, перед протяжкой и резом.
  /// Пустой подвал не даёт ни одной строки.
  void _addFooter(ReceiptBuilder receipt, ReceiptOptions options) {
    // Три состояния подвала, а не два.
    //
    // `null` — не задан: печатается благодарность на языке чека. Держать
    // её словами в `ReceiptOptions` нельзя — это `const` в слое
    // сущностей, и до правки там лежала русская строка, уезжавшая на
    // американский чек.
    //
    // Пустой — стёрт владельцем нарочно, и печатать нечего. Слить его с
    // «не задан» значило бы возвращать благодарность тому, кто её убрал.
    final footer = options.footer;
    if (footer != null && footer.isEmpty) {
      receipt
        ..addNewLines(3)
        ..cut();
      return;
    }

    final block =
        footer ?? ReceiptTextBlock(text: _strings().receiptLabelThankYou);
    receipt
      ..addEmptyLine()
      ..addTextBlock(block);
    receipt
      ..addNewLines(3)
      ..cut();
  }

  /// Дата на бумаге — по условиям СТРАНЫ кассы.
  ///
  /// Здесь стояло `ДД.ММ.ГГГГ` всегда. Для американца «05.09.2026» — это
  /// девятое мая, а не пятое сентября: дата читается другим днём, и на чеке
  /// нет ничего, что сказало бы, какое прочтение верное.
  ///
  /// Условия держит ядро (`TillConventions`), как и язык бумаги по
  /// соседству: слою данных знать о них можно, ядру о слое данных — нет.
  String _formatDateTime(DateTime dt) =>
      TillConventions.current.formatDateTime(dt);

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
      return await _submit(_buildPreCheck(data, await _columns()), documentId);
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
      return await _submit(
        _buildServiceIntake(data, await _columns()),
        documentId,
      );
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
      return await _submit(
        _buildServiceCompletion(data, await _columns()),
        documentId,
      );
    } catch (e) {
      return _cannotIdentify(PrintDocumentKind.serviceCompletion, e);
    }
  }

  ReceiptBuilder _buildPreCheck(PreCheckData data, int width) {
    final receipt = ReceiptBuilder(charWidth: width)..init();

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

  ReceiptBuilder _buildServiceIntake(ServiceReceiptData data, int width) {
    final receipt = ReceiptBuilder(charWidth: width)..init();

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

  ReceiptBuilder _buildServiceCompletion(ServiceReceiptData data, int width) {
    final receipt = ReceiptBuilder(charWidth: width)..init();

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

  /// Блок сертификатов X/Z-отчёта — **обязательство отдельно от выручки**.
  ///
  /// # Зачем он на бумаге
  ///
  /// Деньги за проданный сертификат — не выручка, а долг магазина
  /// (`AccountType.certificateLiability`), а гашение — не оплата
  /// (`FiscalTreatment.offsetNotFiscal`, решение заказчика 2026-09-14). До
  /// этого блока в отчёте не было видно ни того, ни другого: кассир сводил
  /// ящик и не знал, что часть денег в нём — чужие, а владелец снимал их
  /// как прибыль.
  ///
  /// # Две строки, а не одна, и вычитать их друг из друга нельзя
  ///
  /// Они отвечают на разные вопросы и берутся **из разных источников**
  /// (полный разбор — в докстринге `ReceiptPrintService.printXReport`):
  ///
  /// - «Выпущено» — номиналы бумажек, выпущенных за смену. Обязательство
  ///   выросло; деньги лежат в ящике и товара на них не отдано.
  /// - «Погашено» — строки оплаты сертификатом. Товар ушёл, живых денег за
  ///   него не приходило.
  ///
  /// Разность этих двух чисел не значит ничего полезного кассиру: бумажку
  /// выпускают в одну смену, а гасят через год. Поэтому строки стоят
  /// **рядом**, без итога под ними, и итог смены их не трогает.
  ///
  /// # Молчит, когда сертификатов не было
  ///
  /// Оба нуля — блок не печатается вовсе. Магазин, который сертификатами не
  /// торгует, не обязан читать про них две строки на каждом Z-отчёте, а
  /// узнать по ним всё равно нечего: ноль здесь и отсутствие блока значат
  /// одно и то же.
  ///
  /// # Чего этот блок НЕ доказывает
  ///
  /// Не доказывает, что выпущенное оплачено наличными: бумажку могли
  /// оплатить картой. И не показывает, сколько магазин должен **всего**:
  /// здесь движение одной смены, а обязательство копится годами и живёт на
  /// счёте.
  void _addCertificateBlock(
    ReceiptBuilder receipt,
    Decimal issued,
    Decimal redeemed,
  ) {
    if (issued == Decimal.zero && redeemed == Decimal.zero) return;
    final l10n = _strings();
    receipt
      ..addLine()
      // Скобки, а не тире. Измерено на эмуляторе принтера: длинное тире в
      // CP866 отсутствует и печатается «?» — строка «СЕРТИФИКАТЫ ? НЕ
      // ВЫРУЧКА» вышла бы на ленту молча, без единой ошибки. Сторож —
      // `certificate_shift_line_wire_test.dart`, случай «ни одного «?»».
      ..addLeft(l10n.rcpCertificatesNotRevenue)
      ..addRow(l10n.rcpCertIssuedDebt, _formatDecimal(issued))
      ..addRow(l10n.rcpCertRedeemed, _formatDecimal(redeemed));
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
