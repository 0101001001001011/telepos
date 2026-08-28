import 'package:decimal/decimal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/sale_mapper.dart';
import 'package:telepos/data/mappers/sale_product_mapper.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';
import 'package:telepos/domain/repositories/sale_repository.dart';

class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<SaleEntity?> findByKey(int receiptNo, int posId) async {
    final sale = await _db.saleDao.findByKey(receiptNo, posId);
    return sale != null ? SaleMapper.fromDrift(sale) : null;
  }

  @override
  Future<SaleEntity?> findBySaleId(int saleId) async {
    final sale = await _db.saleDao.findBySaleId(saleId);
    return sale != null ? SaleMapper.fromDrift(sale) : null;
  }

  @override
  Future<int?> findLastReceiptNo() {
    return _db.saleDao.findLastReceiptNo();
  }

  @override
  Future<SaleEntity?> findInProgress() async {
    final sale = await _db.saleDao.findInProgress();
    return sale != null ? SaleMapper.fromDrift(sale) : null;
  }

  @override
  Future<List<SaleEntity>> findByState(int state) async {
    final sales = await _db.saleDao.findByState(state);
    return SaleMapper.fromDriftList(sales);
  }

  @override
  Future<int> countWithState(int state) {
    return _db.saleDao.countWithState(state);
  }

  @override
  Future<Decimal?> amountOfShift(int userId, int fromTime, int toTime) async {
    final result = await _db.saleDao.amountOfShift(userId, fromTime, toTime);
    if (result == null) return null;
    return Decimal.parse(result.toStringAsFixed(3));
  }

  @override
  Future<void> insert(SaleEntity entity) async {
    final companion = SaleMapper.toDrift(entity);
    await _db.into(_db.sales).insert(companion);
  }

  @override
  Future<void> updateState(int receiptNo, int posId, int state) {
    return _db.saleDao.updateState(receiptNo, posId, state).then((_) {});
  }

  @override
  Future<SaleEntity?> findFirstSaleAfter(int timestamp) async {
    final sale = await _db.saleDao.findFirstSaleAfter(timestamp);
    return sale != null ? SaleMapper.fromDrift(sale) : null;
  }

  @override
  Future<List<SaleProductEntity>> findProductsByKey(
    int receiptNo,
    int posId,
  ) async {
    final products = await _db.saleProductDao.findBySale(receiptNo, posId);
    return SaleProductMapper.fromDriftList(products);
  }
}
