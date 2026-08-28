import 'package:telepos/domain/entities/wms/wms_config_entity.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

abstract class WmsConfigUseCase {
  Future<WmsConfigEntity> getConfig();

  Future<WmsResult> saveConfig(WmsConfigEntity config);

  Future<bool> isModuleEnabled(String module);

  Future<String> pickingStrategy();

  Future<String> costMethod();
}
