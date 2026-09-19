/// Возврат чека, оплаченного сертификатом: деньги возвращаются **бумажкой**,
/// а не в руки — задача 21, уточнённая решениями заказчика 2026-09-16.
///
/// # Что изменило решение 2 (2026-09-16)
///
/// Прежде доля сертификата возвращалась **на ту же бумажку**
/// (`CertificateDao.restore`), и пробы этого файла утверждали её
/// восстановленный остаток. Заказчик решение отменил: старый сертификат
/// остаётся погашенным навсегда, а покупатель получает **новый** на сумму,
/// которую тот закрыл (практика Спортмастера, М.Видео, Magnum). Довод —
/// бумажка, «ожившая» задним числом, неотличима от непогашенной, и её
/// предъявляют второй раз.
///
/// Поэтому утверждения ниже смотрят на **две** бумажки: старая обязана
/// остаться на нуле, новая — держать деньги. Обязательство кассы при этом
/// не изменилось ни на тенге, и числа `liabilityBalance()` те же, что были
/// до правки: старое закрыто продажей, новое взято выпуском.
///
/// # Почему это решение, а не мелочь раскладки
///
/// Живых денег строка сертификата в ящик не приносила: они пришли при
/// выпуске, может быть — в другую смену, может быть — полгода назад, и
/// лежат обязательством кассы. Выдать их сегодняшними наличными значит,
/// во-первых, отдать чужие деньги из чужой смены, а во-вторых — вернуть
/// тот самый обнал, который запрещён у сдачи (`givesChange = false`):
/// купил сертификат картой, купил товар, вернул товар, получил наличные.
///
/// # Что здесь считается числами
///
/// Настоящая база, настоящая корзина, настоящий `LocalPaymentService`,
/// настоящий `SaleUseCaseImpl`, настоящий `RefundUseCaseImpl` и настоящий
/// `CertificateDao`. Подставлен только фискальный узел, которого в этой
/// кассе нет.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
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
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../../helpers/cash_drawer.dart';

import '../../../helpers/discount_authority.dart';

class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late CertificateIssuer issuer;
  late Talker logger;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const customerId = 5;
  const cashbackAccountId = 13;
  const agentMainAccountId = 14;

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

  /// Чек на 1000: две штуки по 500.
  Future<CartView> receipt() async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.setQuantity(7, view.lines.single.id, d('2'), mv(view, 3));
    return view;
  }

  Future<int> refund(
    int receiptNo,
    Decimal amount, {
    int? customerLocalId,
  }) async {
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
      amount: amount,
      userId: 4,
      saleReceiptNo: receiptNo,
      salePosId: 1,
      customerLocalId: customerLocalId,
      products: const [],
    );
    return refundId;
  }

  /// Повторить возврат **по той же строке `Refunds`** — то, чем меряется
  /// достижимость хвоста 2026-09-19 (разбор — у самой пробы внизу файла).
  ///
  /// Настоящий второй проход, а не выдуманный: те же доводы, тот же
  /// `refundLocalId`, новый экземпляр сервиса — ровно то, что случилось бы
  /// при повторе кадра провода или перезапуске кассы между попытками.
  Future<void> refundAgain(
    int refundId,
    int receiptNo,
    Decimal amount, {
    int? customerLocalId,
  }) => RefundUseCaseImpl(
    db: db,
    logger: logger,
    fiscal: const RefusingFiscalService(),
  ).perform(
    refundLocalId: refundId,
    amount: amount,
    userId: 4,
    saleReceiptNo: receiptNo,
    salePosId: 1,
    customerLocalId: customerLocalId,
    products: const [],
  );

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

  Future<GiftCertificate> cert(String number) async =>
      (await db.certificateDao.byNumber(number))!;

  Future<Decimal> liabilityBalance() async {
    final accounts = await db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    if (accounts.isEmpty) return Decimal.zero;
    return accounts.first.value ?? Decimal.zero;
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
    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    issuer = LocalCertificateIssuer(db: db, logger: logger);
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
      ).copyWith(isActive: true),
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

  test('возврат чека, оплаченного сертификатом целиком', () async {
    await boot();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('1000'),
    );
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );
    expect((await cert('C-1')).balance, Decimal.zero);

    final refundId = await refund(view.receiptNo!, d('1000'));

    // **Первое утверждение — про бумажку**, потому что она и есть то,
    // что покупатель унесёт. Их теперь две.
    expect(
      (await cert('C-1')).balance,
      Decimal.zero,
      reason: 'старая остаётся погашенной: ожившая бумажка предъявляется дважды',
    );
    expect((await cert('C-1')).status, CertificateStatus.redeemed);

    final issued = await cert('C-1-R$refundId');
    expect(issued.balance, d('1000'), reason: 'деньги ушли на новую бумажку');
    expect(issued.status, CertificateStatus.active, reason: 'с ней ещё придут');

    // Из ящика не вышло ни тенге: денег в нём за этот чек и не было.
    expect(
      await balanceOf(posAccountId),
      Decimal.zero,
      reason: 'выдача наличных за сертификат — обнал через возврат',
    );
    // Обязательство кассы вернулось на место.
    expect(await liabilityBalance(), d('1000'));
  });

  test('частичный возврат возвращает долю, а не всё', () async {
    await boot();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('1000'),
    );
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );

    final refundId = await refund(view.receiptNo!, d('500'));

    // Доля, а не всё: новая бумажка держит ровно возвращённое.
    expect((await cert('C-1')).balance, Decimal.zero);
    expect((await cert('C-1-R$refundId')).balance, d('500'));
    expect(await liabilityBalance(), d('500'));
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  test('смешанный чек: наличные из ящика, сертификат на бумажку', () async {
    await boot();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('600'),
    );
    final view = await receipt(); // 1000
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('400'),
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );
    expect(await balanceOf(posAccountId), d('400'));
    expect((await cert('C-1')).balance, Decimal.zero);

    final refundId = await refund(view.receiptNo!, d('1000'));

    // **Каждая половина возвращается туда, откуда пришла.** Раскладка,
    // отдавшая всю тысячу из ящика, оставила бы кассу на −600 и
    // покупателя с погашенной бумажкой.
    expect(
      await balanceOf(posAccountId),
      Decimal.zero,
      reason: 'из ящика вышло ровно 400 — столько в него и клали',
    );
    expect((await cert('C-1')).balance, Decimal.zero);
    expect(
      (await cert('C-1-R$refundId')).balance,
      d('600'),
      reason: 'сертификатная половина ушла новой бумажкой, а не в ящик',
    );
    expect(await liabilityBalance(), d('600'));
  });

  test('покупателю не записывается долг за возвращённый сертификат', () async {
    // Зеркало дефекта, который задача 14 сняла у долга: доля, вернувшаяся
    // не деньгами, а зачётом, обязана считаться **вернувшейся**. Иначе
    // возврат чека, оплаченного сертификатом, повесил бы на покупателя
    // минус на всю его сумму.
    await boot();
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
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('1000'),
    );
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );

    final refundId = await refund(
      view.receiptNo!,
      d('1000'),
      customerLocalId: customerId,
    );

    expect(
      await balanceOf(agentMainAccountId),
      Decimal.zero,
      reason: 'долга, которого покупатель не делал, быть не должно',
    );
    expect((await cert('C-1-R$refundId')).balance, d('1000'));
  });

  test('возврат на отозванный сертификат — отказ, а не молчание', () async {
    // Бумажка на 2000, потрачено 1000: она остаётся **годной**, и потому
    // её можно отозвать (отзыв погашенной ничего не меняет — отзывать
    // нечего). Между продажей и возвратом владелец объявляет её
    // недействительной: заявили об утере, нашли подделку тиража.
    await boot();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('2000'),
    );
    final view = await receipt(); // 1000
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );
    expect((await cert('C-1')).balance, d('1000'));
    expect((await cert('C-1')).status, CertificateStatus.active);

    await issuer.cancel('C-1');

    await expectLater(
      refund(view.receiptNo!, d('1000')),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          certificateExhaustedCode,
        ),
      ),
    );

    // **Откат целиком**: тихий пропуск оставил бы покупателя без товара и
    // без сертификата, а кассу — с закрытым обязательством.
    expect((await cert('C-1')).balance, d('1000'));
    expect(await liabilityBalance(), d('1000'));
    expect(
      (await db.productInfoDao.findByUcode(100))!.quantity,
      d('98'),
      reason: 'товар не вернулся на остаток',
    );
  });

  // ── строка на бумажку без номера бумажки: находка 2026-09-19 ─────────
  //
  // Найдена по дороге к хвосту повтора и оказалась **настоящей дырой**, в
  // отличие от него. Маршрут `RefundRoute.certificate` выбирается по роду
  // счёта вида оплаты, а не по наличию номера
  // (`RefundAllocation.routeOf`), а выпуск новой бумажки в
  // `_writeReversal` стоит под `if (number != null)` — тогда как
  // `releaseCredit` под ним не стоит.
  //
  // Что мерилось до правки, тем же телом пробы: `бросок=null`,
  // обязательство `0 → 1000`, сертификат в базе один (погашенный), ящик
  // пуст. Покупатель не получил ничего, а касса записала себе долг на
  // 1000 перед тем, у кого на руках нет ни одной бумажки.
  //
  // # Чего эта проба НЕ доказывает
  //
  // Не доказывает, что такая строка приезжает на кассу в жизни: здесь она
  // сделана руками. Доказывает она другое — что **если** приедет, касса
  // скажет слово до денег, а не вырастит обязательство молча. Своим видом
  // оператора на счёт обязательства и синхронизацией с кассы другой
  // сборки такая пара («маршрут есть, документа нет») получается без
  // выдумки.
  test('возврат на бумажку без номера — отказ, а не рост обязательства',
      () async {
    await boot();
    await issuer.issue(by: fullDiscountAuthority, number: 'C-1', nominal: d('1000'));
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );
    // Обязательство закрыто продажей — с этого нуля и считаем.
    expect(await liabilityBalance(), Decimal.zero);

    // Стираем документ-основание у строки оплаты чека.
    await (db.update(db.payments)
          ..where((t) => t.receiptNo.equals(view.receiptNo!)))
        .write(const PaymentsCompanion(reference: Value(null)));

    await expectLater(
      refund(view.receiptNo!, d('1000')),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          certificateRefundNoSourceCode,
        ),
      ),
    );

    // **Главное — ничего не сдвинулось.** Отказ стоит до денег, поэтому
    // проверяются все три числа, а не только счёт обязательства.
    expect(
      await liabilityBalance(),
      Decimal.zero,
      reason: 'обязательство выросло без бумажки — долг перед никем',
    );
    expect(
      await db.certificateDao.all(),
      hasLength(1),
      reason: 'новой бумажки не выписано — её и не от чего выписывать',
    );
    expect(await balanceOf(posAccountId), Decimal.zero);
    expect(
      (await db.productInfoDao.findByUcode(100))!.quantity,
      d('98'),
      reason: 'товар не вернулся на остаток: отказ откатывает возврат целиком',
    );
  });

  // ── повтор возврата: хвост, названный дорожкой X/Z 2026-09-19 ─────────
  //
  // Заявка была такая: в ветви `RefundRoute.certificate` метода
  // `_writeReversal` `releaseCredit` зовётся **безусловно**, а
  // `insertCertificate` — только если связи ещё нет. Значит на повторном
  // проходе того же возврата счёт обязательства вырастет, новой бумажки не
  // появится, и равенство «выпущено − погашено» разойдётся.
  //
  // # Путь измерен и оказался ЗАКРЫТ — двумя независимыми линиями
  //
  // Читать код на этот вопрос бесполезно: ветвь действительно написана
  // так, как сказано, и «дыра» видна глазами. Не видно глазами того, что
  // до `releaseCredit` второй проход не доходит.
  //
  // 1. **Структурная линия — уникальный ключ `{refundLocalId, seq}` у
  //    `Payments`.** Строка сторно пишется в начале тела цикла, до
  //    `switch`, и на втором проходе первая же вставка с `seq = 0`
  //    отбивается. Измерено, а не выведено: бросок пробы ниже —
  //    `SqliteException(2067): UNIQUE constraint failed:
  //    payments.refund_local_id, payments.seq`. Транзакция откатывается
  //    целиком, вместе с `releaseCredit`.
  //
  // 2. **Продуктовая линия — `refundLocalId` не переиспользуется.** У
  //    `perform` во всём дереве **один** вызывающий
  //    (`LocalRefundService.complete`), и номер он берёт у
  //    `RefundInitiationUseCase.initiate`, который отдаёт существующую
  //    строку, только пока она в состоянии «в работе» (0). Успешный
  //    `perform` ставит 1 **внутри** транзакции, поэтому повтор получает
  //    новую строку; а если транзакция откатилась, состояние осталось 0 —
  //    но тогда первый проход и не записал ничего.
  //
  // Проба обходит линию 2 намеренно (`refundAgain` зовёт `perform` с тем
  // же номером напрямую) — иначе она мерила бы вторую линию и молчала бы о
  // первой. То есть здесь сторожится **структурная** линия, и краснеет она
  // ровно тогда, когда её снимут.
  //
  // # Чего эта проба НЕ доказывает
  //
  // Не доказывает, что ветвь `certificate` написана правильно: она
  // по-прежнему зовёт `releaseCredit` безусловно, и безопасна только
  // потому, что второго прохода не бывает. Если ключ `{refundLocalId,
  // seq}` когда-нибудь снимут или вставку строки сторно сделают
  // терпимой к конфликту (`insertOnConflictUpdate`), ветвь придётся
  // чинить — и эта проба скажет об этом первой.
  test('повтор возврата не растит обязательство без бумажки', () async {
    await boot();
    await issuer.issue(by: fullDiscountAuthority, number: 'C-1', nominal: d('1000'));
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );
    final refundId = await refund(view.receiptNo!, d('1000'));

    // Снимок после честного возврата — то, с чем сравнивается второй проход.
    expect(await liabilityBalance(), d('1000'));
    expect(await db.certificateDao.linksByRefund(refundId), hasLength(1));
    expect(await db.certificateDao.all(), hasLength(2));

    // Второй проход по той же строке `Refunds`. Исход **не утверждается**,
    // и это выбор: утверждать бросок значило бы сторожить сегодняшний
    // способ заслона, а не само требование. Требование — про деньги, и оно
    // ниже. Сегодня сюда прилетает
    // `SqliteException(2067): UNIQUE constraint failed:
    // payments.refund_local_id, payments.seq`.
    Object? secondPass;
    try {
      await refundAgain(refundId, view.receiptNo!, d('1000'));
    } catch (error) {
      secondPass = error;
    }

    // **Главное утверждение — обязательство.** Вырасти оно могло бы только
    // безусловным `releaseCredit`, ради которого хвост и заводился.
    expect(
      await liabilityBalance(),
      d('1000'),
      reason: 'обязательство выросло на повторе (второй проход: $secondPass) '
          '— это деньги из ничего',
    );
    expect(
      await db.certificateDao.all(),
      hasLength(2),
      reason: 'бумажек тоже не прибавилось',
    );
    expect(await db.certificateDao.linksByRefund(refundId), hasLength(1));
    // И ни одной лишней строки сторно: откат был полным, а не частичным.
    final reversals = (await db.select(db.payments).get())
        .where((p) => p.refundLocalId == refundId);
    expect(reversals, hasLength(1));
  });
}
