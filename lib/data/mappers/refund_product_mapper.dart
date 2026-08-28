import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/refund/refund_product_entity.dart';

class RefundProductMapper {
  RefundProductMapper._();

  static RefundProductEntity fromDrift(RefundProduct product) {
    return RefundProductEntity(
      id: product.id,
      refundLocalId: product.refundLocalId,
      refundServerId: product.refundServerId,
      ucode: product.ucode,
      price: product.price,
      quantity: product.quantity,
      weightProductRoundType: product.weightProductRoundType,
      discountsRoundType: product.discountsRoundType,
      inSaleQuantity: product.inSaleQuantity,
      inSalePrice: product.inSalePrice,
      inSalePriceBefore: product.inSalePriceBefore,
    );
  }

  static RefundProductsCompanion toDrift(RefundProductEntity entity) {
    return RefundProductsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      refundLocalId: Value(entity.refundLocalId),
      refundServerId: Value(entity.refundServerId),
      ucode: Value(entity.ucode),
      price: Value(entity.price),
      quantity: Value(entity.quantity),
      weightProductRoundType: Value(entity.weightProductRoundType),
      discountsRoundType: Value(entity.discountsRoundType),
      inSaleQuantity: Value(entity.inSaleQuantity),
      inSalePrice: Value(entity.inSalePrice),
      inSalePriceBefore: Value(entity.inSalePriceBefore),
    );
  }

  static List<RefundProductEntity> fromDriftList(List<RefundProduct> products) {
    return products.map(fromDrift).toList();
  }
}
