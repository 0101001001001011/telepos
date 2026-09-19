import 'package:decimal/decimal.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';

/// Кассовая реализация [QuickProductCatalog] — задача 8.
///
/// Перенос трёх провайдеров сетки быстрых товаров
/// (`quick_products_grid.dart`: `quickProductCategoriesProvider`,
/// `quickProductsByGroupProvider`, `quickProductsProvider`) один в один, до
/// условия отбора. Единственное объединение: `quickProductsProvider`
/// (все быстрые товары) и `quickProductsByGroupProvider(null)` (корневые)
/// читали **одно и то же** — `findAllByParents()` с отсевом строк без
/// `ucode`; двух смыслов у одного запроса не было, была копия.
class LocalQuickProductCatalog implements QuickProductCatalog {
  LocalQuickProductCatalog({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  @override
  Future<List<QuickProductCategory>> categories() async {
    final all = await _db.quickProductDao.findAllByParents();
    return all
        // Строка без `ucode` — это категория; строка без имени показать
        // нечем.
        .where((qp) => qp.ucode == null && qp.name != null)
        .map((qp) => QuickProductCategory(id: qp.id, name: qp.name!))
        .toList();
  }

  @override
  Future<List<QuickProductItem>> items({int? categoryId}) async {
    final rows = categoryId == null
        ? (await _db.quickProductDao.findAllByParents())
              .where((qp) => qp.ucode != null)
              .toList()
        : await _db.quickProductDao.findAllByParentId(categoryId);

    final result = <QuickProductItem>[];
    for (final qp in rows) {
      final ucode = qp.ucode;
      if (ucode == null) continue;

      // `findByIdAndNotDeleted`: товар, убранный из каталога, кнопкой не
      // показывается — так было и до переноса.
      final info = await _db.productInfoDao.findByIdAndNotDeleted(ucode);
      if (info == null) continue;

      final price = await _db.productPriceDao.findByUcode(ucode);
      result.add(
        QuickProductItem(
          ucode: ucode,
          name: qp.name ?? info.name,
          price: price?.sellingPrice ?? Decimal.zero,
        ),
      );
    }
    return result;
  }
}
