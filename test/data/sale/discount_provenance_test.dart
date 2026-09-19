import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/sale/sale_receipt_composer.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/discount/discount_origin.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

/// Происхождение скидки и аудит попыток — задача 13, шаги 1–5.
///
/// # Что здесь доказывается числами
///
/// Продажа идёт настоящим путём: настоящая база, настоящая корзина,
/// настоящий [LocalPaymentService], настоящий [SaleUseCaseImpl].
/// Подставлен только фискальный узел, которого в этой кассе нет.
///
/// Несущее утверждение одно: **подарок акции в проданном чеке отличим от
/// уступки кассира**. Сегодня скидка выводится разностью `priceBefore −
/// price`, и обе выглядят одинаково; вывести источник задним числом нечем
/// — акций в базе нет вовсе, они чистая функция от строк и `Promotions`,
/// считаемая при сборке снимка.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late LocalPaymentService payments;
  late Talker logger;

  const barcodeA = '4870001234567';
  const barcodeB = '4870007654321';
  const posAccountId = 11;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: 0, receiptNo: null);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  /// Кассир с правом на скидку, с известным идентификатором: аудит обязан
  /// назвать **кто**, и «кто» здесь не выдумывается сервисом.
  const cashier = DiscountAuthority(
    roleIndex: 3, // UserRole.cashier
    userId: 4,
    permissions: {PermissionKeys.opSellDiscount, PermissionKeys.opEditPrice},
  );

  const cashierNoDiscount = DiscountAuthority(
    roleIndex: 3,
    userId: 4,
    permissions: {PermissionKeys.opEditPrice},
  );

  Future<void> seedProduct({
    required String barcode,
    required int ucode,
    required String name,
    required String price,
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            name: name,
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
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
          ),
        );
    await seedProduct(
      barcode: barcodeA,
      ucode: 100,
      name: 'Кофе',
      price: '500',
    );
    await seedProduct(
      barcode: barcodeB,
      ucode: 200,
      name: 'Печенье',
      price: '100',
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
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await db.close();
  });

  group('происхождение скидки в проданном чеке', () {
    test(
      'подарок акции и уступка кассира различимы, а раньше были одним числом',
      () async {
        // Акция «две штуки печенья — третья даром».
        await db
            .into(db.promotions)
            .insert(
              PromotionsCompanion.insert(
                id: const Value(77),
                name: 'Три печенья — одно даром',
                triggerUcode: 200,
                triggerQty: const Value(3),
                rewardUcode: 200,
                rewardQty: const Value(1),
                enabled: const Value(true),
              ),
            );

        var view = await cart.start(
          terminalId: 7,
          wholesale: false,
          meta: m(1),
        );
        // Строка с ручной скидкой: кофе 500, уступлено 50.
        view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
        final coffeeId = view.lines.single.id;
        view = await cart.setDiscountAmount(
          7,
          coffeeId,
          d('50'),
          mv(view, 3),
          by: cashier,
        );
        // Строка с подарком акции: три печенья по 100, одно даром.
        view = await cart.addByBarcode(7, barcodeB, mv(view, 4));
        final biscuitId = view.lines
            .firstWhere((l) => l.productId == 200)
            .id;
        view = await cart.setQuantity(7, biscuitId, d('3'), mv(view, 5));

        // Снимок уже различает их — это то, что видит браузерный экран.
        final coffee = view.lines.firstWhere((l) => l.id == coffeeId);
        final biscuit = view.lines.firstWhere((l) => l.id == biscuitId);
        expect(coffee.discounts.single.origin, DiscountOrigin.manual);
        expect(coffee.discounts.single.sourceId, isNull);
        expect(biscuit.discounts.single.origin, DiscountOrigin.promotion);
        expect(
          biscuit.discounts.single.sourceId,
          77,
          reason: 'какая именно акция — иначе «сколько отдали этой акцией» '
              'не спросить',
        );
        // Старый читатель не тронут: `discount` по-прежнему сумма.
        expect(coffee.discount, d('50'));
        expect(biscuit.discount, d('100'));

        final receiptNo = view.receiptNo!;
        await payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('2000')),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        // **Несущее утверждение.** В проданном чеке происхождение осталось.
        final rows = await db.saleDiscountDao.findBySale(receiptNo, 1);
        expect(
          rows.map((r) => r.origin).toSet(),
          {DiscountOrigin.manual, DiscountOrigin.promotion},
          reason: 'обе скидки записаны, и они разного происхождения',
        );

        final manual = rows.firstWhere(
          (r) => r.origin == DiscountOrigin.manual,
        );
        final promo = rows.firstWhere(
          (r) => r.origin == DiscountOrigin.promotion,
        );
        expect(manual.amount, d('50'));
        expect(manual.sourceId, isNull);
        expect(promo.amount, d('100'));
        expect(promo.sourceId, 77);
        expect(manual.saleProductId, int.parse(coffeeId));
        expect(promo.saleProductId, int.parse(biscuitId));

        // Сумма происхождений сходится с разностью цен строки — тем самым
        // числом, которым скидка выводилась до этой таблицы. Расхождение
        // означало бы, что таблица и чек рассказывают разное.
        //
        // **С копейкой допуска, и она унаследованная, а не своя.** Цена
        // единицы в проданном чеке — это итог строки, делённый на
        // количество и округлённый до денег S3
        // (`LocalSaleCheckoutService._moneyScale`, предел, измеренный и
        // названный задачей 8): скидка 100 на трёх штуках даёт 66.667 за
        // штуку и 100.002 обратно. Авторитет здесь — `SaleDiscounts.amount`,
        // потому что он **не делится**: он и есть та сумма, которую сняли
        // со строки. Допуск не «чтобы прошло»: он ограничен копейкой на
        // строку, и настоящая порча происхождения (не тот источник, не то
        // число) в него не поместится.
        final penny = Decimal.parse('0.01');
        for (final sp in await db.saleProductDao.findBySale(receiptNo, 1)) {
          final byLine = rows.where((r) => r.saleProductId == sp.id);
          final sum = byLine.fold(Decimal.zero, (s, r) => s + r.amount);
          final derived = (sp.priceBefore - sp.price) * sp.quantity;
          expect(
            (sum - derived).abs() <= penny,
            isTrue,
            reason: 'строка ${sp.id}: происхождение обязано объяснить всю '
                'разность цен, а не часть её — по журналу $sum, '
                'по ценам чека $derived',
          );
        }

        // И читатель, ради которого таблица заведена, отвечает числом.
        final byOrigin = await db.saleDiscountDao.givenByOrigin(
          fromTime: 0,
          toTime: 1 << 40,
        );
        expect(byOrigin[DiscountOrigin.promotion], d('100'));
        expect(byOrigin[DiscountOrigin.manual], d('50'));
      },
    );

    test(
      'печатный чек называет подарок акции своим именем, а не числом',
      () async {
        // **Читатель `SaleDiscounts` в продукте**, а не только в отчёте.
        // Чек — единственное, что покупатель уносит с собой, и до задачи 13
        // он называл подарок акции безымянной «Скидкой»: разность
        // `priceBefore − price` не помнит, откуда взялась. Покупатель,
        // которому пообещали «две пачки — третья даром», не мог проверить
        // по чеку, что акцию ему применили вовсе.
        await db
            .into(db.promotions)
            .insert(
              PromotionsCompanion.insert(
                id: const Value(77),
                name: 'Три печенья — одно даром',
                triggerUcode: 200,
                triggerQty: const Value(3),
                rewardUcode: 200,
                rewardQty: const Value(1),
                enabled: const Value(true),
              ),
            );

        var view = await cart.start(
          terminalId: 7,
          wholesale: false,
          meta: m(1),
        );
        view = await cart.addByBarcode(7, barcodeB, mv(view, 2));
        final biscuitId = view.lines.single.id;
        view = await cart.setQuantity(7, biscuitId, d('3'), mv(view, 3));
        view = await cart.addByBarcode(7, barcodeA, mv(view, 4));
        final coffeeId = view.lines.firstWhere((l) => l.productId == 100).id;
        view = await cart.setDiscountAmount(
          7,
          coffeeId,
          d('50'),
          mv(view, 5),
          by: cashier,
        );
        final receiptNo = view.receiptNo!;

        await payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('2000')),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        final receipt = await SaleReceiptComposer(
          db: db,
          logger: logger,
        ).compose(receiptNo: receiptNo, posId: 1);

        final biscuit = receipt!.products.firstWhere(
          (p) => p.name == 'Печенье',
        );
        final coffee = receipt.products.firstWhere((p) => p.name == 'Кофе');
        expect(biscuit.discountLabel, 'подарок акции');
        expect(coffee.discountLabel, 'скидка кассира');
        // Слом в обратную сторону: подпись не подменяет число.
        expect(biscuit.discountAmount > Decimal.zero, isTrue);
        expect(coffee.discountAmount, d('50'));
      },
    );

    test('чек, проданный до журнала, подписи не выдумывает', () async {
      // Слом в обратную сторону: чеки без записанного происхождения обязаны
      // остаться безымянной «Скидкой». «Скидка кассира» на подарке акции
      // хуже молчания — это выдумка, неотличимая от факта.
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 900,
              posId: 1,
              userId: 4,
              amount: d('450'),
              state: const Value(1),
              time: 1000,
            ),
          );
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              receiptNo: const Value(900),
              posId: const Value(1),
              ucode: 100,
              quantity: d('1'),
              price: d('450'),
              priceBefore: d('500'),
            ),
          );

      final receipt = await SaleReceiptComposer(
        db: db,
        logger: logger,
      ).compose(receiptNo: 900, posId: 1);

      expect(receipt!.products.single.discountAmount, d('50'));
      expect(
        receipt.products.single.discountLabel,
        isNull,
        reason: 'происхождения нет — подписи тоже нет',
      );
    });

    test('чек без скидок строк происхождения не заводит', () async {
      // Слом в обратную сторону: таблица, пишущая строку на каждую строку
      // чека, была бы зелена в предыдущей пробе целиком.
      var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1));
      view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
      final receiptNo = view.receiptNo!;

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('500')),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      expect(await db.saleDiscountDao.findBySale(receiptNo, 1), isEmpty);
    });

    test(
      'повторная попытка оплаты не удваивает происхождение',
      () async {
        // Подготовка чека повторяется на каждой попытке (отказ терминала —
        // обычный путь, а не авария), и без снятия прежних строк чек копил
        // бы происхождение от каждой.
        var view = await cart.start(
          terminalId: 7,
          wholesale: false,
          meta: m(1),
        );
        view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
        view = await cart.setDiscountAmount(
          7,
          view.lines.single.id,
          d('50'),
          mv(view, 3),
          by: cashier,
        );
        final receiptNo = view.receiptNo!;

        // Первая попытка: наличных не хватает — отказ.
        await expectLater(
          payments.complete(
            7,
            PaymentRequest(type: PaymentType.cash, cashReceived: d('1')),
            mv(view, 9),
          ),
          throwsA(isA<WireRefusal>()),
        );

        await payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('500')),
          CartCommandMeta(
            key: 'k10',
            baseVersion: view.version,
            receiptNo: receiptNo,
          ),
        );
        await payments.pendingSideEffects;

        final rows = await db.saleDiscountDao.findBySale(receiptNo, 1);
        expect(rows, hasLength(1), reason: 'одна скидка — одна строка');
        expect(rows.single.amount, d('50'));
      },
    );
  });

  group('аудит скидки', () {
    test('прошедшая уступка записывает кто, сколько и чей предел', () async {
      var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1));
      view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
      final receiptNo = view.receiptNo!;
      await cart.setDiscountAmount(
        7,
        view.lines.single.id,
        d('50'),
        mv(view, 3),
        by: cashier,
      );

      final audit = await db.saleDiscountDao.auditFor(userId: 4);
      expect(audit, hasLength(1));
      expect(audit.single.allowed, isTrue);
      expect(audit.single.userId, 4);
      expect(audit.single.roleIndex, 3);
      expect(audit.single.amount, d('50'));
      expect(
        audit.single.percent,
        d('10'),
        reason: '50 из 500 — десять процентов; предел объявлен процентом, '
            'а деньги отдаются суммой, и одно из другого потом не '
            'восстановить',
      );
      expect(audit.single.receiptNo, receiptNo);
      expect(
        audit.single.capSource,
        contains('умолчанию'),
        reason: 'чей предел решил — «предел кассы по умолчанию»',
      );
      expect(audit.single.refusalCode, isNull);
    });

    test(
      'отказ записывается тоже — и это главное, ради чего таблица заведена',
      () async {
        // Скидка, которой отказали, чека не получит никогда. «Кассир девять
        // раз пробовал дать сорок процентов» — тот факт, которого в базе не
        // было нигде.
        var view = await cart.start(
          terminalId: 7,
          wholesale: false,
          meta: m(1),
        );
        view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
        await db
            .into(db.discountLimits)
            .insertOnConflictUpdate(
              DiscountLimitsCompanion.insert(
                role: const Value(3),
                maxPercentPerLine: Value(d('5')),
              ),
            );

        for (var i = 0; i < 3; i++) {
          await expectLater(
            cart.setDiscountAmount(
              7,
              view.lines.single.id,
              d('200'),
              CartCommandMeta(
                key: 'try$i',
                baseVersion: view.version,
                receiptNo: view.receiptNo,
              ),
              by: cashier,
            ),
            throwsA(isA<WireRefusal>()),
          );
        }

        final refusals = await db.saleDiscountDao.refusalsBetween(
          fromTime: 0,
          toTime: 1 << 40,
        );
        expect(
          refusals,
          hasLength(3),
          reason: 'три попытки — три записи, и ни одной строки чека',
        );
        expect(refusals.first.refusalCode, 'denied_limit');
        expect(refusals.first.amount, d('200'));
        expect(refusals.first.percent, d('40'));
        expect(
          refusals.first.capSource,
          contains('Кассир'),
          reason: 'чей предел отказал — иначе кассир пойдёт не туда',
        );

        // Скидки в чеке при этом нет.
        expect(
          (await db.saleProductDao.findBySale(view.receiptNo!, 1)).single,
          isNotNull,
        );
        final after = await cart.viewOfReceipt(view.receiptNo!, 1);
        expect(after!.lines.single.discount, Decimal.zero);
      },
    );

    test('отказ по праву записывается раньше всякого предела', () async {
      var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1));
      view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

      await expectLater(
        cart.setDiscountAmount(
          7,
          view.lines.single.id,
          d('50'),
          mv(view, 3),
          by: cashierNoDiscount,
        ),
        throwsA(isA<WireRefusal>()),
      );

      final audit = await db.saleDiscountDao.auditFor();
      expect(audit, hasLength(1));
      expect(audit.single.allowed, isFalse);
      expect(audit.single.refusalCode, 'forbidden');
      expect(
        audit.single.capSource,
        isNull,
        reason: 'до предела дело не дошло — придумывать его нечем',
      );
    });

    test('снятие скидки уступкой не считается и журнал не разбавляет',
        () async {
      // Слом в обратную сторону: аудит, пишущий каждую команду, наполнил бы
      // журнал событиями, где денег никому не отдавали, и первый же
      // проверяющий перестал бы его читать.
      var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1));
      view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
      final lineId = view.lines.single.id;
      view = await cart.setDiscountAmount(
        7,
        lineId,
        d('50'),
        mv(view, 3),
        by: cashier,
      );
      await cart.setDiscountAmount(
        7,
        lineId,
        Decimal.zero,
        mv(view, 4),
        by: cashier,
      );

      final audit = await db.saleDiscountDao.auditFor();
      expect(
        audit,
        hasLength(1),
        reason: 'записана уступка, но не её снятие',
      );
      expect(audit.single.amount, d('50'));
    });
  });

  setUpAll(() {
    // `LocalPaymentService` резолвит необязательные порты из контейнера;
    // пустой контейнер — та же касса, что в остальных пробах этого каталога.
    GetIt.I.allowReassignment = true;
  });
}
