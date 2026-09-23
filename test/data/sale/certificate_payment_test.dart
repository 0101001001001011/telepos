/// Оплата сертификатом на настоящем пути кассы — задача 21.
///
/// # Почему баланс сумм здесь ничего не доказывает
///
/// Инвариант «Σ строк оплаты == сумма чека» держится и у кассы, которая
/// списала сертификат дважды, и у кассы, которая не списала его вовсе:
/// обе оставляют чек в идеальном равновесии, и обе раздают товар даром.
/// Поэтому каждый случай утверждает **про сам остаток бумажки** и про
/// **счёт обязательства**, а сумма проверяется вдобавок, а не вместо.
///
/// # Стенд — настоящий, швы объявлены продуктом
///
/// `SaleCheckoutService` и `SaleUseCase` — доводы конструктора
/// [LocalPaymentService], и подделывается здесь только **расписание**
/// (`_GatedSaleUseCase`), как в `payment_claim_race_test.dart`. Работу
/// делает настоящий `SaleUseCaseImpl`, гашение — настоящий
/// `CertificateDao`.
library;

import 'dart:async';

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
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/sale/receipt_line.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late LocalPaymentService payments;
  late _GatedSaleUseCase gate;
  late CertificateIssuer issuer;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const bankAccountId = 12;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

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

  Future<GiftCertificate> cert(String number) async =>
      (await db.certificateDao.byNumber(number))!;

  Future<Decimal> liabilityBalance() async {
    final accounts = await db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    if (accounts.isEmpty) return Decimal.zero;
    return accounts.first.value ?? Decimal.zero;
  }

  /// Вид «Сертификат» заводится **выключенным** (задача 14). Оператор
  /// включает его настройкой, и без этого движения ни одна оплата
  /// сертификатом не проходит — что проверяется отдельным случаем ниже.
  Future<void> enableCertificateKind() async {
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
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
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(posAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(bankAccountId),
            type: AccountType.customBank,
            name: const Value('Эквайринг'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
          ),
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
    checkout = LocalSaleCheckoutService(db: db, cart: cart, logger: logger);
    gate = _GatedSaleUseCase(db: db, logger: logger);
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: gate,
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    issuer = LocalCertificateIssuer(db: db, logger: logger);
    await enableCertificateKind();
  });

  tearDown(() async {
    if (gate.holdFirst && !gate.released) gate.release();
    await db.close();
  });

  group('гашение и продажа — либо оба, либо ни одного', () {
    test('упавшая продажа не оставляет несписанного сертификата', () async {
      // Проба шага 1 задачи 21. Диверсия, которая её краснит: вынести
      // `certificateDao.redeem` из транзакции `perform` в `_plan` — то
      // есть списать до продажи. Тогда упавшая продажа оставляет
      // сертификат погашенным, покупатель отдал бумажку и не получил
      // товара, а касса об этом не знает.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final view = await receiptWith(); // 500

      gate.failFirst = true;
      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            certificates: const [CertificateTender(number: 'C-1')],
          ),
          mv(view, 9),
        ),
        throwsA(anything),
      );

      expect(
        (await cert('C-1')).balance,
        d('500'),
        reason:
            'либо оба, либо ни одного: иначе это подарок, повторяемый '
            'бесконечно',
      );
      expect((await cert('C-1')).status, CertificateStatus.active);
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });

    test('удавшаяся продажа списывает ровно один раз', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final view = await receiptWith(); // 500

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('500'));
      expect(outcome.change, Decimal.zero);
      expect((await cert('C-1')).balance, Decimal.zero);
      expect((await cert('C-1')).status, CertificateStatus.redeemed);

      // Строка оплаты **несёт номер бумажки**: без него гашение
      // непогасимо, а возврат — невозвратен.
      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows, hasLength(1));
      expect(rows.single.kindId, SystemPaymentKindIds.certificate);
      expect(rows.single.reference, 'C-1');
      expect(rows.single.amount, d('500'));

      // **Ни тенге в выручку.** Деньги за сертификат пришли раньше;
      // положить их в кассу второй раз значит удвоить выручку смены.
      expect(await balanceOf(posAccountId), Decimal.zero);
      // Обязательство закрыто товаром: было 500, стало 0.
      expect(await liabilityBalance(), Decimal.zero);
    });

    test('повтор той же команды не гасит второй раз', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final view = await receiptWith();

      final request = PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      );
      await payments.complete(7, request, mv(view, 9));
      final again = await payments.complete(7, request, mv(view, 9));

      expect(again.repeat, isTrue);
      expect((await cert('C-1')).balance, Decimal.zero);
      expect(
        (await cert('C-1')).nominal - (await cert('C-1')).balance,
        d('500'),
        reason: 'погашено ровно 500, а не 1000',
      );
    });
  });

  group('сертификат больше суммы чека', () {
    test('остаток остаётся НА БУМАЖКЕ, сдачи наличными нет', () async {
      // **Решение задачи 21, а не расчёт.** Сдача с сертификата — способ
      // обналичить: купил картой на 5000, отоварил на 500, забрал 4500
      // наличными. Полный разбор — докстринг `CertificateApplication`.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      final view = await receiptWith(); // 500

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('500'));
      expect(
        outcome.change,
        Decimal.zero,
        reason: 'сдача с сертификата — это обнал',
      );
      expect((await cert('C-1')).balance, d('4500'));
      expect(
        (await cert('C-1')).status,
        CertificateStatus.active,
        reason: 'бумажка остаётся годной — с ней ещё придут',
      );
      expect(
        await balanceOf(posAccountId),
        Decimal.zero,
        reason: 'из ящика не вышло ни тенге',
      );
      expect(await liabilityBalance(), d('4500'));

      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows, hasLength(1));
      expect(
        rows.single.amount,
        d('500'),
        reason: 'в чеке записан зачёт на 500, а не номинал на 5000',
      );
    });

    test('сертификат меньше чека — остаток добирается наличными', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('300'),
      );
      final view = await receiptWith(); // 500

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('200'),
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('500'));
      expect(outcome.change, Decimal.zero);
      expect((await cert('C-1')).balance, Decimal.zero);
      expect(await balanceOf(posAccountId), d('200'));

      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows, hasLength(2));
      expect(
        rows.map((p) => p.amount).fold(Decimal.zero, (a, b) => a + b),
        d('500'),
      );
      final byKind = {for (final r in rows) r.kindId: r.amount};
      expect(byKind[SystemPaymentKindIds.cash], d('200'));
      expect(byKind[SystemPaymentKindIds.certificate], d('300'));
    });

    test('нехватки наличных при сертификате касса не выдумывает', () async {
      // Слом в обе стороны: сертификат обязан **уменьшать** требуемые
      // наличные. Раскладка, забывшая вычесть его из суммы к доплате,
      // потребовала бы 500 наличными при бумажке на 300.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('300'),
      );
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('199'),
            certificates: const [CertificateTender(number: 'C-1')],
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payInsufficientCode),
        ),
      );
      expect(
        (await cert('C-1')).balance,
        d('300'),
        reason: 'отказ до единой записи — сертификат не тронут',
      );
    });
  });

  group('Σ строк оплаты == сумма чека — сторож, а не украшение', () {
    /// # Почему этот случай **безналичный**, и это не вкусовщина
    ///
    /// «Диверсия покраснела» и «покраснел **тот** сторож, ради которого
    /// она ставилась» — разные утверждения, и разница измерена соседними
    /// задачами того же яруса: у них диверсия раскладки краснела
    /// `payment_insufficient`, то есть мерила соседний сторож, а до
    /// `payment_unbalanced` дело не доходило вовсе.
    ///
    /// Наличный путь проходит через «наличных меньше суммы к оплате», и
    /// он способен ответить раньше. Безналичный этой ветви не имеет:
    /// `needsCash` у карты — ноль, и первым, кто может возразить, остаётся
    /// именно сверка сумм.
    ///
    /// # Замер, и он назван поимённо
    ///
    /// Диверсия — «снят потолок бумажки» (`amountFor => balance`).
    /// Краснеет **второй** случай группы, где бумажка больше чека:
    /// `WireRefusal(payment_unbalanced: сумма строк оплаты (5000) не равна
    /// сумме чека (500))`, брошенный сверкой сумм в
    /// `LocalPaymentService._plan`. Сторож, оставленный задачей 14 «для
    /// следующего вида оплаты», сработал ровно на нём.
    ///
    /// **Первый случай той же диверсией НЕ краснеет, и это сказано
    /// вслух:** бумажка на 300 против чека на 500 меньше недостачи, и
    /// снятый потолок ничего не меняет — `min(300, 500)` и `300` дают одно
    /// число. Случай нужен как обратная сторона (обычная смешанная оплата
    /// сертификатом и картой проходит), а не как замер сторожа.
    test('сертификат вместе с картой: сумма сходится, чек проходит', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('300'),
      );
      final view = await receiptWith(); // 500

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.card,
          accountId: bankAccountId,
          approvalCode: '000000',
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('500'));
      expect(outcome.change, Decimal.zero);

      // Утверждения о полях, а не о балансе: баланс сойдётся и у кассы,
      // списавшей бумажку дважды.
      expect((await cert('C-1')).balance, Decimal.zero);
      expect(await balanceOf(bankAccountId), d('200'));
      expect(
        await balanceOf(posAccountId),
        Decimal.zero,
        reason: 'наличных в этом чеке не было ни тенге',
      );

      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows, hasLength(2));
      final byKind = {for (final r in rows) r.kindId: r.amount};
      expect(byKind[SystemPaymentKindIds.card], d('200'));
      expect(byKind[SystemPaymentKindIds.certificate], d('300'));
      expect(
        rows.map((p) => p.amount).fold(Decimal.zero, (a, b) => a + b),
        d('500'),
        reason: 'Σ строк оплаты == сумма чека',
      );
    });

    test('сертификат больше безналичного чека: карты не остаётся', () async {
      // Тот же путь, но потолок бумажки работает в другую сторону: чек
      // покрыт целиком, безналичной строки нет вовсе, и сумма всё равно
      // сходится. Диверсия «снят потолок» краснеет здесь тем же
      // `payment_unbalanced`.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      final view = await receiptWith(); // 500

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.card,
          accountId: bankAccountId,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('500'));
      expect((await cert('C-1')).balance, d('4500'));
      expect(await balanceOf(bankAccountId), Decimal.zero);

      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows, hasLength(1));
      expect(rows.single.kindId, SystemPaymentKindIds.certificate);
      expect(rows.single.amount, d('500'));
    });
  });

  group('двойное предъявление', () {
    test('дважды в одной оплате — отказ ДО раскладки', () async {
      // Чек на 1000 и бумажка на 500, названная дважды. Без проверки
      // раскладка насчитала бы **1000 зачёта с остатка 500**: каждая
      // строка порознь проходит потолок (`min(500, недостача)`), а вместе
      // они требуют вдвое больше, чем есть. Дальше условный `UPDATE`
      // внутри транзакции откатил бы чек `certificate_race` — «остаток
      // изменился, повторите», — и повтор не помог бы ни разу.
      //
      // Отказ до раскладки называет ту беду, которая есть, и лечится он
      // тем, что кассир и так делает руками: убрать повтор.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final view = await receiptWith(quantity: 2); // 1000

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            certificates: const [
              CertificateTender(number: 'C-1'),
              CertificateTender(number: 'C-1'),
            ],
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateDuplicateCode,
          ),
        ),
      );
      expect((await cert('C-1')).balance, d('500'));
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });

    test('два РАЗНЫХ сертификата в одной оплате складываются', () async {
      // Слом в обе стороны у случая выше: сторож, запрещающий два номера,
      // запретил бы обычный день — покупателю дарят по одному, а тратит
      // он сразу.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('300'),
      );
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-2',
        nominal: d('300'),
      );
      final view = await receiptWith(); // 500

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [
            CertificateTender(number: 'C-1'),
            CertificateTender(number: 'C-2'),
          ],
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('500'));
      expect(outcome.change, Decimal.zero);
      expect((await cert('C-1')).balance, Decimal.zero);
      expect(
        (await cert('C-2')).balance,
        d('100'),
        reason: 'вторая гасится только на недостачу, а не целиком',
      );
      expect((await cert('C-2')).status, CertificateStatus.active);
      expect(await balanceOf(posAccountId), Decimal.zero);
    });

    test('погашенный, поданный в СЛЕДУЮЩИЙ чек, отвергается', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final first = await receiptWith();
      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(first, 9),
      );

      final second = await receiptWith();
      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            certificates: const [CertificateTender(number: 'C-1')],
          ),
          mv(second, 19),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateExhaustedCode,
          ),
        ),
      );
      expect(await db.paymentDao.countBySale(second.receiptNo!, 1), 0);
      expect((await cert('C-1')).balance, Decimal.zero);
    });

    test('ГОНКА: остаток, ушедший между раскладкой и деньгами', () async {
      // Заслон раскладки (`_plan` спрашивает остаток) заслоном **не
      // является**: между чтением остатка и записью помещается чужая
      // транзакция. Настоящий заслон — условный `UPDATE` внутри
      // транзакции продажи, и здесь он и меряется.
      //
      // Расписание выстраивается на шве, объявленном продуктом:
      // `SaleUseCase` — довод конструктора `LocalPaymentService`.
      // Гонщик встаёт **внутри** `perform`, уже посчитав раскладку по
      // остатку 500; пока он стоит, бумажку гасит второй чек.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final view = await receiptWith(); // 500

      gate.holdFirst = true;
      final first = payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );
      await gate.atDoor;

      // Пока чек стоит перед деньгами, бумажку гасят мимо него — так же,
      // как это сделала бы соседняя касса или соседняя вкладка.
      expect(
        await db.certificateDao.redeem(number: 'C-1', amount: d('500')),
        1,
      );

      gate.release();
      Object? refusal;
      try {
        await first;
      } catch (e) {
        refusal = e;
      }

      expect(
        refusal,
        isA<WireRefusal>().having((r) => r.code, 'code', certificateRaceCode),
        reason: 'проигравший обязан получить названный отказ, а не пройти',
      );
      // **Главное утверждение случая — не отказ, а откат.** Товар не
      // должен уехать за бумажку, которой уже нет.
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      expect(
        (await db.productInfoDao.findByUcode(100))!.quantity,
        d('100'),
        reason: 'остаток товара не списан',
      );
      expect((await cert('C-1')).balance, Decimal.zero);
      expect(
        (await db.saleDao.findByKey(view.receiptNo!, 1))!.state,
        isNot(1),
        reason: 'чек не стал проданным',
      );
    });
  });

  group('вид, выключенный оператором', () {
    test('выключённый сертификат не принимается кассой', () async {
      await db.paymentKindDao.put(
        SystemPaymentKinds.byId(
          SystemPaymentKindIds.certificate,
        ).copyWith(isActive: false),
      );
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            certificates: const [CertificateTender(number: 'C-1')],
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payKindInactiveCode),
        ),
      );
      expect((await cert('C-1')).balance, d('500'));
    });
  });

  group('срок и ПИН на настоящем пути', () {
    test('просроченный отказывает и остаётся помеченным', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
        expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1,
      );
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            certificates: const [CertificateTender(number: 'C-1')],
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateExpiredCode,
          ),
        ),
      );
      // Отметка пережила отказ: она написана **вне** транзакции продажи.
      expect((await cert('C-1')).status, CertificateStatus.expired);
    });

    test('неверный ПИН не пропускает к оплате', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
        pin: '4821',
      );
      final view = await receiptWith();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            certificates: const [CertificateTender(number: 'C-1', pin: '0000')],
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificatePinWrongCode,
          ),
        ),
      );
      expect((await cert('C-1')).balance, d('500'));

      // Слом в обе стороны: верный ПИН проходит.
      final ok = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1', pin: '4821')],
        ),
        mv(view, 10),
      );
      expect(ok.paid, d('500'));
      expect((await cert('C-1')).balance, Decimal.zero);
    });
  });
}

/// `SaleUseCase`, останавливающий или роняющий **первый** `perform`.
///
/// Тот же шов и тот же приём, что в `payment_claim_race_test.dart`:
/// подделывается только расписание, работу делает настоящий
/// `SaleUseCaseImpl`.
class _GatedSaleUseCase extends SaleUseCaseImpl {
  _GatedSaleUseCase({required super.db, required super.logger});

  final _atDoor = Completer<void>();
  final _hold = Completer<void>();

  Future<void> get atDoor => _atDoor.future;

  bool get released => _hold.isCompleted;

  void release() => _hold.complete();

  bool holdFirst = false;

  bool failFirst = false;

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
    if (n == 0) {
      if (failFirst) throw StateError('perform упал');
      if (holdFirst) {
        _atDoor.complete();
        await _hold.future;
      }
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
