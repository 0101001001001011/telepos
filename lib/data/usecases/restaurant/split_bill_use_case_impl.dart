import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/restaurant/guest_split_entry.dart';
import 'package:telepos/domain/usecases/restaurant/split_bill_use_case.dart';

class SplitBillUseCaseImpl implements SplitBillUseCase {
  SplitBillUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> splitEvenly(int orderId, int guestCount) async {
    if (guestCount <= 0) {
      throw ArgumentError('SplitBill: guestCount must be > 0');
    }

    try {
      final order = await _db.restaurantOrderDao.findById(orderId);
      if (order == null) {
        throw StateError('SplitBill: order $orderId not found');
      }

      final receiptNo = order.receiptNo;
      final posId = order.posId;
      if (receiptNo == null || posId == null) {
        throw StateError('SplitBill: order $orderId is not linked to a sale');
      }

      final products = await _db.saleProductDao.findBySale(receiptNo, posId);
      if (products.isEmpty) {
        _logger.warning('SplitBill: no products in order $orderId');
        return;
      }

      await _db.guestSplitDao.deleteByOrder(orderId);

      final guestCountDecimal = Decimal.fromInt(guestCount);
      final sharePerGuest = (Decimal.one / guestCountDecimal).toDecimal(
        scaleOnInfinitePrecision: 10,
      );
      final remainder =
          Decimal.one - sharePerGuest * Decimal.fromInt(guestCount - 1);

      final entries = <GuestSplitsCompanion>[];
      for (final product in products) {
        for (int guest = 1; guest <= guestCount; guest++) {
          final share = guest == guestCount ? remainder : sharePerGuest;
          entries.add(
            GuestSplitsCompanion.insert(
              orderId: orderId,
              guestNumber: guest,
              saleProductId: product.id,
              shareQuantity: share,
            ),
          );
        }
      }

      await _db.guestSplitDao.insertAll(entries);

      _logger.info(
        'SplitBill: split order $orderId evenly among '
        '$guestCount guests (${entries.length} entries)',
      );
    } catch (e) {
      _logger.error('SplitBill: failed to split order $orderId evenly: $e');
      rethrow;
    }
  }

  @override
  Future<void> splitByItems(int orderId, List<GuestSplitEntry> splits) async {
    try {
      await _db.guestSplitDao.deleteByOrder(orderId);

      final entries = splits
          .map(
            (s) => GuestSplitsCompanion.insert(
              orderId: s.orderId,
              guestNumber: s.guestNumber,
              saleProductId: s.saleProductId,
              shareQuantity: s.shareQuantity,
            ),
          )
          .toList();

      await _db.guestSplitDao.insertAll(entries);

      _logger.info(
        'SplitBill: split order $orderId by items (${entries.length} entries)',
      );
    } catch (e) {
      _logger.error('SplitBill: failed to split order $orderId by items: $e');
      rethrow;
    }
  }

  @override
  Future<List<GuestSplitEntry>> getSplits(int orderId) async {
    try {
      final rows = await _db.guestSplitDao.getByOrder(orderId);

      _logger.info(
        'SplitBill: loaded ${rows.length} splits for order $orderId',
      );

      return rows.map(_mapToEntry).toList();
    } catch (e) {
      _logger.error('SplitBill: failed to get splits for order $orderId: $e');
      rethrow;
    }
  }

  GuestSplitEntry _mapToEntry(GuestSplit row) {
    return GuestSplitEntry(
      id: row.id,
      orderId: row.orderId,
      guestNumber: row.guestNumber,
      saleProductId: row.saleProductId,
      shareQuantity: row.shareQuantity,
    );
  }
}
