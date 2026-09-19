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
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

/// QR как **тендер чека** — задача 22, вторая половина.
///
/// # Что здесь проверяется сверх эмуляторных проб
///
/// Эмуляторные пробы (`test/emulators/sbp/`) отвечают на вопрос «что
/// случилось с намерением». Здесь — на другой: **как деньги намерения
/// становятся строкой чека**, и что при этом нельзя.
///
/// Три утверждения, и все три про деньги:
///
/// 1. **Сумму читает касса, а не заявка.** В кадре едет ключ намерения и
///    только он. Пробы называют в заявке сумму, отличную от намерения, и
///    требуют, чтобы касса её не заметила.
/// 2. **Деньги ложатся в чек один раз.** Второй чек на то же намерение —
///    это двойное взятие с другой стороны: покупатель заплатил один раз,
///    а товара получил бы на два.
/// 3. **Вид, выключенный оператором, выключен и для кассы.** QR заводится
///    выключенным (`SystemPaymentKinds`), и без включения не проходит.
///
/// # Про `payment_unbalanced`
///
/// Ветка была объявлена задачей 14 недостижимой сегодня и оставлена
/// сторожем «для следующего вида оплаты». Следующий вид — этот, и ответ
/// измерен, а не угадан: см. группу «сторож равенства» ниже.
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

  Future<void> seedDebtor() async {
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

  /// Тумблер кассы «Разрешить продажу в кредит».
  Future<void> allowDebtSales() async {
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(sellInDebt: Value(true)),
    );
  }

  /// Включить QR — то самое движение оператора, которым вид перестаёт быть
  /// выключенным. Без него ни одна проба ниже не проходит, и это правильно.
  Future<void> enableQr() async {
    await (db.update(db.paymentKinds)
          ..where((k) => k.id.equals(SystemPaymentKindIds.qr)))
        .write(const PaymentKindsCompanion(isActive: Value(true)));
  }

  /// Оплаченное намерение в базе кассы — то, что оставил бы за собой
  /// `QrPaymentCoordinator`, дождавшись подтверждения.
  Future<PaymentIntent> paidIntent(
    String key,
    String amount, {
    String? paid,
    DateTime? settledAt,
    int? settledReceiptNo,
  }) async {
    // Рабочее место 7 — то, на котором `receiptWith` заводит чек по
    // умолчанию: `startQr` место всегда ставит, а намерение без места с
    // 2026-09-15 не принадлежит никому (пункт 10 C).
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
      paidAmount: d(paid ?? amount),
      confirmedAt: DateTime.now(),
      countConfirmation: true,
    );
    if (settledAt != null) {
      await db.paymentIntentDao.markSettled(
        id: row.id,
        receiptNo: settledReceiptNo ?? 999,
        at: settledAt,
      );
    }
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

  tearDown(() async {
    await db.close();
  });

  group('вид, выключенный оператором, выключен и для кассы', () {
    test('QR не проходит, пока оператор его не включил', () async {
      await paidIntent('q-off', '1000');
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, qrIntentKey: 'q-off'),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payKindInactiveCode,
          ),
        ),
      );

      final rows = await db.select(db.payments).get();
      expect(rows, isEmpty, reason: 'отказ приходит ДО единой записи');
    });
  });

  group('сумму читает касса, а не заявка', () {
    test('строка оплаты равна подтверждённому, а не названному в кадре',
        () async {
      await enableQr();
      await paidIntent('q-1', '1000');
      final view = await receiptWith();

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          // Заявка врёт: она называет 100 наличными и рассчитывает, что
          // касса дополнит QR-ом. Касса читает намерение у себя.
          cashReceived: d('100'),
          qrIntentKey: 'q-1',
        ),
        mv(view, 9),
      );

      expect(outcome.amount, d('1000'));
      expect(outcome.paid, d('1000'));
      expect(outcome.debt, Decimal.zero);

      final rows = await db.select(db.payments).get();
      expect(rows.length, 1, reason: 'весь чек закрыт одной строкой QR');
      final qr = rows.single;
      expect(qr.kindId, SystemPaymentKindIds.qr);
      expect(qr.amount, d('1000'));
      expect(
        qr.payeeAccountId,
        bankAccountId,
        reason:
            'деньги пришли на счёт в банке, а не в ящик: счёт кассы завысил '
            'бы наличные смены на сумму, которой в ящике нет',
      );
      expect(
        qr.reference,
        'q-1',
        reason: 'документ-основание — ключ намерения (колонка задачи 14)',
      );
      expect(
        qr.providerCode,
        'sbp_test',
        reason:
            'без кода провайдера подтверждение, пришедшее снаружи, не с чем '
            'сверить',
      );
      expect(qr.terminalTransactionId, 'PRV-q-1');
      expect(qr.seq, 0, reason: 'seq считается от нуля на каждой попытке');
    });

    test('оплачено частично — остаток добирается наличными', () async {
      await enableQr();
      await paidIntent('q-part', '1000', paid: '400');
      final view = await receiptWith();

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('600'),
          qrIntentKey: 'q-part',
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('1000'));
      final rows = await db.select(db.payments).get()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      expect(rows.length, 2);
      expect(rows.map((r) => r.kindId), [
        SystemPaymentKindIds.cash,
        SystemPaymentKindIds.qr,
      ]);
      expect(rows.map((r) => r.amount), [d('600'), d('400')]);
      expect(
        rows.map((r) => r.seq),
        [0, 1],
        reason: 'нумерация от нуля не сломана новым видом',
      );
    });

    test('намерение больше чека — строка не превышает суммы чека', () async {
      await enableQr();
      await paidIntent('q-big', '5000');
      final view = await receiptWith();

      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, qrIntentKey: 'q-big'),
        mv(view, 9),
      );

      expect(outcome.paid, d('1000'));
      final rows = await db.select(db.payments).get();
      expect(
        rows.single.amount,
        d('1000'),
        reason:
            'сдачи QR не даёт — лишнее ушло бы в выручку смены деньгами, '
            'которых в кассе нет',
      );
      expect(outcome.change, Decimal.zero);
    });
  });

  group('QR вместе с долгом', () {
    /// **Сочетание, ради которого сторож равенства и существует.**
    ///
    /// Часть чека оплачена телефоном, остаток записан покупателю: у долга
    /// сумма считается **разностью от суммы чека**, а не от остатка, и
    /// забыть в этой разности одно слагаемое — беда, которую видно только
    /// сложением строк. Ровно на этом сочетании `payment_unbalanced`
    /// перестаёт быть недостижимым: без `− qr` в разности строки дают
    /// 1400 на чеке в 1000.
    test('часть телефоном, остаток в долг — Σ строк равна сумме чека',
        () async {
      await enableQr();
      await seedDebtor();
      await allowDebtSales();
      await paidIntent('q-debt', '400');
      final view = await receiptWith();

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.debt,
          customerId: customerId,
          qrIntentKey: 'q-debt',
        ),
        mv(view, 9),
      );

      // `SaleOutcome.paid` — **живые деньги**, а не сумма строк: строка
      // долга это обязательство, и класть её в «оплачено» значило бы
      // сказать кассиру, что чек закрыт деньгами. Строк при этом две, и
      // их сумма равна чеку — два разных утверждения об одном чеке, и
      // проверяются оба.
      expect(outcome.paid, d('400'), reason: 'телефоном пришло 400');
      expect(outcome.debt, d('600'), reason: 'остальное — обязательство');

      final rows = await db.select(db.payments).get()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      expect(rows.length, 2);
      expect(rows.map((r) => r.kindId), [
        SystemPaymentKindIds.qr,
        SystemPaymentKindIds.debt,
      ]);
      expect(rows.map((r) => r.amount), [d('400'), d('600')]);

      // **Ни одной наличной строки — и это утверждение, а не совпадение.**
      //
      // Замер соседа по авансу: на наличном чеке до сторожа равенства
      // дело **не доходит** — диверсия падает раньше, на
      // `payment_insufficient` («наличных меньше суммы к оплате»), и
      // проба, написанная на наличном чеке, мерит соседний сторож, а не
      // этот. У меня то же самое измерено на диверсии `toPay`.
      //
      // Значит проба на `payment_unbalanced` **обязана быть
      // безналичной**, и обязанность эта закрепляется здесь: без этой
      // строки чья-нибудь правка добавит сюда наличных, проба останется
      // зелёной, а сторож перестанет проверяться — и узнать об этом
      // будет неоткуда.
      expect(
        rows.where((r) => r.kindId == SystemPaymentKindIds.cash),
        isEmpty,
        reason:
            'проба на сторож равенства обязана быть безналичной: с наличной '
            'строкой первым отвечает payment_insufficient, и диверсия мерит '
            'не тот сторож',
      );
      expect(
        rows.fold(Decimal.zero, (s, r) => s + r.amount),
        d('1000'),
        reason: 'Σ строк оплаты == сумма чека (I172)',
      );

      final debtor = await db.accountDao.findById(agentMainAccountId);
      expect(
        debtor!.value,
        d('-600'),
        reason:
            'покупателю записаны 600, а не 1000: четыреста он уже заплатил '
            'телефоном, и записать их в долг значило бы взять с него дважды',
      );
    });
  });

  group('деньги намерения ложатся в чек ровно один раз', () {
    test('после оплаты намерение помечено разобранным', () async {
      await enableQr();
      final intent = await paidIntent('q-settle', '1000');
      final view = await receiptWith();

      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, qrIntentKey: 'q-settle'),
        mv(view, 9),
      );

      final row = await db.paymentIntentDao.byId(intent.id);
      expect(row!.settledAt, isNotNull);
      expect(row.settledReceiptNo, outcome.receiptNo);
      expect(
        row.isOrphanMoney,
        isFalse,
        reason: 'деньги в чеке — на экране разбора им больше не место',
      );
      expect(
        await db.paymentIntentDao.orphanMoney(),
        isEmpty,
      );
    });

    test('второй чек на то же намерение отвергается названной причиной',
        () async {
      await enableQr();
      await paidIntent(
        'q-used',
        '1000',
        settledAt: DateTime.now(),
        settledReceiptNo: 42,
      );
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, qrIntentKey: 'q-used'),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>()
              .having((r) => r.code, 'code', payQrAlreadySettledCode)
              .having((r) => r.message, 'message', contains('42')),
        ),
      );
    });
  });

  group('намерение, которое нельзя брать в чек', () {
    test('ключа нет в базе — qr_intent_unknown, а не подстановка нуля',
        () async {
      await enableQr();
      final view = await receiptWith();
      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, qrIntentKey: 'q-нет'),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payQrIntentUnknownCode,
          ),
        ),
      );
    });

    test('намерение не оплачено — qr_intent_not_paid', () async {
      await enableQr();
      final (row, _) = await db.paymentIntentDao.claim(
        intentKey: 'q-pending',
        providerCode: 'sbp_test',
        amount: d('1000'),
        createdAt: DateTime.now(),
        terminalId: 7,
      );
      await db.paymentIntentDao.attachProviderIntent(
        id: row.id,
        providerIntentId: 'PRV-pending',
        status: QrIntentStatus.pending,
      );
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, qrIntentKey: 'q-pending'),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>()
              .having((r) => r.code, 'code', payQrNotPaidCode)
              .having((r) => r.message, 'message', contains('pending')),
        ),
      );
      expect(
        await db.select(db.payments).get(),
        isEmpty,
        reason: 'отдать товар за деньги, которых нет, — не вариант',
      );
    });
  });

  group('сторож равенства: Σ строк оплаты == сумма чека', () {
    /// **Ветка `payment_unbalanced` по-прежнему недостижима с исправным
    /// кодом — и это ЗАМЕР, а не догадка.**
    ///
    /// Равенство держится арифметикой: `toPay = amount − bonus − qr`,
    /// наличная часть равна остатку, долговая — недостаче. `Decimal` не
    /// теряет копеек, и ни одно сочетание входов не даёт расхождения.
    ///
    /// **Что изменилось против задачи 14.** Тогда ветка была объявлена
    /// недостижимой и оставлена «сторожем для следующего вида оплаты» —
    /// то есть принята на веру. Теперь следующий вид есть, и сторож
    /// **проверен диверсией**: убрать `− qr` из остатка (или `+ qr` из
    /// суммы долга) — и он краснеет. Разница между веткой, названной
    /// недостижимой, и веткой, про которую соврали, что она проверена, —
    /// вся; здесь она закрыта.
    ///
    /// Числа диверсий записаны в `docs/internal/testing-notes.md`.
    test('исправный код равенства не нарушает ни на одном сочетании',
        () async {
      await enableQr();
      for (final (paid, cash) in const [
        ('1000', '0'),
        ('400', '600'),
        ('999.999', '0.001'),
        ('0.001', '999.999'),
      ]) {
        await db.customStatement('DELETE FROM payment_intents');
        await db.customStatement('DELETE FROM payments');
        await db.customStatement('DELETE FROM sales');
        await db.customStatement('DELETE FROM sale_products');
        await paidIntent('q-$paid', '1000', paid: paid);
        final view = await receiptWith();
        final outcome = await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d(cash),
            qrIntentKey: 'q-$paid',
          ),
          mv(view, 90),
        );
        expect(outcome.paid, d('1000'), reason: 'QR $paid + наличные $cash');
        final rows = await db.select(db.payments).get();
        final sum = rows.fold(Decimal.zero, (s, r) => s + r.amount);
        expect(
          sum,
          d('1000'),
          reason:
              'Σ строк оплаты == сумма чека — утверждение о СТРОКАХ, а не '
              'об ответе метода: ответ считает тот же код, что и строки',
        );
      }
    });
  });
}
