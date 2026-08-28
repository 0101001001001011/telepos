library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/constants/enums/cash_in_out_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/usecases/fiscal/vat_calculator.dart';
import 'package:telepos/domain/usecases/service/add_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/create_service_order_use_case.dart';
import 'package:telepos/domain/usecases/service/service_order_transition_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.cashOperations).go();
    await h.db.delete(h.db.serviceMarks).go();
    await h.db.delete(h.db.serviceOrders).go();
    await h.db.delete(h.db.payments).go();
    await h.db.delete(h.db.sales).go();
    await h.db.delete(h.db.shifts).go();
  });

  test('consuming a part (consumable mark) decrements product stock '
      '(Decimal-exact)', () async {
    final db = GetIt.I<AppDatabase>();
    final addMark = GetIt.I<AddServiceMarkUseCase>();
    final createOrder = GetIt.I<CreateServiceOrderUseCase>();

    const partUcode = 1004;
    final before = (await db.productInfoDao.findByUcode(partUcode))?.quantity;
    expect(before, d('100'), reason: 'seed: part starts at 100 in stock');

    final order = await createOrder.create(
      userId: 1,
      clientName: 'Клиент А',
      complaint: 'Замена детали',
    );

    await addMark.add(
      serviceOrderId: order.id,
      description: 'Установлена деталь x3',
      markType: 1,
      userId: 1,
      cost: d('2670'),
      productUcode: partUcode,
      quantity: d('3'),
    );

    final after = (await db.productInfoDao.findByUcode(partUcode))?.quantity;
    expect(
      after,
      d('97'),
      reason: 'installing 3 parts must drop stock 100 → 97 (Decimal-exact)',
    );

    final otherBefore = (await db.productInfoDao.findByUcode(1005))?.quantity;
    await addMark.add(
      serviceOrderId: order.id,
      description: 'Диагностика',
      markType: 4,
      userId: 1,
      cost: d('1000'),
    );
    final otherAfter = (await db.productInfoDao.findByUcode(1005))?.quantity;
    expect(
      otherAfter,
      otherBefore,
      reason: 'a pure-service mark with no productUcode never moves stock',
    );
  });

  test('cancelling an order with a prepayment posts a reversal cash-out and '
      'nets the till back to its opening balance', () async {
    final db = GetIt.I<AppDatabase>();
    final createOrder = GetIt.I<CreateServiceOrderUseCase>();
    final transition = GetIt.I<ServiceOrderTransitionUseCase>();

    final posAccId = (await db.accountDao.findByType(AccountType.pos)).first.id;
    final opening =
        (await db.accountDao.findById(posAccId))?.value ?? Decimal.zero;

    const prepay = '5000';

    final order = await createOrder.create(
      userId: 1,
      clientName: 'Клиент Б',
      complaint: 'Ремонт с предоплатой',
      prepaymentAmount: d(prepay),
    );

    final afterIntake =
        (await db.accountDao.findById(posAccId))?.value ?? Decimal.zero;
    expect(
      afterIntake,
      opening + d(prepay),
      reason: 'prepayment is booked into the till as cash-in',
    );
    final ins = await (db.select(
      db.cashOperations,
    )..where((c) => c.type.equals(CashInOutType.investment.index))).get();
    expect(
      ins.where((o) => o.amount == d(prepay)),
      isNotEmpty,
      reason: 'intake records a cash-IN investment for the prepayment',
    );

    final cancelled = await transition.cancel(order.id);
    expect(cancelled.status.index, 4, reason: 'order is cancelled (status 4)');

    final outs = await (db.select(
      db.cashOperations,
    )..where((c) => c.type.equals(CashInOutType.expense.index))).get();
    expect(
      outs.where((o) => o.amount == d(prepay)),
      isNotEmpty,
      reason: 'cancellation posts a cash-OUT reversal for the prepayment',
    );

    final afterCancel =
        (await db.accountDao.findById(posAccId))?.value ?? Decimal.zero;
    expect(
      afterCancel,
      opening,
      reason: 'reversal nets the till back to opening — no stuck money',
    );
  });

  test('cancelling a no-prepayment order posts no reversal', () async {
    final db = GetIt.I<AppDatabase>();
    final createOrder = GetIt.I<CreateServiceOrderUseCase>();
    final transition = GetIt.I<ServiceOrderTransitionUseCase>();

    final order = await createOrder.create(
      userId: 1,
      clientName: 'Клиент В',
      complaint: 'Без предоплаты',
    );
    await transition.cancel(order.id);

    final ops = await db.select(db.cashOperations).get();
    expect(
      ops,
      isEmpty,
      reason: 'no prepayment → nothing to reverse → no cash movement',
    );
  });

  test('service receipt total has a Decimal-exact 16% НДС breakdown', () async {
    final breakdown = VatCalculator.breakdown(d('1160'));
    expect(
      breakdown.vatAmount,
      d('160'),
      reason: 'НДС from 1160 gross must be exactly 160 (16/116)',
    );
    expect(
      breakdown.netAmount,
      d('1000'),
      reason: 'нетто from 1160 gross must be exactly 1000',
    );
    expect(breakdown.vatRatePercent, VatCalculator.standardRatePercent);
  });
}
