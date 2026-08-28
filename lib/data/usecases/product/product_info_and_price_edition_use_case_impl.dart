import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/product_info_and_price_edition_use_case.dart';

class ProductInfoAndPriceEditionUseCaseImpl
    implements ProductInfoAndPriceEditionUseCase {
  ProductInfoAndPriceEditionUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> edit({
    required int ucode,
    required int userId,
    String? name,
    Decimal? price,
    Decimal? minPrice,
    int? categoryId,
    int? type,
    int? measure,
    int? vatRate,
    bool vatRateSet = false,
    String? ntin,
    bool? isMarkable,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
  }) async {
    await _db.transaction(() async {
      final hasInfoChange =
          name != null ||
          categoryId != null ||
          type != null ||
          measure != null ||
          vatRateSet ||
          ntin != null ||
          isMarkable != null ||
          brand != null ||
          manufacturer != null ||
          countryOfOrigin != null;
      if (hasInfoChange) {
        await (_db.update(
          _db.productInfos,
        )..where((p) => p.ucode.equals(ucode))).write(
          ProductInfosCompanion(
            name: name != null ? Value(name) : const Value.absent(),
            categoryId: categoryId != null
                ? Value(categoryId)
                : const Value.absent(),
            type: type != null ? Value(type) : const Value.absent(),
            measure: measure != null ? Value(measure) : const Value.absent(),
            vatRate: vatRateSet ? Value(vatRate) : const Value.absent(),
            ntin: ntin != null ? Value(ntin) : const Value.absent(),
            isMarkable: isMarkable != null
                ? Value(isMarkable)
                : const Value.absent(),
            brand: brand != null ? Value(brand) : const Value.absent(),
            manufacturer: manufacturer != null
                ? Value(manufacturer)
                : const Value.absent(),
            countryOfOrigin: countryOfOrigin != null
                ? Value(countryOfOrigin)
                : const Value.absent(),
            localEditTime: Value(DateTime.now()),
          ),
        );
      }

      if (price != null || minPrice != null) {
        await (_db.update(
          _db.productPrices,
        )..where((p) => p.ucode.equals(ucode))).write(
          ProductPricesCompanion(
            sellingPrice: price != null ? Value(price) : const Value.absent(),
            wholesalePrice: minPrice != null
                ? Value(minPrice)
                : const Value.absent(),
            editTime: Value(DateTime.now()),
          ),
        );
      }

      await createEdition(ucode, userId: userId);

      _logger.info(
        'ProductInfoAndPriceEdition: edited ucode=$ucode by userId=$userId',
      );
    });
  }

  @override
  Future<void> createEdition(int ucode, {required int userId}) async {
    final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(ucode);
    final productPrice = await _db.productPriceDao.findByUcode(ucode);

    final now = DateTime.now();

    if (productInfo != null) {
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
    }

    if (productPrice != null) {
      await _db
          .into(_db.productPriceEditions)
          .insert(
            ProductPriceEditionsCompanion.insert(
              ucode: Value(ucode),
              userId: userId,
              editTime: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    _logger.info(
      'ProductInfoAndPriceEdition: created edition for ucode=$ucode by userId=$userId',
    );
  }
}
