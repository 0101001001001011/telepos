import 'package:decimal/decimal.dart';

class SerialEntity {
  const SerialEntity({
    this.id,
    this.ucode,
    this.serialNumber,
    this.type,
    this.batchId,
    this.cellId,
    this.status,
    this.receivedAt,
    this.receivedBy,
    this.supplierId,
    this.supplyId,
    this.purchasePrice,
    this.soldAt,
    this.soldBy,
    this.saleId,
    this.salePrice,
    this.customerId,
    this.warrantyStart,
    this.warrantyEnd,
    this.warrantyMonths,
    this.markingCode,
    this.condition,
    this.notes,
    this.state,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  final int? ucode;

  final String? serialNumber;

  final int? type;

  final int? batchId;

  final int? cellId;

  final int? status;

  final int? receivedAt;

  final int? receivedBy;

  final int? supplierId;

  final int? supplyId;

  final Decimal? purchasePrice;

  final int? soldAt;

  final int? soldBy;

  final int? saleId;

  final Decimal? salePrice;

  final int? customerId;

  final int? warrantyStart;

  final int? warrantyEnd;

  final int? warrantyMonths;

  final String? markingCode;

  final String? condition;

  final String? notes;

  final int? state;

  final int? createdAt;

  final int? updatedAt;

  bool get isAvailable => status == 0;

  bool get hasWarranty => warrantyEnd != null;

  bool get isWarrantyExpired {
    if (warrantyEnd == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return warrantyEnd! < now;
  }

  SerialEntity copyWith({
    int? id,
    int? ucode,
    String? serialNumber,
    int? type,
    int? batchId,
    int? cellId,
    int? status,
    int? receivedAt,
    int? receivedBy,
    int? supplierId,
    int? supplyId,
    Decimal? purchasePrice,
    int? soldAt,
    int? soldBy,
    int? saleId,
    Decimal? salePrice,
    int? customerId,
    int? warrantyStart,
    int? warrantyEnd,
    int? warrantyMonths,
    String? markingCode,
    String? condition,
    String? notes,
    int? state,
    int? createdAt,
    int? updatedAt,
  }) {
    return SerialEntity(
      id: id ?? this.id,
      ucode: ucode ?? this.ucode,
      serialNumber: serialNumber ?? this.serialNumber,
      type: type ?? this.type,
      batchId: batchId ?? this.batchId,
      cellId: cellId ?? this.cellId,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedBy: receivedBy ?? this.receivedBy,
      supplierId: supplierId ?? this.supplierId,
      supplyId: supplyId ?? this.supplyId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      soldAt: soldAt ?? this.soldAt,
      soldBy: soldBy ?? this.soldBy,
      saleId: saleId ?? this.saleId,
      salePrice: salePrice ?? this.salePrice,
      customerId: customerId ?? this.customerId,
      warrantyStart: warrantyStart ?? this.warrantyStart,
      warrantyEnd: warrantyEnd ?? this.warrantyEnd,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      markingCode: markingCode ?? this.markingCode,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
