import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';

part 'pos_dao.g.dart';

@DriftAccessor(tables: [PosEntries])
class PosDao extends DatabaseAccessor<AppDatabase> with _$PosDaoMixin {
  PosDao(super.db);

  Future<List<PosEntry>> findHavingSales() =>
      customSelect(
        'SELECT DISTINCT p.* FROM sales s LEFT JOIN pos_entries p ON s.pos_id = p.id WHERE p.is_virtual = 0',
        readsFrom: {posEntries},
      ).get().then(
        (_) =>
            (select(posEntries)..where((p) => p.isVirtual.equals(false))).get(),
      );

  Future<PosEntry?> findThis() =>
      customSelect(
        'SELECT p.* FROM pos_entries p WHERE p.id = (SELECT tp.id FROM this_pos_entries tp LIMIT 1)',
        readsFrom: {posEntries},
      ).get().then(
        (rows) => rows.isEmpty
            ? null
            : (select(posEntries)..limit(1)).getSingleOrNull(),
      );

  Future<PosEntry?> findLast() =>
      (select(posEntries)
            ..orderBy([
              (p) => OrderingTerm.desc(p.updateTime),
              (p) => OrderingTerm.desc(p.id),
            ])
            ..limit(1))
          .getSingleOrNull();
}
