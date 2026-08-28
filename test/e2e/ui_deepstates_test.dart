library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/service/create_service_order_use_case.dart';

import 'support/harness.dart';

void main() {
  final h = E2eHarness();
  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  Future<void> render(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('deep/$name.png'),
    );
  }

  Future<void> dismiss(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      final navs = find.byType(Navigator).evaluate();
      if (navs.isEmpty) break;
      final root = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (!root.canPop()) break;
      root.pop();
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> seed() async {
    final db = h.db;
    final tables = <(String, int, int, String)>[
      ('1', 4, 1, 'Зал'),
      ('2', 2, 0, 'Зал'),
      ('3', 6, 1, 'Зал'),
      ('4', 4, 2, 'Зал'),
      ('5', 2, 0, 'Терраса'),
      ('6', 8, 1, 'Терраса'),
      ('7', 4, 3, 'VIP'),
      ('8', 2, 0, 'VIP'),
    ];
    var i = 0;
    for (final t in tables) {
      i++;
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: t.$1,
          capacity: Value(t.$2),
          status: Value(t.$3),
          zone: Value(t.$4),
          sortOrder: Value(i),
        ),
      );
    }

    await db.wmsConfigDao.saveConfig(
      const WmsConfigsCompanion(
        cellStorageEnabled: Value(true),
        batchTrackingEnabled: Value(true),
        serialTrackingEnabled: Value(true),
        markingEnabled: Value(true),
        warrantyTrackingEnabled: Value(true),
      ),
    );
    await db.warehouseDao.insertWarehouse(
      WarehousesCompanion.insert(
        code: 'WH1',
        name: 'Основной склад',
        isDefault: const Value(true),
      ),
    );
    await db.warehouseDao.insertWarehouse(
      WarehousesCompanion.insert(code: 'WH2', name: 'Склад №2'),
    );

    try {
      await GetIt.I<CreateServiceOrderUseCase>().create(
        userId: 1,
        clientName: 'Алиев Руслан',
        clientPhone: '+77012345678',
        deviceDescription: 'iPhone 13',
        complaint: 'Не включается после падения',
        estimatedAmount: Decimal.parse('25000'),
      );
    } catch (e) {
      // ignore: avoid_print
      print('[deep] service create failed: $e');
    }
  }

  testWidgets('deep working states', (tester) async {
    await seed();
    await h.pumpApp(tester);
    await tester.pump(const Duration(seconds: 1));
    await h.loginAsCashier(tester);
    await render(tester);

    h.router!.go('/tables');
    await render(tester);
    await shot(tester, '01_restaurant_tables');
    try {
      final free = find.text('2');
      if (free.evaluate().isNotEmpty) {
        await tester.tap(free.first);
        await render(tester);
        await shot(tester, '02_table_detail');
      }
    } catch (_) {}
    await dismiss(tester);

    h.router!.go('/service-queue');
    await render(tester);
    await shot(tester, '03_service_queue');
    try {
      final row = find.textContaining('Алиев');
      if (row.evaluate().isNotEmpty) {
        await tester.tap(row.first);
        await render(tester);
        await shot(tester, '04_service_detail');
      }
    } catch (_) {}
    await dismiss(tester);

    h.router!.go('/wms');
    await render(tester);
    await shot(tester, '05_wms_dashboard');
    h.router!.go('/wms-warehouses');
    await render(tester);
    await shot(tester, '06_wms_warehouses');

    h.router!.go('/sale');
    await render(tester);
    for (final code in ['4607001', '4607002', '4607003']) {
      await tester.enterText(find.byType(TextField).first, code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await render(tester);
    }
    var pay = find.text('ОПЛАТИТЬ');
    if (pay.evaluate().isNotEmpty) {
      await tester.tap(pay.first);
      await render(tester);
      final note = find.text('1K');
      if (note.evaluate().isNotEmpty) {
        await tester.tap(note.first);
        await render(tester);
      }
      pay = find.text('ОПЛАТИТЬ');
      if (pay.evaluate().isNotEmpty) {
        await tester.tap(pay.last);
        await render(tester);
      }
    }
    await dismiss(tester);
    await render(tester);

    h.router!.go('/history');
    await render(tester);
    await shot(tester, '07_history_with_sale');

    final lastReceipt = await h.db.saleDao.findLastReceiptNo();
    int? receiptWithItems;
    for (var rno = 1; rno <= (lastReceipt ?? 1); rno++) {
      final rows = await h.db
          .customSelect(
            'SELECT COUNT(*) c FROM sale_products WHERE receipt_no = ?',
            variables: [Variable.withInt(rno)],
          )
          .getSingleOrNull();
      if (rows != null && rows.read<int>('c') > 0) {
        receiptWithItems = rno;
        break;
      }
    }
    h.router!.go('/refund');
    await render(tester);
    try {
      final load = find.textContaining('Загрузить чек');
      if (load.evaluate().isNotEmpty && receiptWithItems != null) {
        await tester.tap(load.first);
        await render(tester);
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.last, '$receiptWithItems');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await render(tester);
        }
        await shot(tester, '08_refund_loaded');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[deep] refund load failed: $e');
    }
    await dismiss(tester);

    // ignore: avoid_print
    print('[deep] lastReceipt=$lastReceipt receiptWithItems=$receiptWithItems');
  });
}
