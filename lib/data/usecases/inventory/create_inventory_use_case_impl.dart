import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/inventory/create_inventory_use_case.dart';

class CreateInventoryUseCaseImpl implements CreateInventoryUseCase {
  CreateInventoryUseCaseImpl();

  AppDatabase get _db => GetIt.I<AppDatabase>();
  Talker get _logger => GetIt.I<Talker>();

  @override
  Future<int> create({
    String? comment,
    int? userId,
    bool isFullCount = false,
  }) async {
    try {
      final existing = await _db.inventoryDao.findActive();
      if (existing != null) {
        _logger.warning('Active inventory already exists: ${existing.id}');
        return existing.id;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final inventoryId = await _db.inventoryDao.insertInventory(
        InventoriesCompanion(
          userId: Value(userId),
          startTime: Value(now),
          status: const Value(0),
          comment: Value(comment),
          state: const Value(0),
          isFullCount: Value(isFullCount),
        ),
      );

      _logger.info('Inventory created: id=$inventoryId');
      return inventoryId;
    } catch (e) {
      _logger.error('Failed to create inventory: $e');
      rethrow;
    }
  }

  @override
  Future<void> upsertProduct({
    required int inventoryId,
    required int ucode,
    required Decimal expectedQty,
    required Decimal actualQty,
    required Decimal price,
  }) async {
    try {
      final difference = actualQty - expectedQty;

      await _db.inventoryProductDao.upsert(
        inventoryId: inventoryId,
        ucode: ucode,
        product: InventoryProductsCompanion(
          inventoryId: Value(inventoryId),
          ucode: Value(ucode),
          expectedQty: Value(expectedQty),
          actualQty: Value(actualQty),
          difference: Value(difference),
          price: Value(price),
        ),
      );

      _logger.debug(
        'Inventory product upserted: inventory=$inventoryId, '
        'ucode=$ucode, expected=$expectedQty, actual=$actualQty, diff=$difference',
      );
    } catch (e) {
      _logger.error('Failed to upsert inventory product: $e');
      rethrow;
    }
  }

  @override
  Future<CreateInventoryResult> complete(int inventoryId) async {
    try {
      final products = await _db.inventoryProductDao.findByInventoryId(
        inventoryId,
      );

      if (products.isEmpty) {
        return CreateInventoryResult.failed('Нет товаров в инвентаризации');
      }

      final discrepancyCount = products
          .where((p) => (p.actualQty - p.expectedQty) != Decimal.zero)
          .length;

      final inventory = await _db.inventoryDao.findById(inventoryId);
      final isFullCount = inventory?.isFullCount ?? false;

      await _db.inventoryDao.complete(inventoryId, discrepancyCount);

      final countedUcodes = <int>{};
      for (final p in products) {
        await _db.productInfoDao.updateQuantity(p.ucode, p.actualQty);
        countedUcodes.add(p.ucode);
      }

      var zeroedCount = 0;
      if (isFullCount) {
        const pageSize = 500;
        var offset = 0;
        while (true) {
          final page = await _db.productInfoDao.findAll(
            includeDeleted: false,
            limit: pageSize,
            offset: offset,
          );
          if (page.isEmpty) break;
          for (final product in page) {
            if (countedUcodes.contains(product.ucode)) continue;
            final currentQty = product.quantity ?? Decimal.zero;
            if (currentQty == Decimal.zero) continue;
            await _db.productInfoDao.updateQuantity(
              product.ucode,
              Decimal.zero,
            );
            zeroedCount++;
          }
          if (page.length < pageSize) break;
          offset += pageSize;
        }
      }

      _logger.info(
        'Inventory completed (${isFullCount ? 'full' : 'selective/scan-driven'}): '
        'id=$inventoryId, ${products.length} counted products adjusted, '
        '$discrepancyCount discrepancies'
        '${isFullCount ? ', $zeroedCount un-counted items zeroed' : '. Un-counted catalog items keep their previous quantity.'}',
      );

      return CreateInventoryResult.saved(
        inventoryId: inventoryId,
        productCount: products.length,
        discrepancyCount: discrepancyCount,
      );
    } catch (e) {
      _logger.error('Failed to complete inventory: $e');
      return CreateInventoryResult.failed(
        'Ошибка завершения инвентаризации: $e',
      );
    }
  }
}
