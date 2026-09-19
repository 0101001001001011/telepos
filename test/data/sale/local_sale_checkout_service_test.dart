import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import '../../helpers/discount_authority.dart';

/// Подготовка чека к оплате — задача 8.
///
/// Настоящая база, настоящая корзина под сервисом. Мок здесь доказал бы,
/// что сервис зовёт то, что мы велели ему звать; доказать надо другое: что
/// **строка чека переписана на месте**, что марка её пережила, и что три
/// запрета кассы отвечают названной причиной, а не молча пропускают чек.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late SaleUseCaseImpl sale;

  const barcodeA = '4870001234567';

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

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
    bool markable = false,
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
            isMarkable: Value(markable),
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
    await seedProduct(ucode: 100, barcode: barcodeA, price: '500');

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
    sale = SaleUseCaseImpl(db: db, logger: logger);
  });

  /// Записать чек так, как это делает продукт.
  ///
  /// До задачи 9 здесь стоял отдельный метод контракта подготовки. Его
  /// больше нет: запись формата переехала внутрь транзакции
  /// `SaleUseCase.perform` — там же, где чек перестаёт быть корзиной, —
  /// потому что отдельным методом она была мертва (звал её только
  /// `SaleNotifier.completeSale`, у которого вызывающих ноль). Пробы,
  /// утверждающие о **записи**, зовут теперь настоящего писателя, а не
  /// выдуманного.
  Future<void> writeReceipt(CheckoutPreparation prepared) => sale.perform(
    receiptNo: prepared.receiptNo,
    posId: prepared.posId,
    amount: prepared.amount!,
    lines: prepared.lines,
    payments: const [],
    change: Decimal.zero,
    selectiveOfd: false,
  );

  tearDown(() async {
    await db.close();
  });

  test('пустой чек не готовится к оплате — названный отказ', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );

    final prepared = await checkout.prepare(
      receiptNo: view.receiptNo!,
      posId: view.posId,
    );

    expect(prepared.amount, isNull);
    expect(prepared.refusal?.code, checkoutEmptyCode);
  });

  test(
    'маркируемый товар без марки не проходит, с маркой — проходит',
    () async {
      await seedProduct(
        ucode: 300,
        barcode: '4870000000003',
        price: '700',
        name: 'Сигареты',
        markable: true,
      );

      var view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      view = await cart.addProduct(7, 300, Decimal.one, mv(view, 2));

      final blocked = await checkout.prepare(
        receiptNo: view.receiptNo!,
        posId: view.posId,
      );
      expect(blocked.refusal?.code, checkoutMarkRequiredCode);
      expect(
        blocked.refusal?.message,
        'Сигареты',
        reason: 'кассиру надо назвать товар, а не «какая-то строка»',
      );

      view = await cart.setMark(7, view.lines.single.id, 'DM-1', mv(view, 3));
      final passed = await checkout.prepare(
        receiptNo: view.receiptNo!,
        posId: view.posId,
      );
      expect(passed.refusal, isNull);
      expect(passed.amount, d('700'));
    },
  );

  test('запрет продажи в минус называет товар, которого не хватает', () async {
    await seedProduct(
      ucode: 400,
      barcode: '4870000000004',
      price: '100',
      name: 'Дефицит',
      stock: '2',
    );
    await db
        .update(db.thisPosEntries)
        .write(const ThisPosEntriesCompanion(blockOversell: Value(true)));

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 400, d('3'), mv(view, 2));

    final prepared = await checkout.prepare(
      receiptNo: view.receiptNo!,
      posId: view.posId,
    );

    expect(prepared.refusal?.code, checkoutInsufficientStockCode);
    expect(prepared.refusal?.message, 'Дефицит');

    // Правило нуля: ровно остаток — не «больше остатка».
    var ok = await cart.start(terminalId: 8, wholesale: false, meta: m(11, 0));
    ok = await cart.addProduct(8, 400, d('2'), mv(ok, 12));
    final atLimit = await checkout.prepare(
      receiptNo: ok.receiptNo!,
      posId: ok.posId,
    );
    expect(atLimit.refusal, isNull);
  });

  test('потолок суммы: миллион проходит, больше — отказ', () async {
    await seedProduct(
      ucode: 500,
      barcode: '4870000000005',
      price: '1000000',
      name: 'Дорогой',
      stock: '10',
    );

    var over = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    over = await cart.addProduct(7, 500, d('2'), mv(over, 2));
    final blocked = await checkout.prepare(
      receiptNo: over.receiptNo!,
      posId: over.posId,
    );
    expect(blocked.refusal?.code, checkoutBigAmountCode);

    // Ровно потолок — не «выше потолка».
    var atLimit = await cart.start(
      terminalId: 8,
      wholesale: false,
      meta: m(11, 0),
    );
    atLimit = await cart.addProduct(8, 500, Decimal.one, mv(atLimit, 12));
    final passed = await checkout.prepare(
      receiptNo: atLimit.receiptNo!,
      posId: atLimit.posId,
    );
    expect(passed.refusal, isNull, reason: 'ровно миллион — это не «выше»');

    await db
        .update(db.thisPosEntries)
        .write(const ThisPosEntriesCompanion(allowBigAmount: Value(true)));
    final allowed = await checkout.prepare(
      receiptNo: over.receiptNo!,
      posId: over.posId,
    );
    expect(allowed.refusal, isNull);
    expect(allowed.amount, d('2000000'));
  });

  test('подготовка не трогает корзину — ни ручную скидку, ни акцию', () async {
    // Круг правки 1, C2 и C3. Подготовка считала и **сразу записывала**
    // формат завершённого чека в те же колонки, из которых корзина читает
    // цену и скидку. Замер разбора: ручная скидка 10 на трёх штуках по 100
    // давала 290 -> 289.998 -> 289.998, а подарок акции превращался в
    // ручную скидку и переставал быть подарком. Путь достижим: завершение
    // продажи бросило — кассир повторяет оплату по испорченной корзине.
    await seedProduct(
      ucode: 900,
      barcode: '4870000000009',
      price: '100',
      name: 'Делится нацело не всегда',
      stock: '100',
    );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 900, d('3'), mv(view, 2));
    view = await cart.setDiscountAmount(
      7,
      view.lines.single.id,
      d('10'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    expect(view.total, d('290'));
    final versionBefore = view.version;

    final first = await checkout.prepare(
      receiptNo: view.receiptNo!,
      posId: view.posId,
    );
    expect(first.amount, d('290'));

    final afterFirst = await cart.watch(7).first;
    expect(
      afterFirst.total,
      d('290'),
      reason: 'подготовка переписала цену строки, и скидка выросла',
    );
    expect(afterFirst.lines.single.discount, d('10'));
    expect(
      afterFirst.version,
      versionBefore,
      reason:
          'деньги в корзине изменились без версии — протокол команд задачи 7 '
          'держится только на ней',
    );

    final second = await checkout.prepare(
      receiptNo: view.receiptNo!,
      posId: view.posId,
    );
    expect(second.amount, d('290'), reason: 'подготовка не идемпотентна');
    final afterSecond = await cart.watch(7).first;
    expect(afterSecond.total, d('290'));
  });

  test('подготовка не превращает подарок акции в ручную скидку', () async {
    // Вторая половина C3. Запечённая в цену акционная скидка неотличима от
    // ручной: строка перестаёт сливаться, выпадает из расчёта акций и
    // переживает смену количества застывшей суммой — находка 3 задачи 8,
    // воспроизведённая через оплату.
    await seedProduct(
      ucode: 910,
      barcode: '4870000000910',
      price: '100',
      name: 'Акционный',
      stock: '100',
    );
    await db
        .into(db.promotions)
        .insert(
          PromotionsCompanion.insert(
            name: 'Три по цене двух',
            triggerUcode: 910,
            rewardUcode: 910,
            triggerQty: const Value(3),
            rewardQty: const Value(1),
          ),
        );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 910, d('3'), mv(view, 2));
    expect(view.total, d('200'));

    final prepared = await checkout.prepare(
      receiptNo: view.receiptNo!,
      posId: view.posId,
    );
    expect(prepared.amount, d('200'));

    view = await cart.setQuantity(7, view.lines.single.id, d('2'), mv(view, 3));
    expect(
      view.lines.single.discount,
      Decimal.zero,
      reason: 'подарок застыл ручной скидкой и пережил своё условие',
    );
    expect(view.total, d('200'));
  });

  test('строка чека переписывается на месте, вместе с маркой', () async {
    await seedProduct(
      ucode: 600,
      barcode: '4870000000006',
      price: '300',
      name: 'Маркируемый',
      markable: true,
    );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 600, d('2'), mv(view, 2));
    final lineId = view.lines.single.id;
    view = await cart.setMark(7, lineId, 'DM-7', mv(view, 3));
    view = await cart.setDiscountAmount(
      7,
      lineId,
      d('60'),
      mv(view, 4),
      by: fullDiscountAuthority,
    );

    final rowsBefore = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(rowsBefore, hasLength(1));
    final idBefore = rowsBefore.single.id;

    final prepared = await checkout.prepare(
      receiptNo: view.receiptNo!,
      posId: view.posId,
    );
    expect(prepared.amount, d('540'));
    await writeReceipt(prepared);

    final rowsAfter = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(
      rowsAfter,
      hasLength(1),
      reason: 'чек удвоился: строки вставлены заново поверх лежащих в базе',
    );
    expect(
      rowsAfter.single.id,
      idBefore,
      reason: 'строка пересоздана — марка осталась бы у мёртвого номера',
    );
    // Скидка вложена в цену единицы — формат завершённого чека.
    expect(rowsAfter.single.price, d('270'));
    expect(rowsAfter.single.priceBefore, d('300'));

    final marks = await db.saleProductDao.findMarksBySaleProduct(idBefore);
    expect(marks.map((mk) => mk.mark), [
      'DM-7',
    ], reason: 'марка потеряна вместе со строкой, к которой была привязана');

    final sale = await db.saleDao.findByKey(view.receiptNo!, view.posId);
    expect(sale!.amount, d('540'));
  });

  test(
    'повторная подготовка не удваивает чек и снимает прежние платежи',
    () async {
      var view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

      final first = await checkout.prepare(
        receiptNo: view.receiptNo!,
        posId: view.posId,
      );
      expect(first.amount, d('500'));

      // Платёж первой попытки: терминал отказал, кассир платит заново.
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: 4,
              receiptNo: Value(view.receiptNo!),
              posId: Value(view.posId),
              payeeAccountId: 1,
              amount: d('500'),
              time: 1000,
            ),
          );

      final second = await checkout.prepare(
        receiptNo: view.receiptNo!,
        posId: view.posId,
      );
      expect(second.amount, d('500'));

      final rows = await db.saleProductDao.findBySale(
        view.receiptNo!,
        view.posId,
      );
      expect(rows, hasLength(1), reason: 'повтор удвоил строки чека');

      final payments = await db.paymentDao.findBySale(
        view.receiptNo!,
        view.posId,
      );
      expect(
        payments,
        isEmpty,
        reason: 'платёж первой попытки остался и будет посчитан дважды',
      );
    },
  );

  test(
    'умолчание выборочного ОФД: выключено, пока касса не сказала иное',
    () async {
      expect(await checkout.selectiveOfdDefault(), isFalse);

      await db
          .update(db.thisPosEntries)
          .write(
            const ThisPosEntriesCompanion(
              sendToOfd: Value(true),
              ofdSyncType: Value(1),
            ),
          );
      expect(await checkout.selectiveOfdDefault(), isTrue);

      // Отправка в ОФД включена, но режим не выборочный.
      await db
          .update(db.thisPosEntries)
          .write(const ThisPosEntriesCompanion(ofdSyncType: Value(0)));
      expect(await checkout.selectiveOfdDefault(), isFalse);
    },
  );
}
