/// Возврат рассрочного чека **отказывается** — шаг 7 задачи 24.
///
/// # Довод измерен на настоящем коде, а не выведен
///
/// Настоящая база, настоящая корзина, настоящий `LocalPaymentService`,
/// настоящий `SaleUseCaseImpl` и настоящий `RefundUseCaseImpl`. Подставлен
/// только фискальный узел, которого в этой кассе нет.
///
/// Чек 1000: первый взнос 200 наличными, рассрочка 800. Без отказа возврат
/// сделал бы вот что:
///
/// * выдал бы из ящика **200** — долю наличной строки (обязательство из
///   ящика не выходит с задачи 14);
/// * сдвинул бы счёт покупателя на `amount − reversed` = **800 в плюс**,
///   то есть вернул бы деньги, которых покупатель не платил;
/// * **не тронул бы ни одной строки графика** — договор остался бы живым,
///   и покупатель был бы должен по нему за товар, который вернул.
///
/// Ниже это утверждается зеркально: после отказа все три числа стоят на
/// месте. Проба, спросившая только «пришёл ли отказ», не отличила бы
/// отказ **до записи** от отказа после неё.
///
/// # Контрольный маркер обязателен
///
/// Рядом стоит возврат **обычного** чека того же вида и той же суммы. Без
/// него зелёный отказ означал бы «возврат не работает вовсе», а не
/// «возврат рассрочки отказан».
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/credit_dao.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late Talker logger;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const bankAccountId = 12;
  const agentMainAccountId = 14;
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

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

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

  Future<CartView> receipt() async {
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

  setUp(() async {
    GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());
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
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.installment,
      ).copyWith(isActive: true),
    );
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.debt,
      ).copyWith(isActive: true),
    );
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await GetIt.I.unregister<RefundProductService>();
    await db.close();
  });

  test('возврат рассрочного чека отказывается названной причиной', () async {
    final view = await receipt();
    await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.installment,
        customerId: customerId,
        cashReceived: d('200'),
        installmentTermMonths: 3,
        installmentScheme: InstallmentScheme.equalInstalments.code,
      ),
      mv(view, 9),
    );
    await payments.pendingSideEffects;

    expect(await balanceOf(posAccountId), d('200'));
    expect(await balanceOf(agentMainAccountId), d('-800'));

    await expectLater(
      refundWhole(view.receiptNo!, customerLocalId: customerId),
      throwsA(
        isA<WireRefusal>()
            .having((e) => e.code, 'code', refundInstallmentRefusedCode)
            // Причина названа договором, а не «нельзя»: кассир обязан
            // понять, куда идти.
            .having((e) => e.message, 'message', contains('РС-1-')),
      ),
    );

    // ── три числа, стоящие на месте ─────────────────────────────────
    expect(
      await balanceOf(posAccountId),
      d('200'),
      reason: 'из ящика ничего не вышло',
    );
    expect(
      await balanceOf(agentMainAccountId),
      d('-800'),
      reason: 'покупателю не вернули денег, которых он не платил',
    );

    final contractRow = (await db.creditDao.rowByReceipt(
      receiptNo: view.receiptNo!,
      posId: 1,
    ))!;
    final schedule = await db.creditDao.scheduleRows(contractRow.id);
    expect(
      [for (final e in schedule) e.paidMillis],
      [0, 0, 0],
      reason: 'график не тронут ни одной веткой возврата',
    );
    expect(
      CreditDao.toDomain(contractRow)!.isLive,
      isTrue,
      reason: 'договор жив — его расторжение это не операция кассы',
    );

    // Строк сторно не появилось: отказ пришёл до единой записи.
    final reversals = await (db.select(
      db.payments,
    )..where((p) => p.refundLocalId.isNotNull())).get();
    expect(reversals, isEmpty);
  });

  test(
    'КОНТРОЛЬНЫЙ МАРКЕР: возврат обычного долгового чека проходит',
    () async {
      // Без него зелёный отказ выше означал бы «возврат не работает
      // вовсе», а не «возврат рассрочки отказан». Тот же покупатель, та
      // же сумма, тот же первый взнос — отличается только вид оплаты.
      final view = await receipt();
      await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.debt,
          customerId: customerId,
          cashReceived: d('200'),
        ),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      expect(await balanceOf(posAccountId), d('200'));
      expect(await balanceOf(agentMainAccountId), d('-800'));

      await refundWhole(view.receiptNo!, customerLocalId: customerId);

      // Возврат состоялся: из ящика вышла доля наличной строки, а
      // обязательство сторнировано счётом покупателя.
      expect(await balanceOf(posAccountId), Decimal.zero);
      expect(await balanceOf(agentMainAccountId), Decimal.zero);
      expect(
        await db.creditDao.rowByReceipt(receiptNo: view.receiptNo!, posId: 1),
        isNull,
        reason: 'долговой чек договора не заводит',
      );
    },
  );
}

class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}
