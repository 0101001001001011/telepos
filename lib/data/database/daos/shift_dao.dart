import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/shift_tables.dart';

part 'shift_dao.g.dart';

@DriftAccessor(tables: [Shifts])
class ShiftDao extends DatabaseAccessor<AppDatabase> with _$ShiftDaoMixin {
  ShiftDao(super.db);

  Future<Shift?> findOpenedShift() => (select(
    shifts,
  )..where((sh) => sh.isOpened.equals(true))).getSingleOrNull();

  Future<Shift?> findById(int shiftId) =>
      (select(shifts)..where((sh) => sh.id.equals(shiftId))).getSingleOrNull();

  Future<List<Shift>> findClosedShifts({int limit = 100}) =>
      (select(shifts)
            ..where((sh) => sh.isOpened.equals(false))
            ..orderBy([
              (sh) => OrderingTerm.desc(sh.closeTime),
              (sh) => OrderingTerm.desc(sh.id),
            ])
            ..limit(limit))
          .get();

  Future<List<Shift>> findAllNonSync() =>
      (select(shifts)..where(
            (sh) => sh.isOpened.equals(false) & sh.isSynced.equals(false),
          ))
          .get();

  Future<List<Shift>> findLatestDescOrder() => (select(
    shifts,
  )..orderBy([(sh) => OrderingTerm.desc(sh.closeTime)])).get();

  Future<Shift?> findLastClosedShiftReport() {
    return customSelect(
      'SELECT * FROM shifts WHERE is_opened = 0 AND close_time = (SELECT MAX(close_time) FROM shifts)',
      readsFrom: {shifts},
    ).get().then((rows) {
      if (rows.isEmpty) return null;
      return (select(shifts)
            ..where((sh) => sh.isOpened.equals(false))
            ..orderBy([(sh) => OrderingTerm.desc(sh.closeTime)])
            ..limit(1))
          .getSingleOrNull();
    });
  }

  Future<int> countUnsyncedReports() {
    final expr = shifts.id.count();
    return (selectOnly(shifts)
          ..addColumns([expr])
          ..where(
            shifts.isOpened.equals(false) & shifts.isSynced.equals(false),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<QueryRow?> findCurrentUser() => customSelect(
    'SELECT u.* FROM users u WHERE u.id = (SELECT sh.user_id FROM shifts sh WHERE sh.is_opened = 1)',
    readsFrom: {shifts},
  ).get().then((rows) => rows.isEmpty ? null : rows.first);

  Future<int> count() {
    final expr = shifts.id.count();
    return (selectOnly(
      shifts,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<int> countOpened() {
    final expr = shifts.id.count();
    return (selectOnly(shifts)
          ..addColumns([expr])
          ..where(shifts.isOpened.equals(true)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countClosed() {
    final expr = shifts.id.count();
    return (selectOnly(shifts)
          ..addColumns([expr])
          ..where(shifts.isOpened.equals(false)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countSynced() {
    final expr = shifts.id.count();
    return (selectOnly(shifts)
          ..addColumns([expr])
          ..where(shifts.isSynced.equals(true)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<bool> hasAny() async {
    final c = await count();
    return c > 0;
  }

  Future<Shift?> findLast() =>
      (select(shifts)
            ..orderBy([
              (sh) => OrderingTerm.desc(sh.closeTime),
              (sh) => OrderingTerm.desc(sh.openTime),
              (sh) => OrderingTerm.desc(sh.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<Shift?> findLastClosed() =>
      (select(shifts)
            ..where((sh) => sh.isOpened.equals(false))
            ..orderBy([
              (sh) => OrderingTerm.desc(sh.closeTime),
              (sh) => OrderingTerm.desc(sh.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<ShiftStats> getStats() async {
    final total = await count();
    final opened = await countOpened();
    final closed = await countClosed();
    final synced = await countSynced();
    final unsynced = await countUnsyncedReports();

    return ShiftStats(
      total: total,
      opened: opened,
      closed: closed,
      synced: synced,
      unsynced: unsynced,
    );
  }

  Future<int> insertShift(ShiftsCompanion companion) =>
      into(shifts).insert(companion);

  Future<void> updateShift(int shiftId, ShiftsCompanion companion) => (update(
    shifts,
  )..where((sh) => sh.id.equals(shiftId))).write(companion).then((_) {});

  Future<int> markAsSynced(int shiftId) =>
      (update(shifts)..where((sh) => sh.id.equals(shiftId))).write(
        const ShiftsCompanion(isSynced: Value(true)),
      );
}

class ShiftStats {
  final int total;
  final int opened;
  final int closed;
  final int synced;
  final int unsynced;

  const ShiftStats({
    required this.total,
    required this.opened,
    required this.closed,
    required this.synced,
    required this.unsynced,
  });

  @override
  String toString() =>
      'total=$total (opened=$opened, closed=$closed, '
      'synced=$synced, unsynced=$unsynced)';
}
