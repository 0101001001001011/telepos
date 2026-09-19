/// Аванс и сертификат **с экрана до базы** — на настоящем графе.
///
/// # Почему не подделка контроллера и не подделка кассы
///
/// Ловушка, измеренная задачей 18: проба экрана, подменяющая контроллер,
/// не касается настоящей логики — обе ветви предела там не выполнялись ни
/// разу, а вторая возвращала правдоподобное «сто процентов». Поэтому здесь
/// настоящий `PaymentScreen`, настоящий `PaymentNotifier`, настоящий
/// `LocalPaymentService` над настоящей базой drift. Подставлены только
/// экран продажи (снимок чека и номер рабочего места) и сеанс — ни то, ни
/// другое к зачётам отношения не имеет.
///
/// # Что утверждается
///
/// Не «суммы сошлись» (сходятся при любом порядке потолков), а то, что
/// экран **производит**:
///
/// 1. кассир видит остаток аванса и остаток бумажки **до ввода** — числами
///    кассы на экране;
/// 2. недоступный аванс погашен и называет причину нажатием;
/// 3. после «Оплатить» в базе: остаток бумажки (`balanceMillis`), сальдо
///    расчётного счёта покупателя, строки оплаты по `kindId` и номер
///    бумажки в `reference`.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/cash_drawer.dart';

import '../../../helpers/discount_authority.dart';

const _barcode = '4870001234567';
const _terminalId = 7;
const _posAccountId = 11;
const _customerMainAccountId = 14;
const _customerId = 5;
const _phone = '77015550000';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  late AppDatabase db;
  late LocalPaymentService payments;
  late CartView receipt;
  late ProviderContainer container;

  /// Касса: смена, товар по 500, счёт кассы, покупатель с внесённым
  /// авансом [advance] и бумажка C-500 на 500 с ПИНом 1234. Виды
  /// [enabled] включены — остальные выключены, как на новой кассе.
  Future<void> seed({
    required String advance,
    required List<int> enabled,
  }) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = Talker();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(_posAccountId),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: const Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: const Value(true),
            isSynced: const Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            name: 'Товар',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            sellingPrice: Value(d('500')),
          ),
        );
    for (final (id, type, value) in [
      (_posAccountId, AccountType.pos, '0'),
      (12, AccountType.customBank, '0'),
      (_customerMainAccountId, AccountType.agentMain, advance),
    ]) {
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
    await db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            localId: const Value(_customerId),
            name: const Value('Айгуль'),
            phone: Value(int.parse(_phone)),
            mainAccountId: const Value(_customerMainAccountId),
          ),
        );
    for (final id in enabled) {
      await db.paymentKindDao.put(
        SystemPaymentKinds.byId(id).copyWith(isActive: true),
      );
    }
    await LocalCertificateIssuer(
      db: db,
      logger: logger,
    ).issue(
      by: fullDiscountAuthority,
      number: 'C-500',
      nominal: d('500'),
      pin: '1234',
    );

    final cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    CartCommandMeta meta(CartView? v, int n) => CartCommandMeta(
      key: 'k$n',
      baseVersion: v?.version ?? 0,
      receiptNo: v?.receiptNo,
    );
    var view = await cart.start(
      terminalId: _terminalId,
      wholesale: false,
      meta: meta(null, 1),
    );
    view = await cart.addByBarcode(_terminalId, _barcode, meta(view, 2));
    receipt = await cart.setQuantity(
      _terminalId,
      view.lines.single.id,
      d('3'),
      meta(view, 3),
    );

    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      cardTerminal: (_, {required amountTiyn, required receiptNo}) async =>
          const CardCharge(outcome: CardChargeOutcome.notConfigured),
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  }

  Future<void> mount(WidgetTester tester) async {
    if (!isLoggerReady) installLogger(Talker());
    if (GetIt.I.isRegistered<PaymentService>()) {
      GetIt.I.unregister<PaymentService>();
    }
    GetIt.I.registerSingleton<PaymentService>(payments);
    container = ProviderContainer(
      overrides: [
        saleControllerProvider.overrideWith(
          () => MockSaleNotifier(
            SaleState(
              receiptNo: receipt.receiptNo,
              posId: receipt.posId,
              version: receipt.version,
            ),
          ),
        ),
        paymentAccountsProvider.overrideWith(
          (ref) async => const <PaymentAccount>[],
        ),
        appStateProvider.overrideWith(MockAppStateNotifier.new),
      ],
    );
    addTearDown(() async {
      container.dispose();
      if (GetIt.I.isRegistered<PaymentService>()) {
        GetIt.I.unregister<PaymentService>();
      }
      await tester.runAsync(db.close);
    });

    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PaymentScreen(amount: d('1500')),
        ),
        GoRoute(
          path: AppRoutes.sale,
          builder: (_, _) => const Scaffold(body: Text('продажа')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ru')],
          locale: const Locale('ru'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    // Экран сам зовёт `initialize` отложенным кадром, а касса отвечает вне
    // поддельных часов — дать обоим дойти.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  /// Дать базе ответить. drift отвечает вне поддельных часов теста, поэтому
  /// кадры перемежаются настоящим ожиданием, пока [until] не станет правдой.
  Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
      if (until != null && until()) return;
    }
  }

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data ?? '';

  Finder phoneField() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.prefixIcon is Icon &&
        (w.decoration!.prefixIcon! as Icon).icon == Icons.phone,
  );

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  testWidgets('кассир видит остатки ДО ввода, и в базу уходит ровно '
      'предпросмотренное', (tester) async {
    await tester.runAsync(
      () => seed(
        advance: '700',
        enabled: const [
          SystemPaymentKindIds.certificate,
          SystemPaymentKindIds.prepayment,
        ],
      ),
    );
    await mount(tester);

    // Покупатель не найден — аванс погашен и называет причину нажатием.
    expect(find.byKey(const Key('payment_prepayment_locked')), findsOneWidget);
    await tapKey(tester, const Key('payment_prepayment_panel'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('payment_prepayment_denied_reason')),
      findsOneWidget,
      reason: 'погашенный зачёт обязан называть причину, а не молчать',
    );

    // Покупатель найден — остаток аванса на экране ДО ввода суммы.
    await tester.enterText(phoneField(), _phone);
    await settle(
      tester,
      until: () =>
          find.byKey(const Key('payment_prepayment_balance')).evaluate().isNotEmpty,
    );
    expect(textOf(tester, const Key('payment_prepayment_balance')), '700');
    expect(
      find.byKey(const Key('payment_prepayment_applied')),
      findsNothing,
      reason: 'до решения кассира зачитывать нечего',
    );

    // Бумажка — остаток ДО гашения.
    await tester.enterText(
      find.byKey(const Key('payment_certificate_number')),
      'C-500',
    );
    await tester.enterText(
      find.byKey(const Key('payment_certificate_pin')),
      '1234',
    );
    await tapKey(tester, const Key('payment_certificate_present'));
    const paperBalance = Key('payment_certificate_balance_C-500');
    await settle(
      tester,
      until: () => find.byKey(paperBalance).evaluate().isNotEmpty,
    );
    expect(textOf(tester, paperBalance), contains('500'));
    expect(
      (await tester.runAsync(() => db.certificateDao.byNumber('C-500')))!
          .balance,
      d('500'),
      reason: 'показ остатка ничего не погасил',
    );

    // Кассир решает зачесть весь аванс: цепочка кладёт бумажку первой,
    // аванс вторым, остаток — деньгами.
    await tapKey(tester, const Key('payment_prepayment_all'));
    await tester.pump();
    expect(textOf(tester, const Key('payment_prepayment_applied')), contains('700'));
    final state = container.read(paymentControllerProvider);
    expect(state.offsets.certificates, [d('500')]);
    expect(state.offsets.prepayment, d('700'));
    expect(state.amountToPay, d('300'));

    container.read(paymentControllerProvider.notifier).setCashReceived(d('300'));
    await tester.pump();

    final pay = find.byKey(const Key('payment_complete'));
    final onPressed = tester.widget<ElevatedButton>(pay).onPressed;
    expect(onPressed, isNotNull, reason: '300 наличных покрывают остаток');
    onPressed!();
    await settle(
      tester,
      until: () =>
          container.read(paymentControllerProvider.notifier).lastOutcome !=
          null,
    );

    final outcome = container
        .read(paymentControllerProvider.notifier)
        .lastOutcome;
    expect(outcome, isNotNull, reason: 'оплата не дошла до кассы');

    final (paper, advanceLeft, rows) = (await tester.runAsync(
      () async => (
        await db.certificateDao.byNumber('C-500'),
        (await db.accountDao.findById(_customerMainAccountId))!.value,
        await db.paymentDao.findBySale(receipt.receiptNo!, receipt.posId),
      ),
    ))!;

    expect(paper!.balance, d('0'), reason: 'бумажка погашена на 500');
    expect(paper.status, CertificateStatus.redeemed);
    expect(advanceLeft, d('0'), reason: 'аванс зачтён на 700');

    final byKind = {for (final p in rows) p.kindId: p};
    expect(byKind[SystemPaymentKindIds.certificate]?.amount, d('500'));
    expect(byKind[SystemPaymentKindIds.certificate]?.reference, 'C-500');
    expect(byKind[SystemPaymentKindIds.prepayment]?.amount, d('700'));
    expect(byKind[SystemPaymentKindIds.cash]?.amount, d('300'));
  });

  testWidgets('вид «аванс» выключен — панель погашена словами кассы', (
    tester,
  ) async {
    await tester.runAsync(
      () => seed(
        advance: '700',
        enabled: const [SystemPaymentKindIds.certificate],
      ),
    );
    await mount(tester);

    await tester.enterText(phoneField(), _phone);
    await settle(
      tester,
      until: () =>
          container.read(paymentControllerProvider).prepaymentRefusal != null,
    );

    expect(
      container.read(paymentControllerProvider).prepaymentRefusal,
      'error.payment_kind_inactive',
    );
    expect(find.byKey(const Key('payment_prepayment_locked')), findsOneWidget);
    expect(find.byKey(const Key('payment_prepayment_balance')), findsNothing);
    await tapKey(tester, const Key('payment_prepayment_panel'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('payment_prepayment_denied_reason')),
      findsOneWidget,
    );
  });
}
