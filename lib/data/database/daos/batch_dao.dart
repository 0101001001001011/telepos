import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'batch_dao.g.dart';

@DriftAccessor(tables: [Batches])
class BatchDao extends DatabaseAccessor<AppDatabase> with _$BatchDaoMixin {
  BatchDao(super.db);

  Future<Batche?> findById(int id) =>
      (select(batches)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<List<Batche>> findByUcode(int ucode) =>
      (select(batches)..where((b) => b.ucode.equals(ucode))).get();

  Future<Batche?> findByBatchNumber(String number) => (select(
    batches,
  )..where((b) => b.batchNumber.equals(number))).getSingleOrNull();

  Future<List<Batche>> findExpiring(int daysAhead) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final threshold = now + daysAhead * 86400;
    return (select(batches)
          ..where(
            (b) =>
                b.expiryDate.isSmallerOrEqualValue(threshold) &
                b.expiryDate.isBiggerOrEqualValue(now) &
                b.isActive.equals(true),
          )
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  Future<List<Batche>> findExpired() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (select(batches)
          ..where(
            (b) =>
                b.expiryDate.isSmallerThanValue(now) & b.isActive.equals(true),
          )
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  Future<List<Batche>> findQuarantined() =>
      (select(batches)..where((b) => b.isQuarantined.equals(true))).get();

  Future<List<Batche>> findActiveByUcode(int ucode) =>
      (select(batches)
            ..where((b) => b.ucode.equals(ucode) & b.isActive.equals(true))
            ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
          .get();

  Future<List<Batche>> findFifoConsumable(int ucode) =>
      (select(batches)
            ..where(
              (b) =>
                  b.ucode.equals(ucode) &
                  b.isActive.equals(true) &
                  b.currentQuantity.isBiggerThanValue(0),
            )
            ..orderBy([
              (b) => OrderingTerm.asc(b.receivedDate),
              (b) => OrderingTerm.asc(b.createdAt),
              (b) => OrderingTerm.asc(b.id),
            ]))
          .get();

  Future<int> insertBatch(BatchesCompanion batch) =>
      into(batches).insert(batch);

  Future<int> updateBatch(int id, BatchesCompanion batch) =>
      (update(batches)..where((b) => b.id.equals(id))).write(batch);

  Future<int> adjustQuantity(int id, Decimal delta) async {
    final existing = await (select(
      batches,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (existing == null) return 0;

    final raw = existing.currentQuantity + delta;
    final newQty = raw < Decimal.zero ? Decimal.zero : raw;
    return (update(batches)..where((b) => b.id.equals(id))).write(
      BatchesCompanion(
        currentQuantity: Value(newQty),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
  }
}
