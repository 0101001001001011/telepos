import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/dish_tables.dart';

part 'gost_loss_norm_dao.g.dart';

@DriftAccessor(tables: [GostLossNorms])
class GostLossNormDao extends DatabaseAccessor<AppDatabase>
    with _$GostLossNormDaoMixin {
  GostLossNormDao(super.db);

  Future<List<GostLossNorm>> findAll() => select(gostLossNorms).get();

  Future<List<GostLossNorm>> findByProductName(String name) => (select(
    gostLossNorms,
  )..where((n) => n.productName.like('%$name%'))).get();

  Future<int> insertNorm(GostLossNormsCompanion entry) =>
      into(gostLossNorms).insert(entry);

  Future<void> seedInitialData() async {
    final existing = await select(gostLossNorms).get();
    if (existing.isNotEmpty) return;

    final norms = <GostLossNormsCompanion>[
      _norm('Картофель', 25.0, 3.0, 0),
      _norm('Картофель', 30.0, 3.0, 1),
      _norm('Морковь', 20.0, 5.0, 0),
      _norm('Морковь', 25.0, 5.0, 1),
      _norm('Свёкла', 20.0, 5.0, 0),
      _norm('Капуста', 20.0, 10.0, 0),
      _norm('Лук репчатый', 16.0, 26.0, 0),
      _norm('Помидоры', 15.0, 10.0, 0),
      _norm('Огурцы', 5.0, 0.0, 0),
      _norm('Говядина', 26.0, 38.0, 0),
      _norm('Свинина', 15.0, 40.0, 0),
      _norm('Курица', 25.0, 28.0, 0),
      _norm('Рыба', 40.0, 20.0, 0),
      _norm('Рис', 0.0, 3.0, 0),
      _norm('Макароны', 0.0, 0.0, 0),
      _norm('Яйца', 12.5, 8.0, 0),
      _norm('Масло сл.', 0.0, 0.0, 0),
      _norm('Мука', 0.0, 0.0, 0),
      _norm('Сахар', 0.0, 0.0, 0),
      _norm('Молоко', 0.0, 5.0, 0),
      _norm('Сметана', 0.0, 5.0, 0),
      _norm('Творог', 0.0, 10.0, 0),
    ];

    await batch((b) {
      b.insertAll(gostLossNorms, norms);
    });
  }

  static GostLossNormsCompanion _norm(
    String name,
    double coldLoss,
    double hotLoss,
    int season,
  ) {
    return GostLossNormsCompanion.insert(
      productName: name,
      coldLossPercent: Decimal.parse(coldLoss.toString()),
      hotLossPercent: Decimal.parse(hotLoss.toString()),
      season: Value(season),
    );
  }
}
