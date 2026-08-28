import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';

class SaleProductMapper {
  SaleProductMapper._();

  static SaleProductEntity fromDrift(SaleProduct product) {
    return SaleProductEntity(
      id: product.id,
      receiptNo: product.receiptNo,
      posId: product.posId,
      saleId: product.saleId,
      ucode: product.ucode,
      barcode: product.barcode,
      categoryId: product.categoryId,
      quantity: product.quantity,
      price: product.price,
      priceBefore: product.priceBefore,
    );
  }

  static SaleProductsCompanion toDrift(SaleProductEntity entity) {
    return SaleProductsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      receiptNo: Value(entity.receiptNo),
      posId: Value(entity.posId),
      saleId: Value(entity.saleId),
      ucode: Value(entity.ucode),
      barcode: Value(entity.barcode),
      categoryId: Value(entity.categoryId),
      quantity: Value(entity.quantity),
      price: Value(entity.price),
      priceBefore: Value(entity.priceBefore),
    );
  }

  static List<SaleProductEntity> fromDriftList(List<SaleProduct> products) {
    return products.map(fromDrift).toList();
  }
}
