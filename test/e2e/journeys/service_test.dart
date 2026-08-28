library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';

import '../support/harness.dart';

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> seedServiceProduct(
  AppDatabase db, {
  required int ucode,
  required String name,
  required String price,
}) async {
  await db
      .into(db.productInfos)
      .insert(
        ProductInfosCompanion(
          ucode: Value(ucode),
          barcode: Value(ucode),
          name: Value(name),
          type: const Value(4),
          measure: const Value(0),
          quantity: Value(d('0')),
          categoryId: const Value(1),
          isDeleted: const Value(false),
        ),
      );
  await db
      .into(db.productPrices)
      .insert(
        ProductPricesCompanion(
          ucode: Value(ucode),
          barcode: Value(ucode),
          sellingPrice: Value(d(price)),
          wholesalePrice: Value(d(price)),
        ),
      );
  await db.quickProductDao.addQuickProduct(ucode: ucode, orderName: name);
}

void main() {
  final h = E2eHarness();

  const serviceName = 'Замена экрана';
  final servicePrice = d('5000');
  final prepayment = d('2000');
  final remaining = servicePrice - prepayment;

  setUp(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    await h.db.thisPosDao.updateOperatingMode(2);

    final seededUsers = await h.db.userDao.findActiveUsers();
    for (final u in seededUsers) {
      await h.db.userDao.updateUser(u.id, const UsersCompanion(role: Value(0)));
    }

    final cashierId = seededUsers
        .firstWhere((u) => u.name == E2eHarness.cashierName)
        .id;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db
        .into(h.db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: cashierId,
            openTime: nowSec,
            isOpened: true,
            isSynced: false,
          ),
        );

    await seedServiceProduct(
      h.db,
      ucode: 2001,
      name: serviceName,
      price: '5000',
    );
  });
  tearDown(() => h.tearDown());

  Future<void> gotoServiceQueue(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await h.pumpApp(tester);

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.go(AppRoutes.login);
    await tester.pump();

    final cashier = find.text(E2eHarness.cashierName);
    var reachedLogin = false;
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      if (cashier.evaluate().isNotEmpty) {
        reachedLogin = true;
        break;
      }
    }
    expect(
      reachedLogin,
      isTrue,
      reason: 'login screen with the seeded cashier must render',
    );

    await tester.tap(cashier.first);
    await settle(tester);
    for (int i = 0; i < 4; i++) {
      final zero = find.text('0');
      if (zero.evaluate().isNotEmpty) {
        await tester.tap(zero.first);
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    await settle(tester, 12);

    router.go(AppRoutes.serviceQueue);
    await settle(tester, 12);
  }

  group('Service journey: intake -> work -> close', () {
    testWidgets(
      'intake books prepayment as real cash-in; close collects remaining as revenue',
      (tester) async {
        final db = h.db;

        final posAccounts = await db.accountDao.findByType(AccountType.pos);
        expect(
          posAccounts,
          isNotEmpty,
          reason: 'seed must provide a POS account',
        );
        final posAccountId = posAccounts.first.id;
        final startBalance =
            (await db.accountDao.findById(posAccountId))!.value ?? Decimal.zero;

        await gotoServiceQueue(tester);
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: 'service queue must render',
        );
        final ordersBefore = await db.serviceOrderDao.findAll();
        expect(ordersBefore, isEmpty, reason: 'no service orders seeded');

        final fab = find.byType(FloatingActionButton);
        expect(
          fab,
          findsOneWidget,
          reason: 'queue must expose a "new order" FAB',
        );
        await tester.tap(fab);
        await settle(tester);
        expect(
          find.text('Приём заказа'),
          findsOneWidget,
          reason: 'FAB must open the intake screen',
        );

        expect(
          find.text('Сохранить'),
          findsOneWidget,
          reason: 'intake Save button present',
        );
        await tester.tap(find.text('Сохранить'));
        await settle(tester);
        expect(
          await db.serviceOrderDao.findAll(),
          isEmpty,
          reason: 'invalid (no client) intake must NOT create an order',
        );
        expect(
          find.text('Приём заказа'),
          findsOneWidget,
          reason: 'still on intake after invalid save attempt',
        );

        final nameField = find.widgetWithText(TextField, 'Имя клиента');
        expect(nameField, findsOneWidget, reason: 'client quick-name field');
        await tester.enterText(nameField, 'Иван Тестов');
        await settle(tester);

        final quickBtn = find.text(serviceName);
        expect(
          quickBtn,
          findsWidgets,
          reason: 'quick service button must render for a type=4 product',
        );
        await tester.tap(quickBtn.first);
        await settle(tester);
        expect(
          find.textContaining('5000'),
          findsWidgets,
          reason: 'selected service total (5000) must be shown',
        );

        await tester.tap(find.text('Предоплата'));
        await settle(tester);
        final prepayField = find.widgetWithText(TextField, 'Сумма предоплаты');
        expect(prepayField, findsOneWidget, reason: 'prepayment dialog field');
        await tester.enterText(prepayField, '2000');
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Сохранить').last);
        await settle(tester);

        expect(
          find.text('Сохранить'),
          findsWidgets,
          reason: 'Save button present',
        );
        await tester.tap(find.text('Сохранить').last);
        await settle(tester, 16);

        final orders = await db.serviceOrderDao.findAll();
        expect(orders.length, 1, reason: 'exactly one order created');
        final order = orders.first;
        expect(order.clientName, 'Иван Тестов');
        expect(order.status, 0, reason: 'new order starts in intake status');
        expect(
          order.prepaymentAmount,
          prepayment,
          reason: 'prepayment stored on order exactly',
        );

        final marks = await db.serviceMarkDao.getByOrder(order.id);
        expect(
          marks,
          isNotEmpty,
          reason: 'selected service must become a mark',
        );
        final markCost = await db.serviceMarkDao.sumCostByOrder(order.id);
        expect(
          markCost,
          servicePrice,
          reason: 'mark total must equal the service price exactly',
        );

        final cashOps = await db.select(db.cashOperations).get();
        expect(
          cashOps,
          isNotEmpty,
          reason: 'GUARD #17: prepayment must book a real cash operation',
        );
        final prepayOp = cashOps.firstWhere(
          (o) => o.amount == prepayment,
          orElse: () => throw TestFailure(
            'GUARD #17 FAIL: no cash-in operation for prepayment $prepayment',
          ),
        );
        expect(
          prepayOp.accountId,
          posAccountId,
          reason: 'prepayment must land on the POS cash account',
        );

        final balAfterPrepay =
            (await db.accountDao.findById(posAccountId))!.value ?? Decimal.zero;
        expect(
          balAfterPrepay,
          startBalance + prepayment,
          reason: 'POS balance must rise by the prepayment amount exactly',
        );

        expect(
          find.textContaining('${order.orderNumber}'),
          findsWidgets,
          reason: 'detail screen shows the order number',
        );

        Future<void> progress(String progressLabel) async {
          final btn = find.text(progressLabel);
          expect(
            btn,
            findsWidgets,
            reason: 'action bar must offer "$progressLabel"',
          );
          await tester.tap(btn.first);
          await settle(tester);
          final confirm = find.widgetWithText(FilledButton, 'Начать работу');
          expect(confirm, findsWidgets, reason: 'confirm dialog must appear');
          await tester.tap(confirm.last);
          await settle(tester, 12);
        }

        await progress('Начать работу');
        var reloaded = await db.serviceOrderDao.findById(order.id);
        expect(reloaded!.status, 1, reason: 'order should be inProgress');

        await progress('Готов');
        reloaded = await db.serviceOrderDao.findById(order.id);
        expect(reloaded!.status, 2, reason: 'order should be completed');

        await progress('Закрыт');
        reloaded = await db.serviceOrderDao.findById(order.id);
        expect(reloaded!.status, 3, reason: 'order should be closed');

        expect(
          reloaded.finalAmount,
          servicePrice,
          reason: 'GUARD #4: finalAmount must equal total work cost',
        );

        final sales = await db.select(db.sales).get();
        expect(
          sales,
          isNotEmpty,
          reason: 'GUARD #4: closing must create a Sale',
        );
        final closeSale = sales.firstWhere(
          (s) => s.amount == remaining,
          orElse: () => throw TestFailure(
            'GUARD #4 FAIL: no Sale for remaining $remaining on close',
          ),
        );

        final payments = await db.select(db.payments).get();
        final closePayment = payments.firstWhere(
          (p) => p.amount == remaining,
          orElse: () => throw TestFailure(
            'GUARD #4 FAIL: no Payment for remaining $remaining on close',
          ),
        );
        expect(
          closePayment.payeeAccountId,
          posAccountId,
          reason: 'GUARD #4: payment must land on the POS cash account',
        );
        expect(
          closePayment.receiptNo,
          closeSale.receiptNo,
          reason: 'payment must reference the close sale receipt',
        );

        final finalBalance =
            (await db.accountDao.findById(posAccountId))!.value ?? Decimal.zero;
        expect(
          finalBalance,
          startBalance + servicePrice,
          reason:
              'POS balance must equal prepayment + remaining = total, exact',
        );

        expect(
          reloaded.receiptNo,
          isNotNull,
          reason: 'closed order must be linked to its sale receipt',
        );
        expect(reloaded.receiptNo, closeSale.receiptNo);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
