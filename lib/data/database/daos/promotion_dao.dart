import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'promotion_dao.g.dart';

@DriftAccessor(tables: [Promotions])
class PromotionDao extends DatabaseAccessor<AppDatabase>
    with _$PromotionDaoMixin {
  PromotionDao(super.db);

  Future<List<Promotion>> getAll() =>
      (select(promotions)..orderBy([(p) => OrderingTerm.desc(p.id)])).get();

  Future<List<Promotion>> getEnabled() =>
      (select(promotions)..where((p) => p.enabled.equals(true))).get();

  Future<int> insertPromotion(PromotionsCompanion entry) =>
      into(promotions).insert(entry);

  Future<void> setEnabled(int id, bool enabled) =>
      (update(promotions)..where((p) => p.id.equals(id))).write(
        PromotionsCompanion(enabled: Value(enabled)),
      );

  Future<void> deletePromotion(int id) =>
      (delete(promotions)..where((p) => p.id.equals(id))).go();
}
