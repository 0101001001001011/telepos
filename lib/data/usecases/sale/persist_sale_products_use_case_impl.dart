import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/persist_sale_products_use_case.dart';
import 'package:telepos/domain/usecases/sale/universal_product_use_case.dart';

class PersistSaleProductsUseCaseImpl implements PersistSaleProductsUseCase {
  PersistSaleProductsUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> persist({
    required int receiptNo,
    required int posId,
    required List<SaleProductEntry> products,
  }) async {
    if (products.isEmpty) return;

    final universalProducts = <SaleProductEntry>[];
    final standardProducts = <SaleProductEntry>[];

    for (final p in products) {
      if (p.ucode == UniversalProductUseCase.universalUcode) {
        universalProducts.add(p);
      } else {
        standardProducts.add(p);
      }
    }

    if (standardProducts.isNotEmpty) {
      await _persistSaleProducts(receiptNo, posId, standardProducts);
    }

    if (universalProducts.isNotEmpty) {
      await _persistUniversalProducts(receiptNo, posId, universalProducts);
    }

    _logger.info(
      'PersistSaleProducts: saved ${standardProducts.length} standard, '
      '${universalProducts.length} universal for receipt=$receiptNo',
    );
  }

  Future<void> _persistSaleProducts(
    int receiptNo,
    int posId,
    List<SaleProductEntry> products,
  ) async {
    final grouped = <String, SaleProductEntry>{};

    for (final p in products) {
      final key = '${p.ucode}:${p.price}';

      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;
        grouped[key] = SaleProductEntry(
          ucode: existing.ucode,
          barcode: existing.barcode,
          categoryId: existing.categoryId,
          quantity: existing.quantity + p.quantity,
          price: existing.price,
          priceBefore: existing.priceBefore,
        );
      } else {
        grouped[key] = p;
      }
    }

    await _db.batch((batch) {
      for (final p in grouped.values) {
        batch.insert(
          _db.saleProducts,
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            ucode: p.ucode,
            barcode: Value(p.barcode),
            categoryId: Value(p.categoryId),
            quantity: p.quantity,
            price: p.price,
            priceBefore: p.priceBefore,
          ),
        );
      }
    });
  }

  Future<void> _persistUniversalProducts(
    int receiptNo,
    int posId,
    List<SaleProductEntry> products,
  ) async {
    final grouped = <String, SaleProductEntry>{};

    for (final p in products) {
      final key = p.price.toString();

      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;
        grouped[key] = SaleProductEntry(
          ucode: existing.ucode,
          barcode: existing.barcode,
          categoryId: existing.categoryId,
          quantity: existing.quantity + p.quantity,
          price: existing.price,
          priceBefore: existing.priceBefore,
        );
      } else {
        grouped[key] = p;
      }
    }

    await _db.batch((batch) {
      for (final p in grouped.values) {
        batch.insert(
          _db.universalProducts,
          UniversalProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            quantity: p.quantity,
            price: p.price,
            priceBefore: Value(p.priceBefore),
          ),
        );
      }
    });
  }
}
