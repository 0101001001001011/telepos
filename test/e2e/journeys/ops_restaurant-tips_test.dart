library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/add_items_to_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/create_table_order_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart' show AppLocalizations;

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.guestSplits).go();
    await h.db.delete(h.db.restaurantOrders).go();
    await h.db.delete(h.db.restaurantTables).go();
    await h.db.delete(h.db.saleProducts).go();
    await h.db.delete(h.db.sales).go();
    await h.db.delete(h.db.shifts).go();
  });

  Future<void> setDesktopSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> settle(WidgetTester tester, {int frames = 16}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 150));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  Future<void> openShiftInDb(AppDatabase db) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: 1,
            openTime: nowSec - 5,
            isOpened: true,
            isSynced: false,
          ),
        );
  }

  Future<({int tableId, int orderId})> seedTableOrderWithItem(
    AppDatabase db,
  ) async {
    final tableId = await db
        .into(db.restaurantTables)
        .insert(
          RestaurantTablesCompanion.insert(name: '1', zone: const Value('Зал')),
        );

    final order = await GetIt.I<CreateTableOrderUseCase>().create(
      tableId: tableId,
      partySize: 2,
      orderType: OrderType.dineIn,
    );

    await GetIt.I<AddItemsToOrderUseCase>().addItem(
      orderId: order.id,
      productUcode: 1001,
      quantity: Decimal.one,
      price: Decimal.parse('450'),
      guestNumber: 0,
    );

    return (tableId: tableId, orderId: order.id);
  }

  Future<void> pumpAtTable(WidgetTester tester, int tableId) async {
    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          supportedLocales: AppLocale.supportedLocales,
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pump();
    await settle(tester, frames: 20);
    router.go('/tables/$tableId');
    await settle(tester, frames: 20);
  }

  Future<Decimal?> readTips(AppDatabase db, int orderId) async {
    final order = await db.restaurantOrderDao.findById(orderId);
    return order?.tips;
  }

  testWidgets(
    'settling a table with a 500 tip persists restaurant_orders.tips == 500',
    (tester) async {
      await setDesktopSurface(tester);

      final db = GetIt.I<AppDatabase>();
      await openShiftInDb(db);
      final seeded = await seedTableOrderWithItem(db);

      expect(
        await readTips(db, seeded.orderId),
        isNull,
        reason: 'no tip captured before settlement',
      );

      await pumpAtTable(tester, seeded.tableId);

      await pumpUntilFound(tester, find.text('450'));
      expect(
        find.text('450'),
        findsWidgets,
        reason: 'seeded order item total (450) must render',
      );

      final payBtn = find.text('К оплате');
      await pumpUntilFound(tester, payBtn);
      expect(payBtn, findsWidgets, reason: 'payment action must be present');
      await tester.tap(payBtn.first);
      await settle(tester);

      final tipField = find.byKey(const Key('restaurant.tips.field'));
      await pumpUntilFound(tester, tipField);
      expect(
        tipField,
        findsOneWidget,
        reason: 'settlement must prompt for tips (чаевые)',
      );

      for (final ch in '500'.split('')) {
        final digit = find.widgetWithText(ElevatedButton, ch);
        expect(digit, findsWidgets, reason: 'NumPad must expose a "$ch" key');
        await tester.tap(digit.first);
        await tester.pump();
      }
      await settle(tester);

      final confirm = find.byKey(const Key('restaurant.tips.confirm'));
      expect(confirm, findsOneWidget, reason: 'tips confirm button present');
      await tester.tap(confirm);
      await settle(tester);

      final persisted = await readTips(db, seeded.orderId);
      expect(
        persisted,
        isNotNull,
        reason: 'tip must be captured at settlement',
      );
      expect(
        persisted,
        Decimal.parse('500'),
        reason:
            'restaurant_orders.tips must be exactly 500 (Decimal, no drift)',
      );
    },
  );

  testWidgets(
    'skipping tips ("Без чаевых") leaves restaurant_orders.tips NULL',
    (tester) async {
      await setDesktopSurface(tester);

      final db = GetIt.I<AppDatabase>();
      await openShiftInDb(db);
      final seeded = await seedTableOrderWithItem(db);

      await pumpAtTable(tester, seeded.tableId);
      await pumpUntilFound(tester, find.text('450'));

      final payBtn = find.text('К оплате');
      await pumpUntilFound(tester, payBtn);
      await tester.tap(payBtn.first);
      await settle(tester);

      final skip = find.byKey(const Key('restaurant.tips.skip'));
      await pumpUntilFound(tester, skip);
      expect(skip, findsOneWidget, reason: 'skip-tips action present');
      await tester.tap(skip);
      await settle(tester);

      expect(
        await readTips(db, seeded.orderId),
        isNull,
        reason: 'skipping tips must leave restaurant_orders.tips NULL',
      );
    },
  );
}
