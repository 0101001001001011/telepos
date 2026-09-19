/// Скидка, введённая **с браузерного терминала**, доезжает до оператора
/// фискальных данных — и чек сходится с оплатой до копейки.
///
/// # Чем это отличается от соседних проб
///
/// `test/emulators/webkassa/live_till_test.dart` фискализует скидку, **положенную
/// в базу руками** («строки кладутся ровно так, как их оставляет касса»), и
/// зовёт `FiscalService` напрямую. `fiscal_envelope_balance_test.dart` и
/// `fiscal_kopeck_test.dart` ведут корзину кассы без провода. Ни одна не
/// проходит путь терминала: `WtCartService.setDiscountAmount` → кадр
/// `sale.setDiscountAmount` → сторож `op.sellDiscount` → `LocalCartService` →
/// `WtPaymentService.complete` → `LocalPaymentService` → `FiscalServiceImpl` →
/// `WebKassaProvider` → настоящий сокет эмулятора. Здесь подставлен только
/// QUIC (`Loopback`).
///
/// # Чего не доказывает
///
/// Что настоящая WebKassa ответила бы так же — см. докстринг `emulator.dart`.
/// Эмулятор здесь на порту из 18230–18239: соседние дорожки держат свои.
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart'
    hide FiscalQueueEntry, Terminal;
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_cart_service.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_payment_service.dart';

import '../data/transport/till_operations_stubs.dart';
import '../emulators/webkassa/emulator.dart';
import '../emulators/webkassa/state.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';
import '../helpers/cash_drawer.dart';

const _barcode = '4870001234567';
const _cashbox = 'SWK00000001';
const _regNumber = '000000000001';
const _posAccountId = 11;

class _StaticSettings implements FiscalSettingsSource {
  _StaticSettings(this._settings);
  final FiscalSettings _settings;
  @override
  Future<FiscalSettings> load() async => _settings;
}

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late WebKassaEmulator emulator;
  late EmulatorState emulState;
  late WtCartService cart;
  late WtPaymentService payments;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  /// Порт эмулятора — из диапазона дорожки, первый свободный.
  Future<void> startEmulator() async {
    for (var port = 18230; port < 18240; port++) {
      try {
        await emulator.start('127.0.0.1', port);
        return;
      } on SocketException {
        continue;
      }
    }
    fail('порты 18230–18239 заняты все');
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(_posAccountId),
            cashBoxName: Value('Касса 1'),
            companyName: Value('ТОО Ромашка'),
            // Тумблер «продажа со скидкой» — без него касса откажет
            // `denied_policy`, и проба мерила бы отказ, а не конверт.
            sellInDiscount: Value(true),
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
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_posAccountId),
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
            name: 'Сыр',
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
            sellingPrice: Value(d('100')),
          ),
        );

    emulState = EmulatorState(
      cashboxes: {
        _cashbox: EmulatedCashbox(
          uniqueNumber: _cashbox,
          registrationNumber: _regNumber,
          now: DateTime.now(),
        ),
      },
      login: 'emul',
      password: 'emul',
      tokenTtl: const Duration(hours: 1),
      vat: VatMode.off,
    );
    emulator = WebKassaEmulator(state: emulState, echo: false);
    await startEmulator();

    final logger = Talker(settings: TalkerSettings(enabled: false));
    final settings = FiscalSettings(
      operatorType: FiscalOperatorType.webkassa,
      testMode: true,
      baseUrl: emulator.baseUri.toString(),
      login: 'emul',
      password: 'emul',
      apiKey: 'emulated-integrator-key',
      cashboxUniqueNumber: _cashbox,
      registrationNumber: _regNumber,
    );
    final store = DriftFiscalQueueStore(db);
    final registry = FiscalProviderRegistry()
      ..register(
        FiscalOperatorType.webkassa,
        (s) => OfflineQueueingProvider(
          inner: WebKassaProvider(settings: s, logger: logger),
          store: store,
          isReachable: () async => true,
        ),
      );
    final local = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
      discountPolicy: LocalDiscountPolicy(db),
    );

    final sessions = SessionRegistry();
    final invites = PairingInvites();
    final operations = TillOperations(
      db: db,
      bootstrap: NoopBootstrap(),
      setup: NoopSetupRepository(),
      terminals: LocalTerminalRepository(db),
      invites: invites,
      deviceBindings: NoopDeviceBindingRepository(),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      cart: local,
      payments: LocalPaymentService(
        db: db,
        checkout: LocalSaleCheckoutService(db: db, cart: local, logger: logger),
        sale: SaleUseCaseImpl(db: db, logger: logger),
        logger: logger,
        fiscal: FiscalServiceImpl(
          db: db,
          registry: registry,
          settingsSource: _StaticSettings(settings),
          logger: logger,
        ),
        fiscalQueue: store,
        drawer: drawerOpens,
      ),
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {
        PermissionKeys.navSale,
        PermissionKeys.opSellDiscount,
      },
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
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    cart = WtCartService(browser);
    payments = WtPaymentService(browser);
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await emulator.stop();
    await db.close();
  });

  /// Три штуки по 100, набранные **с терминала**.
  Future<CartView> threeByHundred() async {
    var view = await cart.start(
      terminalId: 1,
      wholesale: false,
      meta: const CartCommandMeta(key: 'k1', baseVersion: 0, receiptNo: null),
    );
    view = await cart.addByBarcode(1, _barcode, mv(view, 2));
    return cart.setQuantity(1, view.lines.single.id, d('3'), mv(view, 3));
  }

  Map<String, Object?> checkEnvelope() {
    final check = emulState.journal.singleWhere(
      (e) => e.path == '/api/v4/check',
    );
    expect(
      check.outcome,
      'ok',
      reason: 'оператор не свёл сумму позиций с суммой оплат',
    );
    return check.request;
  }

  /// Σ(цена × количество − скидка) по позициям конверта — в копейках, чтобы
  /// сравнение не зависело от того, как JSON записал число.
  int positionsKopecks(Map<String, Object?> request) {
    var sum = 0;
    for (final p in (request['Positions']! as List).cast<Map>()) {
      final gross = d('${p['Price']}') * d('${p['Count']}');
      final discount = d('${p['Discount'] ?? 0}');
      sum += ((gross - discount) * Decimal.fromInt(100)).toBigInt().toInt();
    }
    return sum;
  }

  int paymentsKopecks(Map<String, Object?> request) {
    var sum = 0;
    for (final p in (request['Payments']! as List).cast<Map>()) {
      sum += (d('${p['Sum']}') * Decimal.fromInt(100)).toBigInt().toInt();
    }
    return sum;
  }

  test('скидка суммой с терминала уходит оператору, чек = оплата до '
      'копейки', () async {
    var view = await threeByHundred();
    // 100 на трёх штуках — делится с периодом (66.666… за штуку): ровно
    // случай, на котором цена единицы расходилась с оплатой на копейку.
    view = await cart.setDiscountAmount(
      1,
      view.lines.single.id,
      d('100'),
      mv(view, 4),
      by: DiscountAuthority.none,
    );
    expect(view.totalDiscount, d('100'), reason: 'скидка легла в корзину кассы');
    expect(view.total, d('200'));

    final outcome = await payments.complete(
      1,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('200')),
      mv(view, 5),
    );
    expect(outcome.amount, d('200'));

    final request = checkEnvelope();
    final position = (request['Positions']! as List).cast<Map>().single;
    expect(position['Price'], 100, reason: 'в конверт — цена ДО скидки');
    expect(position['Count'], 3);
    expect(
      position['Discount'],
      100,
      reason: 'скидка, введённая с терминала, обязана доехать до оператора',
    );
    expect(positionsKopecks(request), 20000);
    expect(
      paymentsKopecks(request),
      positionsKopecks(request),
      reason: 'сумма чека обязана совпасть с суммой оплаты до копейки',
    );

    final receipts = await db.select(db.webkassaReceipts).get();
    expect(receipts, hasLength(1), reason: 'документ оператора не сохранён');
  });

  test('скидка процентом с терминала уходит оператору деньгами', () async {
    var view = await threeByHundred();
    view = await cart.setDiscountPercent(
      1,
      view.lines.single.id,
      d('15'),
      mv(view, 4),
      by: DiscountAuthority.none,
    );
    expect(view.totalDiscount, d('45'));

    await payments.complete(
      1,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('255')),
      mv(view, 5),
    );

    final request = checkEnvelope();
    final position = (request['Positions']! as List).cast<Map>().single;
    expect(position['Discount'], 45);
    expect(positionsKopecks(request), 25500);
    expect(paymentsKopecks(request), positionsKopecks(request));
  });
}
