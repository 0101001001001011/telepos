import 'package:decimal/decimal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/payment_mapper.dart';
import 'package:telepos/domain/entities/payment/payment_entity.dart';
import 'package:telepos/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<PaymentEntity>> findBySale(int receiptNo, int posId) async {
    final payments = await _db.paymentDao.findBySale(receiptNo, posId);
    return PaymentMapper.fromDriftList(payments);
  }

  @override
  Future<List<PaymentEntity>> findByRefund(int refundLocalId) async {
    final payments = await _db.paymentDao.findByRefund(refundLocalId);
    return PaymentMapper.fromDriftList(payments);
  }

  @override
  Future<void> insertPayments(List<PaymentEntity> payments) async {
    if (payments.isEmpty) return;

    await _db.batch((batch) {
      for (final payment in payments) {
        batch.insert(_db.payments, PaymentMapper.toDrift(payment));
      }
    });
  }

  @override
  Future<Decimal?> sumByUserAndAccountBetween(
    int userId,
    int payeeAccountId,
    int fromTime,
    int toTime,
  ) async {
    final result = await _db.paymentDao.sumByUserAndPayeeAccountIdBetween(
      userId,
      payeeAccountId,
      fromTime,
      toTime,
    );
    if (result == null) return null;
    return Decimal.parse(result.toStringAsFixed(3));
  }

  @override
  Future<void> setState(int receiptNo, int posId, int state) async {
    final payments = await _db.paymentDao.findBySale(receiptNo, posId);
    if (payments.isNotEmpty) {
      await _db.paymentDao.setState(payments.map((p) => p.id).toList(), state);
    }
  }
}
