import 'package:decimal/decimal.dart';

abstract class PaymentSequences {
  List<PaymentWithType> sortForRefund(List<PaymentWithType> payments);

  Map<AccountType, List<PaymentWithType>> groupByType(
    List<PaymentWithType> payments,
  );

  int getPriority(AccountType type);

  Map<AccountType, Decimal> sumByType(List<PaymentWithType> payments);
}

enum AccountType { cash, bank, custom }

class PaymentWithType {
  const PaymentWithType({
    required this.paymentId,
    required this.accountId,
    required this.accountType,
    required this.amount,
    this.time,
  });

  final int paymentId;
  final int accountId;
  final AccountType accountType;
  final Decimal amount;
  final int? time;

  factory PaymentWithType.fromRawType({
    required int paymentId,
    required int accountId,
    required int rawAccountType,
    required Decimal amount,
    int? time,
  }) {
    final accountType = _parseAccountType(rawAccountType);
    return PaymentWithType(
      paymentId: paymentId,
      accountId: accountId,
      accountType: accountType,
      amount: amount,
      time: time,
    );
  }

  static AccountType _parseAccountType(int rawType) {
    switch (rawType) {
      case 0:
        return AccountType.cash;
      case 1:
        return AccountType.bank;
      default:
        return AccountType.custom;
    }
  }
}

extension AccountTypeExtension on AccountType {
  int get refundPriority {
    switch (this) {
      case AccountType.cash:
        return 0;
      case AccountType.bank:
        return 1;
      case AccountType.custom:
        return 2;
    }
  }

  int get rawValue {
    switch (this) {
      case AccountType.cash:
        return 0;
      case AccountType.bank:
        return 1;
      case AccountType.custom:
        return 2;
    }
  }
}
