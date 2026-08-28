import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';

class RefundInitiationUseCaseImpl implements RefundInitiationUseCase {
  RefundInitiationUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _stateInProgress = 0;

  @override
  Future<Refund?> getInProgress() async {
    final refund = await _db.refundDao.findWithState(_stateInProgress);
    if (refund == null) {
      return null;
    }

    final shift = await _db.shiftDao.findOpenedShift();
    if (shift == null) {
      _logger.warning('RefundInitiation: no opened shift');
      return refund;
    }

    await (_db.update(_db.refunds)
          ..where((r) => r.localId.equals(refund.localId)))
        .write(RefundsCompanion(userId: Value(shift.userId)));

    return await _db.refundDao.findWithState(_stateInProgress);
  }

  @override
  Future<Refund?> initiate({
    int? saleReceiptNo,
    int? salePosId,
    int? saleId,
    int? saleWeightRoundType,
    int? saleDiscountsRoundType,
    int? customerLocalId,
    int? customerServerId,
  }) async {
    var refund = await _db.refundDao.findWithState(_stateInProgress);

    final shift = await _db.shiftDao.findOpenedShift();
    if (shift == null) {
      throw StateError('RefundInitiation: no opened shift');
    }

    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) {
      throw StateError('RefundInitiation: ThisPos not found');
    }

    final weightRoundType =
        saleWeightRoundType ?? thisPos.weightProductRoundType;
    final discountsRoundType =
        saleDiscountsRoundType ?? thisPos.discountsRoundType;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (refund != null) {
      await (_db.update(
        _db.refunds,
      )..where((r) => r.localId.equals(refund.localId))).write(
        RefundsCompanion(
          userId: Value(shift.userId),
          saleId: Value(saleId),
          saleReceiptNo: Value(saleReceiptNo),
          salePosId: Value(salePosId),
          weightProductRoundType: Value(weightRoundType),
          discountsRoundType: Value(discountsRoundType),
          customerLocalId: Value(customerLocalId),
          customerServerId: Value(customerServerId),
          isOfd: const Value(false),
        ),
      );

      _logger.info(
        'RefundInitiation: updated in-progress refund=${refund.localId}',
      );
    } else {
      await _db
          .into(_db.refunds)
          .insert(
            RefundsCompanion.insert(
              userId: shift.userId,
              time: now,
              state: const Value(0),
              saleId: Value(saleId),
              saleReceiptNo: Value(saleReceiptNo),
              salePosId: Value(salePosId),
              weightProductRoundType: Value(weightRoundType),
              discountsRoundType: Value(discountsRoundType),
              customerLocalId: Value(customerLocalId),
              customerServerId: Value(customerServerId),
              isOfd: const Value(false),
            ),
          );

      _logger.info(
        'RefundInitiation: created new refund for '
        'sale=$saleReceiptNo, pos=$salePosId',
      );
    }

    return _db.refundDao.findWithState(_stateInProgress);
  }
}
