class MarkingCodeEntity {
  const MarkingCodeEntity({
    this.id,
    this.ucode,
    this.code,
    this.gtin,
    this.serial,
    this.batch,
    this.expiry,
    this.checksum,
    this.status,
    this.parentCodeId,
    this.aggregationLevel,
    this.supplyId,
    this.saleId,
    this.cellId,
    this.state,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  final int? ucode;

  final String? code;

  final String? gtin;

  final String? serial;

  final String? batch;

  final String? expiry;

  final String? checksum;

  final int? status;

  final int? parentCodeId;

  final int? aggregationLevel;

  final int? supplyId;

  final int? saleId;

  final int? cellId;

  final int? state;

  final int? createdAt;

  final int? updatedAt;

  bool get isUnit => aggregationLevel == 0;

  bool get isBox => aggregationLevel == 1;

  bool get isPallet => aggregationLevel == 2;

  MarkingCodeEntity copyWith({
    int? id,
    int? ucode,
    String? code,
    String? gtin,
    String? serial,
    String? batch,
    String? expiry,
    String? checksum,
    int? status,
    int? parentCodeId,
    int? aggregationLevel,
    int? supplyId,
    int? saleId,
    int? cellId,
    int? state,
    int? createdAt,
    int? updatedAt,
  }) {
    return MarkingCodeEntity(
      id: id ?? this.id,
      ucode: ucode ?? this.ucode,
      code: code ?? this.code,
      gtin: gtin ?? this.gtin,
      serial: serial ?? this.serial,
      batch: batch ?? this.batch,
      expiry: expiry ?? this.expiry,
      checksum: checksum ?? this.checksum,
      status: status ?? this.status,
      parentCodeId: parentCodeId ?? this.parentCodeId,
      aggregationLevel: aggregationLevel ?? this.aggregationLevel,
      supplyId: supplyId ?? this.supplyId,
      saleId: saleId ?? this.saleId,
      cellId: cellId ?? this.cellId,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
