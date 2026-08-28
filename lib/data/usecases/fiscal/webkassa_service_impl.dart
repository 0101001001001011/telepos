import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';

class WebKassaServiceImpl implements WebKassaService {
  WebKassaServiceImpl({
    required AppDatabase db,
    required Talker logger,
    required FiscalSettingsSource settingsSource,
    FiscalPositionBuilder? positionBuilder,
  }) : _db = db,
       _logger = logger,
       _settingsSource = settingsSource,
       _positions = positionBuilder ?? const FiscalPositionBuilder();

  final AppDatabase _db;
  final Talker _logger;
  final FiscalSettingsSource _settingsSource;
  final FiscalPositionBuilder _positions;

  WebKassaProvider? _provider;
  FiscalSettings? _settings;

  Future<WebKassaProvider?> _getProvider() async {
    final settings = await _settingsSource.load();
    if (settings.operatorType != FiscalOperatorType.webkassa) return null;
    if (settings.apiKey == null || settings.apiKey!.isEmpty) return null;
    if (_provider != null && _settings == settings) return _provider;
    _settings = settings;
    _provider = WebKassaProvider(settings: settings, logger: _logger);
    return _provider;
  }

  @override
  Future<FiscalizeResult> fiscalizeSale({
    required int saleId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    List<FiscalItemData>? items,
    String? customerBin,
  }) async {
    _logger.info('WebKassa: fiscalizing sale $saleId, amount=$amount');
    final provider = await _getProvider();
    if (provider == null) return FiscalizeResult.notConfigured();

    final settings = _settings!;
    final sale = await _db.saleDao.findBySaleId(saleId);
    if (sale == null) {
      return FiscalizeResult.failed('Продажа не найдена: $saleId');
    }

    try {
      final positions = await _salePositions(
        sale.receiptNo,
        sale.posId,
        settings,
      );
      final req = FiscalSaleRequest(
        idempotencyKey: 'sale-${sale.receiptNo}-${sale.posId}',
        localOperationId: saleId,
        positions: positions,
        payments: _payments(cashAmount, cardAmount),
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime.now(),
        customer: customerBin == null
            ? null
            : FiscalCustomer(binIin: customerBin),
      );
      final result = await provider.fiscalizeSale(req);
      if (result.success && result.hasFiscalSign) {
        await _saveReceipt(
          operationId: saleId,
          receiptNo: sale.receiptNo,
          result: result,
          isSale: true,
        );
      }
      return _toLegacy(result);
    } catch (e, st) {
      _logger.error('WebKassa fiscalizeSale error', e, st);
      return FiscalizeResult.failed('Ошибка связи с WebKassa: $e');
    }
  }

  @override
  Future<FiscalizeResult> fiscalizeRefund({
    required int refundId,
    required String originalFiscalNo,
    required Decimal amount,
    List<FiscalItemData>? items,
  }) async {
    _logger.info('WebKassa: fiscalizing refund $refundId, amount=$amount');
    final provider = await _getProvider();
    if (provider == null) return FiscalizeResult.notConfigured();

    final settings = _settings!;
    try {
      final positions = await _refundPositions(refundId, settings);
      final sale = FiscalSaleRequest(
        idempotencyKey: 'refund-$refundId',
        localOperationId: refundId,
        positions: positions,
        payments: [FiscalPayment(kind: FiscalPaymentKind.cash, amount: amount)],
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime.now(),
        kind: FiscalOperationKind.saleReturn,
      );
      final basis = FiscalRefundBasis(
        originalFiscalSign: originalFiscalNo,
        originalDateTime: DateTime.now(),
        originalRegistrationNumber: settings.registrationNumber ?? '',
        originalTotal: amount,
      );
      final result = await provider.fiscalizeRefund(
        FiscalRefundRequest(sale: sale, basis: basis),
      );
      if (result.success && result.hasFiscalSign) {
        await _saveReceipt(
          operationId: refundId,
          receiptNo: refundId,
          result: result,
          isSale: false,
        );
      }
      return _toLegacy(result);
    } catch (e, st) {
      _logger.error('WebKassa fiscalizeRefund error', e, st);
      return FiscalizeResult.failed('Ошибка связи с WebKassa: $e');
    }
  }

  @override
  Future<WebKassaStatus> getStatus() async {
    try {
      final provider = await _getProvider();
      if (provider == null) {
        return const WebKassaStatus(
          isConfigured: false,
          isActive: false,
          isOnline: false,
          lastError: 'WebKassa не настроен',
        );
      }
      final status = await provider.getStatus();
      return WebKassaStatus(
        isConfigured: status.configured,
        isActive: status.active,
        isOnline: status.online,
        lastErrorTime: status.lastErrorAt,
        lastError: status.lastError,
      );
    } catch (e) {
      _logger.error('Error getting WebKassa status', e);
      return WebKassaStatus(
        isConfigured: false,
        isActive: false,
        isOnline: false,
        lastError: 'Ошибка: $e',
      );
    }
  }

  @override
  Future<WebKassaConfig?> getConfig() async {
    try {
      final config = await _db.webkassaReceiptDao.getFirstConfig();
      if (config == null) return null;
      return WebKassaConfig(
        posId: config.posId,
        posFactoryNo: config.posFactoryNo,
        taxDeptRegNo: config.taxDeptRegNo,
        ofdId: config.ofdId,
        taxpayerName: config.taxpayerName,
        iinBin: config.iinBin,
        address: config.address,
        ofdName: config.ofdName,
        ofdHost: config.ofdHost,
        isActive: config.isActive,
        isTaxpayer: config.isTaxpayer,
        vatSerialNo: config.taxpayerVatSerialNo,
        vatNo: config.taxpayerVatNo,
      );
    } catch (e) {
      _logger.error('Error getting WebKassa config', e);
      return null;
    }
  }

  @override
  Future<bool> isAvailable() async {
    final status = await getStatus();
    return status.canFiscalize;
  }

  @override
  Future<int> getOfflineReceiptCount() async {
    try {
      return await _db.webkassaReceiptDao.countOfflineReceipts();
    } catch (e) {
      _logger.warning('Error getting offline receipt count: $e');
      return 0;
    }
  }

  @override
  Future<OfflineSyncResult> syncOfflineReceipts() async {
    _logger.info('Starting offline receipts sync...');
    try {
      final offlineReceipts = await _db.webkassaReceiptDao
          .findOfflineReceipts();
      if (offlineReceipts.isEmpty) return OfflineSyncResult.empty();

      final provider = await _getProvider();
      if (provider == null) {
        return OfflineSyncResult(
          totalCount: offlineReceipts.length,
          syncedCount: 0,
          failedCount: offlineReceipts.length,
          errors: const ['WebKassa не настроен'],
        );
      }

      var syncedCount = 0;
      var failedCount = 0;
      final errors = <String>[];

      for (final receipt in offlineReceipts) {
        try {
          if (receipt.fiscalNo != null && receipt.fiscalNo!.isNotEmpty) {
            await _db.webkassaReceiptDao.markAsSynced(
              receipt.operationId,
              receipt.isSale ?? true,
            );
            syncedCount++;
          } else {
            final result = await _retryFiscalization(receipt);
            if (result.success) {
              syncedCount++;
            } else {
              failedCount++;
              errors.add('Чек ${receipt.operationId}: ${result.errorMessage}');
            }
          }
        } catch (e) {
          failedCount++;
          errors.add('Чек ${receipt.operationId}: $e');
        }
      }

      _logger.info(
        'Offline sync completed: $syncedCount synced, $failedCount failed',
      );
      return OfflineSyncResult(
        totalCount: offlineReceipts.length,
        syncedCount: syncedCount,
        failedCount: failedCount,
        errors: errors,
      );
    } catch (e, st) {
      _logger.error('Offline sync failed', e, st);
      return OfflineSyncResult(
        totalCount: 0,
        syncedCount: 0,
        failedCount: 0,
        errors: ['Ошибка синхронизации: $e'],
      );
    }
  }

  Future<FiscalizeResult> _retryFiscalization(WebkassaReceipt receipt) async {
    final isSale = receipt.isSale ?? true;
    final operationId = receipt.operationId;

    if (isSale) {
      final sale = await _db.saleDao.findBySaleId(operationId);
      if (sale == null) {
        return FiscalizeResult.failed('Продажа не найдена: $operationId');
      }
      final payments = await _db.paymentDao.findBySale(
        sale.receiptNo,
        sale.posId,
      );
      var cashAmount = Decimal.zero;
      var cardAmount = Decimal.zero;
      for (final payment in payments) {
        if (payment.payeeAccountId == 1) {
          cashAmount += payment.amount;
        } else {
          cardAmount += payment.amount;
        }
      }
      return fiscalizeSale(
        saleId: operationId,
        amount: sale.amount,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
      );
    }

    final refunds = await _db
        .customSelect(
          'SELECT * FROM refunds WHERE local_id = ?',
          variables: [Variable.withInt(operationId)],
          readsFrom: {_db.refunds},
        )
        .get();
    if (refunds.isEmpty) {
      return FiscalizeResult.failed('Возврат не найден: $operationId');
    }
    final refund = refunds.first;
    final amount = Decimal.parse(refund.read<double>('amount').toString());
    final originalSaleId = refund.read<int?>('sale_id');
    var originalFiscalNo = '';
    if (originalSaleId != null) {
      final originalReceipt = await _db.webkassaReceiptDao
          .findByIsSaleAndOperationId(true, originalSaleId);
      originalFiscalNo = originalReceipt?.fiscalNo ?? '';
    }
    return fiscalizeRefund(
      refundId: operationId,
      originalFiscalNo: originalFiscalNo,
      amount: amount,
    );
  }

  Future<FiscalReceipt?> getReceipt(
    int operationId, {
    required bool isSale,
  }) async {
    final receipt = await _db.webkassaReceiptDao.findByIsSaleAndOperationId(
      isSale,
      operationId,
    );
    if (receipt == null) return null;
    return FiscalReceipt(
      operationId: receipt.operationId,
      receiptNo: receipt.receiptNo,
      fiscalNo: receipt.fiscalNo,
      wkReceiptNo: receipt.wkReceiptNo,
      wkTime: receipt.wkTime != null
          ? DateTime.fromMillisecondsSinceEpoch(receipt.wkTime! * 1000)
          : null,
      wkOfflineMode: receipt.wkOfflineMode ?? false,
      ticketUrl: receipt.ticketUrl,
      isSale: receipt.isSale ?? true,
    );
  }

  Future<List<FiscalPosition>> _salePositions(
    int receiptNo,
    int posId,
    FiscalSettings settings,
  ) async {
    final lines = await _db.saleProductDao.findBySale(receiptNo, posId);
    final positions = <FiscalPosition>[];
    for (final sp in lines) {
      final product = await _db.productInfoDao.findByUcode(sp.ucode);
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
          lineTotal: sp.quantity * sp.price,
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

  Future<List<FiscalPosition>> _refundPositions(
    int refundLocalId,
    FiscalSettings settings,
  ) async {
    final lines = await _db.refundDao.findProductsByRefund(refundLocalId);
    final positions = <FiscalPosition>[];
    for (final rp in lines) {
      final product = await _db.productInfoDao.findByUcode(rp.ucode);
      positions.add(
        _positions.build(
          name: product?.name ?? 'Товар ${rp.ucode}',
          quantity: rp.quantity,
          unitPrice: rp.price,
          lineTotal: rp.quantity * rp.price,
          settings: settings,
          productVatRate: product?.vatRate,
          ntin: product?.ntin,
          barcode: product?.barcode.toString(),
          isMarkable: product?.isMarkable ?? false,
        ),
      );
    }
    return positions;
  }

  List<FiscalPayment> _payments(Decimal cash, Decimal card) {
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

  Future<void> _saveReceipt({
    required int operationId,
    required int receiptNo,
    required FiscalResult result,
    required bool isSale,
  }) async {
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
  }

  FiscalizeResult _toLegacy(FiscalResult r) {
    if (r.success) {
      return FiscalizeResult.success(
        fiscalNo: r.fiscalSign ?? '',
        ticketUrl: r.ticketUrl,
        offlineMode: r.offlineMode,
      );
    }
    return FiscalizeResult.failed(
      r.errorMessage ?? 'Ошибка фискализации',
      errorCode: r.rawErrorCode,
    );
  }

  void dispose() {
    _provider?.dispose();
    _provider = null;
  }
}
