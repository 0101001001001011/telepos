import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/sale/sale_debt_amount_use_case.dart';

class SaleDebtAmountUseCaseImpl implements SaleDebtAmountUseCase {
  @override
  Decimal calculate({
    required Decimal saleAmount,
    required List<Decimal> paymentAmounts,
    required Decimal withdrawalAmount,
  }) {
    final paymentsSum = paymentAmounts.fold<Decimal>(
      Decimal.zero,
      (sum, amount) => sum + amount,
    );

    final debt = saleAmount - (paymentsSum + withdrawalAmount);

    if (debt < Decimal.zero) {
      throw StateError(
        'Payments sum is bigger than Sale amount: '
        'sale=$saleAmount, payments=$paymentsSum, withdrawal=$withdrawalAmount',
      );
    }

    return debt;
  }
}
