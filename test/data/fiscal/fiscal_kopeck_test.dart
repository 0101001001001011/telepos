// Скидка доезжает до оператора — и доезжает **до копейки**.
//
// # Два дефекта, а не один
//
// 1. **Скидка не уезжала никогда.** `FiscalPositionBuilder.build` принимал
//    `Decimal? discount`, и **ни один** из четырёх вызовов его не передавал;
//    `totalDiscount` конверта был захардкожен нулём в четырёх местах. В
//    конверт уезжала уже уценённая цена единицы, поля `Discount` не было
//    вовсе. Для оператора чек со скидкой был неотличим от чека без неё,
//    только дешевле.
// 2. **Копейка расходилась и без всякой скидки.** Цена единицы лежит в базе
//    с запасом по разрядам (`LocalCartService._perUnitScale` = 10,
//    `LocalSaleCheckoutService._moneyScale` = 3), а в конверт уезжает
//    округлённой до двух (`WebKassaProvider._money`). Оператор считает
//    `round(Count × Price, 2) − Discount`, то есть **по округлённой цене**.
//    Замер: три штуки по 100 со скидкой 100 дают цену единицы 66.6666666667
//    → 66.67 → 200.01 против оплаты 200.00. Расхождение в одну копейку —
//    отказ кодом 9 (`FiscalErrorCode.validation`), то есть «деньги взяты,
//    документа нет».
//
// # Почему проба идёт через настоящую кассу, а не собирает позиции руками
//
// Позиции, собранные руками, проверяют арифметику самой пробы и молчат ровно
// про тот дефект, ради которого она написана: цена единицы в базе — это
// результат деления скидки на количество внутри `LocalCartService._writeLine`,
// и подставить её «примерно такой» значит не измерить ничего. Здесь чек
// набирается настоящим `LocalCartService`, скидка назначается его же
// командами, оплата проходит настоящим `LocalPaymentService`, а позиции
// строит `FiscalServiceImpl._buildSalePositions` из строк базы.
//
// # Почему сверка — чужим пересчётом, а не своим expect
//
// Конверт собирает настоящий `WebKassaProvider.buildCheckPayload` (то есть
// `_money`/`_qty` округляют по-настоящему), а сходится он **тем же самым
// `recountCheck`**, которым сходится эмулятор WebKassa
// (`lib/emulators/webkassa/state.dart`). Своё выражение здесь было бы
// вторым мнением о том, что считает оператор, и разошлось бы с эмулятором
// молча. Нулевой допуск — оттуда же.
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
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
import 'package:telepos/domain/sale/payment_service.dart';
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
  const terminalId = 7;

  /// Три товара по одной цене — чтобы случай раскладки по чеку набирался
  /// тремя строками, а не одной.
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
    await seedProduct(100, barcodes[0], '100');
    await seedProduct(200, barcodes[1], '100');
    await seedProduct(300, barcodes[2], '1500');

    // Строка **чужого** чека — та, которой в конверте быть не должно.
    // Правило нуля (`qa-depth`): проба на базе, где верный ответ совпадает с
    // «всё, что нашлось», не отличает выборку от её отсутствия. Скидка здесь
    // нарочно огромная: попади строка в конверт, `sumDiscounts` разъедется
    // с оплатой и это будет видно числом, а не догадкой.
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
        settingsSource: _FixedSettings(
          FiscalSettings(
            operatorType: FiscalOperatorType.webkassa,
            apiKey: 'WKD-1',
            login: 'a@b.kz',
            cashboxUniqueNumber: 'SWK00000001',
          ),
        ),
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

  /// Прогнать набранный чек через оплату и вернуть пересчёт конверта тем же
  /// кодом, каким его считает эмулятор оператора.
  Future<emul.Recount> settle(CartView view) async {
    final total = view.total;
    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(type: PaymentType.cash, cashReceived: total),
      mv(view, 90),
    );
    await payments.pendingSideEffects;

    expect(
      outcome.fiscal.state,
      FiscalState.done,
      reason: 'чек обязан дойти до провайдера, иначе мерить нечего',
    );
    final req = registry.provider.captured.single;
    expect(
      req.positions.every((p) => p.unitPrice != d('9999')),
      isTrue,
      reason: 'строка чужого чека не имеет права попасть в конверт',
    );

    final provider = WebKassaProvider(
      settings: FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        apiKey: 'WKD-1',
        login: 'a@b.kz',
        cashboxUniqueNumber: 'SWK00000001',
      ),
      logger: logger,
    );
    final body = provider.buildCheckPayload(req, 2, token: 'T');

    final recount = emul.recountCheck(
      body.cast<String, Object?>(),
      emul.VatMode.off,
    );
    // ignore: avoid_print
    print('\n--- пересчёт конверта ---');
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

  group('копейка не расходится, скидка доезжает', () {
    test('3 × 100, скидка 100 суммой: 200.00, а не 200.01', () async {
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
      expect(view.total, d('200'), reason: 'с кассира берут 200');

      final recount = await settle(view);
      expect(
        recount.complaint,
        isNull,
        reason: 'оператор обязан свести чек со скидкой',
      );
      expect(recount.positionsTotal, d('200'));

      final req = registry.provider.captured.single;
      expect(
        req.positions.single.unitPrice,
        d('100'),
        reason: 'в конверт уезжает цена ДО скидки',
      );
      expect(req.positions.single.discountOr, d('100'));
      expect(
        req.totalDiscount,
        d('100'),
        reason: 'итог чека — сумма позиционных скидок, а не своё число',
      );
    });

    test('3 × 100 без скидки: поля Discount не появляется вовсе', () async {
      var view = await start();
      view = await add(view, barcodes[0], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('3'),
        mv(view, 3),
      );

      final recount = await settle(view);
      expect(recount.complaint, isNull);
      expect(recount.positionsTotal, d('300'));

      final req = registry.provider.captured.single;
      expect(req.positions.single.discountOr, Decimal.zero);
      expect(req.totalDiscount, Decimal.zero);

      final provider = WebKassaProvider(
        settings: FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          apiKey: 'WKD-1',
          login: 'a@b.kz',
          cashboxUniqueNumber: 'SWK00000001',
        ),
        logger: logger,
      );
      final body = provider.buildCheckPayload(req, 2, token: 'T');
      final position = (body['Positions'] as List).single as Map;
      expect(
        position.containsKey('Discount'),
        isFalse,
        reason: 'бесскидочный чек не имеет права обрасти полем скидки',
      );
    });

    test(
      '0.333 × 1500, скидка 10 %: масштаб количества против денег',
      () async {
        var view = await start();
        view = await add(view, barcodes[2], 2);
        view = await cart.setQuantity(
          terminalId,
          view.lines.single.id,
          d('0.333'),
          mv(view, 3),
        );
        view = await cart.setDiscountPercent(
          terminalId,
          view.lines.single.id,
          d('10'),
          mv(view, 4),
          by: fullDiscountAuthority,
        );

        final recount = await settle(view);
        expect(recount.complaint, isNull);
        expect(
          recount.positionsTotal,
          (view.total).round(scale: 2),
          reason: 'сумма позиций равна тому, что взято с покупателя',
        );

        // Здесь копейка сходится и **до** правки — скидка делится на
        // количество нацело. Красным этот случай делает не баланс, а само
        // наличие скидки в конверте: без него оператор видит чек, дешевле
        // прейскуранта без объяснения.
        final position = registry.provider.captured.single.positions.single;
        expect(position.unitPrice, d('1500'), reason: 'цена ДО скидки');
        expect(position.discountOr, d('49.95'));
      },
    );

    test(
      'скидка 100 суммой на 7 штук: период в делении, худший случай',
      () async {
        // Плановый случай назывался «скидка 33 % на 3 штуки». Измерено: он не
        // краснеет и краснеть не может. Скидка процентом считается как
        // `priceBefore × quantity × percent / 100` и потому **всегда** делится
        // на количество нацело — период в `capped / quantity` при ней
        // недостижим. Период рождает только скидка суммой; 100 на 7 штук —
        // худший случай: цена единицы 85.7142857143, округлённая до копейки
        // даёт 599.97 против 600.00, то есть промах втрое больше копейки.
        var view = await start();
        view = await add(view, barcodes[0], 2);
        view = await cart.setQuantity(
          terminalId,
          view.lines.single.id,
          d('7'),
          mv(view, 3),
        );
        view = await cart.setDiscountAmount(
          terminalId,
          view.lines.single.id,
          d('100'),
          mv(view, 4),
          by: fullDiscountAuthority,
        );
        expect(view.total, d('600'));

        final recount = await settle(view);
        expect(recount.complaint, isNull);
        expect(recount.positionsTotal, d('600'));

        final position = registry.provider.captured.single.positions.single;
        expect(position.unitPrice, d('100'));
        expect(position.discountOr, d('100'));
      },
    );

    test('0.3335 кг × 1500: количество само не влезает в конверт', () async {
      // Шестой случай, которого в плане не было, и без которого **порядок
      // округления не проверен ничем**.
      //
      // Измерено: во всех пяти плановых случаях цена лежит в двух разрядах,
      // а количество в трёх — то есть оба множителя уже влезают в конверт, и
      // «округлить до вычитания» тождественно равно «округлить после». Пять
      // случаев доказывают, что в конверт уезжает цена ДО скидки, и молчат
      // про порядок.
      //
      // Здесь количество имеет **четыре** разряда: весы взвесили 0.3335 кг,
      // а `WebKassaProvider._qty` округляет количество до трёх и отправит
      // 0.334. Оператор считает `0.334 × 1500 = 501.00`, а с покупателя
      // взяли 450.23 — скидка обязана быть разностью между этими двумя
      // числами (50.77), а не разностью цен (50.03). Промах порядка здесь
      // не копейка, а 74 копейки.
      var view = await start();
      view = await add(view, barcodes[2], 2);
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('0.3335'),
        mv(view, 3),
      );
      view = await cart.setDiscountPercent(
        terminalId,
        view.lines.single.id,
        d('10'),
        mv(view, 4),
        by: fullDiscountAuthority,
      );

      final recount = await settle(view);
      expect(
        recount.complaint,
        isNull,
        reason:
            'скидка обязана считаться из ОКРУГЛЁННОГО количества: оператор '
            'умножает на 0.334, а не на 0.3335',
      );

      final position = registry.provider.captured.single.positions.single;
      expect(position.unitPrice, d('1500'));
      expect(
        position.discountOr,
        d('50.77'),
        reason:
            'разность конверта (501.00) и денег покупателя (450.23), а не '
            'разность цен (50.03)',
      );
    });

    test(
      'скидка 500 на три строки: остаток не создаёт четвёртой копейки',
      () async {
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
        // Раскладка скидки чека 500 на три строки: 166.67 + 166.67 + 166.66.
        // Остаток копейки достаётся последней строке — ровно так, как его
        // раскладывает касса, и ровно здесь он мог бы завестись четвёртый раз.
        const shares = ['166.67', '166.67', '166.66'];
        for (var i = 0; i < lineIds.length; i++) {
          view = await cart.setDiscountAmount(
            terminalId,
            lineIds[i],
            d(shares[i]),
            mv(view, 10 + i),
            by: fullDiscountAuthority,
          );
        }
        expect(view.lines, hasLength(3));

        final recount = await settle(view);
        expect(recount.complaint, isNull);

        final req = registry.provider.captured.single;
        expect(
          req.totalDiscount,
          d('500.00'),
          reason: 'сумма позиционных скидок — ровно скидка чека',
        );
        expect(req.positions.map((p) => p.discountOr).toList(), [
          d('166.67'),
          d('166.67'),
          d('166.66'),
        ], reason: 'остаток лежит в одной строке, а не размазан по трём');
      },
    );

    test('НДС считается от суммы ПОСЛЕ скидки, а не от gross', () async {
      // Закрепление шага 7 плана: `_buildTax` берёт `lineTotal`, то есть
      // цену после скидки. Без этой пробы следующая правка «выровняет» его
      // к `unitPrice × quantity`, и налог вырастет на скидку.
      final vat = Decimal.fromInt(12);
      final beforeDiscount = FiscalPositionBuilder.vatFromGross(d('300'), vat);
      final afterDiscount = FiscalPositionBuilder.vatFromGross(d('200'), vat);
      expect(afterDiscount, lessThan(beforeDiscount));

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
      await settle(view);
      final position = registry.provider.captured.single.positions.single;
      expect(
        position.lineTotal.round(scale: 2),
        d('200.00'),
        reason: 'база налога — деньги покупателя, а не цена до скидки',
      );
      // Рядом с базой обязаны стоять оба числа скидки: без них проба
      // сходилась бы и на сегодняшнем коде, где скидки в конверте нет.
      expect(position.unitPrice, d('100'));
      expect(position.discountOr, d('100'));

      // И то же самое — прямо на билдере, с включённым НДС: в сквозной
      // прогонке плательщик НДС не настроен, и налог там ноль при любой
      // формуле.
      const builder = FiscalPositionBuilder();
      final built = builder.build(
        name: 'x',
        quantity: d('3'),
        unitPrice: d('100'),
        lineTotal: d('200'),
        settings: FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          isVatPayer: true,
          vatRatePercent: vat,
        ),
      );
      expect(built.tax.amount, afterDiscount);
      expect(
        built.tax.amount,
        isNot(beforeDiscount),
        reason: 'выравнивание базы к gross завысило бы налог ровно на скидку',
      );
      expect(built.discountOr, d('100'));
    });
  });

  group('наценка — та же разность с обратным знаком', () {
    // `lineMarkup` и `sumMarkups` заведены этой же правкой, и без пробы были
    // бы новыми публичными методами, которых не проверяет ничто.
    //
    // Ветка не декоративная: `_positionToJson` кладёт `Discount` только при
    // положительном значении. Уйди отрицательная разность в поле скидки — она
    // исчезла бы бесследно, и сумма позиций разошлась бы с оплатой на всю
    // наценку, а не на копейку.
    const builder = FiscalPositionBuilder();
    final settings = FiscalSettings(operatorType: FiscalOperatorType.webkassa);

    test('цена строки выше цены до неё: скидки нет, наценка есть', () {
      final p = builder.build(
        name: 'x',
        quantity: d('2'),
        unitPrice: d('100'),
        lineTotal: d('250'),
        settings: settings,
      );
      expect(
        p.discount,
        isNull,
        reason: 'скидки не было — поля быть не должно',
      );
      expect(p.markupOr, d('50'));
      expect(
        FiscalPositionBuilder.lineDiscount(
          quantity: d('2'),
          priceBefore: d('100'),
          lineTotal: d('250'),
        ),
        Decimal.zero,
        reason: 'отрицательной скидки не бывает',
      );
      // Тождество оператора: Price × Count − Discount + Markup = строка.
      expect(d('100') * d('2') - p.discountOr + p.markupOr, d('250'));
    });

    test('итоги чека складываются по позициям — оба', () {
      final positions = [
        builder.build(
          name: 'a',
          quantity: d('3'),
          unitPrice: d('100'),
          lineTotal: d('200'),
          settings: settings,
        ),
        builder.build(
          name: 'b',
          quantity: d('2'),
          unitPrice: d('100'),
          lineTotal: d('250'),
          settings: settings,
        ),
      ];
      expect(FiscalPositionBuilder.sumDiscounts(positions), d('100'));
      expect(FiscalPositionBuilder.sumMarkups(positions), d('50'));
      expect(
        FiscalPositionBuilder.sumDiscounts(const <FiscalPosition>[]),
        Decimal.zero,
        reason: 'пустой чек даёт ноль, а не падение',
      );
    });

    test('бонус задачи 7 войдёт СЛАГАЕМЫМ, а не вторым полем', () {
      // Точка расширения проверяется здесь, пока её ещё никто не занял.
      // Проба существует затем, чтобы следующий увидел готовое место и не
      // завёл второе число: цена ошибки — отказ кодом 9 на каждой продаже с
      // бонусом.
      final withoutBonus = FiscalPositionBuilder.lineDiscount(
        quantity: d('3'),
        priceBefore: d('100'),
        lineTotal: d('200'),
      );
      final withBonus = FiscalPositionBuilder.lineDiscount(
        quantity: d('3'),
        priceBefore: d('100'),
        lineTotal: d('200'),
        extraDiscount: d('30'),
      );
      expect(withoutBonus, d('100'));
      expect(
        withBonus,
        withoutBonus + d('30'),
        reason: 'слагаемое, а не замена и не второе поле',
      );
      // И главное: строка по-прежнему сходится с тем, что покупатель платит
      // деньгами, — 200 минус списанные 30.
      expect(d('100') * d('3') - withBonus, d('170'));
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
  _FixedSettings(this._settings);

  final FiscalSettings _settings;

  @override
  Future<FiscalSettings> load() async => _settings;
}
