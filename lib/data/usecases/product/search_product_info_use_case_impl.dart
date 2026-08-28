import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart';

class SearchProductInfoUseCaseImpl implements SearchProductInfoUseCase {
  SearchProductInfoUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<ProductSearchResult>> search({
    required String query,
    int limit = 50,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    final isNumeric = int.tryParse(query) != null;

    if (isNumeric) {
      return searchByBarcode(barcodePart: query, limit: limit);
    } else {
      return searchByName(namePart: query, limit: limit);
    }
  }

  @override
  Future<List<ProductSearchResult>> searchByName({
    required String namePart,
    int limit = 50,
  }) async {
    final products = await _db.productInfoDao.findByNamePart(
      namePart,
      includeDeleted: true,
    );

    final results = products
        .take(limit)
        .map(
          (p) => ProductSearchResult(
            ucode: p.ucode,
            barcode: p.barcode,
            name: p.name,
            type: p.type,
            measure: p.measure,
            categoryId: p.categoryId,
            isDeleted: p.isDeleted,
          ),
        )
        .toList();

    _logger.info(
      'SearchProductInfo: found ${results.length} products for name=$namePart',
    );

    return results;
  }

  @override
  Future<List<ProductSearchResult>> searchByBarcode({
    required String barcodePart,
    int limit = 50,
  }) async {
    final barcodePrefix = int.tryParse(barcodePart);
    if (barcodePrefix == null) {
      return [];
    }

    final digits = barcodePart.length;
    final multiplier = _pow10(13 - digits);
    final minBarcode = barcodePrefix * multiplier;
    final maxBarcode = (barcodePrefix + 1) * multiplier;

    final products =
        await (_db.select(_db.productInfos)
              ..where((p) => p.barcode.isBiggerOrEqualValue(minBarcode))
              ..where((p) => p.barcode.isSmallerThanValue(maxBarcode))
              ..orderBy([
                (p) => OrderingTerm.asc(p.isDeleted),
                (p) => OrderingTerm.asc(p.barcode),
              ])
              ..limit(limit))
            .get();

    final results = products
        .map(
          (p) => ProductSearchResult(
            ucode: p.ucode,
            barcode: p.barcode,
            name: p.name,
            type: p.type,
            measure: p.measure,
            categoryId: p.categoryId,
            isDeleted: p.isDeleted,
          ),
        )
        .toList();

    _logger.info(
      'SearchProductInfo: found ${results.length} products for barcode=$barcodePart',
    );

    return results;
  }

  int _pow10(int exponent) {
    if (exponent <= 0) return 1;
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
