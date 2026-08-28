import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_mark_entity.dart';
import 'package:telepos/domain/usecases/service/service_order_receipt_use_case.dart';

class ServiceOrderReceiptUseCaseImpl implements ServiceOrderReceiptUseCase {
  ServiceOrderReceiptUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<ServiceOrderReceiptData> generateIntakeReceipt(int orderId) async {
    try {
      final order = await _db.serviceOrderDao.findById(orderId);
      if (order == null) {
        throw StateError('Service order not found: $orderId');
      }

      String clientName = order.clientName ?? '';
      if (clientName.isEmpty && order.clientAgentId != null) {
        final agent = await _db.agentDao.findById(order.clientAgentId!);
        if (agent != null) {
          clientName = agent.name ?? '';
        }
      }
      if (clientName.isEmpty) {
        clientName = order.clientPhone ?? 'N/A';
      }

      _logger.info(
        'Generated intake receipt for order $orderId '
        '(${order.orderNumber})',
      );

      return ServiceOrderReceiptData(
        orderNumber: order.orderNumber,
        clientName: clientName,
        deviceDescription: order.deviceDescription,
        complaint: order.complaint,
        intakeTime: order.intakeTime,
        estimatedCompletionTime: order.estimatedCompletionTime,
        estimatedAmount: order.estimatedAmount,
      );
    } catch (e) {
      _logger.error('Failed to generate intake receipt for order $orderId: $e');
      rethrow;
    }
  }

  @override
  Future<ServiceOrderReceiptData> generateCompletionReceipt(int orderId) async {
    try {
      final order = await _db.serviceOrderDao.findById(orderId);
      if (order == null) {
        throw StateError('Service order not found: $orderId');
      }

      String clientName = order.clientName ?? '';
      if (clientName.isEmpty && order.clientAgentId != null) {
        final agent = await _db.agentDao.findById(order.clientAgentId!);
        if (agent != null) {
          clientName = agent.name ?? '';
        }
      }
      if (clientName.isEmpty) {
        clientName = order.clientPhone ?? 'N/A';
      }

      final markRows = await _db.serviceMarkDao.getByOrder(orderId);
      final marks = markRows
          .map(
            (m) => ServiceMarkEntity(
              id: m.id,
              serviceOrderId: m.serviceOrderId,
              description: m.description,
              markType: m.markType,
              userId: m.userId,
              cost: m.cost,
              createdAt: m.createdAt,
              note: m.note,
            ),
          )
          .toList();

      final totalCost = await _db.serviceMarkDao.sumCostByOrder(orderId);
      final estimatedAmount = order.finalAmount ?? totalCost;

      _logger.info(
        'Generated completion receipt for order $orderId '
        '(${order.orderNumber}), marks: ${marks.length}, '
        'total: $estimatedAmount',
      );

      return ServiceOrderReceiptData(
        orderNumber: order.orderNumber,
        clientName: clientName,
        deviceDescription: order.deviceDescription,
        complaint: order.complaint,
        intakeTime: order.intakeTime,
        estimatedCompletionTime: order.estimatedCompletionTime,
        estimatedAmount: estimatedAmount,
        marks: marks,
      );
    } catch (e) {
      _logger.error(
        'Failed to generate completion receipt for order $orderId: $e',
      );
      rethrow;
    }
  }
}
