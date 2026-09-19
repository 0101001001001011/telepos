import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_quick_product_catalog.dart';

/// Сетка быстрых товаров за контрактом — задача 8.
///
/// Три провайдера виджета читали три DAO напрямую и красили сторожа слоёв
/// узла продажи. Перенос проверяется не «метод отвечает списком», а тем,
/// что отбор остался прежним: категория — строка **без** `ucode`, товар,
/// убранный из каталога, кнопкой не показывается, цена берётся из
/// `ProductPrices`.
void main() {
  late AppDatabase db;
  late LocalQuickProductCatalog catalog;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> seedProduct({
    required int ucode,
    required int barcode,
    required String name,
    String price = '100',
    bool deleted = false,
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: barcode,
            name: name,
            type: 0,
            measure: 0,
            isDeleted: Value(deleted),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: Value(ucode),
            barcode: barcode,
            sellingPrice: Value(d(price)),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    catalog = LocalQuickProductCatalog(db: db);

    await seedProduct(ucode: 10, barcode: 4870000000010, name: 'Молоко');
    await seedProduct(
      ucode: 20,
      barcode: 4870000000020,
      name: 'Хлеб',
      price: '250',
    );
    await seedProduct(
      ucode: 30,
      barcode: 4870000000030,
      name: 'Снятый с продажи',
      deleted: true,
    );

    // Категория — строка без `ucode`.
    await db.quickProductDao.createCategory(name: 'Напитки');
    // Товар в корне.
    await db.quickProductDao.addQuickProduct(ucode: 10, orderName: 'Молоко');
    // Товар, которого больше нет в каталоге, — тоже в корне.
    await db.quickProductDao.addQuickProduct(
      ucode: 30,
      orderName: 'Снятый с продажи',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('категории — только строки без товара', () async {
    final categories = await catalog.categories();

    expect(categories.map((c) => c.name), ['Напитки']);
    // Товары в список категорий не попадают: у кнопки «Молоко» есть
    // `ucode`, и категорией она не является.
    expect(categories.map((c) => c.name), isNot(contains('Молоко')));
  });

  test('удалённый товар кнопкой не показывается', () async {
    final items = await catalog.items();

    expect(items.map((i) => i.ucode), [
      10,
    ], reason: 'кнопка ведёт в товар, которого нет в каталоге');
    expect(items.single.name, 'Молоко');
    expect(items.single.price, d('100'));
  });

  test('товары категории отбираются по ней, а не по всему дереву', () async {
    final categories = await catalog.categories();
    final drinks = categories.single.id;
    await db.quickProductDao.addQuickProduct(
      ucode: 20,
      parentId: drinks,
      orderName: 'Хлеб',
    );

    final inCategory = await catalog.items(categoryId: drinks);
    expect(inCategory.map((i) => i.ucode), [20]);
    expect(inCategory.single.price, d('250'));

    // Корень при этом не вобрал товар категории.
    final root = await catalog.items();
    expect(root.map((i) => i.ucode), [10]);
  });

  test('товар без цены показывается нулём, а не пропадает', () async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(40),
            barcode: 4870000000040,
            name: 'Без цены',
            type: 0,
            measure: 0,
          ),
        );
    await db.quickProductDao.addQuickProduct(ucode: 40, orderName: 'Без цены');

    final items = await catalog.items();
    final free = items.firstWhere((i) => i.ucode == 40);
    expect(free.price, Decimal.zero);
  });
}
