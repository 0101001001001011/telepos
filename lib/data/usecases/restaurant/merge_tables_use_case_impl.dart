import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/merge_tables_use_case.dart';

class MergeTablesUseCaseImpl implements MergeTablesUseCase {
  MergeTablesUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> merge(List<int> orderIds, int targetTableId) async {
    if (orderIds.length < 2) {
      throw ArgumentError('MergeTables: need at least 2 orders to merge');
    }

    try {
      final targetOrder = await _db.restaurantOrderDao.findOpenByTable(
        targetTableId,
      );
      if (targetOrder == null) {
        throw StateError(
          'MergeTables: no open order on target table $targetTableId',
        );
      }

      final targetReceiptNo = targetOrder.receiptNo;
      final targetPosId = targetOrder.posId;
      if (targetReceiptNo == null || targetPosId == null) {
        throw StateError(
          'MergeTables: target order ${targetOrder.id} is not linked to a sale',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      for (final orderId in orderIds) {
        if (orderId == targetOrder.id) continue;

        final sourceOrder = await _db.restaurantOrderDao.findById(orderId);
        if (sourceOrder == null) {
          _logger.warning('MergeTables: source order $orderId not found, skip');
          continue;
        }

        final srcReceiptNo = sourceOrder.receiptNo;
        final srcPosId = sourceOrder.posId;

        if (srcReceiptNo != null && srcPosId != null) {
          final products = await _db.saleProductDao.findBySale(
            srcReceiptNo,
            srcPosId,
          );

          for (final product in products) {
            await _db
                .into(_db.saleProducts)
                .insert(
                  SaleProductsCompanion.insert(
                    receiptNo: Value(targetReceiptNo),
                    posId: Value(targetPosId),
                    ucode: product.ucode,
                    quantity: product.quantity,
                    price: product.price,
                    priceBefore: product.priceBefore,
                    barcode: Value(product.barcode),
                    categoryId: Value(product.categoryId),
                  ),
                );
          }

          _logger.info(
            'MergeTables: moved ${products.length} products '
            'from order $orderId to order ${targetOrder.id}',
          );

          await _db.saleDao.updateState(srcReceiptNo, srcPosId, 1);
        }

        await _db.restaurantOrderDao.closeOrder(orderId, now);

        final sourceTableId = sourceOrder.tableId;
        if (sourceTableId != null && sourceTableId != targetTableId) {
          await _db.restaurantTableDao.updateStatus(
            sourceTableId,
            TableStatus.free.index,
          );
          _logger.info('MergeTables: table $sourceTableId -> free');
        }
      }

      final targetProducts = await _db.saleProductDao.findBySale(
        targetReceiptNo,
        targetPosId,
      );
      var totalAmount = Decimal.zero;
      for (final p in targetProducts) {
        totalAmount += p.price * p.quantity;
      }
      await _db.saleDao.setAmount(targetReceiptNo, targetPosId, totalAmount);

      _logger.info(
        'MergeTables: merged ${orderIds.length} orders '
        'into order ${targetOrder.id} on table $targetTableId, '
        'total amount=$totalAmount',
      );
    } catch (e) {
      _logger.error(
        'MergeTables: failed to merge orders $orderIds '
        'into table $targetTableId: $e',
      );
      rethrow;
    }
  }
}
