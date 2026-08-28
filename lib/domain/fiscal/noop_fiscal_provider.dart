import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class NoOpFiscalProvider implements FiscalProvider {
  const NoOpFiscalProvider();

  @override
  String get id => 'noop';

  @override
  FiscalCapabilities get capabilities => FiscalCapabilities.none;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok();

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async =>
      FiscalResult.queued();

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async =>
      FiscalResult.queued();

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.queued();

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.queued();

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      FiscalResult.queued();

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      FiscalResult.queued();

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      const FiscalResult(success: true);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      const FiscalReportResult(result: FiscalResult(success: true));

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      const FiscalReportResult(result: FiscalResult(success: true));

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.unsupported('correctionReceipt');

  @override
  Future<FiscalStatus> getStatus() async =>
      const FiscalStatus(configured: false, active: false, online: false);
}
