import 'package:telepos/domain/entities/wms/warehouse_entity.dart';
import 'package:telepos/domain/repositories/warehouse_repository.dart';
import 'package:telepos/domain/usecases/wms/manage_warehouse_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

class ManageWarehouseUseCaseImpl implements ManageWarehouseUseCase {
  ManageWarehouseUseCaseImpl(this._warehouseRepo);

  final WarehouseRepository _warehouseRepo;

  @override
  Future<WmsResult> createWarehouse({
    required String code,
    required String name,
    String? address,
  }) async {
    try {
      final id = await _warehouseRepo.create(
        WarehouseEntity(
          code: code,
          name: name,
          address: address,
          isActive: true,
          isDefault: false,
        ),
      );

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка создания склада: $e');
    }
  }

  @override
  Future<WmsResult> updateWarehouse(
    int id, {
    String? code,
    String? name,
    String? address,
    bool? isActive,
  }) async {
    try {
      final existing = await _warehouseRepo.findById(id);
      if (existing == null) {
        return WmsResult.failed('Склад с ID $id не найден');
      }

      await _warehouseRepo.update(
        existing.copyWith(
          code: code,
          name: name,
          address: address,
          isActive: isActive,
        ),
      );

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка обновления склада: $e');
    }
  }

  @override
  Future<WmsResult> deleteWarehouse(int id) async {
    try {
      final existing = await _warehouseRepo.findById(id);
      if (existing == null) {
        return WmsResult.failed('Склад с ID $id не найден');
      }

      await _warehouseRepo.delete(id);
      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка удаления склада: $e');
    }
  }

  @override
  Future<WmsResult> setDefaultWarehouse(int id) async {
    try {
      final existing = await _warehouseRepo.findById(id);
      if (existing == null) {
        return WmsResult.failed('Склад с ID $id не найден');
      }

      await _warehouseRepo.setDefault(id);

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка установки склада по умолчанию: $e');
    }
  }
}
