import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/config_tables.dart';

part 'additional_printer_dao.g.dart';

@DriftAccessor(tables: [AdditionalPrinters])
class AdditionalPrinterDao extends DatabaseAccessor<AppDatabase>
    with _$AdditionalPrinterDaoMixin {
  AdditionalPrinterDao(super.db);

  Future<List<String>> findAllNames() {
    final expr = additionalPrinters.name;
    return (selectOnly(
      additionalPrinters,
    )..addColumns([expr])).map((row) => row.read(expr)!).get();
  }
}
