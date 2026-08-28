import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/movement_tables.dart';

part 'movement_dao.g.dart';

@DriftAccessor(tables: [Movements])
class MovementDao extends DatabaseAccessor<AppDatabase>
    with _$MovementDaoMixin {
  MovementDao(super.db);

  Future<List<Movement>> findAll({int limit = 50, int offset = 0}) =>
      (select(movements)
            ..orderBy([(m) => OrderingTerm.desc(m.editTime)])
            ..limit(limit, offset: offset))
          .get();

  Future<Movement?> findById(int id) =>
      (select(movements)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> insertMovement(MovementsCompanion movement) =>
      into(movements).insert(movement);

  Future<int> updateMovement(int id, MovementsCompanion movement) =>
      (update(movements)..where((m) => m.id.equals(id))).write(movement);

  Future<int> deleteMovement(int id) =>
      (delete(movements)..where((m) => m.id.equals(id))).go();

  Future<int> countAll() {
    final expr = movements.id.count();
    return (selectOnly(
      movements,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<List<Movement>> findNonSynced() =>
      (select(movements)..where((m) => m.state.equals(3).not())).get();

  Future<int> countUnsynced() {
    final expr = movements.id.count();
    return (selectOnly(movements)
          ..addColumns([expr])
          ..where(movements.state.equals(3).not()))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> setResponse(int id, String? msg, int state) =>
      (update(movements)..where((m) => m.id.equals(id))).write(
        MovementsCompanion(state: Value(state), msg: Value(msg)),
      );

  Future<List<Movement>> findFiltered({
    int? dateFrom,
    int? dateTo,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(movements);

    if (dateFrom != null) {
      query.where((m) => m.editTime.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query.where((m) => m.editTime.isSmallerOrEqualValue(dateTo));
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where(
        (m) =>
            m.comment.like('%$searchQuery%') |
            m.fromLocation.like('%$searchQuery%') |
            m.toLocation.like('%$searchQuery%'),
      );
    }

    query
      ..orderBy([(m) => OrderingTerm.desc(m.editTime)])
      ..limit(limit, offset: offset);

    return query.get();
  }
}
