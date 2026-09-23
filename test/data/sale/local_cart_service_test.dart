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

/// Задача 7 плана «Продажа с браузерного терминала»: контракт корзины и
/// кассовая реализация.
///
/// Никаких моков: настоящая база в памяти и настоящие юзкейсы под
/// сервисом. Мок здесь доказал бы, что сервис зовёт то, что мы велели ему
/// звать, — а доказать надо другое: что **строка легла в базу**, что
/// повтор не удвоил её, что устаревшая версия отвергнута, и что два
/// рабочих места не видят корзин друг друга.
void main() {
  late AppDatabase db;
  late LocalCartService cart;

  const barcodeA = '4870001234567';
  const barcodeB = '4870007654321';

  /// Команда рабочего места, у которого **нет** чека: `receiptNo` пуст.
  /// Такими бывают только `start` первого чека и подъём отложенного
  /// поверх пустоты — всё остальное считается от снимка и берёт из него
  /// и версию, и номер чека ([mv]).
  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

  /// Команда, посчитанная от снимка [v]: и версия, и **номер чека** —
  /// оттуда. Круг правки 2: одной версии для опознания мало, у каждого
  /// нового чека счёт начинается с нуля.
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
    int measure = 0,
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            name: name,
            type: 0,
            measure: measure,
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
            // Задача 12: тумблер кассы «продажа со скидкой» получил
            // читателя на самой кассе, а не только на экране. Пробы
            // ниже назначают скидку, значит тумблер обязан быть
            // включён — иначе они мерили бы отказ политики.
            sellInDiscount: Value(true),
            // Задача 9 ревизии 2026-09-19: то же самое у тумблера «правка
            // цены». Пробы ниже правят цену строки ради слияния близнецов
            // и округлений, а не ради политики; выключенный тумблер (а он
            // выключен по умолчанию колонки) отказывал бы им первым.
            editPrice: Value(true),
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
    await seedProduct(
      ucode: 200,
      barcode: barcodeB,
      price: '300',
      name: 'Второй',
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
  });

  tearDown(() async {
    await db.close();
  });

  // ── четыре теста брифа ────────────────────────────────────────────────

  test('скан кладёт строку в базу, а не только в память', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    await cart.addByBarcode(7, barcodeA, mv(view, 2));

    final rows = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(rows, hasLength(1), reason: 'корзина не переживёт перезапуск кассы');
    expect(rows.single.ucode, 100);
    expect(rows.single.priceBefore, d('500'));
  });

  test('повтор команды с тем же ключом не удваивает строку', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    final meta = mv(view, 2);

    final first = await cart.addByBarcode(7, barcodeA, meta);
    final again = await cart.addByBarcode(7, barcodeA, meta);

    expect(again.version, first.version);
    expect(again.lines, hasLength(1));
    expect(again.lines.single.quantity, Decimal.one);

    // И в базе тоже одна строка одной штукой — снимок мог бы совпасть, а
    // база разойтись, если бы повтор писал, но не менял версию.
    final rows = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(rows, hasLength(1));
    expect(rows.single.quantity, Decimal.one);
  });

  test('команда от устаревшей версии отвергается названным отказом', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    await cart.addByBarcode(7, barcodeA, mv(view, 2));

    expect(
      () => cart.addByBarcode(7, barcodeB, mv(view, 3)),
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', cartStaleCode)),
    );

    // Отвергнутая команда не оставила следа: вторая строка не легла.
    final rows = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(rows, hasLength(1));
  });

  test('два рабочих места набирают разные корзины', () async {
    final a = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    final b = await cart.start(terminalId: 9, wholesale: false, meta: m(2, 0));

    expect(a.receiptNo, isNot(b.receiptNo));
    await cart.addByBarcode(7, barcodeA, mv(a, 3));

    expect((await cart.watch(9).first).lines, isEmpty);
    expect((await cart.watch(7).first).lines, hasLength(1));
  });

  // ── существо сверх брифа ──────────────────────────────────────────────

  test('чек в работе продолжается, а не начинается заново', () async {
    final first = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    final filled = await cart.addByBarcode(7, barcodeA, mv(first, 2));

    final again = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: mv(filled, 3),
    );

    expect(again.receiptNo, first.receiptNo);
    expect(again.lines, hasLength(1), reason: 'набранный чек потерян');
  });

  test('скидка суммой возвращается кассиру той же суммой', () async {
    // Три штуки по 100 и скидка 10: скидка не делится нацело на
    // количество, и без запаса по разрядам вернулась бы как 9.999.
    await seedProduct(ucode: 300, barcode: '4870000000003', price: '100');
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 300, d('3'), mv(view, 2));
    final lineId = view.lines.single.id;

    view = await cart.setDiscountAmount(
      7,
      lineId,
      d('10'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    expect(view.lines.single.discount, d('10'));
    expect(view.total, d('290'));

    // И после перезагрузки кассы (нового чтения из базы) — та же сумма.
    expect((await cart.watch(7).first).lines.single.discount, d('10'));
  });

  test('скидка больше строки не уводит чек в минус', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = view.lines.single.id;

    view = await cart.setDiscountAmount(
      7,
      lineId,
      d('900'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    expect(view.lines.single.discount, d('500'));
    expect(view.total, Decimal.zero);
  });

  test(
    'процент вне ста отвергается названным отказом, а не молчанием',
    () async {
      final view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      final withLine = await cart.addByBarcode(7, barcodeA, mv(view, 2));
      final lineId = withLine.lines.single.id;

      expect(
        () => cart.setDiscountPercent(
          7,
          lineId,
          d('101'),
          mv(withLine, 3),
          by: fullDiscountAuthority,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            cartInvalidAmountCode,
          ),
        ),
      );
    },
  );

  test('акция снимается, когда количество упало ниже порога', () async {
    // «Два по цене одного»: два товара 100 — один в подарок.
    await db
        .into(db.promotions)
        .insert(
          PromotionsCompanion.insert(
            name: 'Два по цене одного',
            triggerUcode: 100,
            rewardUcode: 100,
            triggerQty: const Value(2),
            rewardQty: const Value(1),
          ),
        );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 100, d('2'), mv(view, 2));
    expect(view.lines.single.discount, d('500'), reason: 'акция не сработала');

    final lineId = view.lines.single.id;
    view = await cart.setQuantity(7, lineId, Decimal.one, mv(view, 3));

    expect(
      view.lines.single.discount,
      Decimal.zero,
      reason: 'подарок пережил условие, которое его давало',
    );
  });

  test('выключенная тумблером акция перестаёт действовать', () async {
    // Приёмка задачи 19 плана «полнота продажи» (2026-09-07): «акцию можно
    // завести и, **главное**, выключить без редактирования базы». До этой
    // задачи на экран акций не вело ни одного перехода, поэтому тумблер
    // был недостижим — а выключение проверялось только тем, что
    // `getEnabled()` фильтрует по колонке.
    //
    // Проба идёт **тем путём, каким идёт тумблер** — через
    // `PromotionDao.setEnabled` (`promotions_screen.dart:136`), а не
    // вставкой строки с `enabled: false`: вставка доказала бы фильтр
    // выборки и промолчала бы, перестань экранная запись доходить до базы.
    final id = await db
        .into(db.promotions)
        .insert(
          PromotionsCompanion.insert(
            name: 'Два по цене одного',
            triggerUcode: 100,
            rewardUcode: 100,
            triggerQty: const Value(2),
            rewardQty: const Value(1),
          ),
        );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 100, d('2'), mv(view, 2));
    expect(
      view.lines.single.discount,
      d('500'),
      reason: 'акция не сработала — проба измеряла бы ноль против ноля',
    );

    await db.promotionDao.setEnabled(id, false);

    // Новый чек: скидка пересчитывается при наборе, а не задним числом.
    view = await cart.start(terminalId: 7, wholesale: false, meta: m(2, 0));
    view = await cart.addProduct(7, 100, d('2'), mv(view, 2));
    expect(
      view.lines.single.discount,
      Decimal.zero,
      reason:
          'выключенная акция всё ещё раздаёт подарки — тумблер на экране '
          'ничего не выключает',
    );
  });

  test('отложенный чек уходит в общий пул и виден обоим местам', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final receiptNo = view.receiptNo!;

    final after = await cart.defer(7, mv(view, 3), by: fullDiscountAuthority);
    expect(after.receiptNo, isNull, reason: 'чек остался за рабочим местом');

    final pool = await cart.watchDeferred(by: fullDiscountAuthority).first;
    expect(pool, hasLength(1));
    expect(pool.single.receiptNo, receiptNo);
    expect(pool.single.total, d('500'));
    expect(pool.single.lineCount, 1);
    expect(pool.single.userId, 4);
    expect(pool.single.userName, 'Айгуль');
    expect(pool.single.firstLineName, 'Товар');

    // Владельца у отложенного чека нет — правило смысла Sales.terminalId.
    final row = await db.saleDao.findByKey(receiptNo, 1);
    expect(row!.terminalId, isNull);
    expect(row.state, 3);

    // Поднимает другое рабочее место, и строки уже там — пакетной
    // вставки при откладывании больше нет.
    final taken = await cart.loadDeferred(
      9,
      receiptNo,
      m(4, 0),
      by: fullDiscountAuthority,
    );
    expect(taken.receiptNo, receiptNo);
    expect(taken.lines, hasLength(1));
    expect(taken.terminalId, 9);
  });

  test('повтор откладывания не отказывает и не откладывает дважды', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

    final meta = mv(view, 3);
    await cart.defer(7, meta, by: fullDiscountAuthority);
    final again = await cart.defer(7, meta, by: fullDiscountAuthority);

    expect(again.receiptNo, isNull);
    expect(
      await cart.watchDeferred(by: fullDiscountAuthority).first,
      hasLength(1),
    );
  });

  test('второй поднявший отложенный чек получает названный отказ', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final receiptNo = view.receiptNo!;
    await cart.defer(7, mv(view, 3), by: fullDiscountAuthority);

    await cart.loadDeferred(9, receiptNo, m(4, 0), by: fullDiscountAuthority);

    expect(
      () =>
          cart.loadDeferred(11, receiptNo, m(5, 0), by: fullDiscountAuthority),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartDeferredTakenCode),
      ),
    );
  });

  test('поднять отложенный поверх своего непустого чека нельзя', () async {
    var seven = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    seven = await cart.addByBarcode(7, barcodeA, mv(seven, 2));
    final receiptNo = seven.receiptNo!;
    await cart.defer(7, mv(seven, 3), by: fullDiscountAuthority);

    var nine = await cart.start(terminalId: 9, wholesale: false, meta: m(4, 0));
    nine = await cart.addByBarcode(9, barcodeB, mv(nine, 5));

    expect(
      () => cart.loadDeferred(
        9,
        receiptNo,
        mv(nine, 6),
        by: fullDiscountAuthority,
      ),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartNotEmptyCode),
      ),
    );

    // И свой чек цел — молча его никто не удалил.
    expect((await cart.watch(9).first).lines, hasLength(1));
  });

  test('команда без начатого чека отвергается названным отказом', () async {
    expect(
      () => cart.addByBarcode(7, barcodeA, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartNotStartedCode),
      ),
    );
  });

  test('агент и опт живут в базе, а не в памяти экрана', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.setAgent(7, 42, mv(view, 2));
    expect(view.agentId, 42);

    view = await cart.setWholesale(
      7,
      true,
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    expect(view.wholesale, isTrue);

    final row = await db.saleDao.findByKey(view.receiptNo!, view.posId);
    expect(row!.customerLocalId, 42);
    expect(row.isWholesale, isTrue);
  });

  test('маркировка не копится: вторая марка заменяет первую', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = view.lines.single.id;

    view = await cart.setMark(7, lineId, 'MARK-1', mv(view, 3));
    view = await cart.setMark(7, lineId, 'MARK-2', mv(view, 4));

    expect(view.lines.single.mark, 'MARK-2');
    final marks = await db.saleProductDao.findMarksBySaleProduct(
      int.parse(lineId),
    );
    expect(marks, hasLength(1));
  });

  test('очистка убирает строки из базы, а не только с экрана', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.clear(7, mv(view, 3));

    expect(view.lines, isEmpty);
    expect(await db.saleProductDao.countBySale(view.receiptNo!, view.posId), 0);
  });

  test('поиск находит товар по имени и по штрихкоду', () async {
    expect((await cart.search('Втор')).single.id, 200);
    expect((await cart.search(barcodeA)).single.id, 100);
    expect((await cart.search(barcodeA)).single.price, d('500'));
  });

  // ── команды, которых не было в первом круге ───────────────────────────
  //
  // Проход `anti-gaps` (шаг 2) прогнал этот файл с учётом покрытия и нашёл
  // **пять публичных команд контракта, которых не касался ни один тест**:
  // `increment`, `decrement`, `updatePrice`, `removeLine` и удачный путь
  // `setDiscountPercent` (краснел только его отказ). Прогон был зелёный, и
  // зелёным он был бы и с пустыми телами этих пяти — ровно тот случай,
  // ради которого проход существует. Ниже — они и непройденные ветви
  // рядом с ними.

  test(
    'плюс и минус меняют количество, минус до нуля убирает строку',
    () async {
      var view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
      final lineId = view.lines.single.id;

      view = await cart.increment(7, lineId, mv(view, 3));
      expect(view.lines.single.quantity, d('2'));
      expect(view.total, d('1000'));

      view = await cart.decrement(7, lineId, mv(view, 4));
      expect(view.lines.single.quantity, Decimal.one);

      view = await cart.decrement(7, lineId, mv(view, 5));
      expect(view.lines, isEmpty, reason: 'строка с нулём — это не строка');
      expect(
        await db.saleProductDao.countBySale(view.receiptNo!, view.posId),
        0,
        reason: 'строка исчезла с экрана, но осталась в базе',
      );
    },
  );

  test('скидка процентом считается от строки и ложится в базу', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 100, d('2'), mv(view, 2));
    final lineId = view.lines.single.id;

    view = await cart.setDiscountPercent(
      7,
      lineId,
      d('10'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    expect(view.lines.single.discount, d('100'));
    expect(view.total, d('900'));
    expect((await cart.watch(7).first).lines.single.discount, d('100'));
  });

  test('правка цены сохраняет назначенную скидку', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = view.lines.single.id;
    view = await cart.setDiscountAmount(
      7,
      lineId,
      d('50'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    view = await cart.updatePrice(
      7,
      lineId,
      d('400'),
      mv(view, 4),
      by: fullDiscountAuthority,
    );

    expect(view.lines.single.price, d('400'));
    expect(view.lines.single.discount, d('50'), reason: 'скидка потерялась');
    expect(view.total, d('350'));
  });

  test('скидка не переживает цену, которая стала меньше неё', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = view.lines.single.id;
    view = await cart.setDiscountAmount(
      7,
      lineId,
      d('400'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    view = await cart.updatePrice(
      7,
      lineId,
      d('100'),
      mv(view, 4),
      by: fullDiscountAuthority,
    );

    expect(view.lines.single.discount, d('100'));
    expect(view.total, Decimal.zero, reason: 'строка ушла в минус');
  });

  test('удаление строки уносит её из базы вместе с маркой', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = view.lines.single.id;
    view = await cart.setMark(7, lineId, 'MARK-1', mv(view, 3));

    view = await cart.removeLine(7, lineId, mv(view, 4));

    expect(view.lines, isEmpty);
    expect(await db.saleProductDao.countBySale(view.receiptNo!, view.posId), 0);
    expect(
      await db.saleProductDao.findMarksBySaleProduct(int.parse(lineId)),
      isEmpty,
      reason: 'марка пережила строку, которой была',
    );
  });

  test(
    'второй скан того же товара увеличивает строку, а не заводит вторую',
    () async {
      var view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
      view = await cart.addByBarcode(7, barcodeA, mv(view, 3));

      expect(view.lines, hasLength(1));
      expect(view.lines.single.quantity, d('2'));
      expect(
        await db.saleProductDao.countBySale(view.receiptNo!, view.posId),
        1,
      );
    },
  );

  test('неизвестный штрихкод и неизвестный код — названный отказ', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );

    expect(
      () => cart.addByBarcode(7, '4870009999999', mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          cartProductNotFoundCode,
        ),
      ),
    );
    expect(
      () => cart.addProduct(7, 999, Decimal.one, mv(view, 3)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          cartProductNotFoundCode,
        ),
      ),
    );
  });

  test('команда по несуществующей строке — названный отказ', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );

    expect(
      () => cart.increment(7, '4242', mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartLineNotFoundCode),
      ),
    );
  });

  test('пробитый удалённый товар возвращается в каталог', () async {
    await (db.update(db.productInfos)..where((p) => p.ucode.equals(200))).write(
      const ProductInfosCompanion(isDeleted: Value(true)),
    );

    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    await cart.addByBarcode(7, barcodeB, mv(view, 2));

    final info = await db.productInfoDao.findByUcode(200);
    expect(info!.isDeleted, isFalse);
  });

  test('повтор начала чека тем же ключом отдаёт тот же чек', () async {
    final first = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    final again = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );

    expect(again.receiptNo, first.receiptNo);
    expect(again.version, first.version);
  });

  test(
    'без открытой смены чек не начинается — отказ, а не молчаливая смена',
    () async {
      await (db.update(db.shifts)..where((sh) => sh.isOpened.equals(true)))
          .write(const ShiftsCompanion(isOpened: Value(false)));

      expect(
        () => cart.start(terminalId: 7, wholesale: false, meta: m(1, 0)),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'shift_not_open'),
        ),
      );
    },
  );

  test('пустой чек в работе не мешает поднять отложенный', () async {
    var seven = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    seven = await cart.addByBarcode(7, barcodeA, mv(seven, 2));
    final receiptNo = seven.receiptNo!;
    await cart.defer(7, mv(seven, 3), by: fullDiscountAuthority);

    // Девятое место успело начать свой чек, но ничего не набрало.
    final nine = await cart.start(
      terminalId: 9,
      wholesale: false,
      meta: m(4, 0),
    );

    final taken = await cart.loadDeferred(
      9,
      receiptNo,
      mv(nine, 5),
      by: fullDiscountAuthority,
    );
    expect(taken.receiptNo, receiptNo);
    expect(taken.lines, hasLength(1));
  });

  test('количество, выставленное в ноль, убирает строку из базы', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = view.lines.single.id;

    view = await cart.setQuantity(7, lineId, Decimal.zero, mv(view, 3));

    expect(view.lines, isEmpty);
    expect(await db.saleProductDao.countBySale(view.receiptNo!, view.posId), 0);
  });

  test('повтор подъёма отложенного чека не поднимает его дважды', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final receiptNo = view.receiptNo!;
    await cart.defer(7, mv(view, 3), by: fullDiscountAuthority);

    final meta = m(4, 0);
    final first = await cart.loadDeferred(
      9,
      receiptNo,
      meta,
      by: fullDiscountAuthority,
    );
    final again = await cart.loadDeferred(
      9,
      receiptNo,
      meta,
      by: fullDiscountAuthority,
    );

    expect(again.receiptNo, first.receiptNo);
    expect(again.version, first.version);
    expect(again.lines, hasLength(1));
  });

  test('в пул попадает чужая касса, но не чек в другом состоянии', () async {
    // **Утверждение перевёрнуто 2026-09-19, и это решение заказчика.**
    // Раньше проба требовала, чтобы отложенный чек соседней кассы в пул НЕ
    // попадал. Сценарий заказчика требует обратного: покупатель отложил
    // корзину на первой кассе, вернулся — там очередь, пошёл ко второй, и
    // она обязана эту корзину увидеть. Продажи ещё нет; деньги получит та
    // касса, которая пробьёт.
    //
    // Что осталось прежним и почему проба всё ещё что-то мерит: завершённый
    // чек в пул не попадает. Правило нуля (`qa-depth`) держится на нём —
    // иначе «список пуст» и «фильтр работает» были бы неотличимы.
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final mine = view.receiptNo!;
    await cart.defer(7, mv(view, 3), by: fullDiscountAuthority);

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 900,
            // Отложенный чек соседней кассы: состояние то же, касса чужая.
            posId: 2,
            userId: 4,
            amount: d('777'),
            time: 0,
            state: const Value(3),
            terminalId: const Value(null),
          ),
        );
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 901,
            posId: 1,
            userId: 4,
            amount: d('888'),
            time: 100,
            // Завершённый чек своей кассы: касса та же, состояние другое.
            state: const Value(4),
            terminalId: const Value(null),
          ),
        );

    final pool = await cart.watchDeferred(by: fullDiscountAuthority).first;
    expect(
      pool.map((c) => c.receiptNo).toSet(),
      {mine, 900},
      reason: 'свой отложенный и отложенный соседа — оба доступны для подъёма',
    );
    expect(
      pool.map((c) => c.receiptNo),
      isNot(contains(901)),
      reason: 'завершённый чек поднимать нечего — он уже продан',
    );
    expect(
      pool.firstWhere((c) => c.receiptNo == 900).posId,
      2,
      reason:
          'карточка обязана нести номер кассы-владельца: по нему экран '
          'отличает чужую корзину, а подъём знает, чей документ занимать',
    );
  });

  test('подъём отложенного от устаревшей версии отвергается', () async {
    // Круг правки 1: `loadDeferred` была единственной из команд, не
    // читавшей `baseVersion` вовсе — правило держали не все, а почти все.
    var seven = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    seven = await cart.addByBarcode(7, barcodeA, mv(seven, 2));
    final receiptNo = seven.receiptNo!;
    await cart.defer(7, mv(seven, 3), by: fullDiscountAuthority);

    // У девятого места чек пустой, но его версия уже уехала на единицу.
    final nine = await cart.start(
      terminalId: 9,
      wholesale: false,
      meta: m(4, 0),
    );
    await cart.setWholesale(9, true, mv(nine, 5), by: fullDiscountAuthority);

    expect(
      // Номер чека верный — устарела именно версия, и отказ обязан быть
      // про версию, а не про чек.
      () => cart.loadDeferred(
        9,
        receiptNo,
        CartCommandMeta(key: 'k6', baseVersion: 0, receiptNo: nine.receiptNo),
        by: fullDiscountAuthority,
      ),
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', cartStaleCode)),
    );
  });

  test('поднять несуществующий чек — названный отказ', () async {
    expect(
      () => cart.loadDeferred(7, 4242, m(1, 0), by: fullDiscountAuthority),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          cartDeferredNotFoundCode,
        ),
      ),
    );
  });

  test('пустой чек не откладывается', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );

    expect(
      () => cart.defer(7, mv(view, 2), by: fullDiscountAuthority),
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', cartEmptyCode)),
    );
  });

  test('откладывание от устаревшей версии отвергается', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

    expect(
      () => cart.defer(
        7,
        CartCommandMeta(key: 'k3', baseVersion: 0, receiptNo: view.receiptNo),
        by: fullDiscountAuthority,
      ),
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', cartStaleCode)),
    );
    expect(
      (await cart.watchDeferred(by: fullDiscountAuthority).first),
      isEmpty,
    );
  });

  test('после откладывания подписка отдаёт пустую корзину', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    await cart.defer(7, mv(view, 3), by: fullDiscountAuthority);

    final after = await cart.watch(7).first;
    expect(after.receiptNo, isNull);
    expect(after.lines, isEmpty);
    expect(after.version, 0, reason: 'с этой версии начнётся следующий чек');
  });

  test('откладывать нечего, когда чек не начат', () async {
    expect(
      () => cart.defer(7, m(1, 0), by: fullDiscountAuthority),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartNotStartedCode),
      ),
    );
  });

  // ── одновременность ───────────────────────────────────────────────────
  //
  // Круг правки 1. Тридцать семь тестов выше — строго последовательные, и
  // ни один не видел, что обе гарантии контракта (ключ повтора и версия)
  // проверялись **вне** транзакции: очередь транзакций drift защищает сами
  // транзакции, а не чтение перед ними. `anti-gaps` спросил «какой строки
  // не касается прогон» и не спросил «какого **утверждения** не касается
  // прогон» — вот эти два утверждения.

  test('две одновременные команды с одним ключом не удваивают товар', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    final meta = mv(view, 2);

    final both = await Future.wait([
      cart.addByBarcode(7, barcodeA, meta),
      cart.addByBarcode(7, barcodeA, meta),
    ]);

    expect(
      both.map((v) => v.version),
      everyElement(1),
      reason: 'повтор посчитан вторым изменением',
    );
    expect(both.first.lines.single.quantity, Decimal.one);
    expect(both.last.lines.single.quantity, Decimal.one);

    final rows = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(rows, hasLength(1));
    expect(
      rows.single.quantity,
      Decimal.one,
      reason: 'терминал не дождался ответа, повторил — и товар удвоился',
    );

    final sale = await db.saleDao.findByKey(view.receiptNo!, view.posId);
    expect(sale!.cartVersion, 1);
  });

  test('из двух одновременных команд от одной версии проходит одна', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );

    Future<Object> outcome(Future<CartView> f) =>
        f.then<Object>((v) => v).catchError((Object e) => e);

    final results = await Future.wait([
      outcome(cart.addByBarcode(7, barcodeA, mv(view, 2))),
      outcome(cart.addByBarcode(7, barcodeB, mv(view, 3))),
    ]);

    expect(results.whereType<CartView>(), hasLength(1));
    expect(
      results.whereType<WireRefusal>().single.code,
      cartStaleCode,
      reason: 'вторая команда применилась поверх чужого изменения',
    );

    final rows = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(rows, hasLength(1));

    final sale = await db.saleDao.findByKey(view.receiptNo!, view.posId);
    expect(
      sale!.cartVersion,
      1,
      reason: 'счётчик версий разошёлся с числом изменений',
    );
  });

  test('два одновременных начала чека дают один чек, а не два', () async {
    // Круг правки 2: `start` был единственной командой снаружи правки
    // круга 1. Два одновременных запуска с одним ключом заводили два
    // чека, сжигали два номера и оставляли месту две продажи в работе —
    // а какую из них продолжит кассир, не знал никто.
    final meta = m(1, 0);

    final both = await Future.wait([
      cart.start(terminalId: 7, wholesale: false, meta: meta),
      cart.start(terminalId: 7, wholesale: false, meta: meta),
    ]);

    expect(both.first.receiptNo, both.last.receiptNo);

    final inProgress = await (db.select(
      db.sales,
    )..where((s) => s.state.equals(0) & s.terminalId.equals(7))).get();
    expect(
      inProgress,
      hasLength(1),
      reason: 'у рабочего места две продажи в работе разом',
    );
    expect(
      await db.saleDao.findLastReceiptNo(),
      1,
      reason: 'сожжён лишний номер чека',
    );
  });

  test('запоздавшая команда не ложится в чек, начатый после неё', () async {
    // Круг правки 2, проба разбора: версия сторожит «сколько изменений
    // было у текущего чека», а не «тот ли это чек». У чека №2 версия
    // тоже ноль — и команда от чека №1 совпала бы по версии.
    var first = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    first = await cart.addByBarcode(7, barcodeA, mv(first, 2));
    // Команда посчитана здесь и «застряла в проводе»: чек №1, версия 1.
    final belated = mv(first, 3);

    await cart.defer(7, mv(first, 4), by: fullDiscountAuthority);
    var second = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(5, 0),
    );
    second = await cart.addByBarcode(7, barcodeA, mv(second, 6));

    expect(second.receiptNo, isNot(first.receiptNo));
    expect(
      second.version,
      belated.baseVersion,
      reason:
          'проба потеряла смысл: версии обязаны совпасть, иначе '
          'запоздавшую команду отвергла бы сверка версии, а не опознание',
    );

    expect(
      () => cart.addByBarcode(7, barcodeB, belated),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartWrongReceiptCode),
      ),
    );
    expect(
      (await cart.watch(7).first).lines,
      hasLength(1),
      reason: 'запоздавшая команда легла в чужой чек',
    );
  });

  // ── круг правки 3 ─────────────────────────────────────────────────────

  test('чек соседней кассы не становится своим', () async {
    // Строки чужой кассы попадают в базу штатно: обмен и слияние тянут
    // чеки других касс сети. `state = 0` и `terminalId = 7` у них
    // совпадают с нашими — не совпадает только касса.
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 1,
            posId: 2,
            userId: 4,
            amount: d('999'),
            time: 0,
            state: const Value(0),
            terminalId: const Value(7),
          ),
        );

    final view = await cart.watch(7).first;
    expect(view.receiptNo, isNull, reason: 'чек соседней кассы показан своим');

    // И записать в него ничего нельзя: чека в работе у места нет.
    expect(
      () => cart.addByBarcode(7, barcodeA, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartNotStartedCode),
      ),
    );
    expect(
      await db.saleProductDao.countBySale(1, 2),
      0,
      reason: 'строка легла в чек соседней кассы',
    );
  });

  test('возобновление чека не снимает опт молча', () async {
    var view = await cart.start(terminalId: 7, wholesale: true, meta: m(1, 0));
    expect(view.wholesale, isTrue);
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

    // Законный снимок, законная версия — и розница в доводе.
    final resumed = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: mv(view, 3),
    );

    expect(
      resumed.wholesale,
      isTrue,
      reason: 'опт снят возобновлением, и версия этого не показала',
    );
    final row = await db.saleDao.findByKey(view.receiptNo!, view.posId);
    expect(row!.isWholesale, isTrue);
    expect(resumed.version, view.version);
  });

  test('возобновление не переписывает округления чека', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

    // Настройку кассы поменяли посреди чека.
    await db
        .update(db.thisPosEntries)
        .write(const ThisPosEntriesCompanion(discountsRoundType: Value(1)));

    final resumed = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: mv(view, 3),
    );

    final row = await db.saleDao.findByKey(view.receiptNo!, view.posId);
    expect(
      row!.discountsRoundType,
      0,
      reason: 'правила округления чека сменились под ним, без версии',
    );
    expect(resumed.version, view.version);
  });

  test('start с холода продолжает чек, а не отказывает', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

    // Вторая вкладка того же терминала: номера чека она не знает.
    final cold = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(3, 0),
    );

    expect(cold.receiptNo, view.receiptNo);
    expect(cold.lines, hasLength(1));
    expect(cold.version, view.version);
  });

  test('start с названным чужим номером отвергается', () async {
    final view = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );

    expect(
      () => cart.start(
        terminalId: 7,
        wholesale: false,
        meta: CartCommandMeta(
          key: 'k2',
          baseVersion: view.version,
          receiptNo: view.receiptNo! + 100,
        ),
      ),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartWrongReceiptCode),
      ),
    );
  });

  test('start с названным чеком и устаревшей версией отвергается', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

    expect(
      () => cart.start(
        terminalId: 7,
        wholesale: false,
        // Номер верный, версия — от снимка до скана.
        meta: CartCommandMeta(
          key: 'k3',
          baseVersion: 0,
          receiptNo: view.receiptNo,
        ),
      ),
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', cartStaleCode)),
    );
  });

  test('два одновременных начала с разными ключами не отказывают', () async {
    final both = await Future.wait([
      cart.start(terminalId: 7, wholesale: false, meta: m(1, 0)),
      cart.start(terminalId: 7, wholesale: false, meta: m(2, 0)),
    ]);

    expect(both.first.receiptNo, both.last.receiptNo);
    expect(await db.saleDao.findLastReceiptNo(), 1);
  });

  test('оптовый чек берёт оптовую цену, розничный — розничную', () async {
    // Круг правки 4: теста на две цены не было ни одного, поэтому пробел
    // и не заметили — `setWholesale` меняла флаг, поднимала версию и не
    // делала ничего, а оптовая цена с браузерного терминала была
    // недостижима.
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(500),
            barcode: 4870000000005,
            name: 'Двухценовой',
            type: 0,
            measure: 0,
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(500),
            barcode: 4870000000005,
            sellingPrice: Value(d('500')),
            wholesalePrice: Value(d('100')),
          ),
        );

    var retail = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1, 0),
    );
    retail = await cart.addProduct(7, 500, Decimal.one, mv(retail, 2));
    expect(retail.lines.single.price, d('500'));
    await cart.defer(7, mv(retail, 3), by: fullDiscountAuthority);

    var wholesale = await cart.start(
      terminalId: 7,
      wholesale: true,
      meta: m(4, 0),
    );
    wholesale = await cart.addProduct(7, 500, Decimal.one, mv(wholesale, 5));
    expect(
      wholesale.lines.single.price,
      d('100'),
      reason: 'оптовый чек набран по розничной цене',
    );
    expect(wholesale.total, d('100'));
  });

  test('оптовая цена берётся и сканом штрихкода', () async {
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(600),
            barcode: 4870000000006,
            sellingPrice: Value(d('800')),
            wholesalePrice: Value(d('200')),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(600),
            barcode: 4870000000006,
            name: 'Сканируемый',
            type: 0,
            measure: 0,
          ),
        );

    var view = await cart.start(terminalId: 7, wholesale: true, meta: m(1, 0));
    view = await cart.addByBarcode(7, '4870000000006', mv(view, 2));

    expect(view.lines.single.price, d('200'));
  });

  test('без оптовой цены оптовый чек берёт розничную', () async {
    // Правило то же, что у пути, который кладёт строки сегодня
    // (`SaleProductCreationUseCaseImpl`): опт применяется, только если
    // оптовая цена вообще задана.
    var view = await cart.start(terminalId: 7, wholesale: true, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));

    expect(view.lines.single.price, d('500'));
  });

  test(
    'ненастроенная касса отвечает названным отказом, а не поломкой',
    () async {
      // Круг правки 5: единая политика номера кассы (круг 4) сломала то, что
      // аккуратно сделала задача 5 — отказ `till_not_configured` приходил
      // **значением**, и у экрана под этот код есть свой ключ. После круга 4
      // `start` бросал внутреннее исключение, не доходя до места, где отказ
      // формулируется, и на провод уехало бы одно имя типа.
      await db.delete(db.thisPosEntries).go();

      expect(
        () => cart.start(terminalId: 7, wholesale: false, meta: m(1, 0)),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            'till_not_configured',
          ),
        ),
      );
      expect(
        cart.watch(7).first,
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            'till_not_configured',
          ),
        ),
      );
    },
  );

  test(
    'после перехода в опт пересканированный товар берёт оптовую цену',
    () async {
      // Круг правки 5: ветка слияния брала прежнюю цену строки и вычисленную
      // не смотрела вовсе — товар, уже лежащий в корзине, оптовую цену не
      // получал **никогда**. Кассир переключает режим, видит ярлык «ОПТ»,
      // пересканирует товар (единственное, что он попробует) — и цена молча
      // остаётся розничной.
      await db
          .into(db.productPrices)
          .insert(
            ProductPricesCompanion.insert(
              ucode: const Value(700),
              barcode: 4870000000007,
              sellingPrice: Value(d('900')),
              wholesalePrice: Value(d('300')),
            ),
          );
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion.insert(
              ucode: const Value(700),
              barcode: 4870000000007,
              name: 'Двухценовой',
              type: 0,
              measure: 0,
            ),
          );

      var view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      view = await cart.addProduct(7, 700, Decimal.one, mv(view, 2));
      expect(view.lines.single.price, d('900'));

      view = await cart.setWholesale(
        7,
        true,
        mv(view, 3),
        by: fullDiscountAuthority,
      );
      view = await cart.addProduct(7, 700, Decimal.one, mv(view, 4));

      expect(
        view.lines,
        hasLength(2),
        reason: 'новые единицы подмешались в строку по старой цене',
      );
      expect(view.lines.map((l) => l.price), containsAll([d('900'), d('300')]));
      expect(view.total, d('1200'));

      // Уже набранная единица осталась по своей цене — политика заявлена и
      // соблюдена (докстринг `CartService.setWholesale`).
      expect(view.lines.first.price, d('900'));
      expect(view.lines.first.quantity, Decimal.one);
    },
  );

  test('правленная вручную цена не разбавляется каталожной', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.updatePrice(
      7,
      view.lines.single.id,
      d('400'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    view = await cart.addByBarcode(7, barcodeA, mv(view, 4));

    expect(view.lines, hasLength(2));
    expect(view.lines.map((l) => l.price), containsAll([d('400'), d('500')]));
  });

  // Тест «имя рабочего места — доверенный довод» убран кругом правки 5.
  // Он был зелёным сторожем, который ничего не сторожил: обе стороны в нём
  // звали одно и то же имя, а на уровне сервиса своё и чужое имя
  // неразличимы **по определению** — красным он не стал бы ни от какого
  // переноса защиты внутрь, зато покраснел бы ложно от смены политики
  // холодного `start`. Настоящий сторож этого требования ставит задача 10,
  // где есть кадр и сеанс; само требование — в докстринге `CartService`.

  test('холодный start не сжигает ключ повтора соседней вкладки', () async {
    // Круг правки 4: вкладка A применила команду и не получила ответа;
    // вкладка B зовёт холодный `start`; честный повтор A обязан вернуть
    // тот же снимок, а не отказ.
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    final applied = mv(view, 2);
    view = await cart.addByBarcode(7, barcodeA, applied);

    // Вкладка B — то же рабочее место, номера чека не знает.
    await cart.start(terminalId: 7, wholesale: false, meta: m(3, 0));

    final again = await cart.addByBarcode(7, barcodeA, applied);
    expect(again.version, view.version);
    expect(
      again.lines.single.quantity,
      Decimal.one,
      reason: 'повтор применился вторым разом',
    );
  });

  // ── чек в работе — не деньги ──────────────────────────────────────────
  //
  // Круг правки 1, находка I1. Задача 7 положила в два денежных агрегата
  // оба недостающих слагаемых: `setAgent` пишет клиента чеку **в работе**,
  // а каждая команда пишет ему непустую сумму. Время здесь проставляется
  // руками намеренно: сегодня у незавершённого чека оно ноль, и именно
  // ноль спасал итог смены — то есть денежный итог держался на побочном
  // свойстве соседней колонки, а не на условии. Проверяется условие.

  test('итог смены игнорирует чек в работе', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    await (db.update(db.sales)..where(
          (s) =>
              s.receiptNo.equals(view.receiptNo!) & s.posId.equals(view.posId),
        ))
        .write(SalesCompanion(time: Value(now)));

    expect(
      await db.saleDao.amountOfShift(4, now - 10, now + 10),
      anyOf(isNull, 0.0),
      reason: 'ненабранный чек попал в выручку смены',
    );

    // Страховка от вырожденного результата: настоящая продажа в тот же
    // отрезок считается — значит фильтр отсекает состояние, а не всё.
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 900,
            posId: 1,
            userId: 4,
            amount: d('700'),
            time: now,
            state: const Value(4),
            terminalId: const Value(null),
          ),
        );
    expect(await db.saleDao.amountOfShift(4, now - 10, now + 10), 700.0);
  });

  test('баланс агента игнорирует чек в работе', () async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.setAgent(7, 42, mv(view, 3));

    expect(
      await db.saleDao.sumAmountByCustomerLocalId(42),
      anyOf(isNull, 0.0),
      reason: 'долг агента вырос на скан ненабранного чека',
    );

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 900,
            posId: 1,
            userId: 4,
            amount: d('700'),
            time: 100,
            state: const Value(4),
            customerLocalId: const Value(42),
            terminalId: const Value(null),
          ),
        );
    expect(await db.saleDao.sumAmountByCustomerLocalId(42), 700.0);
  });

  test('округление кассы применяется к цене строки со скидкой', () async {
    // Настройка кассы «округлять цену вверх при скидке» переносится в чек
    // при его начале (`Sales.discountsRoundType`) — как и было в
    // `SaleState.roundedUnitPrice`.
    await db
        .update(db.thisPosEntries)
        .write(const ThisPosEntriesCompanion(discountsRoundType: Value(1)));
    await seedProduct(ucode: 400, barcode: '4870000000004', price: '100.5');

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 400, Decimal.one, mv(view, 2));
    expect(
      view.lines.single.price,
      d('100.5'),
      reason: 'без скидки округление скидок не применяется',
    );

    final lineId = view.lines.single.id;
    view = await cart.setDiscountAmount(
      7,
      lineId,
      d('10'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    expect(view.lines.single.price, d('101'));
    expect(view.total, d('91'));
  });

  // ── задача 8: четыре находки координатора ─────────────────────────────

  /// Товар с двумя ценами — им набирается чек, в котором один и тот же
  /// товар лежит двумя строками (круг правки 5 задачи 7 развёл их по цене).
  Future<void> seedTwoPriced() async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(700),
            barcode: 4870000000007,
            name: 'Двухценовой',
            type: 0,
            measure: 0,
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(700),
            barcode: 4870000000007,
            sellingPrice: Value(d('900')),
            wholesalePrice: Value(d('300')),
          ),
        );
    await db
        .into(db.promotions)
        .insert(
          PromotionsCompanion.insert(
            name: 'Два по цене одного',
            triggerUcode: 700,
            rewardUcode: 700,
            triggerQty: const Value(2),
            rewardQty: const Value(1),
          ),
        );
  }

  test('итог чека с акцией не зависит от порядка набора', () async {
    // Находка 1 задачи 8. Один и тот же набор — одна единица розницей, две
    // оптом — набирается в двух порядках. Подарок раздавался **в порядке
    // вставки строк**, и его цена (а с ней и итог чека) зависела от того,
    // в каком порядке кассир нажимал кнопки.
    await seedTwoPriced();

    // Порядок A: сначала розница, потом опт.
    var a = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    a = await cart.addProduct(7, 700, Decimal.one, mv(a, 2));
    a = await cart.setWholesale(7, true, mv(a, 3), by: fullDiscountAuthority);
    a = await cart.addProduct(7, 700, d('2'), mv(a, 4));

    // Порядок B: тот же набор с другого рабочего места, наоборот.
    var b = await cart.start(terminalId: 8, wholesale: true, meta: m(11, 0));
    b = await cart.addProduct(8, 700, d('2'), mv(b, 12));
    b = await cart.setWholesale(8, false, mv(b, 13), by: fullDiscountAuthority);
    b = await cart.addProduct(8, 700, Decimal.one, mv(b, 14));

    expect(
      a.lines.map((l) => l.quantity * l.price).reduce((x, y) => x + y),
      d('1500'),
      reason:
          'наборы обязаны совпасть до скидки — иначе тест сравнивает разное',
    );
    expect(
      b.lines.map((l) => l.quantity * l.price).reduce((x, y) => x + y),
      d('1500'),
    );

    expect(
      a.total,
      b.total,
      reason: 'итог зависит от порядка нажатий, а набор один и тот же',
    );
    // Подарок — самая дешёвая единица: 300, а не 900.
    expect(a.total, d('1200'));
    expect(a.totalDiscount, d('300'));
  });

  test('подарок минует строку со скидкой и уходит самой дешёвой', () async {
    // Вторая половина находки 1: правило раздачи названо, а не выведено из
    // порядка вставки. Три строки одного товара, и порядок вставки
    // **обратен** порядку цен — 900, 500, 300, — а первая из них ещё и со
    // скидкой кассира.
    //
    // Строка со скидкой из раздачи исключена (это было и раньше), но
    // подарок уходил **следующей по вставке**, то есть строке за 500.
    // Правило «самая дешёвая единица» отдаёт его строке за 300, и это
    // разные деньги: 1150 против 1350.
    await seedTwoPriced();

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 700, Decimal.one, mv(view, 2));
    final first = view.lines.single.id;
    view = await cart.setDiscountAmount(
      7,
      first,
      d('50'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );

    view = await cart.addProduct(7, 700, Decimal.one, mv(view, 4));
    final second = view.lines.firstWhere((l) => l.id != first).id;
    view = await cart.updatePrice(
      7,
      second,
      d('500'),
      mv(view, 5),
      by: fullDiscountAuthority,
    );

    view = await cart.setWholesale(
      7,
      true,
      mv(view, 6),
      by: fullDiscountAuthority,
    );
    view = await cart.addProduct(7, 700, Decimal.one, mv(view, 7));

    expect(
      view.lines.map((l) => l.price).toList(),
      [d('900'), d('500'), d('300')],
      reason:
          'порядок вставки обязан быть обратен порядку цен — иначе '
          'тест не отличает правило от порядка набора',
    );

    final withManual = view.lines.firstWhere((l) => l.price == d('900'));
    expect(
      withManual.discount,
      d('50'),
      reason: 'подарок сложился с ручной скидкой на одной строке',
    );
    expect(
      view.lines.firstWhere((l) => l.price == d('300')).discount,
      d('300'),
      reason: 'подарок ушёл не самой дешёвой единице',
    );
    expect(
      view.lines.firstWhere((l) => l.price == d('500')).discount,
      Decimal.zero,
    );
    expect(view.total, d('1350'));
  });

  test('строки с одинаковой видимой ценой сливаются, а не двоятся', () async {
    // Находка 2 задачи 8. Округление веса включено: цены 100.4 и 100.6
    // показываются кассиру одинаково — «100», — а ключ слияния до этой
    // правки был **неокруглённой** ценой. Два одинаковых ряда в чеке, и
    // объяснить их нечем: ключ в снимок не выведен.
    await db
        .update(db.thisPosEntries)
        .write(const ThisPosEntriesCompanion(weightProductRoundType: Value(2)));
    await seedProduct(
      ucode: 500,
      barcode: '4870000000005',
      price: '100.4',
      name: 'Весовой',
      measure: 1,
    );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addProduct(7, 500, Decimal.one, mv(view, 2));
    view = await cart.updatePrice(
      7,
      view.lines.single.id,
      d('100.6'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    expect(view.lines.single.price, d('100'), reason: 'округление не работает');

    view = await cart.addProduct(7, 500, Decimal.one, mv(view, 4));

    expect(
      view.lines,
      hasLength(1),
      reason: 'кассир видит два одинаковых ряда и не понимает почему',
    );
    expect(view.lines.single.quantity, d('2'));
  });

  test('правка цены до соседней сливает строки, а не оставляет две', () async {
    // Вторая половина находки 2: «и слить их нечем». Кассир развёл строки
    // ручной ценой (круг правки 5 задачи 7), потом вернул цену обратно —
    // и до этой правки в чеке навсегда оставались два одинаковых ряда.
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final first = view.lines.single.id;
    view = await cart.updatePrice(
      7,
      first,
      d('400'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    view = await cart.addByBarcode(7, barcodeA, mv(view, 4));
    expect(view.lines, hasLength(2), reason: 'разведение по цене не работает');

    final second = view.lines.firstWhere((l) => l.id != first).id;
    view = await cart.updatePrice(
      7,
      second,
      d('400'),
      mv(view, 5),
      by: fullDiscountAuthority,
    );

    expect(view.lines, hasLength(1), reason: 'две строки 400 остались двумя');
    expect(view.lines.single.id, first, reason: 'выживает ранняя строка');
    expect(view.lines.single.quantity, d('2'));
    expect(view.total, d('800'));

    final rows = await db.saleProductDao.findBySale(
      view.receiptNo!,
      view.posId,
    );
    expect(rows, hasLength(1), reason: 'лишняя строка осталась в базе');
  });

  test('ручная скидка строки не разбавляется новыми единицами', () async {
    // Находка 3 задачи 8. Скидка хранится абсолютной суммой, и добавление
    // единиц в строку со скидкой растягивало ту же сумму на больший товар:
    // «сто со штуки» превращалось в «пятьдесят с каждой из двух». Ручная
    // **цена** от этого была защищена с круга правки 5, ручная **скидка** —
    // нет.
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.setDiscountAmount(
      7,
      view.lines.single.id,
      d('100'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    expect(view.total, d('400'));

    view = await cart.addByBarcode(7, barcodeA, mv(view, 4));

    expect(
      view.lines,
      hasLength(2),
      reason: 'новые единицы разбавили назначенную кассиром скидку',
    );
    final discounted = view.lines.firstWhere((l) => l.discount > Decimal.zero);
    expect(discounted.quantity, Decimal.one);
    expect(
      discounted.total,
      d('400'),
      reason: 'обещание «сто со штуки» размазалось на две штуки',
    );
    expect(view.total, d('900'));

    // И деньги после того, как новые единицы убрали: скидка обязана
    // остаться той же сотней, а не половиной от неё.
    final plain = view.lines.firstWhere((l) => l.discount == Decimal.zero);
    view = await cart.removeLine(7, plain.id, mv(view, 5));
    expect(view.total, d('400'));
  });

  test(
    'подарок акции стоит ровно столько, сколько показано в строке',
    () async {
      // Круг правки 1, C1. Цена 100.6, весовое округление вниз — кассир видит
      // 100. Подарок считался по **сырой** цене 100.6, и чек не складывался
      // сам с собой: три штуки по 100 минус подарок 100.6 давали 199.4 вместо
      // 200. Тот самый дефект «цены не складываются в свой же итог», который
      // задача 8 убрала из контроллера, жил здесь.
      await db
          .update(db.thisPosEntries)
          .write(
            const ThisPosEntriesCompanion(weightProductRoundType: Value(2)),
          );
      await seedProduct(
        ucode: 800,
        barcode: '4870000000008',
        price: '100.6',
        name: 'Весовой',
        measure: 1,
      );
      await db
          .into(db.promotions)
          .insert(
            PromotionsCompanion.insert(
              name: 'Три по цене двух',
              triggerUcode: 800,
              rewardUcode: 800,
              triggerQty: const Value(3),
              rewardQty: const Value(1),
            ),
          );

      var view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      view = await cart.addProduct(7, 800, d('3'), mv(view, 2));

      final line = view.lines.single;
      expect(line.price, d('100'), reason: 'округление не применилось');
      expect(
        line.discount,
        d('100'),
        reason: 'подарок посчитан по сырой цене, а не по показанной',
      );
      // Главное утверждение: итог складывается из тех же чисел, что в строке.
      expect(view.total, line.price * line.quantity - line.discount);
      expect(view.total, d('200'));
    },
  );

  test('скидка строки переживает смену количества поштучно', () async {
    // Круг правки 1, I2. Скидка 10% с 500 даёт 450; «плюс» давал 950, то
    // есть 5% — абсолютная сумма растягивалась на большее количество.
    // Ручная **цена** смену количества переживала, ручная **скидка** — нет;
    // асимметрия, ради снятия которой заведена находка 3, оставалась на
    // втором пути.
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = view.lines.single.id;
    view = await cart.setDiscountPercent(
      7,
      lineId,
      d('10'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    expect(view.total, d('450'));

    view = await cart.increment(7, lineId, mv(view, 4));
    expect(
      view.total,
      d('900'),
      reason: 'скидка размазалась: две штуки по 500 минус те же 50',
    );
    expect(view.lines.single.discount, d('100'));

    view = await cart.setQuantity(7, lineId, d('4'), mv(view, 5));
    expect(view.total, d('1800'));
    expect(view.lines.single.discount, d('200'));

    view = await cart.decrement(7, lineId, mv(view, 6));
    expect(view.total, d('1350'));
  });

  test('правка цены сливает строки в обе стороны, а не в одну', () async {
    // Круг правки 1, I1. Слияние срабатывало только когда правили цену
    // **поздней** строки. Правка цены первой строки под вторую оставляла
    // две строки одного товара с одной видимой ценой — дословно то, что
    // находка 2 называла «слить нечем».
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final first = view.lines.single.id;
    view = await cart.updatePrice(
      7,
      first,
      d('400'),
      mv(view, 3),
      by: fullDiscountAuthority,
    );
    view = await cart.addByBarcode(7, barcodeA, mv(view, 4));
    expect(view.lines, hasLength(2));

    // Правим **раннюю** строку под позднюю: 400 → 500.
    view = await cart.updatePrice(
      7,
      first,
      d('500'),
      mv(view, 5),
      by: fullDiscountAuthority,
    );

    expect(view.lines, hasLength(1), reason: 'слить нечем в эту сторону');
    expect(view.lines.single.id, first, reason: 'выживает ранняя строка');
    expect(view.lines.single.quantity, d('2'));
    expect(view.total, d('1000'));
  });

  test('удаление строки уносит модификаторы и долю гостя', () async {
    // Круг правки 1, I3. На строке чека висят три хвоста, и все привязаны к
    // её **номеру**, а не к товару: марка, модификаторы блюда и доля гостя
    // при разделении счёта. Снималась только марка. `SaleProducts.id` —
    // `autoIncrement`, но `clear` и новый набор в том же чеке номера
    // возвращают: осиротевший модификатор всплыл бы на чужом блюде вместе
    // со своей доплатой к цене.
    final groupId = await db
        .into(db.modifierGroups)
        .insert(ModifierGroupsCompanion.insert(name: 'Соус'));
    final optionId = await db
        .into(db.modifierOptions)
        .insert(
          ModifierOptionsCompanion.insert(groupId: groupId, name: 'Двойной'),
        );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = int.parse(view.lines.single.id);

    await db.modifierDao.insertSaleModifier(
      SaleProductModifiersCompanion.insert(
        saleProductId: lineId,
        modifierGroupId: groupId,
        modifierOptionId: optionId,
        priceAdjustment: const Value(50),
      ),
    );
    await db.guestSplitDao.insertForItem(1, 2, lineId, Decimal.one);

    expect(await db.modifierDao.getSelectedModifiers(lineId), hasLength(1));
    expect(await db.guestSplitDao.findBySaleProductId(lineId), hasLength(1));

    await cart.removeLine(7, '$lineId', mv(view, 3));

    expect(
      await db.modifierDao.getSelectedModifiers(lineId),
      isEmpty,
      reason: 'модификатор остался сиротой на переиспользуемом номере строки',
    );
    expect(
      await db.guestSplitDao.findBySaleProductId(lineId),
      isEmpty,
      reason: 'доля гостя осталась сиротой',
    );
  });

  test('строка с модификаторами не принимает новых единиц', () async {
    // Та же причина, что у марки: модификатор принадлежит экземпляру блюда.
    // Слияние здесь и удалило бы строку-жертву вместе с её модификаторами.
    final groupId = await db
        .into(db.modifierGroups)
        .insert(ModifierGroupsCompanion.insert(name: 'Соус'));
    final optionId = await db
        .into(db.modifierOptions)
        .insert(ModifierOptionsCompanion.insert(groupId: groupId, name: 'Без'));

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    final lineId = int.parse(view.lines.single.id);
    await db.modifierDao.insertSaleModifier(
      SaleProductModifiersCompanion.insert(
        saleProductId: lineId,
        modifierGroupId: groupId,
        modifierOptionId: optionId,
      ),
    );

    view = await cart.addByBarcode(7, barcodeA, mv(view, 3));

    expect(view.lines, hasLength(2));
    expect(
      view.lines.firstWhere((l) => l.id == '$lineId').quantity,
      Decimal.one,
      reason: 'две единицы уехали в чек с одними модификаторами',
    );
  });

  test('маркированная строка не принимает новых единиц', () async {
    // Марка принадлежит экземпляру товара, а не строке: `setMark` хранит
    // одну марку на строку. Слив две единицы маркируемого товара в одну
    // строку, касса напечатала бы чек, где обе едут под одним кодом.
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.setMark(7, view.lines.single.id, 'DM-1', mv(view, 3));

    view = await cart.addByBarcode(7, barcodeA, mv(view, 4));

    expect(view.lines, hasLength(2));
    expect(view.lines.where((l) => l.mark == 'DM-1'), hasLength(1));
    expect(
      view.lines.firstWhere((l) => l.mark == 'DM-1').quantity,
      Decimal.one,
      reason: 'две единицы уехали в чек под одной маркой',
    );
  });
}
