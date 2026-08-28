library;

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/controllers/movement/movement_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUp(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDown(() => h.tearDown());

  Future<Decimal> qtyOf(AppDatabase db, int ucode) async {
    final p = await db.productInfoDao.findByUcode(ucode);
    return p?.quantity ?? Decimal.zero;
  }

  testWidgets(
    'inter-warehouse transfer is quantity-neutral (no stock loss) and '
    'persists exact Decimal amounts',
    (tester) async {
      final db = h.db;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(movementControllerProvider.notifier);

      const ucode = 1001;
      final startQty = await qtyOf(db, ucode);
      expect(
        startQty,
        Decimal.parse('100'),
        reason: 'seed baseline: 100 units on hand',
      );

      notifier.setFromLocation('Склад A');
      notifier.setToLocation('Склад B');
      await notifier.addProduct(
        ucode: ucode,
        quantity: Decimal.parse('30'),
        price: Decimal.parse('12.345'),
      );

      final expectedAmount = Decimal.parse('370.350');
      expect(
        notifier.state.totalAmount,
        expectedAmount,
        reason: 'in-memory total is exact Decimal before save',
      );

      final result = await notifier.save();
      expect(
        result.success,
        isTrue,
        reason: 'transfer must save successfully: ${result.errorMessage}',
      );
      final movementId = result.movementId!;

      final afterQty = await qtyOf(db, ucode);
      expect(
        afterQty,
        Decimal.parse('100'),
        reason:
            'inter-warehouse transfer must be quantity-neutral: stock stays '
            '100, NOT 70 (transfer must never destroy stock)',
      );

      final movement = await (db.select(
        db.movements,
      )..where((m) => m.id.equals(movementId))).getSingleOrNull();
      expect(movement, isNotNull, reason: 'movement record kept for history');
      expect(movement!.fromLocation, 'Склад A');
      expect(movement.toLocation, 'Склад B');

      expect(
        movement.amount,
        expectedAmount,
        reason: 'persisted movement amount is exact Decimal (no double drift)',
      );

      final lines = await (db.select(
        db.movementProducts,
      )..where((mp) => mp.movementId.equals(movementId))).get();
      expect(lines.length, 1, reason: 'exactly one movement line persisted');
      final line = lines.single;
      expect(line.ucode, ucode);
      expect(
        line.quantity,
        Decimal.parse('30'),
        reason: 'persisted line quantity is exact Decimal',
      );
      expect(
        line.price,
        Decimal.parse('12.345'),
        reason: 'persisted line price is exact Decimal',
      );
      expect(
        line.amount,
        expectedAmount,
        reason: 'persisted line amount is exact Decimal',
      );
    },
  );
}
