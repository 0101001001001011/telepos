import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/payment/purchase_with_cash_use_case.dart';

class PurchaseWithCashUseCaseImpl implements PurchaseWithCashUseCase {
  PurchaseWithCashUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<int> execute({
    required int receiptNo,
    required int posId,
    required Decimal amount,
  }) async {
    final thisPos = await _db.thisPosDao.get();
    final accountId = thisPos?.accountId;

    if (accountId == null) {
      throw StateError('PurchaseWithCash: no cash accountId in ThisPos');
    }

    final sales =
        await (_db.select(_db.sales)..where(
              (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
            ))
            .get();

    if (sales.isEmpty) {
      throw StateError(
        'PurchaseWithCash: sale receiptNo=$receiptNo, posId=$posId not found',
      );
    }

    final sale = sales.first;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final paymentId = await _db
        .into(_db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: sale.userId,
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            payeeAccountId: accountId,
            amount: amount,
            time: now,
          ),
        );

    _logger.info(
      'PurchaseWithCash: created payment id=$paymentId, '
      'receiptNo=$receiptNo, posId=$posId, amount=$amount',
    );

    return paymentId;
  }

  @override
  Future<int> executeForRefund({
    required int refundLocalId,
    required Decimal amount,
  }) async {
    final thisPos = await _db.thisPosDao.get();
    final accountId = thisPos?.accountId;

    if (accountId == null) {
      throw StateError('PurchaseWithCash: no cash accountId in ThisPos');
    }

    final refunds = await (_db.select(
      _db.refunds,
    )..where((r) => r.localId.equals(refundLocalId))).get();

    if (refunds.isEmpty) {
      throw StateError('PurchaseWithCash: refund $refundLocalId not found');
    }

    final refund = refunds.first;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final paymentId = await _db
        .into(_db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: refund.userId,
            refundLocalId: Value(refundLocalId),
            payeeAccountId: accountId,
            amount: amount,
            time: now,
          ),
        );

    _logger.info(
      'PurchaseWithCash: created refund payment id=$paymentId, '
      'refundLocalId=$refundLocalId, amount=$amount',
    );

    return paymentId;
  }
}
