import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/wms_config_entity.dart';
import 'package:telepos/domain/repositories/wms_config_repository.dart';

class WmsConfigRepositoryImpl implements WmsConfigRepository {
  WmsConfigRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<WmsConfigEntity?> getConfig() async {
    final row = await _db.wmsConfigDao.getConfig();
    return row != null ? WmsConfigMapper.fromDrift(row) : null;
  }

  @override
  Future<int> saveConfig(WmsConfigEntity entity) {
    final companion = WmsConfigMapper.toDrift(entity);
    return _db.wmsConfigDao.saveConfig(companion);
  }
}
