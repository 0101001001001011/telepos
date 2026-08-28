import 'package:decimal/decimal.dart';

class ShiftReceipt {
  ShiftReceipt({
    required this.shiftId,
    required this.shiftUserName,
    required this.shiftOpenTime,
    required this.shiftCloseTime,
    required this.saleAmount,
    required this.debtAmount,
    required this.cashInPos,
    required this.cashPaymentsSum,
    required this.paymentSums,
    Decimal? openingCash,
    this.posName,
    this.companyName,
  }) : openingCash = openingCash ?? Decimal.zero;

  final int shiftId;

  final String shiftUserName;

  final int shiftOpenTime;

  final int shiftCloseTime;

  final Decimal saleAmount;

  final Decimal debtAmount;

  final Decimal cashInPos;

  final Decimal openingCash;

  final Decimal cashPaymentsSum;

  final List<PaymentSumEntry> paymentSums;

  final String? posName;

  final String? companyName;
}

class PaymentSumEntry {
  const PaymentSumEntry({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.amount,
  });

  final int accountId;

  final String accountName;

  final int accountType;

  final Decimal amount;
}
