import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

class FiscalServiceImpl implements FiscalService {
  FiscalServiceImpl({
    required AppDatabase db,
    required FiscalProviderRegistry registry,
    required FiscalSettingsSource settingsSource,
    required Talker logger,
    FiscalPositionBuilder? positionBuilder,
  }) : _db = db,
       _registry = registry,
       _settingsSource = settingsSource,
       _logger = logger,
       _positions = positionBuilder ?? const FiscalPositionBuilder();

  final AppDatabase _db;
  final FiscalProviderRegistry _registry;
  final FiscalSettingsSource _settingsSource;
  final Talker _logger;
  final FiscalPositionBuilder _positions;

  @override
  Future<FiscalSettings> currentSettings() => _settingsSource.load();

  @override
  Future<bool> isEnabled() async => (await currentSettings()).isEnabled;

  Future<(FiscalProvider, FiscalSettings)> _resolve() async {
    final settings = await currentSettings();
    return (_registry.resolve(settings), settings);
  }

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    String? customerBin,
  }) async {
    try {
      final (provider, settings) = await _resolve();

      final positions = await _buildSalePositions(
        receiptNo: saleReceiptNo,
        posId: salePosId,
        settings: settings,
      );
      final payments = _buildPayments(cashAmount, cardAmount);

      final req = FiscalSaleRequest(
        idempotencyKey: _idempotencyKey('sale', saleReceiptNo, salePosId),
        localOperationId: saleReceiptNo,
        positions: positions,
        payments: payments,
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime.now(),
        customer: customerBin == null
            ? null
            : FiscalCustomer(binIin: customerBin),
      );

      final result = await provider.fiscalizeSale(req);
      await _persistReceipt(
        operationId: saleReceiptNo,
        receiptNo: saleReceiptNo,
        result: result,
        isSale: true,
      );
      _log('sale', saleReceiptNo, result);
      return result;
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizeSale error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации: $e');
    }
  }

  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
  }) async {
    try {
      final (provider, settings) = await _resolve();

      final positions = await _buildRefundPositions(
        refundLocalId: refundLocalId,
        settings: settings,
      );

      final basis = await _buildRefundBasis(
        originalSaleReceiptNo: originalSaleReceiptNo,
        settings: settings,
        fallbackTotal: amount,
      );

      final sale = FiscalSaleRequest(
        idempotencyKey: _idempotencyKey('refund', refundLocalId, 0),
        localOperationId: refundLocalId,
        positions: positions,
        payments: [FiscalPayment(kind: FiscalPaymentKind.cash, amount: amount)],
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime.now(),
        kind: FiscalOperationKind.saleReturn,
      );

      final result = await provider.fiscalizeRefund(
        FiscalRefundRequest(sale: sale, basis: basis),
      );
      await _persistReceipt(
        operationId: refundLocalId,
        receiptNo: refundLocalId,
        result: result,
        isSale: false,
      );
      _log('refund', refundLocalId, result);
      return result;
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizeRefund error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации возврата: $e');
    }
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.fiscalizePurchase(req);
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizePurchase error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации покупки: $e');
    }
  }

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.fiscalizePurchaseReturn(req);
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizePurchaseReturn error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации возврата покупки: $e');
    }
  }

  @override
  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.moneyIn(_moneyReq(amount, comment, idempotencyKey));
    } catch (e, st) {
      _logger.warning('FiscalService.moneyIn error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации внесения: $e');
    }
  }

  @override
  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.moneyOut(
        _moneyReq(amount, comment, idempotencyKey),
      );
    } catch (e, st) {
      _logger.warning('FiscalService.moneyOut error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации изъятия: $e');
    }
  }

  @override
  Future<FiscalResult> openShift() async {
    try {
      final (provider, _) = await _resolve();
      return await provider.openShift(const FiscalShiftRequest());
    } catch (e, st) {
      _logger.warning('FiscalService.openShift error: $e', e, st);
      return FiscalResult.failure('Ошибка открытия смены: $e');
    }
  }

  @override
  Future<FiscalReportResult> closeShift() async {
    try {
      final (provider, _) = await _resolve();
      final report = await provider.closeShift(const FiscalShiftRequest());
      _log('closeShift(Z)', report.shiftNumber ?? 0, report.result);
      return report;
    } catch (e, st) {
      _logger.warning('FiscalService.closeShift error: $e', e, st);
      return FiscalReportResult.failure('Ошибка Z-отчёта: $e');
    }
  }

  @override
  Future<FiscalReportResult> xReport() async {
    try {
      final (provider, _) = await _resolve();
      return await provider.xReport(const FiscalShiftRequest());
    } catch (e, st) {
      _logger.warning('FiscalService.xReport error: $e', e, st);
      return FiscalReportResult.failure('Ошибка X-отчёта: $e');
    }
  }

  @override
  Future<FiscalResult> correction(FiscalCorrectionRequest req) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.correctionReceipt(req);
    } catch (e, st) {
      _logger.warning('FiscalService.correction error: $e', e, st);
      return FiscalResult.failure('Ошибка чека коррекции: $e');
    }
  }

  @override
  Future<FiscalStatus> status() async {
    try {
      final (provider, _) = await _resolve();
      return await provider.getStatus();
    } catch (e, st) {
      _logger.warning('FiscalService.status error: $e', e, st);
      return FiscalStatus.notConfigured();
    }
  }

  Future<List<FiscalPosition>> _buildSalePositions({
    required int receiptNo,
    required int posId,
    required FiscalSettings settings,
  }) async {
    final lines = await _db.saleProductDao.findBySale(receiptNo, posId);
    final positions = <FiscalPosition>[];
    for (final sp in lines) {
      final product = await _db.productInfoDao.findByUcode(sp.ucode);
      final lineTotal = sp.quantity * sp.price;

      final isMarkable = product?.isMarkable ?? false;
      var markCodes = const <String>[];
      if (isMarkable) {
        final marks = await _db.saleProductDao.findMarksBySaleProduct(sp.id);
        markCodes = marks
            .map((m) => m.mark)
            .whereType<String>()
            .where((m) => m.isNotEmpty)
            .toList();
      }

      positions.add(
        _positions.build(
          name: product?.name ?? 'Товар ${sp.ucode}',
          quantity: sp.quantity,
          unitPrice: sp.price,
          lineTotal: lineTotal,
          settings: settings,
          productVatRate: product?.vatRate,
          ntin: product?.ntin,
          barcode: sp.barcode?.toString() ?? product?.barcode.toString(),
          isMarkable: isMarkable,
          markCodes: markCodes,
        ),
      );
    }
    return positions;
  }

  Future<List<FiscalPosition>> _buildRefundPositions({
    required int refundLocalId,
    required FiscalSettings settings,
  }) async {
    final lines = await _db.refundDao.findProductsByRefund(refundLocalId);
    final positions = <FiscalPosition>[];
    for (final rp in lines) {
      final product = await _db.productInfoDao.findByUcode(rp.ucode);
      final lineTotal = rp.quantity * rp.price;

      final isMarkable = product?.isMarkable ?? false;
      var markCodes = const <String>[];
      if (isMarkable) {
        final marks = await _db.refundDao.findMarksByRefundProduct(rp.id);
        markCodes = marks
            .map((m) => m.mark)
            .whereType<String>()
            .where((m) => m.isNotEmpty)
            .toList();
      }

      positions.add(
        _positions.build(
          name: product?.name ?? 'Товар ${rp.ucode}',
          quantity: rp.quantity,
          unitPrice: rp.price,
          lineTotal: lineTotal,
          settings: settings,
          productVatRate: product?.vatRate,
          ntin: product?.ntin,
          barcode: product?.barcode.toString(),
          isMarkable: isMarkable,
          markCodes: markCodes,
        ),
      );
    }
    return positions;
  }

  Future<FiscalRefundBasis> _buildRefundBasis({
    required int? originalSaleReceiptNo,
    required FiscalSettings settings,
    required Decimal fallbackTotal,
  }) async {
    var originalSign = '';
    var originalWasOffline = false;
    var originalDateTime = DateTime.now();
    var originalTotal = fallbackTotal;

    if (originalSaleReceiptNo != null) {
      final receipt = await _db.webkassaReceiptDao.findByIsSaleAndOperationId(
        true,
        originalSaleReceiptNo,
      );
      if (receipt != null) {
        originalSign = receipt.fiscalNo ?? '';
        originalWasOffline = receipt.wkOfflineMode ?? false;
        if (receipt.wkTime != null) {
          originalDateTime = DateTime.fromMillisecondsSinceEpoch(
            receipt.wkTime! * 1000,
          );
        }
      }
      final sale = await _db.saleDao.findBySaleId(originalSaleReceiptNo);
      if (sale != null) {
        originalTotal = sale.amount;
      }
    }

    return FiscalRefundBasis(
      originalFiscalSign: originalSign,
      originalDateTime: originalDateTime,
      originalRegistrationNumber: settings.registrationNumber ?? '',
      originalTotal: originalTotal,
      originalWasOffline: originalWasOffline,
    );
  }

  List<FiscalPayment> _buildPayments(Decimal cash, Decimal card) {
    final payments = <FiscalPayment>[];
    if (cash > Decimal.zero) {
      payments.add(FiscalPayment(kind: FiscalPaymentKind.cash, amount: cash));
    }
    if (card > Decimal.zero) {
      payments.add(FiscalPayment(kind: FiscalPaymentKind.card, amount: card));
    }
    if (payments.isEmpty) {
      payments.add(
        FiscalPayment(kind: FiscalPaymentKind.cash, amount: Decimal.zero),
      );
    }
    return payments;
  }

  FiscalMoneyRequest _moneyReq(Decimal amount, String? comment, String? key) =>
      FiscalMoneyRequest(
        idempotencyKey: key ?? 'money-${DateTime.now().microsecondsSinceEpoch}',
        amount: amount,
        occurredAt: DateTime.now(),
        comment: comment,
      );

  String _idempotencyKey(String op, int id1, int id2) => '$op-$id1-$id2';

  Future<void> _persistReceipt({
    required int operationId,
    required int receiptNo,
    required FiscalResult result,
    required bool isSale,
  }) async {
    if (!result.success || !result.hasFiscalSign) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _db.webkassaReceiptDao.insertReceipt(
        WebkassaReceiptsCompanion(
          operationId: Value(operationId),
          receiptNo: Value(receiptNo),
          fiscalNo: Value(result.fiscalSign),
          wkReceiptNo: Value(result.documentNumber?.toString()),
          wkTime: Value(now),
          wkOfflineMode: Value(result.offlineMode),
          ticketUrl: Value(result.ticketUrl),
          isSale: Value(isSale),
        ),
      );
    } catch (e, st) {
      _logger.warning('FiscalService: persist receipt failed: $e', e, st);
    }
  }

  void _log(String op, int id, FiscalResult r) {
    if (r.success) {
      if (r.queued) {
        _logger.info('Fiscal $op #$id queued offline');
      } else {
        _logger.info('Fiscal $op #$id ok: sign=${r.fiscalSign}');
      }
    } else {
      _logger.warning(
        'Fiscal $op #$id failed: ${r.errorMessage} '
        '(${r.errorCode})',
      );
    }
  }
}
