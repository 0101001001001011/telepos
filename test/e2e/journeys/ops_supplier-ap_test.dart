library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUp(() => h.setUp());
  tearDown(() => h.tearDown());

  Future<Decimal> balanceOf(AppDatabase db, int accountId) async {
    final acc = await db.accountDao.findById(accountId);
    return acc?.value ?? Decimal.zero;
  }

  Future<Decimal> supplierLedger(AppDatabase db, int agentLocalId) async {
    final agent = await db.agentDao.findByLocalId(agentLocalId);
    final accId = agent?.mainAccountId;
    if (accId == null) return Decimal.zero;
    return balanceOf(db, accId);
  }

  Future<Decimal> stockOf(AppDatabase db, int ucode) async {
    final p = await db.productInfoDao.findByUcode(ucode);
    return p?.quantity ?? Decimal.zero;
  }

  Future<({int agentId, int apAccountId})> seedSupplier(
    AppDatabase db, {
    required Decimal openingAp,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final apAccId = await db.accountDao.insertAccount(
      AccountsCompanion(
        id: drift.Value(await db.accountDao.getNextId()),
        type: const drift.Value(AccountType.agentMain),
        name: const drift.Value('Кредиторка ОптТорг'),
        value: drift.Value(openingAp),
        visibleToPos: const drift.Value(false),
        updateTime: drift.Value(now),
      ),
    );
    final agentId = await db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            type: const drift.Value(0),
            name: const drift.Value('ОптТорг'),
            mainAccountId: drift.Value(apAccId),
            isDeleted: const drift.Value(false),
            editTime: drift.Value(now),
          ),
        );
    return (agentId: agentId, apAccountId: apAccId);
  }

  Future<void> addLine(
    AppDatabase db, {
    required int supplyId,
    required int ucode,
    required Decimal qty,
    required Decimal price,
  }) async {
    await db.supplyProductDao.insertProduct(
      SupplyProductsCompanion(
        supplyId: drift.Value(supplyId),
        ucode: drift.Value(ucode),
        quantity: drift.Value(qty),
        price: drift.Value(price),
        amount: drift.Value(qty * price),
      ),
    );
  }

  test('supplier supply: FULL pay debits cash & settles AP ledger; CONSIGNMENT '
      'leaves cash and grows AP', () async {
    final db = h.db;
    GetIt.I.registerSingleton<AppDatabase>(db);

    final create = GetIt.I<CreateSupplyUseCase>();
    final save = GetIt.I<SaveSupplyUseCase>();

    final posAccId = (await db.accountDao.findByType(AccountType.pos)).first.id;
    await db.accountDao.updateBalance(posAccId, d('20000'));
    expect(await balanceOf(db, posAccId), d('20000'));

    final supplierA = await seedSupplier(db, openingAp: Decimal.zero);
    final openingStock = await stockOf(db, 1001);

    final createdA = await create.execute(
      userId: 1,
      supplierId: supplierA.agentId,
      paymentType: SupplyPaymentType.fullSupply,
      accountId: posAccId,
    );
    expect(createdA.success, isTrue, reason: 'draft created');

    await addLine(
      db,
      supplyId: createdA.supplyId,
      ucode: 1001,
      qty: d('10'),
      price: d('500'),
    );

    final resultA = await save.execute(createdA.supplyId);
    expect(resultA.success, isTrue, reason: resultA.errorMessage ?? '');
    expect(resultA.totalAmount, d('5000'), reason: 'exact Decimal total');

    final rowA = await db.supplyDao.findById(createdA.supplyId);
    expect(rowA!.amount, d('5000'));
    expect(rowA.payment, d('5000'), reason: 'paid in full');
    expect(rowA.consignmentAmount, Decimal.zero);

    expect(
      await balanceOf(db, posAccId),
      d('15000'),
      reason: 'cash account must be DEBITED by the paid amount',
    );

    expect(
      await supplierLedger(db, supplierA.agentId),
      Decimal.zero,
      reason: 'full payment settles the supplier ledger (net 0)',
    );

    expect(
      await stockOf(db, 1001),
      openingStock + d('10'),
      reason: 'received quantity added to stock',
    );

    final cashAfterFull = await balanceOf(db, posAccId);
    final supplierB = await seedSupplier(db, openingAp: d('1000'));

    final createdB = await create.execute(
      userId: 1,
      supplierId: supplierB.agentId,
      paymentType: SupplyPaymentType.consignment,
    );
    expect(createdB.success, isTrue);

    await addLine(
      db,
      supplyId: createdB.supplyId,
      ucode: 1002,
      qty: d('6'),
      price: d('500'),
    );

    final resultB = await save.execute(createdB.supplyId);
    expect(resultB.success, isTrue, reason: resultB.errorMessage ?? '');
    expect(resultB.totalAmount, d('3000'));

    final rowB = await db.supplyDao.findById(createdB.supplyId);
    expect(rowB!.payment, Decimal.zero, reason: 'nothing paid');
    expect(rowB.consignmentAmount, d('3000'));

    expect(
      await balanceOf(db, posAccId),
      cashAfterFull,
      reason: 'consignment must not move cash',
    );

    expect(
      await supplierLedger(db, supplierB.agentId),
      d('4000'),
      reason: 'unpaid supply increases кредиторка by its full amount',
    );
  });
}
