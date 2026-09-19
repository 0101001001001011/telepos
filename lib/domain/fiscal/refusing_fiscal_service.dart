import 'package:decimal/decimal.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

/// Фискальный узел, которого **нет в собранной кассе** — сказанный вслух.
///
/// # Зачем этот класс существует
///
/// До задачи 3 «узла фискализации нет» выражалось нулём: довод `fiscal:`
/// у `LocalPaymentService` был обнуляемым, и его просто не передавали.
/// Ноль читался двусмысленно, и это не оборот речи, а измерение: из 14
/// мест сборки службы **8 не передавали довод вовсе**, и ни одно из них
/// не собиралось этим что-либо утверждать — они про фискализацию не
/// думали. Компилятор молчал одинаково и там, и в единственном месте,
/// где отсутствие узла было настоящим решением.
///
/// Теперь довод обязателен, а «узла нет» — это **тип**. Тот, кто собирает
/// кассу без фискального узла, обязан назвать его: `const
/// RefusingFiscalService()`. Забыть больше нельзя — не по сторожу, а по
/// сборке.
///
/// # Контракт, одной строкой
///
/// *Каждый член возвращает названный отказ; ни один не возвращает успех и
/// ни один не обещает очереди.*
///
/// Вторая половина — не украшение. Задача 2 сняла ровно такую ложь с
/// `NoOpFiscalProvider`, который отвечал [FiscalResult.queued] шестью
/// методами: «чек уедет сам». Очередь даёт `OfflineQueueingProvider`,
/// оборачивающий **настоящих** исполнителей, а заглушка подставлялась
/// вместо всей цепочки — обещать за неё было некому. Повторять эту ложь
/// уровнем выше, у службы, нельзя по той же причине.
///
/// # Почему [isEnabled] отвечает `false`, но этого мало
///
/// `isOfdSale` спрашивает [isEnabled] первым, и `false` увёл бы чек в
/// [FiscalState.operatorAbsent] — «оператор не настроен». Это неправда:
/// оператора нельзя настроить там, где нет узла, который бы его читал.
/// Одно лечится экраном настроек, другое — пересборкой кассы, и задача 5
/// развела их нарочно.
///
/// Поэтому `LocalPaymentService._fiscalize` узнаёт **этот тип** и отвечает
/// [FiscalState.fiscalModuleAbsent]. Проверка типа здесь — не
/// переехавший обнуляемый сторож: ноль был значением по умолчанию и
/// получался молчанием, а этот тип нельзя получить иначе, чем написав его
/// имя. Разница между «забыл» и «сказал» и есть вся задача.
class RefusingFiscalService implements FiscalService {
  const RefusingFiscalService();

  /// Настройки, в которых оператора нет и быть не может.
  ///
  /// Не `null` и не выдумка: `FiscalOperatorType.none` — то же самое, что
  /// увидела бы касса с ненастроенным оператором. Отличает эти два
  /// положения не поле настроек, а тип службы.
  @override
  Future<FiscalSettings> currentSettings() async => FiscalSettings();

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal creditAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePrepaymentRefund({
    required int operationId,
    required int? intakeOperationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> openShift() async => FiscalResult.notConfigured();

  @override
  Future<FiscalReportResult> closeShift() async =>
      FiscalReportResult(result: FiscalResult.notConfigured());

  @override
  Future<FiscalReportResult> xReport() async =>
      FiscalReportResult(result: FiscalResult.notConfigured());

  @override
  Future<FiscalResult> correction(FiscalCorrectionRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalStatus> status() async => FiscalStatus.notConfigured();
}
