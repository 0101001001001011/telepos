import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/refund/refund_entity.dart';

class RefundMapper {
  RefundMapper._();

  static RefundEntity fromDrift(Refund refund) {
    return RefundEntity(
      localId: refund.localId,
      serverId: refund.serverId,
      saleId: refund.saleId,
      saleReceiptNo: refund.saleReceiptNo,
      salePosId: refund.salePosId,
      userId: refund.userId,
      amount: refund.amount,
      cashbackAmount: refund.cashbackAmount,
      time: refund.time,
      state: refund.state,
      customerLocalId: refund.customerLocalId,
      customerServerId: refund.customerServerId,
      weightProductRoundType: refund.weightProductRoundType,
      discountsRoundType: refund.discountsRoundType,
      isOfd: refund.isOfd,
    );
  }

  static RefundsCompanion toDrift(RefundEntity entity) {
    return RefundsCompanion(
      localId: entity.localId != null
          ? Value(entity.localId!)
          : const Value.absent(),
      serverId: Value(entity.serverId),
      saleId: Value(entity.saleId),
      saleReceiptNo: Value(entity.saleReceiptNo),
      salePosId: Value(entity.salePosId),
      userId: Value(entity.userId),
      amount: Value(entity.amount),
      cashbackAmount: Value(entity.cashbackAmount),
      time: Value(entity.time),
      state: Value(entity.state),
      customerLocalId: Value(entity.customerLocalId),
      customerServerId: Value(entity.customerServerId),
      weightProductRoundType: Value(entity.weightProductRoundType),
      discountsRoundType: Value(entity.discountsRoundType),
      isOfd: Value(entity.isOfd),
    );
  }

  static List<RefundEntity> fromDriftList(List<Refund> refunds) {
    return refunds.map(fromDrift).toList();
  }
}
