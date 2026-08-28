class ProductComponentEntity {
  const ProductComponentEntity({
    this.id,
    this.parentSerialId,
    this.componentSerialId,
    this.componentName,
    this.componentSn,
    this.warrantyMonths,
    this.warrantyEnd,
    this.notes,
  });

  final int? id;

  final int? parentSerialId;

  final int? componentSerialId;

  final String? componentName;

  final String? componentSn;

  final int? warrantyMonths;

  final int? warrantyEnd;

  final String? notes;

  bool get isWarrantyExpired {
    if (warrantyEnd == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return warrantyEnd! < now;
  }

  ProductComponentEntity copyWith({
    int? id,
    int? parentSerialId,
    int? componentSerialId,
    String? componentName,
    String? componentSn,
    int? warrantyMonths,
    int? warrantyEnd,
    String? notes,
  }) {
    return ProductComponentEntity(
      id: id ?? this.id,
      parentSerialId: parentSerialId ?? this.parentSerialId,
      componentSerialId: componentSerialId ?? this.componentSerialId,
      componentName: componentName ?? this.componentName,
      componentSn: componentSn ?? this.componentSn,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      warrantyEnd: warrantyEnd ?? this.warrantyEnd,
      notes: notes ?? this.notes,
    );
  }
}
