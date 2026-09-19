import 'package:decimal/decimal.dart';

abstract class RefundUseCase {
  Future<RefundResult> perform({
    required int refundLocalId,
    required Decimal amount,
    Decimal? cashbackAmount,
    required int userId,
    int? saleReceiptNo,
    int? salePosId,
    int? customerLocalId,
    int? customerServerId,
    required List<RefundProductEntry> products,

    /// Рабочее место, откуда пришла команда: карта возвращается через **его**
    /// платёжный терминал (задача 26). `null` — привязку спросить не у кого,
    /// и возврат на карту через терминал получит названный отказ.
    int? terminalId,
  });
}

class RefundProductEntry {
  const RefundProductEntry({
    required this.ucode,
    required this.quantity,
    required this.price,
    this.inSalePrice,
    this.inSaleQuantity,
    this.inSalePriceBefore,
  });

  final int ucode;

  final Decimal quantity;

  final Decimal price;

  final Decimal? inSalePrice;

  final Decimal? inSaleQuantity;

  final Decimal? inSalePriceBefore;
}

class RefundResult {
  const RefundResult({
    required this.refundLocalId,
    required this.amount,
    required this.productCount,
    required this.paymentCount,
    required this.drawerAmount,
  });

  final int refundLocalId;

  final Decimal amount;

  final int productCount;

  final int paymentCount;

  /// Сколько **вышло из денежного ящика** — сумма частей раскладки с
  /// маршрутом `RefundRoute.drawer`. Ноль — возврат целиком ушёл на
  /// сертификат, аванс, бонус, карту или QR, и ящик открывать незачем.
  ///
  /// # Зачем это число, найденное живой приёмкой 2026-09-17
  ///
  /// Возврат чека «сертификат 3000 + наличные 200» называл кассиру маршрут
  /// «Наличными из ящика — 200», проводил фискальный возврат с наличными 200
  /// и печатал документ — а **ящик не открывался**: ни один путь возврата
  /// его не звал. У продажи ящик открывается по наличной части оплаты
  /// (`LocalPaymentService._dispatchHardware`), у возврата вопрос «была ли
  /// наличная часть» задать было некому: раскладку знал только юзкейс, а
  /// наружу уходили сумма и счётчики.
  ///
  /// **Обязательное, а не со значением по умолчанию**: умолчание «ноль»
  /// значило бы «ящик не нужен» у любой реализации, забывшей его посчитать,
  /// — ровно тот путь, которым дефект и родился.
  final Decimal drawerAmount;
}

class InvalidRefundException implements Exception {
  const InvalidRefundException(this.message);
  final String message;

  @override
  String toString() => 'InvalidRefundException: $message';
}
