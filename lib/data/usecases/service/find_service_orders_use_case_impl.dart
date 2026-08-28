import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/domain/usecases/service/find_service_orders_use_case.dart';

class FindServiceOrdersUseCaseImpl implements FindServiceOrdersUseCase {
  FindServiceOrdersUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<ServiceOrderEntity>> findByStatus(
    ServiceOrderStatus status,
  ) async {
    try {
      final rows = await _db.serviceOrderDao.getByStatus(status.index);

      _logger.debug('Found ${rows.length} service orders with status $status');

      return rows.map(_mapToEntity).toList();
    } catch (e) {
      _logger.error('Failed to find service orders by status $status: $e');
      rethrow;
    }
  }

  @override
  Future<List<ServiceOrderEntity>> findActive() async {
    try {
      final rows = await _db.serviceOrderDao.getActive();

      _logger.debug('Found ${rows.length} active service orders');

      return rows.map(_mapToEntity).toList();
    } catch (e) {
      _logger.error('Failed to find active service orders: $e');
      rethrow;
    }
  }

  @override
  Future<ServiceOrderEntity?> findByOrderNumber(String orderNumber) async {
    try {
      final row = await _db.serviceOrderDao.findByOrderNumber(orderNumber);
      if (row == null) {
        _logger.debug('Service order not found: $orderNumber');
        return null;
      }

      return _mapToEntity(row);
    } catch (e) {
      _logger.error('Failed to find service order by number $orderNumber: $e');
      rethrow;
    }
  }

  @override
  Future<List<ServiceOrderEntity>> search(String query) async {
    try {
      final rows = await _db.serviceOrderDao.searchByClientNameOrPhone(query);

      _logger.debug('Search "$query" found ${rows.length} service orders');

      return rows.map(_mapToEntity).toList();
    } catch (e) {
      _logger.error('Failed to search service orders for "$query": $e');
      rethrow;
    }
  }

  ServiceOrderEntity _mapToEntity(ServiceOrder row) {
    return ServiceOrderEntity(
      id: row.id,
      orderNumber: row.orderNumber,
      receiptNo: row.receiptNo,
      posId: row.posId,
      status: ServiceOrderStatus.values[row.status],
      userId: row.userId,
      assigneeId: row.assigneeId,
      clientAgentId: row.clientAgentId,
      clientName: row.clientName,
      clientPhone: row.clientPhone,
      clientNote: row.clientNote,
      deviceDescription: row.deviceDescription,
      serialNumber: row.serialNumber,
      complaint: row.complaint,
      intakeTime: row.intakeTime,
      estimatedCompletionTime: row.estimatedCompletionTime,
      estimatedAmount: row.estimatedAmount,
      prepaymentAmount: row.prepaymentAmount,
      finalAmount: row.finalAmount,
    );
  }
}
