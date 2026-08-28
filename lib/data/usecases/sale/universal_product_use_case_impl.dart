import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/universal_product_use_case.dart';

class UniversalProductUseCaseImpl implements UniversalProductUseCase {
  UniversalProductUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _typeService = 1;

  static const int _measurePiece = 0;

  @override
  Future<void> ensureProductExists() async {
    final existing = await _db.productInfoDao.findByIdAndNotDeleted(
      UniversalProductUseCase.universalUcode,
    );

    if (existing != null) {
      return;
    }

    _logger.info('UniversalProduct: creating universal product in catalog');

    final shift = await _db.shiftDao.findOpenedShift();
    final now = DateTime.now();
    const ucode = UniversalProductUseCase.universalUcode;

    await _db
        .into(_db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(ucode),
            barcode: Value(ucode),
            name: const Value(UniversalProductUseCase.universalName),
            type: const Value(_typeService),
            measure: const Value(_measurePiece),
            isDeleted: const Value(false),
            localEditTime: Value(now),
          ),
        );

    if (shift != null) {
      await _db
          .into(_db.productInfoEditions)
          .insert(
            ProductInfoEditionsCompanion(
              ucode: Value(ucode),
              userId: Value(shift.userId),
              editTime: Value(now),
            ),
          );
    }

    await _db
        .into(_db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: Value(ucode),
            barcode: Value(ucode),
            sellingPrice: Value(Decimal.zero),
            wholesalePrice: Value(Decimal.zero),
          ),
        );

    _logger.info('UniversalProduct: universal product created successfully');
  }

  @override
  Future<void> createForSale({
    required int receiptNo,
    required int posId,
    required Decimal priceBefore,
  }) async {
    await ensureProductExists();

    await _db
        .into(_db.universalProducts)
        .insert(
          UniversalProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            quantity: Decimal.one,
            price: priceBefore,
            priceBefore: Value(priceBefore),
          ),
        );

    _logger.info(
      'UniversalProduct: created for sale '
      'receipt=$receiptNo, price=$priceBefore',
    );
  }

  @override
  Future<void> createForRefundFromSale({
    required int refundLocalId,
    required Decimal originalPrice,
    required Decimal originalQuantity,
  }) async {
    await ensureProductExists();

    await _db
        .into(_db.universalProducts)
        .insert(
          UniversalProductsCompanion.insert(
            refundLocalId: Value(refundLocalId),
            quantity: originalQuantity,
            price: originalPrice,
            priceBefore: Value(originalPrice),
            inSalePrice: Value(originalPrice),
            inSaleQuantity: Value(originalQuantity),
          ),
        );

    _logger.info(
      'UniversalProduct: created for refund from sale '
      'refund=$refundLocalId, originalPrice=$originalPrice',
    );
  }

  @override
  Future<void> createForRefundCustom({
    required int refundLocalId,
    required Decimal price,
  }) async {
    await ensureProductExists();

    await _db
        .into(_db.universalProducts)
        .insert(
          UniversalProductsCompanion.insert(
            refundLocalId: Value(refundLocalId),
            quantity: Decimal.one,
            price: price,
            priceBefore: Value(price),
          ),
        );

    _logger.info(
      'UniversalProduct: created for refund custom '
      'refund=$refundLocalId, price=$price',
    );
  }
}
