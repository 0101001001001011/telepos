import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/sale_product_creation_use_case.dart';

class SaleProductCreationUseCaseImpl implements SaleProductCreationUseCase {
  SaleProductCreationUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> create({
    required int receiptNo,
    required int posId,
    required bool isWholesale,
    required int ucode,
    int? barcode,
    int? categoryId,
    required Decimal sellingPrice,
    Decimal? wholesalePrice,
    Decimal? weight,
  }) async {
    final price = isWholesale && wholesalePrice != null
        ? wholesalePrice
        : sellingPrice;

    final quantity = weight ?? Decimal.one;

    await _db
        .into(_db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            ucode: ucode,
            barcode: Value(barcode),
            categoryId: Value(categoryId),
            quantity: quantity,
            price: price,
            priceBefore: price,
          ),
        );

    _logger.info(
      'SaleProductCreation: added ucode=$ucode to receipt=$receiptNo, '
      'price=$price, qty=$quantity, wholesale=$isWholesale',
    );
  }
}
