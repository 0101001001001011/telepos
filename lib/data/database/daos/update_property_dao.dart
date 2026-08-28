import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/config_tables.dart';

part 'update_property_dao.g.dart';

@DriftAccessor(tables: [UpdateProperties])
class UpdatePropertyDao extends DatabaseAccessor<AppDatabase>
    with _$UpdatePropertyDaoMixin {
  UpdatePropertyDao(super.db);
}
