import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/writeoff_tables.dart';

part 'writeoff_dao.g.dart';

@DriftAccessor(tables: [Writeoffs])
class WriteoffDao extends DatabaseAccessor<AppDatabase>
    with _$WriteoffDaoMixin {
  WriteoffDao(super.db);

  Future<int> insertWriteoff(WriteoffsCompanion writeoff) =>
      into(writeoffs).insert(writeoff);

  Future<Writeoff?> findById(int id) =>
      (select(writeoffs)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<List<Writeoff>> findAll({int limit = 50, int offset = 0}) =>
      (select(writeoffs)
            ..orderBy([(w) => OrderingTerm.desc(w.docTime)])
            ..limit(limit, offset: offset))
          .get();

  Future<List<Writeoff>> findNonSynced() =>
      (select(writeoffs)..where((w) => w.state.equals(3).not())).get();

  Future<int> countUnsynced() {
    final expr = writeoffs.id.count();
    return (selectOnly(writeoffs)
          ..addColumns([expr])
          ..where(writeoffs.state.equals(3).not()))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> setResponse(int id, String? msg, int state) =>
      (update(writeoffs)..where((w) => w.id.equals(id))).write(
        WriteoffsCompanion(state: Value(state), msg: Value(msg)),
      );

  Future<int> deleteWriteoff(int id) =>
      (delete(writeoffs)..where((w) => w.id.equals(id))).go();
}
