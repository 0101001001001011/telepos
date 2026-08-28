import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'mark_up_dao.g.dart';

@DriftAccessor(tables: [MarkUps])
class MarkUpDao extends DatabaseAccessor<AppDatabase> with _$MarkUpDaoMixin {
  MarkUpDao(super.db);

  Future<MarkUp?> findMarkUpFor(int categoryId) async {
    final rows = await customSelect(
      'SELECT m.* FROM mark_ups m '
      'WHERE m.category_id = ? '
      'OR m.category_id = (SELECT c.parent_id FROM categories c WHERE c.id = ?) '
      'LIMIT 1',
      variables: [Variable.withInt(categoryId), Variable.withInt(categoryId)],
      readsFrom: {markUps},
    ).get();
    if (rows.isEmpty) return null;
    return (select(
      markUps,
    )..where((m) => m.categoryId.equals(categoryId))).getSingleOrNull();
  }

  Future<int> countMarkUp() {
    final expr = markUps.categoryId.count();
    return (selectOnly(
      markUps,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<bool> hasNoMarkUps() async {
    final result = await (select(markUps)..limit(1)).get();
    return result.isEmpty;
  }

  Future<List<MarkUp>> getAll() => select(markUps).get();

  Future<void> upsertMarkUp(
    int categoryId,
    Decimal markup, {
    int? storeId,
  }) async {
    await into(markUps).insertOnConflictUpdate(
      MarkUpsCompanion(
        categoryId: Value(categoryId),
        storeId: Value(storeId),
        markup: Value(markup),
      ),
    );
  }
}
