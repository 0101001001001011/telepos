/// Три настройки дорожки A — **через эмулятор WebKassa на сокете**.
///
/// * п.2 (A1): продажа сертификата — чек по настройке, по умолчанию нет;
/// * п.3(б): раскладка «чек только на доплату»;
/// * п.4 (A3): приём аванса — чек по настройке, по умолчанию да, тип оплаты
///   фактический, вид приёма хранится;
/// * п.7 (A4): возврат чека с сертификатом — фискальный возврат только на
///   живые деньги.
///
/// Касса настоящая (корзина, `LocalPaymentService`, `SaleUseCaseImpl`,
/// `RefundUseCaseImpl`, `CustomerPaymentUseCaseImpl`, `FiscalServiceImpl`,
/// `WebKassaProvider`); доказательство — журнал эмулятора и его пересчёт.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';

import 'emulator.dart';
import 'offset_fiscal_live_test.dart' as live;
import 'state.dart';
import '../../helpers/cash_drawer.dart';

import '../../helpers/discount_authority.dart';

class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late FiscalService fiscal;
  late Talker logger;
  late EmulatorState state;
  late WebKassaEmulator emulator;

  const posAccountId = 11;
  const bankAccountId = 12;
  const advanceAccountId = 31;
  const customerId = 5;
  const terminalId = 7;
  const barcode8350 = '4870001234567';
  const barcode500 = '4870001234574';
  const barcodeCertificate = '4870009999990';

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);
  CartCommandMeta mv(CartView v, int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: v.version, receiptNo: v.receiptNo);

  Future<void> seedProduct(
    int ucode,
    String barcode,
    String price, {
    String? name,
    ProductType type = ProductType.normal,
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            name: name ?? 'Товар $ucode',
            type: type.index,
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

  Future<void> settings(FiscalOffsetSettings s) async {
    expect(await db.thisPosDao.saveOffsetFiscalSettings(s), 1);
  }

  setUp(() async {
    state = live.emulatorState();
    emulator = await live.startEmulatorInRange(state);

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
    await seedProduct(200, barcode500, '500');
    await seedProduct(
      900,
      barcodeCertificate,
      '5000',
      name: 'Подарочный сертификат 5000',
      type: ProductType.giftCertificate,
    );

    for (final id in [
      SystemPaymentKindIds.certificate,
      SystemPaymentKindIds.prepayment,
    ]) {
      await (db.update(db.paymentKinds)..where((k) => k.id.equals(id))).write(
        const PaymentKindsCompanion(isActive: Value(true)),
      );
    }

    logger = Talker();
    fiscal = FiscalServiceImpl(
      db: db,
      registry: live.emulatorRegistry(logger),
      settingsSource: live.FixedFiscalSettings(
        live.emulatorSettings(emulator.baseUri),
      ),
      logger: logger,
    );
    // `SaleUseCaseImpl._isOfd` спрашивает узел у GetIt — тот же, что у
    // кассы. Возврат узел там больше не ищет: он получает его доводом
    // конструктора (`fiscal:` у `RefundUseCaseImpl` ниже), и подставлен туда
    // **тот же экземпляр**, что и продаже, — иначе проба мерила бы двух
    // разных операторов.
    GetIt.I.registerSingleton<FiscalService>(fiscal);
    GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());

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
      fiscal: fiscal,
      fiscalQueue: DriftFiscalQueueStore(db),
      printer: null,
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await GetIt.I.unregister<RefundProductService>();
    await GetIt.I.unregister<FiscalService>();
    await db.close();
    await emulator.stop();
  });

  Future<CartView> receiptOf(List<String> barcodes) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    var n = 2;
    for (final b in barcodes) {
      view = await cart.addByBarcode(terminalId, b, mv(view, n++));
    }
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

  Map<int, Decimal> paymentsByType(JournalEntry check) => {
    for (final p in (check.request['Payments'] as List)
        .cast<Map<String, Object?>>())
      (p['PaymentType'] as num).toInt(): live.money(p['Sum']),
  };

  List<Map<String, Object?>> positionsOf(JournalEntry check) =>
      (check.request['Positions'] as List).cast<Map<String, Object?>>();

  group('п.3(б): чек только на доплату', () {
    test('чек 8350: наличных 1150, позиция на 1150 без скидки', () async {
      await settings(
        const FiscalOffsetSettings(
          offsetLayout: OffsetFiscalLayout.surchargeOnly,
        ),
      );
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

      final view = await receiptOf([barcode8350]);
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
      printJournal('(б) 8350');

      expect(outcome.fiscal.state, FiscalState.done);
      final check = checks().single;
      expect(check.outcome, 'ok');
      expect(paymentsByType(check), {0: d('1150')});
      final recount = recountCheck(check.request, VatMode.off);
      expect(recount.complaint, isNull);
      expect(recount.positionsTotal, d('1150'));
      final position = positionsOf(check).single;
      expect(
        live.money(position['Price']),
        d('1150'),
        reason: 'вариант (б): цена позиции — доплата, а не полная цена',
      );
      expect(
        position.containsKey('Discount'),
        isFalse,
        reason: 'под зачёт поля скидки нет; 7200 значит, что стоит вариант (а)',
      );
    });

    test('чек целиком сертификатом — документа нет и в варианте (б)', () async {
      await settings(
        const FiscalOffsetSettings(
          offsetLayout: OffsetFiscalLayout.surchargeOnly,
        ),
      );
      await LocalCertificateIssuer(
        db: db,
        logger: logger,
      ).issue(by: fullDiscountAuthority, number: 'C-500', nominal: d('500'));
      final view = await receiptOf([barcode500]);
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-500')],
        ),
        mv(view, 9),
      );
      printJournal('(б) целиком сертификатом');
      expect(checks(), isEmpty);
      expect(outcome.fiscal.state, FiscalState.notRequired);
    });
  });

  group('п.2 (A1): продажа сертификата', () {
    test('по умолчанию (выкл) — журнал эмулятора пуст', () async {
      expect(
        (await db.thisPosDao.offsetFiscalSettings()).fiscalizeCertificateSale,
        isFalse,
      );
      final view = await receiptOf([barcodeCertificate]);
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('5000')),
        mv(view, 9),
      );
      printJournal('A1 выкл');
      expect(
        state.journal,
        isEmpty,
        reason: 'касса не сходила к оператору вовсе — даже за токеном',
      );
      expect(outcome.fiscal.state, FiscalState.notRequired);
    });

    test('выкл, смешанный чек: документ только на товар, наличных 500', () async {
      final view = await receiptOf([barcodeCertificate, barcode500]);
      expect(view.total, d('5500'));
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('5500')),
        mv(view, 9),
      );
      printJournal('A1 выкл, смешанный');
      expect(outcome.fiscal.state, FiscalState.done);
      final check = checks().single;
      expect(check.outcome, 'ok');
      expect(
        positionsOf(check).map((p) => p['PositionName']).toList(),
        ['Товар 200'],
        reason: 'строка сертификата в документ не идёт',
      );
      expect(paymentsByType(check), {0: d('500')});
    });

    test('вкл — check с позицией сертификата на полученную сумму', () async {
      await settings(
        const FiscalOffsetSettings(fiscalizeCertificateSale: true),
      );
      final view = await receiptOf([barcodeCertificate]);
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('5000')),
        mv(view, 9),
      );
      printJournal('A1 вкл');
      expect(outcome.fiscal.state, FiscalState.done);
      final check = checks().single;
      expect(check.outcome, 'ok');
      expect(
        positionsOf(check).single['PositionName'],
        'Подарочный сертификат 5000',
      );
      expect(paymentsByType(check), {0: d('5000')});
    });
  });

  group('п.4 (A3): приём аванса', () {
    CustomerPaymentUseCaseImpl useCase() =>
        CustomerPaymentUseCaseImpl(db: db, logger: logger, fiscal: fiscal);

    test('по умолчанию (вкл): check на сумму аванса, тип — карта, вид '
        'приёма записан', () async {
      final result = await useCase().execute(
        agentId: customerId,
        amount: d('700'),
        decision: CustomerPaymentDecision.investment,
        tenderKindId: SystemPaymentKindIds.card,
      );
      printJournal('A3 вкл, карта');

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.fiscalError, isNull);
      expect(result.fiscalSign, isNotNull);
      final check = checks().single;
      expect(check.outcome, 'ok');
      expect(
        paymentsByType(check),
        {1: d('700')},
        reason: 'аванс, принятый картой, уходит картой, а не наличными',
      );
      final position = positionsOf(check).single;
      expect(
        position['PositionName'] as String,
        startsWith('Аванс (предоплата)'),
      );
      expect(recountCheck(check.request, VatMode.off).complaint, isNull);

      final operation = await db.select(db.cashOperations).getSingle();
      expect(operation.kindId, SystemPaymentKindIds.card);
    });

    test('выкл: журнал эмулятора пуст, вид приёма всё равно записан', () async {
      await settings(
        const FiscalOffsetSettings(fiscalizePrepaymentReceipt: false),
      );
      final result = await useCase().execute(
        agentId: customerId,
        amount: d('700'),
        decision: CustomerPaymentDecision.investment,
        tenderKindId: SystemPaymentKindIds.cash,
      );
      printJournal('A3 выкл');
      expect(result.success, isTrue);
      expect(state.journal, isEmpty);
      expect(
        (await db.select(db.cashOperations).getSingle()).kindId,
        SystemPaymentKindIds.cash,
      );
    });

    test('погашение долга авансом не называется: долг 300, внесено 1000 — '
        'чек на 700', () async {
      await (db.update(db.accounts)
            ..where((a) => a.id.equals(advanceAccountId)))
          .write(AccountsCompanion(value: Value(d('-300'))));
      final result = await useCase().execute(
        agentId: customerId,
        amount: d('1000'),
        decision: CustomerPaymentDecision.investment,
        tenderKindId: SystemPaymentKindIds.cash,
      );
      printJournal('A3 долг + аванс');
      expect(result.success, isTrue);
      expect(paymentsByType(checks().single), {0: d('700')});
    });

    test('зачёт вида «Сертификат» принять деньгами нельзя', () async {
      final result = await useCase().execute(
        agentId: customerId,
        amount: d('700'),
        decision: CustomerPaymentDecision.investment,
        tenderKindId: SystemPaymentKindIds.certificate,
      );
      expect(result.success, isFalse);
      expect(await db.select(db.cashOperations).get(), isEmpty);
      expect(state.journal, isEmpty);
    });
  });

  group('п.7 (A4): возврат', () {
    Future<void> refund(int receiptNo, String amount) async {
      await db
          .into(db.refunds)
          .insert(RefundsCompanion.insert(userId: 4, time: 2000));
      final refundId = (await db.select(db.refunds).get()).last.localId;
      await db
          .into(db.refundProducts)
          .insert(
            RefundProductsCompanion(
              refundLocalId: Value(refundId),
              ucode: const Value(200),
              quantity: Value(d('2')),
              price: Value(d('500')),
            ),
          );
      await RefundUseCaseImpl(
        db: db,
        logger: logger,
        fiscal: fiscal,
      ).perform(
        refundLocalId: refundId,
        amount: d(amount),
        userId: 4,
        saleReceiptNo: receiptNo,
        salePosId: 1,
        products: const [],
      );
    }

    test('чек 1000 = сертификат 600 + наличные 400: фискальный возврат '
        'на наличные 400, остаток — на сертификат', () async {
      await LocalCertificateIssuer(
        db: db,
        logger: logger,
      ).issue(by: fullDiscountAuthority, number: 'C-600', nominal: d('600'));
      final view = await receiptOf([barcode500, barcode500]);
      expect(view.total, d('1000'));
      await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('400'),
          certificates: const [CertificateTender(number: 'C-600')],
        ),
        mv(view, 9),
      );
      await payments.pendingSideEffects;
      state.journal.clear();

      await refund(view.receiptNo!, '1000');
      printJournal('A4 возврат');

      final returned = checks().single;
      expect(returned.request['OperationType'], 3);
      expect(returned.outcome, 'ok');
      expect(
        paymentsByType(returned),
        {0: d('400')},
        reason: '1000 наличными — возврат денег, которых из ящика не выходило',
      );
      expect(recountCheck(returned.request, VatMode.off).complaint, isNull);
      // Решение заказчика 2026-09-16, пункт 2: на ту же бумажку деньги не
      // возвращаются никогда. Старая остаётся погашенной, покупатель
      // получает **новую** на закрытую ею сумму — фискальная половина при
      // этом не меняется ни на тенге: документ по-прежнему возвращает
      // только живые 400.
      expect(
        (await db.certificateDao.byNumber('C-600'))!.balance,
        Decimal.zero,
      );
      expect(
        (await db.certificateDao.all())
            .where((c) => c.number.startsWith('C-600-R'))
            .single
            .balance,
        d('600'),
        reason: 'сертификатная доля ушла новой бумажкой, а не в ящик',
      );
    });

    test('чек целиком сертификатом: возврат на сертификат без фискального '
        'документа', () async {
      await LocalCertificateIssuer(
        db: db,
        logger: logger,
      ).issue(by: fullDiscountAuthority, number: 'C-1000', nominal: d('1000'));
      final view = await receiptOf([barcode500, barcode500]);
      await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1000')],
        ),
        mv(view, 9),
      );
      await payments.pendingSideEffects;
      state.journal.clear();

      await refund(view.receiptNo!, '1000');
      printJournal('A4 возврат целиком сертификатом');
      expect(checks(), isEmpty);
      expect(
        (await db.certificateDao.byNumber('C-1000'))!.balance,
        Decimal.zero,
      );
      expect(
        (await db.certificateDao.all())
            .where((c) => c.number.startsWith('C-1000-R'))
            .single
            .balance,
        d('1000'),
        reason: 'документа нет — живых денег не выходило, — но бумажка выпущена',
      );
    });
  });
}
