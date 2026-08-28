import 'package:telepos/domain/entities/wms/wms_config_entity.dart';
import 'package:telepos/domain/repositories/wms_config_repository.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

class WmsConfigUseCaseImpl implements WmsConfigUseCase {
  WmsConfigUseCaseImpl(this._configRepo);

  final WmsConfigRepository _configRepo;

  @override
  Future<WmsConfigEntity> getConfig() async {
    final config = await _configRepo.getConfig();
    if (config == null) {
      return const WmsConfigEntity(
        id: 1,
        enableBatches: false,
        enableSerials: false,
        enableCells: false,
        enableMarkingCodes: false,
        enableWarranty: false,
        enableStockRules: false,
        enableFifo: false,
        enableFefo: false,
        expiryWarningDays: 30,
        defaultWarrantyMonths: 12,
        autoAssignCells: false,
        requireBatchOnReceive: false,
        requireSerialOnReceive: false,
        requireCellOnReceive: false,
      );
    }

    return config;
  }

  @override
  Future<WmsResult> saveConfig(WmsConfigEntity config) async {
    try {
      await _configRepo.saveConfig(config);
      return WmsResult.ok(1);
    } catch (e) {
      return WmsResult.failed('Ошибка сохранения конфигурации WMS: $e');
    }
  }

  @override
  Future<bool> isModuleEnabled(String module) async {
    final config = await getConfig();

    switch (module) {
      case 'cellStorage':
        return config.enableCells ?? false;
      case 'serialTracking':
        return config.enableSerials ?? false;
      case 'batchTracking':
        return config.enableBatches ?? false;
      case 'markingCodes':
        return config.enableMarkingCodes ?? false;
      case 'warranty':
        return config.enableWarranty ?? false;
      case 'stockRules':
        return config.enableStockRules ?? false;
      default:
        return false;
    }
  }

  @override
  Future<String> pickingStrategy() async {
    final config = await getConfig();
    const allowed = {'FEFO', 'FIFO', 'LIFO'};
    final token = config.pickingStrategy?.toUpperCase();
    if (token != null && allowed.contains(token)) return token;
    if (config.enableFefo == true) return 'FEFO';
    if (config.enableFifo == true) return 'FIFO';
    return 'FEFO';
  }

  @override
  Future<String> costMethod() async {
    final config = await getConfig();
    const allowed = {'FIFO', 'LIFO', 'AVG'};
    final token = config.costMethod?.toUpperCase();
    if (token != null && allowed.contains(token)) return token;
    return 'FIFO';
  }
}
