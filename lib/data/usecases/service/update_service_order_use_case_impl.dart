import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/domain/usecases/service/update_service_order_use_case.dart';

class UpdateServiceOrderUseCaseImpl implements UpdateServiceOrderUseCase {
  UpdateServiceOrderUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> update(ServiceOrderEntity order) async {
    try {
      final driftModel = ServiceOrder(
        id: order.id,
        orderNumber: order.orderNumber,
        receiptNo: order.receiptNo,
        posId: order.posId,
        status: order.status.index,
        userId: order.userId,
        assigneeId: order.assigneeId,
        clientAgentId: order.clientAgentId,
        clientName: order.clientName,
        clientPhone: order.clientPhone,
        clientNote: order.clientNote,
        deviceDescription: order.deviceDescription,
        serialNumber: order.serialNumber,
        complaint: order.complaint,
        intakeTime: order.intakeTime,
        estimatedCompletionTime: order.estimatedCompletionTime,
        estimatedAmount: order.estimatedAmount,
        prepaymentAmount: order.prepaymentAmount,
        finalAmount: order.finalAmount,
        warrantyDays: order.warrantyDays,
        qualityRating: order.qualityRating,
        qualityNote: order.qualityNote,
        intakeInventory: order.intakeInventory,
      );

      await _db.serviceOrderDao.updateOrder(driftModel);

      _logger.info(
        'Service order updated: id=${order.id}, '
        'orderNumber=${order.orderNumber}, status=${order.status}',
      );
    } catch (e) {
      _logger.error('Failed to update service order ${order.id}: $e');
      rethrow;
    }
  }
}
