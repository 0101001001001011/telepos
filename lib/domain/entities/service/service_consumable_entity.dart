import 'package:decimal/decimal.dart';

class ServiceConsumableEntity {
  const ServiceConsumableEntity({
    this.id,
    required this.serviceProductUcode,
    required this.consumableUcode,
    required this.quantity,
    this.consumableName,
    this.consumablePrice,
  });

  final int? id;

  final int serviceProductUcode;

  final int consumableUcode;

  final Decimal quantity;

  final String? consumableName;

  final Decimal? consumablePrice;

  Decimal get totalCost => (consumablePrice ?? Decimal.zero) * quantity;

  ServiceConsumableEntity copyWith({
    int? id,
    int? serviceProductUcode,
    int? consumableUcode,
    Decimal? quantity,
    String? consumableName,
    Decimal? consumablePrice,
  }) {
    return ServiceConsumableEntity(
      id: id ?? this.id,
      serviceProductUcode: serviceProductUcode ?? this.serviceProductUcode,
      consumableUcode: consumableUcode ?? this.consumableUcode,
      quantity: quantity ?? this.quantity,
      consumableName: consumableName ?? this.consumableName,
      consumablePrice: consumablePrice ?? this.consumablePrice,
    );
  }
}
