import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';

abstract class GetSuppliesHistoryUseCase {
  Future<List<SupplyHistoryItem>> getSupplies({int limit = 50, int offset = 0});

  Future<List<SupplyHistoryItem>> getBySupplier(int supplierId);

  Future<SupplyDetails?> getDetails(int supplyId);
}

class SupplyHistoryItem {
  const SupplyHistoryItem({
    required this.id,
    required this.supplierId,
    this.supplierName,
    required this.amount,
    required this.paymentType,
    required this.editTime,
    required this.syncState,
    this.productCount,
  });

  final int id;
  final int supplierId;
  final String? supplierName;
  final Decimal amount;
  final SupplyPaymentType paymentType;
  final DateTime editTime;
  final SupplySyncState syncState;
  final int? productCount;
}

class SupplyDetails {
  const SupplyDetails({
    required this.id,
    required this.supplierId,
    this.supplierName,
    required this.userId,
    this.userName,
    required this.amount,
    required this.paymentType,
    this.accountId,
    this.comment,
    required this.payment,
    required this.consignmentAmount,
    required this.paidAmount,
    required this.editTime,
    required this.syncState,
    required this.products,
  });

  final int id;
  final int supplierId;
  final String? supplierName;
  final int userId;
  final String? userName;
  final Decimal amount;
  final SupplyPaymentType paymentType;
  final int? accountId;
  final String? comment;
  final Decimal payment;
  final Decimal consignmentAmount;
  final Decimal paidAmount;
  final DateTime editTime;
  final SupplySyncState syncState;
  final List<SupplyDetailProduct> products;
}

class SupplyDetailProduct {
  const SupplyDetailProduct({
    required this.id,
    required this.ucode,
    required this.quantity,
    required this.price,
    required this.amount,
    this.productName,
    this.barcode,
  });

  final int id;
  final int ucode;
  final Decimal quantity;
  final Decimal price;
  final Decimal amount;
  final String? productName;
  final String? barcode;
}

enum SupplySyncState { inProgress, pendingSync, beingSent, synced }

extension SupplySyncStateExtension on SupplySyncState {
  int get index => SupplySyncState.values.indexOf(this);

  static SupplySyncState fromIndex(int? index) {
    if (index == null || index < 0 || index >= SupplySyncState.values.length) {
      return SupplySyncState.inProgress;
    }
    return SupplySyncState.values[index];
  }
}

extension SupplyPaymentTypeExtension on SupplyPaymentType {
  int get index => SupplyPaymentType.values.indexOf(this);

  static SupplyPaymentType fromIndex(int? index) {
    if (index == null ||
        index < 0 ||
        index >= SupplyPaymentType.values.length) {
      return SupplyPaymentType.fullSupply;
    }
    return SupplyPaymentType.values[index];
  }
}
