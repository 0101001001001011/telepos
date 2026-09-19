/// Оплата по QR **с экрана до базы** — на настоящем графе.
///
/// # Почему не подделка контроллера и не подделка кассы
///
/// Ловушка, измеренная задачей 18: проба экрана, подменяющая контроллер,
/// не касается настоящей логики. Здесь настоящий `PaymentScreen`,
/// настоящий `PaymentNotifier`, настоящий `LocalPaymentService` со стойкой
/// `QrPaymentDesk`, настоящий `HttpQrPaymentProvider` — и **эмулятор
/// провайдера на сокете**, подключённый адресом из базы кассы. Подставлены
/// только экран продажи (снимок чека и номер места) — к QR он отношения не
/// имеет.
///
/// # Что утверждается
///
/// 1. Кассир нажимает «Показать QR» и видит код; пока касса ждёт, «Оплатить»
///    погашена — даже с наличными, покрывающими чек.
/// 2. Оплаченное идёт в цепочку зачётов вторым звеном: предпросмотр
///    `offsets.qr`, остаток к оплате ноль.
/// 3. После «Оплатить» в базе — строка `kindId = qr` с `reference` = ключ
///    намерения и `providerCode`, намерение разобрано этим чеком.
/// 4. Отмена, разошедшаяся с оплатой, кладёт деньги в этот же чек.
/// 5. Провайдер не настроен — панель гаснет и называет причину нажатием.
library;

import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:http/io_client.dart';
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
import 'package:telepos/data/payment/qr_payment_desk.dart';
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
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/payment/qr_tender.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';

import '../../../emulators/sbp/emulator.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/cash_drawer.dart';

const _barcode = '4870001234567';
const _terminalId = 7;
const _posAccountId = 11;

void main() {
  Decimal d(String v) => Decimal.parse(v);

  late AppDatabase db;
  late SbpEmulator emulator;
  late LocalPaymentService payments;
  late CartView receipt;
  late ProviderContainer container;

  /// Касса: смена, товар по 500, чек на 1500, QR включён, провайдер —
  /// эмулятор по адресу (если [configured]).
  Future<void> seed({required bool configured}) async {
    emulator = SbpEmulator(echo: false);
    await emulator.start('127.0.0.1', 0);
    await emulator.startControl('127.0.0.1', 0);

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
    for (final (id, type) in [
      (_posAccountId, AccountType.pos),
      (12, AccountType.customBank),
    ]) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: Value(id),
              type: type,
              name: Value('Счёт $id'),
              value: Value(Decimal.zero),
              visibleToPos: const Value(true),
            ),
          );
    }
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(SystemPaymentKindIds.qr).copyWith(isActive: true),
    );
    if (configured) {
      await db.qrProviderConfigDao.save(
        QrProviderSettings(
          baseUrl: emulator.baseUrl,
          code: 'sbp_emul',
          apiKey: 'screen-key',
        ),
        at: DateTime.now(),
      );
    }

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
      qr: QrPaymentDesk(
        db: db,
        logger: logger,
        timeout: const Duration(seconds: 2),
        // Без удержания соединения: клиент, заведённый в поддельной зоне
        // связки тестов, оставлял таймер простоя на 15 секунд, и связка
        // объявляла пробу упавшей по «висящему таймеру» после того, как
        // деньги уже легли в чек (измерено первым прогоном).
        httpClient: () => IOClient(HttpClient()..idleTimeout = Duration.zero),
      ),
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
      await tester.runAsync(() async {
        await db.close();
        await emulator.stop();
      });
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
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  /// База и провайдер отвечают вне поддельных часов теста — кадры
  /// перемежаются настоящим ожиданием, пока [until] не станет правдой.
  Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
      if (until != null && until()) return;
    }
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  /// Дать клиенту HTTP закрыть соединение: с нулевым простоем он заводит
  /// таймер закрытия нулевой длины **после** ответа, и без ещё одного кадра
  /// связка назвала бы его висящим.
  Future<void> drainHttp(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  /// Нажать **настоящую** кнопку панели — её собственный `onPressed` — в
  /// настоящей зоне и дождаться [until].
  ///
  /// # Почему не `tester.tap`
  ///
  /// Нажатие связки выполняется в поддельной зоне, и всё, что оно
  /// запускает, живёт там же — включая HTTP-клиент стойки и его таймеры
  /// соединения. Измерено двумя прогонами: вопрос из другой зоны ждал
  /// ответа, который не приходил (`qr_timeout`), а таймер закрытия
  /// соединения, заведённый посреди кадра, связка объявляла висящим после
  /// того, как деньги уже легли в чек. Кнопка при этом та же: зовётся её
  /// `onPressed`, а не метод контроллера мимо неё.
  Future<void> pressReal(
    WidgetTester tester,
    VoidCallback? onPressed,
    bool Function() until,
  ) async {
    expect(onPressed, isNotNull, reason: 'кнопка погашена');
    await tester.runAsync(() async {
      onPressed!();
      for (var i = 0; i < 300 && !until(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
  }

  PaymentState read() => container.read(paymentControllerProvider);

  VoidCallback? payButton(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.byKey(const Key('payment_complete')))
      .onPressed;

  setUp(() {
    // Связка тестов подменяет HTTP-клиент заглушкой, отвечающей 400 на всё.
    // Эмулятор провайдера — настоящий сокет, и клиент к нему обязан быть
    // настоящим: иначе проба мерила бы заглушку связки, а не наш адаптер.
    HttpOverrides.global = null;
  });

  testWidgets('кассир показывает код, ждёт, и в чек уходят деньги телефона', (
    tester,
  ) async {
    await tester.runAsync(() => seed(configured: true));
    await mount(tester);

    expect(find.byKey(const Key('payment_qr_panel')), findsOneWidget);
    await pressReal(
      tester,
      tester
          .widget<ElevatedButton>(find.byKey(const Key('payment_qr_start')))
          .onPressed,
      () => read().qr != null,
    );

    final shown = read().qr;
    expect(shown?.phase, QrTenderPhase.waiting, reason: '${read().qrRefusal}');
    expect(shown!.amount, d('1500'), reason: 'сумма по умолчанию — остаток');
    expect(find.byKey(const Key('payment_qr_code')), findsOneWidget);
    expect(find.byKey(const Key('payment_qr_cancel')), findsOneWidget);

    // Наличные покрывают чек, но касса ждёт провайдера — «Оплатить» гаснет.
    container
        .read(paymentControllerProvider.notifier)
        .setCashReceived(d('1500'));
    await tester.pump();
    expect(read().amountCovered, isFalse);
    expect(payButton(tester), isNull);

    // Покупатель заплатил; экран спрашивает кассу. Вопрос зовётся в той же
    // зоне, что и нажатие «Показать QR»: HTTP-клиент стойки заведён там, и
    // вопрос из другой зоны ждал бы ответа, который туда не придёт
    // (измерено: первый прогон получил `qr_timeout` и фазу `waiting`).
    emulator.confirm(emulator.byKey[shown.intentKey]!);
    await tester.runAsync(
      () => container.read(paymentControllerProvider.notifier).pollQr(),
    );
    await tester.pump();

    expect(read().qr?.phase, QrTenderPhase.paid);
    expect(find.byKey(const Key('payment_qr_paid')), findsOneWidget);
    expect(read().offsets.qr, d('1500'), reason: 'QR встал в цепочку');
    expect(read().amountToPay, d('0'));

    container
        .read(paymentControllerProvider.notifier)
        .setCashReceived(Decimal.zero);
    await tester.pump();
    final onPressed = payButton(tester);
    expect(onPressed, isNotNull, reason: 'чек покрыт деньгами телефона');
    onPressed!();
    await settle(
      tester,
      until: () =>
          container.read(paymentControllerProvider.notifier).lastOutcome !=
          null,
    );

    final (rows, intent) = (await tester.runAsync(
      () async => (
        await db.paymentDao.findBySale(receipt.receiptNo!, receipt.posId),
        await db.paymentIntentDao.byKey(shown.intentKey),
      ),
    ))!;
    final qrRows = rows.where((p) => p.kindId == SystemPaymentKindIds.qr);
    expect(qrRows, hasLength(1));
    expect(qrRows.single.amount, d('1500'));
    expect(qrRows.single.reference, shown.intentKey);
    expect(qrRows.single.providerCode, 'sbp_emul');
    expect(
      rows
          .where((p) => p.kindId != SystemPaymentKindIds.qr)
          .fold(Decimal.zero, (s, p) => s + p.amount),
      Decimal.zero,
    );
    expect(intent!.settledReceiptNo, receipt.receiptNo);
    expect(intent.abandonedAt, isNull);
    expect(read().qr, isNull, reason: 'следующий чек без чужого намерения');
    await drainHttp(tester);
  });

  testWidgets('отмена разошлась с оплатой — деньги идут в этот же чек', (
    tester,
  ) async {
    await tester.runAsync(() => seed(configured: true));
    await mount(tester);

    await pressReal(
      tester,
      tester
          .widget<ElevatedButton>(find.byKey(const Key('payment_qr_start')))
          .onPressed,
      () => read().qr != null,
    );
    final shown = read().qr!;
    expect(shown.phase, QrTenderPhase.waiting, reason: '${read().qrRefusal}');

    // Покупатель подтвердил оплату ровно тогда, когда кассир нажал отмену.
    emulator.confirm(emulator.byKey[shown.intentKey]!);
    await pressReal(
      tester,
      tester
          .widget<OutlinedButton>(find.byKey(const Key('payment_qr_cancel')))
          .onPressed,
      () => read().qr?.phase != QrTenderPhase.waiting && !read().qrBusy,
    );

    expect(read().qr?.phase, QrTenderPhase.paidAfterGiveUp);
    expect(find.byKey(const Key('payment_qr_paid')), findsOneWidget);
    expect(read().offsets.qr, d('1500'));

    final onPressed = payButton(tester);
    expect(onPressed, isNotNull);
    onPressed!();
    await settle(
      tester,
      until: () =>
          container.read(paymentControllerProvider.notifier).lastOutcome !=
          null,
    );

    final intent = (await tester.runAsync(
      () => db.paymentIntentDao.byKey(shown.intentKey),
    ))!;
    expect(intent.abandonedAt, isNotNull);
    expect(intent.settledReceiptNo, receipt.receiptNo);
    await drainHttp(tester);
  });

  // Пункт 9 C (2026-09-15): панель узнавала «не настроено» только на первом
  // «Показать QR» — кассир набирал сумму ради отказа. Теперь — при открытии.
  testWidgets('провайдер не настроен — панель знает это при открытии, без нажатия',
      (tester) async {
    await tester.runAsync(() => seed(configured: false));
    await mount(tester);

    await settle(tester, until: () => read().qrRefusal != null);

    expect(read().qrRefusal, 'error.qr_not_configured');
    expect(find.byKey(const Key('payment_qr_locked')), findsOneWidget);
    expect(
      find.byKey(const Key('payment_qr_start')),
      findsNothing,
      reason: 'кнопки, ведущей к отказу, на погашенной панели нет',
    );
    expect(emulator.byId, isEmpty);
  });

  testWidgets('провайдер не настроен — панель гаснет и называет причину', (
    tester,
  ) async {
    await tester.runAsync(() => seed(configured: false));
    await mount(tester);

    // С 2026-09-15 панель гаснет при открытии — «Показать QR» на ней нет
    // (проба выше), и причину называет нажатие на саму панель.
    await settle(tester, until: () => read().qrRefusal != null);

    expect(read().qrRefusal, 'error.qr_not_configured');
    expect(find.byKey(const Key('payment_qr_locked')), findsOneWidget);
    await tapKey(tester, const Key('payment_qr_panel'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('payment_qr_denied_reason')), findsOneWidget);
    expect(emulator.byId, isEmpty);
  });
}
