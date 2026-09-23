import 'dart:async';

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
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/sale/receipt_line.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

/// Один аванс дважды не зачитывается — задача 23.
///
/// # Почему `Future.wait` здесь ничего не доказал бы
///
/// Тот же довод, что и в `payment_claim_race_test.dart`, и он там
/// **измерен**: drift на одном соединении выстраивает запросы в очередь,
/// и одновременность на уровне `Future` до настоящего чередования
/// «прочитал → записал» не доводит. Гонка разводится во времени на шве,
/// объявленном самим продуктом: `SaleUseCase` — довод конструктора
/// `LocalPaymentService`, ровно как драйвер платёжного терминала.
///
/// # Расписание
///
/// 1. первый чек разложен: касса прочитала остаток аванса (1000) и
///    встала **перед** записью денег ([_GatedSaleUseCase]);
/// 2. второй чек — **другой чек, тот же покупатель** — раскладывается и
///    видит **тот же** остаток: списать ещё никто не успел. Он проходит
///    целиком, и аванса не остаётся;
/// 3. первого отпускают, и он идёт списывать уже списанное, держа в
///    руках прочитанный до списания остаток.
///
/// Второй шаг — то, ради чего условная запись существует. Без неё оба
/// чека зачли бы по 1000 с внесённой тысячи, и счёт покупателя ушёл бы
/// в −1000, то есть в долг, которого он не брал.
///
/// # Отличие от гонки задачи 8
///
/// Там гонщики дрались за **один чек**, и от второго взятия денег их
/// прикрывал бы (частично) уникальный ключ `Payments`. Здесь чеки
/// **разные**, ключ молчит по построению, и прикрывать нечему: без
/// условной записи беда проходит целиком.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late _GatedSaleUseCase gate;

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

  Future<CartView> receiptOn(int terminalId, int n) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(n, 0),
    );
    view = await cart.addByBarcode(terminalId, barcodeA, mv(view, n + 1));
    view = await cart.setQuantity(
      terminalId,
      view.lines.single.id,
      d('2'),
      mv(view, n + 2),
    );
    return view;
  }

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

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
    await seedAccount(agentMainAccountId, AccountType.agentMain, value: '1000');
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
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.prepayment,
      ).copyWith(isActive: true),
    );

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
    gate = _GatedSaleUseCase(db: db, logger: logger);
    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: gate,
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    if (gate.holdFirst && !gate.released) gate.release();
    await db.close();
  });

  test('второй чек не зачитывает тот же аванс', () async {
    final viewA = await receiptOn(7, 1);
    final viewB = await receiptOn(8, 20);
    gate.holdFirst = true;

    // Первый: разложился (прочитал остаток 1000) и встал перед записью.
    final first = payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('1000'),
      ),
      mv(viewA, 9),
    );
    await gate.atDoor;
    expect(
      await balanceOf(agentMainAccountId),
      d('1000'),
      reason: 'страховка от вырождения: аванс ещё не тронут',
    );

    // Второй читает **тот же** остаток и проходит целиком.
    await payments.complete(
      8,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('1000'),
      ),
      mv(viewB, 29),
    );
    expect(await balanceOf(agentMainAccountId), Decimal.zero);

    // Первого отпускают — списывать уже списанное.
    gate.release();
    Object? refusal;
    try {
      await first;
    } catch (e) {
      refusal = e;
    }

    // Деньги — первым утверждением: беда именно в них.
    expect(
      await balanceOf(agentMainAccountId),
      Decimal.zero,
      reason:
          'счёт покупателя ушёл в минус — аванс зачтён дважды, и '
          'покупателю записан долг, которого он не брал',
    );

    final claimed = await (db.select(
      db.payments,
    )..where((p) => p.kindId.equals(SystemPaymentKindIds.prepayment))).get();
    expect(
      claimed.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount),
      d('1000'),
      reason: 'с внесённой тысячи зачтено больше тысячи',
    );
    expect(claimed, hasLength(1));

    expect(
      refusal,
      isA<WireRefusal>().having(
        (e) => e.code,
        'code',
        payPrepaymentInsufficientCode,
      ),
      reason: 'второй обязан получить названный отказ, а не пройти',
    );

    // Транзакция отката: у первого чека нет ни строк оплаты, ни списания
    // остатка. Иначе товар ушёл бы за деньги, которых нет.
    expect(await db.paymentDao.countBySale(viewA.receiptNo!, 1), 0);
    expect(
      (await db.productInfoDao.findByUcode(100))?.quantity,
      d('98'),
      reason: 'остаток списан по одному чеку, а не по двум',
    );
  });

  test('условная запись не даёт списать больше остатка и в одиночку', () async {
    // Обратная сторона: без всякой гонки списание сверх остатка обязано
    // не состояться, а не увести счёт в минус.
    expect(
      await db.accountDao.claimCredit(agentMainAccountId, d('1500')),
      isFalse,
    );
    expect(await balanceOf(agentMainAccountId), d('1000'));

    expect(
      await db.accountDao.claimCredit(agentMainAccountId, d('1000')),
      isTrue,
    );
    expect(await balanceOf(agentMainAccountId), Decimal.zero);

    expect(
      await db.accountDao.claimCredit(agentMainAccountId, d('0.001')),
      isFalse,
    );
    expect(await balanceOf(agentMainAccountId), Decimal.zero);
  });
}

/// `SaleUseCase`, который останавливает **первый** `perform`.
///
/// Шов объявлен продуктом: `SaleUseCase` — довод конструктора
/// `LocalPaymentService`. Работу делает настоящий [SaleUseCaseImpl];
/// подделано только расписание.
class _GatedSaleUseCase extends SaleUseCaseImpl {
  _GatedSaleUseCase({required super.db, required super.logger});

  final _atDoor = Completer<void>();
  final _hold = Completer<void>();

  Future<void> get atDoor => _atDoor.future;

  bool get released => _hold.isCompleted;

  void release() => _hold.complete();

  bool holdFirst = false;

  var _seen = 0;

  @override
  Future<void> perform({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required List<ReceiptLine> lines,
    required List<PaymentEntry> payments,
    required Decimal change,
    required bool selectiveOfd,
    String? customerBin,
    int? agentLocalId,
    int? agentServerId,
    List<CustomFieldEntry>? customFields,
    WithdrawalEntry? withdrawal,
    CreditContractDraft? credit,
  }) async {
    final n = _seen++;
    if (n == 0 && holdFirst) {
      _atDoor.complete();
      await _hold.future;
    }
    return super.perform(
      receiptNo: receiptNo,
      posId: posId,
      amount: amount,
      lines: lines,
      payments: payments,
      change: change,
      selectiveOfd: selectiveOfd,
      customerBin: customerBin,
      agentLocalId: agentLocalId,
      agentServerId: agentServerId,
      customFields: customFields,
      withdrawal: withdrawal,
      credit: credit,
    );
  }
}
