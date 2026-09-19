/// Браузерная половина оплаты — задача 14, круг правки 1.
///
/// **Заведён потому, что «экран один и тот же на обеих сборках» было
/// утверждением, а не измерением:** `WtPaymentService` не покрывал ни один
/// тест. Здесь обе половины провода соединены торцами тем же стендом, что и
/// `wt_till_speaks_first_test.dart`: настоящая база drift, настоящая
/// корзина, настоящая подготовка чека, настоящий `SaleUseCaseImpl`,
/// настоящие `TillOperations` и `TillWire` — и настоящий
/// `WtPaymentService` поверх настоящего `WtDispatcher`. Подставлен ровно
/// один QUIC (нативной библиотеки под `flutter test` нет) и драйвер
/// платёжного терминала (открывает сокет к железу).
///
/// Проверяется не «поля переложились», а три вещи, которых кассовый набор
/// не видит **по построению**:
///
/// 1. сдача, посчитанная кассой, доезжает до браузера через настоящий кадр;
/// 2. отказ кассы доезжает **кодом**, а не текстом;
/// 3. право `op.sellDebt` отказывает **браузеру**, а не только сторожу в
///    отдельно взятом тесте.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_payment_service.dart';

import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';
import '../helpers/cash_drawer.dart';

import '../helpers/discount_authority.dart';

const _barcode = '4870001234567';

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late LocalCartService cart;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  /// Включить на кассе продажу в кредит — тумблер мастера настройки.
  Future<void> allowDebtSales() async {
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(sellInDebt: Value(true)),
    );
  }

  /// Поднять обе половины провода с сеансом, несущим [permissions].
  Future<WtPaymentService> boot(Set<String> permissions) async {
    final sessions = SessionRegistry();
    final logger = Talker();
    final invites = PairingInvites();
    cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    final operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      invites: invites,
      payments: LocalPaymentService(
        db: db,
        checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
        sale: SaleUseCaseImpl(db: db, logger: logger),
        logger: logger,
        // Порт обязателен (задача 3). Проба про оплату по проводу, а не про
        // фискализацию: узла здесь нет, и это сказано, а не забыто.
        fiscal: const RefusingFiscalService(),
        drawer: drawerOpens,
      ),
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: permissions,
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 1,
    );
    wire = TillWire(
      loop,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      runHandlers: operations.runHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
    )..start();
    final browser = WtDispatcher(loop, tokens: FakeTokens(session.token));

    // Рабочее место берётся кассой **из сеанса** — сессия обязана сначала
    // назвать себя тем же путём, каким это делает настоящая вкладка. Была
    // `terminals.selfEnsure`; задача 19 вырезала оттуда запись в
    // `_sessionTerminals` (она сажала любую сессию на строку самой кассы,
    // без кода и без секрета), и путь вкладки — `terminals.register`.
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    return WtPaymentService(browser);
  }

  /// Чек на 1000: две штуки по 500, набранные **на кассе**.
  Future<CartView> receipt() async {
    var view = await cart.start(terminalId: 1, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(1, _barcode, mv(view, 2));
    return cart.setQuantity(1, view.lines.single.id, d('2'), mv(view, 3));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(11),
            cashBoxName: Value('Касса-1'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(11),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
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
            quantity: Value(Decimal.fromInt(100)),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            sellingPrice: Value(Decimal.fromInt(500)),
          ),
        );
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  test(
    'сдача считается кассой и доезжает до браузера настоящим кадром',
    () async {
      final payments = await boot(const {PermissionKeys.navSale});
      final view = await receipt();

      final outcome = await payments.complete(
        1,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('5000'),
          claimedChange: d('9999'), // подделка вкладки
        ),
        mv(view, 9),
      );

      expect(outcome.amount, d('1000'));
      expect(outcome.change, d('4000'));
      // И в базе кассы: браузер мог бы показать одно, а чек унести другое.
      final sale = await db.saleDao.findByKey(view.receiptNo!, 1);
      expect(sale!.change, d('4000'));
      expect(sale.state, isNot(0));
    },
  );

  test('аванс и сертификат: остаток доезжает до браузера ДО гашения, и '
      'гасится ровно поданное', () async {
    final payments = await boot(const {PermissionKeys.navSale});
    for (final id in const [
      SystemPaymentKindIds.certificate,
      SystemPaymentKindIds.prepayment,
    ]) {
      await db.paymentKindDao.put(
        SystemPaymentKinds.byId(id).copyWith(isActive: true),
      );
    }
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(14),
            type: AccountType.agentMain,
            name: const Value('Расчёты с Айгуль'),
            value: Value(d('700')),
            visibleToPos: const Value(false),
          ),
        );
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(5),
            name: Value('Айгуль'),
            phone: Value(77015550000),
            mainAccountId: Value(14),
          ),
        );
    await LocalCertificateIssuer(
      db: db,
      logger: Talker(),
    ).issue(
      by: fullDiscountAuthority,
      number: 'C-500',
      nominal: d('500'),
      pin: '1234',
    );

    // Остаток — до ввода, через настоящий кадр.
    expect(await payments.prepaymentBalance(5), d('700'));
    final paper = await payments.findCertificate('C-500', pin: '1234');
    expect(paper.balance, d('500'));
    expect(paper.pinHash, isNull, reason: 'хэш ПИНа в браузер не едет');

    // Без ПИНа остатка не отдают, и отказ доезжает кодом — «нужен ПИН»
    // (2026-09-15), а не «не подошёл»: кассир не набирал ничего.
    await expectLater(
      payments.findCertificate('C-500'),
      throwsA(
        isA<WtProtocolError>().having(
          (e) => e.code,
          'code',
          'certificate_pin_required',
        ),
      ),
    );
    // Не тот ПИН — по-прежнему своим кодом.
    await expectLater(
      payments.findCertificate('C-500', pin: '0000'),
      throwsA(
        isA<WtProtocolError>().having(
          (e) => e.code,
          'code',
          'certificate_pin_wrong',
        ),
      ),
    );

    // Вопрос ничего не списал.
    expect((await db.certificateDao.byNumber('C-500'))!.balance, d('500'));
    expect((await db.accountDao.findById(14))!.value, d('700'));

    // Оплата теми же полями через провод: чек 1000 = бумажка 500 +
    // аванс 500, наличных ноль.
    final view = await receipt();
    final outcome = await payments.complete(
      1,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: 5,
        prepaymentUsed: d('500'),
        certificates: const [CertificateTender(number: 'C-500', pin: '1234')],
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(outcome.paid, d('1000'));
    final spent = await db.certificateDao.byNumber('C-500');
    expect(spent!.balance, d('0'), reason: 'бумажка погашена целиком');
    expect(spent.status, CertificateStatus.redeemed);
    expect(
      (await db.accountDao.findById(14))!.value,
      d('200'),
      reason: 'аванс зачтён на 500 из 700, 200 остались покупателю',
    );
    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(
      {for (final p in rows) p.kindId: p.amount},
      containsPair(SystemPaymentKindIds.certificate, d('500')),
    );
    expect(
      {for (final p in rows) p.kindId: p.amount},
      containsPair(SystemPaymentKindIds.prepayment, d('500')),
    );
  });

  test('выключенный вид сертификата называется при вопросе, а не при оплате',
      () async {
    final payments = await boot(const {PermissionKeys.navSale});
    await LocalCertificateIssuer(
      db: db,
      logger: Talker(),
    ).issue(by: fullDiscountAuthority, number: 'C-1', nominal: d('100'));

    await expectLater(
      payments.findCertificate('C-1'),
      throwsA(
        isA<WtProtocolError>().having(
          (e) => e.code,
          'code',
          payKindInactiveCode,
        ),
      ),
    );
  });

  test('счета и клиент лояльности доезжают через провод', () async {
    final payments = await boot(const {PermissionKeys.navSale});

    final accounts = await payments.accounts();
    expect(accounts.map((a) => a.id), [11]);
    expect(accounts.single.isDefault, isTrue);

    expect(await payments.findLoyalty('77019999999'), isNull);
  });

  test('отказ кассы доезжает кодом, а не текстом', () async {
    final payments = await boot(const {PermissionKeys.navSale});
    final view = await receipt();

    await expectLater(
      payments.complete(
        1,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1')),
        mv(view, 9),
      ),
      throwsA(
        isA<WtProtocolError>().having(
          (e) => e.code,
          'code',
          payInsufficientCode,
        ),
      ),
    );
    expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
  });

  test('оплата в долг без op.sellDebt отвергается кассой', () async {
    // Тест брифа задачи 14 в его настоящем виде: не сторож в отдельно
    // взятом тесте, а **браузер, получивший отказ от кассы**.
    final payments = await boot(const {PermissionKeys.navSale});
    final view = await receipt();

    await expectLater(
      payments.complete(
        1,
        PaymentRequest(type: PaymentType.debt, customerId: 5),
        mv(view, 9),
      ),
      throwsA(
        isA<WtProtocolError>().having((e) => e.code, 'code', 'forbidden'),
      ),
    );
    expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
  });

  test('право есть, а кредита на кассе нет — отказ кассы, не сторожа', () async {
    // Задача 16: тумблер кассы и право кассира — разные вещи. Право у
    // этого сеанса есть, и сторож кадр пропускает; отказывает **касса**,
    // потому что `ThisPosEntries.sellInDebt` выключен. Спрятанная кнопка
    // тут ни при чём — кадр собран мимо экрана вовсе.
    final payments = await boot(const {
      PermissionKeys.navSale,
      PermissionKeys.opSellDebt,
    });
    final view = await receipt();

    await expectLater(
      payments.complete(
        1,
        PaymentRequest(type: PaymentType.debt, customerId: 5),
        mv(view, 9),
      ),
      throwsA(
        isA<WtProtocolError>().having(
          (e) => e.code,
          'code',
          payDebtNotSoldHereCode,
        ),
      ),
    );
    expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
  });

  test('тумблер кассы доезжает до браузера ответом, а не догадкой', () async {
    // Экрану он нужен затем же, зачем набор видов рабочего места: чтобы
    // кассир не выбирал покупателя ради отказа последним нажатием.
    final payments = await boot(const {PermissionKeys.navSale});
    expect(await payments.sellsInDebt(), isFalse);

    await allowDebtSales();
    expect(await payments.sellsInDebt(), isTrue);
  });

  test(
    'с правом долг доходит до кассы и упирается уже в её проверку',
    () async {
      // Страховка от вырождения: если бы кадр не доходил вовсе, отказ выше
      // ничего не доказывал бы про право. С правом отказ **другой** — от
      // самой оплаты, а не от сторожа.
      final payments = await boot(const {
        PermissionKeys.navSale,
        PermissionKeys.opSellDebt,
      });
      // Тумблер кассы включён: без него касса ответила бы про кредит, а
      // проба утверждает про **безымянного должника**.
      await allowDebtSales();
      final view = await receipt();

      await expectLater(
        payments.complete(
          1,
          PaymentRequest(type: PaymentType.debt),
          mv(view, 9),
        ),
        throwsA(
          isA<WtProtocolError>().having(
            (e) => e.code,
            'code',
            payDebtorRequiredCode,
          ),
        ),
      );
    },
  );

  test('имя рабочего места в кадр не кладётся', () async {
    // Касса отвергает кадр, назвавший рабочее место (`_payTerminal`).
    // Значит если бы браузерная реализация его положила, **все** её
    // операции отвечали бы `bad_request` — а они отвечают по существу
    // (пробы выше). Здесь то же самое сказано прямо: довод `terminalId`
    // умышленно взят чужой, и это ничего не меняет.
    final payments = await boot(const {PermissionKeys.navSale});
    final view = await receipt();

    final outcome = await payments.complete(
      99, // не терминал сеанса
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );

    expect(outcome.paid, d('1000'));
  });
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}
