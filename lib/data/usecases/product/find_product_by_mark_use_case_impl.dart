import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/find_product_by_mark_use_case.dart';
import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';

class FindProductByMarkUseCaseImpl implements FindProductByMarkUseCase {
  FindProductByMarkUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _gtinLength = 14;

  static const int _minMarkLength = 21;

  @override
  Future<ProductWithPrice?> find(String mark) async {
    final gtin = extractGtin(mark);
    if (gtin == null) {
      _logger.warning('FindProductByMark: invalid mark format');
      return null;
    }

    final barcode = int.tryParse(gtin.substring(1));
    if (barcode == null) {
      _logger.warning('FindProductByMark: cannot parse GTIN to barcode');
      return null;
    }

    final products =
        await (_db.select(_db.productInfos)
              ..where((p) => p.barcode.equals(barcode))
              ..where((p) => p.isDeleted.equals(false)))
            .get();

    if (products.isEmpty) {
      final fullGtin = int.tryParse(gtin);
      if (fullGtin != null) {
        final productsFullGtin =
            await (_db.select(_db.productInfos)
                  ..where((p) => p.barcode.equals(fullGtin))
                  ..where((p) => p.isDeleted.equals(false)))
                .get();
        if (productsFullGtin.isNotEmpty) {
          return _toProductWithPrice(productsFullGtin.first);
        }
      }

      _logger.info('FindProductByMark: not found for gtin=$gtin');
      return null;
    }

    final productInfo = products.first;
    return _toProductWithPrice(productInfo);
  }

  @override
  String? extractGtin(String mark) {
    if (mark.length < _minMarkLength) {
      return null;
    }

    final ai01Index = mark.indexOf('01');
    if (ai01Index == -1) {
      if (mark.length >= _gtinLength) {
        final potential = mark.substring(0, _gtinLength);
        if (_isNumeric(potential)) {
          return potential;
        }
      }
      return null;
    }

    final gtinStart = ai01Index + 2;
    if (mark.length < gtinStart + _gtinLength) {
      return null;
    }

    final gtin = mark.substring(gtinStart, gtinStart + _gtinLength);
    if (!_isNumeric(gtin)) {
      return null;
    }

    return gtin;
  }

  @override
  bool isValidMark(String mark) {
    return extractGtin(mark) != null;
  }

  bool _isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  Future<ProductWithPrice> _toProductWithPrice(ProductInfo productInfo) async {
    final productPrice = await _db.productPriceDao.findByUcode(
      productInfo.ucode,
    );

    _logger.info('FindProductByMark: found ucode=${productInfo.ucode}');

    final price =
        productPrice?.sellingPrice ??
        productPrice?.wholesalePrice ??
        Decimal.zero;

    return ProductWithPrice(
      ucode: productInfo.ucode,
      barcode: productInfo.barcode,
      name: productInfo.name,
      type: productInfo.type,
      measure: productInfo.measure,
      categoryId: productInfo.categoryId,
      price: price,
      minPrice: productPrice?.wholesalePrice,
      isDeleted: productInfo.isDeleted,
    );
  }
}
