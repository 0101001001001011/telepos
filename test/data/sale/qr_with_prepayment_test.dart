/// Чек, оплаченный **авансом и QR одновременно** — случай слияния задач
/// 22 и 23, которого не видел ни один из двух авторов.
///
/// # Зачем отдельный файл
///
/// Задачи шли параллельно и друг про друга не знали. Каждая завела свой
/// зачёт «остатка чека после бонуса» и каждая считала его одинаково —
/// `amount - bonus`. Порознь обе верны. Вместе, взятые механически, они
/// **выдают одну комнату дважды**: на чеке 1000 намерение QR на 600 и
/// зачёт аванса на 600 дали бы `toPay = 1000 - 600 - 600 = -400`, то
/// есть кассу, которая должна покупателю сдачу с денег, которых не
/// получала.
///
/// Сторож равенства (`payment_unbalanced`) это поймал бы — но поймал бы
/// **у клиента**, потому что ни в одной из двух веток такой пробы нет.
/// Здесь она есть.
///
/// # Что именно утверждается
///
/// Не «сумма сошлась». Сумма сходится и в неверном порядке тоже: урежь
/// касса строку QR вместо строки аванса, чек всё равно закрылся бы на
/// 1000, и сложение не сказало бы ни слова. Поэтому пробы утверждают
/// **какая из двух строк урезана**, и это разные деньги:
///
/// * QR — деньги, **уже взятые** провайдером, и сдачи QR не даёт
///   (`givesChange = false`). Урезанная строка QR значит заплаченное
///   покупателем **вне чека**: деньги взяты, документа нет.
/// * Аванс — **остаток**, а не движение. Урезанный зачёт не теряет
///   ничего: незачтённое остаётся кредитовым сальдо и уходит в
///   следующий чек.
///
/// Отсюда порядок бонус → QR → аванс, и проверяется он по остаткам
/// счетов, а не по итогу.
library;

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
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import '../../helpers/cash_drawer.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const bankAccountId = 12;
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

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

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

  Future<void> seedCustomerWithAdvance(String advance) async {
    await seedAccount(
      agentMainAccountId,
      AccountType.agentMain,
      value: advance,
    );
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

  /// Оба вида заводятся выключенными, и включает их оператор. Смешанный
  /// чек требует обоих движений — забудь одно, и проба измеряла бы
  /// `pay_kind_inactive`, а не раскладку.
  Future<void> enableBoth() async {
    await (db.update(db.paymentKinds)
          ..where((k) => k.id.equals(SystemPaymentKindIds.qr)))
        .write(const PaymentKindsCompanion(isActive: Value(true)));
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.prepayment,
      ).copyWith(isActive: true),
    );
  }

  Future<PaymentIntent> paidIntent(String key, String amount) async {
    // Рабочее место 7 — то, на котором `receiptWith` заводит чек: `startQr`
    // место всегда ставит, а намерение без места с 2026-09-15 не
    // принадлежит никому (пункт 10 C).
    final (row, _) = await db.paymentIntentDao.claim(
      intentKey: key,
      providerCode: 'sbp_test',
      amount: d(amount),
      createdAt: DateTime.now(),
      terminalId: 7,
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
      cardTerminal: (_, {required amountTiyn, required receiptNo}) async =>
          const CardCharge(outcome: CardChargeOutcome.notConfigured),
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() async => db.close());

  test('аванс и QR на одном чеке: комната делится, а не выдаётся дважды',
      () async {
    await enableBoth();
    await seedCustomerWithAdvance('600');
    await paidIntent('q-mix', '600');
    final view = await receiptWith(); // 2 × 500 = 1000

    final outcome = await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('600'),
        prepaymentReference: 'АВ-7',
        qrIntentKey: 'q-mix',
      ),
      mv(view, 9),
    );

    expect(outcome.amount, d('1000'));
    expect(outcome.paid, d('1000'));
    expect(outcome.debt, Decimal.zero);

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);

    // **Урезан аванс, а не QR** — вот всё утверждение этой пробы.
    final qr = rows.singleWhere((r) => r.kindId == SystemPaymentKindIds.qr);
    expect(
      qr.amount,
      d('600'),
      reason: 'деньги провайдер уже взял, сдачи QR не даёт: урезанная '
          'строка оставила бы заплаченное вне чека',
    );
    expect(qr.payeeAccountId, bankAccountId);

    final offset = rows.singleWhere(
      (r) => r.kindId == SystemPaymentKindIds.prepayment,
    );
    expect(
      offset.amount,
      d('400'),
      reason: 'аванс добирает остаток чека ПОСЛЕ QR, а не вместе с ним: '
          '1000 − 600 = 400',
    );
    expect(offset.payeeAccountId, agentMainAccountId);
    expect(offset.reference, 'АВ-7');

    // I172 — отдельно от полей, а не вместо них.
    expect(rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount), d('1000'));
    expect(rows.length, 2, reason: 'наличной строки на нулевую сдачу нет');

    // Живых денег в ящике нет ни от одного из двух.
    expect(await balanceOf(posAccountId), Decimal.zero);
    // QR — тендер: деньги посчитаны на банковский счёт.
    expect(await balanceOf(bankAccountId), d('600'));
    // Незачтённые 200 остались авансом покупателя, а не сгорели.
    expect(
      await balanceOf(agentMainAccountId),
      d('200'),
      reason: 'обратный порядок урезал бы QR, зачёл 600 авансом и обнулил '
          'счёт — сумма сошлась бы так же, а 200 чужих денег пропали бы',
    );
  });

  test('аванс покрывает то, что осталось после QR, а не весь чек', () async {
    await enableBoth();
    await seedCustomerWithAdvance('5000');
    await paidIntent('q-big', '900');
    final view = await receiptWith(); // 1000

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        // Терминал просит зачесть весь чек авансом. Потолок ставит касса.
        prepaymentUsed: d('1000'),
        qrIntentKey: 'q-big',
      ),
      mv(view, 9),
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(
      rows.singleWhere((r) => r.kindId == SystemPaymentKindIds.qr).amount,
      d('900'),
    );
    expect(
      rows
          .singleWhere((r) => r.kindId == SystemPaymentKindIds.prepayment)
          .amount,
      d('100'),
      reason: 'заявка просила 1000 — касса дала ровно незакрытый остаток',
    );
    expect(rows.fold<Decimal>(Decimal.zero, (s, r) => s + r.amount), d('1000'));
    expect(await balanceOf(agentMainAccountId), d('4900'));
  });

  test('QR закрыл чек целиком — строки зачёта нет вовсе, аванс цел',
      () async {
    await enableBoth();
    await seedCustomerWithAdvance('600');
    await paidIntent('q-all', '1000');
    final view = await receiptWith(); // 1000

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('600'),
        qrIntentKey: 'q-all',
      ),
      mv(view, 9),
    );

    final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
    expect(
      rows.map((r) => r.kindId),
      [SystemPaymentKindIds.qr],
      reason: 'зачитывать нечего: строка на ноль — это строка ни о чём',
    );
    expect(
      await balanceOf(agentMainAccountId),
      d('600'),
      reason: 'аванс не тронут: покупатель заплатил телефоном',
    );
  });

  test('QR не идёт условной записью зачёта — он тендер, а не offset',
      () async {
    // **Замер, а не пересказ справочника.** Ветвь зачёта в
    // `SaleUseCaseImpl.perform` спрашивает род расчёта и род счёта
    // (`isOffset && !isBonus`) и списывает деньги через `claimCredit` —
    // то есть **уменьшает** остаток счёта-получателя. Пойди QR по ней,
    // банковский счёт ушёл бы в минус на сумму оплаты вместо плюса, и
    // итог чека этого бы не заметил.
    await enableBoth();
    await seedCustomerWithAdvance('600');
    await paidIntent('q-tender', '600');
    final view = await receiptWith(); // 1000

    final before = await balanceOf(bankAccountId);
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('600'),
        qrIntentKey: 'q-tender',
      ),
      mv(view, 9),
    );

    expect(
      await balanceOf(bankAccountId),
      before + d('600'),
      reason: 'тендер кладёт деньги на счёт (post), а не снимает их с него '
          '(claimCredit)',
    );
    // А зачёт по той же операции — снял.
    expect(await balanceOf(agentMainAccountId), d('200'));
  });

  test('намерение помечено разобранным, и ровно этим чеком', () async {
    await enableBoth();
    await seedCustomerWithAdvance('600');
    final intent = await paidIntent('q-settle', '600');
    final view = await receiptWith();

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        customerId: customerId,
        prepaymentUsed: d('600'),
        qrIntentKey: 'q-settle',
      ),
      mv(view, 9),
    );

    final after = (await db.paymentIntentDao.byId(intent.id))!;
    expect(after.settledAt, isNotNull);
    expect(
      after.settledReceiptNo,
      view.receiptNo,
      reason: 'соседство с зачётом аванса не должно уводить пометку в чужой '
          'чек',
    );
  });
}
