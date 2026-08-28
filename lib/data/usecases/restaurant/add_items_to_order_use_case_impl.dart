import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/add_items_to_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/selected_modifier.dart';

class AddItemsToOrderUseCaseImpl implements AddItemsToOrderUseCase {
  AddItemsToOrderUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<int> addItem({
    required int orderId,
    required int productUcode,
    required Decimal quantity,
    required Decimal price,
    int guestNumber = 0,
    List<SelectedModifier> modifiers = const [],
  }) async {
    try {
      final order = await _db.restaurantOrderDao.findById(orderId);
      if (order == null) {
        throw StateError('AddItemsToOrder: order $orderId not found');
      }

      final receiptNo = order.receiptNo;
      final posId = order.posId;
      if (receiptNo == null || posId == null) {
        throw StateError(
          'AddItemsToOrder: order $orderId is not linked to a sale',
        );
      }

      final productInfo = await _db.productInfoDao.findByUcode(productUcode);
      if (productInfo != null && productInfo.isDeleted) {
        await _db.productInfoDao.restoreProduct(productUcode);
      }

      final saleProductId = await _db
          .into(_db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              receiptNo: Value(receiptNo),
              posId: Value(posId),
              ucode: productUcode,
              quantity: quantity,
              price: price,
              priceBefore: price,
            ),
          );

      if (modifiers.isNotEmpty) {
        for (final mod in modifiers) {
          await _db.modifierDao.insertSaleModifier(
            SaleProductModifiersCompanion.insert(
              saleProductId: saleProductId,
              modifierGroupId: mod.groupId,
              modifierOptionId: mod.optionId,
              priceAdjustment: Value(mod.priceAdjustment),
            ),
          );
        }
      }

      if (guestNumber > 0) {
        await _db.guestSplitDao.insertForItem(
          orderId,
          guestNumber,
          saleProductId,
          quantity,
        );
      }

      await _updateSaleAmount(receiptNo, posId);

      _logger.info(
        'AddItemsToOrder: added product ucode=$productUcode '
        'qty=$quantity price=$price guest=$guestNumber to order $orderId '
        '(receipt=$receiptNo, pos=$posId, spId=$saleProductId)',
      );

      return saleProductId;
    } catch (e) {
      _logger.error(
        'AddItemsToOrder: failed to add item to order $orderId: $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> removeItem(int orderId, int saleProductId) async {
    try {
      await _db.modifierDao.deleteBySaleProductId(saleProductId);

      await _db.guestSplitDao.deleteBySaleProductId(saleProductId);

      await (_db.delete(
        _db.saleProducts,
      )..where((sp) => sp.id.equals(saleProductId))).go();

      final order = await _db.restaurantOrderDao.findById(orderId);
      if (order != null && order.receiptNo != null && order.posId != null) {
        await _updateSaleAmount(order.receiptNo!, order.posId!);
      }

      _logger.info(
        'AddItemsToOrder: removed saleProduct $saleProductId '
        'from order $orderId',
      );
    } catch (e) {
      _logger.error(
        'AddItemsToOrder: failed to remove item $saleProductId '
        'from order $orderId: $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> updateItemQuantity(int saleProductId, Decimal quantity) async {
    try {
      await _db.saleProductDao.setQuantity(saleProductId, quantity);

      final sp = await (_db.select(
        _db.saleProducts,
      )..where((s) => s.id.equals(saleProductId))).getSingleOrNull();
      if (sp != null && sp.receiptNo != null && sp.posId != null) {
        await _updateSaleAmount(sp.receiptNo!, sp.posId!);
      }

      _logger.info(
        'AddItemsToOrder: updated saleProduct $saleProductId '
        'quantity=$quantity',
      );
    } catch (e) {
      _logger.error(
        'AddItemsToOrder: failed to update quantity '
        'for saleProduct $saleProductId: $e',
      );
      rethrow;
    }
  }

  Future<void> _updateSaleAmount(int receiptNo, int posId) async {
    await _db.customStatement(
      'UPDATE sales SET amount = ('
      '  SELECT COALESCE(SUM(quantity * price), 0) '
      '  FROM sale_products '
      '  WHERE receipt_no = ? AND pos_id = ?'
      ') WHERE receipt_no = ? AND pos_id = ?',
      [receiptNo, posId, receiptNo, posId],
    );
  }
}
