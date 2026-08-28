import 'package:decimal/decimal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/supply/get_supplies_history_use_case.dart';

class GetSuppliesHistoryUseCaseImpl implements GetSuppliesHistoryUseCase {
  GetSuppliesHistoryUseCaseImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<SupplyHistoryItem>> getSupplies({
    int limit = 50,
    int offset = 0,
  }) async {
    final supplies = await _db.supplyDao.findAll(limit: limit, offset: offset);

    return _mapToHistoryItems(supplies);
  }

  @override
  Future<List<SupplyHistoryItem>> getBySupplier(int supplierId) async {
    final supplies = await _db.supplyDao.findBySupplierId(supplierId);
    return _mapToHistoryItems(supplies);
  }

  @override
  Future<SupplyDetails?> getDetails(int supplyId) async {
    final supply = await _db.supplyDao.findById(supplyId);
    if (supply == null) return null;

    String? supplierName;
    if (supply.supplierId != null) {
      final supplier = await _db.agentDao.findByLocalId(supply.supplierId!);
      supplierName = supplier?.name;
    }

    String? userName;
    if (supply.userId != null) {
      final user = await _db.userDao.findById(supply.userId!);
      userName = user?.name;
    }

    final products = await _db.supplyProductDao.findBySupplyId(supplyId);
    final detailProducts = <SupplyDetailProduct>[];

    for (final p in products) {
      final productInfo = await _db.productInfoDao.findByUcode(p.ucode);
      final productPrice = await _db.productPriceDao.findByUcode(p.ucode);

      detailProducts.add(
        SupplyDetailProduct(
          id: p.id,
          ucode: p.ucode,
          quantity: p.quantity,
          price: p.price,
          amount: p.amount,
          productName: productInfo?.name,
          barcode: productPrice?.barcode.toString(),
        ),
      );
    }

    return SupplyDetails(
      id: supply.id,
      supplierId: supply.supplierId ?? 0,
      supplierName: supplierName,
      userId: supply.userId ?? 0,
      userName: userName,
      amount: supply.amount ?? Decimal.zero,
      paymentType: SupplyPaymentTypeExtension.fromIndex(supply.paymentType),
      accountId: supply.accountId,
      comment: supply.comment,
      payment: supply.payment ?? Decimal.zero,
      consignmentAmount: supply.consignmentAmount ?? Decimal.zero,
      paidAmount: supply.paidAmount ?? Decimal.zero,
      editTime: DateTime.fromMillisecondsSinceEpoch(
        (supply.editTime ?? 0) * 1000,
      ),
      syncState: SupplySyncStateExtension.fromIndex(supply.state),
      products: detailProducts,
    );
  }

  Future<List<SupplyHistoryItem>> _mapToHistoryItems(
    List<Supply> supplies,
  ) async {
    final result = <SupplyHistoryItem>[];

    for (final s in supplies) {
      String? supplierName;
      if (s.supplierId != null) {
        final supplier = await _db.agentDao.findByLocalId(s.supplierId!);
        supplierName = supplier?.name;
      }

      final productCount = await _db.supplyProductDao.countBySupplyId(s.id);

      result.add(
        SupplyHistoryItem(
          id: s.id,
          supplierId: s.supplierId ?? 0,
          supplierName: supplierName,
          amount: s.amount ?? Decimal.zero,
          paymentType: SupplyPaymentTypeExtension.fromIndex(s.paymentType),
          editTime: DateTime.fromMillisecondsSinceEpoch(
            (s.editTime ?? 0) * 1000,
          ),
          syncState: SupplySyncStateExtension.fromIndex(s.state),
          productCount: productCount,
        ),
      );
    }

    return result;
  }
}
