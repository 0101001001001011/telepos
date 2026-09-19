/// Погашение рассрочки — **как платёж находит свой договор и что при
/// переплате**.
///
/// # Почему сумма остатка — слабая проверка
///
/// «Осталось 500» верно и у кассы, которая разнесла 400 на последнюю
/// строку графика вместо первых двух. Разница видна только при просрочке:
/// покупатель, заплативший вперёд, оказался бы просрочившим первый месяц.
/// Поэтому каждый случай утверждает **сами строки** — `paid` по каждому
/// `seq`, — а не только их сумму.
///
/// # И почему счетов проверяется два
///
/// Погашение двигает долг покупателя и приход в кассу. Проверь одно —
/// и проба останется зелёной у кассы, которая уменьшила долг **ничем**:
/// деньги кассир взял, а положить их забыли. Ровно этой второй половины
/// нет у сегодняшнего погашения долга контрагентом
/// (`CustomerPaymentUseCaseImpl` двигает счёт покупателя, а счёт кассы
/// правит экранный контроллер, вне транзакции).
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/credit_dao.dart';
import 'package:telepos/data/payment/local_credit_service.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

void main() {
  late AppDatabase db;
  late CreditService credit;

  const posAccountId = 11;
  const agentMainAccountId = 14;
  const customerId = 5;
  const userId = 4;

  Decimal d(String v) => Decimal.parse(v);

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  Future<void> seedAccount(int id, int type, {String value = '0'}) async {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: Value(id),
            type: type,
            name: Value('Счёт $id'),
            value: Value(d(value)),
            visibleToPos: const Value(true),
          ),
        );
  }

  /// Договор на 900 тремя платежами по 300, покупатель должен 900.
  Future<String> openContract({String principal = '900', int term = 3}) async {
    await db.creditDao.insertContract(
      number: 'РС-1-1',
      agentLocalId: customerId,
      receivableAccountId: agentMainAccountId,
      receiptNo: 1,
      posId: 1,
      principal: d(principal),
      feeTotal: Decimal.zero,
      downPayment: Decimal.zero,
      termMonths: term,
      scheme: InstallmentScheme.equalInstalments,
      signedAt: 1000,
      schedule: InstallmentScheduler.build(
        principal: d(principal),
        feeTotal: Decimal.zero,
        termMonths: term,
        firstDueDate: DateTime(2026, 10, 1),
        scheme: InstallmentScheme.equalInstalments,
      ),
      signedByUserId: userId,
    );
    return 'РС-1-1';
  }

  Future<List<Decimal>> paidBySeq() async {
    final row = (await db.creditDao.rowByNumber('РС-1-1'))!;
    final rows = await db.creditDao.scheduleRows(row.id);
    return [for (final e in rows) CreditDao.entryToDomain(e).paid];
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedAccount(posAccountId, AccountType.pos);
    await seedAccount(agentMainAccountId, AccountType.agentMain, value: '-900');
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(customerId),
            name: Value('Айгуль'),
            phone: Value(77015550000),
            mainAccountId: Value(agentMainAccountId),
          ),
        );
    credit = LocalCreditService(db: db, logger: Talker());
  });

  tearDown(() async => db.close());

  group('разнесение FIFO по seq', () {
    test('400 закрывают первый месяц целиком и второй частично', () async {
      final number = await openContract();

      final result = await credit.repay(
        contractNumber: number,
        amount: d('400'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      // **Сами строки, а не их сумма.** Разнеси касса те же 400 на
      // последний месяц — сумма осталась бы той же, а покупатель стал бы
      // просрочившим первый.
      expect(await paidBySeq(), [d('300'), d('100'), Decimal.zero]);
      expect(result.allocated, d('400'));
      expect(result.standing.outstanding, d('500'));
      expect(result.closed, isFalse);
    });

    test('оба счёта двинулись: долг уменьшился, деньги легли в ящик',
        () async {
      final number = await openContract();

      await credit.repay(
        contractNumber: number,
        amount: d('400'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      expect(await balanceOf(agentMainAccountId), d('-500'));
      expect(
        await balanceOf(posAccountId),
        d('400'),
        reason: 'уменьшить долг, не положив денег, — значит списать его ничем',
      );
    });

    test('строка Payments вида agent_settlement с номером договора',
        () async {
      final number = await openContract();

      await credit.repay(
        contractNumber: number,
        amount: d('400'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      final rows = await db.select(db.payments).get();
      expect(rows.length, 1);
      final row = rows.single;
      expect(row.kindId, SystemPaymentKindIds.agentSettlement);
      expect(row.amount, d('400'));
      expect(row.payeeAccountId, agentMainAccountId);
      expect(
        row.reference,
        number,
        reason: 'без номера договора строка неотличима от прочих расчётов',
      );
      expect(row.customerLocalId, customerId);
      // Не чек и не возврат: погашение — своё событие.
      expect(row.receiptNo, isNull);
      expect(row.refundLocalId, isNull);

      // Приход в ящик получил документ — тем же механизмом, каким его
      // пишет приём оплаты от контрагента.
      final cash = await db.select(db.cashOperations).get();
      expect(cash.length, 1);
      expect(cash.single.amount, d('400'));
      expect(cash.single.accountId, posAccountId);
    });

    test('два платежа подряд ложатся дальше по графику, а не поверх',
        () async {
      final number = await openContract();

      await credit.repay(
        contractNumber: number,
        amount: d('300'),
        userId: userId,
        receivingAccountId: posAccountId,
      );
      await credit.repay(
        contractNumber: number,
        amount: d('350'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      expect(await paidBySeq(), [d('300'), d('300'), d('50')]);
      expect(await balanceOf(agentMainAccountId), d('-250'));
      expect((await db.select(db.payments).get()).length, 2);
    });
  });

  group('недоплата — нормальный ход договора', () {
    test('месячный взнос принимается и договор остаётся живым', () async {
      final number = await openContract();

      final result = await credit.repay(
        contractNumber: number,
        amount: d('300'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      expect(result.closed, isFalse);
      expect(result.standing.outstanding, d('600'));
      final row = (await db.creditDao.rowByNumber(number))!;
      expect(CreditDao.toDomain(row)!.status, CreditContractStatus.active);
    });

    test('одна тысячная тоже принимается — потолка снизу нет', () async {
      final number = await openContract();
      await credit.repay(
        contractNumber: number,
        amount: d('0.001'),
        userId: userId,
        receivingAccountId: posAccountId,
      );
      expect(await paidBySeq(), [d('0.001'), Decimal.zero, Decimal.zero]);
      expect(await balanceOf(agentMainAccountId), d('-899.999'));
    });
  });

  group('переплата — отказ, и НИЧЕГО не двинулось', () {
    test('на одну тысячную больше остатка — credit_overpayment', () async {
      final number = await openContract();

      await expectLater(
        credit.repay(
          contractNumber: number,
          amount: d('900.001'),
          userId: userId,
          receivingAccountId: posAccountId,
        ),
        throwsA(
          isA<WireRefusal>()
              .having((e) => e.code, 'code', creditOverpaymentCode)
              // Остаток назван числом: досрочное погашение целиком — это
              // ровно `amount == outstanding`, и кассиру нужно это число,
              // а не «слишком много».
              .having((e) => e.message, 'message', contains('900')),
        ),
      );

      // Контрольные маркеры: отказ пришёл **до единой записи**.
      expect(await paidBySeq(), [Decimal.zero, Decimal.zero, Decimal.zero]);
      expect(await balanceOf(agentMainAccountId), d('-900'));
      expect(await balanceOf(posAccountId), Decimal.zero);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await db.select(db.cashOperations).get(), isEmpty);
    });

    test('переплата считается от ОСТАТКА, а не от тела договора', () async {
      // Контрольный маркер к предыдущей пробе: после взноса 300 потолок
      // становится 600, и 700 обязаны отказать, а 600 — пройти. Без этого
      // случая «отказ на 900.001» был бы зелен и у кассы, которая
      // сравнивает с телом договора навсегда.
      final number = await openContract();
      await credit.repay(
        contractNumber: number,
        amount: d('300'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      await expectLater(
        credit.repay(
          contractNumber: number,
          amount: d('700'),
          userId: userId,
          receivingAccountId: posAccountId,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            creditOverpaymentCode,
          ),
        ),
      );

      final result = await credit.repay(
        contractNumber: number,
        amount: d('600'),
        userId: userId,
        receivingAccountId: posAccountId,
      );
      expect(result.closed, isTrue);
    });
  });

  group('досрочное погашение целиком', () {
    test('ровно остаток — договор закрывается и счёт выходит в ноль',
        () async {
      final number = await openContract();

      final result = await credit.repay(
        contractNumber: number,
        amount: d('900'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      expect(result.closed, isTrue);
      expect(result.standing.outstanding, Decimal.zero);
      expect(await paidBySeq(), [d('300'), d('300'), d('300')]);
      expect(await balanceOf(agentMainAccountId), Decimal.zero);
      expect(await balanceOf(posAccountId), d('900'));

      final row = (await db.creditDao.rowByNumber(number))!;
      expect(CreditDao.toDomain(row)!.status, CreditContractStatus.closed);
    });

    test('по закрытому договору платить нельзя — credit_contract_not_active',
        () async {
      final number = await openContract();
      await credit.repay(
        contractNumber: number,
        amount: d('900'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      await expectLater(
        credit.repay(
          contractNumber: number,
          amount: d('1'),
          userId: userId,
          receivingAccountId: posAccountId,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            creditContractNotActiveCode,
          ),
        ),
      );
      expect(await balanceOf(posAccountId), d('900'));
    });
  });

  group('как платёж находит свой договор', () {
    test('по номеру, и незнакомый номер — отказ, а не догадка', () async {
      await openContract();
      await expectLater(
        credit.repay(
          contractNumber: 'РС-1-999',
          amount: d('100'),
          userId: userId,
          receivingAccountId: posAccountId,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            creditContractUnknownCode,
          ),
        ),
      );
      expect(await balanceOf(agentMainAccountId), d('-900'));
    });

    test('живые договоры покупателя перечислимы — по ним и выбирают',
        () async {
      await openContract();
      final live = await credit.activeFor(customerId);
      expect(live.length, 1);
      expect(live.single.contract.number, 'РС-1-1');
      expect(
        live.single.standingAt(2000).outstanding,
        d('900'),
        reason: 'остаток считается из строк, а не хранится',
      );
    });

    test('платёж не положителен — credit_repayment_invalid', () async {
      final number = await openContract();
      for (final bad in ['0', '-1']) {
        await expectLater(
          credit.repay(
            contractNumber: number,
            amount: d(bad),
            userId: userId,
            receivingAccountId: posAccountId,
          ),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              creditRepaymentInvalidCode,
            ),
          ),
        );
      }
      expect(await balanceOf(posAccountId), Decimal.zero);
    });
  });

  group('просрочка вычисляется, а не хранится', () {
    test('срок прошёл — договор просрочен, и это видно без единой записи',
        () async {
      await openContract();
      final row = (await db.creditDao.rowByNumber('РС-1-1'))!;
      final entries = (await db.creditDao.scheduleRows(row.id))
          .map(CreditDao.entryToDomain)
          .toList();

      // Одна и та же неизменная база отвечает по-разному на разные «когда»
      // — ровно то, чего хранимая колонка дать не может.
      final due = entries.first.dueDate;
      expect(CreditStanding.of(entries, due - 1).isOverdue, isFalse);
      expect(CreditStanding.of(entries, due + 1).isOverdue, isTrue);
      expect(CreditStanding.of(entries, due + 1).overdueEntries, 1);
      expect(CreditStanding.of(entries, due + 1).overdueAmount, d('300'));
    });

    test('оплаченная строка не просрочивается, сколько ни жди', () async {
      final number = await openContract();
      await credit.repay(
        contractNumber: number,
        amount: d('300'),
        userId: userId,
        receivingAccountId: posAccountId,
      );

      final row = (await db.creditDao.rowByNumber(number))!;
      final entries = (await db.creditDao.scheduleRows(row.id))
          .map(CreditDao.entryToDomain)
          .toList();
      final firstDue = entries.first.dueDate;

      expect(CreditStanding.of(entries, firstDue + 1).isOverdue, isFalse);
      // А второй месяц — просрочится.
      expect(
        CreditStanding.of(entries, entries[1].dueDate + 1).overdueEntries,
        1,
      );
    });

    test('ближайший срок и его сумма — то, что кассир говорит покупателю',
        () async {
      await openContract();
      final row = (await db.creditDao.rowByNumber('РС-1-1'))!;
      final entries = (await db.creditDao.scheduleRows(row.id))
          .map(CreditDao.entryToDomain)
          .toList();
      final standing = CreditStanding.of(entries, 1000);
      expect(standing.nextDueDate, entries.first.dueDate);
      expect(standing.nextDueAmount, d('300'));
    });
  });
}
