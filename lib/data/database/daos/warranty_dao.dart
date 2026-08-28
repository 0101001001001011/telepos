import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'warranty_dao.g.dart';

@DriftAccessor(
  tables: [WarrantyRecords, Claims, ClaimHistoryEntries, ProductComponents],
)
class WarrantyDao extends DatabaseAccessor<AppDatabase>
    with _$WarrantyDaoMixin {
  WarrantyDao(super.db);

  Future<List<WarrantyRecord>> findWarrantyBySerialId(int serialId) => (select(
    warrantyRecords,
  )..where((w) => w.serialId.equals(serialId))).get();

  Future<List<WarrantyRecord>> findWarrantyByUcode(int ucode) =>
      (select(warrantyRecords)..where((w) => w.ucode.equals(ucode))).get();

  Future<List<WarrantyRecord>> findExpiringWarranties(int daysAhead) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final threshold = now + daysAhead * 86400;
    return (select(warrantyRecords)
          ..where(
            (w) =>
                w.warrantyEnd.isSmallerOrEqualValue(threshold) &
                w.warrantyEnd.isBiggerOrEqualValue(now),
          )
          ..orderBy([(w) => OrderingTerm.asc(w.warrantyEnd)]))
        .get();
  }

  Future<int> insertWarranty(WarrantyRecordsCompanion warranty) =>
      into(warrantyRecords).insert(warranty);

  Future<int> updateWarranty(int id, WarrantyRecordsCompanion warranty) =>
      (update(warrantyRecords)..where((w) => w.id.equals(id))).write(warranty);

  Future<Claim?> findClaimById(int id) =>
      (select(claims)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<List<Claim>> findClaimsByStatus(int status) =>
      (select(claims)
            ..where((c) => c.status.equals(status))
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
          .get();

  Future<List<Claim>> findAllClaims({int limit = 200, int offset = 0}) =>
      (select(claims)
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
            ..limit(limit, offset: offset))
          .get();

  Future<List<Claim>> findClaimsByCustomerId(int customerId) =>
      (select(claims)
            ..where((c) => c.customerId.equals(customerId))
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
          .get();

  Future<int> insertClaim(ClaimsCompanion claim) => into(claims).insert(claim);

  Future<int> updateClaim(int id, ClaimsCompanion claim) =>
      (update(claims)..where((c) => c.id.equals(id))).write(claim);

  Future<String> getNextClaimNumber() async {
    final year = DateTime.now().year;
    final expr = claims.id.count();
    final count = await (selectOnly(
      claims,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
    final number = count + 1;
    return 'CLM-$year-${number.toString().padLeft(4, '0')}';
  }

  Future<int> insertClaimHistory(ClaimHistoryEntriesCompanion entry) =>
      into(claimHistoryEntries).insert(entry);

  Future<List<ClaimHistoryEntry>> findClaimHistory(int claimId) =>
      (select(claimHistoryEntries)
            ..where((h) => h.claimId.equals(claimId))
            ..orderBy([(h) => OrderingTerm.desc(h.timestamp)]))
          .get();

  Future<List<ProductComponent>> findComponentsBySerialId(int parentSerialId) =>
      (select(
        productComponents,
      )..where((c) => c.parentSerialId.equals(parentSerialId))).get();

  Future<int> insertComponent(ProductComponentsCompanion component) =>
      into(productComponents).insert(component);
}
