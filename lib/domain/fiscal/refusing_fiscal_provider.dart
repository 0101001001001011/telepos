import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

/// Провайдер, который **ничего не умеет и об этом говорит**.
///
/// Подставляется реестром, когда оператор не выбран (`operatorType == none`)
/// либо выбран, но не зарегистрирован. Существует ради того, чтобы
/// `FiscalProviderRegistry.resolve` возвращал значение, а не `null`: порт
/// остаётся необнуляемым, и вызывающему не приходится помнить о проверке.
///
/// **Контракт, одной строкой: каждый член возвращает названный отказ; ни один
/// не возвращает успех.** До переименования здесь стоял `NoOpFiscalProvider`,
/// и он возвращал успех в 11 методах из 13. Шесть из них отвечали
/// [FiscalResult.queued] — то есть обещали очередь, которой за ними нет:
/// очередь даёт `OfflineQueueingProvider`, а он оборачивает **настоящих**
/// провайдеров; заглушка подставлялась *вместо* обёртки, а не под неё.
/// Чек, за который никто не отвечал, уходил покупателю как фискальный.
///
/// Отказ этого провайдера не делает каждую продажу нефискальной: политика
/// `isOfdSale` стоит **раньше** — она спрашивает `FiscalService.isEnabled()`,
/// то есть `operatorType != none`, и на кассе без оператора до провайдера дело
/// не доходит вовсе. Сюда попадают только те, кто политику обошёл, — и им
/// отказ причитается.
class RefusingFiscalProvider implements FiscalProvider {
  const RefusingFiscalProvider();

  @override
  String get id => 'refusing';

  @override
  FiscalCapabilities get capabilities => FiscalCapabilities.none;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.failure(_reason, code: FiscalErrorCode.notConfigured);

  @override
  String? validateConfig(FiscalSettings config) => _reason;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      FiscalReportResult(result: FiscalResult.notConfigured());

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      FiscalReportResult(result: FiscalResult.notConfigured());

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalStatus> getStatus() async => FiscalStatus.notConfigured();

  static const String _reason = 'Фискальный оператор не настроен';
}
