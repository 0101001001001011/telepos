// Бонус входит в чек **слагаемым скидки позиции** — и конверт сходится.
//
// # Что было измерено до правки
//
// Списанный бонус уходил с бонусного счёта покупателя, счёт кассы не
// двигался, а раскладка для оператора (`LocalPaymentService._fiscalize`)
// складывала только `AccountType.pos` → наличные и `AccountType.customBank`
// → карта. Бонусная строка оплаты не попадала **никуда**, позиции при этом
// строились на полную сумму. Чек 300 с бонусом 100 уезжал оператору как
// «позиций на 300, оплат на 200», и пересчёт с нулевым допуском отвечал
// кодом 9 (`FiscalErrorCode.validation`) — то есть **каждая продажа с
// бонусом была «деньги взяты, документа нет»**.
//
// # Почему бонус — скидка, а не платёж
//
// `FiscalPaymentKind` — `{cash, card, credit, mobile, tare}`, и подходящего
// члена там нет. Завести его нельзя даром: `WebKassaProvider._paymentType` —
// исчерпывающий `switch` без `default`, новый член ломает сборку (и это
// хорошо, компилятор сторожит). Но главный довод не в перечислении, а в
// налоге: `_buildTax` считает НДС от суммы, которую платит покупатель.
// Объявить бонус платежом значит сказать оператору, что покупатель заплатил
// полную цену, — то есть **завысить базу**. Объявить его вторым числом
// скидки (второе поле, свой `totalDiscount`, «строка оплаты плюс скидка»)
// значит вычесть его дважды и **занизить** базу на `rate/(100+rate) × B` —
// для КЗ при 12 % это 10,71 % от суммы бонуса на каждом чеке.
//
// Слагаемое в **одном** поле `Discount` — единственная раскладка, при
// которой бонус учтён ровно один раз.
//
// # Почему проба идёт через настоящую кассу
//
// Позиции, собранные руками, проверяют арифметику самой пробы. Здесь чек
// набирается настоящим `LocalCartService`, оплата с бонусом проходит
// настоящим `LocalPaymentService.complete` (он же ставит оба потолка
// бонуса), позиции строит `FiscalServiceImpl._buildSalePositions` из строк
// базы, конверт собирает настоящий `WebKassaProvider.buildCheckPayload`, а
// сводит его **тот же `recountCheck`**, которым сводит эмулятор WebKassa
// (`lib/emulators/webkassa/state.dart`). Нулевой допуск — оттуда же.
//
// # Слом в обе стороны
//
// Каждый случай ниже держит **три** утверждения, а не одно:
//
// * `recount.complaint == null` — суммы сошлись;
// * `position.unitPrice` — цена в конверте осталась ценой ДО скидки. Без
//   этого «бонус уменьшил цену позиции» свёл бы суммы и всё равно соврал:
//   оператор увидел бы чек дешевле прейскуранта без объяснения;
// * `payments` — бонуса нет среди оплат, и сумма оплат ровно
//   `сумма чека − бонус`. Без этого «бонус вторым числом» прошёл бы.
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import '../../emulators/webkassa/state.dart' as emul;
import '../../helpers/discount_authority.dart';
import '../../helpers/cash_drawer.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late LocalPaymentService payments;
  late Talker logger;
  late _CapturingRegistry registry;

  const posAccountId = 11;
  const bonusAccountId = 21;
  const customerId = 5;
  const terminalId = 7;

  const barcodes = <String>['4870001234567', '4870001234574', '4870001234581'];

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  Future<void> seedProduct(int ucode, String barcode, String price) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            name: 'Product $ucode',
            type: 0,
            measure: 0,
            quantity: Value(d('1000')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            sellingPrice: Value(d(price)),
          ),
        );
  }

  FiscalSettings fiscalSettings({bool vatPayer = false}) => FiscalSettings(
    operatorType: FiscalOperatorType.webkassa,
    apiKey: 'WKD-1',
    login: 'a@b.kz',
    cashboxUniqueNumber: 'SWK00000001',
    isVatPayer: vatPayer,
    vatRatePercent: Decimal.fromInt(12),
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            cashBoxName: Value('Касса 1'),
            companyName: Value('ТОО Ромашка'),
            // Задача 12: тумблер кассы «продажа со скидкой» получил
            // читателя на самой кассе, а не только на экране. Пробы
            // ниже назначают скидку, значит тумблер обязан быть
            // включён — иначе они мерили бы отказ политики.
            sellInDiscount: Value(true),
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
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(posAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(d('0')),
            visibleToPos: const Value(true),
          ),
        );
    // Бонусный счёт покупателя. Тип `cashback` (7) — тот, который
    // раскладка `_fiscalize` не относит ни к наличным, ни к карте, и
    // относить не должна: бонус не деньги кассы.
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(bonusAccountId),
            type: AccountType.cashback,
            name: const Value('Бонусы клиента'),
            value: Value(d('1000')),
            visibleToPos: const Value(false),
          ),
        );
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(customerId),
            name: Value('Покупатель'),
            phone: Value(77011234567),
            cashbackAccountId: Value(bonusAccountId),
          ),
        );

    await seedProduct(100, barcodes[0], '100');
    await seedProduct(200, barcodes[1], '100');
    await seedProduct(300, barcodes[2], '1500');

    // Строка **чужого** чека — правило нуля (`qa-depth`). База, где верный
    // ответ совпадает с «всё, что нашлось», не отличает выборку от её
    // отсутствия, а раскладка бонуса делит именно по списку строк: попади
    // сюда лишняя, доли всех остальных поехали бы, и сумма позиций
    // разошлась бы с оплатой числом, а не догадкой.
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: const Value(999),
            posId: const Value(1),
            ucode: const Value(100),
            barcode: Value(int.parse(barcodes[0])),
            categoryId: const Value(1),
            quantity: Value(d('5')),
            price: Value(d('10')),
            priceBefore: Value(d('9999')),
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
    checkout = LocalSaleCheckoutService(db: db, cart: cart, logger: logger);
    registry = _CapturingRegistry();
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: FiscalServiceImpl(
        db: db,
        registry: registry,
        settingsSource: _FixedSettings(fiscalSettings()),
        logger: logger,
      ),
      fiscalQueue: DriftFiscalQueueStore(db),
      printer: null,
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Провести чек с бонусом и вернуть пересчёт конверта тем же кодом,
  /// каким его считает эмулятор оператора.
  Future<emul.Recount> settleWithBonus(CartView view, Decimal bonus) async {
    final total = view.total;
    final cashDue = total - bonus;
    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(
        type: PaymentType.cash,
        cashReceived: cashDue,
        bonusUsed: bonus,
        customerId: customerId,
      ),
      mv(view, 90),
    );
    await payments.pendingSideEffects;

    expect(
      outcome.fiscal.state,
      FiscalState.done,
      reason:
          'чек обязан дойти до провайдера, иначе мерить нечего '
          '(состояние ${outcome.fiscal.state.name})',
    );

    final req = registry.provider.captured.single;
    expect(
      req.positions.every((p) => p.unitPrice != d('9999')),
      isTrue,
      reason: 'строка чужого чека не имеет права попасть в конверт',
    );

    final provider = WebKassaProvider(
      settings: fiscalSettings(),
      logger: logger,
    );
    final body = provider.buildCheckPayload(req, 2, token: 'T');
    final recount = emul.recountCheck(
      body.cast<String, Object?>(),
      emul.VatMode.off,
    );
    // ignore: avoid_print
    print('\n--- пересчёт конверта (бонус $bonus) ---');
    for (final r in recount.reasons) {
      // ignore: avoid_print
      print(r);
    }
    return recount;
  }

  Future<CartView> add(CartView view, String barcode, int seq) =>
      cart.addByBarcode(terminalId, barcode, mv(view, seq));

  Future<CartView> start() =>
      cart.start(terminalId: terminalId, wholesale: false, meta: m(1, 0));

  group('бонус — слагаемое скидки, а не второе число', () {
    test('чек 300 с бонусом 100: позиции минус скидка равны оплатам', () async {
      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('3'),
        mv(view, 3),
      );
      expect(view.total, d('300'));

      final recount = await settleWithBonus(view, d('100'));

      expect(
        recount.complaint,
        isNull,
        reason:
            'оператор обязан свести чек с бонусом: 3 × 100 − 100 = 200 '
            'против оплаты наличными 200',
      );
      expect(recount.positionsTotal, d('200'));

      final req = registry.provider.captured.single;
      final position = req.positions.single;

      // Слом №1: «бонус уменьшил цену позиции». Свёл бы суммы и всё равно
      // соврал — цена уценена, скидки нет.
      expect(
        position.unitPrice,
        d('100'),
        reason: 'в конверт уезжает цена ДО скидки, бонус её не трогает',
      );
      expect(
        position.discountOr,
        d('100'),
        reason: 'бонус стал скидкой позиции, а не исчез',
      );
      expect(
        req.totalDiscount,
        d('100'),
        reason: 'итог чека — сумма позиционных скидок',
      );

      // Слом №2: «бонус вторым числом» — строкой оплаты либо своим полем.
      expect(
        req.payments.map((p) => p.amount).fold(Decimal.zero, (a, b) => a + b),
        d('200'),
        reason: 'бонус не платёж: оплат ровно на 300 − 100',
      );
      expect(req.payments.map((p) => p.kind).toList(), [
        FiscalPaymentKind.cash,
      ], reason: 'бонусной строки оплаты в конверте быть не должно');
    });

    test('бонус СКЛАДЫВАЕТСЯ с ручной скидкой кассира в одном поле', () async {
      // Самый опасный случай: у поля `Discount` два претендента разом.
      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('3'),
        mv(view, 3),
      );
      view = await cart.setDiscountAmount(
        terminalId,
        view.lines.single.id,
        d('100'),
        mv(view, 4),
        by: fullDiscountAuthority,
      );
      expect(view.total, d('200'), reason: 'после ручной скидки — 200');

      final recount = await settleWithBonus(view, d('50'));

      expect(recount.complaint, isNull);
      expect(recount.positionsTotal, d('150'));

      final position = registry.provider.captured.single.positions.single;
      expect(position.unitPrice, d('100'), reason: 'цена ДО обеих скидок');
      expect(
        position.discountOr,
        d('150'),
        reason: 'ручная 100 плюс бонус 50 — одно поле, одно число',
      );
    });

    test('бонус 500 на три строки: остаток по названному правилу', () async {
      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await add(view, barcodes[1], 3);
      view = await add(view, barcodes[2], 4);
      final lineIds = [for (final l in view.lines) l.id];
      for (var i = 0; i < lineIds.length; i++) {
        view = await cart.setQuantity(
          terminalId,
          lineIds[i],
          d('3'),
          mv(view, 5 + i),
        );
      }
      // 300 + 300 + 4500 = 5100.
      expect(view.total, d('5100'));

      final recount = await settleWithBonus(view, d('500'));

      expect(recount.complaint, isNull);
      expect(recount.positionsTotal, d('4600'));

      final req = registry.provider.captured.single;
      expect(
        FiscalPositionBuilder.sumDiscounts(req.positions),
        d('500'),
        reason: 'сумма долей — ровно бонус, ни копейкой больше',
      );
      expect(req.totalDiscount, d('500'), reason: 'итог чека — та же сумма');
      // Пропорция: 300/5100 × 500 = 29.41(17), 4500/5100 × 500 = 441.17(6).
      // Округление даёт 29.41 + 29.41 + 441.18 = 500.00 — остаток −0.06
      // достался бы самой большой строке; здесь округление вверх у неё уже
      // случилось, и правило проверяется тем, что сумма ровна.
      expect(req.positions.map((p) => p.discountOr).toList(), [
        d('29.41'),
        d('29.41'),
        d('441.18'),
      ], reason: 'доли пропорциональны суммам строк, остаток — в большей');
    });

    test(
      'бонус покрывает чек целиком: позиции сходятся с нулём оплат',
      () async {
        var view = await start();
        view = await add(view, barcodes[0], 2);
        view = await cart.setQuantity(
          terminalId,
          view.lines.single.id,
          d('3'),
          mv(view, 3),
        );

        final recount = await settleWithBonus(view, d('300'));

        expect(recount.complaint, isNull);
        expect(recount.positionsTotal, Decimal.zero);

        final req = registry.provider.captured.single;
        expect(req.positions.single.discountOr, d('300'));
        expect(
          req.payments.map((p) => p.amount).fold(Decimal.zero, (a, b) => a + b),
          Decimal.zero,
        );
      },
    );

    test('чек без бонуса не обрастает скидкой', () async {
      // Правило нуля: правка, добавляющая слагаемое, обязана оставить
      // бесскидочный чек бесскидочным.
      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('3'),
        mv(view, 3),
      );

      final recount = await settleWithBonus(view, Decimal.zero);
      expect(recount.complaint, isNull);
      expect(recount.positionsTotal, d('300'));

      final req = registry.provider.captured.single;
      expect(req.positions.single.discount, isNull);
      expect(req.totalDiscount, Decimal.zero);
    });
  });

  group('сторож сводит конверт ПЕРЕД отправкой', () {
    // Новый сторож обязан покраснеть сам — иначе он принят на веру.
    // Здесь чек собирается заведомо несводимым (оплат меньше, чем позиций,
    // и бонусом это не объяснено), и проверяется **два** утверждения:
    // касса отказала названной причиной **и** провайдера не позвала.
    // Второе важнее первого: сторож, который отправляет и потом жалуется,
    // сторожем не является.
    FiscalServiceImpl service(_CapturingRegistry r) => FiscalServiceImpl(
      db: db,
      registry: r,
      settingsSource: _FixedSettings(fiscalSettings()),
      logger: logger,
    );

    /// Строка `Sales` заводится вместе со строкой товара, и это не
    /// украшение пробы: с 2026-09-18 эпоха ключа идемпотентности — время
    /// самой продажи (`FiscalIdempotency`), и чек без строки в `Sales`
    /// фискализации не подлежит вовсе. До этого случаи ниже собирали
    /// документ для продажи, которой в базе не было.
    Future<void> seedLine(int receiptNo, String qty, String price) async {
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: 1,
              userId: 1,
              amount: d(qty) * d(price),
              time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          );
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion(
              receiptNo: Value(receiptNo),
              posId: const Value(1),
              ucode: const Value(100),
              barcode: Value(int.parse(barcodes[0])),
              categoryId: const Value(1),
              quantity: Value(d(qty)),
              price: Value(d(price)),
              priceBefore: Value(d(price)),
            ),
          );
    }

    test('оплат меньше позиций: отказ до провайдера, причина числом', () async {
      await seedLine(555, '3', '100');
      final r = _CapturingRegistry();

      final result = await service(r).fiscalizeSale(
        saleReceiptNo: 555,
        salePosId: 1,
        amount: d('300'),
        cashAmount: d('200'),
        cardAmount: Decimal.zero,
        mobileAmount: Decimal.zero,
        // Бонуса нет — значит объяснить недостачу нечем.
        bonusAmount: Decimal.zero,
        offsetAmount: Decimal.zero,
        offsetLayout: OffsetFiscalLayout.discount,
        excludeCertificatePositions: false,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, FiscalErrorCode.validation);
      expect(
        result.errorMessage,
        contains('сумма позиций 300, сумма оплат 200'),
        reason: 'причина обязана быть числом, а не «ошибка фискализации»',
      );
      expect(
        r.provider.captured,
        isEmpty,
        reason:
            'сторож стоит ПЕРЕД отправкой: несводимый конверт не имеет права '
            'уехать оператору и вернуться кодом 9',
      );
    });

    test('тот же чек с бонусом 100 сторож пропускает', () async {
      // Ноль выше не пустой: та же касса, тот же чек, разница только в
      // бонусе. Без этой половины сторож мог бы отказывать всему подряд.
      await seedLine(556, '3', '100');
      final r = _CapturingRegistry();

      final result = await service(r).fiscalizeSale(
        saleReceiptNo: 556,
        salePosId: 1,
        amount: d('300'),
        cashAmount: d('200'),
        cardAmount: Decimal.zero,
        mobileAmount: Decimal.zero,
        bonusAmount: d('100'),
        offsetAmount: Decimal.zero,
        offsetLayout: OffsetFiscalLayout.discount,
        excludeCertificatePositions: false,
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(r.provider.captured, hasLength(1));
      expect(r.provider.captured.single.positions.single.discountOr, d('100'));
    });
  });

  group('раскладка бонуса — правило, записанное один раз', () {
    test('доли пропорциональны, сумма долей ровна бонусу', () {
      final shares = FiscalPositionBuilder.distributeBonus(
        bonus: d('100'),
        lineTotals: [d('300'), d('300'), d('4500')],
      );
      expect(shares.fold(Decimal.zero, (a, b) => a + b), d('100'));
    });

    test('остаток достаётся большей строке, при равенстве — первой', () {
      // 10 на три равные строки: 3.33 × 3 = 9.99, остаток 0.01 — первой.
      final equal = FiscalPositionBuilder.distributeBonus(
        bonus: d('10'),
        lineTotals: [d('100'), d('100'), d('100')],
      );
      expect(equal, [d('3.34'), d('3.33'), d('3.33')]);
      expect(equal.fold(Decimal.zero, (a, b) => a + b), d('10'));

      // 10 на неравные: остаток в самую большую, а не в первую.
      final uneven = FiscalPositionBuilder.distributeBonus(
        bonus: d('10'),
        lineTotals: [d('100'), d('100'), d('700')],
      );
      expect(uneven.fold(Decimal.zero, (a, b) => a + b), d('10'));
      expect(
        uneven[2],
        greaterThan(uneven[0]),
        reason: 'большая строка берёт и большую долю, и остаток',
      );
    });

    test('нулевой бонус даёт нули, пустой чек — пустой список', () {
      expect(
        FiscalPositionBuilder.distributeBonus(
          bonus: Decimal.zero,
          lineTotals: [d('100'), d('200')],
        ),
        [Decimal.zero, Decimal.zero],
      );
      expect(
        FiscalPositionBuilder.distributeBonus(
          bonus: d('10'),
          lineTotals: const [],
        ),
        isEmpty,
      );
    });

    test('чек нулевой суммы бонус не делит', () {
      // Делить пропорционально нечему — деление на ноль обязано быть
      // названным, а не упасть.
      expect(
        FiscalPositionBuilder.distributeBonus(
          bonus: d('10'),
          lineTotals: [Decimal.zero, Decimal.zero],
        ),
        [Decimal.zero, Decimal.zero],
      );
    });
  });

  group('НДС считается от суммы ПОСЛЕ бонуса', () {
    const builder = FiscalPositionBuilder();

    test('бонус уменьшает базу налога ровно один раз', () {
      final vat = Decimal.fromInt(12);
      final settings = fiscalSettings(vatPayer: true);

      final withBonus = builder.build(
        name: 'x',
        quantity: d('3'),
        unitPrice: d('100'),
        lineTotal: d('300'),
        settings: settings,
        extraDiscount: d('100'),
      );
      // Оператор считает строку как `Count × Price − Discount` = 200, и НДС
      // обязан считаться от неё же. База 300 — налог с денег, которых не
      // брали; база 100 — бонус вычтен дважды.
      expect(
        withBonus.tax.amount,
        FiscalPositionBuilder.vatFromGross(d('200'), vat),
      );
      expect(
        withBonus.tax.amount,
        isNot(FiscalPositionBuilder.vatFromGross(d('300'), vat)),
        reason: 'без вычета бонуса база завышена ровно на бонус',
      );
      expect(
        withBonus.tax.amount,
        isNot(FiscalPositionBuilder.vatFromGross(d('100'), vat)),
        reason:
            'двойной вычет занижает базу на 10,71 % от бонуса — ровно та '
            'ошибка, ради которой всё это написано',
      );
    });

    test('пересчёт оператора с НДС сходится на строке с бонусом', () {
      // Тот же случай, но сведённый **чужим** пересчётом: своё выражение
      // здесь было бы вторым мнением о том, что считает оператор.
      final position = builder.build(
        name: 'x',
        quantity: d('3'),
        unitPrice: d('100'),
        lineTotal: d('300'),
        settings: fiscalSettings(vatPayer: true),
        extraDiscount: d('100'),
      );
      final req = FiscalSaleRequest(
        idempotencyKey: 'vat-1',
        localOperationId: 1,
        positions: [position],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: d('200')),
        ],
        totalDiscount: FiscalPositionBuilder.sumDiscounts([position]),
        totalMarkup: FiscalPositionBuilder.sumMarkups([position]),
        occurredAt: DateTime.now(),
      );
      final body = WebKassaProvider(
        settings: fiscalSettings(vatPayer: true),
        logger: Talker(),
      ).buildCheckPayload(req, 2, token: 'T');
      final recount = emul.recountCheck(
        body.cast<String, Object?>(),
        emul.VatMode.included,
      );
      expect(
        recount.complaint,
        isNull,
        reason: 'пересчёт НДС оператора обязан сойтись: ${recount.complaint}',
      );
    });
  });

  group('подарок акции доезжает до конверта — задача 9', () {
    // Задача 9 нашла, что формат завершённого чека не записывался вовсе:
    // `SaleCheckoutService.finalize` был мёртв. Для конверта это значило
    // не «строка чуть неточна», а **отказ оператора на каждой продаже с
    // акцией**: позиции строились из `SaleProducts.price`, куда подарок не
    // попадал, а оплат приходило столько, сколько кассир взял с
    // покупателя. Пересчёт с нулевым допуском отвечал бы кодом 9.
    //
    // Проба идёт настоящим путём оплаты и сводит конверт **тем же**
    // `recountCheck`, которым сводит эмулятор WebKassa.
    test('чек с подарком «2+1»: позиции сходятся с оплатами', () async {
      await db
          .into(db.promotions)
          .insert(
            PromotionsCompanion.insert(
              name: 'Два плюс один',
              triggerUcode: 100,
              rewardUcode: 100,
              triggerQty: const Value(2),
              rewardQty: const Value(1),
            ),
          );

      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('4'),
        mv(view, 3),
      );
      // Четыре штуки по 100, две из них подарочные: 200 к оплате.
      expect(view.subtotal, d('400'));
      expect(view.totalDiscount, d('200'));
      expect(view.total, d('200'));

      final recount = await settleWithBonus(view, Decimal.zero);

      expect(
        recount.complaint,
        isNull,
        reason:
            'подарок акции не доехал до конверта: оператор отвергнет чек '
            'кодом 9 — ${recount.complaint}',
      );

      // Утверждение о **полях**, а не только о балансе: баланс сумм —
      // слабая проверка, конверт может сойтись и соврать. Цена позиции
      // обязана остаться прейскурантной, а подарок — уехать скидкой.
      final position = registry.provider.captured.single.positions.single;
      expect(
        position.unitPrice,
        d('100'),
        reason: 'цена в конверте обязана остаться ценой ДО скидки',
      );
      expect(
        position.quantity,
        d('4'),
        reason: 'покупатель уносит четыре штуки, а не две',
      );
      expect(
        FiscalPositionBuilder.lineDiscount(
          quantity: position.quantity,
          priceBefore: position.unitPrice,
          lineTotal: d('200'),
        ),
        d('200'),
        reason: 'подарок обязан быть скидкой позиции целиком',
      );
    });
  });

  group('сертификат в фискальном документе — задача 21', () {
    /// Выпустить бумажку и провести ею чек целиком.
    Future<emul.Recount> settleWithCertificate(
      CartView view,
      String number,
      Decimal nominal, {
      Decimal? cash,
    }) async {
      final issuer = LocalCertificateIssuer(db: db, logger: logger);
      await issuer.issue(
        by: fullDiscountAuthority,
        number: number,
        nominal: nominal,
      );

      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: cash ?? Decimal.zero,
          certificates: [CertificateTender(number: number)],
        ),
        mv(view, 90),
      );
      await payments.pendingSideEffects;
      expect(
        outcome.fiscal.state,
        FiscalState.done,
        reason:
            'чек обязан дойти до провайдера, иначе мерить нечего '
            '(состояние ${outcome.fiscal.state.name})',
      );

      final req = registry.provider.captured.single;
      final provider = WebKassaProvider(
        settings: fiscalSettings(),
        logger: logger,
      );
      final body = provider.buildCheckPayload(req, 2, token: 'T');
      return emul.recountCheck(body.cast<String, Object?>(), emul.VatMode.off);
    }

    Future<CartView> receipt300() async {
      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('3'),
        mv(view, 3),
      );
      expect(view.total, d('300'));
      return view;
    }

    /// Вид «Сертификат» заводится выключенным (задача 14) — оператор
    /// включает его настройкой, и без этого движения касса его не примет.
    Future<void> enableCertificate({FiscalTreatment? treatment}) async {
      final base = SystemPaymentKinds.byId(SystemPaymentKindIds.certificate);
      await db.paymentKindDao.put(
        base.copyWith(isActive: true, fiscalTreatment: treatment),
      );
    }

    // # Решение задачи 21 «сертификат — платёж» отменено заказчиком 2026-09-14
    //
    // Гашение сертификата — не денежный расчёт (КГД 2020, 2021), и строкой
    // оплаты оператору не едет **никогда**: ни наличными, ни картой. Разницу
    // позиций и оплат закрывает раскладка оператора (по умолчанию —
    // скидкой позиций, практика 1С:Розница КЗ). Довод «скидка занижает
    // базу налога» остаётся вопросом бухгалтеру (A6), а не решением кассы.
    // Живые пробы того же — `test/emulators/webkassa/offset_fiscal_live_test
    // .dart`.
    test(
      'чек, целиком оплаченный сертификатом, до оператора не едет',
      () async {
        await enableCertificate();
        await LocalCertificateIssuer(
          db: db,
          logger: logger,
        ).issue(by: fullDiscountAuthority, number: 'C-1', nominal: d('300'));
        final view = await receipt300();
        final outcome = await payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.cash,
            certificates: const [CertificateTender(number: 'C-1')],
          ),
          mv(view, 90),
        );
        await payments.pendingSideEffects;

        expect(outcome.fiscal.state, FiscalState.notRequired);
        expect(
          registry.provider.captured,
          isEmpty,
          reason: 'денежного расчёта не было — документ не на что выписывать',
        );
      },
    );

    test('сертификат, перенастроенный оператором в «карту», оплатой всё '
        'равно не едет — сторож, а не пожелание', () async {
      // В коде по-прежнему нет ни одного `kindId == 5`: признак — род
      // расчёта и род счёта-получателя вида. Но трактовка-платёж у
      // сертификата — двойная выручка по ККМ, и её снимает
      // `FiscalOffsetSettings.effectiveTreatment` (решения заказчика 1 и 5).
      await enableCertificate(treatment: FiscalTreatment.card);

      final recount = await settleWithCertificate(
        await receipt300(),
        'C-2',
        d('120'),
        cash: d('180'),
      );

      expect(recount.complaint, isNull);
      final req = registry.provider.captured.single;
      expect(req.payments.map((p) => (p.kind, p.amount)).toList(), [
        (FiscalPaymentKind.cash, d('180')),
      ], reason: 'карта на 120 значит, что сторож не сработал');
      expect(req.totalDiscount, d('120'));
    });

    test('сертификат 120 + наличные 180: конверт сходится', () async {
      await enableCertificate();
      final issuer = LocalCertificateIssuer(db: db, logger: logger);
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-3',
        nominal: d('120'),
      );

      final view = await receipt300();
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('180'),
          certificates: const [CertificateTender(number: 'C-3')],
        ),
        mv(view, 90),
      );
      await payments.pendingSideEffects;
      expect(outcome.fiscal.state, FiscalState.done);

      final req = registry.provider.captured.single;
      final provider = WebKassaProvider(
        settings: fiscalSettings(),
        logger: logger,
      );
      final recount = emul.recountCheck(
        provider.buildCheckPayload(req, 2, token: 'T').cast<String, Object?>(),
        emul.VatMode.off,
      );

      expect(recount.complaint, isNull);
      expect(
        recount.positionsTotal,
        d('180'),
        reason: 'позиции после раскладки (а) сведены с живыми деньгами',
      );
      expect(
        req.payments.map((p) => (p.kind, p.amount)).toList(),
        [(FiscalPaymentKind.cash, d('180'))],
        reason:
            'оператор видит наличных ровно столько, сколько в ящике; '
            '300 значит, что гашение сертификата уехало оплатой',
      );
      expect(
        req.totalDiscount,
        d('120'),
        reason: 'раскладка по умолчанию — сертификат скидкой позиции',
      );
      expect(
        req.positions.single.unitPrice,
        d('100'),
        reason: 'цена позиции — полная',
      );
    });

    /// **Выборочная фискализация и сертификат** — ревизия 2026-09-19,
    /// дыра 1, и её обратная сторона: мало решить «уезжает», конверт
    /// такого чека обязан ещё и сойтись.
    ///
    /// # Что было измерено
    ///
    /// На кассе с `ofdSyncType == 2` («только безналичные чеки») вопрос
    /// задавался каждой строке отдельно: «безналична?». Гашение
    /// сертификата — `FiscalTreatment.offsetNotFiscal`, и ответ «нет»
    /// уводил **весь** чек мимо оператора: деньги картой взяты,
    /// фискального документа нет, кассир видит обычную успешную продажу.
    ///
    /// # Почему эта проба живёт здесь, а не только в политике
    ///
    /// `ofd_policy_cashless_kinds_test` спрашивает одно: «уезжает ли». Оно
    /// не знает, что оператор сделает с конвертом, а у сертификата
    /// позиции идут на полную сумму, и оплата — только живыми деньгами:
    /// без раскладки зачёта это код 9, то есть снова «деньги взяты,
    /// документа нет», только по другой причине. Здесь спрошены оба
    /// вопроса разом, и вторым — тем же `recountCheck`, которым сводит
    /// эмулятор оператора.
    test('выборочная фискализация: «карта 180 + сертификат 120» уезжает '
        'оператору и сходится', () async {
      const bankAccountId = 41;
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: const Value(bankAccountId),
              type: AccountType.customBank,
              name: const Value('Банк'),
              value: Value(d('0')),
              visibleToPos: const Value(true),
            ),
          );
      // Касса фискализует **только безналичные чеки**.
      await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
        const ThisPosEntriesCompanion(ofdSyncType: Value(2)),
      );
      await enableCertificate();
      await LocalCertificateIssuer(
        db: db,
        logger: logger,
      ).issue(by: fullDiscountAuthority, number: 'C-4', nominal: d('120'));

      final view = await receipt300();
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.card,
          accountId: bankAccountId,
          approvalCode: '000000',
          certificates: const [CertificateTender(number: 'C-4')],
        ),
        mv(view, 90),
      );
      await payments.pendingSideEffects;

      expect(
        outcome.fiscal.state,
        FiscalState.done,
        reason:
            'картой взято 180 живых тенге. `notRequired` здесь означает '
            '«деньги взяты, документа нет» — и ни отказа, ни полосы',
      );

      final req = registry.provider.captured.single;
      final recount = emul.recountCheck(
        WebKassaProvider(settings: fiscalSettings(), logger: logger)
            .buildCheckPayload(req, 2, token: 'T')
            .cast<String, Object?>(),
        emul.VatMode.off,
      );

      expect(
        recount.complaint,
        isNull,
        reason: 'позиции после раскладки зачёта сведены с живыми деньгами',
      );
      expect(
        req.payments.map((p) => (p.kind, p.amount)).toList(),
        [(FiscalPaymentKind.card, d('180'))],
        reason:
            'оператор видит ровно то, что ушло по карте; гашение '
            'сертификата оплатой не едет',
      );
      expect(req.totalDiscount, d('120'));
      expect(
        (await db.accountDao.findById(bankAccountId))?.value,
        d('180'),
        reason: 'на банковский счёт легли те же 180 — конверт не выдумка',
      );
    });
  });

  group('слияние задач 21 и 23: аванс попадает в конверт РОВНО ОДИН РАЗ', () {
    // # Что здесь измерено, и почему этого не видел ни один из двух наборов
    //
    // Задача 23 (аванс) клала зачёт в конверт **руками**:
    // `cash += plan.prepayment` после цикла вёдер. Это было верно в её
    // дереве — цикл раскладывал по роду счёта, а расчётный счёт покупателя
    // (`agentMain`) не попадал ни в наличные, ни в карту, и без ручной
    // прибавки оператор получил бы «позиций больше, чем оплат».
    //
    // Задача 21 (сертификат) сменила признак цикла на
    // `PaymentKind.fiscalTreatment`. У вида `prepayment` она `cash` — и
    // цикл стал брать ту же строку сам. Две прибавки сложились.
    //
    // Ни один из двух наборов покраснеть не мог: у задачи 21 в дереве не
    // было аванса вовсе, у задачи 23 — трактовки. Сторож живёт здесь,
    // потому что беда видна только оператору: сумма строк `Payments`
    // остаётся верной (`payment_unbalanced` молчит), врёт **конверт**.
    //
    // # Какой именно сторож краснеет — измерено диверсией, а не выведено
    //
    // Диверсия (вернуть прибавку `cash += аванс` после цикла) роняет обе
    // пробы на строке `outcome.fiscal.state == FiscalState.done`, а не на
    // сложении оплат: конверт не доходит до провайдера, потому что его
    // разворачивает **пересчёт перед отправкой**
    // (`FiscalServiceImpl`, задача 7) — оплат 420 при позициях на 300.
    // До `req.payments` дело не доходит вовсе, `captured` пуст.
    //
    // Обе строки нужны, и роли у них разные: `FiscalState` ловит, а
    // сложение **называет размер вранья**, если однажды пересчёт ослабят
    // или допуск перестанет быть нулевым. Утверждать одно сложение было
    // бы ошибкой: оно недостижимо ровно в том случае, ради которого
    // ставилось.
    //
    // Цена дефекта названа его состоянием: `FiscalState.failed` — это
    // «деньги взяты, документа нет» на каждом чеке со смешанным авансом.
    const advanceAccountId = 31;

    Future<void> seedAdvance(String value) async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: const Value(advanceAccountId),
              type: AccountType.agentMain,
              name: const Value('Расчёты с покупателем'),
              value: Value(d(value)),
              visibleToPos: const Value(false),
            ),
          );
      await (db.update(db.agents)..where((a) => a.localId.equals(customerId)))
          .write(const AgentsCompanion(mainAccountId: Value(advanceAccountId)));
      await db.paymentKindDao.put(
        SystemPaymentKinds.byId(
          SystemPaymentKindIds.prepayment,
        ).copyWith(isActive: true),
      );
    }

    test('чек 300: аванс 120 и наличные 180 дают оплат ровно на 300', () async {
      await seedAdvance('500');

      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('3'),
        mv(view, 3),
      );
      expect(view.total, d('300'));

      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('180'),
          prepaymentUsed: d('120'),
          prepaymentReference: 'АВ-1',
          customerId: customerId,
        ),
        mv(view, 90),
      );
      await payments.pendingSideEffects;
      expect(outcome.fiscal.state, FiscalState.done);

      final req = registry.provider.captured.single;
      final total = req.payments
          .map((p) => p.amount)
          .fold(Decimal.zero, (a, b) => a + b);

      // **Число, а не «сошлось».** С двойной прибавкой задачи 23 было бы
      // 420; с трактовкой `cash` до решения заказчика 2026-09-14 — 300.
      // Сегодня зачёт аванса при фискализованном приёме (умолчание) —
      // не оплата вовсе, и в оплатах ровно наличные.
      expect(
        total,
        d('180'),
        reason:
            'аванс уже прошёл чеком приёма; 300 — двойная выручка по ККМ, '
            '420 — ещё и ручная прибавка',
      );

      final provider = WebKassaProvider(
        settings: fiscalSettings(),
        logger: logger,
      );
      final recount = emul.recountCheck(
        provider.buildCheckPayload(req, 2, token: 'T').cast<String, Object?>(),
        emul.VatMode.off,
      );
      expect(
        recount.complaint,
        isNull,
        reason: 'оператор обязан свести чек со смешанным авансом',
      );
      expect(recount.positionsTotal, d('180'));

      // Раскладка по умолчанию — зачёт скидкой позиции. Довод задачи 23
      // «скидка занижает базу налога» — вопрос бухгалтеру (A6).
      expect(req.totalDiscount, d('120'));
    });

    test(
      'чек, закрытый ОДНИМ авансом (приём фискализован): документа нет',
      () async {
        await seedAdvance('500');

        var view = await start();
        view = await add(view, barcodes[0], 2);
        view = await cart.setQuantity(
          terminalId,
          view.lines.single.id,
          d('3'),
          mv(view, 3),
        );

        final outcome = await payments.complete(
          terminalId,
          PaymentRequest(
            type: PaymentType.cash,
            prepaymentUsed: d('300'),
            prepaymentReference: 'АВ-2',
            customerId: customerId,
          ),
          mv(view, 90),
        );
        await payments.pendingSideEffects;

        // Решение (в) плана 2026-09-14: чек, целиком закрытый зачётом аванса,
        // уже фискализованного чеком приёма, документа не даёт. Прежнее
        // «оплат 300, а не 600» мерило удвоение внутри решения, которое
        // заказчик отменил.
        expect(outcome.fiscal.state, FiscalState.notRequired);
        expect(
          registry.provider.captured,
          isEmpty,
          reason: 'денежного расчёта на этом чеке не было',
        );
      },
    );
  });

  group('выдача аванса деньгами — конверт возврата (2026-09-19)', () {
    // # Зачем отдельные случаи, если у приёма конверт уже сторожится
    //
    // Потому что до 2026-09-19 выдачи не было **вовсе**, и конверт её
    // документа никто не складывал. У возврата он собирается своей
    // веткой (`fiscalizePrepaymentRefund`), и разойтись с приёмом ей
    // ничего не мешало: одна строка позиции, один платёж, ноль НДС — всё
    // это здесь повторено вторым кодом, и второй код расходится с первым
    // ровно так же, как разошлись задачи 21 и 23 этажом выше.
    //
    // Сводится конверт **тем же** `recountCheck`, которым сводит эмулятор
    // WebKassa, с нулевым допуском.

    FiscalServiceImpl advanceService() => FiscalServiceImpl(
      db: db,
      registry: registry,
      settingsSource: _FixedSettings(fiscalSettings()),
      logger: logger,
    );

    emul.Recount recountLast() {
      final provider = WebKassaProvider(
        settings: fiscalSettings(),
        logger: logger,
      );
      return emul.recountCheck(
        provider
            .buildCheckPayload(registry.provider.captured.last, 2, token: 'T')
            .cast<String, Object?>(),
        emul.VatMode.off,
      );
    }

    test('выдача 700 картой: позиций на 700, оплат на 700', () async {
      final result = await advanceService().fiscalizePrepaymentRefund(
        operationId: 31,
        intakeOperationId: null,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.card,
        positionName: 'Возврат аванса (предоплаты) — Айгуль',
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      final recount = recountLast();
      expect(recount.complaint, isNull);
      expect(recount.positionsTotal, d('700'));
      expect(
        registry.provider.captured.last.payments.map((p) => (p.kind, p.amount)),
        [(FiscalPaymentKind.card, d('700'))],
        reason:
            'аванс, выданный на карту и уехавший оператору наличными, — '
            'тот же дефект, что закрыт v47 на приёме',
      );
      expect(
        registry.provider.captured.last.kind,
        FiscalOperationKind.saleReturn,
      );
    });

    test('копейки в выдаче не разводят позиции с оплатой', () async {
      // Деньги — `Decimal`, и деление на единицу количества у аванса не
      // происходит вовсе; проба держит это свойство, а не надеется на него.
      final result = await advanceService().fiscalizePrepaymentRefund(
        operationId: 32,
        intakeOperationId: null,
        amount: d('333.33'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Возврат аванса (предоплаты)',
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      final recount = recountLast();
      expect(recount.complaint, isNull);
      expect(recount.positionsTotal, d('333.33'));
    });

    test('приём и выдача одной суммы дают ЗЕРКАЛЬНЫЕ конверты', () async {
      // Главный случай группы. Документ выдачи, посчитанный иначе, чем
      // приём, развёл бы у оператора две половины одного расчёта — и
      // заметить это можно только сравнив их между собой.
      await advanceService().fiscalizePrepayment(
        operationId: 41,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Аванс (предоплата)',
      );
      final intake = registry.provider.captured.last;
      final intakeRecount = recountLast();

      await advanceService().fiscalizePrepaymentRefund(
        operationId: 42,
        intakeOperationId: 41,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Возврат аванса (предоплаты)',
      );
      final payout = registry.provider.captured.last;
      final payoutRecount = recountLast();

      expect(intakeRecount.complaint, isNull);
      expect(payoutRecount.complaint, isNull);
      expect(
        payoutRecount.positionsTotal,
        intakeRecount.positionsTotal,
        reason:
            'сумма позиций выдачи обязана совпасть с суммой позиций '
            'приёма — иначе у оператора приход и расход разной величины',
      );
      expect(
        payout.payments.map((p) => (p.kind, p.amount)),
        intake.payments.map((p) => (p.kind, p.amount)),
      );
      expect(
        payout.positions.single.tax.amount,
        intake.positions.single.tax.amount,
        reason:
            'НДС приёма — ноль (вопрос бухгалтеру A6); НДС выдачи, '
            'посчитанный иначе, оставил бы у оператора налог с воздуха',
      );
      expect(
        intake.kind,
        FiscalOperationKind.sale,
        reason:
            'приём — продажа, выдача — возврат; поменять их местами '
            'значит удвоить выручку вместо того, чтобы её обнулить',
      );
      expect(payout.kind, FiscalOperationKind.saleReturn);
    });
  });
}

class _CapturingRegistry extends FiscalProviderRegistry {
  final _CapturingProvider provider = _CapturingProvider();

  @override
  FiscalProvider resolve(FiscalSettings settings) => provider;
}

class _CapturingProvider implements FiscalProvider {
  final List<FiscalSaleRequest> captured = [];

  @override
  String get id => 'capture';

  @override
  FiscalCapabilities get capabilities => FiscalCapabilities.none;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok();

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    captured.add(req);
    return FiscalResult.ok(fiscalSign: 'CAP-1');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async {
    captured.add(req.sale);
    return FiscalResult.ok(fiscalSign: 'CAP-2');
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async {
    captured.add(req);
    return FiscalResult.ok(fiscalSign: 'CAP-3');
  }

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async {
    captured.add(req.sale);
    return FiscalResult.ok(fiscalSign: 'CAP-4');
  }

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'CAP-5');

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'CAP-6');

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      const FiscalResult(success: true);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      FiscalReportResult(result: FiscalResult.ok(fiscalSign: 'Z'));

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      FiscalReportResult(result: FiscalResult.ok(fiscalSign: 'X'));

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.unsupported('correctionReceipt');

  @override
  Future<FiscalStatus> getStatus() async =>
      const FiscalStatus(configured: true, active: true, online: true);
}

class _FixedSettings implements FiscalSettingsSource {
  _FixedSettings(this.settings);

  final FiscalSettings settings;

  @override
  Future<FiscalSettings> load() async => settings;
}
