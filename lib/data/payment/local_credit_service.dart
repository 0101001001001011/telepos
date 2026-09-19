import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/credit_dao.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Рассрочка на кассе — реализация [CreditService] поверх `CreditDao`.
class LocalCreditService implements CreditService {
  LocalCreditService({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  /// Состояние строки оплаты и кассовой операции «отправлено в очередь
  /// синхронизации» — то же число, что пишет продажа и возврат.
  static const int _statePendingSync = 1;

  @override
  Future<CreditContractView?> byNumber(String number) async {
    final row = await _db.creditDao.rowByNumber(number);
    if (row == null) return null;
    return _view(row);
  }

  @override
  Future<CreditContractView?> byReceipt({
    required int receiptNo,
    required int posId,
  }) async {
    final row = await _db.creditDao.rowByReceipt(
      receiptNo: receiptNo,
      posId: posId,
    );
    if (row == null) return null;
    return _view(row);
  }

  @override
  Future<List<CreditContractView>> activeFor(int agentLocalId) async {
    final rows = await _db.creditDao.rowsByAgent(
      agentLocalId,
      status: CreditContractStatus.active,
    );
    final out = <CreditContractView>[];
    for (final row in rows) {
      final view = await _view(row);
      if (view != null) out.add(view);
    }
    return out;
  }

  @override
  Future<bool> hasOverdue(int agentLocalId, {DateTime? asOf}) async {
    final at =
        (asOf ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    for (final view in await activeFor(agentLocalId)) {
      if (view.standingAt(at).isOverdue) return true;
    }
    return false;
  }

  @override
  Future<CreditRepayment> repay({
    required String contractNumber,
    required Decimal amount,
    required int userId,
    required int receivingAccountId,
    DateTime? at,
  }) async {
    if (amount <= Decimal.zero) {
      throw WireRefusal(
        creditRepaymentInvalidCode,
        'платёж по договору $contractNumber не положителен: $amount',
      );
    }

    final row = await _db.creditDao.rowByNumber(contractNumber);
    if (row == null) {
      throw WireRefusal(
        creditContractUnknownCode,
        'договора $contractNumber нет в базе кассы',
      );
    }
    final contract = CreditDao.toDomain(row);
    if (contract == null || !contract.isLive) {
      throw WireRefusal(
        creditContractNotActiveCode,
        'договор $contractNumber не живой '
        '(${contract?.status.code ?? row.status}) — платить по нему нечего',
      );
    }

    final now = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    var entries = (await _db.creditDao.scheduleRows(contract.id))
        .map(CreditDao.entryToDomain)
        .toList();
    final before = CreditStanding.of(entries, now);

    // **Переплата — отказ, а не аванс.** Разбор целиком — в докстринге
    // [creditOverpaymentCode]. Остаток называется числом: досрочное
    // погашение целиком это `amount == outstanding`, и кассиру нужно
    // ровно это число, а не «слишком много».
    if (amount > before.outstanding) {
      throw WireRefusal(
        creditOverpaymentCode,
        'по договору $contractNumber осталось ${before.outstanding}, '
        'а внести хотят $amount',
      );
    }

    await _db.transaction(() async {
      // ── разнесение FIFO по `seq` ──────────────────────────────────────
      //
      // Правило одно, и выбрано оно не за красоту: **любое другое
      // требует выбора человеком**, а кассир его сделать не может —
      // договора у него перед глазами нет, есть купюры и номер. «Гасить
      // самый старый долг первым» — единственное правило, которое кассир
      // не обязан знать, чтобы оно выполнилось верно.
      //
      // Условная запись здесь — настоящий заслон, а не вежливость:
      // остаток строки прочитан выше, и в окно между чтением и записью
      // помещается второй кассир с деньгами того же покупателя.
      var rest = amount;
      for (final entry in entries) {
        if (rest <= Decimal.zero) break;
        final due = entry.outstanding;
        if (due <= Decimal.zero) continue;
        final take = due < rest ? due : rest;
        final touched = await _db.creditDao.allocate(
          entryId: entry.id,
          amount: take,
        );
        if (touched == 0) {
          _logger.warning(
            'Credit: schedule entry ${entry.contractId}/${entry.seq} no '
            'longer takes $take — repayment of $contractNumber rolled back',
          );
          throw WireRefusal(
            creditAllocationRaceCode,
            'по договору $contractNumber успели заплатить с другой кассы '
            '— примите платёж заново',
          );
        }
        rest -= take;
      }

      if (rest > Decimal.zero) {
        // Недостижимо, пока потолок выше стоит: `amount <= outstanding`, а
        // `outstanding` и есть сумма всех `due`. Ветка оставлена потому,
        // что молчаливо принятые и никуда не разнесённые деньги — это
        // ровно тот класс, ради которого заведён отказ выше, и «не может
        // случиться» здесь стоило бы принятых денег без записи.
        _logger.warning(
          'Credit: $rest of $amount unallocated on $contractNumber',
        );
        throw WireRefusal(
          creditAllocationRaceCode,
          'разнести удалось не всё: $rest из $amount остались без строки '
          'графика',
        );
      }

      // ── деньги ────────────────────────────────────────────────────────
      //
      // Счёт задолженности — **снимок договора**, а не живое
      // `Agents.mainAccountId`: счёт могли сменить, а платят по тому
      // договору, который подписан.
      //
      // `post`, а не `updateBalance(посчитано снаружи)`: знак движения
      // выбирает `AccountPosting` по роду счёта, и у `agentMain` он не
      // перевёрнут — долг это минус, поступление это плюс, остаток растёт
      // к нулю.
      await _db.accountDao.post(contract.receivableAccountId, amount);

      // **Второй счёт — и без него погашение печатает деньги.** Долг
      // покупателя уменьшился на `amount`; эти деньги обязаны где-то
      // лежать, иначе касса списала долг ничем. Проверяется числом:
      // `credit_repayment_test`, случай «оба счёта двинулись».
      //
      // Ровно этой второй половины нет у сегодняшнего погашения долга
      // контрагентом: `CustomerPaymentUseCaseImpl` двигает счёт
      // покупателя, а счёт кассы правит **экранный контроллер**
      // (`CustomerPaymentController._creditPosAccount`) — в другом ярусе
      // и вне транзакции. Авария между двумя записями теряет деньги, и
      // покраснеть этому негде: у пути нет ни одной пробы на оба счёта
      // сразу.
      await _db.accountDao.post(receivingAccountId, amount);

      // Документ на приход в ящик — тем же механизмом, каким его пишет
      // приём оплаты от контрагента (`CustomerPaymentUseCaseImpl`).
      // Второй механизм рядом означал бы, что инкассация видит одни
      // приходы и не видит других.
      await _db
          .into(_db.cashOperations)
          .insert(
            CashOperationsCompanion.insert(
              amount: amount,
              type: 0,
              accountId: Value(receivingAccountId),
              note: Value('Погашение рассрочки ${contract.number}'),
              docTime: Value(now),
              state: const Value(_statePendingSync),
            ),
          );

      // **Строка `Payments`, а не второй регистр** — шаг 6 задачи 24.
      //
      // Вид `agent_settlement` (ид 9) заведён задачей 14 ровно под это и
      // до сих пор **не имел ни одного писателя во всём `lib/`**: его
      // докстринг говорит «читает погашение долга контрагентом», а
      // погашение писало только остаток счёта. Здесь у него появляется
      // первый.
      //
      // Вид `offset` и `notAPayment`: в выручку смены строка не идёт и в
      // фискальный документ не едет вовсе — и то, и другое верно, потому
      // что **выручка признана в момент продажи**, а не сейчас. Признать
      // её второй раз значило бы удвоить её ровно на сумму каждой
      // рассрочки.
      //
      // Ни `receiptNo`, ни `refundLocalId` у строки нет: погашение — не
      // чек и не возврат. Отчёт смены её и не увидит — он суммирует по
      // счетам кассы и банка (`CustomBankPaymentsSumUseCaseImpl`), а эта
      // лежит на счёте покупателя.
      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: userId,
              payeeAccountId: contract.receivableAccountId,
              amount: amount,
              time: now,
              state: const Value(_statePendingSync),
              customerLocalId: Value(contract.agentLocalId),
              kindId: Value(SystemPaymentKindIds.agentSettlement),
              // По нему и только по нему видно, за какой договор
              // заплачено. Строка погашения без номера договора
              // неотличима от любого другого расчёта с контрагентом.
              reference: Value(contract.number),
            ),
          );

      entries = (await _db.creditDao.scheduleRows(contract.id))
          .map(CreditDao.entryToDomain)
          .toList();
      if (CreditStanding.of(entries, now).isSettled) {
        // Условно: два одновременных платежа, оба доведшие остаток до
        // нуля, закрыли бы договор дважды. Ноль затронутых строк здесь —
        // не беда, а сведение: закрыл его не я.
        final closed = await _db.creditDao.closeContract(contract.id);
        _logger.info(
          'Credit: contract $contractNumber settled '
          '(closed by this repayment: ${closed == 1})',
        );
      }
    });

    final after = CreditStanding.of(
      (await _db.creditDao.scheduleRows(contract.id))
          .map(CreditDao.entryToDomain)
          .toList(),
      now,
    );

    _logger.info(
      'Credit: repaid $amount on $contractNumber, left ${after.outstanding}',
    );

    return CreditRepayment(
      contractNumber: contractNumber,
      allocated: amount,
      standing: after,
      closed: after.isSettled,
    );
  }

  Future<CreditContractView?> _view(CreditContractRow row) async {
    final contract = CreditDao.toDomain(row);
    if (contract == null) {
      // Схема графика не разобрана — договор приехал от кассы более новой
      // сборки. Отдать его с подставленной схемой значило бы напечатать
      // чужую раскладку как подписанную.
      _logger.warning(
        'Credit: contract ${row.number} has unknown scheme "${row.scheme}"',
      );
      return null;
    }
    final schedule = (await _db.creditDao.scheduleRows(row.id))
        .map(CreditDao.entryToDomain)
        .toList();
    return CreditContractView(contract: contract, schedule: schedule);
  }
}
