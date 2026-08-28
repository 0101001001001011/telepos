import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_mark_entity.dart';
import 'package:telepos/domain/usecases/service/add_service_mark_use_case.dart';

class AddServiceMarkUseCaseImpl implements AddServiceMarkUseCase {
  AddServiceMarkUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<ServiceMarkEntity> add({
    required int serviceOrderId,
    required String description,
    required int markType,
    required int userId,
    Decimal? cost,
    String? note,
    int? productUcode,
    int? approvalStatus,
    Decimal? quantity,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final markQuantity = quantity ?? Decimal.one;

      final id = await _db.serviceMarkDao.insert(
        ServiceMarksCompanion(
          serviceOrderId: Value(serviceOrderId),
          description: Value(description),
          markType: Value(markType),
          userId: Value(userId),
          cost: Value(cost),
          createdAt: Value(now),
          note: Value(note),
          productUcode: Value(productUcode),
          approvalStatus: Value(approvalStatus),
          quantity: Value(markQuantity),
        ),
      );

      final isConsumable =
          productUcode != null && (markType == 5 || markType == 1);
      if (isConsumable) {
        await _consumeStock(
          ucode: productUcode,
          quantity: markQuantity,
          serviceOrderId: serviceOrderId,
          markId: id,
        );
      }

      _logger.info(
        'Service mark added: id=$id, orderId=$serviceOrderId, '
        'type=$markType, cost=$cost, productUcode=$productUcode',
      );

      return ServiceMarkEntity(
        id: id,
        serviceOrderId: serviceOrderId,
        description: description,
        markType: markType,
        userId: userId,
        cost: cost,
        createdAt: now,
        note: note,
        productUcode: productUcode,
        approvalStatus: approvalStatus,
        quantity: markQuantity,
      );
    } catch (e) {
      _logger.error('Failed to add service mark to order $serviceOrderId: $e');
      rethrow;
    }
  }

  Future<void> _consumeStock({
    required int ucode,
    required Decimal quantity,
    required int serviceOrderId,
    required int markId,
  }) async {
    if (quantity <= Decimal.zero) return;
    try {
      final product = await _db.productInfoDao.findByUcode(ucode);
      if (product == null) {
        _logger.warning(
          'Service consume: product ucode=$ucode not found in catalog — '
          'stock not decremented (order=$serviceOrderId, mark=$markId)',
        );
        return;
      }
      await _db.productInfoDao.adjustQuantity(ucode, -quantity);
      final before = product.quantity ?? Decimal.zero;
      _logger.info(
        'Service consume: ucode=$ucode stock $before → ${before - quantity} '
        '(−$quantity, order=$serviceOrderId, mark=$markId)',
      );
    } catch (e) {
      _logger.error(
        'Service consume failed for ucode=$ucode '
        '(order=$serviceOrderId, mark=$markId): $e',
      );
    }
  }
}
