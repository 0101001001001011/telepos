/// Сертификат **вместе с соседями по ярусу** — сочетания, которых не
/// видел ни один из трёх авторов.
///
/// # Зачем отдельный файл
///
/// Задачи 21 (сертификат), 22 (QR) и 23 (аванс) шли параллельно и друг
/// друга не видели. У каждой свой набор, и каждый набор зелен — на своём
/// дереве. Ни один из трёх не мог поставить чек, где сертификат встречается
/// с намерением QR, с зачётом аванса или с долгом: соседского кода в дереве
/// не было.
///
/// # Что именно утверждается, и почему не «сумма сошлась»
///
/// Сумма сходится при **любом** порядке потолков: урежь касса не ту
/// строку, чек всё равно закроется на 1000, и сложение не скажет ни слова.
/// Хуже: сумма сходится и у кассы, которая списала бумажку дважды, и у
/// той, которая не списала её вовсе. Поэтому каждый случай утверждает
/// **три разных числа**:
///
/// * какая строка урезана и на сколько — то есть порядок раскладки;
/// * остаток самой бумажки (`GiftCertificates.balanceMillis`);
/// * остаток счёта обязательства (`AccountType.certificateLiability`).
///
/// Последние два — разные строки в разных таблицах, и держать их вместе
/// обязана транзакция продажи. Проба, спросившая только одно из двух, не
/// отличила бы «погашено один раз» от «погашено в одной таблице из двух».
///
/// # Место, которое автор сертификата просил проверить ЧИСЛОМ
///
/// Он оставил оговорку: строка сертификата идёт по **общей** ветви зачёта
/// (`!isBonus && isOffset`, задача 23) без правок, «если та не
/// переворачивает знак руками». Кода соседа в его дереве не было, и он
/// назвал это местом, которое надо измерить при слиянии.
///
/// Измерено, и ответ утвердительный: общая ветвь зовёт
/// `AccountDao.claimCredit`, то есть `balance − amount` условной записью.
/// Для рода `certificateLiability` это ровно то же число, что дало бы
/// `post(+amount)` через `AccountPosting.isRedemption`. Знак не
/// переворачивается ни разу, и сертификат проходит по чужой ветви без
/// единой правки.
///
/// # Три диверсии, которыми это измерено
///
/// Читать условие ветви бесполезно: оно выглядит верным при любом из трёх
/// исходов. Поэтому подменялась сама запись, и каждый раз смотрелось, какое
/// число выходит:
///
/// 1. **`post(id, −amount)`** — знак, перевёрнутый рукой. Обязательство
///    вместо `600 → 0` идёт в `600 → 1200`: касса, погасив бумажку,
///    должна вдвое больше. Краснеют **все пять** проб ниже, каждая на
///    остатке счёта обязательства.
/// 2. **`post(id, +amount)`** — правило знака вместо условной записи. Все
///    утверждения **про сертификат остаются зелёными**: для рода
///    `certificateLiability` это то же вычитание. Оговорка автора верна
///    ровно в том виде, в каком он её написал.
/// 3. Та же подмена, но смотреть на **аванс**: расчётный счёт покупателя
///    идёт `600 → 1000` вместо `600 → 200`, потому что род `agentMain`
///    редемпшном не объявлен и `post` там прибавляет.
///
/// Отсюда полный ответ, которого не было ни у одного из авторов:
/// `claimCredit` в этой ветви **несменяем**, но держит его не сертификат,
/// а аванс. Сертификату всё равно; сведи кто-нибудь ветвь на `post`, ради
/// «единого правила знака» — сертификатные пробы промолчат, а аванс
/// сломается молча.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
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
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
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

  Future<GiftCertificate> cert(String number) async =>
      (await db.certificateDao.byNumber(number))!;

  /// Остаток счёта обязательства — **второе** из двух чисел, которые
  /// обязаны двигаться вместе с гашением бумажки.
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

  /// Покупатель с расчётным и бонусным счётом. Оба нужны сразу: чек
  /// «все четыре зачёта» ниже спрашивает и то, и другое, а разводить
  /// покупателей по пробам значило бы мерить разные картотеки.
  Future<void> seedCustomer({
    String advance = '0',
    String bonus = '0',
  }) async {
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

  /// Все виды заводятся выключенными (задача 14), включает их оператор.
  /// Забудь одно движение — и проба мерила бы `payment_kind_inactive`, а
  /// не раскладку. Ровно та ловушка, о которой предупреждает
  /// `qr_with_prepayment_test`.
  Future<void> enableKinds() async {
    for (final id in const [
      SystemPaymentKindIds.certificate,
      SystemPaymentKindIds.qr,
      SystemPaymentKindIds.prepayment,
      SystemPaymentKindIds.bonus,
      SystemPaymentKindIds.debt,
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
    await enableKinds();
  });

  tearDown(() async => db.close());

  test('сертификат + аванс: урезан АВАНС, а не бумажка', () async {
    // Чек 1000, бумажка на 600, внесённый аванс 600. Комнаты хватает
    // ровно на одну из двух сумм, и выбор между ними — это и есть
    // порядок раскладки.
    //
    // Сертификат берёт комнату первым, потому что у него **есть срок**
    // (`GiftCertificates.expiresAt`), а у аванса срока нет ни одного.
    // Незачтённый аванс уйдёт в следующий чек целиком; неистраченная
    // бумажка может до следующего чека не дожить.
    await seedCustomer(advance: '600');
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('600'),
    );
    final view = await receiptWith(); // 2 × 500 = 1000

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('600'),
        prepaymentReference: 'АВ-7',
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(outcome.paid, d('1000'));
    expect(outcome.debt, Decimal.zero);
    expect(outcome.change, Decimal.zero);

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);

    final byCert = rows.singleWhere(
      (r) => r.kindId == SystemPaymentKindIds.certificate,
    );
    expect(
      byCert.amount,
      d('600'),
      reason: 'бумажка гасится целиком: у неё срок, у аванса — нет',
    );
    expect(byCert.reference, 'C-1');

    final byAdvance = rows.singleWhere(
      (r) => r.kindId == SystemPaymentKindIds.prepayment,
    );
    expect(
      byAdvance.amount,
      d('400'),
      reason: 'аванс добирает остаток ПОСЛЕ сертификата: 1000 − 600 = 400. '
          'Взяли бы обе задачи потолок `amount − bonus` порознь — вышло бы '
          'два зачёта по 600 и toPay = −200',
    );

    // I172 — вдобавок к полям, а не вместо них.
    expect(rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount), d('1000'));
    expect(rows.length, 2, reason: 'наличной строки на нулевую сдачу нет');

    // Бумажка погашена ровно один раз.
    expect((await cert('C-1')).balance, Decimal.zero);
    expect((await cert('C-1')).status, CertificateStatus.redeemed);
    // И счёт обязательства двинулся на то же число и в ту же сторону:
    // 600 → 0. Это и есть замер оговорки автора про общую ветвь зачёта.
    expect(
      await liabilityBalance(),
      Decimal.zero,
      reason: 'общая ветвь зачёта не переворачивает знак: обязательство '
          'уменьшилось, а не выросло до 1200',
    );
    // Незачтённые 200 остались авансом покупателя, а не сгорели.
    expect(await balanceOf(agentMainAccountId), d('200'));
    // Ни тенге живых денег: обе половины пришли раньше.
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  test('сертификат + QR: урезан СЕРТИФИКАТ, а не уже взятые деньги', () async {
    // Здесь порядок переворачивается, и это не противоречие, а то же
    // правило: первым берёт комнату тот, кого урезать дороже. Деньги QR
    // провайдер **уже взял**, и сдачи QR не даёт; урезанная строка QR
    // оставила бы заплаченное вне чека — «деньги взяты, документа нет».
    // Урезанная бумажка не теряет ничего сегодня: остаток на ней живёт.
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-2',
      nominal: d('600'),
    );
    await paidIntent('q-cert', '600');
    final view = await receiptWith(); // 1000

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.cash,
        qrIntentKey: 'q-cert',
        certificates: const [CertificateTender(number: 'C-2')],
      ),
      mv(view, 9),
    );

    expect(outcome.paid, d('1000'));
    expect(outcome.debt, Decimal.zero);

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    final qr = rows.singleWhere((r) => r.kindId == SystemPaymentKindIds.qr);
    expect(qr.amount, d('600'), reason: 'QR не урезается: деньги уже взяты');
    expect(qr.payeeAccountId, bankAccountId);

    final byCert = rows.singleWhere(
      (r) => r.kindId == SystemPaymentKindIds.certificate,
    );
    expect(
      byCert.amount,
      d('400'),
      reason: 'бумажка добирает остаток ПОСЛЕ QR: 1000 − 600 = 400',
    );

    expect(rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount), d('1000'));

    // Остаток бумажки — 200, и он живой: статус не `redeemed`.
    expect(
      (await cert('C-2')).balance,
      d('200'),
      reason: 'сдачи с сертификата нет — непогашенное остаётся на бумажке',
    );
    expect((await cert('C-2')).status, CertificateStatus.active);
    // Обязательство уменьшилось ровно на погашенное, а не на номинал.
    expect(await liabilityBalance(), d('200'));
    expect(await balanceOf(bankAccountId), d('600'));
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  test('сертификат + долг: остаток чека уходит В ДОЛГ, а не выдуман', () async {
    // Слагаемое `+ certificate` в расчёте `deferred` — то место, где
    // слияние трёх задач расходится молча. Забудь его — и покупателю,
    // отдавшему бумажку на 600, запишут в долг всю тысячу: строки чека
    // при этом сойдутся, `payment_unbalanced` промолчит, а долг будет
    // выдуман на 600.
    await seedCustomer();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-3',
      nominal: d('600'),
    );
    final view = await receiptWith(); // 1000

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.debt,
        customerId: customerId,
        certificates: const [CertificateTender(number: 'C-3')],
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(
      outcome.debt,
      d('400'),
      reason: 'в долг уходит только НЕПОКРЫТОЕ: 1000 − 600 = 400',
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    final debt = rows.singleWhere((r) => r.kindId == SystemPaymentKindIds.debt);
    expect(debt.amount, d('400'));
    expect(debt.payeeAccountId, agentMainAccountId);

    final byCert = rows.singleWhere(
      (r) => r.kindId == SystemPaymentKindIds.certificate,
    );
    expect(byCert.amount, d('600'));

    expect(rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount), d('1000'));

    // Счёт покупателя ушёл в минус ровно на долг, а не на сумму чека.
    expect(
      await balanceOf(agentMainAccountId),
      d('-400'),
      reason: 'обязательство сертификата — не долг покупателя: пропусти '
          'слагаемое, и здесь было бы −1000',
    );
    expect((await cert('C-3')).balance, Decimal.zero);
    expect(await liabilityBalance(), Decimal.zero);
  });

  test('все четыре зачёта на одном чеке: цепочка потолков, а не четыре '
      'независимых', () async {
    // Чек 1000. Бонус 300, QR 300, бумажка 300, аванс 300 — вместе 1200,
    // то есть на 200 больше комнаты. Считай каждый потолок от
    // `amount − bonus`, как делали все три автора порознь, — и вышло бы
    // `toPay = 1000 − 300 − 300 − 300 − 300 = −200`.
    //
    // Порядок берёт своё: бонус, QR и бумажка проходят целиком, аванс
    // добирает 100 и оставляет 200 на счёте покупателя.
    await seedCustomer(advance: '300', bonus: '300');
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-4',
      nominal: d('300'),
    );
    await paidIntent('q-all', '300');
    final view = await receiptWith(); // 1000

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        bonusUsed: d('300'),
        qrIntentKey: 'q-all',
        prepaymentUsed: d('300'),
        prepaymentReference: 'АВ-9',
        certificates: const [CertificateTender(number: 'C-4')],
      ),
      mv(view, 9),
    );

    expect(outcome.paid, d('1000'));
    expect(outcome.debt, Decimal.zero);
    expect(outcome.change, Decimal.zero);

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    Decimal amountOf(int kindId) =>
        rows.singleWhere((r) => r.kindId == kindId).amount;

    expect(amountOf(SystemPaymentKindIds.bonus), d('300'));
    expect(amountOf(SystemPaymentKindIds.qr), d('300'));
    expect(amountOf(SystemPaymentKindIds.certificate), d('300'));
    expect(
      amountOf(SystemPaymentKindIds.prepayment),
      d('100'),
      reason: 'последний в порядке добирает ОСТАТОК: 1000−300−300−300 = 100',
    );

    expect(rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount), d('1000'));

    expect((await cert('C-4')).balance, Decimal.zero);
    expect(await liabilityBalance(), Decimal.zero);
    expect(await balanceOf(bankAccountId), d('300'));
    // Бонус ведает журнал, а не счёт: 300 списаны записью, счёт следом.
    expect(await balanceOf(bonusAccountId), Decimal.zero);
    // Незачтённые 200 аванса остались покупателю.
    expect(await balanceOf(agentMainAccountId), d('200'));
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  test('две бумажки и наличные: обязательство падает на сумму ОБЕИХ', () async {
    // Общая ветвь зачёта зовёт `claimCredit` **по строке**, и обе строки
    // идут на один и тот же счёт обязательства. Условная запись читает
    // остаток заново на каждом обороте — если бы она читала его один раз,
    // вторая бумажка либо не прошла бы, либо стёрла бы первую.
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-5',
      nominal: d('600'),
    );
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-6',
      nominal: d('300'),
    );
    final view = await receiptWith(); // 1000

    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('100'),
        certificates: const [
          CertificateTender(number: 'C-5'),
          CertificateTender(number: 'C-6'),
        ],
      ),
      mv(view, 9),
    );

    expect(outcome.paid, d('1000'));
    expect(outcome.change, Decimal.zero);

    expect((await cert('C-5')).balance, Decimal.zero);
    expect((await cert('C-6')).balance, Decimal.zero);
    expect(
      await liabilityBalance(),
      Decimal.zero,
      reason: 'было 900 (600 + 300), погашено 900 — обе строки прошли',
    );
    expect(
      await balanceOf(posAccountId),
      d('100'),
      reason: 'в ящик легли только настоящие наличные',
    );
  });
}
