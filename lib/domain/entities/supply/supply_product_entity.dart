import 'package:decimal/decimal.dart';

class SupplyProductEntity {
  const SupplyProductEntity({
    this.id,
    required this.supplyId,
    required this.ucode,
    required this.quantity,
    required this.price,
    required this.amount,
    this.serialNumbers,
  });

  final int? id;

  final int supplyId;

  final int ucode;

  final Decimal quantity;

  final Decimal price;

  final Decimal amount;

  final List<String>? serialNumbers;

  SupplyProductEntity copyWith({
    int? id,
    int? supplyId,
    int? ucode,
    Decimal? quantity,
    Decimal? price,
    Decimal? amount,
    List<String>? serialNumbers,
  }) {
    return SupplyProductEntity(
      id: id ?? this.id,
      supplyId: supplyId ?? this.supplyId,
      ucode: ucode ?? this.ucode,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      amount: amount ?? this.amount,
      serialNumbers: serialNumbers ?? this.serialNumbers,
    );
  }
}
