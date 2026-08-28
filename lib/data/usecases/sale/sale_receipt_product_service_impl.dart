import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/sale_receipt_product_service.dart';
import 'package:telepos/domain/usecases/sale/universal_product_use_case.dart';

class SaleReceiptProductServiceImpl implements SaleReceiptProductService {
  SaleReceiptProductServiceImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<ReceiptProductData>> getSaleProducts({
    required int receiptNo,
    required int posId,
    required bool isWholesale,
    required int weightProductRoundType,
    required int discountsRoundType,
    required bool isSaleComplete,
  }) async {
    final products = <ReceiptProductData>[];

    final saleProducts = await _db.saleProductDao.findBySale(receiptNo, posId);

    for (final sp in saleProducts) {
      final wrapped = await _wrapSaleProduct(
        sp,
        isWholesale: isWholesale,
        weightProductRoundType: weightProductRoundType,
        discountsRoundType: discountsRoundType,
        isSaleComplete: isSaleComplete,
      );
      if (wrapped != null) {
        products.add(wrapped);
      }
    }

    final universalProducts = await _db.saleProductDao.findUniversalBySale(
      receiptNo,
      posId,
    );

    for (final up in universalProducts) {
      products.add(
        _wrapUniversalProduct(
          up,
          isWholesale: isWholesale,
          weightProductRoundType: weightProductRoundType,
          discountsRoundType: discountsRoundType,
          isSaleComplete: isSaleComplete,
        ),
      );
    }

    _logger.info(
      'SaleReceiptProductService: loaded ${saleProducts.length} standard, '
      '${universalProducts.length} universal for receipt=$receiptNo',
    );

    return products;
  }

  Future<ReceiptProductData?> _wrapSaleProduct(
    SaleProduct sp, {
    required bool isWholesale,
    required int weightProductRoundType,
    required int discountsRoundType,
    required bool isSaleComplete,
  }) async {
    final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(
      sp.ucode,
    );
    if (productInfo == null) {
      _logger.warning(
        'SaleReceiptProductService: ProductInfo not found for ucode=${sp.ucode}',
      );
      return null;
    }

    final productPrice = await _db.productPriceDao.findByUcode(sp.ucode);

    final markUp = await getMarkUpForCategory(sp.categoryId);

    final marks = await _db.saleProductDao.findMarksBySaleProduct(sp.id);
    final markStrings = marks
        .where((m) => m.mark != null)
        .map((m) => m.mark!)
        .toList();

    return ReceiptProductData(
      id: sp.id,
      ucode: sp.ucode,
      productName: productInfo.name,
      measure: productInfo.measure,
      quantity: sp.quantity,
      price: sp.price,
      priceBefore: sp.priceBefore,
      sellingPrice: productPrice?.sellingPrice ?? Decimal.zero,
      wholesalePrice: productPrice?.wholesalePrice ?? Decimal.zero,
      isWholesale: isWholesale,
      isUniversal: false,
      isSaleComplete: isSaleComplete,
      weightProductRoundType: weightProductRoundType,
      discountsRoundType: discountsRoundType,
      barcode: sp.barcode,
      categoryId: sp.categoryId,
      markUp: markUp,
      marks: markStrings,
    );
  }

  ReceiptProductData _wrapUniversalProduct(
    UniversalProduct up, {
    required bool isWholesale,
    required int weightProductRoundType,
    required int discountsRoundType,
    required bool isSaleComplete,
  }) {
    return ReceiptProductData(
      id: up.id,
      ucode: UniversalProductUseCase.universalUcode,
      productName: UniversalProductUseCase.universalName,
      measure: 0,
      quantity: up.quantity,
      price: up.price,
      priceBefore: up.priceBefore ?? up.price,
      sellingPrice: up.price,
      wholesalePrice: up.price,
      isWholesale: isWholesale,
      isUniversal: true,
      isSaleComplete: isSaleComplete,
      weightProductRoundType: weightProductRoundType,
      discountsRoundType: discountsRoundType,
    );
  }

  @override
  Future<Decimal?> getMarkUpForCategory(int? categoryId) async {
    if (categoryId == null) return null;

    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) return null;

    final fromDate = thisPos.markUpFromDate;
    final toDate = thisPos.markUpToDate;

    if (fromDate == null || toDate == null) return null;

    final now = DateTime.now();
    final from = DateTime.tryParse(fromDate);
    final to = DateTime.tryParse(toDate);

    if (from == null || to == null) return null;
    if (now.isBefore(from) || now.isAfter(to)) return null;

    final markUp = await _db.markUpDao.findMarkUpFor(categoryId);
    return markUp?.markup;
  }
}
