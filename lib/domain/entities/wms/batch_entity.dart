import 'package:decimal/decimal.dart';

class BatchEntity {
  const BatchEntity({
    this.id,
    this.ucode,
    this.batchNumber,
    this.productionDate,
    this.expiryDate,
    this.supplierId,
    this.supplierBatchNo,
    this.supplyId,
    this.receivedDate,
    this.receivedBy,
    this.initialQuantity,
    this.currentQuantity,
    this.reservedQuantity,
    this.unitCost,
    this.qualityStatus,
    this.qualityCheckDate,
    this.qualityNotes,
    this.certificateNumber,
    this.storageConditions,
    this.cellId,
    this.markingCodesJson,
    this.isActive,
    this.isQuarantined,
    this.notes,
    this.state,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  final int? ucode;

  final String? batchNumber;

  final int? productionDate;

  final int? expiryDate;

  final int? supplierId;

  final String? supplierBatchNo;

  final int? supplyId;

  final int? receivedDate;

  final int? receivedBy;

  final Decimal? initialQuantity;

  final Decimal? currentQuantity;

  final Decimal? reservedQuantity;

  final Decimal? unitCost;

  final int? qualityStatus;

  final int? qualityCheckDate;

  final String? qualityNotes;

  final String? certificateNumber;

  final String? storageConditions;

  final int? cellId;

  final String? markingCodesJson;

  final bool? isActive;

  final bool? isQuarantined;

  final String? notes;

  final int? state;

  final int? createdAt;

  final int? updatedAt;

  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiryDate! < now;
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiryDate! < (now + 30 * 86400);
  }

  Decimal get availableQuantity =>
      (currentQuantity ?? Decimal.zero) - (reservedQuantity ?? Decimal.zero);

  BatchEntity copyWith({
    int? id,
    int? ucode,
    String? batchNumber,
    int? productionDate,
    int? expiryDate,
    int? supplierId,
    String? supplierBatchNo,
    int? supplyId,
    int? receivedDate,
    int? receivedBy,
    Decimal? initialQuantity,
    Decimal? currentQuantity,
    Decimal? reservedQuantity,
    Decimal? unitCost,
    int? qualityStatus,
    int? qualityCheckDate,
    String? qualityNotes,
    String? certificateNumber,
    String? storageConditions,
    int? cellId,
    String? markingCodesJson,
    bool? isActive,
    bool? isQuarantined,
    String? notes,
    int? state,
    int? createdAt,
    int? updatedAt,
  }) {
    return BatchEntity(
      id: id ?? this.id,
      ucode: ucode ?? this.ucode,
      batchNumber: batchNumber ?? this.batchNumber,
      productionDate: productionDate ?? this.productionDate,
      expiryDate: expiryDate ?? this.expiryDate,
      supplierId: supplierId ?? this.supplierId,
      supplierBatchNo: supplierBatchNo ?? this.supplierBatchNo,
      supplyId: supplyId ?? this.supplyId,
      receivedDate: receivedDate ?? this.receivedDate,
      receivedBy: receivedBy ?? this.receivedBy,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      unitCost: unitCost ?? this.unitCost,
      qualityStatus: qualityStatus ?? this.qualityStatus,
      qualityCheckDate: qualityCheckDate ?? this.qualityCheckDate,
      qualityNotes: qualityNotes ?? this.qualityNotes,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      storageConditions: storageConditions ?? this.storageConditions,
      cellId: cellId ?? this.cellId,
      markingCodesJson: markingCodesJson ?? this.markingCodesJson,
      isActive: isActive ?? this.isActive,
      isQuarantined: isQuarantined ?? this.isQuarantined,
      notes: notes ?? this.notes,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
