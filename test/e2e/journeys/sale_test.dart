library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/l10n/app_localizations.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

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
  });

  Future<void> setDesktopSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpAppAtSale(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();

    await tester.pumpWidget(
      // Гасит очередь печати вместе с деревом — иначе таймер пробуждения,
      // заведённый после первой же печати, роняет тест «A Timer is still
      // pending». `E2eHarness.pumpApp` делает это сам; здесь дерево своё.
      PrintQueueLifetime(
        child: ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
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
    await tester.pump();
    await settle(tester, frames: 20);
    router.go('/sale');
    await settle(tester, frames: 20);

    await pumpUntilFound(tester, find.text('ОПЛАТИТЬ'));
    expect(
      find.text('ОПЛАТИТЬ'),
      findsWidgets,
      reason: 'Sale screen must render with a pay button',
    );
  }

  Future<void> addProductBySearch(
    WidgetTester tester,
    String query,
    String displayName,
  ) async {
    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, query);
    await settle(tester, frames: 12);
    final result = find.text(displayName);
    await pumpUntilFound(tester, result);
    expect(
      result,
      findsWidgets,
      reason: 'Search for "$query" must surface product "$displayName"',
    );
    await tester.tap(result.first);
    await settle(tester);
  }

  Future<void> openPayment(WidgetTester tester) async {
    final payBtn = find.text('ОПЛАТИТЬ');
    expect(payBtn, findsWidgets, reason: 'Pay button must be present on sale');
    await tester.tap(payBtn.first);
    await settle(tester);
    await pumpUntilFound(tester, find.text('Оплата'));
    expect(
      find.text('Оплата'),
      findsWidgets,
      reason: 'Payment screen must open',
    );
  }

  group('E2E Sale journey', () {
    testWidgets('CASH sale: exact total, completes, shift auto-opens, '
        'recorded to POS account', (tester) async {
      await setDesktopSurface(tester);
      await pumpAppAtSale(tester);

      final db = GetIt.I<AppDatabase>();

      await addProductBySearch(tester, 'Молоко', 'Молоко 1л');

      expect(
        find.text('450'),
        findsWidgets,
        reason: 'Sale total must show the exact item price 450',
      );

      final openShift = await db.shiftDao.findOpenedShift();
      expect(
        openShift,
        isNotNull,
        reason: 'Shift must auto-open on the first sale',
      );

      await openPayment(tester);

      final cashField = find.byType(TextField);
      expect(
        cashField,
        findsWidgets,
        reason: 'Cash received input must be present for cash payment',
      );
      await tester.enterText(cashField.first, '450');
      await settle(tester);

      final confirm = find.widgetWithText(ElevatedButton, 'ОПЛАТИТЬ');
      expect(confirm, findsWidgets, reason: 'Confirm-pay button must exist');
      await tester.tap(confirm.first);
      await settle(tester);
      await pumpUntilFound(tester, find.text('Оплата успешна'));

      expect(
        find.text('Оплата успешна'),
        findsWidgets,
        reason: 'Successful cash payment must show success snackbar',
      );

      final completed = await db.saleDao.findByState(1);
      expect(completed.length, 1, reason: 'Exactly one completed sale');
      final sale = completed.first;
      expect(
        sale.amount,
        d('450'),
        reason: 'Recorded sale amount must be exactly 450 (Decimal)',
      );

      final payments = await db.paymentDao.findBySale(
        sale.receiptNo,
        sale.posId,
      );
      expect(payments.length, 1, reason: 'One payment line for cash sale');
      expect(
        payments.first.amount,
        d('450'),
        reason: 'Cash payment amount must be exactly 450',
      );
      final payAcc = await db.accountDao.findById(
        payments.first.payeeAccountId,
      );
      expect(payAcc, isNotNull);
      expect(
        payAcc!.type,
        AccountType.pos,
        reason: 'Cash payment must hit the POS (cash) account',
      );
    });

    testWidgets('CARD sale WITHOUT terminal: offline fallback records to bank '
        'account and completes (guard #3)', (tester) async {
      await setDesktopSurface(tester);
      await pumpAppAtSale(tester);

      final db = GetIt.I<AppDatabase>();

      await addProductBySearch(tester, 'Хлеб', 'Хлеб белый');
      expect(
        find.text('150'),
        findsWidgets,
        reason: 'Sale total must show exact item price 150',
      );

      await openPayment(tester);

      final cardType = find.text('Безналичная');
      expect(cardType, findsWidgets, reason: 'Card payment type must exist');
      await tester.tap(cardType.first);
      await settle(tester);

      final confirm = find.widgetWithText(ElevatedButton, 'ОПЛАТИТЬ');
      expect(confirm, findsWidgets);
      await tester.tap(confirm.first);
      await settle(tester);
      await pumpUntilFound(tester, find.text('Оплата успешна'));

      expect(
        find.text('Оплата успешна'),
        findsWidgets,
        reason:
            'Card sale must complete via offline fallback without a '
            'terminal configured (guard #3)',
      );

      final completed = await db.saleDao.findByState(1);
      expect(completed.length, 1, reason: 'Exactly one completed card sale');
      final sale = completed.first;
      expect(
        sale.amount,
        d('150'),
        reason: 'Recorded card sale amount must be exactly 150 (Decimal)',
      );

      final payments = await db.paymentDao.findBySale(
        sale.receiptNo,
        sale.posId,
      );
      expect(payments.length, 1, reason: 'One payment line for card sale');
      expect(
        payments.first.amount,
        d('150'),
        reason: 'Card payment amount must be exactly 150',
      );
      final payAcc = await db.accountDao.findById(
        payments.first.payeeAccountId,
      );
      expect(payAcc, isNotNull);
      expect(
        payAcc!.type,
        AccountType.customBank,
        reason:
            'Card payment must hit the bank (acquiring) account, '
            'not the cash POS account',
      );
      expect(
        payments.first.approvalCode,
        isNull,
        reason: 'No terminal configured → manual card path, no approval code',
      );
    });

    testWidgets('CASH change: exact change computed for overpayment', (
      tester,
    ) async {
      await setDesktopSurface(tester);
      await pumpAppAtSale(tester);

      final db = GetIt.I<AppDatabase>();

      await addProductBySearch(tester, 'Молоко', 'Молоко 1л');
      await addProductBySearch(tester, 'Сахар', 'Сахар 1кг');
      expect(
        find.text('730'),
        findsWidgets,
        reason: 'Multi-item total must be exact 450 + 280 = 730',
      );

      await openPayment(tester);

      final cashField = find.byType(TextField);
      await tester.enterText(cashField.first, '1000');
      await settle(tester);
      expect(
        find.text('270'),
        findsWidgets,
        reason: 'Change must be exactly 1000 - 730 = 270',
      );

      final confirm = find.widgetWithText(ElevatedButton, 'ОПЛАТИТЬ');
      await tester.tap(confirm.first);
      await settle(tester);
      await pumpUntilFound(tester, find.text('Оплата успешна'));

      expect(find.text('Оплата успешна'), findsWidgets);

      final completed = await db.saleDao.findByState(1);
      expect(completed.length, 1);
      expect(
        completed.first.amount,
        d('730'),
        reason: 'Sale amount must be exactly 730 regardless of overpayment',
      );
    });
  });
}
