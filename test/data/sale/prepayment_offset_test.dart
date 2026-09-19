import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
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
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

/// Предоплата — задача 23.
///
/// # Два события, а не одно
///
/// Аванс — деньги, полученные **до** отгрузки и зачтённые **потом**.
/// Значит событий два, и деньги приходят в первом, а чек выписывается во
/// втором:
///
/// 1. **приём аванса** — покупатель вносит деньги, и они ложатся на его
///    расчётный счёт (`AccountType.agentMain`) в плюс. Это делает
///    `CustomerPaymentUseCase` с решением
///    `CustomerPaymentDecision.investment` — путь, который в дереве уже
///    есть и которым эта задача не занимается;
/// 2. **зачёт аванса** — строка `Payments` вида
///    [SystemPaymentKindIds.prepayment] (`PaymentSettlement.offset`) на
///    том же счёте. Живых денег в кассу она не приносит: они пришли
///    раньше.
///
/// # Почему ни своей таблицы, ни своего остатка
///
/// Остаток аванса — это **кредитовое сальдо расчётного счёта
/// покупателя**, то есть ровно тот же счёт, который уходит в минус при
/// продаже в долг. Плюс — покупатель внёс вперёд, минус — покупатель
/// должен. Заводить второй остаток под то же число значило бы завести
/// вторую правду, расходящуюся с первой при первой же операции, которую
/// забыли продублировать.
///
/// # Чего эта работа НЕ сводит
///
/// `ServiceOrders.prepaymentAmount` (`service_order_tables.dart:40`) —
/// **совпадение слова, а не смысла**, и сводить их эта задача не
/// берётся. Измерено чтением
/// `service_order_transition_use_case_impl.dart:190-230`: закрытие
/// заказ-наряда пишет `Sales.amount = totalCost − prepaid`, то есть чек
/// на **остаток**, одну строку `Payments` без `kindId` — и аванс там не
/// зачитывается вовсе, а молча уменьшает сумму чека. Это отдельная беда
/// отдельной подсистемы; здесь она названа, чтобы следующий читатель не
/// принял зелень этих проб за утверждение о заказ-нарядах.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const bankAccountId = 12;
  const agentMainAccountId = 14;
  const cashbackAccountId = 13;
  const customerId = 5;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

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

  /// Покупатель, внёсший [advance] вперёд.
  ///
  /// Плюс на расчётном счёте — и есть аванс: ровно то, что оставляет
  /// `CustomerPaymentUseCase` с решением `investment`.
  Future<void> seedCustomerWithAdvance(String advance) async {
    await seedAccount(agentMainAccountId, AccountType.agentMain,
        value: advance);
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(customerId),
            name: Value('Айгуль'),
            phone: Value(77015550000),
            mainAccountId: Value(agentMainAccountId),
          ),
        );
  }

  Future<CartView> receiptWith({int quantity = 1, int terminalId = 7}) async {
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

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  /// Включить вид «Предоплата»: справочник заводит его выключенным, и это
  /// решение оператора, а не кассы.
  Future<void> enablePrepayment() async {
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.prepayment,
      ).copyWith(isActive: true),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
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
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() async => db.close());

  test('зачёт аванса — строка оплаты со своим видом, а не скидка', () async {
    await enablePrepayment();
    await seedCustomerWithAdvance('600');
    final view = await receiptWith(quantity: 2); // 1000

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('400'),
        customerId: customerId,
        prepaymentUsed: d('600'),
        prepaymentReference: 'АВ-1',
      ),
      mv(view, 9),
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);

    // **Утверждение о самих полях, а не о сумме.** Баланс сумм зелен и
    // тогда, когда зачёт уехал на счёт кассы наличными: сложение об этом
    // не скажет ни слова.
    final offset = rows.singleWhere(
      (r) => r.kindId == SystemPaymentKindIds.prepayment,
    );
    expect(offset.amount, d('600'));
    expect(
      offset.payeeAccountId,
      agentMainAccountId,
      reason: 'зачёт уменьшает обязательство перед покупателем, а не '
          'кладёт деньги в кассу',
    );
    expect(offset.customerLocalId, customerId);
    expect(offset.reference, 'АВ-1', reason: 'документ-основание назван');

    final cash = rows.singleWhere(
      (r) => r.kindId == SystemPaymentKindIds.cash,
    );
    expect(cash.amount, d('400'));
    expect(cash.payeeAccountId, posAccountId);

    // I172 — и он проверяется отдельно от полей, а не вместо них.
    expect(
      rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount),
      d('1000'),
    );
    expect(rows.map((r) => r.seq).toList()..sort(), [0, 1]);

    // Живых денег зачёт не приносит: в ящике только те 400, что дал
    // покупатель.
    expect(await balanceOf(posAccountId), d('400'));
    // Аванс израсходован целиком.
    expect(await balanceOf(agentMainAccountId), Decimal.zero);
  });

  test('остаток аванса остаётся авансом, а не превращается в сдачу', () async {
    await enablePrepayment();
    await seedCustomerWithAdvance('1000');
    final view = await receiptWith(); // 500

    final result = await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('1000'),
      ),
      mv(view, 9),
    );

    expect(
      result.change,
      Decimal.zero,
      reason: 'сдача с аванса — способ обналичить чужие деньги',
    );
    expect(
      await balanceOf(agentMainAccountId),
      d('500'),
      reason: 'непотраченные 500 остаются авансом покупателя',
    );
    expect(await balanceOf(posAccountId), Decimal.zero);

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(rows, hasLength(1));
    expect(rows.single.amount, d('500'));
    expect(rows.single.kindId, SystemPaymentKindIds.prepayment);
  });

  test('зачесть больше внесённого нельзя — потолок ставит касса', () async {
    await enablePrepayment();
    await seedCustomerWithAdvance('300');
    final view = await receiptWith(quantity: 2); // 1000

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('700'),
        customerId: customerId,
        prepaymentUsed: d('1000'),
      ),
      mv(view, 9),
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(
      rows
          .singleWhere((r) => r.kindId == SystemPaymentKindIds.prepayment)
          .amount,
      d('300'),
      reason: 'заявка терминала просила 1000 — внесено было 300',
    );
    expect(
      rows.singleWhere((r) => r.kindId == SystemPaymentKindIds.cash).amount,
      d('700'),
    );
    expect(await balanceOf(agentMainAccountId), Decimal.zero);
  });

  test('вид, выключенный оператором, зачёта не даёт', () async {
    // Справочник заводит предоплату выключенной, и `enablePrepayment`
    // здесь намеренно не зовётся.
    await seedCustomerWithAdvance('600');
    final view = await receiptWith(quantity: 2);

    await expectLater(
      payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('400'),
          customerId: customerId,
          prepaymentUsed: d('600'),
        ),
        mv(view, 9),
      ),
      throwsA(isA<WireRefusal>()),
    );
    expect(
      await balanceOf(agentMainAccountId),
      d('600'),
      reason: 'отказ приходит до единой записи',
    );
  });

  test('конверт оператора не теряет зачтённый аванс', () async {
    // Задача 7 измерила это на бонусе: строка оплаты, которую конверт не
    // считает ни наличными, ни картой, даёт позиции на 1000 при платежах
    // на 400 — оператор отвергает чек кодом 9, и **каждая** такая
    // продажа становится «деньги взяты, документа нет».
    //
    // Проверяется не «позвали фискализацию», а **сами числа конверта**:
    // равенство сумм здесь и есть предмет, а не побочная страховка.
    await enablePrepayment();
    await seedCustomerWithAdvance('600');

    final logger = Talker();
    final spy = _SpyFiscal();
    final withSpy = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: spy,
      drawer: drawerOpens,
    );

    final view = await receiptWith(quantity: 2); // 1000
    await withSpy.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('400'),
        customerId: customerId,
        prepaymentUsed: d('600'),
      ),
      mv(view, 9),
    );

    expect(spy.calls, hasLength(1));
    final call = spy.calls.single;
    expect(call.amount, d('1000'));
    expect(
      call.cash + call.card + call.mobile + call.bonus + call.offset,
      d('1000'),
      reason: 'позиций на 1000, а конверт объяснил только '
          '${call.cash + call.card + call.mobile + call.bonus + call.offset} — '
          'оператор отвергнет чек кодом 9',
    );
    // **Решение задачи 23 («аванс признаётся выручкой здесь и впервые»)
    // отменено заказчиком 2026-09-14.** Приём аванса даёт свой фискальный
    // чек (настройка, по умолчанию вкл), значит выручку по ККМ признал уже
    // он, и зачёт наличными на чеке отгрузки — двойная выручка.
    expect(
      call.cash,
      d('400'),
      reason: 'оператор видит наличных ровно столько, сколько в ящике',
    );
    expect(
      call.offset,
      d('600'),
      reason: 'аванс — зачёт, а не оплата',
    );
    expect(call.bonus, Decimal.zero);
  });

  test('зачёт вместе с картой — и здесь сторожит payment_unbalanced', () async {
    // # Зачем именно карта
    //
    // Задача 14 оставила ветку `payment_unbalanced` сторожем
    // **следующего вида оплаты**: «первая же забытая строка „вычесть из
    // остатка" даст чек, у которого сумма строк больше суммы». Аванс —
    // тот самый следующий вид, и предсказание проверено диверсией
    // (`toPay = amount - bonus`, без вычитания аванса).
    //
    // Результат замера оказался не тем, что ожидалось, и записан как
    // есть: на **наличном** чеке диверсия падает раньше и на другом
    // отказе — `payment_insufficient` («наличных меньше суммы»), потому
    // что нехватка наличных считается до сверки. На **безналичном**
    // чеке достаточности наличных не спрашивают вовсе, и до сверки
    // диверсия доходит.
    //
    // Отсюда эта проба: без неё сторож, ради которого ветку сохранили,
    // остался бы непроверенным для того самого вида, ради которого его
    // берегли.
    await enablePrepayment();
    await seedCustomerWithAdvance('600');
    final view = await receiptWith(quantity: 2); // 1000

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.card,
        accountId: bankAccountId,
        approvalCode: '000000',
        customerId: customerId,
        prepaymentUsed: d('600'),
      ),
      mv(view, 9),
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(
      rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount),
      d('1000'),
    );
    expect(
      rows.singleWhere((r) => r.kindId == SystemPaymentKindIds.card).amount,
      d('400'),
      reason: 'картой берут остаток после зачёта, а не всю сумму',
    );
    expect(await balanceOf(bankAccountId), d('400'));
    expect(await balanceOf(agentMainAccountId), Decimal.zero);
  });

  test('должнику зачитывать нечего — строки зачёта не появляется', () async {
    // Правило нуля, и оно здесь **денежное**: на расчётном счёте
    // покупателя плюс значит «внёс вперёд», минус — «должен». Зачесть
    // минус значило бы уменьшить чек на долг покупателя, то есть
    // подарить ему товар за то, что он уже должен.
    await enablePrepayment();
    await seedCustomerWithAdvance('-500');
    final view = await receiptWith(quantity: 2); // 1000

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('1000'),
        customerId: customerId,
        prepaymentUsed: d('600'),
      ),
      mv(view, 9),
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(
      rows.where((r) => r.kindId == SystemPaymentKindIds.prepayment),
      isEmpty,
      reason: 'зачёт долга — это подарок товара, а не оплата',
    );
    expect(rows.single.amount, d('1000'));
    expect(await balanceOf(posAccountId), d('1000'));
    expect(
      await balanceOf(agentMainAccountId),
      d('-500'),
      reason: 'долг остался тем же: чек его не трогал',
    );
  });

  test('аванс и бонус вместе не берут с покупателя дважды', () async {
    await enablePrepayment();
    await seedCustomerWithAdvance('1000');
    await seedAccount(cashbackAccountId, AccountType.agentCashback,
        value: '300');
    await (db.update(db.agents)..where((a) => a.localId.equals(customerId)))
        .write(const AgentsCompanion(
      cashbackAccountId: Value(cashbackAccountId),
    ));

    final view = await receiptWith(quantity: 2); // 1000

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        bonusUsed: d('300'),
        prepaymentUsed: d('1000'),
      ),
      mv(view, 9),
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(
      rows
          .singleWhere((r) => r.kindId == SystemPaymentKindIds.prepayment)
          .amount,
      d('700'),
      reason: 'потолок аванса — остаток ПОСЛЕ бонуса: зачесть авансом то, '
          'что уже покрыто бонусом, значит взять с покупателя дважды',
    );
    expect(
      rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount),
      d('1000'),
    );
    expect(await balanceOf(agentMainAccountId), d('300'));
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  test('аванс без покупателя не зачитывается', () async {
    await enablePrepayment();
    final view = await receiptWith(quantity: 2);

    await expectLater(
      payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('400'),
          prepaymentUsed: d('600'),
        ),
        mv(view, 9),
      ),
      throwsA(isA<WireRefusal>()),
    );
  });
}


/// Соглядатай за конвертом: запоминает **числа**, отданные оператору.
class _SpyFiscal implements FiscalService {
  final List<_Envelope> calls = [];

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  }) async {
    calls.add(
      _Envelope(
        amount: amount,
        cash: cashAmount,
        card: cardAmount,
        mobile: mobileAmount,
        bonus: bonusAmount,
        offset: offsetAmount,
      ),
    );
    return const FiscalResult(success: true, fiscalSign: 'ФП-1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _Envelope {
  const _Envelope({
    required this.amount,
    required this.cash,
    required this.card,
    required this.mobile,
    required this.bonus,
    required this.offset,
  });

  final Decimal amount;
  final Decimal cash;
  final Decimal card;
  final Decimal mobile;
  final Decimal bonus;

  /// Зачёт — не оплата (решение заказчика 2026-09-14).
  final Decimal offset;
}
