class ServiceTypeEntity {
  const ServiceTypeEntity({
    this.id,
    required this.productUcode,
    this.estimatedDurationMinutes,
    this.warrantyDays,
    this.requiresDevice = false,
    this.requiresIntakePhotos = false,
    this.requiresRepairPhotos = false,
    this.requiresQualityCheck = false,
    this.requiresIntakeInventory = false,
    this.isActive = true,
  });

  final int? id;
  final int productUcode;
  final int? estimatedDurationMinutes;
  final int? warrantyDays;
  final bool requiresDevice;

  final bool requiresIntakePhotos;
  final bool requiresRepairPhotos;
  final bool requiresQualityCheck;
  final bool requiresIntakeInventory;
  final bool isActive;

  ServiceTypeEntity copyWith({
    int? id,
    int? productUcode,
    int? estimatedDurationMinutes,
    int? warrantyDays,
    bool? requiresDevice,
    bool? requiresIntakePhotos,
    bool? requiresRepairPhotos,
    bool? requiresQualityCheck,
    bool? requiresIntakeInventory,
    bool? isActive,
  }) {
    return ServiceTypeEntity(
      id: id ?? this.id,
      productUcode: productUcode ?? this.productUcode,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      warrantyDays: warrantyDays ?? this.warrantyDays,
      requiresDevice: requiresDevice ?? this.requiresDevice,
      requiresIntakePhotos: requiresIntakePhotos ?? this.requiresIntakePhotos,
      requiresRepairPhotos: requiresRepairPhotos ?? this.requiresRepairPhotos,
      requiresQualityCheck: requiresQualityCheck ?? this.requiresQualityCheck,
      requiresIntakeInventory:
          requiresIntakeInventory ?? this.requiresIntakeInventory,
      isActive: isActive ?? this.isActive,
    );
  }
}
