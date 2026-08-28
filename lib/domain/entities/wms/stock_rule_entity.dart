import 'package:decimal/decimal.dart';

class StockRuleEntity {
  const StockRuleEntity({
    this.id,
    this.ucode,
    this.warehouseId,
    this.minStock,
    this.maxStock,
    this.reorderQty,
    this.safetyStock,
    this.avgDailySales,
    this.leadTimeDays,
    this.defaultSupplierId,
    this.autoReorder,
    this.abcClass,
    this.updatedAt,
  });

  final int? id;

  final int? ucode;

  final int? warehouseId;

  final Decimal? minStock;

  final Decimal? maxStock;

  final Decimal? reorderQty;

  final Decimal? safetyStock;

  final Decimal? avgDailySales;

  final int? leadTimeDays;

  final int? defaultSupplierId;

  final bool? autoReorder;

  final String? abcClass;

  final int? updatedAt;

  StockRuleEntity copyWith({
    int? id,
    int? ucode,
    int? warehouseId,
    Decimal? minStock,
    Decimal? maxStock,
    Decimal? reorderQty,
    Decimal? safetyStock,
    Decimal? avgDailySales,
    int? leadTimeDays,
    int? defaultSupplierId,
    bool? autoReorder,
    String? abcClass,
    int? updatedAt,
  }) {
    return StockRuleEntity(
      id: id ?? this.id,
      ucode: ucode ?? this.ucode,
      warehouseId: warehouseId ?? this.warehouseId,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      reorderQty: reorderQty ?? this.reorderQty,
      safetyStock: safetyStock ?? this.safetyStock,
      avgDailySales: avgDailySales ?? this.avgDailySales,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      defaultSupplierId: defaultSupplierId ?? this.defaultSupplierId,
      autoReorder: autoReorder ?? this.autoReorder,
      abcClass: abcClass ?? this.abcClass,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
