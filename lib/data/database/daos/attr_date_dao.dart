import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/config_tables.dart';

part 'attr_date_dao.g.dart';

@DriftAccessor(tables: [AttrDates])
class AttrDateDao extends DatabaseAccessor<AppDatabase>
    with _$AttrDateDaoMixin {
  AttrDateDao(super.db);
}
