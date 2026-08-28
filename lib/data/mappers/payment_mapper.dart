import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/payment/payment_entity.dart';

class PaymentMapper {
  PaymentMapper._();

  static PaymentEntity fromDrift(Payment payment) {
    return PaymentEntity(
      id: payment.id,
      userId: payment.userId,
      receiptNo: payment.receiptNo,
      posId: payment.posId,
      refundLocalId: payment.refundLocalId,
      customerLocalId: payment.customerLocalId,
      payeeAccountId: payment.payeeAccountId,
      amount: payment.amount,
      time: payment.time,
      state: payment.state,
    );
  }

  static PaymentsCompanion toDrift(PaymentEntity entity) {
    return PaymentsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      userId: Value(entity.userId),
      receiptNo: Value(entity.receiptNo),
      posId: Value(entity.posId),
      refundLocalId: Value(entity.refundLocalId),
      customerLocalId: Value(entity.customerLocalId),
      payeeAccountId: Value(entity.payeeAccountId),
      amount: Value(entity.amount),
      time: Value(entity.time),
      state: Value(entity.state),
    );
  }

  static List<PaymentEntity> fromDriftList(List<Payment> payments) {
    return payments.map(fromDrift).toList();
  }
}
