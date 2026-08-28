import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/create_product_price_use_case.dart';

class CreateProductPriceUseCaseImpl implements CreateProductPriceUseCase {
  CreateProductPriceUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<int> create({
    required int ucode,
    required int barcode,
    required Decimal sellingPrice,
    Decimal? wholesalePrice,
  }) async {
    await _db
        .into(_db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: Value(ucode),
            barcode: barcode,
            sellingPrice: Value(sellingPrice),
            wholesalePrice: Value(wholesalePrice),
            editTime: Value(DateTime.now()),
          ),
        );

    _logger.info(
      'CreateProductPrice: created ucode=$ucode, price=$sellingPrice',
    );

    return ucode;
  }

  @override
  Future<void> update({
    required int ucode,
    Decimal? sellingPrice,
    Decimal? wholesalePrice,
  }) async {
    if (sellingPrice == null && wholesalePrice == null) {
      return;
    }

    await (_db.update(
      _db.productPrices,
    )..where((p) => p.ucode.equals(ucode))).write(
      ProductPricesCompanion(
        sellingPrice: sellingPrice != null
            ? Value(sellingPrice)
            : const Value.absent(),
        wholesalePrice: wholesalePrice != null
            ? Value(wholesalePrice)
            : const Value.absent(),
        editTime: Value(DateTime.now()),
      ),
    );

    _logger.info(
      'CreateProductPrice: updated ucode=$ucode, price=$sellingPrice',
    );
  }
}
