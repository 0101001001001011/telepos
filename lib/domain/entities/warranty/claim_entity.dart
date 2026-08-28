import 'package:decimal/decimal.dart';

class ClaimEntity {
  const ClaimEntity({
    this.id,
    this.claimNumber,
    this.claimType,
    this.serialId,
    this.ucode,
    this.batchId,
    this.quantity,
    this.customerId,
    this.supplierId,
    this.operatorId,
    this.problemDescription,
    this.defectType,
    this.severity,
    this.photoIdsJson,
    this.resolutionType,
    this.resolutionNotes,
    this.resolutionDate,
    this.resolvedBy,
    this.supplierClaimNumber,
    this.supplierResponse,
    this.supplierResponseDate,
    this.refundAmount,
    this.repairCost,
    this.createdAt,
    this.deadline,
    this.updatedAt,
    this.status,
    this.state,
  });

  final int? id;

  final String? claimNumber;

  final int? claimType;

  final int? serialId;

  final int? ucode;

  final int? batchId;

  final Decimal? quantity;

  final int? customerId;

  final int? supplierId;

  final int? operatorId;

  final String? problemDescription;

  final int? defectType;

  final int? severity;

  final String? photoIdsJson;

  final int? resolutionType;

  final String? resolutionNotes;

  final int? resolutionDate;

  final int? resolvedBy;

  final String? supplierClaimNumber;

  final String? supplierResponse;

  final int? supplierResponseDate;

  final Decimal? refundAmount;

  final Decimal? repairCost;

  final int? createdAt;

  final int? deadline;

  final int? updatedAt;

  final int? status;

  final int? state;

  bool get isOpen => status == 0;

  bool get isOverdue {
    if (deadline == null) return false;
    if (!isOpen) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return deadline! < now;
  }

  ClaimEntity copyWith({
    int? id,
    String? claimNumber,
    int? claimType,
    int? serialId,
    int? ucode,
    int? batchId,
    Decimal? quantity,
    int? customerId,
    int? supplierId,
    int? operatorId,
    String? problemDescription,
    int? defectType,
    int? severity,
    String? photoIdsJson,
    int? resolutionType,
    String? resolutionNotes,
    int? resolutionDate,
    int? resolvedBy,
    String? supplierClaimNumber,
    String? supplierResponse,
    int? supplierResponseDate,
    Decimal? refundAmount,
    Decimal? repairCost,
    int? createdAt,
    int? deadline,
    int? updatedAt,
    int? status,
    int? state,
  }) {
    return ClaimEntity(
      id: id ?? this.id,
      claimNumber: claimNumber ?? this.claimNumber,
      claimType: claimType ?? this.claimType,
      serialId: serialId ?? this.serialId,
      ucode: ucode ?? this.ucode,
      batchId: batchId ?? this.batchId,
      quantity: quantity ?? this.quantity,
      customerId: customerId ?? this.customerId,
      supplierId: supplierId ?? this.supplierId,
      operatorId: operatorId ?? this.operatorId,
      problemDescription: problemDescription ?? this.problemDescription,
      defectType: defectType ?? this.defectType,
      severity: severity ?? this.severity,
      photoIdsJson: photoIdsJson ?? this.photoIdsJson,
      resolutionType: resolutionType ?? this.resolutionType,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      resolutionDate: resolutionDate ?? this.resolutionDate,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      supplierClaimNumber: supplierClaimNumber ?? this.supplierClaimNumber,
      supplierResponse: supplierResponse ?? this.supplierResponse,
      supplierResponseDate: supplierResponseDate ?? this.supplierResponseDate,
      refundAmount: refundAmount ?? this.refundAmount,
      repairCost: repairCost ?? this.repairCost,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      state: state ?? this.state,
    );
  }
}
