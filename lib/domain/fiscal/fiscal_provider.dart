import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class FiscalCapabilities {
  const FiscalCapabilities({
    this.implicitShift = false,
    this.supportsCorrection = false,
    this.supportsMarking = false,
    this.supportsLocalModule = false,
    this.supportsPurchase = false,
  });

  final bool implicitShift;

  final bool supportsCorrection;

  final bool supportsMarking;

  final bool supportsLocalModule;

  final bool supportsPurchase;

  static const FiscalCapabilities none = FiscalCapabilities();
}

abstract interface class FiscalProvider {
  String get id;

  FiscalCapabilities get capabilities;

  Future<FiscalAuthResult> authorize(FiscalSettings config);

  String? validateConfig(FiscalSettings config);

  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req);
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req);
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req);
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req);

  Future<FiscalResult> moneyIn(FiscalMoneyRequest req);

  Future<FiscalResult> moneyOut(FiscalMoneyRequest req);

  Future<FiscalResult> openShift(FiscalShiftRequest req);

  Future<FiscalReportResult> closeShift(FiscalShiftRequest req);

  Future<FiscalReportResult> xReport(FiscalShiftRequest req);

  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req);

  Future<FiscalStatus> getStatus();
}
