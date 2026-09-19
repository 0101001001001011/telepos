import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/receipt_numbers.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';
import 'package:telepos/domain/usecases/restaurant/create_table_order_use_case.dart';

class CreateTableOrderUseCaseImpl implements CreateTableOrderUseCase {
  CreateTableOrderUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger,
      _receiptNumbers = ReceiptNumbers(db);

  final AppDatabase _db;
  final Talker _logger;
  final ReceiptNumbers _receiptNumbers;

  static const int _stateInProgress = 0;

  @override
  Future<RestaurantOrderEntity> create({
    int? tableId,
    int partySize = 1,
    OrderType orderType = OrderType.dineIn,
    int? waiterId,
    String? note,
  }) async {
    try {
      if (tableId != null) {
        final existingOrder = await _db.restaurantOrderDao.findOpenByTable(
          tableId,
        );
        if (existingOrder != null) {
          throw StateError(
            'CreateTableOrder: table $tableId already has open order '
            '${existingOrder.id}',
          );
        }
      }

      final thisPos = await _db.thisPosDao.get();
      if (thisPos == null) {
        throw StateError('CreateTableOrder: ThisPos not configured');
      }

      final posId = thisPos.id;
      if (posId == null) {
        throw StateError('CreateTableOrder: ThisPos has no id');
      }

      final shift = await _db.shiftDao.findOpenedShift();
      if (shift == null) {
        throw StateError('CreateTableOrder: no opened shift');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Владелец обязателен при `state = 0` (правило смысла
      // `Sales.terminalId`) — без него чек в работе не находит никто,
      // включая `findInProgress`. Терминал — `terminals.self`: этот стол
      // заводит сама касса, тот же приём, что и
      // `sale_initiation_use_case_impl.dart`, пока задача 5 не даёт
      // довод `terminalId` явно.
      final terminalId = (await _db.terminalDao.self())?.id ?? 0;

      // Номер закрепляется атомарно вместе с полной строкой — тот же
      // класс, что и `sale_initiation_use_case_impl.dart` (задача 4,
      // круг правки 1): `findLastReceiptNo() ?? 0) + 1` здесь на месте
      // делил один и тот же счётчик с продажей и с закрытием заказа
      // услуги без всякой защиты от гонки между ними.
      final nextReceiptNo = await _receiptNumbers.withNext(posId, (
        receiptNo,
      ) async {
        await _db
            .into(_db.sales)
            .insert(
              SalesCompanion.insert(
                receiptNo: receiptNo,
                posId: posId,
                userId: shift.userId,
                amount: Decimal.zero,
                time: now,
                storeId: Value(thisPos.storeId),
                state: const Value(_stateInProgress),
                isWholesale: const Value(false),
                isOfd: const Value(false),
                orderType: Value(orderType.index),
                terminalId: Value(terminalId),
              ),
            );
        return receiptNo;
      });

      _logger.info(
        'CreateTableOrder: created sale '
        'receipt=$nextReceiptNo, pos=$posId',
      );

      final orderId = await _db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(
          tableId: Value(tableId),
          receiptNo: Value(nextReceiptNo),
          posId: Value(posId),
          partySize: Value(partySize),
          orderType: Value(orderType.index),
          openTime: now,
          waiterId: Value(waiterId),
          note: Value(note),
        ),
      );

      _logger.info(
        'CreateTableOrder: created order id=$orderId, '
        'table=$tableId, type=${orderType.name}',
      );

      if (tableId != null) {
        await _db.restaurantTableDao.updateStatus(
          tableId,
          TableStatus.occupied.index,
        );
        _logger.info('CreateTableOrder: table $tableId -> occupied');
      }

      final order = await _db.restaurantOrderDao.findById(orderId);
      return _mapToEntity(order!);
    } catch (e) {
      _logger.error(
        'CreateTableOrder: failed to create order '
        'for table $tableId: $e',
      );
      rethrow;
    }
  }

  RestaurantOrderEntity _mapToEntity(RestaurantOrder row) {
    return RestaurantOrderEntity(
      id: row.id,
      tableId: row.tableId,
      receiptNo: row.receiptNo,
      posId: row.posId,
      partySize: row.partySize,
      orderType: OrderType.values[row.orderType],
      openTime: row.openTime,
      closeTime: row.closeTime,
      waiterId: row.waiterId,
      tips: row.tips,
      deliveryAddress: row.deliveryAddress,
      deliveryPhone: row.deliveryPhone,
      note: row.note,
    );
  }
}
