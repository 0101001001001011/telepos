import 'package:telepos/core/constants/enums/measure.dart';
import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/data/database/app_database.dart' as db;
import 'package:telepos/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Future<ProductInfo?> findByBarcode(int barcode) async {
    final row = await _db.productInfoDao.findByBarcode(barcode.toString());
    if (row == null) return null;
    return _toProductInfo(row);
  }

  @override
  Future<ProductInfo?> findByUcode(int ucode) async {
    final row = await _db.productInfoDao.findByUcode(ucode);
    if (row == null) return null;
    return _toProductInfo(row);
  }

  @override
  Future<List<ProductInfo>> search(String query, {int limit = 20}) async {
    final rows = await _db.productInfoDao.findByNamePart(query);
    return rows.take(limit).map(_toProductInfo).toList();
  }

  @override
  Future<int> count() {
    return _db.productInfoDao.count();
  }

  ProductInfo _toProductInfo(db.ProductInfo row) {
    final measure = row.measure >= 0 && row.measure < Measure.values.length
        ? Measure.values[row.measure]
        : Measure.piece;
    final productType = row.type >= 0 && row.type < ProductType.values.length
        ? ProductType.values[row.type]
        : ProductType.normal;

    return ProductInfo(
      ucode: row.ucode,
      barcode: row.barcode,
      name: row.name,
      categoryId: row.categoryId,
      unitName: measure.unit,
      isWeightProduct: productType == ProductType.weight,
    );
  }
}
