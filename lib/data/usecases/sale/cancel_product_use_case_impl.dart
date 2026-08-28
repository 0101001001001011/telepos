import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/cancel_product_use_case.dart';
import 'package:telepos/domain/usecases/sale/universal_product_use_case.dart';

class CancelProductUseCaseImpl implements CancelProductUseCase {
  CancelProductUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _aggregationWindowMs = 60000;

  static const int _pendingSync = 1;
  static const int _beingSent = 2;
  static const int _synced = 3;

  @override
  Future<void> onCancel({
    required int ucode,
    required Decimal expectedQuantity,
    required Decimal cancelledQuantity,
  }) async {
    if (ucode == UniversalProductUseCase.universalUcode) {
      return;
    }

    final now = DateTime.now();
    final minuteAgo = now.subtract(
      const Duration(milliseconds: _aggregationWindowMs),
    );

    final recentCancellations = await _db.cancelledProductDao
        .findByUcodeAndDateAfter(ucode, minuteAgo);

    CancelledProduct? aggregatable;
    for (final cp in recentCancellations) {
      if (_canBeAddedTo(cp, cancelledQuantity, expectedQuantity)) {
        aggregatable = cp;
        break;
      }
    }

    if (aggregatable == null) {
      final shift = await _db.shiftDao.findOpenedShift();

      await _db
          .into(_db.cancelledProducts)
          .insert(
            CancelledProductsCompanion(
              ucode: Value(ucode),
              expectedQuantity: Value(expectedQuantity),
              quantity: Value(cancelledQuantity),
              userId: Value(shift?.userId),
              date: Value(now),
              syncStatus: const Value(_pendingSync),
            ),
          );

      _logger.info(
        'CancelProduct: new cancellation ucode=$ucode, '
        'qty=$cancelledQuantity, expected=$expectedQuantity',
      );
    } else {
      await _db.cancelledProductDao.setSyncStatus([
        aggregatable.id,
      ], _beingSent);

      final newQuantity =
          (aggregatable.quantity ?? Decimal.zero) + cancelledQuantity;

      await ((_db.update(
        _db.cancelledProducts,
      ))..where((c) => c.id.equals(aggregatable!.id))).write(
        CancelledProductsCompanion(
          quantity: Value(newQuantity),
          date: Value(now),
          syncStatus: const Value(_pendingSync),
        ),
      );

      _logger.info(
        'CancelProduct: aggregated into id=${aggregatable.id}, '
        'ucode=$ucode, newQty=$newQuantity',
      );
    }
  }

  bool _canBeAddedTo(
    CancelledProduct cp,
    Decimal cancelledQuantity,
    Decimal expectedQuantity,
  ) {
    if (cp.syncStatus == _synced) return false;

    final existingQuantity = cp.quantity ?? Decimal.zero;
    final existingExpected = cp.expectedQuantity ?? Decimal.zero;

    final quantityToCancel = existingQuantity + cancelledQuantity;
    final initialQuantity = expectedQuantity + existingQuantity;

    if ((existingExpected - quantityToCancel) <= Decimal.zero) return false;

    if (initialQuantity != existingExpected) return false;

    return true;
  }
}
