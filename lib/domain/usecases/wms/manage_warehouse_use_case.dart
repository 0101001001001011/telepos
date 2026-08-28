import 'package:telepos/domain/usecases/wms/wms_result.dart';

abstract class ManageWarehouseUseCase {
  Future<WmsResult> createWarehouse({
    required String code,
    required String name,
    String? address,
  });

  Future<WmsResult> updateWarehouse(
    int id, {
    String? code,
    String? name,
    String? address,
    bool? isActive,
  });

  Future<WmsResult> deleteWarehouse(int id);

  Future<WmsResult> setDefaultWarehouse(int id);
}
