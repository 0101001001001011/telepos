library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/usecases/agent/bonus_service_impl.dart';
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';

import '../support/harness.dart';

/// P7: бонусы работают **оффлайн**, против местного кэшбэк-счёта, и никогда
/// не бросают `NoInternet`.
///
/// # Что здесь изменилось в задаче 13 — и почему это не потеря покрытия
///
/// Проба звала `BonusService.deductBonuses` и `cancelTransaction`. Обе
/// удалены, и обе были **вторым способом** сделать то, что продукт делает
/// иначе:
///
/// - списание в кассе идёт строкой `Payments` на бонусный счёт, а потолок
///   («не больше остатка», «не больше суммы чека») стоит в
///   `LocalPaymentService._plan`, где о чеке известно. Проверка потолка
///   живёт в `test/data/sale/` и в `refund_bonus_sign_test.dart` — на
///   настоящем пути, а не на дублирующем методе;
/// - `cancelTransaction` была пустым `return;` и не вызывалась ниоткуда.
///
/// Взамен проба спрашивает то, чего до журнала спросить было нельзя вовсе:
/// **чем объясняется остаток**. «Оффлайн работает» и «остаток верен» —
/// разные утверждения, и второе сильнее.
void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  test('bonus accrual runs OFFLINE against the local cashback account, and '
      'the balance is explained by the journal (Decimal-exact)', () async {
    final db = GetIt.I<AppDatabase>();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
        .write(const ThisPosEntriesCompanion(cashbackRate: drift.Value(5)));

    const cashbackOpening = '500';
    final cashbackAccId = await db.accountDao.insertAccount(
      AccountsCompanion(
        id: drift.Value(await db.accountDao.getNextId()),
        type: const drift.Value(AccountType.agentCashback),
        name: const drift.Value('Бонусы клиента'),
        value: drift.Value(d(cashbackOpening)),
        visibleToPos: const drift.Value(false),
        updateTime: drift.Value(now),
      ),
    );
    // Счёт заведён **после** миграции, поэтому стартовой записи у него нет:
    // журнал объясняет только то, что произошло с ним при живом журнале.
    // Сверка это знает и потому обязана показать расхождение — оно здесь
    // настоящее, а не ложная тревога.
    await db.bonusEntryDao.record(
      accountId: cashbackAccId,
      kind: BonusEntryKind.opening,
      amount: d(cashbackOpening),
      reason: 'остаток на момент заведения счёта',
    );
    // `record` сдвинул остаток на свою сумму — вернём объявленный.
    await db.accountDao.updateBalance(
      cashbackAccId,
      d(cashbackOpening),
      redemption: true,
    );

    const phone = 7011234567;
    await db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            type: const drift.Value(1),
            name: const drift.Value('Лояльный Клиент'),
            phone: const drift.Value(phone),
            cashbackAccountId: drift.Value(cashbackAccId),
            isDeleted: const drift.Value(false),
            editTime: drift.Value(now),
          ),
        );

    final service = BonusServiceImpl(db: db);

    final opening = await service.getBonusBalance(phone);
    expect(
      opening.balance,
      d(cashbackOpening),
      reason: 'offline balance must equal the local cashback account value',
    );
    expect(opening.name, 'Лояльный Клиент');

    final accrual = await service.accrualBonuses(
      phone: phone,
      saleAmount: d('1000'),
      saleReceiptNo: 42,
    );
    expect(accrual.success, isTrue);
    expect(
      accrual.accruedAmount,
      d('50'),
      reason: '5% of 1000 = 50, Decimal-exact',
    );
    expect(
      accrual.newBalance,
      d('550'),
      reason: 'cashback 500 + 50 accrued = 550',
    );

    final afterAccrual = (await db.accountDao.findById(cashbackAccId))?.value;
    expect(
      afterAccrual,
      d('550'),
      reason: 'accrual must persist to the local cashback account',
    );

    final reread = await service.getBonusBalance(phone);
    expect(reread.balance, d('550'));

    // **Несущее утверждение после задачи 13.** Остаток объясняется журналом
    // целиком: 500 стартовых плюс 50 начисленных. До журнала объяснять его
    // было нечем — «кто, когда, по какому чеку» не записывалось нигде.
    expect(await db.bonusEntryDao.balanceOf(cashbackAccId), d('550'));
    expect(
      await db.bonusEntryDao.divergences(),
      isEmpty,
      reason: 'записанный остаток обязан совпасть с суммой журнала',
    );

    final journal = await db.bonusEntryDao.findByAccount(cashbackAccId);
    final accrued = journal.where((e) => e.kind == BonusEntryKind.accrual);
    expect(accrued, hasLength(1));
    expect(accrued.single.amount, d('50'));
    expect(
      accrued.single.receiptNo,
      42,
      reason: 'по какому чеку — то, чего в базе не было нигде',
    );
    expect(
      accrued.single.reason,
      contains('5'),
      reason: 'запись называет ставку, по которой начислено: '
          'к моменту возврата ставка может быть другой',
    );

    // Ставка ноль начисляет ноль — и записи не заводит: журнал не место для
    // «ничего не произошло».
    await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
        .write(const ThisPosEntriesCompanion(cashbackRate: drift.Value(0)));
    final none = await service.accrualBonuses(
      phone: phone,
      saleAmount: d('1000'),
      saleReceiptNo: 43,
    );
    expect(none.success, isTrue);
    expect(none.accruedAmount, Decimal.zero);
    expect(await db.bonusEntryDao.findBySale(43, 1), isEmpty);
    expect(await db.bonusEntryDao.balanceOf(cashbackAccId), d('550'));

    // Неизвестный телефон — ноль и никакого исключения: оффлайн есть
    // оффлайн.
    final unknown = await service.getBonusBalance(7000000000);
    expect(unknown.balance, Decimal.zero);
  });
}
