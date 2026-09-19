/// Сертификат, аванс и QR в фискальном чеке — **через эмулятор WebKassa на
/// сокете**, а не через подменённый `_send`.
///
/// Решения заказчика 2026-09-14 (план `2026-09-14-sale-remaining.md`, группа
/// A, пункт C; разбор `docs/internal/research/2026-09-14-certificate-
/// prepayment-fiscal-kz.md`):
///
/// 1. Гашение сертификата — не фискальная оплата: ни в наличных, ни в карте,
///    ни в `Payments` конверта.
/// 3. Раскладка гашения — настройка: (а) скидкой позиций — по умолчанию;
///    (б) чек только на доплату живыми деньгами.
/// 5. Приём аванса фискализован → зачёт аванса оплатой уйти не может.
/// 6. QR/СБП — `mobile` (PaymentType 4), а не карта.
///
/// # Что считается доказательством
///
/// Журнал эмулятора: тело запроса `/api/v4/check`, которое пришло по
/// настоящему HTTP, и пересчёт того же эмулятора (`recountCheck`) с нулевым
/// допуском. Касса собрана настоящая: корзина, `LocalPaymentService`,
/// `SaleUseCaseImpl`, `FiscalServiceImpl`, `WebKassaProvider`.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что настоящая WebKassa примет чек со скидкой, равной сумме сертификата,
/// или чек на одну доплату — вопросы к поддержке WebKassa (A6) остаются.
/// Эмулятор сводит суммы так, как описано в `state.dart`, и только.
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import 'emulator.dart';
import 'state.dart';
import '../../helpers/cash_drawer.dart';

import '../../helpers/discount_authority.dart';

/// Эмулятор на порту из 18100–18199 — правило машины: чужие порты не
/// трогаются, свои известны заранее.
Future<WebKassaEmulator> startEmulatorInRange(EmulatorState state) async {
  for (var port = 18100; port <= 18199; port++) {
    final emulator = WebKassaEmulator(state: state, echo: false);
    try {
      await emulator.start('127.0.0.1', port);
      return emulator;
    } on SocketException {
      continue;
    }
  }
  throw StateError('на портах 18100–18199 нет свободного');
}

EmulatorState emulatorState() => EmulatorState(
  cashboxes: {
    'SWK00000001': EmulatedCashbox(
      uniqueNumber: 'SWK00000001',
      registrationNumber: '000000000001',
      now: DateTime.now(),
    ),
  },
  login: 'emul',
  password: 'emul',
  tokenTtl: const Duration(hours: 1),
  vat: VatMode.off,
);

FiscalSettings emulatorSettings(Uri base) => FiscalSettings(
  operatorType: FiscalOperatorType.webkassa,
  testMode: true,
  baseUrl: base.toString(),
  login: 'emul',
  password: 'emul',
  apiKey: 'emulated-integrator-key',
  cashboxUniqueNumber: 'SWK00000001',
  registrationNumber: '000000000001',
);

/// Реестр с одним настоящим провайдером — тем же, что собирает касса.
FiscalProviderRegistry emulatorRegistry(Talker logger) =>
    FiscalProviderRegistry()..register(
      FiscalOperatorType.webkassa,
      (s) => WebKassaProvider(settings: s, logger: logger),
    );

class FixedFiscalSettings implements FiscalSettingsSource {
  FixedFiscalSettings(this.settings);
  final FiscalSettings settings;
  @override
  Future<FiscalSettings> load() async => settings;
}

Decimal money(Object? v) => Decimal.parse('$v');

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late Talker logger;
  late EmulatorState state;
  late WebKassaEmulator emulator;

  const posAccountId = 11;
  const bankAccountId = 12;
  const advanceAccountId = 31;
  const customerId = 5;
  const terminalId = 7;
  const barcode8350 = '4870001234567';
  const barcode300 = '4870001234574';

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);
  CartCommandMeta mv(CartView v, int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: v.version, receiptNo: v.receiptNo);

  Future<void> seedProduct(int ucode, String barcode, String price) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            name: 'Товар $ucode',
            type: 0,
            measure: 0,
            quantity: Value(d('1000')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            sellingPrice: Value(d(price)),
          ),
        );
  }

  Future<void> seedAccount(int id, int type, String value) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: Value(id),
          type: type,
          name: Value('Счёт $id'),
          value: Value(d(value)),
          visibleToPos: const Value(false),
        ),
      );

  setUp(() async {
    state = emulatorState();
    emulator = await startEmulatorInRange(state);

    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            acquiringAccountId: Value(bankAccountId),
            cashBoxName: Value('Касса 1'),
            companyName: Value('ТОО Ромашка'),
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
    await seedAccount(posAccountId, AccountType.pos, '0');
    await seedAccount(bankAccountId, AccountType.customBank, '0');
    await seedAccount(advanceAccountId, AccountType.agentMain, '700');
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(customerId),
            name: Value('Покупатель'),
            phone: Value(77011234567),
            mainAccountId: Value(advanceAccountId),
          ),
        );
    await seedProduct(100, barcode8350, '8350');
    await seedProduct(200, barcode300, '300');

    for (final id in [
      SystemPaymentKindIds.certificate,
      SystemPaymentKindIds.prepayment,
      SystemPaymentKindIds.qr,
    ]) {
      await (db.update(db.paymentKinds)..where((k) => k.id.equals(id))).write(
        const PaymentKindsCompanion(isActive: Value(true)),
      );
    }

    logger = Talker();
    cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: FiscalServiceImpl(
        db: db,
        registry: emulatorRegistry(logger),
        settingsSource: FixedFiscalSettings(emulatorSettings(emulator.baseUri)),
        logger: logger,
      ),
      fiscalQueue: DriftFiscalQueueStore(db),
      printer: null,
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await db.close();
    await emulator.stop();
  });

  Future<CartView> receiptOf(String barcode) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(terminalId, barcode, mv(view, 2));
    return view;
  }

  List<JournalEntry> checks() =>
      state.journal.where((e) => e.path == '/api/v4/check').toList();

  void printJournal(String title) {
    // ignore: avoid_print
    print('\n--- $title: журнал эмулятора (${state.journal.length}) ---');
    for (final e in state.journal) {
      // ignore: avoid_print
      print(e.line);
    }
  }

  /// Оплаты конверта по типу WebKassa: `{PaymentType: Sum}`.
  Map<int, Decimal> paymentsByType(JournalEntry check) => {
    for (final p in (check.request['Payments'] as List)
        .cast<Map<String, Object?>>())
      (p['PaymentType'] as num).toInt(): money(p['Sum']),
  };

  group('п.1 и п.3(а): гашение сертификата — не оплата, по умолчанию скидкой', () {
    test('чек 8350 = сертификаты 1500+5000 + аванс 700 + наличные 1150: '
        'у эмулятора наличных ровно 1150', () async {
      final issuer = LocalCertificateIssuer(db: db, logger: logger);
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1500',
        nominal: d('1500'),
      );
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-5000',
        nominal: d('5000'),
      );

      final view = await receiptOf(barcode8350);
      expect(view.total, d('8350'));

      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('1150'),
          prepaymentUsed: d('700'),
          prepaymentReference: 'АВ-1',
          customerId: customerId,
          certificates: const [
            CertificateTender(number: 'C-1500'),
            CertificateTender(number: 'C-5000'),
          ],
        ),
        mv(view, 9),
      );
      printJournal('8350');

      expect(outcome.fiscal.state, FiscalState.done);
      final check = checks().single;
      expect(check.outcome, 'ok', reason: 'кода 9 быть не должно');
      expect(
        paymentsByType(check),
        {0: d('1150')},
        reason:
            'оператор видит наличных ровно столько, сколько в ящике; '
            '8350 значит, что сертификаты и аванс уехали наличными',
      );

      final recount = recountCheck(check.request, VatMode.off);
      expect(recount.complaint, isNull);
      expect(
        recount.positionsTotal,
        d('1150'),
        reason: 'сумма позиций после раскладки равна сумме оплат',
      );
      final position = (check.request['Positions'] as List)
          .cast<Map<String, Object?>>()
          .single;
      expect(money(position['Price']), d('8350'), reason: 'цена — полная');
      expect(
        money(position['Discount']),
        d('7200'),
        reason: 'вариант (а): сертификаты 6500 и аванс 700 — скидкой позиции',
      );
    });

    test('чек, целиком оплаченный сертификатом, фискального документа не '
        'даёт', () async {
      await LocalCertificateIssuer(
        db: db,
        logger: logger,
      ).issue(by: fullDiscountAuthority, number: 'C-300', nominal: d('300'));
      final view = await receiptOf(barcode300);

      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-300')],
        ),
        mv(view, 9),
      );
      printJournal('целиком сертификатом');

      expect(
        checks(),
        isEmpty,
        reason:
            'денежного расчёта не было — фискальный документ не на что '
            'выбивать (решение (в) плана)',
      );
      expect(outcome.fiscal.state, FiscalState.notRequired);
    });
  });

  group('п.5: сторож на опасное сочетание', () {
    test('приём аванса фискализован, а вид «Предоплата» назван наличными — '
        'зачёт всё равно не уезжает оплатой', () async {
      // Оператор (или старая база) оставил зачёту трактовку `cash`. При
      // включённой фискализации приёма (умолчание) это двойная выручка по
      // ККМ — запрещено построением, а не пожеланием.
      final base = SystemPaymentKinds.byId(SystemPaymentKindIds.prepayment);
      await db.paymentKindDao.put(
        base.copyWith(isActive: true, fiscalTreatment: FiscalTreatment.cash),
      );

      final view = await receiptOf(barcode300);
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('180'),
          prepaymentUsed: d('120'),
          prepaymentReference: 'АВ-2',
          customerId: customerId,
        ),
        mv(view, 9),
      );
      printJournal('сторож аванса');

      expect(outcome.fiscal.state, FiscalState.done);
      final check = checks().single;
      expect(check.outcome, 'ok');
      expect(
        paymentsByType(check),
        {0: d('180')},
        reason: '300 значит, что аванс, уже фискализованный при приёме, '
            'второй раз прошёл выручкой',
      );
    });
  });

  group('п.6: QR/СБП — mobile (PaymentType 4)', () {
    test('чек, оплаченный телефоном, уходит оператору типом 4, а не картой',
        () async {
      final (row, _) = await db.paymentIntentDao.claim(
        intentKey: 'q-1',
        providerCode: 'sbp_test',
        amount: d('300'),
        createdAt: DateTime.now(),
        // Намерение без рабочего места ничьё (пункт 10 C): кассу оно
        // зачесть в этот чек не даст — место то же, что у оплаты.
        terminalId: terminalId,
      );
      await db.paymentIntentDao.attachProviderIntent(
        id: row.id,
        providerIntentId: 'PRV-q-1',
        status: QrIntentStatus.pending,
      );
      await db.paymentIntentDao.applyState(
        id: row.id,
        status: QrIntentStatus.paid,
        paidAmount: d('300'),
        confirmedAt: DateTime.now(),
        countConfirmation: true,
      );

      final view = await receiptOf(barcode300);
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(type: PaymentType.cash, qrIntentKey: 'q-1'),
        mv(view, 9),
      );
      printJournal('QR');

      expect(outcome.fiscal.state, FiscalState.done);
      final check = checks().single;
      expect(check.outcome, 'ok');
      expect(
        paymentsByType(check),
        {4: d('300')},
        reason: '{1: 300} — QR уехал картой (три ведра конверта)',
      );
    });
  });
}
