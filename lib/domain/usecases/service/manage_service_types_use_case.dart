import 'package:telepos/domain/entities/service/service_type_entity.dart';

abstract class ManageServiceTypesUseCase {
  Future<List<ServiceTypeEntity>> getActive();

  Future<ServiceTypeEntity> create({
    required int productUcode,
    int? estimatedDurationMinutes,
    int? warrantyDays,
    bool requiresDevice,
    bool requiresIntakePhotos,
    bool requiresRepairPhotos,
    bool requiresQualityCheck,
    bool requiresIntakeInventory,
  });

  Future<void> update(ServiceTypeEntity serviceType);

  Future<void> deactivate(int id);
}
