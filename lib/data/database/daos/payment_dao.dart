import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';
import 'package:telepos/data/database/tables/payment_tables.dart';
import 'package:telepos/domain/account/account_type.dart';

part 'payment_dao.g.dart';

@DriftAccessor(tables: [Payments])
class PaymentDao extends DatabaseAccessor<AppDatabase> with _$PaymentDaoMixin {
  PaymentDao(super.db);

  Future<List<Payment>> findBySale(int receiptNo, int posId) => (select(
    payments,
  )..where((p) => p.receiptNo.equals(receiptNo) & p.posId.equals(posId))).get();

  Future<List<Payment>> findByRefund(int refundLocalId) => (select(
    payments,
  )..where((p) => p.refundLocalId.equals(refundLocalId))).get();

  Future<double?> sumByUserAndPayeeAccountIdBetween(
    int userId,
    int payeeAccountId,
    int startDate,
    int endDate,
  ) {
    final expr = payments.amount.sum();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.userId.equals(userId) &
                payments.payeeAccountId.equals(payeeAccountId) &
                payments.time.isBetweenValues(startDate, endDate) &
                payments.receiptNo.isNotNull() &
                payments.posId.isNotNull(),
          ))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  /// Суммы смены **по счёту И по виду оплаты** — второе измерение,
  /// заведённое задачей 14.
  ///
  /// # Почему одного счёта стало мало
  ///
  /// Задача 14 сняла отказ `payment_account_conflict`, а с ним — запрет
  /// на две строки одного чека, лежащие на одном счёте. Запрет был не
  /// правилом учёта, а следствием старого уникального ключа
  /// `{receiptNo, posId, payeeAccountId}`. **Цена снятия названа в том же
  /// шаге и уплачена здесь:** отчёт смены суммировал по счёту, и как
  /// только на один счёт легли два вида, он слил бы их в одну строку —
  /// кассир увидел бы «Счёт кассы: 1000» там, где было 600 наличными и
  /// 400 картой на тот же счёт.
  ///
  /// Строки без вида (до v41 и со снесённым счётом) приходят с
  /// `kind_id IS NULL` — **своей строкой**, а не подмешанными к
  /// наличным: «не знаю» в отчёте видно, а выдуманное «наличные» — нет.
  Future<List<QueryRow>> sumsByAccountAndKindBetween(
    int userId,
    List<int> accountIds,
    int startDate,
    int endDate,
  ) {
    if (accountIds.isEmpty) return Future.value(const <QueryRow>[]);
    final ids = accountIds.join(', ');
    return customSelect(
      'SELECT payee_account_id, kind_id, SUM(amount) AS total '
      'FROM payments '
      'WHERE user_id = ? AND payee_account_id IN ($ids) '
      'AND time BETWEEN ? AND ? '
      'AND receipt_no IS NOT NULL AND pos_id IS NOT NULL '
      'GROUP BY payee_account_id, kind_id '
      'ORDER BY payee_account_id, kind_id',
      variables: [
        Variable.withInt(userId),
        Variable.withInt(startDate),
        Variable.withInt(endDate),
      ],
      readsFrom: {payments},
    ).get();
  }

  /// Сумма строк оплаты **сертификатом** за окно смены — строка «погашено
  /// сертификатов» X- и Z-отчёта.
  ///
  /// # Почему отбор идёт по РОДУ СЧЁТА, а не по `kind_id`
  ///
  /// Правило дерева, объявленное `SaleUseCaseImpl._isCertificateKind`:
  /// сертификатность вида спрашивается у справочника
  /// (`payee_account_type == AccountType.certificateLiability`), а не
  /// сравнением с `SystemPaymentKindIds.certificate`. Оператор вправе
  /// завести **свой** вид («подарочные карты сети», «сертификаты
  /// партнёра»), и он гасится тем же кодом. Сравнение с системным числом
  /// напечатало бы в отчёте ноль на кассе, где сертификаты работают.
  ///
  /// Здесь спрашивается род **счёта-получателя строки**, а не вида: счёт
  /// записан в самой строке и не меняется задним числом, а
  /// `payment_kinds.payee_account_type` оператор вправе переназначить —
  /// и тогда отчёт за прошлую смену пересчитался бы сам.
  ///
  /// # Почему не остаток бумажек и не `balance_millis`
  ///
  /// Остаток — **снимок на сейчас**, а не движение за окно. Бумажка,
  /// выпущенная и погашенная в одну смену, по остатку неотличима от
  /// невыпущенной; бумажка, погашенная вчера, по остатку неотличима от
  /// погашенной сегодня. Разница остатков «на начало — на конец» тоже не
  /// ответ: между двумя снимками лежат и выпуски. Движение записано
  /// строками `Payments` — одно на гашение, с номером бумажки в
  /// `reference`, — и только они отвечают на вопрос «за эту смену».
  ///
  /// # Возвраты сюда НЕ попадают, и это не пропуск
  ///
  /// `receipt_no IS NOT NULL` отсекает строки сторно (у них заполнен
  /// `refund_local_id`). Довод учётный, а не технический: возврат чека,
  /// оплаченного бумажкой, **не возвращает** обязательство строкой оплаты —
  /// он выпускает НОВУЮ бумажку (`RefundRoute.certificate`, решение
  /// заказчика 2026-09-16) и возвращает счёт `releaseCredit`. То есть в
  /// отчёте он виден строкой «выпущено», и засчитать его ещё и здесь —
  /// значит посчитать одно движение дважды.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Не доказывает, что на эту сумму уменьшилась выручка смены: гашение —
  /// `FiscalTreatment.offsetNotFiscal`, оплатой оно не едет ни оператору,
  /// ни в ящик, и в `saleAmount` цена товара входит целиком. Строка
  /// отвечает на вопрос «сколько товара отдано без живых денег», и стоит
  /// в отчёте отдельно именно поэтому.
  ///
  /// Не доказывает и того, что столько денег кассе не досталось: часть
  /// чека могла быть доплачена наличными, и она в ящике.
  Future<Decimal> sumCertificateRedemptionsBetween({
    required int userId,
    required int startDate,
    required int endDate,
  }) async {
    final rows = await customSelect(
      'SELECT p.amount AS amount FROM payments p '
      'JOIN accounts a ON a.id = p.payee_account_id '
      'WHERE p.user_id = ?1 AND a.type = ?2 '
      'AND p.time BETWEEN ?3 AND ?4 '
      'AND p.receipt_no IS NOT NULL AND p.pos_id IS NOT NULL',
      variables: [
        Variable.withInt(userId),
        Variable.withInt(AccountType.certificateLiability),
        Variable.withInt(startDate),
        Variable.withInt(endDate),
      ],
      readsFrom: {payments, attachedDatabase.accounts},
    ).get();
    // `SUM` в SQL сложил бы `REAL`, то есть деньги в `double` (I159).
    // Строки гашения за смену считаются десятками, и складываются они
    // `Decimal`-ом — тем же преобразованием, каким их читает drift.
    const converter = DecimalConverter();
    var total = Decimal.zero;
    for (final row in rows) {
      total += converter.fromSql(row.read<double>('amount'));
    }
    return total;
  }

  Future<List<QueryRow>> findDebtPaymentsWithState(int state) => customSelect(
    'SELECT p.id, p.user_id, ac.id AS agent_account_id, p.payee_account_id, p.amount, p.time '
    'FROM payments p '
    'JOIN agents ag ON ag.local_id = p.customer_local_id '
    'JOIN accounts ac ON ac.agent_id = ag.server_id AND ac.type = 3 '
    'WHERE ac.id IS NOT NULL AND p.state = ?',
    variables: [Variable.withInt(state)],
    readsFrom: {payments},
  ).get();

  Future<List<QueryRow>> findUnSyncedDebtPayments() => customSelect(
    'SELECT p.id, p.user_id, ac.id AS agent_account_id, p.payee_account_id, p.amount, p.time '
    'FROM payments p '
    'JOIN agents ag ON ag.local_id = p.customer_local_id '
    'JOIN accounts ac ON ac.agent_id = ag.server_id AND ac.type = 3 '
    'WHERE ac.id IS NOT NULL AND p.state <> 4',
    readsFrom: {payments},
  ).get();

  Future<int> countUnsynced() {
    final expr = payments.id.count();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.state.equals(1) &
                payments.receiptNo.isNull() &
                payments.refundLocalId.isNull(),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<double?> sumAmountByCustomerLocalId(int customerLocalId) {
    final expr = payments.amount.sum();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(payments.customerLocalId.equals(customerLocalId)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<int> setState(List<int> ids, int state) =>
      (update(payments)..where((p) => p.id.isIn(ids))).write(
        PaymentsCompanion(state: Value(state)),
      );

  Future<int?> findIdByRefund(int refundLocalId, int payeeAccountId) {
    final expr = payments.id;
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.payeeAccountId.equals(payeeAccountId) &
                payments.refundLocalId.equals(refundLocalId),
          ))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<int> countBySale(int receiptNo, int posId) {
    final expr = payments.id.count();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.receiptNo.equals(receiptNo) & payments.posId.equals(posId),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> deleteBySale(int receiptNo, int posId) => (delete(
    payments,
  )..where((p) => p.receiptNo.equals(receiptNo) & p.posId.equals(posId))).go();
}
