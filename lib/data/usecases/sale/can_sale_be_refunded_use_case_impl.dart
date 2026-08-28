import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/can_sale_be_refunded_use_case.dart';

class CanSaleBeRefundedUseCaseImpl implements CanSaleBeRefundedUseCase {
  CanSaleBeRefundedUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<bool> canBeRefunded({
    required int receiptNo,
    required int posId,
  }) async {
    final existingRefund = await _db.refundDao.findBySale(receiptNo, posId);
    if (existingRefund != null) {
      _logger.info(
        'CanSaleBeRefunded: refund already exists for '
        'receipt=$receiptNo, pos=$posId',
      );
      return false;
    }

    final payments = await _db.paymentDao.findBySale(receiptNo, posId);
    if (payments.isEmpty) {
      return true;
    }

    final thisPos = await _db.thisPosDao.get();
    final acquiringAccountId = thisPos?.acquiringAccountId;

    for (final payment in payments) {
      final account = await _db.accountDao.findById(payment.payeeAccountId);
      if (account == null) {
        _logger.warning(
          'CanSaleBeRefunded: account ${payment.payeeAccountId} not found',
        );
        continue;
      }

      if (account.acquirerId == null) {
        continue;
      }

      if (account.id != acquiringAccountId) {
        _logger.info(
          'CanSaleBeRefunded: account ${account.id} has acquirer '
          '${account.acquirerId} but POS acquiring=$acquiringAccountId',
        );
        return false;
      }
    }

    return true;
  }
}
