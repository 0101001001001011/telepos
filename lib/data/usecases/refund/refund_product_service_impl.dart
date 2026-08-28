import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';

class RefundProductServiceImpl implements RefundProductService {
  RefundProductServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<int> add({
    required int refundLocalId,
    required int ucode,
    required Decimal quantity,
    required Decimal price,
    Decimal? inSalePrice,
    Decimal? inSaleQuantity,
    Decimal? inSalePriceBefore,
    List<String> marks = const [],
  }) async {
    return _db.transaction(() async {
      final refundProductId = await _db
          .into(_db.refundProducts)
          .insert(
            RefundProductsCompanion.insert(
              refundLocalId: Value(refundLocalId),
              ucode: ucode,
              quantity: quantity,
              price: price,
              inSalePrice: Value(inSalePrice),
              inSaleQuantity: Value(inSaleQuantity),
              inSalePriceBefore: Value(inSalePriceBefore),
            ),
          );

      for (final mark in marks) {
        await _db
            .into(_db.refundProductMarks)
            .insert(
              RefundProductMarksCompanion.insert(
                refundProductId: Value(refundProductId),
                mark: Value(mark),
              ),
            );
      }

      _logger.info(
        'RefundProductService: added product ucode=$ucode, qty=$quantity '
        'to refund=$refundLocalId, id=$refundProductId',
      );

      return refundProductId;
    });
  }

  @override
  Future<int> addUniversalProduct({
    required int refundLocalId,
    required Decimal quantity,
    required Decimal price,
    Decimal? priceBefore,
    Decimal? inSalePrice,
    Decimal? inSaleQuantity,
  }) async {
    final universalProductId = await _db
        .into(_db.universalProducts)
        .insert(
          UniversalProductsCompanion.insert(
            refundLocalId: Value(refundLocalId),
            quantity: quantity,
            price: price,
            priceBefore: Value(priceBefore),
            inSalePrice: Value(inSalePrice),
            inSaleQuantity: Value(inSaleQuantity),
          ),
        );

    _logger.info(
      'RefundProductService: added universal product price=$price '
      'to refund=$refundLocalId, id=$universalProductId',
    );

    return universalProductId;
  }

  @override
  Future<List<RefundProductItem>> getFromRefundProducts({
    required int refundLocalId,
  }) async {
    final refundProducts = await _db.refundDao.findProductsByRefund(
      refundLocalId,
    );

    final result = <RefundProductItem>[];
    for (final rp in refundProducts) {
      final marks = await _db.refundDao.findMarksByRefundProduct(rp.id);

      result.add(
        RefundProductItem(
          id: rp.id,
          refundLocalId: rp.refundLocalId ?? refundLocalId,
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
        ),
      );
    }

    _logger.info(
      'RefundProductService: loaded ${result.length} products '
      'for refund=$refundLocalId',
    );

    return result;
  }

  @override
  Future<List<RefundUniversalProductItem>> getUniversalProducts({
    required int refundLocalId,
  }) async {
    final universalProducts = await _db.saleProductDao.findUniversalByRefund(
      refundLocalId,
    );

    final result = universalProducts
        .map(
          (up) => RefundUniversalProductItem(
            id: up.id,
            receiptNo: up.receiptNo ?? 0,
            posId: up.posId ?? 0,
            refundLocalId: up.refundLocalId ?? refundLocalId,
            quantity: up.quantity,
            price: up.price,
            priceBefore: up.priceBefore,
            inSalePrice: up.inSalePrice,
            inSaleQuantity: up.inSaleQuantity,
          ),
        )
        .toList();

    _logger.info(
      'RefundProductService: loaded ${result.length} universal products '
      'for refund=$refundLocalId',
    );

    return result;
  }

  @override
  Future<void> remove({required int refundProductId}) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.refundProductMarks,
      )..where((m) => m.refundProductId.equals(refundProductId))).go();

      await (_db.delete(
        _db.refundProducts,
      )..where((rp) => rp.id.equals(refundProductId))).go();
    });

    _logger.info(
      'RefundProductService: removed refundProduct=$refundProductId',
    );
  }

  @override
  Future<void> removeUniversal({required int universalProductId}) async {
    await (_db.delete(
      _db.universalProducts,
    )..where((up) => up.id.equals(universalProductId))).go();

    _logger.info(
      'RefundProductService: removed universalProduct=$universalProductId',
    );
  }

  @override
  Future<void> updateQuantity({
    required int refundProductId,
    required Decimal quantity,
  }) async {
    await (_db.update(_db.refundProducts)
          ..where((rp) => rp.id.equals(refundProductId)))
        .write(RefundProductsCompanion(quantity: Value(quantity)));

    _logger.info(
      'RefundProductService: updated quantity=$quantity '
      'for refundProduct=$refundProductId',
    );
  }
}
