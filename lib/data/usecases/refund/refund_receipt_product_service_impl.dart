import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/refund_receipt_product_service.dart';

class RefundReceiptProductServiceImpl implements RefundReceiptProductService {
  RefundReceiptProductServiceImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<RefundReceiptProduct>> getProducts({
    required int refundLocalId,
  }) async {
    final refundProducts = await _db.refundDao.findProductsByRefund(
      refundLocalId,
    );

    final result = <RefundReceiptProduct>[];
    for (final rp in refundProducts) {
      final marks = await _db.refundDao.findMarksByRefundProduct(rp.id);

      final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(
        rp.ucode,
      );

      result.add(
        RefundReceiptProduct(
          id: rp.id,
          ucode: rp.ucode,
          quantity: rp.quantity,
          price: rp.price,
          inSalePrice: rp.inSalePrice,
          inSaleQuantity: rp.inSaleQuantity,
          inSalePriceBefore: rp.inSalePriceBefore,
          marks: marks
              .where((m) => m.mark != null)
              .map((m) => m.mark!)
              .toList(),
          name: productInfo?.name,
          measure: productInfo?.measure,
          barcode: productInfo?.barcode,
        ),
      );
    }

    _logger.info(
      'RefundReceiptProductService: loaded ${result.length} products '
      'for refund=$refundLocalId',
    );

    return result;
  }

  @override
  Future<List<RefundReceiptProduct>> getProductsFromSale({
    required int saleReceiptNo,
    required int salePosId,
  }) async {
    final saleProducts = await _db.saleProductDao.findBySale(
      saleReceiptNo,
      salePosId,
    );

    final result = <RefundReceiptProduct>[];
    for (final sp in saleProducts) {
      final marks = await _db.saleProductDao.findMarksBySaleProduct(sp.id);

      final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(
        sp.ucode,
      );

      result.add(
        RefundReceiptProduct(
          id: sp.id,
          ucode: sp.ucode,
          quantity: sp.quantity,
          price: sp.price,
          inSalePrice: sp.price,
          inSaleQuantity: sp.quantity,
          inSalePriceBefore: sp.priceBefore,
          marks: marks
              .where((m) => m.mark != null)
              .map((m) => m.mark!)
              .toList(),
          name: productInfo?.name,
          measure: productInfo?.measure,
          barcode: productInfo?.barcode,
        ),
      );
    }

    _logger.info(
      'RefundReceiptProductService: loaded ${result.length} products '
      'from sale receiptNo=$saleReceiptNo, posId=$salePosId',
    );

    return result;
  }

  @override
  Future<RefundReceiptProduct> wrap({required int refundProductId}) async {
    final refundProducts = await (_db.select(
      _db.refundProducts,
    )..where((rp) => rp.id.equals(refundProductId))).get();

    if (refundProducts.isEmpty) {
      throw StateError('RefundProduct $refundProductId not found');
    }

    final rp = refundProducts.first;

    final marks = await _db.refundDao.findMarksByRefundProduct(rp.id);

    final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(
      rp.ucode,
    );

    _logger.info(
      'RefundReceiptProductService: wrapped refundProduct=$refundProductId',
    );

    return RefundReceiptProduct(
      id: rp.id,
      ucode: rp.ucode,
      quantity: rp.quantity,
      price: rp.price,
      inSalePrice: rp.inSalePrice,
      inSaleQuantity: rp.inSaleQuantity,
      inSalePriceBefore: rp.inSalePriceBefore,
      marks: marks.where((m) => m.mark != null).map((m) => m.mark!).toList(),
      name: productInfo?.name,
      measure: productInfo?.measure,
      barcode: productInfo?.barcode,
    );
  }
}
