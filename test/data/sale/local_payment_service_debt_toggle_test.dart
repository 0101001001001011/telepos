import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
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
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

/// Тумблер кассы «продажа в кредит» — задача 16.
///
/// # Зачем эти пробы существуют отдельно от соседа
///
/// `ThisPosEntries.sellInDebt` завёл мастер настройки, и до этой задачи у
/// колонки было **ноль читателей** во всём `lib/`: тумблер писался и не
/// значил ничего. Здесь у него появляется читатель, который не экран, —
/// и это принципиально. Тумблер, который читает только экран, защищён
/// ровно настолько, насколько трудно собрать кадр руками, то есть никак
/// (I44, I162).
///
/// # Тумблер кассы и право кассира — разные вещи, и проверяются обе
///
/// `sellInDebt` отвечает «здесь вообще торгуют в долг», `op.sellDebt` —
/// «этому человеку можно». Право сторожит провод до вызова обработчика
/// (`PayOps.payExtraPermissions`, пробы — `pay_ops_access_test.dart`), и
/// эти пробы его не дублируют: сюда кадр приходит уже пропущенным
/// сторожем, а тумблер сторож не видит вовсе — он не знает базы кассы.
/// Подмени одно другим — и касса, где кредита нет, продаст в долг любому
/// администратору, у которого право есть по должности.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const agentMainAccountId = 14;
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

  Future<void> seedCustomer() async {
    await seedAccount(agentMainAccountId, AccountType.agentMain);
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

  /// Включить продажу в кредит на этой кассе — то, что делает тумблер
  /// мастера настройки («Разрешить продажу в кредит»).
  Future<void> allowDebtSales() async {
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(sellInDebt: Value(true)),
    );
  }

  Future<CartView> receiptWith({int quantity = 2, int terminalId = 7}) async {
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
    // `sellInDebt` здесь **не назван** намеренно: умолчание колонки —
    // `false`, и это то состояние, в котором касса выходит из мастера
    // настройки с выключенным тумблером.
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
  });

  tearDown(() async {
    await db.close();
  });

  group('касса, где в долг не торгуют', () {
    test('долг отвергается названным отказом, а не молча', () async {
      await seedCustomer();
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.debt, customerId: customerId),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payDebtNotSoldHereCode,
          ),
        ),
      );
    });

    test('ни товара, ни строки оплаты, ни движения по счетам', () async {
      await seedCustomer();
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.debt,
            cashReceived: d('300'),
            customerId: customerId,
          ),
          mv(view, 9),
        ),
        throwsA(isA<WireRefusal>()),
      );

      // Отказ обязан быть **до** денег: чек в работе, остаток цел, долг
      // никуда не записан.
      expect((await db.saleDao.findByKey(view.receiptNo!, 1))!.state, 0);
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      expect(
        (await db.productInfoDao.findByUcode(100))!.quantity,
        d('100'),
        reason: 'товар не отдан',
      );
      expect(
        (await db.accountDao.findById(agentMainAccountId))!.value,
        Decimal.zero,
      );
      expect(
        (await db.accountDao.findById(posAccountId))!.value,
        Decimal.zero,
        reason: 'наличная часть долга тоже не взята',
      );
    });

    test('тумблер выключен — касса так и отвечает', () async {
      expect(await payments.sellsInDebt(), isFalse);
    });

    test('остальные виды оплаты тумблер не трогает', () async {
      final view = await receiptWith();

      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      expect(
        outcome.paid,
        d('1000'),
        reason: 'выключенный кредит не запрещает наличные',
      );
    });
  });

  group('касса, где в долг торгуют', () {
    test('тумблер включён — касса так и отвечает', () async {
      await allowDebtSales();
      expect(await payments.sellsInDebt(), isTrue);
    });

    test('долг проходит и ложится на баланс покупателя', () async {
      await allowDebtSales();
      await seedCustomer();
      final view = await receiptWith(); // 1000

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.debt,
          cashReceived: d('300'),
          customerId: customerId,
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('300'));
      expect(outcome.debt, d('700'));

      // **Дырка, закреплённая здесь числом, закрыта задачей 14 — и
      // закрытие видно как изменение этой пробы, а не как молчание.**
      //
      // Прежняя редакция ждала `[300]` и объясняла почему: у долга не
      // было строки оплаты вовсе, он выводился разностью «сумма чека
      // минус сумма платежей», и семисот не было в `Payments` ни одной
      // строкой. Инвариант «Σ строк оплаты == сумма чека» был нарушен у
      // каждой продажи в долг.
      //
      // Теперь строк две: наличная и долговая. Долговая несёт вид
      // `debt` (`PaymentSettlement.deferred`) и лежит на **расчётном
      // счёте покупателя**.
      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows.map((p) => p.amount).toList(), [d('300'), d('700')]);
      expect(rows.map((p) => p.kindId).toList(), [
        SystemPaymentKindIds.cash,
        SystemPaymentKindIds.debt,
      ]);
      expect(
        rows.map((p) => p.seq).toList(),
        [0, 1],
        reason:
            'нумерация от нуля на каждой попытке — иначе новый ключ '
            '`{receiptNo, posId, seq}` становится украшением молча',
      );
      expect(
        rows
            .firstWhere((p) => p.kindId == SystemPaymentKindIds.debt)
            .payeeAccountId,
        agentMainAccountId,
      );

      // Σ строк оплаты == сумма чека. Ради этого равенства всё и делалось.
      expect(
        rows.fold(Decimal.zero, (Decimal sum, p) => sum + p.amount),
        d('1000'),
      );

      // **Остаток не изменился ни на копейку, и это главное.** Одна
      // правка меняет форму записи и не двигает ни одного счёта: долг
      // как был −700, так и остался. Строка оплаты рода `deferred`
      // обычным движением по счёту не проводится — `post(+700)` дал бы
      // покупателю переплату вместо задолженности.
      expect(
        (await db.accountDao.findById(agentMainAccountId))!.value,
        d('-700'),
      );
    });

    test('включённый тумблер не отменяет требования покупателя', () async {
      await allowDebtSales();
      final view = await receiptWith();

      // Требование 3 задачи: молча брать «никого» нельзя — это деньги,
      // отданные в никуда. Тумблер разрешает вид оплаты, а не безымянного
      // должника.
      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.debt),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payDebtorRequiredCode,
          ),
        ),
      );
    });
  });

  group('касса без строки настроек вовсе', () {
    // Достижимо: `ThisPosEntries` пуста до мастера настройки, а
    // `LocalPaymentService` живёт с первой минуты. Умолчание обязано
    // быть тем, которое ничего не разрешает.
    test('нет строки — в долг не продают', () async {
      await db.delete(db.thisPosEntries).go();
      expect(await payments.sellsInDebt(), isFalse);
    });
  });
}
