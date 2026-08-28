import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/payment/payment_sequences.dart';

class PaymentSequencesImpl implements PaymentSequences {
  @override
  List<PaymentWithType> sortForRefund(List<PaymentWithType> payments) {
    final sorted = List<PaymentWithType>.from(payments);
    sorted.sort(
      (a, b) =>
          a.accountType.refundPriority.compareTo(b.accountType.refundPriority),
    );
    return sorted;
  }

  @override
  Map<AccountType, List<PaymentWithType>> groupByType(
    List<PaymentWithType> payments,
  ) {
    final result = <AccountType, List<PaymentWithType>>{};

    for (final payment in payments) {
      result.putIfAbsent(payment.accountType, () => []);
      result[payment.accountType]!.add(payment);
    }

    return result;
  }

  @override
  int getPriority(AccountType type) {
    return type.refundPriority;
  }

  @override
  Map<AccountType, Decimal> sumByType(List<PaymentWithType> payments) {
    final result = <AccountType, Decimal>{};

    for (final payment in payments) {
      result.update(
        payment.accountType,
        (sum) => sum + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }

    return result;
  }
}
