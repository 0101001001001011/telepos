import 'package:decimal/decimal.dart';

abstract class BonusService {
  Future<BonusBalance> getBonusBalance(int phone);

  Future<BonusDeductResult> deductBonuses({
    required int phone,
    required Decimal amount,
    required int saleReceiptNo,
  });

  Future<BonusAccrualResult> accrualBonuses({
    required int phone,
    required Decimal saleAmount,
    required int saleReceiptNo,
  });

  Future<void> cancelTransaction(String transactionId);
}

class BonusBalance {
  const BonusBalance({
    required this.phone,
    required this.balance,
    this.name,
    this.cardNumber,
  });

  final int phone;
  final Decimal balance;
  final String? name;
  final String? cardNumber;
}

class BonusDeductResult {
  const BonusDeductResult({
    required this.success,
    required this.transactionId,
    required this.deductedAmount,
    required this.remainingBalance,
    this.errorMessage,
  });

  final bool success;
  final String transactionId;
  final Decimal deductedAmount;
  final Decimal remainingBalance;
  final String? errorMessage;
}

class BonusAccrualResult {
  const BonusAccrualResult({
    required this.success,
    required this.transactionId,
    required this.accruedAmount,
    required this.newBalance,
    this.errorMessage,
  });

  final bool success;
  final String transactionId;
  final Decimal accruedAmount;
  final Decimal newBalance;
  final String? errorMessage;
}

class NoInternetConnectionException implements Exception {
  const NoInternetConnectionException([
    this.message = 'Нет подключения к интернету',
  ]);

  final String message;

  @override
  String toString() => 'NoInternetConnectionException: $message';
}
