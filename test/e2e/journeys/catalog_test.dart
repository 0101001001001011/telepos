library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;

import '../pages/catalog_page.dart';
import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  bool talkerReady = false;
  Future<void> localSetUp() async {
    SharedPreferences.setMockInitialValues(const {});
    if (!talkerReady) {
      try {
        app_log.installLogger(Talker());
      } on Error {}
      talkerReady = true;
    }
    GetIt.I.allowReassignment = true;
    h.db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    // Задача 12: `login()` ниже жмёт настоящий вход, и `getPostLoginRoute()`
    // спрашивает `GetIt<HostCapabilities>` — см. `harness.dart` для полного
    // обоснования.
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    await seed(h.db);
    await _openShift(h.db);
  }

  setUp(localSetUp);
  tearDown(() => h.tearDown());

  Future<void> pumpFor(
    WidgetTester tester, {
    int frames = 12,
    Duration step = const Duration(milliseconds: 150),
  }) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(step);
    }
  }

  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> goToCatalog(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).go(AppRoutes.catalog);
    for (
      int i = 0;
      i < 24 && find.text(CatalogPage.title).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await pumpFor(tester);
  }

  Future<bool> login(WidgetTester tester) async {
    for (
      int i = 0;
      i < 40 && find.text(E2eHarness.cashierName).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    final userTile = find.text(E2eHarness.cashierName);
    if (userTile.evaluate().isEmpty) return false;
    await tester.tap(userTile.first);
    await pumpFor(tester);

    final noPinBtn = find.widgetWithText(ElevatedButton, 'Войти без PIN');
    final enterBtn = find.widgetWithText(ElevatedButton, 'Войти');
    if (noPinBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(noPinBtn.first);
      await tester.pump();
      await tester.tap(noPinBtn.first);
    } else if (enterBtn.evaluate().isNotEmpty) {
      await tester.tap(enterBtn.first);
    } else {
      for (int i = 0; i < 4; i++) {
        final zero = find.text('0');
        if (zero.evaluate().isNotEmpty) {
          await tester.tap(zero.first);
          await tester.pump(const Duration(milliseconds: 80));
        }
      }
    }
    await pumpFor(tester, frames: 16);
    if (find.byType(Scaffold).evaluate().isEmpty) return false;
    final ctx = tester.element(find.byType(Scaffold).first);
    final loc = GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.path;
    return loc != '/login' && loc != '/';
  }

  Future<CatalogPage> reachCatalog(WidgetTester tester) async {
    await h.pumpApp(tester);
    final loggedIn = await login(tester);
    expect(loggedIn, isTrue, reason: 'must reach a post-login surface');
    useDesktopSurface(tester);
    await pumpFor(tester);
    await goToCatalog(tester);
    final page = CatalogPage(tester);
    expect(
      find.text(CatalogPage.title),
      findsWidgets,
      reason: 'catalog screen must render its title',
    );
    return page;
  }

  group('Catalog journey', () {
    testWidgets('READ: seeded products render in the catalog list', (
      tester,
    ) async {
      final page = await reachCatalog(tester);

      expect(page.productVisible('Молоко 1л'), isTrue);
      expect(page.productVisible('Хлеб белый'), isTrue);
      expect(page.productVisible('Яйца 10шт'), isTrue);
      expect(
        find.text('450'),
        findsWidgets,
        reason: 'seeded milk price 450 must render exactly',
      );
    });

    testWidgets(
      'CREATE valid: new product is saved, shown, and persisted to DB',
      (tester) async {
        final page = await reachCatalog(tester);

        const name = 'Кофе молотый';
        const price = '1250';

        await page.createProduct(name: name, price: price);

        expect(
          find.text(CatalogPage.productCreated),
          findsWidgets,
          reason: 'creating must surface "Товар создан"',
        );

        expect(
          page.productVisible(name),
          isTrue,
          reason: 'new product must appear in the catalog list',
        );

        final infos = await h.db.productInfoDao.findByNamePart('%$name%');
        expect(infos, isNotEmpty, reason: 'product_infos row must exist');
        final created = infos.first;
        final priceRow = await h.db.productPriceDao.findByUcode(created.ucode);
        expect(priceRow, isNotNull, reason: 'product_prices row must exist');
        expect(
          priceRow!.sellingPrice,
          Decimal.parse(price),
          reason: 'selling price must persist exactly (no rounding drift)',
        );
      },
    );

    testWidgets('CREATE invalid: empty name + bad price block save', (
      tester,
    ) async {
      final page = await reachCatalog(tester);

      final beforeCount = await h.db.productInfoDao.countFiltered(
        includeDeleted: true,
      );

      await page.openCreate();
      await page.enterName('');
      await page.enterPrice('0');
      await page.submitForm();

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'invalid form must NOT close the dialog',
      );
      final hasNameError = find
          .text(CatalogPage.nameRequired)
          .evaluate()
          .isNotEmpty;
      final hasPriceError =
          find.text(CatalogPage.priceInvalid).evaluate().isNotEmpty ||
          find.text(CatalogPage.priceRequired).evaluate().isNotEmpty;
      expect(
        hasNameError,
        isTrue,
        reason: 'empty name must show "Введите название"',
      );
      expect(
        hasPriceError,
        isTrue,
        reason: 'zero/empty price must show a price validation error',
      );

      final afterCount = await h.db.productInfoDao.countFiltered(
        includeDeleted: true,
      );
      expect(
        afterCount,
        beforeCount,
        reason: 'invalid input must NOT create a product',
      );

      await page.cancelForm();
    });

    testWidgets('READ/search: searching narrows the list to the match', (
      tester,
    ) async {
      final page = await reachCatalog(tester);

      await page.search('Хлеб');
      expect(
        page.productVisible('Хлеб белый'),
        isTrue,
        reason: 'search must find the matching product',
      );
      expect(
        page.productVisible('Молоко 1л'),
        isFalse,
        reason: 'non-matching products must be filtered out',
      );

      await page.clearSearch();
      expect(
        page.productVisible('Молоко 1л'),
        isTrue,
        reason: 'clearing search must restore the full list',
      );
    });

    testWidgets('UPDATE: editing the price persists and is reflected', (
      tester,
    ) async {
      final page = await reachCatalog(tester);

      const target = 'Сахар 1кг';
      const newPrice = '333';

      final before = await h.db.productPriceDao.findByUcode(1003);
      expect(before!.sellingPrice, Decimal.parse('280'));

      await page.openEdit(target);
      await page.enterPrice(newPrice);
      await page.submitForm();

      expect(
        find.text(CatalogPage.productUpdated),
        findsWidgets,
        reason: 'update must surface "Товар обновлён"',
      );

      final after = await h.db.productPriceDao.findByUcode(1003);
      expect(
        after!.sellingPrice,
        Decimal.parse(newPrice),
        reason: 'edited price must persist exactly',
      );

      expect(
        find.text(newPrice),
        findsWidgets,
        reason: 'new price must render in the catalog table',
      );
    });

    testWidgets(
      'DELETE + RESTORE: soft-delete removes from active list, restore brings back',
      (tester) async {
        final page = await reachCatalog(tester);

        const target = 'Масло сливочное';
        const ucode = 1004;

        expect(page.productVisible(target), isTrue);

        await page.deleteProduct(target);
        expect(
          find.text(CatalogPage.productDeleted),
          findsWidgets,
          reason: 'delete must surface "Товар удалён"',
        );

        final deleted = await h.db.productInfoDao.findByUcode(ucode);
        expect(
          deleted,
          isNotNull,
          reason: 'soft-delete must keep the row in the DB',
        );
        expect(
          deleted!.isDeleted,
          isTrue,
          reason: 'product must be flagged isDeleted=true',
        );

        expect(
          page.productVisible(target),
          isFalse,
          reason: 'deleted product must leave the active list',
        );

        final toggled = await page.toggleShowDeleted();
        expect(
          toggled,
          isTrue,
          reason: 'a "show deleted" filter must exist to reach restore',
        );
        expect(
          page.productVisible(target),
          isTrue,
          reason: 'deleted product must appear when "show deleted" is on',
        );

        await page.restoreProduct(target);
        expect(
          find.text(CatalogPage.productRestored),
          findsWidgets,
          reason: 'restore must surface "Товар восстановлен"',
        );

        final restored = await h.db.productInfoDao.findByUcode(ucode);
        expect(
          restored!.isDeleted,
          isFalse,
          reason: 'restore must clear the isDeleted flag',
        );
      },
    );

    testWidgets(
      'CREATE category: new category persists via the editor dialog',
      (tester) async {
        final page = await reachCatalog(tester);

        const catName = 'Напитки';
        final before = await h.db.categoryDao.findAll(limit: 10000);
        expect(
          before.any((c) => c.name == catName),
          isFalse,
          reason: 'category must not exist yet',
        );

        await page.openCategoryEditor();
        await page.addCategoryInEditor(catName);

        final after = await h.db.categoryDao.findAll(limit: 10000);
        expect(
          after.any((c) => c.name == catName),
          isTrue,
          reason: 'new category must be saved to the categories table',
        );

        expect(
          find.text(catName),
          findsWidgets,
          reason: 'new category must render in the editor',
        );

        await page.closeCategoryEditor();
      },
    );

    testWidgets('EMPTY: with no products, a real empty-state is shown', (
      tester,
    ) async {
      await _wipeProducts(h.db);

      final page = await reachCatalog(tester);

      expect(
        page.isEmptyState,
        isTrue,
        reason: 'empty catalog must show the "Нет товаров" empty-state',
      );
      expect(page.productVisible('Молоко 1л'), isFalse);
    });
  });
}

Future<void> _openShift(AppDatabase db) async {
  final users = await db.userDao.findAll();
  final cashier = users.firstWhere(
    (u) => u.name == E2eHarness.cashierName,
    orElse: () => users.first,
  );
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  await db.shiftDao.insertShift(
    ShiftsCompanion(
      userId: Value(cashier.id),
      openTime: Value(now),
      isOpened: const Value(true),
      openingCash: Value(Decimal.zero),
      isSynced: const Value(false),
    ),
  );
}

Future<void> _wipeProducts(AppDatabase db) async {
  await db.delete(db.quickProducts).go();
  await db.delete(db.productPrices).go();
  await db.delete(db.productInfos).go();
}
