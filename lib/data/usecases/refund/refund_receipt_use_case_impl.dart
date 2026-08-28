import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/refund_receipt_use_case.dart';

class RefundReceiptUseCaseImpl implements RefundReceiptUseCase {
  RefundReceiptUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<RefundReceipt> wrap({required int refundLocalId}) async {
    final refunds = await (_db.select(
      _db.refunds,
    )..where((r) => r.localId.equals(refundLocalId))).get();

    if (refunds.isEmpty) {
      throw StateError('Refund $refundLocalId not found');
    }

    final refund = refunds.first;

    SaleWithdrawal? withdrawal;
    if (refund.saleReceiptNo != null && refund.salePosId != null) {
      withdrawal = await _db.saleDao.findWithdrawalBySale(
        refund.saleReceiptNo!,
        refund.salePosId!,
      );
    }

    _logger.info(
      'RefundReceipt: wrapped refund=$refundLocalId, '
      'withdrawalAmount=${withdrawal?.amount}',
    );

    return RefundReceipt(
      localId: refund.localId,
      amount: refund.amount,
      time: refund.time,
      userId: refund.userId,
      saleReceiptNo: refund.saleReceiptNo,
      salePosId: refund.salePosId,
      saleId: refund.saleId,
      customerLocalId: refund.customerLocalId,
      customerServerId: refund.customerServerId,
      cashbackAmount: refund.cashbackAmount,
      isOfd: refund.isOfd,
      state: refund.state,
      withdrawalAmount: withdrawal?.amount,
    );
  }
}
