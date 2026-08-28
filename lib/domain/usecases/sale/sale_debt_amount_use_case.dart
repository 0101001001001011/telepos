import 'package:decimal/decimal.dart';

abstract class SaleDebtAmountUseCase {
  Decimal calculate({
    required Decimal saleAmount,
    required List<Decimal> paymentAmounts,
    required Decimal withdrawalAmount,
  });
}
