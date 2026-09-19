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
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import '../../../helpers/cash_drawer.dart';

/// Знак движения по бонусному счёту — задача 10.
///
/// # Что здесь доказывается числами, а не чтением
///
/// Две зеркальные порчи денег покупателя, обе на настоящем коде:
/// настоящая база, настоящая корзина, настоящий [LocalPaymentService],
/// настоящий [SaleUseCaseImpl] и настоящий [RefundUseCaseImpl]. Подставлен
/// только фискальный узел, которого в этой кассе нет.
///
/// 1. **Списанные бонусы списываются второй раз.** Продажа знает про
///    бонусный счёт (`sale_use_case_impl.dart`, ветка
///    `isCashbackRedemption`), а возврат вычитает **единообразно по всем
///    счетам получателя** (`refund_use_case_impl.dart`,
///    `_createReversalPayments`). Покупатель платит бонусами, возвращает
///    товар — и теряет их ещё раз.
///
/// 2. **Начисленный кэшбэк при возврате не сторнируется никогда.** Возврат
///    трогает расчётные счета и бонусный — но только вычитанием;
///    `BonusService.cancelTransaction` — пустой `return;` и не вызывается
///    ниоткуда.
///
/// # Почему вторая порча здесь названа, а не починена
///
/// Сторно начисления — шаг 8 задачи 13: `BonusService.reverseForRefund`
/// поверх журнала `BonusEntries`. Без журнала «сколько начислено по этому
/// чеку» в базе не записано нигде: ставка кэшбэка живёт в
/// `this_pos_entries.cashback_rate` и к моменту возврата может быть уже
/// другой. Пересчёт по нынешней ставке дал бы правдоподобное неверное
/// число — ровно тот случай, который сторож обязан не пропускать.
/// Проба ниже помечена `skip` **с числами внутри**, чтобы задача 13
/// начиналась с готового красного, а не с повторного измерения.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late LocalPaymentService payments;
  late Talker logger;

  const barcodeA = '4870001234567';

  const posAccountId = 11;
  const bankAccountId = 12;
  const cashbackAccountId = 13;
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

  Future<void> seedCustomer({String bonus = '0'}) async {
    await seedAccount(
      cashbackAccountId,
      AccountType.agentCashback,
      value: bonus,
    );
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
  Future<CartView> receipt({int terminalId = 7}) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(terminalId, barcodeA, mv(view, 2));
    view = await cart.setQuantity(
      terminalId,
      view.lines.single.id,
      d('2'),
      mv(view, 3),
    );
    return view;
  }

  Future<Decimal> bonusBalance() async =>
      (await db.accountDao.findById(cashbackAccountId))?.value ?? Decimal.zero;

  /// Возврат чека целиком — ровно теми доводами, которыми его зовёт
  /// `refund_controller.dart:507`.
  Future<void> refundWhole(int receiptNo, {int? customerLocalId}) async {
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
  }

  Future<void> boot({int? cashbackRate}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          ThisPosEntriesCompanion(
            id: const Value(1),
            accountId: const Value(posAccountId),
            cashBoxName: const Value('Касса 1'),
            companyName: const Value('ТОО Ромашка'),
            cashbackRate: Value(cashbackRate),
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
    await seedAccount(bankAccountId, AccountType.customBank);

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

  setUp(() async {
    GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await GetIt.I.unregister<RefundProductService>();
    await db.close();
  });

  group('возврат чека, оплаченного бонусами', () {
    test(
      'списанные бонусы возвращаются, а не списываются второй раз',
      () async {
        // Ставка кэшбэка выключена: эта проба про списание, и начисление
        // мешало бы читать числа.
        await boot();
        await seedCustomer(bonus: '300');

        expect(await bonusBalance(), d('300'), reason: 'у клиента было 300');

        final view = await receipt();
        await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('700'),
            bonusUsed: d('300'),
            customerId: customerId,
          ),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        expect(
          await bonusBalance(),
          d('0'),
          reason: 'бонусами оплачено 300 — на счету не осталось ничего',
        );

        await refundWhole(view.receiptNo!);

        // **Несущее утверждение работы.** До правки здесь −300: сторно
        // платежа на бонусном счёте вычиталось так же, как на кассовом.
        expect(
          await bonusBalance(),
          d('300'),
          reason: 'товар вернули — бонусы, которыми за него платили, вернулись',
        );
      },
    );

    test(
      'расчётный счёт кассы при этом отдаёт только наличную часть',
      () async {
        await boot();
        await seedCustomer(bonus: '300');

        final view = await receipt();
        await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('700'),
            bonusUsed: d('300'),
            customerId: customerId,
          ),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        final afterSale =
            (await db.accountDao.findById(posAccountId))?.value ?? Decimal.zero;
        expect(afterSale, d('700'), reason: 'в ящик легли 700 наличными');

        await refundWhole(view.receiptNo!);

        // Слом в обратную сторону: правка знака на бонусном счёте не имеет
        // права тронуть обычный. 700 пришли — 700 ушли.
        expect(
          (await db.accountDao.findById(posAccountId))?.value,
          d('0'),
          reason: 'из ящика вернули ровно наличные, а не всю сумму чека',
        );
      },
    );

    test(
      'расчётный счёт покупателя возврат не двигает — правило в правиле',
      () async {
        await boot();
        await seedCustomer(bonus: '300');

        final view = await receipt();
        await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('700'),
            bonusUsed: d('300'),
            customerId: customerId,
          ),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        // Экран возврата отдаёт покупателя чека — и он же ставится
        // `customerLocalId`. Сегодня чек его не несёт (круг правки 2
        // задачи 16), но правило не имеет права держаться на этом:
        // разбудят соседний сервис, который поле заполнит, — и дефект
        // вернётся целиком. Поэтому подставляем покупателя явно.
        await refundWhole(view.receiptNo!, customerLocalId: customerId);

        expect(
          (await db.accountDao.findById(agentMainAccountId))?.value,
          Decimal.zero,
          reason:
              'чек оплачен полностью (наличные + бонусы) — долга не было, '
              'значит и возвращать по долговому счёту нечего',
        );
      },
    );
  });

  group('начисленный кэшбэк при возврате', () {
    test(
      'сторнируется, а не остаётся у покупателя',
      () async {
        await boot(cashbackRate: 5);
        await seedCustomer();

        expect(await bonusBalance(), d('0'), reason: 'бонусов не было');

        final view = await receipt();
        await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('1000'),
            customerId: customerId,
          ),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        expect(
          await bonusBalance(),
          d('50'),
          reason: '5% от 1000 начислено продажей',
        );

        // Начислено — **записью в журнале**, а не выводом из остатка. Это
        // и есть то, чего до задачи 13 не было нигде: «сколько начислено
        // по этому чеку».
        final accruals = (await db.bonusEntryDao.findBySale(
          view.receiptNo!,
          1,
        )).where((e) => e.kind == BonusEntryKind.accrual);
        expect(accruals, hasLength(1));
        expect(accruals.single.amount, d('50'));

        await refundWhole(view.receiptNo!);

        // **Несущее утверждение шага 8.** До журнала здесь оставалось 50:
        // возврат бонусного счёта не касался вовсе.
        expect(
          await bonusBalance(),
          d('0'),
          reason: 'товара нет — начислять было не за что',
        );

        // И это сторно, а не «обнулили счёт»: журнал обязан объяснить
        // ноль движением, иначе он объясняет не баланс, а самого себя.
        final reversals = (await db.bonusEntryDao.findBySale(
          view.receiptNo!,
          1,
        )).where((e) => e.kind == BonusEntryKind.accrualReversal);
        expect(reversals, hasLength(1));
        expect(reversals.single.amount, d('50'));
        expect(reversals.single.refundLocalId, isNotNull);
        expect(await db.bonusEntryDao.divergences(), isEmpty);
      },
    );

    test(
      'сторно берётся из журнала, а не пересчитывается по нынешней ставке',
      () async {
        // **Довод, ради которого журнал и заведён.** Ставка кэшбэка живёт в
        // `this_pos_entries.cashback_rate` и к моменту возврата может быть
        // уже другой. Пересчёт по ней дал бы правдоподобное неверное число,
        // и опознать его глазами было бы нечем: оно того же порядка.
        //
        // Продажа при ставке 5 % даёт 50. Ставка меняется на 20 %. Возврат
        // обязан снять **50**, а не 200.
        await boot(cashbackRate: 5);
        await seedCustomer();

        final view = await receipt();
        await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('1000'),
            customerId: customerId,
          ),
          mv(view, 9),
        );
        await payments.pendingSideEffects;
        expect(await bonusBalance(), d('50'));

        await db
            .update(db.thisPosEntries)
            .write(const ThisPosEntriesCompanion(cashbackRate: Value(20)));

        await refundWhole(view.receiptNo!);

        expect(
          await bonusBalance(),
          d('0'),
          reason:
              'сняты начисленные 50, а не 200 по новой ставке — иначе счёт '
              'ушёл бы в минус на 150, которых покупателю никто не давал',
        );
      },
    );

    test(
      'частичный возврат сторнирует свою долю, а не всё начисление',
      () async {
        await boot(cashbackRate: 5);
        await seedCustomer();

        final view = await receipt();
        await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('1000'),
            customerId: customerId,
          ),
          mv(view, 9),
        );
        await payments.pendingSideEffects;
        expect(await bonusBalance(), d('50'));

        // Половину товара вернули — половину начисленного забрали.
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
          amount: d('500'),
          userId: 4,
          saleReceiptNo: view.receiptNo,
          salePosId: 1,
          products: const [],
        );

        expect(
          await bonusBalance(),
          d('25'),
          reason: 'вернули половину чека — сняли половину начисленного',
        );
        expect(await db.bonusEntryDao.divergences(), isEmpty);
      },
    );
  });
}

/// Возврат без строк товара: `RefundUseCaseImpl.perform` резолвит эту
/// службу из `GetIt` внутри себя.
class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}
