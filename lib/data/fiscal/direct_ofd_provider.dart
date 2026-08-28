import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class DirectOfdProvider implements FiscalProvider {
  DirectOfdProvider(this.settings);

  final FiscalSettings settings;

  @override
  String get id => FiscalOperatorType.directOfd.id;

  @override
  FiscalCapabilities get capabilities => const FiscalCapabilities(
    implicitShift: false,
    supportsCorrection: false,
    supportsMarking: true,
    supportsLocalModule: true,
    supportsPurchase: true,
  );

  @override
  String? validateConfig(FiscalSettings config) {
    if (config.operatorType != FiscalOperatorType.directOfd) {
      return 'Выбран другой оператор фискализации';
    }
    final znm = config.cashboxUniqueNumber;
    if (znm == null || znm.isEmpty) {
      return 'Укажите ЗНМ (заводской номер) кассы';
    }
    final rnm = config.registrationNumber;
    if (rnm == null || rnm.isEmpty) {
      return 'Укажите РНМ (регистрационный номер машины)';
    }
    final host = config.resolvedBaseUrl;
    if (host == null || host.isEmpty) {
      return 'Укажите адрес сервера ОФД';
    }
    if (config.directOfdKeyPath == null || config.directOfdKeyPath!.isEmpty) {
      return 'Укажите путь к ключу/сертификату подписи';
    }
    return 'Прямое подключение к ОФД ещё не реализовано';
  }

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.failure(
        'Прямое подключение к ОФД ещё не реализовано',
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
      'DirectOfdProvider.$op не реализован (прямое подключение к ОФД)';
}
