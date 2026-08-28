import 'package:decimal/decimal.dart';

abstract class CalculateServiceChargeUseCase {
  Future<Decimal> calculate(Decimal subtotal);

  Future<void> applyToSale(int receiptNo, int posId);
}
