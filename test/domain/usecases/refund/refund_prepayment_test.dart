/// Возврат чека, закрытого зачётом аванса — задача 23.
///
/// # Решение: аванс возвращается АВАНСОМ, а не деньгами
///
/// Три довода, и первый из них денежный.
///
/// **Этих денег в ящике нет.** Они пришли раньше — может быть, в другую
/// смену, может быть, в другой день, — и на этом чеке касса их не
/// получала. Выдать их из ящика значило бы повторить дефект, который
/// задача 14 чинила у обязательства: из ящика выходит то, что в него не
/// входило. Замер там был такой: чек на 1000, оплаченный 400 наличными и
/// 600 в долг, отдавал из ящика 1000.
///
/// **Выдача аванса — свой документ.** Возврат товара и возврат денег
/// покупателю — два разных события у оператора, и склеивать их значит
/// выдавать наличные без документа на выдачу. Покупателю, которому нужны
/// деньги, а не остаток, их выдаёт та же операция расчёта с
/// контрагентом, какой аванс и вносился.
///
/// **Обратимость.** Восстановленный аванс можно выдать деньгами;
/// выданные деньги обратно в аванс не соберёшь, а кассир ошибается на
/// возвратах чаще, чем на продажах.
///
/// # Что здесь считается числами
///
/// Настоящая база, настоящая корзина, настоящий `LocalPaymentService`,
/// настоящий `SaleUseCaseImpl` и настоящий `RefundUseCaseImpl`. Подставлен
/// только фискальный узел, которого в этой кассе нет.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/agent/bonus_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import '../../../helpers/cash_drawer.dart';

class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late LocalPaymentService payments;
  late Talker logger;

  const barcodeA = '4870001234567';

  const posAccountId = 11;
  const cashbackAccountId = 13;
  const agentMainAccountId = 14;
  const customerId = 5;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

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
    await seedAccount(cashbackAccountId, AccountType.agentCashback);
    await seedAccount(agentMainAccountId, AccountType.agentMain);
    await db
        .into(db.agents)
        .insert(
          AgentsCompanion.insert(
            localId: const Value(customerId),
            name: const Value('Айгүл Дүйсенова'),
            phone: const Value(77015550000),
            cashbackAccountId: const Value(cashbackAccountId),
            mainAccountId: const Value(agentMainAccountId),
          ),
        );
  }

  /// Чек на 1000: две штуки по 500.
  Future<CartView> receipt() async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.setQuantity(7, view.lines.single.id, d('2'), mv(view, 3));
    return view;
  }

  Future<int> refundWhole(int receiptNo, {int? customerLocalId}) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: 4, time: 2000));
    final refundId = (await db.select(db.refunds).get()).last.localId;

    await RefundUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: const RefusingFiscalService(),
    ).perform(
      refundLocalId: refundId,
      amount: d('1000'),
      userId: 4,
      saleReceiptNo: receiptNo,
      salePosId: 1,
      customerLocalId: customerLocalId,
      products: const [],
    );
    return refundId;
  }

  Future<void> boot() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            cashBoxName: Value('Касса 1'),
            companyName: Value('ТОО Ромашка'),
            // На этой кассе в долг торгуют — иначе продажи в долг не
            // будет вовсе, и мерить станет нечего.
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
            name: 'Кофе',
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
    checkout = LocalSaleCheckoutService(db: db, cart: cart, logger: logger);
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      bonuses: BonusServiceImpl(db: db),
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  }

  setUp(() {
    GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await GetIt.I.unregister<RefundProductService>();
    await db.close();
  });

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

  /// Включить вид «Предоплата»: справочник заводит его выключенным.
  Future<void> enablePrepayment() async {
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.prepayment,
      ).copyWith(isActive: true),
    );
  }

  /// Чек на 1000: 400 наличными и 600 зачётом аванса.
  Future<CartView> paidWithAdvance() async {
    await enablePrepayment();
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('400'),
        customerId: customerId,
        prepaymentUsed: d('600'),
        prepaymentReference: 'АВ-7',
      ),
      mv(view, 9),
    );
    await payments.pendingSideEffects;
    return view;
  }

  group('возврат чека, закрытого зачётом аванса', () {
    test('аванс восстанавливается, ящик отдаёт только свои 400', () async {
      await boot();
      await seedCustomer();
      await db.accountDao.updateBalance(agentMainAccountId, d('600'));

      final view = await paidWithAdvance();

      expect(await balanceOf(posAccountId), d('400'), reason: 'в ящик 400');
      expect(
        await balanceOf(agentMainAccountId),
        Decimal.zero,
        reason: 'аванс израсходован',
      );

      await refundWhole(view.receiptNo!, customerLocalId: customerId);

      // **Несущее утверждение работы.** Ящик отдаёт ровно то, что в него
      // клали на этом чеке.
      expect(
        await balanceOf(posAccountId),
        Decimal.zero,
        reason: 'вернули ровно те 400, что брали наличными',
      );
      expect(
        await balanceOf(agentMainAccountId),
        d('600'),
        reason: 'аванс вернулся авансом: 600 снова доступны покупателю',
      );
    });

    test('восстановленный аванс можно зачесть снова', () async {
      // Ради этого решение и принято: остаток остаётся деньгами
      // покупателя у кассы, а не превращается в наличные, которых в
      // ящике нет.
      await boot();
      await seedCustomer();
      await db.accountDao.updateBalance(agentMainAccountId, d('600'));

      final first = await paidWithAdvance();
      await refundWhole(first.receiptNo!, customerLocalId: customerId);

      final second = await receipt();
      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('400'),
          customerId: customerId,
          prepaymentUsed: d('600'),
        ),
        mv(second, 19),
      );
      await payments.pendingSideEffects;

      expect(await balanceOf(agentMainAccountId), Decimal.zero);
      final rows = await db.paymentDao.findBySale(second.receiptNo!, 1);
      expect(
        rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount),
        d('1000'),
      );
    });

    test('строка сторно у зачёта есть, и она несёт тот же вид', () async {
      await boot();
      await seedCustomer();
      await db.accountDao.updateBalance(agentMainAccountId, d('600'));

      final view = await paidWithAdvance();
      final refundId = await refundWhole(
        view.receiptNo!,
        customerLocalId: customerId,
      );

      final rows = await db.paymentDao.findByRefund(refundId);
      expect(rows.map((p) => p.amount).toList(), [d('-400'), d('-600')]);
      expect(rows.map((p) => p.kindId).toList(), [
        SystemPaymentKindIds.cash,
        SystemPaymentKindIds.prepayment,
      ]);
      expect(
        rows.map((p) => p.seq).toList(),
        [0, 1],
        reason: 'ключ {refundLocalId, seq} держится нумерацией от нуля',
      );
    });
  });
}
