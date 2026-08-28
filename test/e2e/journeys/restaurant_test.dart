library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/close_table_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/create_table_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/split_bill_use_case.dart';
import 'package:telepos/presentation/screens/restaurant/table_detail_screen.dart';
import 'package:telepos/presentation/screens/restaurant/table_map_screen.dart';
import 'package:telepos/presentation/screens/restaurant/widgets/menu_product_grid.dart';

import '../support/harness.dart';

Decimal _d(String v) => Decimal.parse(v);

const _dishAName = 'Бургер';
const _dishBName = 'Кола 0.5';
final _dishAPrice = _d('1200');
final _dishBPrice = _d('450');
const _dishAUcode = 2001;
const _dishBUcode = 2002;

Future<void> _seedMenu(AppDatabase db) async {
  await db.thisPosDao.updateOperatingMode(1);

  final cashier = (await db.userDao.findActiveUsers()).first;
  await db.userDao.updateUser(cashier.id, const UsersCompanion(role: Value(0)));

  for (final p in [
    (
      ucode: _dishAUcode,
      barcode: 5500001,
      name: _dishAName,
      price: _dishAPrice,
    ),
    (
      ucode: _dishBUcode,
      barcode: 5500002,
      name: _dishBName,
      price: _dishBPrice,
    ),
  ]) {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(p.ucode),
            barcode: Value(p.barcode),
            name: Value(p.name),
            type: const Value(0),
            measure: const Value(0),
            quantity: Value(_d('100')),
            categoryId: const Value(1),
            isDeleted: const Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: Value(p.ucode),
            barcode: Value(p.barcode),
            sellingPrice: Value(p.price),
            wholesalePrice: Value(p.price),
          ),
        );
  }

  final categoryId = await db.quickProductDao.createCategory(name: 'Кухня');
  await db.quickProductDao.addQuickProduct(
    ucode: _dishAUcode,
    parentId: categoryId,
    orderName: _dishAName,
  );
  await db.quickProductDao.addQuickProduct(
    ucode: _dishBUcode,
    parentId: categoryId,
    orderName: _dishBName,
  );
}

Future<int> _seedTableAndShift(AppDatabase db) async {
  await db.delete(db.guestSplits).go();
  await db.delete(db.restaurantOrders).go();
  await db.delete(db.saleProducts).go();
  await db.delete(db.sales).go();
  await db.delete(db.restaurantTables).go();
  await db.delete(db.shifts).go();

  final cashier = (await db.userDao.findActiveUsers()).first;
  await db.shiftDao.insertShift(
    ShiftsCompanion.insert(
      userId: cashier.id,
      openTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      isOpened: true,
      isSynced: false,
    ),
  );

  return db.restaurantTableDao.insert(
    RestaurantTablesCompanion.insert(
      name: 'Стол 7',
      zone: const Value('Зал'),
      capacity: const Value(4),
    ),
  );
}

Future<void> _settle(
  WidgetTester tester, {
  int frames = 12,
  Duration step = const Duration(milliseconds: 80),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

Future<void> _login(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  router.go(AppRoutes.login);
  await tester.pump();

  final userTile = find.text(E2eHarness.cashierName);
  var reachedLogin = false;
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 150));
    if (userTile.evaluate().isNotEmpty) {
      reachedLogin = true;
      break;
    }
  }
  expect(reachedLogin, isTrue, reason: 'seeded cashier must be offered');

  await tester.tap(userTile.first);
  await tester.pump(const Duration(milliseconds: 200));

  Finder loginButton() => find.byWidgetPredicate(
    (w) =>
        w is ElevatedButton &&
        w.child is Text &&
        ((w.child as Text).data?.startsWith('Войти') ?? false),
  );
  for (var i = 0; i < 20 && loginButton().evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  expect(
    loginButton(),
    findsWidgets,
    reason: 'no-PIN cashier must offer a login button',
  );
  await tester.tap(loginButton().first);

  await _settle(tester, frames: 25, step: const Duration(milliseconds: 100));
}

void main() {
  final h = E2eHarness();
  late int tableId;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    await _seedMenu(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    tableId = await _seedTableAndShift(h.db);
  });

  group('Restaurant: table -> order -> split -> pay', () {
    testWidgets('login in restaurant mode lands on the table map (/tables)', (
      tester,
    ) async {
      await h.pumpApp(tester);
      await _login(tester);

      expect(
        find.byType(TableMapScreen),
        findsOneWidget,
        reason: 'restaurant mode must default-route to the table map',
      );
      expect(
        find.text('Стол 7'),
        findsWidgets,
        reason: 'seeded table must be visible on the map',
      );
    });

    testWidgets('open table -> create order -> add items (money exact) -> '
        'split keeps full total -> pay frees table', (tester) async {
      await h.pumpApp(tester);
      await _login(tester);
      expect(find.byType(TableMapScreen), findsOneWidget);

      final db = GetIt.I<AppDatabase>();

      await tester.tap(find.text('Стол 7').first);
      await _settle(tester, frames: 20);
      expect(
        find.byType(TableDetailScreen),
        findsOneWidget,
        reason: 'tapping a free table opens its detail screen',
      );

      final openOrderCta = find.text('Открыть заказ');
      expect(
        openOrderCta,
        findsWidgets,
        reason: 'free table should offer to open an order',
      );

      await tester.tap(openOrderCta.first);
      await _settle(tester);
      // Искатель обязан быть привязан к диалогу, а не к тексту вообще.
      // `widgetWithText(FilledButton, …)` — это «любой FilledButton-предок
      // любого Text с этой надписью», и таких на экране ДВА, пока диалог
      // открыт: CTA самого экрана (`table_detail_screen.dart:165`,
      // `FilledButton.icon` со своим стилем) остаётся построенным под
      // затемнением, потому что маршрут диалога непрозрачным не бывает, и
      // кнопка подтверждения в `actions` (`:986`). Двусмысленность была в
      // тесте с самого начала; до Flutter 3.47 он попадал в одну кнопку по
      // совпадению, а не по адресу. Привязка к `AlertDialog` говорит ровно
      // то, что сказано ниже в `reason`.
      final dialogConfirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Открыть заказ'),
      );
      expect(
        dialogConfirm,
        findsOneWidget,
        reason: 'create-order dialog must have a confirm button',
      );
      await tester.tap(dialogConfirm);
      await _settle(tester, frames: 25);

      final order = await db.restaurantOrderDao.findOpenByTable(tableId);
      expect(order, isNotNull, reason: 'createOrder must persist an order');
      final tableRow = await db.restaurantTableDao.findById(tableId);
      expect(
        tableRow!.status,
        equals(TableStatus.occupied.index),
        reason: 'creating an order must occupy the table',
      );

      await tester.tap(find.text('Кухня').first);
      await _settle(tester, frames: 15);

      Future<void> tapDish(String name) async {
        final card = find.descendant(
          of: find.byType(MenuProductGrid),
          matching: find.text(name),
        );
        expect(
          card,
          findsWidgets,
          reason: '$name must render in the menu grid',
        );
        await tester.tap(card.first);
        await _settle(tester, frames: 10);
      }

      await tapDish(_dishAName);
      await tapDish(_dishAName);
      await tapDish(_dishBName);

      final expectedTotal = _dishAPrice * _d('2') + _dishBPrice;
      expect(expectedTotal, equals(_d('2850')));

      final orderId = order!.id;
      final reloaded = await db.restaurantOrderDao.findById(orderId);
      final sale = await db.saleDao.findByKey(
        reloaded!.receiptNo!,
        reloaded.posId!,
      );
      expect(sale, isNotNull);
      expect(
        sale!.amount,
        equals(expectedTotal),
        reason: 'persisted sale total must equal exact item sum (Decimal)',
      );

      expect(
        find.text('2850'),
        findsWidgets,
        reason: 'order total must display the exact amount',
      );

      final splitBtn = find.byIcon(Icons.call_split_rounded);
      expect(
        splitBtn,
        findsOneWidget,
        reason: 'order action bar must expose a split-bill button',
      );
      await tester.tap(splitBtn);
      await _settle(tester);
      expect(
        find.text('Разделение счёта'),
        findsOneWidget,
        reason: 'split-bill dialog must open',
      );

      final dialogPlus = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(TeleposIcons.add),
      );
      expect(
        dialogPlus,
        findsOneWidget,
        reason: 'split dialog must expose a +1-guest control',
      );
      await tester.tap(dialogPlus);
      await _settle(tester);
      expect(
        find.textContaining('950'),
        findsWidgets,
        reason: 'even split must show the per-guest amount',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Применить'));
      await _settle(tester, frames: 15);

      final splits = await db.guestSplitDao.getByOrder(orderId);
      expect(
        splits,
        isNotEmpty,
        reason: 'split must persist guest_splits rows',
      );
      final perProduct = <int, Decimal>{};
      for (final s in splits) {
        perProduct[s.saleProductId] =
            (perProduct[s.saleProductId] ?? Decimal.zero) + s.shareQuantity;
      }
      final saleProducts = await db.saleProductDao.findBySale(
        reloaded.receiptNo!,
        reloaded.posId!,
      );
      for (final sp in saleProducts) {
        final shareSum = perProduct[sp.id];
        expect(
          shareSum,
          isNotNull,
          reason: 'every sale product must be split across guests',
        );
        expect(
          shareSum,
          equals(sp.quantity),
          reason:
              'sum of per-guest shares must equal full quantity '
              '(no money/quantity loss): product ${sp.id}',
        );
      }

      final saleAfterSplit = await db.saleDao.findByKey(
        reloaded.receiptNo!,
        reloaded.posId!,
      );
      expect(
        saleAfterSplit!.amount,
        equals(expectedTotal),
        reason: 'splitting the bill must NOT change the settlement total',
      );

      await GetIt.I<CloseTableOrderUseCase>().close(orderId);
      final freedOrder = await db.restaurantOrderDao.findById(orderId);
      expect(
        freedOrder!.closeTime,
        isNotNull,
        reason: 'closing the order must stamp closeTime',
      );
      final freedTable = await db.restaurantTableDao.findById(tableId);
      expect(
        freedTable!.status,
        isNot(equals(TableStatus.occupied.index)),
        reason: 'paying/closing the order must release the table',
      );
      expect(
        freedTable.status,
        equals(TableStatus.dirty.index),
        reason: 'closed table transitions to dirty (free-to-buss)',
      );
      expect(
        await db.restaurantOrderDao.findOpenByTable(tableId),
        isNull,
        reason: 'the table must have no open order after payment',
      );
    });

    testWidgets(
      'takeout button creates a real tableless order and navigates into it '
      '(guards #12/#13/#14 — no tableId=0 dead-end)',
      (tester) async {
        await h.pumpApp(tester);
        await _login(tester);
        expect(find.byType(TableMapScreen), findsOneWidget);

        final db = GetIt.I<AppDatabase>();
        final beforeMaxId = await _maxOrderId(db);

        final takeoutBtn = find.text('Навынос');
        expect(
          takeoutBtn,
          findsWidgets,
          reason: 'table map must show a takeout button',
        );
        await tester.tap(takeoutBtn.first);
        await _settle(tester);

        final confirm = find.widgetWithText(FilledButton, 'Открыть заказ');
        expect(
          confirm,
          findsOneWidget,
          reason: 'takeout dialog must offer to open the order',
        );
        await tester.tap(confirm);
        await _settle(tester, frames: 25);

        final afterMaxId = await _maxOrderId(db);
        expect(
          afterMaxId,
          greaterThan(beforeMaxId),
          reason: 'takeout must persist a new order',
        );
        final newOrder = await db.restaurantOrderDao.findById(afterMaxId);
        expect(newOrder, isNotNull);
        expect(
          newOrder!.orderType,
          equals(OrderType.takeout.index),
          reason: 'order type must be takeout',
        );
        expect(
          newOrder.tableId,
          isNull,
          reason:
              'takeout order must NOT be bound to a phantom table '
              '(guards the tableId=0 dead-end)',
        );

        expect(
          find.byType(TableDetailScreen),
          findsOneWidget,
          reason: 'takeout must open the order detail screen, not dead-end',
        );
        expect(
          find.byType(TableMapScreen),
          findsNothing,
          reason: 'must have left the table map into the order flow',
        );
      },
    );

    testWidgets('delivery button reaches a real tableless order flow '
        '(guards #12/#13/#14)', (tester) async {
      await h.pumpApp(tester);
      await _login(tester);
      expect(find.byType(TableMapScreen), findsOneWidget);

      final db = GetIt.I<AppDatabase>();
      final beforeMaxId = await _maxOrderId(db);

      final deliveryBtn = find.text('Доставка');
      expect(
        deliveryBtn,
        findsWidgets,
        reason: 'table map must show a delivery button',
      );
      await tester.tap(deliveryBtn.first);
      await _settle(tester);

      final confirm = find.widgetWithText(FilledButton, 'Открыть заказ');
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await _settle(tester, frames: 25);

      final afterMaxId = await _maxOrderId(db);
      expect(
        afterMaxId,
        greaterThan(beforeMaxId),
        reason: 'delivery must persist a new order',
      );
      final newOrder = await db.restaurantOrderDao.findById(afterMaxId);
      expect(newOrder!.orderType, equals(OrderType.delivery.index));
      expect(
        newOrder.tableId,
        isNull,
        reason: 'delivery order must not be bound to a phantom table',
      );
      expect(
        find.byType(TableDetailScreen),
        findsOneWidget,
        reason: 'delivery must open a real order flow',
      );
    });

    test(
      'split use case rejects zero guests (Error/invalid — no div-by-zero)',
      () async {
        final order = await GetIt.I<CreateTableOrderUseCase>().create(
          tableId: null,
          partySize: 1,
          orderType: OrderType.takeout,
        );
        expect(
          () => GetIt.I<SplitBillUseCase>().splitEvenly(order.id, 0),
          throwsA(isA<ArgumentError>()),
          reason:
              'splitting among 0 guests must be rejected, not divide-by-zero',
        );
      },
    );

    test('open-orders list reflects created tableless orders (Read)', () async {
      final db = GetIt.I<AppDatabase>();
      expect(
        await db.restaurantOrderDao.getOpenOrders(),
        isEmpty,
        reason: 'fresh DB has no open orders (Empty state)',
      );

      await GetIt.I<CreateTableOrderUseCase>().create(
        tableId: null,
        partySize: 2,
        orderType: OrderType.takeout,
        note: 'E2E takeout',
      );

      final open = await db.restaurantOrderDao.getOpenOrders();
      expect(open, isNotEmpty);
      expect(
        open.any(
          (o) => o.tableId == null && o.orderType == OrderType.takeout.index,
        ),
        isTrue,
        reason: 'a tableless takeout order must be present in the list',
      );
    });
  });
}

Future<int> _maxOrderId(AppDatabase db) async {
  final orders = await db.restaurantOrderDao.getOpenOrders();
  if (orders.isEmpty) return 0;
  return orders.map((o) => o.id).reduce((a, b) => a > b ? a : b);
}
