import 'package:decimal/decimal.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

abstract interface class FiscalService {
  Future<FiscalSettings> currentSettings();

  Future<bool> isEnabled();

  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    String? customerBin,
  });

  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
  });

  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req);

  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req);

  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  });

  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  });

  Future<FiscalResult> openShift();

  Future<FiscalReportResult> closeShift();

  Future<FiscalReportResult> xReport();

  Future<FiscalResult> correction(FiscalCorrectionRequest req);

  Future<FiscalStatus> status();
}

abstract interface class FiscalSettingsSource {
  Future<FiscalSettings> load();
}
