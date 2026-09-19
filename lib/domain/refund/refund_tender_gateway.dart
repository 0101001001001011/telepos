import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Возврат денег через **внешнюю систему** — эквайринг и провайдера QR.
///
/// Чистый Dart. Реализация кассы — `LocalRefundTenderGateway`
/// (`lib/data/refund`): терминал Kaspi по сокету и провайдер QR по HTTP.
///
/// # Отказ приходит значением
///
/// Ни один метод не бросает наружу: связь с банком отказывает обычно, а не
/// исключительно, и возврат обязан назвать причину кассиру, а не упасть.
///
/// # Ключ возврата
///
/// [refundKey] придуман кассой и **повторяется** при повторе того же
/// возврата. Внешняя сторона по нему отдаёт прежний ответ, а не возвращает
/// деньги второй раз: касса, не дождавшаяся ответа, не знает, прошёл ли
/// возврат, и повтор обязан быть безопасным.
abstract interface class RefundTenderGateway {
  /// Вернуть [amount] на карту по транзакции [transactionId] через
  /// платёжный терминал рабочего места [terminalId].
  Future<TenderReturn> returnCard({
    required int? terminalId,
    required String transactionId,
    required Decimal amount,
    required String refundKey,
  });

  /// Вернуть [amount] по намерению провайдера QR [providerIntentId].
  Future<TenderReturn> returnQr({
    required String providerIntentId,
    required Decimal amount,
    required String refundKey,
  });
}

/// Исход возврата через внешнюю систему.
@immutable
class TenderReturn {
  const TenderReturn.done({this.transactionId, this.approvalCode})
    : code = null,
      message = null;

  const TenderReturn.refused(String this.code, String this.message)
    : transactionId = null,
      approvalCode = null;

  /// Код отказа — `refundCashlessUnavailableCode` или
  /// `refundCashlessRefusedCode` (`refund_service.dart`). `null` — прошло.
  final String? code;

  /// Причина словами, без текста исключения (I144).
  final String? message;

  /// Номер операции возврата на внешней стороне.
  final String? transactionId;
  final String? approvalCode;

  bool get ok => code == null;

  @override
  String toString() => ok ? 'TenderReturn.done($transactionId)' : 'TenderReturn($code)';
}
