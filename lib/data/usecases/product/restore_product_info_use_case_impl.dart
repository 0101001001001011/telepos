import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/restore_product_info_use_case.dart';

class RestoreProductInfoUseCaseImpl implements RestoreProductInfoUseCase {
  RestoreProductInfoUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<bool> restore(int ucode, {required int userId}) async {
    final deletedProduct =
        await (_db.select(_db.productInfos)
              ..where((p) => p.ucode.equals(ucode))
              ..where((p) => p.isDeleted.equals(true))
              ..limit(1))
            .getSingleOrNull();

    if (deletedProduct == null) {
      _logger.warning(
        'RestoreProductInfo: product ucode=$ucode not found or not deleted',
      );
      return false;
    }

    await _db.productInfoDao.restoreProduct(ucode);

    final now = DateTime.now();

    await _db
        .into(_db.productInfoEditions)
        .insert(
          ProductInfoEditionsCompanion.insert(
            ucode: Value(ucode),
            userId: userId,
            editTime: now,
          ),
          mode: InsertMode.insertOrReplace,
        );

    _logger.info('RestoreProductInfo: restored ucode=$ucode by userId=$userId');

    return true;
  }

  @override
  Future<bool> restoreByBarcode(int barcode, {required int userId}) async {
    final deletedProduct =
        await (_db.select(_db.productInfos)
              ..where((p) => p.barcode.equals(barcode))
              ..where((p) => p.isDeleted.equals(true))
              ..limit(1))
            .getSingleOrNull();

    if (deletedProduct == null) {
      _logger.warning(
        'RestoreProductInfo: product barcode=$barcode not found or not deleted',
      );
      return false;
    }

    return restore(deletedProduct.ucode, userId: userId);
  }
}
