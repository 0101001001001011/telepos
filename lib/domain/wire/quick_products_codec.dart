/// Кодек быстрых товаров (`QuickProductCatalog`) — ответы операций
/// `sale.quickCategories` и `sale.quickItems`, задача 45.
///
/// Цена кнопки — деньги: строкой через [wireMoney] и обратно `Decimal.parse`
/// (I159). Разбор строгий, тем же правилом, что у `sale_terms_codec.dart`:
/// кадр без поля — чужая форма ответа, а не «умолчание».
library;

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/wire/wire_money.dart';

const quickCategoriesKey = 'categories';
const quickItemsKey = 'items';

/// Довод `sale.quickItems`: категория, `null` — корень. Ключ есть всегда:
/// пропущенный ключ и корень — разные вещи, и касса отличает одно от другого.
const quickItemsCategoryKey = 'categoryId';

Map<String, Object?> quickCategoriesToWireJson(
  List<QuickProductCategory> categories,
) => {
  quickCategoriesKey: [
    for (final category in categories)
      {'id': category.id, 'name': category.name},
  ],
};

List<QuickProductCategory> quickCategoriesFromWireJson(
  Map<String, Object?> body,
) => [
  for (final raw in body[quickCategoriesKey]! as List)
    _category((raw as Map).cast<String, Object?>()),
];

QuickProductCategory _category(Map<String, Object?> json) =>
    QuickProductCategory(id: json['id']! as int, name: json['name']! as String);

Map<String, Object?> quickItemsToWireJson(List<QuickProductItem> items) => {
  quickItemsKey: [
    for (final item in items)
      {'ucode': item.ucode, 'name': item.name, 'price': wireMoney(item.price)},
  ],
};

List<QuickProductItem> quickItemsFromWireJson(Map<String, Object?> body) => [
  for (final raw in body[quickItemsKey]! as List)
    _item((raw as Map).cast<String, Object?>()),
];

QuickProductItem _item(Map<String, Object?> json) => QuickProductItem(
  ucode: json['ucode']! as int,
  name: json['name']! as String,
  price: Decimal.parse(json['price']! as String),
);

Map<String, Object?> quickItemsRequestToWireJson(int? categoryId) => {
  quickItemsCategoryKey: categoryId,
};
