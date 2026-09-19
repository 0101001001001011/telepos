import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Быстрые товары экрана продажи — задача 8 плана «Продажа с браузерного
/// терминала».
///
/// Сетка быстрых товаров (`quick_products_grid.dart`) читала три DAO
/// напрямую — `quickProductDao`, `productPriceDao`, `productInfoDao`, — и
/// была одним из трёх файлов, которые красили сторожа слоёв узла продажи.
/// Контракт заведён затем же, зачем `CartService`: у браузерного терминала
/// той базы нет, а сетка ему нужна та же.
///
/// **Почему это не `CatalogController` и не поиск.** Быстрые товары — не
/// подмножество каталога и не результат поиска: это отдельная таблица
/// `QuickProducts` с собственным деревом (категория — строка без `ucode`),
/// собственным порядком (`orderName`) и признаком активности. Читать её
/// через поиск было бы вторым смыслом у чужого вопроса.
abstract interface class QuickProductCatalog {
  /// Категории верхнего уровня — то, чем размечена сетка.
  Future<List<QuickProductCategory>> categories();

  /// Товары категории [categoryId]; `null` — все, лежащие в корне.
  ///
  /// Товар, которого больше нет в каталоге или который удалён, в список не
  /// попадает: кнопка, ведущая в никуда, хуже отсутствующей.
  Future<List<QuickProductItem>> items({int? categoryId});
}

@immutable
class QuickProductCategory {
  const QuickProductCategory({required this.id, required this.name});

  final int id;

  final String name;

  @override
  bool operator ==(Object other) =>
      other is QuickProductCategory && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Кнопка сетки: товар и цена, которую на ней написать.
///
/// **Цена розничная всегда** — тем же пределом, что у `CartService.search`
/// (см. его докстринг): у сетки нет ни рабочего места, ни чека, значит и
/// признака опта.
///
/// **Измерено кругом правки 1 задачи 8, и это видно кассиру.** В оптовом
/// чеке кнопка говорит 500, а строка становится 300: цену строки решает
/// касса по признаку чека, а не экран по надписи на кнопке. Расхождение
/// стало заметным именно теперь — до задачи 8 опта на кассе не было вовсе
/// (находка 4), и разойтись двум ценам было негде.
///
/// Не починено здесь намеренно: чтобы кнопка знала цену чека, контракту
/// нужен довод «рабочее место» — та же подпись, на которую уже опираются
/// задачи 10 и 12, и та же развилка, что у `CartService.search`. Решать её
/// надо один раз для обоих, а не дважды по-разному.
@immutable
class QuickProductItem {
  const QuickProductItem({
    required this.ucode,
    required this.name,
    required this.price,
  });

  final int ucode;

  final String name;

  /// Деньги — `Decimal` P18,S3, никогда `double` (I159).
  final Decimal price;

  @override
  bool operator ==(Object other) =>
      other is QuickProductItem &&
      other.ucode == ucode &&
      other.name == name &&
      other.price == price;

  @override
  int get hashCode => Object.hash(ucode, name, price);
}
