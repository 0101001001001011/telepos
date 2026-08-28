import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';

class SaleMapper {
  SaleMapper._();

  static SaleEntity fromDrift(Sale sale) {
    return SaleEntity(
      receiptNo: sale.receiptNo,
      posId: sale.posId,
      saleId: sale.saleId,
      userId: sale.userId,
      amount: sale.amount,
      change: sale.change,
      time: sale.time,
      storeId: sale.storeId,
      customerLocalId: sale.customerLocalId,
      customerServerId: sale.customerServerId,
      loyalCustomerPhone: sale.loyalCustomerPhone,
      isOfd: sale.isOfd,
      state: sale.state,
      isWholesale: sale.isWholesale,
      weightProductRoundType: sale.weightProductRoundType,
      discountsRoundType: sale.discountsRoundType,
      customerBin: sale.customerBin,
      orderType: sale.orderType,
      serviceCharge: sale.serviceCharge,
    );
  }

  static SalesCompanion toDrift(SaleEntity entity) {
    return SalesCompanion(
      receiptNo: Value(entity.receiptNo),
      posId: Value(entity.posId),
      saleId: Value(entity.saleId),
      userId: Value(entity.userId),
      amount: Value(entity.amount),
      change: Value(entity.change),
      time: Value(entity.time),
      storeId: Value(entity.storeId),
      customerLocalId: Value(entity.customerLocalId),
      customerServerId: Value(entity.customerServerId),
      loyalCustomerPhone: Value(entity.loyalCustomerPhone),
      isOfd: Value(entity.isOfd),
      state: Value(entity.state),
      isWholesale: Value(entity.isWholesale),
      weightProductRoundType: Value(entity.weightProductRoundType),
      discountsRoundType: Value(entity.discountsRoundType),
      customerBin: Value(entity.customerBin),
      orderType: Value(entity.orderType),
      serviceCharge: Value(entity.serviceCharge),
    );
  }

  static List<SaleEntity> fromDriftList(List<Sale> sales) {
    return sales.map(fromDrift).toList();
  }
}
