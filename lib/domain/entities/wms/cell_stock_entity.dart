import 'package:decimal/decimal.dart';

class CellStockEntity {
  const CellStockEntity({
    this.id,
    this.cellId,
    this.ucode,
    this.batchId,
    this.serialId,
    this.quantity,
    this.reservedQty,
    this.updatedAt,
  });

  final int? id;

  final int? cellId;

  final int? ucode;

  final int? batchId;

  final int? serialId;

  final Decimal? quantity;

  final Decimal? reservedQty;

  final int? updatedAt;

  Decimal get availableQty =>
      (quantity ?? Decimal.zero) - (reservedQty ?? Decimal.zero);

  CellStockEntity copyWith({
    int? id,
    int? cellId,
    int? ucode,
    int? batchId,
    int? serialId,
    Decimal? quantity,
    Decimal? reservedQty,
    int? updatedAt,
  }) {
    return CellStockEntity(
      id: id ?? this.id,
      cellId: cellId ?? this.cellId,
      ucode: ucode ?? this.ucode,
      batchId: batchId ?? this.batchId,
      serialId: serialId ?? this.serialId,
      quantity: quantity ?? this.quantity,
      reservedQty: reservedQty ?? this.reservedQty,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
