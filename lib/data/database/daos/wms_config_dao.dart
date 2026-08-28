import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'wms_config_dao.g.dart';

@DriftAccessor(tables: [WmsConfigs])
class WmsConfigDao extends DatabaseAccessor<AppDatabase>
    with _$WmsConfigDaoMixin {
  WmsConfigDao(super.db);

  Future<WmsConfig?> getConfig() =>
      (select(wmsConfigs)..where((c) => c.id.equals(1))).getSingleOrNull();

  Future<int> saveConfig(WmsConfigsCompanion config) => into(
    wmsConfigs,
  ).insertOnConflictUpdate(config.copyWith(id: const Value(1)));
}
