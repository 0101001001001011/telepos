import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/find_refund_use_case.dart';

class FindRefundUseCaseImpl implements FindRefundUseCase {
  FindRefundUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<Refund?> findByLocalId({required int localId}) async {
    final refunds = await (_db.select(
      _db.refunds,
    )..where((r) => r.localId.equals(localId))).get();

    if (refunds.isNotEmpty) {
      _logger.info('FindRefund: found by localId=$localId');
      return refunds.first;
    }

    _logger.info('FindRefund: not found by localId=$localId');
    return null;
  }

  @override
  Future<Refund?> findBySale({
    required int saleReceiptNo,
    required int salePosId,
  }) async {
    final refund = await _db.refundDao.findBySale(saleReceiptNo, salePosId);

    if (refund != null) {
      _logger.info(
        'FindRefund: found by sale receiptNo=$saleReceiptNo, posId=$salePosId',
      );
      return refund;
    }

    _logger.info(
      'FindRefund: not found by sale receiptNo=$saleReceiptNo, posId=$salePosId',
    );
    return null;
  }

  @override
  Future<Refund?> findByServerId({required int serverId}) async {
    final localId = await _db.refundDao.findLocalIdByServerId(serverId);

    if (localId != null) {
      final refunds = await (_db.select(
        _db.refunds,
      )..where((r) => r.localId.equals(localId))).get();

      if (refunds.isNotEmpty) {
        _logger.info('FindRefund: found by serverId=$serverId');
        return refunds.first;
      }
    }

    _logger.info('FindRefund: not found by serverId=$serverId');
    return null;
  }
}
