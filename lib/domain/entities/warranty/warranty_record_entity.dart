class WarrantyRecordEntity {
  const WarrantyRecordEntity({
    this.id,
    this.serialId,
    this.ucode,
    this.warrantyStart,
    this.warrantyEnd,
    this.warrantyMonths,
    this.warrantyType,
    this.source,
    this.saleId,
    this.supplyId,
    this.customerId,
    this.supplierId,
    this.status,
    this.notes,
    this.state,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  final int? serialId;

  final int? ucode;

  final int? warrantyStart;

  final int? warrantyEnd;

  final int? warrantyMonths;

  final int? warrantyType;

  final int? source;

  final int? saleId;

  final int? supplyId;

  final int? customerId;

  final int? supplierId;

  final int? status;

  final String? notes;

  final int? state;

  final int? createdAt;

  final int? updatedAt;

  bool get isExpired {
    if (warrantyEnd == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return warrantyEnd! < now;
  }

  int? get remainingDays {
    if (warrantyEnd == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = warrantyEnd! - now;
    if (diff <= 0) return 0;
    return diff ~/ 86400;
  }

  WarrantyRecordEntity copyWith({
    int? id,
    int? serialId,
    int? ucode,
    int? warrantyStart,
    int? warrantyEnd,
    int? warrantyMonths,
    int? warrantyType,
    int? source,
    int? saleId,
    int? supplyId,
    int? customerId,
    int? supplierId,
    int? status,
    String? notes,
    int? state,
    int? createdAt,
    int? updatedAt,
  }) {
    return WarrantyRecordEntity(
      id: id ?? this.id,
      serialId: serialId ?? this.serialId,
      ucode: ucode ?? this.ucode,
      warrantyStart: warrantyStart ?? this.warrantyStart,
      warrantyEnd: warrantyEnd ?? this.warrantyEnd,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      warrantyType: warrantyType ?? this.warrantyType,
      source: source ?? this.source,
      saleId: saleId ?? this.saleId,
      supplyId: supplyId ?? this.supplyId,
      customerId: customerId ?? this.customerId,
      supplierId: supplierId ?? this.supplierId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
