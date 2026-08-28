import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/clear_refund_use_case.dart';

class ClearRefundUseCaseImpl implements ClearRefundUseCase {
  ClearRefundUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> clear({required int refundLocalId}) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.refundProducts,
      )..where((rp) => rp.refundLocalId.equals(refundLocalId))).go();

      await (_db.delete(
        _db.refunds,
      )..where((r) => r.localId.equals(refundLocalId))).go();

      _logger.info('ClearRefund: deleted refund=$refundLocalId with products');
    });
  }
}
