library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/domain/refund/refund_receipt_printer.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/usecases/sale/can_sale_be_refunded_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';

import '../support/harness.dart';
import 'package:telepos/app/theme/app_theme.dart';

class _SeededSale {
  const _SeededSale({
    required this.receiptNo,
    required this.posId,
    required this.payAccountId,
    required this.agentAccountId,
    required this.agentOpeningBalance,
    required this.bankOpeningBalance,
    required this.total,
  });
  final int receiptNo;
  final int posId;
  final int payAccountId;
  final int agentAccountId;
  final Decimal agentOpeningBalance;
  final Decimal bankOpeningBalance;
  final Decimal total;
}

void main() {
  final h = E2eHarness();
  late int cashierId;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);

    final users = await h.db.select(h.db.users).get();
    cashierId = users.firstWhere((u) => u.name == E2eHarness.cashierName).id;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db
        .into(h.db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: cashierId,
            openTime: now,
            isOpened: true,
            isSynced: false,
          ),
        );
  });

  tearDownAll(() => h.tearDown());

  /// Свежая касса возврата на каждый тест — **не косметика, а условие того,
  /// что тесты вообще идут после первого.**
  ///
  /// `LocalRefundService` (задача 18) разводит команды очередью: хвост
  /// очереди — `Future`, созданный при предыдущей команде. Каждый
  /// `testWidgets` живёт в **своей** зоне с собственным планировщиком, и
  /// зона предыдущего теста после него мертва: `previous.then(...)`,
  /// подписанный из второго теста на будущее, созданное в первом,
  /// запланировал бы микрозадачу в мёртвой зоне и **не выполнился бы
  /// никогда**. Снаружи это выглядит так, будто экран возврата перестал
  /// отвечать: команда уходит, касса молчит, ошибки нет.
  ///
  /// Найдено задачей 20 при переносе экрана на контракт: до неё экран звал
  /// юзкейсы напрямую, очереди не было, и общего состояния между тестами
  /// тоже. На продукте этого не бывает — там зона одна на всю жизнь
  /// процесса, — поэтому чинится здесь, а не в сервисе.
  setUp(() {
    if (GetIt.I.isRegistered<RefundService>()) {
      GetIt.I.unregister<RefundService>();
    }
    // `registerLazySingleton`, а не `registerSingleton`: `setUp` выполняется
    // **вне** зоны `testWidgets`, и хвост очереди, созданный в нём, был бы
    // ровно так же чужим для тела теста, как хвост предыдущего теста. Ленивая
    // фабрика строит сервис при первом обращении — то есть уже внутри зоны
    // того теста, который им пользуется.
    GetIt.I.registerLazySingleton<RefundService>(
      () => LocalRefundService(
        db: h.db,
        logger: app_log.talker,
        initiation: GetIt.I<RefundInitiationUseCase>(),
        refunds: GetIt.I<RefundUseCase>(),
        canBeRefunded: GetIt.I<CanSaleBeRefundedUseCase>(),
        drawer: () async => true,
        printer: GetIt.I<RefundReceiptPrinter>(),
      ),
    );
  });

  Future<GoRouter> pumpRefundApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/sale',
          builder: (_, __) => const Scaffold(body: Center(child: Text('SALE'))),
        ),
        GoRoute(
          path: '/shift',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('SHIFT'))),
        ),
        GoRoute(
          path: '/refund',
          builder: (_, __) => const Scaffold(body: RefundScreen()),
        ),
      ],
    );

    await tester.pumpWidget(
      // Гасит очередь печати вместе с деревом — иначе таймер пробуждения,
      // заведённый после первой же печати, роняет тест «A Timer is still
      // pending». `E2eHarness.pumpApp` делает это сам; здесь дерево своё.
      PrintQueueLifetime(
        child: ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            // Тема приложения, как в `E2eHarness.pumpApp`. Здесь дерево своё, и
            // тема была пропущена: экран поднимался под материальной по
            // умолчанию, в которой нет расширения `AppSemanticColors`, и любой
            // виджет, спрашивающий у темы роль, падал на разыменовании.
            theme: AppTheme.light,
            routerConfig: router,
            supportedLocales: AppLocale.supportedLocales,
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return router;
  }

  Future<void> login(WidgetTester tester) async {
    final userTile = find.text(E2eHarness.cashierName);
    expect(
      userTile,
      findsWidgets,
      reason: 'seeded cashier must be offered on the login screen',
    );
    await tester.tap(userTile.first);
    await tester.pumpAndSettle();
    final noPinBtn = find.text('Войти без PIN');
    if (noPinBtn.evaluate().isNotEmpty) {
      await tester.tap(noPinBtn.first);
    } else {
      final enter = find.text('Войти');
      expect(enter, findsWidgets, reason: 'a login action must be present');
      await tester.tap(enter.first);
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<void> goToRefund(WidgetTester tester, GoRouter router) async {
    router.go('/refund');
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<void> loadReceiptViaUi(WidgetTester tester, int receiptNo) async {
    final loadBtn = find.text('Загрузить чек');
    expect(
      loadBtn,
      findsWidgets,
      reason: 'Refund screen must expose a "load receipt" action',
    );
    await tester.tap(loadBtn.first);
    await tester.pumpAndSettle();

    expect(
      find.text('Поиск чека'),
      findsOneWidget,
      reason: 'tapping load-receipt must open the receipt input dialog',
    );

    for (final ch in '$receiptNo'.split('')) {
      final digit = find.widgetWithText(ElevatedButton, ch);
      expect(digit, findsWidgets, reason: 'NumPad must expose a "$ch" key');
      await tester.tap(digit.first);
      await tester.pump();
    }
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<_SeededSale> seedCardSaleWithAgent({
    required int receiptNo,
    int posId = 1,
  }) async {
    final db = h.db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final bankAccounts = await db.accountDao.findByType(AccountType.customBank);
    expect(
      bankAccounts,
      isNotEmpty,
      reason: 'harness should seed a bank/acquiring account',
    );
    final bankAccId = bankAccounts.first.id;
    final bankOpening = d('10000');
    await db.accountDao.updateBalance(bankAccId, bankOpening);

    final agentOpening = d('2000');
    final agentAccId = await db.accountDao.insertAccount(
      AccountsCompanion(
        id: drift.Value(await db.accountDao.getNextId()),
        type: const drift.Value(AccountType.agentMain),
        name: const drift.Value('Долг клиента'),
        value: drift.Value(agentOpening),
        visibleToPos: const drift.Value(false),
        updateTime: drift.Value(now),
      ),
    );
    final agentLocalId = await db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            type: const drift.Value(1),
            name: const drift.Value('ИП Клиентов'),
            mainAccountId: drift.Value(agentAccId),
            isDeleted: const drift.Value(false),
            editTime: drift.Value(now),
          ),
        );

    const milkUcode = 1001;
    const breadUcode = 1002;
    final milkPrice = d('450');
    final breadPrice = d('150');
    final total = milkPrice + breadPrice;

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: cashierId,
            amount: total,
            time: now,
            customerLocalId: drift.Value(agentLocalId),
            state: const drift.Value(4),
            isOfd: const drift.Value(false),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: drift.Value(receiptNo),
            posId: drift.Value(posId),
            ucode: milkUcode,
            quantity: d('1'),
            price: milkPrice,
            priceBefore: milkPrice,
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: drift.Value(receiptNo),
            posId: drift.Value(posId),
            ucode: breadUcode,
            quantity: d('1'),
            price: breadPrice,
            priceBefore: breadPrice,
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: cashierId,
            receiptNo: drift.Value(receiptNo),
            posId: drift.Value(posId),
            payeeAccountId: bankAccId,
            amount: total,
            time: now,
            state: const drift.Value(4),
          ),
        );

    return _SeededSale(
      receiptNo: receiptNo,
      posId: posId,
      payAccountId: bankAccId,
      agentAccountId: agentAccId,
      agentOpeningBalance: agentOpening,
      bankOpeningBalance: bankOpening,
      total: total,
    );
  }

  testWidgets('full refund reverses card payment, account & agent balance', (
    tester,
  ) async {
    final sale = await seedCardSaleWithAgent(receiptNo: 5001);

    final router = await pumpRefundApp(tester);
    await login(tester);
    await goToRefund(tester, router);
    await loadReceiptViaUi(tester, sale.receiptNo);

    expect(find.text('Молоко 1л'), findsWidgets);
    expect(find.text('Хлеб белый'), findsWidgets);
    expect(
      find.text('${sale.total}'),
      findsWidgets,
      reason: 'refund total panel must show the full sale total',
    );

    await tester.tap(find.text('ВОЗВРАТ').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Подтвердите возврат'),
      findsOneWidget,
      reason: 'refund must require an explicit confirmation',
    );
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(
      find.text('Возврат успешно проведён'),
      findsWidgets,
      reason: 'a successful refund must surface a success message',
    );

    final db = h.db;

    final refund = await db.refundDao.findBySale(sale.receiptNo, sale.posId);
    expect(
      refund,
      isNotNull,
      reason: 'a refund must be persisted for the sale',
    );
    expect(refund!.state, 1, reason: 'refund state must be PENDING_SYNC (1)');
    expect(
      refund.amount,
      sale.total,
      reason: 'refund amount must equal the full sale total (Decimal-exact)',
    );

    final refProducts = await db.refundDao.findProductsByRefund(refund.localId);
    expect(
      refProducts.length,
      2,
      reason: 'full refund must persist both product lines',
    );

    final refundPayments = await db.paymentDao.findByRefund(refund.localId);
    expect(
      refundPayments.length,
      1,
      reason: 'one reversal payment expected for a single-payment sale',
    );
    final rp = refundPayments.first;
    expect(
      rp.payeeAccountId,
      sale.payAccountId,
      reason: 'reversal must hit the original CARD account, not cash',
    );
    expect(
      rp.amount,
      -sale.total,
      reason: 'reversal payment must be the negative of the refund total',
    );

    final reversalAccount = await db.accountDao.findById(rp.payeeAccountId);
    expect(reversalAccount, isNotNull);
    expect(
      reversalAccount!.type,
      AccountType.customBank,
      reason:
          'card sale reversal must land on a CUSTOM_BANK account '
          '(payment-type guard: card refund, not cash)',
    );

    expect(
      reversalAccount.value,
      sale.bankOpeningBalance - sale.total,
      reason: 'bank account balance must decrease by the refund total',
    );

    // **Прежний сторож #16 требовал порчи денег** (задача 10).
    //
    // Он читался как «долг покупателя уменьшается на сумму возврата» и
    // краснел бы, если бы это перестало быть так. Но чек здесь оплачен
    // картой **полностью**, и возврат уже вернул покупателю все 600
    // сторно на банковский счёт. Двинуть после этого ещё и его расчётный
    // счёт значило бы списать с него те же 600 второй раз: касса и деньги
    // отдала, и долг записала.
    //
    // Правило теперь зеркально продаже: расчётный счёт покупателя двигает
    // **то, что не вернулось деньгами** (`amount − Σсторно`). Здесь это
    // ноль, и остаток обязан остаться нетронутым.
    final agentAccount = await db.accountDao.findById(sale.agentAccountId);
    expect(agentAccount, isNotNull);
    expect(
      agentAccount!.value,
      sale.agentOpeningBalance,
      reason:
          'чек оплачен полностью и полностью возвращён деньгами — '
          'долговой части у этого возврата нет',
    );
  });

  testWidgets('partial refund returns only the selected line, money exact', (
    tester,
  ) async {
    final sale = await seedCardSaleWithAgent(receiptNo: 5002);

    final router = await pumpRefundApp(tester);
    await login(tester);
    await goToRefund(tester, router);
    await loadReceiptViaUi(tester, sale.receiptNo);

    final checkboxes = find.byType(Checkbox);
    expect(
      checkboxes,
      findsWidgets,
      reason: 'refund table must render per-line checkboxes',
    );
    expect(checkboxes.evaluate().length, greaterThanOrEqualTo(3));
    await tester.tap(checkboxes.at(2));
    await tester.pumpAndSettle();

    final expectedPartial = d('450');
    expect(
      find.text('$expectedPartial'),
      findsWidgets,
      reason: 'after deselecting bread, total must be 450',
    );

    await tester.tap(find.text('ВОЗВРАТ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final db = h.db;
    final refund = await db.refundDao.findBySale(sale.receiptNo, sale.posId);
    expect(refund, isNotNull);
    expect(
      refund!.amount,
      expectedPartial,
      reason: 'partial refund amount must be 450 (milk only)',
    );

    final refProducts = await db.refundDao.findProductsByRefund(refund.localId);
    expect(
      refProducts.length,
      1,
      reason: 'partial refund must persist only the selected line',
    );
    expect(
      refProducts.first.ucode,
      1001,
      reason: 'the remaining refunded product must be Молоко (ucode 1001)',
    );

    final refundPayments = await db.paymentDao.findByRefund(refund.localId);
    expect(refundPayments.single.amount, -expectedPartial);

    // Та же правка знака, что и у полного возврата: 450 вернулись
    // сторно на банковский счёт, значит долговой части нет и здесь.
    final agentAccount = await db.accountDao.findById(sale.agentAccountId);
    expect(
      agentAccount!.value,
      sale.agentOpeningBalance,
      reason: 'частичный возврат вернулся деньгами целиком — долг не тронут',
    );
  });

  testWidgets('empty state shown before any receipt is loaded', (tester) async {
    final router = await pumpRefundApp(tester);
    await login(tester);
    await goToRefund(tester, router);

    expect(
      find.textContaining('Нет товаров'),
      findsWidgets,
      reason: 'refund screen must show a real empty-state, not a blank table',
    );

    final refundsBefore = await h.db.select(h.db.refunds).get();
    await tester.tap(find.text('ВОЗВРАТ').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Подтвердите возврат'),
      findsNothing,
      reason: 'refund with no items must not open the confirm dialog',
    );
    final refundsAfter = await h.db.select(h.db.refunds).get();
    expect(
      refundsAfter.length,
      refundsBefore.length,
      reason: 'no refund may be created from the empty state',
    );
  });

  testWidgets(
    'loading a non-existent receipt does not crash or fake a refund',
    (tester) async {
      final router = await pumpRefundApp(tester);
      await login(tester);
      await goToRefund(tester, router);

      final refundsBefore = await h.db.select(h.db.refunds).get();
      await loadReceiptViaUi(tester, 999999);

      expect(find.text('Молоко 1л'), findsNothing);
      expect(find.textContaining('Нет товаров'), findsWidgets);

      await tester.tap(find.text('ВОЗВРАТ').first);
      await tester.pumpAndSettle();
      expect(find.text('Подтвердите возврат'), findsNothing);
      final refundsAfter = await h.db.select(h.db.refunds).get();
      expect(
        refundsAfter.length,
        refundsBefore.length,
        reason: 'a missing receipt must never produce a refund',
      );

      expect(
        find.textContaining('error.receipt_not_found'),
        findsNothing,
        reason: 'the raw error code must not be shown to the user',
      );
      expect(
        find.text('Чек не найден'),
        findsWidgets,
        reason: 'receipt-not-found error must be surfaced honestly in the UI',
      );
    },
  );
}
