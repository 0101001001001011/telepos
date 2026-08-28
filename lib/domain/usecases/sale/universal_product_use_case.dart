import 'package:decimal/decimal.dart';

abstract class UniversalProductUseCase {
  static const int universalUcode = 2999999999991;

  static const String universalName = 'Универсальный продукт';

  Future<void> ensureProductExists();

  Future<void> createForSale({
    required int receiptNo,
    required int posId,
    required Decimal priceBefore,
  });

  Future<void> createForRefundFromSale({
    required int refundLocalId,
    required Decimal originalPrice,
    required Decimal originalQuantity,
  });

  Future<void> createForRefundCustom({
    required int refundLocalId,
    required Decimal price,
  });
}
