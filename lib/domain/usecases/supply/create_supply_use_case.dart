import 'package:decimal/decimal.dart';

abstract class CreateSupplyUseCase {
  Future<CreateSupplyResult> execute({
    required int userId,
    required int supplierId,
    required SupplyPaymentType paymentType,
    int? accountId,
    String? comment,
  });

  Future<SupplyDraft?> getDraft();

  Future<void> deleteDraft(int supplyId);
}

enum SupplyPaymentType { fullSupply, consignment }

class CreateSupplyResult {
  const CreateSupplyResult({
    required this.supplyId,
    required this.success,
    this.errorMessage,
  });

  final int supplyId;
  final bool success;
  final String? errorMessage;

  factory CreateSupplyResult.created(int id) =>
      CreateSupplyResult(supplyId: id, success: true);

  factory CreateSupplyResult.failed(String message) =>
      CreateSupplyResult(supplyId: -1, success: false, errorMessage: message);
}

class SupplyDraft {
  const SupplyDraft({
    required this.id,
    required this.supplierId,
    required this.paymentType,
    this.accountId,
    this.comment,
    required this.amount,
    required this.editTime,
  });

  final int id;
  final int supplierId;
  final SupplyPaymentType paymentType;
  final int? accountId;
  final String? comment;
  final Decimal amount;
  final DateTime editTime;
}
