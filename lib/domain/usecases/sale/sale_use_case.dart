import 'package:decimal/decimal.dart';

abstract class SaleUseCase {
  Future<void> perform({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required List<PaymentEntry> payments,
    required Decimal change,
    required bool selectiveOfd,
    String? customerBin,
    int? agentLocalId,
    int? agentServerId,
    List<CustomFieldEntry>? customFields,
    WithdrawalEntry? withdrawal,
  });

  Future<void> reverseSaleStock({required int receiptNo, required int posId});
}

class PaymentEntry {
  const PaymentEntry({
    required this.payeeAccountId,
    required this.amount,
    this.customerLocalId,
    this.approvalCode,
    this.cardMask,
    this.terminalTransactionId,
  });

  final int payeeAccountId;

  final Decimal amount;

  final int? customerLocalId;

  final String? approvalCode;

  final String? cardMask;

  final String? terminalTransactionId;
}

class CustomFieldEntry {
  const CustomFieldEntry({
    required this.customFieldId,
    required this.customFieldItemId,
  });

  final int customFieldId;

  final int customFieldItemId;
}

class WithdrawalEntry {
  const WithdrawalEntry({required this.agentAccountId, required this.amount});

  final int agentAccountId;

  final Decimal amount;
}
