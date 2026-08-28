import 'package:decimal/decimal.dart';

class WarehouseCellEntity {
  const WarehouseCellEntity({
    this.id,
    this.zoneId,
    this.address,
    this.rowCode,
    this.rackCode,
    this.levelCode,
    this.binCode,
    this.barcode,
    this.maxWeight,
    this.maxVolume,
    this.maxItems,
    this.isActive,
    this.isBlocked,
    this.notes,
  });

  final int? id;

  final int? zoneId;

  final String? address;

  final String? rowCode;

  final String? rackCode;

  final String? levelCode;

  final String? binCode;

  final String? barcode;

  final Decimal? maxWeight;

  final Decimal? maxVolume;

  final int? maxItems;

  final bool? isActive;

  final bool? isBlocked;

  final String? notes;

  WarehouseCellEntity copyWith({
    int? id,
    int? zoneId,
    String? address,
    String? rowCode,
    String? rackCode,
    String? levelCode,
    String? binCode,
    String? barcode,
    Decimal? maxWeight,
    Decimal? maxVolume,
    int? maxItems,
    bool? isActive,
    bool? isBlocked,
    String? notes,
  }) {
    return WarehouseCellEntity(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      address: address ?? this.address,
      rowCode: rowCode ?? this.rowCode,
      rackCode: rackCode ?? this.rackCode,
      levelCode: levelCode ?? this.levelCode,
      binCode: binCode ?? this.binCode,
      barcode: barcode ?? this.barcode,
      maxWeight: maxWeight ?? this.maxWeight,
      maxVolume: maxVolume ?? this.maxVolume,
      maxItems: maxItems ?? this.maxItems,
      isActive: isActive ?? this.isActive,
      isBlocked: isBlocked ?? this.isBlocked,
      notes: notes ?? this.notes,
    );
  }
}
