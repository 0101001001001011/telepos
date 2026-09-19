import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import '../../helpers/discount_authority.dart';

/// Задача 17 плана «Продажа с браузерного терминала»: общий пул отложенных
/// чеков и гонка двух поднявших.
///
/// # Почему отдельный файл, если про откладывание уже есть тесты
///
/// В `local_cart_service_test.dart` откладывание проверено **как команда
/// одного рабочего места**: отложил — получил пустую корзину, поднял —
/// получил строки. Здесь проверяется другое: **пул как общая вещь кассы**,
/// у которой больше одного хозяина одновременно. Это разные утверждения, и
/// последовательный тест по построению не может отличить рабочую защиту от
/// сломанной — он не создаёт того, от чего защита защищает.
///
/// Каждая проба здесь говорит про одно из четырёх:
///
/// 1. **Видимость (решение 4 заказчика).** Чек в работе — личное дело
///    рабочего места; в общий пул он попадает только явным «Отложить».
/// 2. **Одновременность.** Двое поднимают один чек в один момент.
///    `Future.wait`, а не «сначала один, потом другой»: последовательный
///    вызов зеленеет и при полностью снятой защите, потому что второму
///    достаётся уже изменённая строка.
/// 3. **Владелец в базе.** Откладывание освобождает `Sales.terminalId`,
///    подъём занимает — проверяется строкой в базе, а не снимком: снимок
///    считается тем же кодом, который владельца и проставляет, и повторяет
///    его ошибку.
/// 4. **Запертый чек.** Поднявший и потерявший связь не уносит чек с собой
///    навсегда.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late DeferredSaleServiceImpl deferredService;

  const barcodeA = '4870001234567';
  const barcodeB = '4870007654321';

  /// Команда рабочего места, у которого чека нет: `receiptNo` пуст.
  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

  /// Команда, посчитанная от снимка [v].
  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  Decimal d(String v) => Decimal.parse(v);

  Future<void> seedProduct({
    required int ucode,
    required String barcode,
    required String price,
    String name = 'Товар',
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
        .insert(const ThisPosEntriesCompanion(id: Value(1)));
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
    await seedProduct(
      ucode: 200,
      barcode: barcodeB,
      price: '300',
      name: 'Второй',
    );

    final logger = Talker();
    deferredService = DeferredSaleServiceImpl(db: db, logger: logger);
    cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: deferredService,
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Седьмое место набирает один товар и откладывает чек. Возвращает его
  /// номер — то, чем пул опознаёт чек снаружи.
  Future<int> deferOneCart({int terminalId = 7, int firstKey = 1}) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(firstKey, 0),
    );
    view = await cart.addByBarcode(terminalId, barcodeA, mv(view, firstKey + 1));
    final receiptNo = view.receiptNo!;
    await cart.defer(terminalId, mv(view, firstKey + 2), by: fullDiscountAuthority);
    return receiptNo;
  }

  /// Исход команды значением — и успех, и отказ, чтобы `Future.wait` не
  /// обрывал вторую половину гонки на первой же ошибке.
  Future<Object> outcome(Future<CartView> f) =>
      f.then<Object>((v) => v).catchError((Object e) => e);

  // ── решение 4: чек в работе чужим не виден ───────────────────────────

  test('отложенный чек виден всем рабочим местам, чек в работе — нет', () async {
    var a = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    a = await cart.addByBarcode(7, barcodeA, mv(a, 2));

    expect(
      await cart.watchDeferred(by: fullDiscountAuthority).first,
      isEmpty,
      reason: 'набираемый чек показан всей кассе до «Отложить» (решение 4)',
    );

    await cart.defer(7, mv(a, 3), by: fullDiscountAuthority);
    final pool = await cart.watchDeferred(by: fullDiscountAuthority).first;

    expect(pool.map((c) => c.receiptNo), [a.receiptNo]);
  });

  test('чужой чек в работе не виден в пуле ни одному другому месту', () async {
    // Девятое место набирает своё — и не откладывает.
    var nine = await cart.start(terminalId: 9, wholesale: false, meta: m(1, 0));
    nine = await cart.addByBarcode(9, barcodeB, mv(nine, 2));

    // Седьмое место откладывает своё.
    final deferredNo = await deferOneCart(firstKey: 10);

    final pool = await cart.watchDeferred(by: fullDiscountAuthority).first;
    expect(
      pool.map((c) => c.receiptNo),
      [deferredNo],
      reason: 'чек девятого места в работе утёк в общий пул',
    );

    // И поднять его через пул нельзя даже по угаданному номеру: он не
    // отложен, а в работе у другого.
    expect(
      () => cart.loadDeferred(11, nine.receiptNo!, m(20, 0), by: fullDiscountAuthority),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartDeferredTakenCode),
      ),
    );
    expect((await cart.watch(9).first).lines, hasLength(1));
  });

  // ── гонка ────────────────────────────────────────────────────────────

  test('двое, поднявших один чек, разводятся названным отказом', () async {
    final receiptNo = await deferOneCart();

    await cart.loadDeferred(7, receiptNo, m(4, 0), by: fullDiscountAuthority);

    expect(
      () => cart.loadDeferred(9, receiptNo, m(5, 0), by: fullDiscountAuthority),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartDeferredTakenCode),
      ),
    );
  });

  test('одновременный подъём одного чека: один хозяин, второму — отказ', () async {
    final receiptNo = await deferOneCart();

    // Одновременно, а не по очереди: последовательная проба выше зеленеет
    // и при снятой защите — второму достаётся уже изменённая строка, и
    // отказ приходит сам собой. Здесь обе команды входят в кассу до того,
    // как любая из них дописала строку.
    final results = await Future.wait([
      outcome(cart.loadDeferred(7, receiptNo, m(4, 0), by: fullDiscountAuthority)),
      outcome(cart.loadDeferred(9, receiptNo, m(5, 0), by: fullDiscountAuthority)),
    ]);

    final won = results.whereType<CartView>().toList();
    final refused = results.whereType<WireRefusal>().toList();

    expect(won, hasLength(1), reason: 'чек поднят дважды — два хозяина у чека');
    expect(refused, hasLength(1));
    expect(
      refused.single.code,
      cartDeferredTakenCode,
      reason: 'проигравший обязан узнать причину по коду, а не по пустоте',
    );

    // Страховка от вырождения: «никто не поднял» зеленит защиту и ломает
    // продукт — победитель обязан существовать и получить строки.
    expect(won.single.receiptNo, receiptNo);
    expect(won.single.lines, hasLength(1));

    // База согласна со снимком: один владелец, состояние «в работе».
    final row = await db.saleDao.findByKey(receiptNo, 1);
    expect(row!.state, 0);
    expect(row.terminalId, won.single.terminalId);
    expect(
      row.terminalId,
      anyOf(7, 9),
      reason: 'владельцем стал не тот, кто поднял',
    );

    // И проигравший остался без чека — а не с чужим.
    final loserId = row.terminalId == 7 ? 9 : 7;
    expect((await cart.watch(loserId).first).receiptNo, isNull);
    expect(await cart.watchDeferred(by: fullDiscountAuthority).first, isEmpty);

    // Целостность после операции, а не только её ответ (`qa-depth`):
    // проигравший не завёл себе чека «про запас» и не сжёг номер, строки
    // остались при своём чеке и не удвоились.
    final allSales = await db.select(db.sales).get();
    expect(
      allSales,
      hasLength(1),
      reason: 'проигравший гонку оставил после себя лишний чек',
    );
    expect(await db.saleProductDao.countBySale(receiptNo, 1), 1);
  });

  // ── деньги и объём ───────────────────────────────────────────────────

  test('сумма в карточке пула — точные деньги, а не double', () async {
    // Две разные беды, и обе видны только на подобранных числах.
    //
    // **Сложение.** Товар по 0.1 и товар по 0.2: в `double` их сумма
    // равна 0.30000000000000004.
    //
    // **Чего эта проба НЕ проверяет — и это измерено, а не предположено.**
    // Сумма 0.3, прогнанная через `double` и обратно, снова печатается
    // как «0.3»: диверсия «карточка берёт `amount.toDouble()`» оставила
    // пробу зелёной. Значение за пределами точности `double` (18
    // значащих цифр колонки P18,S3) её бы покрасило — но покрасило и
    // **без** диверсии: money-колонки drift лежат в SQLite как `real`,
    // и 12345678901234.567 возвращается из базы как ...568. Это
    // общебазовая находка, а не дефект пула, и она записана в отчёте
    // задачи 17, а не спрятана в зелёной пробе.
    await seedProduct(
      ucode: 300,
      barcode: '4870001111111',
      price: '0.1',
      name: 'Десятая',
    );
    await seedProduct(
      ucode: 400,
      barcode: '4870002222222',
      price: '0.2',
      name: 'Пятая',
    );

    var sum = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    sum = await cart.addByBarcode(7, '4870001111111', mv(sum, 2));
    sum = await cart.addByBarcode(7, '4870002222222', mv(sum, 3));
    await cart.defer(7, mv(sum, 4), by: fullDiscountAuthority);

    final card = (await cart.watchDeferred(by: fullDiscountAuthority).first).single;

    expect(
      card.total.toString(),
      '0.3',
      reason: 'сложение денег ушло в double: 0.1 + 0.2 там не 0.3',
    );

    // Карточка пула не считает свою сумму заново — она берёт ту, что
    // записал чек. Расхождение здесь значило бы, что кассир видит в
    // списке одни деньги, а в поднятом чеке другие.
    final row = await db.saleDao.findByKey(sum.receiptNo!, 1);
    expect(card.total, row!.amount);
  });

  test('пул отдаёт все отложенные чеки, новейший первым', () async {
    // Объём, а не одна запись: одна не отличает «отсортировано» от
    // «повезло». И имена в казахской кириллице — они едут в карточку
    // целиком, а не в латинской транслитерации.
    await (db.update(db.users)..where((u) => u.id.equals(4))).write(
      const UsersCompanion(name: Value('Айгүл Смағұлова')),
    );
    await seedProduct(
      ucode: 500,
      barcode: '4870003333333',
      price: '700',
      name: 'Ысык-Көл суу',
    );

    final first = await deferOneCart(firstKey: 1);
    final second = await deferOneCart(firstKey: 10);

    var third = await cart.start(terminalId: 9, wholesale: false, meta: m(20, 0));
    third = await cart.addByBarcode(9, '4870003333333', mv(third, 21));
    final thirdNo = third.receiptNo!;
    await cart.defer(9, mv(third, 22), by: fullDiscountAuthority);

    final pool = await cart.watchDeferred(by: fullDiscountAuthority).first;
    expect(
      pool.map((c) => c.receiptNo),
      [thirdNo, second, first],
      reason: 'пул отдал не все чеки или отдал их в произвольном порядке',
    );
    expect(pool.map((c) => c.userName), everyElement('Айгүл Смағұлова'));
    expect(pool.first.firstLineName, 'Ысык-Көл суу');

    // Пул общий: чек, отложенный девятым местом, поднимает седьмое.
    final taken = await cart.loadDeferred(7, thirdNo, m(30, 0), by: fullDiscountAuthority);
    expect(taken.lines.single.name, 'Ысык-Көл суу');
  });

  // ── владелец в базе ──────────────────────────────────────────────────

  test('откладывание освобождает владельца, подъём занимает — в базе', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final receiptNo = view.receiptNo!;

    final owned = await db.saleDao.findByKey(receiptNo, 1);
    expect(owned!.terminalId, 7, reason: 'у чека в работе владелец есть');
    expect(owned.state, 0);

    await cart.defer(7, mv(view, 3), by: fullDiscountAuthority);

    final free = await db.saleDao.findByKey(receiptNo, 1);
    expect(
      free!.terminalId,
      isNull,
      reason: 'отложенный чек остался за рабочим местом — пул не общий',
    );
    expect(free.state, 3);

    await cart.loadDeferred(9, receiptNo, m(4, 0), by: fullDiscountAuthority);

    final taken = await db.saleDao.findByKey(receiptNo, 1);
    expect(
      taken!.terminalId,
      9,
      reason: 'владельцем стал не поднявший — снимок мог соврать, база нет',
    );
    expect(taken.state, 0);
  });

  // ── запертый чек ─────────────────────────────────────────────────────

  test('поднявший и потерявший связь не запирает чек навсегда', () async {
    final receiptNo = await deferOneCart();
    await cart.loadDeferred(9, receiptNo, m(4, 0), by: fullDiscountAuthority);

    // Девятое место пропало: вкладка закрыта, провод оборван. Никакой
    // команды «я отключился» касса не получает.

    // Путь освобождения первый и главный: то же рабочее место
    // возвращается и продолжает чек «с холода» — `start` без номера.
    final back = await cart.start(terminalId: 9, wholesale: false, meta: m(5, 0));
    expect(
      back.receiptNo,
      receiptNo,
      reason: 'вернувшееся место потеряло свой чек',
    );
    expect(back.lines, hasLength(1));

    // Названная цена: пока девятое место не вернулось, чек не в пуле и
    // никому другому не достаётся — это личный чек в работе (решение 4).
    // Освободить его может только сам владелец, отложив обратно.
    expect(await cart.watchDeferred(by: fullDiscountAuthority).first, isEmpty);
    expect(
      () => cart.loadDeferred(7, receiptNo, m(6, 0), by: fullDiscountAuthority),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartDeferredTakenCode),
      ),
    );

    // И второй путь освобождения — тот же, что у любого чека: владелец
    // откладывает его обратно в общий пул, и он снова достаётся всем.
    await cart.defer(9, mv(back, 7), by: fullDiscountAuthority);
    expect((await cart.watchDeferred(by: fullDiscountAuthority).first).map((c) => c.receiptNo), [
      receiptNo,
    ]);
    final afterAll = await cart.loadDeferred(7, receiptNo, m(8, 0), by: fullDiscountAuthority);
    expect(afterAll.lines, hasLength(1));
  });

  // ── удаление чужого чека ─────────────────────────────────────────────

  test('поднятие отложенного больше не удаляет чужой чек в работе', () async {
    var other = await cart.start(terminalId: 9, wholesale: false, meta: m(1, 0));
    other = await cart.addByBarcode(9, barcodeB, mv(other, 2));
    final deferredNo = await deferOneCart(firstKey: 10);

    await cart.loadDeferred(7, deferredNo, m(6, 0), by: fullDiscountAuthority);

    expect(
      (await cart.watch(9).first).lines,
      hasLength(1),
      reason: 'подъём отложенного молча снёс набранный чек соседа',
    );
    final row = await db.saleDao.findByKey(other.receiptNo!, other.posId);
    expect(row, isNotNull);
    expect(row!.terminalId, 9);
  });

  test('undeferSale поднимает чек названному месту и ничего не удаляет', () async {
    // Прямая проба на `DeferredSaleServiceImpl` — потому что удаление
    // живёт там, а не в корзине. `LocalCartService.loadDeferred` эту
    // ветку обходит (её докстринг это и объясняет), и проба выше зелёная
    // не потому, что удаления нет, а потому, что до него не доходят.
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

    // Чек в работе у браузерного терминала.
    var mine = await cart.start(terminalId: 9, wholesale: false, meta: m(1, 0));
    mine = await cart.addByBarcode(9, barcodeB, mv(mine, 2));
    final deferredNo = await deferOneCart(firstKey: 10);

    // Поднимает **девятое** место, а не касса.
    final raised = await deferredService.undeferSale(
      receiptNo: deferredNo,
      terminalId: 9,
    );

    expect(raised, isNotNull);
    expect(
      raised!.terminalId,
      9,
      reason: 'владельца назвал вызывающий, а не terminals.self()',
    );

    final untouched = await db.saleDao.findByKey(mine.receiptNo!, 1);
    expect(
      untouched,
      isNotNull,
      reason: 'undeferSale удалила чек в работе, о котором её не спрашивали',
    );
    expect(untouched!.terminalId, 9);
  });

  test('undeferSale не поднимает чек, который уже подняли', () async {
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    final receiptNo = await deferOneCart();
    await cart.loadDeferred(7, receiptNo, m(4, 0), by: fullDiscountAuthority);

    final second = await deferredService.undeferSale(
      receiptNo: receiptNo,
      terminalId: 9,
    );

    expect(
      second,
      isNull,
      reason: 'второй поднявший увёл чек у первого — и первый не узнал',
    );
    final row = await db.saleDao.findByKey(receiptNo, 1);
    expect(row!.terminalId, 7);
  });
}
