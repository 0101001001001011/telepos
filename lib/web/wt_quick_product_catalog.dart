import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Быстрые товары с браузерного терминала — вторая реализация
/// [QuickProductCatalog] (задача 45). Первая — кассовая
/// `LocalQuickProductCatalog`.
///
/// **Касса владеет каталогом.** Сетка на терминале читает ту же таблицу
/// `QuickProducts`, что и на кассе, по проводу, а не свою копию: копия
/// разошлась бы с кассой на первой же правке кнопки.
///
/// До задачи 45 реализации не было, и экран продажи прятал кнопку проверкой
/// `isRegistered<QuickProductCatalog>()` — ошибка сборки контейнера была
/// режимом работы. Теперь кнопка стоит всегда, а незаведённую привязку ловит
/// сторож `browser_routes_test.dart`.
///
/// Отказ кассы приходит [WireRefusal] с кодом кассы — тем же приёмом, что у
/// `WtSaleEditTerms`.
class WtQuickProductCatalog implements QuickProductCatalog {
  WtQuickProductCatalog(this._wire);

  final WtDispatcher _wire;

  @override
  Future<List<QuickProductCategory>> categories() async {
    try {
      return await _wire.ask(SaleOps.quickCategories, null);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  @override
  Future<List<QuickProductItem>> items({int? categoryId}) async {
    try {
      return await _wire.ask(SaleOps.quickItems, categoryId);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }
}
