import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/payment/debt_use_case.dart';

class DebtUseCaseImpl implements DebtUseCase {
  @override
  Decimal calculate({
    required Decimal totalAmount,
    required List<Decimal> payments,
  }) {
    final paymentsSum = payments.fold<Decimal>(
      Decimal.zero,
      (sum, p) => sum + p.abs(),
    );

    return calculateFromSum(totalAmount: totalAmount, paymentsSum: paymentsSum);
  }

  @override
  Decimal calculateFromSum({
    required Decimal totalAmount,
    required Decimal paymentsSum,
  }) {
    final debt = totalAmount - paymentsSum.abs();
    return debt > Decimal.zero ? debt : Decimal.zero;
  }

  @override
  bool hasDebt({required Decimal totalAmount, required Decimal paymentsSum}) {
    return calculateFromSum(
          totalAmount: totalAmount,
          paymentsSum: paymentsSum,
        ) >
        Decimal.zero;
  }
}
