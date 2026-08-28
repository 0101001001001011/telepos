import 'package:decimal/decimal.dart';

class RefundProductEntity {
  const RefundProductEntity({
    this.id,
    this.refundLocalId,
    this.refundServerId,
    required this.ucode,
    required this.price,
    required this.quantity,
    this.weightProductRoundType,
    this.discountsRoundType,
    this.inSaleQuantity,
    this.inSalePrice,
    this.inSalePriceBefore,
  });

  final int? id;

  final int? refundLocalId;

  final int? refundServerId;

  final int ucode;

  final Decimal price;

  final Decimal quantity;

  final int? weightProductRoundType;

  final int? discountsRoundType;

  final Decimal? inSaleQuantity;

  final Decimal? inSalePrice;

  final Decimal? inSalePriceBefore;

  Decimal get total => quantity * price;

  RefundProductEntity copyWith({
    int? id,
    int? refundLocalId,
    int? refundServerId,
    int? ucode,
    Decimal? price,
    Decimal? quantity,
    int? weightProductRoundType,
    int? discountsRoundType,
    Decimal? inSaleQuantity,
    Decimal? inSalePrice,
    Decimal? inSalePriceBefore,
  }) {
    return RefundProductEntity(
      id: id ?? this.id,
      refundLocalId: refundLocalId ?? this.refundLocalId,
      refundServerId: refundServerId ?? this.refundServerId,
      ucode: ucode ?? this.ucode,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      weightProductRoundType:
          weightProductRoundType ?? this.weightProductRoundType,
      discountsRoundType: discountsRoundType ?? this.discountsRoundType,
      inSaleQuantity: inSaleQuantity ?? this.inSaleQuantity,
      inSalePrice: inSalePrice ?? this.inSalePrice,
      inSalePriceBefore: inSalePriceBefore ?? this.inSalePriceBefore,
    );
  }
}
