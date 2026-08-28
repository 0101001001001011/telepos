import 'package:decimal/decimal.dart';

abstract class DebtUseCase {
  Decimal calculate({
    required Decimal totalAmount,
    required List<Decimal> payments,
  });

  Decimal calculateFromSum({
    required Decimal totalAmount,
    required Decimal paymentsSum,
  });

  bool hasDebt({required Decimal totalAmount, required Decimal paymentsSum});
}
