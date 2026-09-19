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

  /// # Нумерация строк — здесь, а не у вызывающего
  ///
  /// Уникальный ключ `Payments` — `{receiptNo, posId, seq}` (задача 14), и
  /// защищает он **только пока `seq` считается от нуля на каждой
  /// попытке**. Пакет, пришедший сюда, и есть одна попытка: номера ему
  /// проставляются по порядку списка, от нуля, внутри каждого чека и
  /// каждого возврата.
  ///
  /// Оставить это вызывающему было бы правилом, живущим в чужой
  /// внимательности: `PaymentEntity.seq` имеет умолчание `0`, и пакет из
  /// двух строк одного чека, собранный без единой мысли о номерах,
  /// столкнулся бы сырым `SqliteException(2067)`. Ровно это и покраснело
  /// в `repository_live_integration_test` в тот же час, когда ключ
  /// сменился.
  ///
  /// **Названный предел:** два *разных* вызова по одному чеку столкнутся
  /// — второй начнёт снова с нуля. Это верно: два вызова — две попытки, а
  /// две попытки оплатить один чек и есть то, от чего ключ поставлен.
  /// Дописывать строки к уже оплаченному чеку этот метод не умеет и не
  /// должен.
  @override
  Future<void> insertPayments(List<PaymentEntity> payments) async {
    if (payments.isEmpty) return;

    final nextSeq = <String, int>{};
    await _db.batch((batch) {
      for (final payment in payments) {
        final group = payment.receiptNo != null
            ? 's:${payment.receiptNo}:${payment.posId}'
            : 'r:${payment.refundLocalId}';
        final seq = nextSeq[group] ?? 0;
        nextSeq[group] = seq + 1;
        batch.insert(
          _db.payments,
          PaymentMapper.toDrift(payment.copyWith(seq: seq)),
        );
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
