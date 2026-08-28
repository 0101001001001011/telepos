library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/inventory/inventory_screen.dart';

import '../pages/inventory_page.dart';
import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  const milkBarcode = '4607001';
  const milkName = 'Молоко 1л';
  const milkUcode = 1001;
  const breadUcode = 1002;

  Future<void> resetState() async {
    await h.db.delete(h.db.inventoryProducts).go();
    await h.db.delete(h.db.inventories).go();
    for (final ucode in [1001, 1002, 1003, 1004, 1005]) {
      await (h.db.update(h.db.productInfos)
            ..where((p) => p.ucode.equals(ucode)))
          .write(ProductInfosCompanion(quantity: Value(d('100'))));
    }
  }

  Future<void> pumpInventory(WidgetTester tester) async {
    await resetState();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          supportedLocales: AppLocale.supportedLocales,
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const InventoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Inventory journey', () {
    testWidgets('Empty: inactive inventory shows a real start empty-state', (
      tester,
    ) async {
      await pumpInventory(tester);
      final page = InventoryPage(tester);

      expect(
        page.isInactiveEmptyState,
        isTrue,
        reason: 'inactive inventory must render the press-start empty-state',
      );
      expect(page.startButton, findsOneWidget);
      expect(page.isActive, isFalse);
    });

    testWidgets(
      'Create + flow: start, scan a product, complete -> stock written back',
      (tester) async {
        await pumpInventory(tester);
        final page = InventoryPage(tester);

        await page.start();
        expect(
          page.isActive,
          isTrue,
          reason: 'after start, the scan field must appear',
        );

        final active = await h.db.inventoryDao.findActive();
        expect(
          active,
          isNotNull,
          reason: 'startNew must persist an inventory row',
        );

        await page.scan(milkBarcode);
        page.expectProductVisible(milkName);
        page.expectDifference('-99');

        final invId = active!.id;
        final invProducts = await h.db.inventoryProductDao.findByInventoryId(
          invId,
        );
        expect(invProducts, hasLength(1));
        final row = invProducts.single;
        expect(row.ucode, milkUcode);
        expect(
          row.expectedQty,
          d('100'),
          reason: 'expected qty must come from current on-hand',
        );
        expect(
          row.actualQty,
          d('1'),
          reason: 'first scan counts exactly 1 unit',
        );

        final milkBefore = await h.db.productInfoDao.findByUcode(milkUcode);
        final breadBefore = await h.db.productInfoDao.findByUcode(breadUcode);
        expect(milkBefore!.quantity, d('100'));
        expect(breadBefore!.quantity, d('100'));

        await page.complete();

        expect(
          find.textContaining(InventoryPage.completedSnack),
          findsWidgets,
          reason: 'completion must surface a success snackbar',
        );

        final completed = await h.db.inventoryDao.findById(invId);
        expect(
          completed!.status,
          1,
          reason: 'inventory must be marked completed',
        );

        final milkAfter = await h.db.productInfoDao.findByUcode(milkUcode);
        expect(
          milkAfter!.quantity,
          d('1'),
          reason: 'completing must write counted qty (1) back to on-hand',
        );

        final breadAfter = await h.db.productInfoDao.findByUcode(breadUcode);
        expect(
          breadAfter!.quantity,
          d('100'),
          reason: 'partial count must NOT zero un-counted SKUs (guards #27)',
        );
      },
    );

    testWidgets('Flow: repeated scans of same barcode accumulate counted qty', (
      tester,
    ) async {
      await pumpInventory(tester);
      final page = InventoryPage(tester);

      await page.start();
      await page.scan(milkBarcode);
      await page.scan(milkBarcode);
      await page.scan(milkBarcode);

      final active = await h.db.inventoryDao.findActive();
      final rows = await h.db.inventoryProductDao.findByInventoryId(active!.id);
      expect(
        rows,
        hasLength(1),
        reason: 'rescanning the same SKU must update, not duplicate',
      );
      expect(
        rows.single.actualQty,
        d('3'),
        reason: 'each scan increments counted qty by 1',
      );

      page.expectDifference('-97');
    });

    testWidgets('Error: scanning an unknown barcode surfaces an honest error', (
      tester,
    ) async {
      await pumpInventory(tester);
      final page = InventoryPage(tester);

      await page.start();
      await page.scan('9999999');

      expect(
        find.textContaining('9999999'),
        findsWidgets,
        reason: 'unknown barcode must surface a not-found error',
      );
      final active = await h.db.inventoryDao.findActive();
      final rows = await h.db.inventoryProductDao.findByInventoryId(active!.id);
      expect(rows, isEmpty, reason: 'unknown barcode must not add a line');
    });

    testWidgets(
      'Partial (default): un-counted SKUs keep their qty (guards #27)',
      (tester) async {
        await pumpInventory(tester);
        final page = InventoryPage(tester);

        expect(
          page.fullCountToggle,
          findsOneWidget,
          reason: 'the inactive empty-state must expose a full/partial toggle',
        );

        await page.start();
        final active = await h.db.inventoryDao.findActive();
        expect(
          active!.isFullCount,
          isFalse,
          reason: 'default (toggle off) must create a selective/partial count',
        );

        await page.scan(milkBarcode);
        await page.complete();

        final milkAfter = await h.db.productInfoDao.findByUcode(milkUcode);
        expect(milkAfter!.quantity, d('1'));

        final breadAfter = await h.db.productInfoDao.findByUcode(breadUcode);
        expect(
          breadAfter!.quantity,
          d('100'),
          reason: 'partial count must NOT zero un-counted SKUs (guards #27)',
        );
      },
    );

    testWidgets(
      'Full count: toggle ON -> completing zeros un-counted SKUs (#27)',
      (tester) async {
        await pumpInventory(tester);
        final page = InventoryPage(tester);

        await page.enableFullCount();
        await page.start();

        final active = await h.db.inventoryDao.findActive();
        expect(
          active!.isFullCount,
          isTrue,
          reason: 'flipping the toggle must create a FULL count',
        );

        await page.scan(milkBarcode);
        await page.complete();

        final milkAfter = await h.db.productInfoDao.findByUcode(milkUcode);
        expect(milkAfter!.quantity, d('1'));

        final breadAfter = await h.db.productInfoDao.findByUcode(breadUcode);
        expect(
          breadAfter!.quantity,
          d('0'),
          reason: 'full count must zero un-counted SKUs',
        );
      },
    );
  });
}
