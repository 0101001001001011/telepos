import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_type_entity.dart';
import 'package:telepos/domain/usecases/service/manage_service_types_use_case.dart';

class ManageServiceTypesUseCaseImpl implements ManageServiceTypesUseCase {
  ManageServiceTypesUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<ServiceTypeEntity>> getActive() async {
    try {
      final rows = await _db.serviceTypeDao.getActive();

      _logger.debug('Found ${rows.length} active service types');

      return rows.map(_mapToEntity).toList();
    } catch (e) {
      _logger.error('Failed to get active service types: $e');
      rethrow;
    }
  }

  @override
  Future<ServiceTypeEntity> create({
    required int productUcode,
    int? estimatedDurationMinutes,
    int? warrantyDays,
    bool requiresDevice = false,
    bool requiresIntakePhotos = false,
    bool requiresRepairPhotos = false,
    bool requiresQualityCheck = false,
    bool requiresIntakeInventory = false,
  }) async {
    try {
      final id = await _db.serviceTypeDao.insert(
        ServiceTypesCompanion(
          productUcode: Value(productUcode),
          estimatedDurationMinutes: Value(estimatedDurationMinutes),
          warrantyDays: Value(warrantyDays),
          requiresDevice: Value(requiresDevice),
          requiresIntakePhotos: Value(requiresIntakePhotos),
          requiresRepairPhotos: Value(requiresRepairPhotos),
          requiresQualityCheck: Value(requiresQualityCheck),
          requiresIntakeInventory: Value(requiresIntakeInventory),
          isActive: const Value(true),
        ),
      );

      _logger.info(
        'Service type created: id=$id, productUcode=$productUcode, '
        'duration=${estimatedDurationMinutes}min, '
        'warranty=${warrantyDays}days',
      );

      return ServiceTypeEntity(
        id: id,
        productUcode: productUcode,
        estimatedDurationMinutes: estimatedDurationMinutes,
        warrantyDays: warrantyDays,
        requiresDevice: requiresDevice,
        requiresIntakePhotos: requiresIntakePhotos,
        requiresRepairPhotos: requiresRepairPhotos,
        requiresQualityCheck: requiresQualityCheck,
        requiresIntakeInventory: requiresIntakeInventory,
        isActive: true,
      );
    } catch (e) {
      _logger.error('Failed to create service type: $e');
      rethrow;
    }
  }

  @override
  Future<void> update(ServiceTypeEntity serviceType) async {
    try {
      if (serviceType.id == null) {
        throw ArgumentError(
          'Cannot update ServiceType without id. '
          'Use create() for new service types.',
        );
      }

      final driftModel = ServiceType(
        id: serviceType.id!,
        productUcode: serviceType.productUcode,
        estimatedDurationMinutes: serviceType.estimatedDurationMinutes,
        warrantyDays: serviceType.warrantyDays,
        requiresDevice: serviceType.requiresDevice,
        requiresIntakePhotos: serviceType.requiresIntakePhotos,
        requiresRepairPhotos: serviceType.requiresRepairPhotos,
        requiresQualityCheck: serviceType.requiresQualityCheck,
        requiresIntakeInventory: serviceType.requiresIntakeInventory,
        isActive: serviceType.isActive,
      );

      await _db.serviceTypeDao.updateType(driftModel);

      _logger.info(
        'Service type updated: id=${serviceType.id}, '
        'productUcode=${serviceType.productUcode}',
      );
    } catch (e) {
      _logger.error('Failed to update service type ${serviceType.id}: $e');
      rethrow;
    }
  }

  @override
  Future<void> deactivate(int id) async {
    try {
      await _db.serviceTypeDao.deactivate(id);

      _logger.info('Service type deactivated: id=$id');
    } catch (e) {
      _logger.error('Failed to deactivate service type $id: $e');
      rethrow;
    }
  }

  ServiceTypeEntity _mapToEntity(ServiceType row) {
    return ServiceTypeEntity(
      id: row.id,
      productUcode: row.productUcode,
      estimatedDurationMinutes: row.estimatedDurationMinutes,
      warrantyDays: row.warrantyDays,
      requiresDevice: row.requiresDevice,
      requiresIntakePhotos: row.requiresIntakePhotos,
      requiresRepairPhotos: row.requiresRepairPhotos,
      requiresQualityCheck: row.requiresQualityCheck,
      requiresIntakeInventory: row.requiresIntakeInventory,
      isActive: row.isActive,
    );
  }
}
