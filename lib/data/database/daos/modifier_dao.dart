import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/modifier_tables.dart';

part 'modifier_dao.g.dart';

@DriftAccessor(tables: [ModifierGroups, ModifierOptions, SaleProductModifiers])
class ModifierDao extends DatabaseAccessor<AppDatabase>
    with _$ModifierDaoMixin {
  ModifierDao(super.db);

  Future<List<ModifierGroup>> getGroupsForDish(int dishUcode) {
    return (select(modifierGroups)
          ..where((g) => g.dishUcode.equals(dishUcode) | g.dishUcode.isNull())
          ..where((g) => g.isActive.equals(true))
          ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
        .get();
  }

  Future<List<ModifierGroup>> getAllGroups() {
    return (select(
      modifierGroups,
    )..orderBy([(g) => OrderingTerm.asc(g.sortOrder)])).get();
  }

  Future<List<ModifierOption>> getOptionsByGroup(int groupId) {
    return (select(modifierOptions)
          ..where((o) => o.groupId.equals(groupId))
          ..where((o) => o.isAvailable.equals(true))
          ..orderBy([(o) => OrderingTerm.asc(o.sortOrder)]))
        .get();
  }

  Future<int> insertGroup(ModifierGroupsCompanion entry) =>
      into(modifierGroups).insert(entry);

  Future<int> updateGroup(int id, ModifierGroupsCompanion entry) =>
      (update(modifierGroups)..where((g) => g.id.equals(id))).write(entry);

  Future<int> deleteGroup(int id) =>
      (delete(modifierGroups)..where((g) => g.id.equals(id))).go();

  Future<int> insertOption(ModifierOptionsCompanion entry) =>
      into(modifierOptions).insert(entry);

  Future<int> updateOption(int id, ModifierOptionsCompanion entry) =>
      (update(modifierOptions)..where((o) => o.id.equals(id))).write(entry);

  Future<int> deleteOption(int id) =>
      (delete(modifierOptions)..where((o) => o.id.equals(id))).go();

  Future<List<SaleProductModifier>> getSelectedModifiers(int saleProductId) {
    return (select(
      saleProductModifiers,
    )..where((m) => m.saleProductId.equals(saleProductId))).get();
  }

  Future<int> insertSaleModifier(SaleProductModifiersCompanion entry) =>
      into(saleProductModifiers).insert(entry);

  Future<int> deleteBySaleProductId(int saleProductId) => (delete(
    saleProductModifiers,
  )..where((m) => m.saleProductId.equals(saleProductId))).go();
}
