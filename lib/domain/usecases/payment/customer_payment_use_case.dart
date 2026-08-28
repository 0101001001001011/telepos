import 'package:decimal/decimal.dart';

abstract class CustomerPaymentUseCase {
  Future<CustomerPaymentResult> execute({
    required int agentId,
    required Decimal amount,
    required CustomerPaymentDecision decision,
    String? note,
  });

  Future<bool> needsDecisionDialog(int agentId);

  Future<Decimal> getCustomerBalance(int agentId);
}

enum CustomerPaymentDecision { investment, deposit }

class CustomerPaymentResult {
  const CustomerPaymentResult({
    required this.success,
    this.transactionId,
    this.newBalance,
    this.errorMessage,
  });

  final bool success;
  final int? transactionId;
  final Decimal? newBalance;
  final String? errorMessage;

  factory CustomerPaymentResult.created({
    required int transactionId,
    required Decimal newBalance,
  }) => CustomerPaymentResult(
    success: true,
    transactionId: transactionId,
    newBalance: newBalance,
  );

  factory CustomerPaymentResult.failed(String message) =>
      CustomerPaymentResult(success: false, errorMessage: message);
}

extension CustomerPaymentDecisionExtension on CustomerPaymentDecision {
  String get displayName {
    switch (this) {
      case CustomerPaymentDecision.investment:
        return 'Вложение';
      case CustomerPaymentDecision.deposit:
        return 'Депозит';
    }
  }

  String get description {
    switch (this) {
      case CustomerPaymentDecision.investment:
        return 'Пополнение основного счёта покупателя';
      case CustomerPaymentDecision.deposit:
        return 'Авансовый платёж на депозитный счёт';
    }
  }
}
