import 'package:decimal/decimal.dart';

class WarehouseZoneEntity {
  const WarehouseZoneEntity({
    this.id,
    this.warehouseId,
    this.code,
    this.name,
    this.type,
    this.storageType,
    this.temperatureMin,
    this.temperatureMax,
    this.isActive,
  });

  final int? id;

  final int? warehouseId;

  final String? code;

  final String? name;

  final int? type;

  final int? storageType;

  final Decimal? temperatureMin;

  final Decimal? temperatureMax;

  final bool? isActive;

  bool get isTemperatureControlled =>
      temperatureMin != null || temperatureMax != null;

  WarehouseZoneEntity copyWith({
    int? id,
    int? warehouseId,
    String? code,
    String? name,
    int? type,
    int? storageType,
    Decimal? temperatureMin,
    Decimal? temperatureMax,
    bool? isActive,
  }) {
    return WarehouseZoneEntity(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      storageType: storageType ?? this.storageType,
      temperatureMin: temperatureMin ?? this.temperatureMin,
      temperatureMax: temperatureMax ?? this.temperatureMax,
      isActive: isActive ?? this.isActive,
    );
  }
}
