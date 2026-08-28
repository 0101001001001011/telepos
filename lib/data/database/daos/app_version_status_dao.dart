import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/config_tables.dart';

part 'app_version_status_dao.g.dart';

@DriftAccessor(tables: [AppVersionStatuses])
class AppVersionStatusDao extends DatabaseAccessor<AppDatabase>
    with _$AppVersionStatusDaoMixin {
  AppVersionStatusDao(super.db);
}
