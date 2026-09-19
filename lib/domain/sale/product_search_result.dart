import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Найденный товар в том виде, в каком его показывает экран продажи:
/// имя, цена, остаток.
///
/// **Откуда переехал (задача 7).** Класс жил в
/// `lib/presentation/controllers/sale/sale_controller.dart` — то есть
/// в презентационном слое, куда браузерный терминал не ходит. Контракт
/// `CartService.search()` обязан вернуть именно его (бриф задачи 7), а
/// контракт — чистый Dart без Flutter; значит тип обязан жить в домене,
/// иначе домен зависел бы от экрана. Сам `sale_controller.dart` его
/// теперь реэкспортирует (`export`), поэтому ни один экран, знающий это
/// имя через контроллер, править не пришлось.
///
/// **Почему это не тот же `ProductSearchResult`, что в
/// `domain/usecases/product/search_product_info_use_case.dart`.** Тот —
/// строка каталога: `ucode`, `barcode` числом, `type`, `categoryId`, и
/// **без цены**. Этот — то, что кассир видит в списке поиска: цена и
/// остаток, уже собранные из двух таблиц (`ProductPrices`,
/// `ProductInfos`). Слить их в один тип означало бы заставить каталог
/// таскать цену, которой у него нет, — поэтому два типа, как и было до
/// переезда.
@immutable
class ProductSearchResult {
  const ProductSearchResult({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
    this.stock,
    this.isDeleted = false,
    this.measure = 0,
  });

  /// `ucode` товара.
  final int id;

  final String name;

  /// Цена продажи. Деньги — `Decimal` P18,S3, никогда `double`.
  final Decimal price;

  final String? barcode;

  /// Остаток на кассе, если известен.
  final Decimal? stock;

  /// Единица измерения; ненулевая означает весовой товар.
  final int measure;

  final bool isDeleted;

  /// Сравнение по значению — тем же приёмом, что `CartLine`, `CartView`,
  /// `CartCommandMeta` и `DeferredCart` (`cart_view.dart`, круг правки 1
  /// задачи 6).
  ///
  /// **Заведено кругом правки 1 задачи 9, и вот чем измерена нужда.** Этот
  /// тип был единственным из четырёх, едущих по проводу, без сравнения по
  /// значению — значит проба кругового обмена (`sale_ops_access_test.dart`)
  /// вынуждена была сверять поля руками, и два из семи в неё не попали.
  /// Диверсия разбора: декодер, прибитый к `measure: 0`, оставлял **171
  /// тест зелёным**. Ненулевая мера означает весовой товар, и её потеря
  /// делает весовой товар штучным на терминале — то есть кассир взвешивает
  /// килограмм, а чек считает одну штуку.
  ///
  /// Сравнение по значению здесь безопасно: тип неизменяемый и нигде не
  /// служит ключом множества или карты (проверено обходом всех вызывающих
  /// в `lib/` — `local_cart_service.dart`,
  /// `search_product_info_use_case_impl.dart` и экраны только строят списки).
  @override
  bool operator ==(Object other) =>
      other is ProductSearchResult &&
      other.id == id &&
      other.name == name &&
      other.price == price &&
      other.barcode == barcode &&
      other.stock == stock &&
      other.measure == measure &&
      other.isDeleted == isDeleted;

  @override
  int get hashCode =>
      Object.hash(id, name, price, barcode, stock, measure, isDeleted);
}
