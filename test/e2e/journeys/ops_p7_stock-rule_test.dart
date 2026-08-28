library;

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/stock_rule/stock_rule_use_case_impl.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  test('evaluateReorders returns EXACTLY the below-reorder-point ucodes '
      '(Decimal-exact, read-only — stock untouched)', () async {
    final db = GetIt.I<AppDatabase>();

    const seedProducts = [
      (ucode: 2001, barcode: 4607101, qty: '3'),
      (ucode: 2002, barcode: 4607102, qty: '5'),
      (ucode: 2003, barcode: 4607103, qty: '20'),
      (ucode: 2004, barcode: 4607104, qty: '0'),
    ];
    for (final p in seedProducts) {
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion(
              ucode: drift.Value(p.ucode),
              barcode: drift.Value(p.barcode),
              name: drift.Value('Товар ${p.ucode}'),
              type: const drift.Value(0),
              measure: const drift.Value(0),
              quantity: drift.Value(d(p.qty)),
              isDeleted: const drift.Value(false),
            ),
          );
    }

    await db.stockRuleDao.upsertRule(
      StockRulesCompanion(
        ucode: const drift.Value(2001),
        minStock: drift.Value(d('5')),
        maxStock: drift.Value(d('30')),
        reorderQty: drift.Value(d('25')),
      ),
    );
    await db.stockRuleDao.upsertRule(
      StockRulesCompanion(
        ucode: const drift.Value(2002),
        minStock: drift.Value(d('5')),
        reorderQty: drift.Value(d('10')),
      ),
    );
    await db.stockRuleDao.upsertRule(
      StockRulesCompanion(
        ucode: const drift.Value(2003),
        minStock: drift.Value(d('5')),
      ),
    );
    await db.stockRuleDao.upsertRule(
      const StockRulesCompanion(
        ucode: drift.Value(2004),
        maxStock: drift.Value(null),
      ),
    );

    final useCase = StockRuleUseCaseImpl(db.stockRuleDao, db.productInfoDao);

    final rules = await useCase.listRules();
    expect(rules.length, 4, reason: 'all seeded rules are listed');

    final below = await useCase.ucodesBelowReorderPoint();
    expect(
      below.toSet(),
      {2001, 2002},
      reason: 'only qty <= reorderPoint with a threshold trigger a signal',
    );
    expect(below, isNot(contains(2003)), reason: '20 > 5 is above the point');
    expect(
      below,
      isNot(contains(2004)),
      reason: 'no reorder point => no signal even at qty 0',
    );

    final signals = await useCase.evaluateReorders();
    final s2001 = signals.firstWhere((s) => s.ucode == 2001);
    expect(s2001.currentQty, d('3'));
    expect(s2001.reorderPoint, d('5'));
    expect(s2001.suggestedOrderQty, d('25'));

    final s2002 = signals.firstWhere((s) => s.ucode == 2002);
    expect(
      s2002.currentQty,
      d('5'),
      reason: 'at-point (qty == reorderPoint) still signals',
    );
    expect(s2002.suggestedOrderQty, d('10'));

    for (final p in seedProducts) {
      final after = await db.productInfoDao.findByUcode(p.ucode);
      expect(
        after?.quantity,
        d(p.qty),
        reason:
            'evaluateReorders is read-only; stock for ${p.ucode} '
            'must be unchanged',
      );
    }

    final forOne = await useCase.listRulesForUcode(2001);
    expect(forOne.length, 1);
    expect(forOne.single.minStock, d('5'));
  });
}
