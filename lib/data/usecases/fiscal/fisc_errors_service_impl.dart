import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/fiscal/fisc_errors_service.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';

class FiscErrorsServiceImpl implements FiscErrorsService {
  FiscErrorsServiceImpl({
    required AppDatabase db,
    required WebKassaService webKassaService,
    required Talker logger,
  }) : _db = db,
       _webKassaService = webKassaService,
       _logger = logger;

  final AppDatabase _db;
  final WebKassaService _webKassaService;
  final Talker _logger;

  @override
  Future<List<UnfiscalizedOperation>> checkErrors() async {
    try {
      _logger.info('Checking fiscal errors...');

      final isAvailable = await _webKassaService.isAvailable();
      if (!isAvailable) {
        _logger.debug('WebKassa not available, skipping error check');
        return [];
      }

      final unfiscalizedSales = await _getUnfiscalizedSales();

      final unfiscalizedRefunds = await _getUnfiscalizedRefunds();

      final result = [...unfiscalizedSales, ...unfiscalizedRefunds];

      _logger.info('Found ${result.length} unfiscalized operations');

      return result;
    } catch (e, st) {
      _logger.error('Error checking fiscal errors', e, st);
      return [];
    }
  }

  @override
  Future<int> getUnfiscalizedCount() async {
    final errors = await checkErrors();
    return errors.length;
  }

  @override
  Future<RetryFiscalizationResult> retryFiscalization({
    required int operationId,
    required bool isSale,
  }) async {
    try {
      _logger.info(
        'Retrying fiscalization for operation $operationId (isSale: $isSale)',
      );

      final result = isSale
          ? await _webKassaService.fiscalizeSale(
              saleId: operationId,
              amount: Decimal.zero,
              cashAmount: Decimal.zero,
              cardAmount: Decimal.zero,
            )
          : await _webKassaService.fiscalizeRefund(
              refundId: operationId,
              originalFiscalNo: '',
              amount: Decimal.zero,
            );

      if (result.success) {
        return RetryFiscalizationResult.success(
          fiscalNo: result.fiscalNo!,
          ticketUrl: result.ticketUrl,
        );
      } else {
        return RetryFiscalizationResult.failed(
          result.errorMessage ?? 'Неизвестная ошибка',
        );
      }
    } catch (e, st) {
      _logger.error('Error retrying fiscalization', e, st);
      return RetryFiscalizationResult.failed('Ошибка: $e');
    }
  }

  @override
  Future<void> skipFiscalization({
    required int operationId,
    required bool isSale,
  }) async {
    try {
      _logger.warning('Skipping fiscalization for operation $operationId');

      await _db.webkassaReceiptDao.insertReceipt(
        WebkassaReceiptsCompanion(
          operationId: Value(operationId),
          fiscalNo: const Value('SKIPPED'),
          isSale: Value(isSale),
        ),
      );
    } catch (e, st) {
      _logger.error('Error skipping fiscalization', e, st);
    }
  }

  @override
  DateTime getNextCheckTime() {
    return FiscErrorsSchedule.getNextCheckTime();
  }

  @override
  bool shouldCheckNow() {
    return FiscErrorsSchedule.isCheckTimeNow();
  }

  Future<List<UnfiscalizedOperation>> _getUnfiscalizedSales() async {
    try {
      final thisPos = await _db.thisPosDao.get();
      if (thisPos == null || !thisPos.sendToOfd) {
        _logger.debug('OFD is disabled in POS settings, skipping check');
        return [];
      }

      final sales = await _db.saleDao.findByState(1);
      final result = <UnfiscalizedOperation>[];

      for (final sale in sales) {
        if (!sale.isOfd) continue;

        final receipt = await _db.webkassaReceiptDao.findByIsSaleAndOperationId(
          true,
          sale.receiptNo,
        );

        if (receipt == null || receipt.fiscalNo == null) {
          result.add(
            UnfiscalizedOperation(
              operationId: sale.receiptNo,
              receiptNo: sale.receiptNo,
              amount: sale.amount.toStringAsFixed(2),
              time: DateTime.fromMillisecondsSinceEpoch(sale.time * 1000),
              isSale: true,
            ),
          );
        }
      }

      return result;
    } catch (e) {
      _logger.warning('Error getting unfiscalized sales: $e');
      return [];
    }
  }

  Future<List<UnfiscalizedOperation>> _getUnfiscalizedRefunds() async {
    try {
      final thisPos = await _db.thisPosDao.get();
      if (thisPos == null || !thisPos.sendToOfd) {
        return [];
      }

      final refunds = await _db.refundDao.findByState(1);
      final result = <UnfiscalizedOperation>[];

      for (final refund in refunds) {
        final receipt = await _db.webkassaReceiptDao.findByIsSaleAndOperationId(
          false,
          refund.localId,
        );

        if (receipt == null || receipt.fiscalNo == null) {
          result.add(
            UnfiscalizedOperation(
              operationId: refund.localId,
              receiptNo: refund.localId,
              amount: refund.amount.toStringAsFixed(2),
              time: DateTime.fromMillisecondsSinceEpoch(refund.time * 1000),
              isSale: false,
            ),
          );
        }
      }

      return result;
    } catch (e) {
      _logger.warning('Error getting unfiscalized refunds: $e');
      return [];
    }
  }
}
