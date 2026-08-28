library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/data/database/app_database.dart';

import 'support/harness.dart';

/// Produces the screenshots used by README.md, driving the real application
/// through the real DI graph. Run with:
///
///   flutter test test/e2e/ui_showcase_test.dart --update-goldens
///
/// Unlike ui_tour_test.dart — which sweeps every route to catch regressions —
/// this file covers a curated set in English with demo data loaded, so the
/// screens show a working till rather than empty states.
void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    await _translateSeedToEnglish(h.db);
  });
  tearDownAll(() => h.tearDown());

  Future<void> render(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );
  }

  Future<void> addByBarcode(WidgetTester tester, String code) async {
    final search = find.byType(TextField);
    if (search.evaluate().isEmpty) return;
    await tester.enterText(search.first, code);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await render(tester);
  }

  Future<void> dismissModals(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      if (find.byType(Navigator).evaluate().isEmpty) break;
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('capture README screenshots', (tester) async {
    await h.pumpApp(tester, locale: 'en');
    await tester.pump(const Duration(seconds: 1));
    await render(tester);

    await shot(tester, '01-login');

    await _loginAsDemoCashier(tester);
    await render(tester);

    // --- Sale with a populated receipt -----------------------------------
    h.router!.go('/sale');
    await render(tester);
    await addByBarcode(tester, '4607001');
    await addByBarcode(tester, '4607002');
    await addByBarcode(tester, '4607005');
    await shot(tester, '02-sale');

    // --- Payment, reached from the populated cart ------------------------
    var payButton = find.widgetWithIcon(ElevatedButton, Icons.payment);
    if (payButton.evaluate().isEmpty) payButton = find.text('PAY');
    if (payButton.evaluate().isNotEmpty) {
      await tester.tap(payButton.first);
      await render(tester);
      await shot(tester, '03-payment');
      await dismissModals(tester);
    }

    const routes = <(String, String)>[
      ('/shift', '04-shift'),
      ('/history', '05-history'),
      ('/reports', '06-reports'),
      ('/catalog', '07-catalog'),
      ('/supply', '08-supply'),
      ('/stock-registry', '09-stock'),
      ('/tables', '10-restaurant-tables'),
      ('/service-queue', '11-service-queue'),
      ('/wms', '12-warehouse'),
      ('/promotions', '13-promotions'),
      ('/telegram-settings', '14-telegram'),
      ('/settings', '15-settings'),
    ];

    for (final (route, name) in routes) {
      h.router!.go(route);
      await render(tester);
      await shot(tester, name);
      await dismissModals(tester);
    }
  });

  /// Тёмная тема и развёрнутая колонка — второй набор снимков.
  ///
  /// Снимается отдельным тестом, а не флагом внутри первого, по двум
  /// причинам. Первая: тема и состояние колонки живут в `SharedPreferences`,
  /// то есть читаются при построении дерева — переключить их посреди прогона
  /// значит перестраивать приложение целиком, что и делает отдельный тест,
  /// только честнее. Вторая: колонка по умолчанию свёрнута, и светлый набор
  /// показывает продукт таким, каким его увидят, а развёрнутая нужна ровно
  /// один раз — чтобы читатель увидел названия разделов.
  testWidgets('capture dark-theme screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'nav_collapsed': false,
    });

    await h.pumpApp(tester, locale: 'en');
    await tester.pump(const Duration(seconds: 1));
    await render(tester);

    await shot(tester, '20-login-dark');

    await _loginAsDemoCashier(tester);
    await render(tester);

    h.router!.go('/sale');
    await render(tester);
    await addByBarcode(tester, '4607001');
    await addByBarcode(tester, '4607002');
    await addByBarcode(tester, '4607005');
    await shot(tester, '21-sale-dark');

    const darkRoutes = <(String, String)>[
      ('/catalog', '22-catalog-dark'),
      ('/reports', '23-reports-dark'),
      ('/wms', '24-warehouse-dark'),
      ('/settings', '25-settings-dark'),
    ];

    for (final (route, name) in darkRoutes) {
      h.router!.go(route);
      await render(tester);
      await shot(tester, name);
      await dismissModals(tester);
    }
  });
}

Future<void> _loginAsDemoCashier(WidgetTester tester) async {
  final tile = find.text(_cashierName);
  if (tile.evaluate().isEmpty) return;
  await tester.tap(tile.first);
  await tester.pumpAndSettle();

  for (var i = 0; i < 4; i++) {
    final zero = find.text('0');
    if (zero.evaluate().isNotEmpty) {
      await tester.tap(zero.first);
      await tester.pump(const Duration(milliseconds: 80));
    }
  }
  await tester.pumpAndSettle(const Duration(seconds: 1));

  final noPin = find.text('Login without PIN');
  if (noPin.evaluate().isNotEmpty) {
    await tester.tap(noPin.first);
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

const _cashierName = 'Alice Weber';

/// The shared harness seeds a Russian catalog. Rename the rows in place rather
/// than reseeding, so the price and stock rows keyed to them stay intact.
Future<void> _translateSeedToEnglish(AppDatabase db) async {
  await db
      .update(db.thisPosEntries)
      .write(const ThisPosEntriesCompanion(companyName: Value('Northwind')));

  await db
      .update(db.users)
      .write(const UsersCompanion(name: Value(_cashierName)));

  await db
      .update(db.categories)
      .write(const CategoriesCompanion(name: Value('Groceries')));

  const names = {
    1001: 'Milk 1L',
    1002: 'White bread',
    1003: 'Sugar 1kg',
    1004: 'Butter 200g',
    1005: 'Eggs, 10 pcs',
  };
  for (final entry in names.entries) {
    await (db.update(db.productInfos)
          ..where((p) => p.ucode.equals(entry.key)))
        .write(ProductInfosCompanion(name: Value(entry.value)));
  }
}
