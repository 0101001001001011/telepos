import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_mark_entity.dart';
import 'package:telepos/domain/usecases/service/approve_service_mark_use_case.dart';

class ApproveServiceMarkUseCaseImpl implements ApproveServiceMarkUseCase {
  ApproveServiceMarkUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _approved = 1;
  static const int _rejected = 2;

  @override
  Future<ServiceMarkEntity> approve({
    required int markId,
    required int approverUserId,
  }) => _setStatus(
    markId: markId,
    status: _approved,
    approverUserId: approverUserId,
  );

  @override
  Future<ServiceMarkEntity> reject({
    required int markId,
    required int approverUserId,
  }) => _setStatus(
    markId: markId,
    status: _rejected,
    approverUserId: approverUserId,
  );

  Future<ServiceMarkEntity> _setStatus({
    required int markId,
    required int status,
    required int approverUserId,
  }) async {
    try {
      await _db.serviceMarkDao.updateApprovalStatus(markId, status);

      final row = await (_db.select(
        _db.serviceMarks,
      )..where((m) => m.id.equals(markId))).getSingle();

      if (status == _rejected) {
        try {
          await _db.serviceMarkDao.restoreStockFor(row);
        } catch (e) {
          _logger.warning(
            'Reject mark $markId: failed to restore consumable stock: $e',
          );
        }
      }

      _logger.info(
        'Service mark $markId approval set to $status '
        '(approver=$approverUserId, order=${row.serviceOrderId})',
      );

      return ServiceMarkEntity(
        id: row.id,
        serviceOrderId: row.serviceOrderId,
        description: row.description,
        markType: row.markType,
        userId: row.userId,
        cost: row.cost,
        createdAt: row.createdAt,
        note: row.note,
        productUcode: row.productUcode,
        approvalStatus: row.approvalStatus,
        quantity: row.quantity,
      );
    } catch (e) {
      _logger.error(
        'Failed to set approval status $status for mark $markId: $e',
      );
      rethrow;
    }
  }
}
