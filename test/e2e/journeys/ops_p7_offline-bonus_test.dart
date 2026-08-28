library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/usecases/agent/bonus_service_impl.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  test('bonus accrual + balance + deduction run OFFLINE against the local '
      'cashback account (Decimal-exact, never throws NoInternet)', () async {
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

    final deduct = await service.deductBonuses(
      phone: phone,
      amount: d('200'),
      saleReceiptNo: 42,
    );
    expect(deduct.success, isTrue);
    expect(deduct.deductedAmount, d('200'));
    expect(
      deduct.remainingBalance,
      d('350'),
      reason: '550 - 200 = 350, Decimal-exact',
    );

    final afterDeduct = (await db.accountDao.findById(cashbackAccId))?.value;
    expect(afterDeduct, d('350'));

    final tooMuch = await service.deductBonuses(
      phone: phone,
      amount: d('1000'),
      saleReceiptNo: 42,
    );
    expect(
      tooMuch.success,
      isFalse,
      reason: 'cannot redeem more bonus than available',
    );
    expect(
      tooMuch.remainingBalance,
      d('350'),
      reason: 'balance is untouched on a rejected deduction',
    );
    final unchanged = (await db.accountDao.findById(cashbackAccId))?.value;
    expect(unchanged, d('350'));

    final unknown = await service.getBonusBalance(7000000000);
    expect(unknown.balance, Decimal.zero);

    await service.cancelTransaction('local-accrual-42-0');
  });
}
