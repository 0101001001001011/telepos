import 'package:decimal/decimal.dart';

// Здесь жил договор `FindProductByCodeUseCase` — зарегистрированный в
// контейнере и не спрошенный ни разу (2026-09-22). Снят; тип
// `ProductWithPrice` остаётся: им пользуется живой поиск по штрихкоду.

class ProductWithPrice {
  const ProductWithPrice({
    required this.ucode,
    required this.barcode,
    required this.name,
    required this.type,
    required this.measure,
    required this.categoryId,
    required this.price,
    this.minPrice,
    this.isDeleted = false,
  });

  final int ucode;

  final int barcode;

  final String name;

  final int type;

  final int measure;

  final int? categoryId;

  final Decimal price;

  final Decimal? minPrice;

  final bool isDeleted;
}
