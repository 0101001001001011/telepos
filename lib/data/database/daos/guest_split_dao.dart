import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/restaurant_tables.dart';

part 'guest_split_dao.g.dart';

@DriftAccessor(tables: [GuestSplits])
class GuestSplitDao extends DatabaseAccessor<AppDatabase>
    with _$GuestSplitDaoMixin {
  GuestSplitDao(super.db);

  Future<List<GuestSplit>> getByOrder(int orderId) =>
      (select(guestSplits)
            ..where((g) => g.orderId.equals(orderId))
            ..orderBy([
              (g) => OrderingTerm.asc(g.guestNumber),
              (g) => OrderingTerm.asc(g.saleProductId),
            ]))
          .get();

  Future<List<GuestSplit>> getByGuest(int orderId, int guestNumber) =>
      (select(guestSplits)..where(
            (g) =>
                g.orderId.equals(orderId) & g.guestNumber.equals(guestNumber),
          ))
          .get();

  Future<int> deleteByOrder(int orderId) =>
      (delete(guestSplits)..where((g) => g.orderId.equals(orderId))).go();

  Future<int> countGuests(int orderId) async {
    final rows = await customSelect(
      'SELECT COUNT(DISTINCT guest_number) AS cnt FROM guest_splits WHERE order_id = ?',
      variables: [Variable.withInt(orderId)],
      readsFrom: {guestSplits},
    ).get();
    return rows.first.read<int>('cnt');
  }

  Future<int> insert(GuestSplitsCompanion entry) =>
      into(guestSplits).insert(entry);

  Future<void> insertAll(List<GuestSplitsCompanion> entries) =>
      batch((b) => b.insertAll(guestSplits, entries));

  Future<int> insertForItem(
    int orderId,
    int guestNumber,
    int saleProductId,
    Decimal quantity,
  ) => into(guestSplits).insert(
    GuestSplitsCompanion.insert(
      orderId: orderId,
      guestNumber: guestNumber,
      saleProductId: saleProductId,
      shareQuantity: quantity,
    ),
  );

  Future<List<GuestSplit>> findBySaleProductId(int saleProductId) => (select(
    guestSplits,
  )..where((g) => g.saleProductId.equals(saleProductId))).get();

  Future<int> deleteBySaleProductId(int saleProductId) => (delete(
    guestSplits,
  )..where((g) => g.saleProductId.equals(saleProductId))).go();
}
