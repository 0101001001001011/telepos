/// Продажа в рассрочку — **договор рождается вместе с чеком**.
///
/// # Что утверждается, и почему не «сумма сошлась»
///
/// Сумма сходится и у кассы, которая записала договор на другое число, и
/// у той, которая не записала его вовсе: строка оплаты вида `installment`
/// в сумму чека входит, а договор в неё не входит **ни одной тысячной**.
/// Поэтому каждый случай утверждает четыре разных числа:
///
/// * строка `Payments` — её вид, сумма и номер договора в `reference`;
/// * остаток расчётного счёта покупателя (долг);
/// * поля самого договора — тело, первый взнос, срок, схема;
/// * строки графика — их число и сумма.
///
/// Проба, спросившая только сумму, не отличила бы «договор на 8000» от
/// «договора нет».
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/credit_dao.dart';
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
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late CreditService credit;

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

  Future<void> seedCustomer({String balance = '0'}) async {
    await seedAccount(
      agentMainAccountId,
      AccountType.agentMain,
      value: balance,
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

  /// Вид `installment` заводится **выключенным** (задача 14), включает его
  /// оператор. Забудь это движение — и проба мерила бы
  /// `payment_kind_inactive`, а не раскладку.
  Future<void> enableInstallment() async {
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.installment,
      ).copyWith(isActive: true),
    );
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
    credit = LocalCreditService(db: db, logger: logger);
    await enableInstallment();
  });

  tearDown(() async => db.close());

  test(
    'чек 1000, первый взнос 200 — договор на 800 и график из 3 строк',
    () async {
      await seedCustomer();
      final view = await receiptWith(); // 2 × 500 = 1000

      final outcome = await payments.complete(
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

      expect(outcome.amount, d('1000'));
      // **Товар отдан за 1000, и это главное число фискальной стороны.**
      // Оператору уезжает вся сумма чека: 200 наличными и 800 обязательством
      // (`FiscalTreatment.credit`). Уехал бы один взнос — `Σ line` (1000) не
      // сошлось бы с `Σ payments` (200), и оператор ответил бы кодом 9.
      expect(outcome.paid, d('200'), reason: 'живыми деньгами пришло 200');
      expect(outcome.debt, d('800'), reason: 'остальное — обязательство');
      expect(outcome.change, Decimal.zero);

      // ── строки оплаты ────────────────────────────────────────────────
      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows.length, 2, reason: 'наличные и рассрочка — две строки');

      final cashRow = rows.firstWhere(
        (r) => r.kindId == SystemPaymentKindIds.cash,
      );
      expect(cashRow.amount, d('200'));
      expect(cashRow.payeeAccountId, posAccountId);

      final creditRow = rows.firstWhere(
        (r) => r.kindId == SystemPaymentKindIds.installment,
      );
      expect(creditRow.amount, d('800'));
      expect(
        creditRow.payeeAccountId,
        agentMainAccountId,
        reason: 'обязательство лежит на расчётном счёте покупателя',
      );
      expect(
        creditRow.reference,
        'РС-1-${view.receiptNo}',
        reason: 'строка без номера договора необъяснима',
      );

      // ── деньги ────────────────────────────────────────────────────────
      expect(await balanceOf(posAccountId), d('200'), reason: 'в ящике 200');
      expect(
        await balanceOf(agentMainAccountId),
        d('-800'),
        reason: 'покупатель должен 800, а не 1000',
      );

      // ── сам договор ───────────────────────────────────────────────────
      final contract = await credit.byNumber('РС-1-${view.receiptNo}');
      expect(contract, isNotNull);
      expect(contract!.contract.principal, d('800'));
      expect(contract.contract.downPayment, d('200'));
      expect(contract.contract.feeTotal, Decimal.zero);
      expect(contract.contract.termMonths, 3);
      expect(contract.contract.scheme, InstallmentScheme.equalInstalments);
      expect(contract.contract.status, CreditContractStatus.active);
      expect(contract.contract.agentLocalId, customerId);
      expect(
        contract.contract.receivableAccountId,
        agentMainAccountId,
        reason: 'снимок счёта на момент подписи',
      );
      expect(contract.contract.receiptNo, view.receiptNo);

      // ── график ────────────────────────────────────────────────────────
      expect(contract.schedule.length, 3);
      expect(
        contract.schedule.fold(Decimal.zero, (Decimal s, e) => s + e.totalDue),
        d('800'),
      );
      expect([for (final e in contract.schedule) e.seq], [0, 1, 2]);
      expect(
        [for (final e in contract.schedule) e.paid],
        [Decimal.zero, Decimal.zero, Decimal.zero],
      );
    },
  );

  test('без первого взноса договор на всю сумму чека', () async {
    await seedCustomer();
    final view = await receiptWith();

    await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.installment,
        customerId: customerId,
        installmentTermMonths: 12,
        installmentScheme: InstallmentScheme.differentiated.code,
      ),
      mv(view, 9),
    );

    final contract = await credit.byNumber('РС-1-${view.receiptNo}');
    expect(contract!.contract.principal, d('1000'));
    expect(contract.contract.downPayment, Decimal.zero);
    expect(contract.schedule.length, 12);
    expect(await balanceOf(agentMainAccountId), d('-1000'));
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  group('что мешает выдать две рассрочки на один чек', () {
    test('вид оплаты у заявки один — значит и договор один', () async {
      await seedCustomer();
      final view = await receiptWith();

      await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.installment,
          customerId: customerId,
          installmentTermMonths: 3,
          installmentScheme: InstallmentScheme.equalInstalments.code,
        ),
        mv(view, 9),
      );

      final all = await db.creditDao.rowsByAgent(customerId);
      expect(all.length, 1);
    });

    test(
      'повтор той же команды отдаёт прежний итог и НЕ второй договор',
      () async {
        await seedCustomer();
        final view = await receiptWith();
        final meta = mv(view, 9);

        final first = await payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.installment,
            customerId: customerId,
            installmentTermMonths: 3,
            installmentScheme: InstallmentScheme.equalInstalments.code,
          ),
          meta,
        );
        final second = await payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.installment,
            customerId: customerId,
            installmentTermMonths: 3,
            installmentScheme: InstallmentScheme.equalInstalments.code,
          ),
          meta,
        );

        expect(second.repeat, isTrue);
        expect(second.amount, first.amount);
        expect(
          (await db.creditDao.rowsByAgent(customerId)).length,
          1,
          reason: 'повтор ключа — не вторая продажа',
        );
        expect(
          await balanceOf(agentMainAccountId),
          d('-1000'),
          reason: 'долг не удвоился',
        );
      },
    );

    test('вторая оплата ЧУЖИМ ключом отвергается до единой записи', () async {
      await seedCustomer();
      final view = await receiptWith();

      await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.installment,
          customerId: customerId,
          installmentTermMonths: 3,
          installmentScheme: InstallmentScheme.equalInstalments.code,
        ),
        mv(view, 9),
      );

      await expectLater(
        payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.installment,
            customerId: customerId,
            installmentTermMonths: 6,
            installmentScheme: InstallmentScheme.feeUpfront.code,
          ),
          CartCommandMeta(
            key: 'другая-попытка',
            baseVersion: view.version,
            receiptNo: view.receiptNo,
          ),
        ),
        throwsA(isA<WireRefusal>()),
      );
      expect((await db.creditDao.rowsByAgent(customerId)).length, 1);
    });
  });

  group('отказы раскладки', () {
    test('срок не назван — credit_term_invalid, и ни одной записи', () async {
      await seedCustomer();
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.installment,
            customerId: customerId,
            installmentScheme: InstallmentScheme.equalInstalments.code,
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            creditTermInvalidCode,
          ),
        ),
      );
      expect(await db.paymentDao.findBySale(view.receiptNo!, 1), isEmpty);
      expect(await balanceOf(agentMainAccountId), Decimal.zero);
    });

    test(
      'схема неизвестна — credit_scheme_unknown, а не подстановка',
      () async {
        await seedCustomer();
        final view = await receiptWith();

        await expectLater(
          payments.complete(
            terminalId,
            PaymentRequest(
              type: PaymentType.installment,
              customerId: customerId,
              installmentTermMonths: 3,
              installmentScheme: 'annuity_v2',
            ),
            mv(view, 9),
          ),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              creditSchemeUnknownCode,
            ),
          ),
        );
      },
    );

    test('покупатель не назван — долг записать не на кого', () async {
      final view = await receiptWith();
      await expectLater(
        payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.installment,
            installmentTermMonths: 3,
            installmentScheme: InstallmentScheme.equalInstalments.code,
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            payDebtorRequiredCode,
          ),
        ),
      );
    });

    test(
      'чек покрыт деньгами целиком — рассрочку не на что оформлять',
      () async {
        await seedCustomer();
        final view = await receiptWith();

        await expectLater(
          payments.complete(
            terminalId,
            PaymentRequest(
              type: PaymentType.installment,
              customerId: customerId,
              cashReceived: d('1000'),
              installmentTermMonths: 3,
              installmentScheme: InstallmentScheme.equalInstalments.code,
            ),
            mv(view, 9),
          ),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              creditPrincipalInvalidCode,
            ),
          ),
        );
        expect(await balanceOf(posAccountId), Decimal.zero);
      },
    );

    test('вид выключен оператором — касса рассрочку не принимает', () async {
      await seedCustomer();
      await db.paymentKindDao.put(
        SystemPaymentKinds.byId(
          SystemPaymentKindIds.installment,
        ).copyWith(isActive: false),
      );
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.installment,
            customerId: customerId,
            installmentTermMonths: 3,
            installmentScheme: InstallmentScheme.equalInstalments.code,
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having((e) => e.code, 'code', payKindInactiveCode),
        ),
      );
    });

    test(
      'на этой кассе в кредит не торгуют — тот же тумблер, что у долга',
      () async {
        await seedCustomer();
        await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1)))
            .write(const ThisPosEntriesCompanion(sellInDebt: Value(false)));
        final view = await receiptWith();

        await expectLater(
          payments.complete(
            terminalId,
            PaymentRequest(
              type: PaymentType.installment,
              customerId: customerId,
              installmentTermMonths: 3,
              installmentScheme: InstallmentScheme.equalInstalments.code,
            ),
            mv(view, 9),
          ),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              payDebtNotSoldHereCode,
            ),
          ),
        );
      },
    );
  });

  group('просрочка замечается тем, кому она дороже всего', () {
    test('просроченный договор закрывает вторую рассрочку', () async {
      await seedCustomer();

      // Первая рассрочка — и её график двигается в прошлое: срок платежа
      // назначается вперёд от подписи, а «сделать вид, что прошёл год»
      // можно только правкой самой строки. Правится **срок**, а не
      // выдуманное поле просрочки: хранимой просрочки в схеме нет вовсе,
      // и это и есть предмет утверждения.
      final first = await receiptWith();
      await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.installment,
          customerId: customerId,
          installmentTermMonths: 3,
          installmentScheme: InstallmentScheme.equalInstalments.code,
        ),
        mv(first, 9),
      );
      final contractId = (await db.creditDao.rowByReceipt(
        receiptNo: first.receiptNo!,
        posId: 1,
      ))!.id;
      final touched =
          await (db.update(db.creditScheduleEntries)..where(
                (e) => e.contractId.equals(contractId) & e.seq.equals(0),
              ))
              .write(
                const CreditScheduleEntriesCompanion(dueDate: Value(1000)),
              );
      expect(touched, 1, reason: 'фикстура обязана попасть в строку');

      expect(await credit.hasOverdue(customerId), isTrue);

      final second = await receiptWith();
      await expectLater(
        payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.installment,
            customerId: customerId,
            installmentTermMonths: 3,
            installmentScheme: InstallmentScheme.equalInstalments.code,
          ),
          mv(second, 19),
        ),
        throwsA(
          isA<WireRefusal>().having((e) => e.code, 'code', creditOverdueCode),
        ),
      );
      expect(
        (await db.creditDao.rowsByAgent(customerId)).length,
        1,
        reason: 'второго договора нет',
      );
    });

    test('НЕпросроченный договор второй рассрочке не мешает', () async {
      // Контрольный маркер: без него зелёный отказ выше означал бы «касса
      // не выдаёт вторую рассрочку никогда», а не «не выдаёт при
      // просрочке».
      await seedCustomer();
      final first = await receiptWith();
      await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.installment,
          customerId: customerId,
          installmentTermMonths: 3,
          installmentScheme: InstallmentScheme.equalInstalments.code,
        ),
        mv(first, 9),
      );
      expect(await credit.hasOverdue(customerId), isFalse);

      final second = await receiptWith();
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.installment,
          customerId: customerId,
          installmentTermMonths: 6,
          installmentScheme: InstallmentScheme.differentiated.code,
        ),
        mv(second, 19),
      );
      expect(outcome.debt, d('1000'));
      expect((await db.creditDao.rowsByAgent(customerId)).length, 2);
      expect(await balanceOf(agentMainAccountId), d('-2000'));
    });
  });
}
