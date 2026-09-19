import 'package:meta/meta.dart';

/// Наименьший возможный ответ на штрихкод — «нашли или нет», без модели чека.
///
/// Заведён под `SaleOps.salePing` (задача 1 плана «Продажа с браузерного
/// терминала»): единственная цель этого обмена — измерить цену одного круга
/// по проводу, прежде чем строить остальные сорок операций фазы 1.
///
/// [price] — строка, не число. Деньги по проводу едут `Decimal.toString()`
/// (инвариант I159, `global-constraints.md`): протокол не делает исключения
/// даже для замера.
@immutable
class ProductProbe {
  const ProductProbe({required this.found, this.name, this.price});

  /// Товар с таким штрихкодом найден в базе кассы.
  final bool found;

  /// `null`, если [found] — `false`.
  final String? name;

  /// Цена строкой (`Decimal.toString()`). `null`, если [found] — `false`
  /// или у товара нет строки цены.
  final String? price;
}
