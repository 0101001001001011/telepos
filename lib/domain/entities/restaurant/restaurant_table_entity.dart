import 'package:telepos/core/constants/enums/table_status.dart';

class RestaurantTableEntity {
  const RestaurantTableEntity({
    required this.id,
    required this.name,
    this.capacity = 4,
    this.status = TableStatus.free,
    this.zone,
    this.positionX,
    this.positionY,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final int capacity;
  final TableStatus status;
  final String? zone;
  final double? positionX;
  final double? positionY;
  final bool isActive;
  final int sortOrder;

  bool get isFree => status == TableStatus.free;
  bool get isOccupied => status == TableStatus.occupied;
  bool get isReserved => status == TableStatus.reserved;
  bool get isDirty => status == TableStatus.dirty;

  RestaurantTableEntity copyWith({
    int? id,
    String? name,
    int? capacity,
    TableStatus? status,
    String? zone,
    double? positionX,
    double? positionY,
    bool? isActive,
    int? sortOrder,
  }) {
    return RestaurantTableEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      zone: zone ?? this.zone,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
