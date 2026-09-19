library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.payments).go();
    await h.db.delete(h.db.saleProducts).go();
    await h.db.delete(h.db.sales).go();
    await h.db.delete(h.db.shifts).go();

    // Задача 5 плана «Продажа с браузерного терминала»:
    // `SaleInitiationUseCaseImpl.initiate()` больше не открывает смену сама,
    // когда её нет, — она отвечает отказом `shift_not_open`. Этот сценарий
    // чистит смены перед каждой пробой и молча полагался на прежнее
    // самооткрытие; теперь смена открывается **явно**, тем же действием, каким
    // её открывает касса перед продажей, и **на названного человека** — того
    // самого кассира, которого завёл харнесс, а не на выдуманный `userId: 1`.
    //
    // Посев вынесен в `E2eHarness.openShift()` при слиянии: те же девять
    // сценариев чинились дважды и по-разному — ветвь `wire-sale` сеяла
    // смену дословно в каждом файле, ветвь `browser-sale` завела помощник.
    // Взято тело помощника; там же назван и довод про **текущее** время
    // открытия (смена задним числом упёрлась бы в сторож «открыта более 24
    // часов», `kShiftMaxAge`, и продажа отказала бы снова, другой причиной).
    await h.openShift();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> waitForSaleInit(SaleNotifier sale) async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (container.read(saleControllerProvider).receiptNo != null) return;
    }
  }

  test('bonus redemption DEBITS the customer cashback account and the recorded '
      'payments cover the full total (no free money)', () async {
    final db = GetIt.I<AppDatabase>();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
    final customerLocalId = await db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            type: const drift.Value(1),
            name: const drift.Value('Лояльный Клиент'),
            phone: const drift.Value(7011234567),
            cashbackAccountId: drift.Value(cashbackAccId),
            isDeleted: const drift.Value(false),
            editTime: drift.Value(now),
          ),
        );

    const bonusUcode = 2001;
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(bonusUcode),
            barcode: const drift.Value(4609001),
            name: const drift.Value('Корзина 1000'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d('100')),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const drift.Value(bonusUcode),
            barcode: const drift.Value(4609001),
            sellingPrice: drift.Value(d('1000')),
            wholesalePrice: drift.Value(d('1000')),
          ),
        );

    final posAccounts = await db.accountDao.findByType(AccountType.pos);
    expect(posAccounts, isNotEmpty, reason: 'harness seeds a POS account');
    final posAccId = posAccounts.first.id;
    final posOpening =
        (await db.accountDao.findById(posAccId))?.value ?? Decimal.zero;

    final saleNotifier = container.read(saleControllerProvider.notifier);
    await waitForSaleInit(saleNotifier);
    final saleState = container.read(saleControllerProvider);
    expect(
      saleState.receiptNo,
      isNotNull,
      reason: 'sale must initialize (receiptNo) before payment',
    );

    // Команда корзины асинхронна с задачи 7: она идёт в базу через
    // контракт `CartService`, а не правит состояние на месте. Без
    // `await` следующая строка читает снимок ДО команды — сумма 0, а
    // продолжение работает поверх уже выброшенного нотифайера.
    await saleNotifier.addProduct(
      ProductSearchResult(
        id: bonusUcode,
        name: 'Корзина 1000',
        price: d('1000'),
      ),
    );

    final total = container.read(saleControllerProvider).total;
    expect(total, d('1000'), reason: 'sale total must be exactly 1000');

    final payNotifier = container.read(paymentControllerProvider.notifier);
    payNotifier.initialize(total);
    payNotifier.setPaymentType(PaymentType.cash);

    await payNotifier.searchLoyaltyCustomer('7011234567');
    final loyaltyState = container.read(paymentControllerProvider);
    expect(
      loyaltyState.loyaltyCustomer,
      isNotNull,
      reason: 'phone search must resolve the seeded loyalty customer',
    );
    expect(loyaltyState.loyaltyCustomer!.id, customerLocalId);
    expect(
      loyaltyState.availableBonus,
      d(cashbackOpening),
      reason: 'available bonus must equal the cashback balance (500)',
    );

    // Та же вторая причина, что и у команд корзины, но на операциях
    // оплаты: `setBonusToUse` ушла за контракт `PaymentService`
    // (задача 14) и стала асинхронной — потолок бонуса ставит касса, а
    // не экран. Без `await` следующая строка читает снимок ДО ответа
    // кассы и видит ноль. Найдено слиянием: ветвь продажи чинила
    // ожидание только своим командам, ветвь оплаты этой пробы не
    // видела зелёной ни разу.
    await payNotifier.setBonusToUse(d('200'));
    expect(container.read(paymentControllerProvider).bonusToUse, d('200'));
    expect(
      container.read(paymentControllerProvider).amountToPay,
      d('800'),
      reason: 'cash/card to collect = total - bonus = 800',
    );

    payNotifier.setCashReceived(d('800'));
    expect(
      container.read(paymentControllerProvider).canComplete,
      isTrue,
      reason: '800 cash covers the 800 remaining after bonus',
    );

    final ok = await payNotifier.processPayment();
    expect(ok, isTrue, reason: 'payment must complete');

    final completed = await db.saleDao.findByState(1);
    expect(completed.length, 1, reason: 'exactly one completed sale');
    final sale = completed.first;
    expect(
      sale.amount,
      d('1000'),
      reason:
          'sale amount is the FULL total 1000 (bonus is not a discount '
          'on the recorded sale)',
    );

    final payments = await db.paymentDao.findBySale(sale.receiptNo, sale.posId);
    expect(
      payments.length,
      2,
      reason: 'two payment lines: cash + bonus redemption',
    );
    final paySum = payments.fold<Decimal>(Decimal.zero, (s, p) => s + p.amount);
    expect(
      paySum,
      d('1000'),
      reason: 'recorded payments must cover the full total — no free money',
    );

    final cashbackAfter = (await db.accountDao.findById(cashbackAccId))?.value;
    expect(
      cashbackAfter,
      d('300'),
      reason: 'cashback balance must DECREASE by the redeemed bonus (200)',
    );

    final posAfter =
        (await db.accountDao.findById(posAccId))?.value ?? Decimal.zero;
    expect(
      posAfter - posOpening,
      d('800'),
      reason: 'cash account receives only the 800 cash portion',
    );

    final bonusLine = payments.firstWhere(
      (p) => p.payeeAccountId == cashbackAccId,
      orElse: () => throw StateError('no bonus payment line recorded'),
    );
    expect(
      bonusLine.amount,
      d('200'),
      reason: 'bonus payment line amount == redeemed bonus',
    );
    expect(
      bonusLine.customerLocalId,
      customerLocalId,
      reason: 'bonus payment is tied to the loyalty customer',
    );
  });
}
