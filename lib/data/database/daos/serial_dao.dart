import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'serial_dao.g.dart';

@DriftAccessor(tables: [Serials, SerialMovements])
class SerialDao extends DatabaseAccessor<AppDatabase> with _$SerialDaoMixin {
  SerialDao(super.db);

  Future<Serial?> findById(int id) =>
      (select(serials)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Serial?> findBySerialNumber(String serialNumber) => (select(
    serials,
  )..where((s) => s.serialNumber.equals(serialNumber))).getSingleOrNull();

  Future<List<Serial>> findByUcode(int ucode) =>
      (select(serials)..where((s) => s.ucode.equals(ucode))).get();

  Future<List<Serial>> findBySaleId(int saleId) =>
      (select(serials)..where((s) => s.saleId.equals(saleId))).get();

  Future<List<Serial>> findByStatus(int status) =>
      (select(serials)..where((s) => s.status.equals(status))).get();

  Future<int> insertSerial(SerialsCompanion serial) =>
      into(serials).insert(serial);

  Future<int> updateSerial(int id, SerialsCompanion serial) =>
      (update(serials)..where((s) => s.id.equals(id))).write(serial);

  Future<int> updateStatus(int id, int status) =>
      (update(serials)..where((s) => s.id.equals(id))).write(
        SerialsCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        ),
      );

  Future<int> insertMovement(SerialMovementsCompanion movement) =>
      into(serialMovements).insert(movement);

  Future<List<SerialMovement>> findMovements(int serialId) =>
      (select(serialMovements)
            ..where((m) => m.serialId.equals(serialId))
            ..orderBy([(m) => OrderingTerm.desc(m.timestamp)]))
          .get();
}
