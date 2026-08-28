import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class Kassa24Provider implements FiscalProvider {
  Kassa24Provider(this.settings);

  final FiscalSettings settings;

  @override
  String get id => FiscalOperatorType.kassa24.id;

  @override
  FiscalCapabilities get capabilities => const FiscalCapabilities(
    implicitShift: false,
    supportsCorrection: false,
    supportsMarking: true,
    supportsLocalModule: false,
    supportsPurchase: true,
  );

  @override
  String? validateConfig(FiscalSettings config) {
    if (config.operatorType != FiscalOperatorType.kassa24) {
      return 'Выбран другой оператор фискализации';
    }
    if (config.login == null || config.login!.isEmpty) {
      return 'Укажите логин Kassa24 / Fiscal24';
    }
    if (config.password == null || config.password!.isEmpty) {
      return 'Укажите пароль Kassa24 / Fiscal24';
    }
    if (config.cashboxUniqueNumber == null ||
        config.cashboxUniqueNumber!.isEmpty) {
      return 'Укажите ЗНМ (заводской номер) кассы';
    }
    if (config.resolvedBaseUrl == null || config.resolvedBaseUrl!.isEmpty) {
      return 'Не удалось определить адрес сервера Fiscal24';
    }
    return 'Интеграция Kassa24 / Fiscal24 ещё не реализована';
  }

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.failure(
        'Интеграция Kassa24 / Fiscal24 ещё не реализована',
        code: FiscalErrorCode.unsupported,
      );

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async =>
      _todo('fiscalizeSale');

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async =>
      _todo('fiscalizeRefund');

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      _todo('fiscalizePurchase');

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      _todo('fiscalizePurchaseReturn');

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      _todo('moneyIn');

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      _todo('moneyOut');

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      _todo('openShift');

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      FiscalReportResult.failure(
        _notImplemented('closeShift'),
        code: FiscalErrorCode.unsupported,
      );

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      FiscalReportResult.failure(
        _notImplemented('xReport'),
        code: FiscalErrorCode.unsupported,
      );

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.unsupported('correctionReceipt');

  @override
  Future<FiscalStatus> getStatus() async => FiscalStatus(
    configured: validateConfig(settings) == null,
    active: false,
    online: false,
    lastError: _notImplemented('getStatus'),
  );

  FiscalResult _todo(String op) => FiscalResult.failure(
    _notImplemented(op),
    code: FiscalErrorCode.unsupported,
  );

  String _notImplemented(String op) =>
      'Kassa24Provider.$op не реализован (Fiscal24 REST)';
}
