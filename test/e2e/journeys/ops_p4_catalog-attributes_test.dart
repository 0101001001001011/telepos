library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.productPrices).go();
    await h.db.delete(h.db.productInfos).go();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> waitForCatalog(CatalogNotifier c) async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (!container.read(catalogControllerProvider).isLoading) return;
    }
  }

  test('brand / manufacturer / country persist through create, reload into the '
      'form (pre-fill), and re-persist through edit', () async {
    final db = GetIt.I<AppDatabase>();
    final notifier = container.read(catalogControllerProvider.notifier);
    await waitForCatalog(notifier);

    final created = await notifier.createProduct(
      name: 'Кола 0.5',
      type: 0,
      measure: 0,
      sellingPrice: d('350'),
      brand: 'Coca-Cola',
      manufacturer: 'Coca-Cola Almaty Bottlers',
      countryOfOrigin: 'Казахстан',
    );
    expect(created, isTrue, reason: 'createProduct must succeed');

    var rows = await db.productInfoDao.findByNamePart('%Кола%');
    expect(rows, hasLength(1), reason: 'exactly one product created');
    final ucode = rows.first.ucode;
    expect(rows.first.brand, 'Coca-Cola');
    expect(rows.first.manufacturer, 'Coca-Cola Almaty Bottlers');
    expect(rows.first.countryOfOrigin, 'Казахстан');

    await notifier.loadProducts();
    final item = container
        .read(catalogControllerProvider)
        .items
        .firstWhere((i) => i.ucode == ucode);
    expect(
      item.brand,
      'Coca-Cola',
      reason: 'pre-fill source: CatalogItem.brand',
    );
    expect(
      item.manufacturer,
      'Coca-Cola Almaty Bottlers',
      reason: 'pre-fill source: CatalogItem.manufacturer',
    );
    expect(
      item.countryOfOrigin,
      'Казахстан',
      reason: 'pre-fill source: CatalogItem.countryOfOrigin',
    );

    final edited = await notifier.editProduct(
      ucode: ucode,
      brand: 'Pepsi',
      manufacturer: 'PepsiCo Kazakhstan',
      countryOfOrigin: 'Россия',
    );
    expect(edited, isTrue, reason: 'editProduct must succeed');

    rows = await db.productInfoDao.findByNamePart('%Кола%');
    expect(rows.first.brand, 'Pepsi');
    expect(rows.first.manufacturer, 'PepsiCo Kazakhstan');
    expect(rows.first.countryOfOrigin, 'Россия');

    await notifier.loadProducts();
    final reloaded = container
        .read(catalogControllerProvider)
        .items
        .firstWhere((i) => i.ucode == ucode);
    expect(reloaded.brand, 'Pepsi');
    expect(reloaded.manufacturer, 'PepsiCo Kazakhstan');
    expect(reloaded.countryOfOrigin, 'Россия');
  });
}
