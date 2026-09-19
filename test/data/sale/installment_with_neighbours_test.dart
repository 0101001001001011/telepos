/// Рассрочка **вместе с соседями по ярусу** — числами, а не рассуждением.
///
/// # Зачем отдельный файл
///
/// Три автора подряд находили дефекты именно на стыках: задачи 21
/// (сертификат), 22 (QR) и 23 (аванс) шли параллельно и друг друга не
/// видели, и все три завели «остаток чека после бонуса» каждая от своего
/// нуля. Рассрочка — четвёртый жилец той же раскладки, и вопрос к ней
/// ровно тот же: **чью комнату она берёт**.
///
/// # Ответ, который проверяется здесь
///
/// **Никакую.** Рассрочка не участвует в цепочке зачётов ни первой, ни
/// последней: она `PaymentSettlement.deferred`, то есть не уменьшает сумму
/// к доплате, а заменяет собой способ её внести. Её сумма не выбирается —
/// она равна остатку после всех зачётов и всех живых денег.
///
/// Следствие, и оно измеримо: **зачёты урезают тело договора**, а не друг
/// друга. Чек 1000 с авансом 300 даёт договор на 700; с сертификатом 400 —
/// на 600; с QR на 500 — на 500. Каждое из этих чисел ложно при любой
/// другой раскладке.
///
/// # Почему утверждений в каждом случае несколько
///
/// «Сумма сошлась» здесь ничего не доказывает: чек закроется на 1000 и
/// при любом порядке. Поэтому рядом стоят числа, которые порядок
/// различают: тело договора, остаток счёта-источника зачёта и остаток
/// расчётного счёта покупателя.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/payment/local_credit_service.dart';
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
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import '../../helpers/cash_drawer.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late CertificateIssuer issuer;
  late CreditService credit;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const bankAccountId = 12;
  const agentMainAccountId = 14;
  const bonusAccountId = 15;
  const customerId = 5;
  const terminalId = 7;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  Future<Decimal> liabilityBalance() async {
    final accounts = await db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    if (accounts.isEmpty) return Decimal.zero;
    return accounts.first.value ?? Decimal.zero;
  }

  Future<void> seedAccount(int id, int type, {String value = '0'}) async {
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

  Future<void> seedCustomer({String advance = '0', String bonus = '0'}) async {
    await seedAccount(agentMainAccountId, AccountType.agentMain, value: advance);
    await seedAccount(bonusAccountId, AccountType.cashback, value: bonus);
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(customerId),
            name: Value('Айгуль'),
            phone: Value(77015550000),
            mainAccountId: Value(agentMainAccountId),
            cashbackAccountId: Value(bonusAccountId),
          ),
        );
  }

  Future<void> enableKinds() async {
    for (final id in const [
      SystemPaymentKindIds.certificate,
      SystemPaymentKindIds.qr,
      SystemPaymentKindIds.prepayment,
      SystemPaymentKindIds.bonus,
      SystemPaymentKindIds.installment,
    ]) {
      await db.paymentKindDao.put(
        SystemPaymentKinds.byId(id).copyWith(isActive: true),
      );
    }
  }

  Future<PaymentIntent> paidIntent(String key, String amount) async {
    // Рабочее место — то, что платит: `startQr` его всегда ставит, а
    // намерение без места с 2026-09-15 не принадлежит никому (пункт 10 C).
    final (row, _) = await db.paymentIntentDao.claim(
      intentKey: key,
      providerCode: 'sbp_test',
      amount: d(amount),
      createdAt: DateTime.now(),
      terminalId: terminalId,
    );
    await db.paymentIntentDao.attachProviderIntent(
      id: row.id,
      providerIntentId: 'PRV-$key',
      status: QrIntentStatus.pending,
    );
    await db.paymentIntentDao.applyState(
      id: row.id,
      status: QrIntentStatus.paid,
      paidAmount: d(amount),
      confirmedAt: DateTime.now(),
      countConfirmation: true,
    );
    return (await db.paymentIntentDao.byId(row.id))!;
  }

  Future<CartView> receiptWith({int quantity = 2}) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(terminalId, barcodeA, mv(view, 2));
    if (quantity > 1) {
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('$quantity'),
        mv(view, 3),
      );
    }
    return view;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            sellInDebt: Value(true),
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
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(barcodeA),
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
            barcode: int.parse(barcodeA),
            sellingPrice: Value(d('500')),
          ),
        );
    await seedAccount(posAccountId, AccountType.pos);
    await seedAccount(bankAccountId, AccountType.customBank);

    final logger = Talker();
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
      cardTerminal: (_, {required amountTiyn, required receiptNo}) async =>
          const CardCharge(outcome: CardChargeOutcome.notConfigured),
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    issuer = LocalCertificateIssuer(db: db, logger: logger);
    credit = LocalCreditService(db: db, logger: logger);
    await enableKinds();
  });

  tearDown(() async => db.close());

  test('рассрочка + аванс: зачёт 300 УМЕНЬШАЕТ ТЕЛО договора до 700',
      () async {
    // Чек 1000, внесённый аванс 300, первого взноса нет.
    //
    // Зачёт аванса — `offset`: он уменьшает сумму к доплате. Рассрочка —
    // `deferred`: она берёт то, что после него осталось. Число 700 ложно
    // при любой другой раскладке: 1000 значило бы, что аванс не зачли,
    // 300 — что зачли не то.
    await seedCustomer(advance: '300');
    final view = await receiptWith();

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.installment,
        customerId: customerId,
        prepaymentUsed: d('300'),
        prepaymentReference: 'АВ-7',
        installmentTermMonths: 3,
        installmentScheme: InstallmentScheme.equalInstalments.code,
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(outcome.paid, d('300'), reason: 'зачёт аванса — не живые деньги');
    expect(outcome.debt, d('700'));

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(rows.length, 2);
    expect(
      rows.firstWhere((r) => r.kindId == SystemPaymentKindIds.prepayment).amount,
      d('300'),
    );
    expect(
      rows
          .firstWhere((r) => r.kindId == SystemPaymentKindIds.installment)
          .amount,
      d('700'),
    );

    final contract = await credit.byNumber('РС-1-${view.receiptNo}');
    expect(contract!.contract.principal, d('700'), reason: 'ТЕЛО договора');
    expect(
      contract.schedule.fold(Decimal.zero, (Decimal s, e) => s + e.totalDue),
      d('700'),
    );

    // Оба движения легли на **один и тот же** счёт покупателя, и порядок
    // их виден числом: аванс 300 списан условной записью (300 → 0), долг
    // 700 записан движением (0 → −700).
    expect(await balanceOf(agentMainAccountId), d('-700'));
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  test('рассрочка + сертификат: бумажка гасится на 400, тело договора 600',
      () async {
    await seedCustomer();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('400'),
    );
    final view = await receiptWith();

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.installment,
        customerId: customerId,
        certificates: const [CertificateTender(number: 'C-1')],
        installmentTermMonths: 6,
        installmentScheme: InstallmentScheme.differentiated.code,
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(outcome.debt, d('600'));

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    final certRow = rows.firstWhere(
      (r) => r.kindId == SystemPaymentKindIds.certificate,
    );
    expect(certRow.amount, d('400'));
    expect(certRow.reference, 'C-1');
    expect(
      rows
          .firstWhere((r) => r.kindId == SystemPaymentKindIds.installment)
          .amount,
      d('600'),
    );

    // Три числа, а не одно: остаток самой бумажки, остаток счёта
    // обязательства и тело договора. Проба, спросившая одно, не отличила
    // бы «погашено один раз» от «погашено в одной таблице из двух».
    expect((await db.certificateDao.byNumber('C-1'))!.balance, Decimal.zero);
    expect(await liabilityBalance(), Decimal.zero);

    final contract = await credit.byNumber('РС-1-${view.receiptNo}');
    expect(contract!.contract.principal, d('600'));
    expect(contract.schedule.length, 6);
    expect(await balanceOf(agentMainAccountId), d('-600'));
  });

  test('рассрочка + QR: деньги провайдера 500 в банк, тело договора 500',
      () async {
    await seedCustomer();
    final intent = await paidIntent('Q-1', '500');
    final view = await receiptWith();

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.installment,
        customerId: customerId,
        qrIntentKey: intent.intentKey,
        accountId: bankAccountId,
        installmentTermMonths: 12,
        installmentScheme: InstallmentScheme.feeUpfront.code,
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(outcome.paid, d('500'), reason: 'QR — живые деньги');
    expect(outcome.debt, d('500'));

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    final qrRow = rows.firstWhere((r) => r.kindId == SystemPaymentKindIds.qr);
    expect(qrRow.amount, d('500'));
    expect(qrRow.payeeAccountId, bankAccountId);
    expect(
      rows
          .firstWhere((r) => r.kindId == SystemPaymentKindIds.installment)
          .amount,
      d('500'),
    );

    expect(
      await balanceOf(bankAccountId),
      d('500'),
      reason: 'деньги телефоном пришли в банк, а не в ящик',
    );
    expect(await balanceOf(posAccountId), Decimal.zero);
    expect(await balanceOf(agentMainAccountId), d('-500'));

    final contract = await credit.byNumber('РС-1-${view.receiptNo}');
    expect(contract!.contract.principal, d('500'));
    expect(contract.contract.downPayment, Decimal.zero,
        reason: 'первый взнос — это наличные и карта, QR туда не входит');

    // Намерение разобрано: деньги провайдера не могут уйти во второй чек.
    expect((await db.paymentIntentDao.byId(intent.id))!.settledAt, isNotNull);
  });

  test('все четверо разом: бонус, QR, сертификат, аванс — и остаток в договор',
      () async {
    // Чек 1000. Бонус 100, QR 200, сертификат 150, аванс 250 — и 300
    // остаётся телом договора. Если бы хоть один потолок считался от
    // `amount - bonus` вместо цепочки, тело вышло бы другим, а `paid`
    // разошёлся бы с суммой строк.
    await seedCustomer(advance: '250', bonus: '100');
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('150'),
    );
    final intent = await paidIntent('Q-1', '200');
    final view = await receiptWith();

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.installment,
        customerId: customerId,
        bonusUsed: d('100'),
        qrIntentKey: intent.intentKey,
        accountId: bankAccountId,
        certificates: const [CertificateTender(number: 'C-1')],
        prepaymentUsed: d('250'),
        prepaymentReference: 'АВ-9',
        installmentTermMonths: 3,
        installmentScheme: InstallmentScheme.equalInstalments.code,
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(outcome.paid, d('700'), reason: '100 + 200 + 150 + 250');
    expect(outcome.debt, d('300'));

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    Decimal of(int kind) =>
        rows.firstWhere((r) => r.kindId == kind).amount;
    expect(of(SystemPaymentKindIds.bonus), d('100'));
    expect(of(SystemPaymentKindIds.qr), d('200'));
    expect(of(SystemPaymentKindIds.certificate), d('150'));
    expect(of(SystemPaymentKindIds.prepayment), d('250'));
    expect(of(SystemPaymentKindIds.installment), d('300'));
    expect(
      rows.fold(Decimal.zero, (Decimal s, r) => s + r.amount),
      d('1000'),
      reason: 'Σ строк оплаты == сумма чека',
    );

    final contract = await credit.byNumber('РС-1-${view.receiptNo}');
    expect(contract!.contract.principal, d('300'));
    expect(
      contract.schedule.fold(Decimal.zero, (Decimal s, e) => s + e.totalDue),
      d('300'),
    );

    // Счета-источники: бонусный обнулён, бумажка обнулена, аванс
    // израсходован и поверх него лёг долг 300.
    expect(await balanceOf(bonusAccountId), Decimal.zero);
    expect((await db.certificateDao.byNumber('C-1'))!.balance, Decimal.zero);
    expect(await balanceOf(agentMainAccountId), d('-300'));
    expect(await balanceOf(bankAccountId), d('200'));
  });
}
