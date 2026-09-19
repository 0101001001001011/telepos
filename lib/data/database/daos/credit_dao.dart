import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/credit_tables.dart';
import 'package:telepos/domain/money/money_millis.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';

part 'credit_dao.g.dart';

/// Договоры рассрочки и их графики — задача 24.
///
/// # Здесь НЕТ метода «поставить `paid`»
///
/// Тот же довод, что у `CertificateDao`: разнесение платежа — это
/// **условная запись** ([allocate]), и ноль затронутых строк означает, что
/// условие не выполнилось. Метод «записать посчитанное снаружи» открыл бы
/// ровно то окно между чтением и записью, ради закрытия которого условная
/// запись и заведена: два кассира, разнося по одному и тому же графику,
/// прочитали бы один и тот же `paid` и оба записали бы свой.
///
/// Отличие от `AccountDao.claimCredit` — в том, **чем считает**. Там
/// колонка `REAL`, и сравнение приходится делать по прочитанному значению
/// (`WHERE value = :было`), потому что вычитание `double` внутри SQL
/// теряет копейки. Здесь колонка целая, и арифметика идёт **внутри
/// запроса** — точная по построению и не зависящая от того, что успело
/// поменяться между чтением и записью.
///
/// # Удаления нет
///
/// Ни у договора, ни у строки графика. Отзыв — это
/// `CreditContractStatus.cancelled`; строка подписанного графика не
/// удаляется никогда, потому что она и есть подписанное.
@DriftAccessor(tables: [CreditContracts, CreditScheduleEntries])
class CreditDao extends DatabaseAccessor<AppDatabase> with _$CreditDaoMixin {
  CreditDao(super.db);

  Future<CreditContractRow?> rowByNumber(String number) =>
      (select(creditContracts)
            ..where((c) => c.number.equals(number)))
          .getSingleOrNull();

  Future<CreditContractRow?> rowByReceipt({
    required int receiptNo,
    required int posId,
  }) =>
      (select(creditContracts)
            ..where((c) => c.receiptNo.equals(receiptNo) & c.posId.equals(posId)))
          .getSingleOrNull();

  Future<List<CreditContractRow>> rowsByAgent(
    int agentLocalId, {
    CreditContractStatus? status,
  }) {
    final q = select(creditContracts)
      ..where((c) => c.agentLocalId.equals(agentLocalId));
    if (status != null) {
      q.where((c) => c.status.equals(status.code));
    }
    q.orderBy([(c) => OrderingTerm.asc(c.signedAt), (c) => OrderingTerm.asc(c.id)]);
    return q.get();
  }

  Future<List<CreditScheduleEntryRow>> scheduleRows(int contractId) =>
      (select(creditScheduleEntries)
            ..where((e) => e.contractId.equals(contractId))
            ..orderBy([(e) => OrderingTerm.asc(e.seq)]))
          .get();

  /// Завести договор и его график **одним вызовом**.
  ///
  /// Договор без графика — это обязательство без сроков, то есть
  /// обязательство, по которому нельзя ни заплатить, ни просрочить.
  /// Раздельные методы дали бы путь, на котором такое состояние законно;
  /// здесь его нет.
  ///
  /// Транзакции внутри **нет намеренно**: единственный вызывающий —
  /// `SaleUseCaseImpl.perform`, и он уже внутри транзакции продажи. Своя
  /// вложенная транзакция здесь означала бы, что договор может уцелеть
  /// после отката чека.
  Future<int> insertContract({
    required String number,
    required int agentLocalId,
    required int receivableAccountId,
    required int receiptNo,
    required int posId,
    required Decimal principal,
    required Decimal feeTotal,
    required Decimal downPayment,
    required int termMonths,
    required InstallmentScheme scheme,
    required int signedAt,
    required List<InstallmentScheduleLine> schedule,
    int? signedByUserId,
  }) async {
    final contractId = await into(creditContracts).insert(
      CreditContractsCompanion.insert(
        number: number,
        agentLocalId: agentLocalId,
        receivableAccountId: receivableAccountId,
        receiptNo: receiptNo,
        posId: posId,
        principalMillis: MoneyMillis.of(principal),
        feeTotalMillis: MoneyMillis.of(feeTotal),
        downPaymentMillis: MoneyMillis.of(downPayment),
        termMonths: termMonths,
        scheme: scheme.code,
        status: CreditContractStatus.active.code,
        signedAt: signedAt,
        signedByUserId: Value(signedByUserId),
      ),
    );

    await batch((b) {
      for (final line in schedule) {
        b.insert(
          creditScheduleEntries,
          CreditScheduleEntriesCompanion.insert(
            contractId: contractId,
            seq: line.seq,
            dueDate: line.dueDate,
            principalDueMillis: MoneyMillis.of(line.principalDue),
            feeDueMillis: MoneyMillis.of(line.feeDue),
            totalDueMillis: MoneyMillis.of(line.totalDue),
          ),
        );
      }
    });

    return contractId;
  }

  /// Разнести [amount] на строку графика [entryId] — **условная запись**.
  ///
  /// Возвращает число затронутых строк. **Ноль обязан быть отвечен
  /// отказом**, а не молчанием: он означает, что по этой строке успели
  /// заплатить с другой кассы, и молчаливый пропуск оставил бы кассира с
  /// принятыми деньгами и непогашенным графиком.
  ///
  /// Условие `paid_millis + ?1 <= total_due_millis` — единственный заслон
  /// от переплаты **строки**: разнесение читает остаток заранее, но между
  /// чтением и записью помещается чужая транзакция.
  Future<int> allocate({required int entryId, required Decimal amount}) {
    final millis = MoneyMillis.of(amount);
    if (millis <= 0) return Future.value(0);
    return customUpdate(
      'UPDATE credit_schedule_entries '
      'SET paid_millis = paid_millis + ?1 '
      'WHERE id = ?2 AND paid_millis + ?1 <= total_due_millis',
      variables: [Variable.withInt(millis), Variable.withInt(entryId)],
      updates: {creditScheduleEntries},
    );
  }

  /// Закрыть договор — **условно и только живой**.
  ///
  /// `status = 'active'` в условии не украшение: два одновременных
  /// погашения, оба доведшие остаток до нуля, закрыли бы договор дважды и
  /// напечатали бы два «договор закрыт». Одна из двух записей вернёт ноль,
  /// и вызывающий узнает, что закрыл его не он.
  ///
  /// Имя `closeContract`, а не `close`: `DatabaseConnectionUser.close()`
  /// уже занято drift-ом, и одноимённый метод здесь не переопределение, а
  /// **подмена закрытия базы**. Компилятор это ловит, и хорошо; имя
  /// названо длиннее нарочно.
  Future<int> closeContract(int contractId) => customUpdate(
    "UPDATE credit_contracts SET status = 'closed' "
    "WHERE id = ?1 AND status = 'active'",
    variables: [Variable.withInt(contractId)],
    updates: {creditContracts},
  );

  // # Метода `cancelContract` здесь НЕТ, и это решение
  //
  // Он был написан первой редакцией — по симметрии с
  // `CertificateDao.cancel` — и снят тем же днём: вызывающих у него ноль,
  // экрана отзыва договора в кассе не существует, и появиться он может
  // только вместе с расторжением, которое лежит **за границей кассы** (см.
  // `CreditContract`, «Граница с банковским модулем»).
  //
  // Метод в интерфейсе без вызывающего — это «мёртвый код, выглядящий
  // живым»: следующий читатель решит, что отзыв работает, и построит на
  // нём экран, у которого не будет ни движения по счёту, ни решения о
  // внесённых взносах. `CreditContractStatus.cancelled` при этом
  // **остаётся** — состояние читается (`toDomain` отдаёт им всякий
  // неразобранный статус), просто ставить его пока некому.

  /// Строка базы → домен.
  ///
  /// Неразобранная схема — это **не** `equalInstalments` по умолчанию:
  /// договор, приехавший от кассы более новой сборки, обязан читаться как
  /// «не знаю», а не как выдуманная раскладка. `null` заставляет
  /// вызывающего ответить; подставленное значение уехало бы в печать
  /// договора как правда.
  static CreditContract? toDomain(CreditContractRow row) {
    final scheme = InstallmentScheme.byCode(row.scheme);
    if (scheme == null) return null;
    return CreditContract(
      id: row.id,
      number: row.number,
      agentLocalId: row.agentLocalId,
      receivableAccountId: row.receivableAccountId,
      receiptNo: row.receiptNo,
      posId: row.posId,
      principal: MoneyMillis.amount(row.principalMillis),
      feeTotal: MoneyMillis.amount(row.feeTotalMillis),
      downPayment: MoneyMillis.amount(row.downPaymentMillis),
      termMonths: row.termMonths,
      scheme: scheme,
      // Неизвестное состояние читается **отозванным**, а не живым: тот же
      // довод, что у `CertificateDao.toDomain`. Ошибиться в сторону
      // «платить нельзя» дешевле, чем в сторону «платите ещё».
      status:
          CreditContractStatus.byCode(row.status) ??
          CreditContractStatus.cancelled,
      signedAt: row.signedAt,
      signedByUserId: row.signedByUserId,
    );
  }

  static CreditScheduleEntry entryToDomain(CreditScheduleEntryRow row) =>
      CreditScheduleEntry(
        id: row.id,
        contractId: row.contractId,
        seq: row.seq,
        dueDate: row.dueDate,
        principalDue: MoneyMillis.amount(row.principalDueMillis),
        feeDue: MoneyMillis.amount(row.feeDueMillis),
        paid: MoneyMillis.amount(row.paidMillis),
      );
}
