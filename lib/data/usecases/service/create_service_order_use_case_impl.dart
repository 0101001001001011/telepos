import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/service/create_service_order_use_case.dart';

class CreateServiceOrderUseCaseImpl implements CreateServiceOrderUseCase {
  CreateServiceOrderUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<ServiceOrderEntity> create({
    required int userId,
    int? clientAgentId,
    String? clientName,
    String? clientPhone,
    String? clientNote,
    String? deviceDescription,
    String? serialNumber,
    String? complaint,
    int? estimatedCompletionTime,
    Decimal? estimatedAmount,
    Decimal? prepaymentAmount,
  }) async {
    try {
      final orderNumber = await _db.serviceOrderDao.generateOrderNumber();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final id = await _db.serviceOrderDao.insert(
        ServiceOrdersCompanion(
          orderNumber: Value(orderNumber),
          status: const Value(0),
          userId: Value(userId),
          clientAgentId: Value(clientAgentId),
          clientName: Value(clientName),
          clientPhone: Value(clientPhone),
          clientNote: Value(clientNote),
          deviceDescription: Value(deviceDescription),
          serialNumber: Value(serialNumber),
          complaint: Value(complaint),
          intakeTime: Value(now),
          estimatedCompletionTime: Value(estimatedCompletionTime),
          estimatedAmount: Value(estimatedAmount),
          prepaymentAmount: Value(prepaymentAmount),
        ),
      );

      _logger.info(
        'Service order created: id=$id, orderNumber=$orderNumber, '
        'userId=$userId, client=${clientName ?? clientAgentId}',
      );

      if (prepaymentAmount != null && prepaymentAmount > Decimal.zero) {
        await _bookPrepayment(
          orderId: id,
          orderNumber: orderNumber,
          amount: prepaymentAmount,
        );
      }

      return ServiceOrderEntity(
        id: id,
        orderNumber: orderNumber,
        status: ServiceOrderStatus.intake,
        userId: userId,
        clientAgentId: clientAgentId,
        clientName: clientName,
        clientPhone: clientPhone,
        clientNote: clientNote,
        deviceDescription: deviceDescription,
        serialNumber: serialNumber,
        complaint: complaint,
        intakeTime: now,
        estimatedCompletionTime: estimatedCompletionTime,
        estimatedAmount: estimatedAmount,
        prepaymentAmount: prepaymentAmount,
      );
    } catch (e) {
      _logger.error('Failed to create service order: $e');
      rethrow;
    }
  }

  Future<void> _bookPrepayment({
    required int orderId,
    required String orderNumber,
    required Decimal amount,
  }) async {
    try {
      final cashController = GetIt.I<CashInOutController>();

      int? accountId = (await _db.thisPosDao.get())?.accountId;
      if (accountId == null) {
        final posAccounts = await _db.accountDao.findByType(AccountType.pos);
        accountId = posAccounts.isNotEmpty ? posAccounts.first.id : null;
      }
      if (accountId == null) {
        _logger.warning(
          'Service prepayment $orderNumber: no POS account — '
          'prepayment $amount not booked to cash',
        );
        return;
      }

      final result = await cashController.createInvestment(
        amount: amount,
        accountId: accountId,
        note: 'Предоплата по заказ-наряду $orderNumber',
      );

      if (result.success) {
        _logger.info(
          'Service prepayment booked as cash-in: order=$orderId, '
          'amount=$amount, account=$accountId, op=${result.operationId}',
        );
      } else {
        _logger.warning(
          'Service prepayment $orderNumber not booked: ${result.refusal?.name ?? result.errorDetail}',
        );
      }
    } catch (e) {
      _logger.error('Failed to book service prepayment $orderNumber: $e');
    }
  }
}
