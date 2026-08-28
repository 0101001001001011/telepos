import 'package:decimal/decimal.dart';

abstract class PaymentController {
  PaymentState createSession({
    required Decimal saleAmount,
    bool isDebtAllowed = false,
    bool hasBonusPayment = false,
  });

  PaymentResult addPayment({
    required PaymentState state,
    required int accountId,
    required Decimal amount,
    required bool isCashless,
  });

  PaymentState removePayment({required PaymentState state, required int index});

  PaymentState clearPayments(PaymentState state);

  PaymentValidation validate(PaymentState state);

  Decimal calculateChange(PaymentState state, Decimal cashAmount);

  PaymentType getPaymentType(PaymentState state);
}

class PaymentState {
  const PaymentState({
    required this.saleAmount,
    this.isDebtAllowed = false,
    this.hasBonusPayment = false,
    this.payments = const [],
  });

  final Decimal saleAmount;

  final bool isDebtAllowed;

  final bool hasBonusPayment;

  final List<PaymentEntry> payments;

  Decimal get received =>
      payments.fold(Decimal.zero, (sum, p) => sum + p.amount);

  Decimal get cashReceived => payments
      .where((p) => !p.isCashless)
      .fold(Decimal.zero, (sum, p) => sum + p.amount);

  Decimal get cashlessReceived => payments
      .where((p) => p.isCashless)
      .fold(Decimal.zero, (sum, p) => sum + p.amount);

  Decimal get remaining {
    final diff = saleAmount - received;
    return diff > Decimal.zero ? diff : Decimal.zero;
  }

  Decimal get debt => isDebtAllowed ? remaining : Decimal.zero;

  bool get hasOverpayment => received > saleAmount;

  Decimal get overpayment {
    if (!hasOverpayment) return Decimal.zero;
    final cashOver = cashReceived - (saleAmount - cashlessReceived);
    return cashOver > Decimal.zero ? cashOver : Decimal.zero;
  }

  PaymentState copyWith({
    Decimal? saleAmount,
    bool? isDebtAllowed,
    bool? hasBonusPayment,
    List<PaymentEntry>? payments,
  }) {
    return PaymentState(
      saleAmount: saleAmount ?? this.saleAmount,
      isDebtAllowed: isDebtAllowed ?? this.isDebtAllowed,
      hasBonusPayment: hasBonusPayment ?? this.hasBonusPayment,
      payments: payments ?? this.payments,
    );
  }
}

class PaymentEntry {
  const PaymentEntry({
    required this.accountId,
    required this.amount,
    required this.isCashless,
    this.time,
  });

  final int accountId;

  final Decimal amount;

  final bool isCashless;

  final int? time;
}

class PaymentResult {
  const PaymentResult._({this.state, this.error});

  factory PaymentResult.success(PaymentState state) =>
      PaymentResult._(state: state);

  factory PaymentResult.failure(PaymentError error) =>
      PaymentResult._(error: error);

  final PaymentState? state;
  final PaymentError? error;

  bool get isSuccess => state != null;
}

enum PaymentError {
  invalidAmount,

  cashlessOverpayment,

  bonusWithDebt,

  cashlessLimitExceeded,
}

enum PaymentType { cash, cashless, mixed, none }

class PaymentValidation {
  const PaymentValidation({
    required this.isValid,
    this.error,
    this.isDebt = false,
  });

  final bool isValid;
  final PaymentValidationError? error;

  final bool isDebt;
}

enum PaymentValidationError { noPayments, insufficientFunds, bonusWithDebt }
