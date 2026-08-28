import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/payment/payment_entity.dart';

abstract class PaymentRepository {
  Future<List<PaymentEntity>> findBySale(int receiptNo, int posId);

  Future<List<PaymentEntity>> findByRefund(int refundLocalId);

  Future<void> insertPayments(List<PaymentEntity> payments);

  Future<Decimal?> sumByUserAndAccountBetween(
    int userId,
    int payeeAccountId,
    int fromTime,
    int toTime,
  );

  Future<void> setState(int receiptNo, int posId, int state);
}
