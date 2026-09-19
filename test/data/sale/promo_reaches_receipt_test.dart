import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
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
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/sale/receipt_line.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import '../../helpers/discount_authority.dart';
import '../../helpers/cash_drawer.dart';

/// Формат завершённого чека — задача 9.
///
/// # Что здесь доказывается и почему это дефект продукта
///
/// `SaleCheckoutService.prepare` считает, чем станут строки чека после
/// оплаты: цену единицы с **вложенной акционной скидкой** и округлённую до
/// денежных трёх знаков. Записывал посчитанное `finalize` — и он **мёртв**:
/// единственный вызывающий, `SaleNotifier.completeSale`, сам никем не
/// зовётся, а путь оплаты (`PaymentService.complete` → `prepare` →
/// `SaleUseCase.perform`) его не трогает вовсе.
///
/// Отсюда два следствия, и оба видны только со стороны **завершённого
/// чека**, а не корзины:
///
/// 1. **подарок акции в базу не попадает.** Акции в базе не хранятся
///    (докстринг `LocalCartService`): они чистая функция от строк и
///    таблицы `Promotions`, считаются при сборке снимка и в цену их
///    впечатывает завершение продажи. Завершения нет — значит подарок
///    виден кассиру в корзине и исчезает из проданного чека;
/// 2. **округления цены единицы не случается.** Ручная скидка ложится в
///    цену с запасом по разрядам (`_perUnitScale` = 10) намеренно — чтобы
///    обратное чтение возвращало кассиру ровно ту скидку, которую он ввёл.
///    Единственным местом, где эти десять знаков сводились к денежным
///    трём, был `finalize`; без него масштаб 10 остаётся в
///    `SaleProducts.price` навсегда и уезжает в фискальный документ и на
///    печать.
///
/// # Почему проба строит кассу руками, а не через `test/e2e/support`
///
/// План называл файл `test/e2e/journeys/`. Стенд там годится — он поднимает
/// `configureDependencies`, то есть и `PaymentService` тоже. Но вместе с
/// ним он поднимает роутер, вход, локализацию и оборудование, и предмет
/// этой пробы — арифметика одной строки чека — утонул бы в них. Сборка
/// здесь повторяет `service_locator.dart:832` довод в довод: те же классы,
/// те же порты, ни одного мока в денежном пути. Тем же приёмом и по той же
/// причине собрана проба задачи 8 (`payment_claim_race_test.dart`).
///
/// # Чем каждый случай **не** проверяется — и это выбор, а не пропуск
///
/// Сумма строк против итога чека сильна только там, где цена единицы
/// делится нацело. Подарок «2+1» на четырёх штуках по 100 даёт ровно 50 за
/// штуку, и там она утверждается. У ручной скидки 10 на трёх штуках цена
/// единицы — 96.666, и обратное умножение даёт 289.998 против 290: это
/// названный предел формата (докстринг `_moneyScale`), а не дефект, и
/// требовать от него равенства значило бы требовать невозможного. Поэтому
/// второй случай утверждает **масштаб и само число**, а не баланс сумм.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;

  const posAccountId = 11;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  Future<void> seedProduct({
    required int ucode,
    required String barcode,
    required String price,
    String name = 'Товар',
    String stock = '100',
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
            quantity: Value(d(stock)),
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
            // Задача 12: тумблер кассы «продажа со скидкой» получил
            // читателя на самой кассе, а не только на экране. Пробы ниже
            // назначают скидку, значит тумблер обязан быть включён — иначе
            // они мерили бы отказ политики.
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
    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() => db.close());

  test('подарок акции доезжает до завершённого чека', () async {
    // Акция «2+1»: на четырёх штуках она срабатывает дважды, и подарочных
    // единиц выходит две. Четыре штуки по 100 за 200 — цена единицы ровно
    // 50, и сумма строк обязана сойтись с итогом чека без остатка.
    await seedProduct(
      ucode: 910,
      barcode: '4870000000910',
      price: '100',
      name: 'Акционный',
    );
    await db
        .into(db.promotions)
        .insert(
          PromotionsCompanion.insert(
            name: 'Два плюс один',
            triggerUcode: 910,
            rewardUcode: 910,
            triggerQty: const Value(2),
            rewardQty: const Value(1),
          ),
        );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 910, d('4'), mv(view, 2));

    // Страховка от вырождения: если корзина подарка не знает, всё
    // дальнейшее ничего не проверяет.
    expect(
      view.totalDiscount,
      d('200'),
      reason: 'корзина не посчитала подарок — проба мерит не то',
    );
    expect(view.total, d('200'));

    final receiptNo = view.receiptNo!;
    final posId = view.posId;

    await payments.complete(
      7,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('200')),
      mv(view, 3),
    );

    final rows = await db.saleProductDao.findBySale(receiptNo, posId);
    expect(rows, hasLength(1));
    final sum = rows.fold(
      Decimal.zero,
      (Decimal s, r) => s + r.price * r.quantity,
    );
    expect(
      sum,
      d('200'),
      reason:
          'подарок акции не доехал до чека: строки завершённого чека дают '
          '$sum при итоге 200',
    );
    expect(
      rows.single.price,
      d('50'),
      reason: 'цена единицы завершённого чека обязана нести подарок в себе',
    );
    expect(
      rows.single.priceBefore,
      d('100'),
      reason: 'цена до скидок — каталожная',
    );

    final sale = await db.saleDao.findByKey(receiptNo, posId);
    expect(sale!.amount, d('200'));
  });

  test('цена единицы завершённого чека — денежных трёх знаков', () async {
    // Ручная скидка 10 на трёх штуках по 100: в корзине цена единицы лежит
    // с десятью разрядами намеренно (`LocalCartService._perUnitScale`),
    // чтобы обратное чтение вернуло кассиру ровно 10.000. В завершённом
    // чеке ей быть нельзя: деньги в этом дереве P18,S3 (I159), и десять
    // знаков уехали бы в фискальный документ и на печать.
    await seedProduct(ucode: 920, barcode: '4870000000920', price: '100');

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 920, d('3'), mv(view, 2));
    view = await cart.setDiscountAmount(
      7,
      view.lines.single.id,
      d('10'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    expect(view.total, d('290'));

    final receiptNo = view.receiptNo!;
    final posId = view.posId;

    final before = await db.saleProductDao.findBySale(receiptNo, posId);
    expect(
      before.single.price.scale,
      10,
      reason:
          'страховка от вырождения: корзина обязана держать цену с запасом '
          'по разрядам, иначе округлять нечего',
    );

    await payments.complete(
      7,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('290')),
      mv(view, 4),
    );

    final rows = await db.saleProductDao.findBySale(receiptNo, posId);
    expect(
      rows.single.price.scale,
      lessThanOrEqualTo(3),
      reason:
          'цена единицы осталась масштаба ${rows.single.price.scale} — '
          'округления не случилось',
    );
    // 290/3 не делится, и три знака берутся **отсечением**, а не
    // округлением: `Rational.toDecimal(scaleOnInfinitePrecision:)` режет
    // хвост. Число не выдумано — это ровно тот пример, которым
    // `LocalSaleCheckoutService._moneyScale` называет свой предел:
    // 96.666 × 3 = 289.998 против 290. Утверждается здесь потому, что без
    // него проба приняла бы любое трёхзначное число, включая неверное.
    expect(rows.single.price, d('96.666'));
    expect(
      rows.single.price * rows.single.quantity,
      d('289.998'),
      reason:
          'названный предел формата: авторитет суммы — Sales.amount, а не '
          'обратное умножение цены единицы',
    );
    expect(rows.single.priceBefore, d('100'));

    final sale = await db.saleDao.findByKey(receiptNo, posId);
    expect(sale!.amount, d('290'), reason: 'авторитет суммы — Sales.amount');
  });

  test('формат не записался — денег с чека не взято', () async {
    // **Ради этого запись и переехала внутрь транзакции.** Отдельным
    // методом после `perform` она оставляла окно: продажа состоялась,
    // деньги взяты, а строки чека остались корзинными. Теперь такого
    // состояния нет — либо и то, и другое, либо ни то, ни другое.
    //
    // Достижимость: `lineId` приходит из снимка корзины и разбирается в
    // `SaleProducts.id` числом. Не разобрался — значит снимок собран не
    // тем, кем мы думаем, и молчать нельзя. Проба подсовывает именно
    // такую строку, потому что другого способа уронить запись формата на
    // полпути у транзакции нет.
    await seedProduct(ucode: 930, barcode: '4870000000930', price: '100');

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 930, d('2'), mv(view, 2));

    final receiptNo = view.receiptNo!;
    final posId = view.posId;
    final stockBefore =
        (await db.productInfoDao.findByUcode(930))?.quantity ?? Decimal.zero;

    await expectLater(
      SaleUseCaseImpl(db: db, logger: Talker()).perform(
        receiptNo: receiptNo,
        posId: posId,
        amount: d('200'),
        lines: [
          ReceiptLine(
            lineId: 'не-число',
            price: Decimal.zero,
            priceBefore: Decimal.zero,
          ),
        ],
        payments: [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: posAccountId, amount: d('200')),
        ],
        change: Decimal.zero,
        selectiveOfd: false,
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      await db.paymentDao.countBySale(receiptNo, posId),
      0,
      reason: 'деньги записаны, а формат чека — нет: транзакция не откатилась',
    );
    final sale = await db.saleDao.findByKey(receiptNo, posId);
    expect(
      sale!.state,
      0,
      reason: 'чек ушёл из работы, хотя запись формата не состоялась',
    );
    expect(
      (await db.productInfoDao.findByUcode(930))?.quantity,
      stockBefore,
      reason: 'остаток списан за продажу, которой не было',
    );
    expect(
      (await db.accountDao.findById(posAccountId))?.value,
      Decimal.zero,
      reason: 'касса приняла деньги за продажу, которой не было',
    );
  });
}
