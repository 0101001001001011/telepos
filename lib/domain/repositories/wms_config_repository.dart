import 'package:telepos/domain/entities/wms/wms_config_entity.dart';

abstract class WmsConfigRepository {
  Future<WmsConfigEntity?> getConfig();

  Future<int> saveConfig(WmsConfigEntity entity);
}
