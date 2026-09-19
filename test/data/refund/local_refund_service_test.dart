import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Задача 18 плана «Продажа с браузерного терминала»: контракт возврата и
/// кассовая реализация.
///
/// Никаких моков: настоящая база в памяти и настоящие юзкейсы под сервисом.
/// Мок здесь доказал бы, что сервис зовёт то, что мы велели ему звать, — а
/// доказать надо другое, и брифом сказано прямо: **возврат возвращает деньги
/// и товар**, а не строку в базе. Поэтому остаток товара и остаток счёта
/// читаются до и после, а не проверяется факт записи.
void main() {
  late AppDatabase db;
  late LocalRefundService refunds;

  const posId = 1;
  const cashierId = 4;
  const cashAccountId = 77;

  Decimal d(String v) => Decimal.parse(v);

  /// Команда рабочего места, у которого **нет** черновика: `receiptNo`
  /// (номер черновика) пуст.
  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

  /// Команда, посчитанная от снимка [v]: и версия, и **номер черновика** —
  /// оттуда.
  CartCommandMeta mv(RefundView v, int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: v.version, receiptNo: v.draftNo);

  Future<void> seedProduct({
    required int ucode,
    required int barcode,
    required String price,
    String name = 'Товар',
    String stock = '100',
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: barcode,
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
            barcode: barcode,
            sellingPrice: Value(d(price)),
          ),
        );
  }

  /// Идентификатор строки возврата по товару — для чеков, где товар лежит
  /// одной строкой. Там, где строк две, тест берёт их по цене.
  String lineOf(RefundView view, int productId) =>
      view.lines.firstWhere((l) => l.productId == productId).id;

  Future<Decimal> stockOf(int ucode) async {
    final info = await db.productInfoDao.findByUcode(ucode);
    return info?.quantity ?? Decimal.zero;
  }

  Future<Decimal> balanceOf(int accountId) async {
    final account = await db.accountDao.findById(accountId);
    return account?.value ?? Decimal.zero;
  }

  /// Совершённая продажа: чек, строки, оплата и снятый остаток.
  ///
  /// Товар списывается с остатка **здесь**, как это делает настоящая
  /// продажа: иначе проверка «товар вернулся» сравнивала бы возврат с
  /// остатком, которого продажа не касалась, и прошла бы даже у сервиса,
  /// который остаток не трогает вовсе.
  Future<void> completeSale({
    required int receiptNo,
    required List<({int ucode, String quantity, String price})> lines,
    int accountId = cashAccountId,
    int? customerLocalId,
    int salePosId = posId,
  }) async {
    var amount = Decimal.zero;
    for (final line in lines) {
      amount += d(line.price) * d(line.quantity);
    }

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: salePosId,
            userId: cashierId,
            amount: amount,
            time: 1700000000,
            state: const Value(1),
            customerLocalId: Value(customerLocalId),
          ),
        );

    for (final line in lines) {
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              receiptNo: Value(receiptNo),
              posId: Value(salePosId),
              ucode: line.ucode,
              quantity: d(line.quantity),
              price: d(line.price),
              priceBefore: d(line.price),
            ),
          );
      await db.productInfoDao.adjustQuantity(line.ucode, -d(line.quantity));
    }

    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: cashierId,
            payeeAccountId: accountId,
            amount: amount,
            time: 1700000000,
            receiptNo: Value(receiptNo),
            posId: Value(salePosId),
            state: const Value(1),
          ),
        );
    await db.accountDao.updateBalance(
      accountId,
      await balanceOf(accountId) + amount,
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(posId),
            accountId: Value(cashAccountId),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(cashAccountId),
            type: 0,
            value: Value(Decimal.zero),
          ),
        );
    await db
        .into(db.users)
        .insert(
          const UsersCompanion(id: Value(cashierId), name: Value('Айгуль')),
        );
    await db
        .into(db.shifts)
        .insert(
          const ShiftsCompanion(
            userId: Value(cashierId),
            openTime: Value(1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );

    await seedProduct(ucode: 100, barcode: 4870001234567, price: '500');
    await seedProduct(
      ucode: 200,
      barcode: 4870007654321,
      price: '300',
      name: 'Второй',
    );

    final logger = Talker();

    // `RefundUseCaseImpl` достаёт `RefundProductService` из `GetIt` сам
    // (`refund_use_case_impl.dart:73`) — это не выбор теста, а сегодняшняя
    // форма продукта.
    if (GetIt.I.isRegistered<RefundProductService>()) {
      await GetIt.I.reset();
    }
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );

    refunds = LocalRefundService(
      db: db,
      logger: logger,
      initiation: RefundInitiationUseCaseImpl(db: db, logger: logger),
      refunds: RefundUseCaseImpl(
        db: db,
        logger: logger,
        fiscal: const RefusingFiscalService(),
      ),
      canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: db, logger: logger),
      drawer: () async => true,
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  // ── существо ────────────────────────────────────────────────────────────

  test(
    'возврат возвращает деньги и товар, а не только строку в базе',
    () async {
      await completeSale(
        receiptNo: 11,
        lines: [(ucode: 100, quantity: '3', price: '500')],
      );

      final stockBefore = await stockOf(100);
      final tillBefore = await balanceOf(cashAccountId);

      final loaded = await refunds.loadReceipt(7, 11, posId, m(1, 0));
      final outcome = await refunds.complete(7, mv(loaded, 2));

      expect(outcome.amount, d('1500'));
      expect(
        await stockOf(100),
        stockBefore + d('3'),
        reason: 'товар не вернулся на остаток',
      );
      expect(
        await balanceOf(cashAccountId),
        tillBefore - d('1500'),
        reason: 'деньги не ушли из кассы',
      );
    },
  );

  test('возвращается ровно то, что вернули, а не весь чек', () async {
    await completeSale(
      receiptNo: 12,
      lines: [
        (ucode: 100, quantity: '3', price: '500'),
        (ucode: 200, quantity: '2', price: '300'),
      ],
    );

    final stock100 = await stockOf(100);
    final stock200 = await stockOf(200);
    final tillBefore = await balanceOf(cashAccountId);

    var view = await refunds.loadReceipt(7, 12, posId, m(1, 0));
    // Кассир снял выделение со второй строки и уменьшил первую до одной.
    view = await refunds.setLineQuantity(
      7,
      lineOf(view, 200),
      Decimal.zero,
      mv(view, 2),
    );
    view = await refunds.setLineQuantity(
      7,
      lineOf(view, 100),
      Decimal.one,
      mv(view, 3),
    );
    final outcome = await refunds.complete(7, mv(view, 4));

    expect(outcome.amount, d('500'));
    expect(outcome.lineCount, 1);
    expect(await stockOf(100), stock100 + Decimal.one);
    expect(
      await stockOf(200),
      stock200,
      reason: 'вернулся товар, который кассир из возврата убрал',
    );
    expect(await balanceOf(cashAccountId), tillBefore - d('500'));
  });

  test('возврат без чека возвращает товар по каталожной цене', () async {
    final stockBefore = await stockOf(200);
    final tillBefore = await balanceOf(cashAccountId);

    var view = await refunds.startWithoutReceipt(7, m(1, 0));
    expect(view.byReceipt, isFalse);
    expect(view.started, isTrue);

    view = await refunds.addProduct(7, 200, d('2'), mv(view, 2));
    expect(view.total, d('600'));

    final outcome = await refunds.complete(7, mv(view, 3));

    expect(outcome.amount, d('600'));
    expect(outcome.saleReceiptNo, isNull);
    expect(await stockOf(200), stockBefore + d('2'));
    expect(await balanceOf(cashAccountId), tillBefore - d('600'));
  });

  // ── уборка черновика при смене кассира — круг правки 1 задачи 19 ───────
  //
  // Правку заказал разбор задачи 19 (C1): черновик лежит под ключом рабочего
  // места и только его, пользователя не помнит и выход переживает, — а
  // значит право `op.refundWithoutReceipt` охраняло только первое нажатие.
  // Кто и когда зовёт `abandon` — обработчик `auth.login`, проба сквозным
  // путём в `test/backend/refund_shift_change_test.dart`. Здесь проверяется
  // само поведение уборки.

  test('уборка забывает черновик — команда после неё не проходит', () async {
    var view = await refunds.startWithoutReceipt(7, m(1, 0));
    view = await refunds.addProduct(7, 200, d('2'), mv(view, 2));
    expect(view.lines, hasLength(1));

    await refunds.abandon(7);

    expect(
      () => refunds.addProduct(7, 200, d('1'), mv(view, 3)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundNotStartedCode),
      ),
    );
    expect(
      () => refunds.complete(7, mv(view, 4)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundNotStartedCode),
      ),
    );
    expect((await refunds.watch(7).first).started, isFalse);
  });

  test('уборка чистит и слот повтора завершения', () async {
    // Иначе повтор ключа завершения после пересменки отдал бы **чужой
    // исход** — ровно та беда, которую круг правки 1 задачи 18 уже ловил на
    // слоте, не чистившемся никогда.
    await completeSale(
      receiptNo: 11,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );
    var view = await refunds.loadReceipt(7, 11, posId, m(1, 0));
    final outcome = await refunds.complete(7, mv(view, 2));
    expect(outcome.amount, d('500'));

    await refunds.abandon(7);

    expect(
      () => refunds.complete(7, mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundNotStartedCode),
      ),
      reason: 'повтор старого ключа обязан получить отказ, а не чужой исход',
    );
  });

  test('уборка видна подписчику снимком, а не молчанием', () async {
    final seen = <RefundView>[];
    final sub = refunds.watch(7).listen(seen.add);
    await pumpEventQueue();

    final view = await refunds.startWithoutReceipt(7, m(1, 0));
    await pumpEventQueue();
    expect(seen.last.started, isTrue);

    await refunds.abandon(7);
    await pumpEventQueue();

    expect(
      seen.last.started,
      isFalse,
      reason:
          'экран обязан увидеть, что черновика больше нет, а не остаться при '
          'старом снимке',
    );
    expect(seen.last.draftNo, isNot(view.draftNo));
    await sub.cancel();
  });

  test('уборка на месте без черновика — не ошибка и не событие', () async {
    final seen = <RefundView>[];
    final sub = refunds.watch(7).listen(seen.add);
    await pumpEventQueue();
    final before = seen.length;

    await refunds.abandon(7);
    await refunds.abandon(7);
    await pumpEventQueue();

    expect(seen.length, before, reason: 'забывать нечего — говорить не о чем');
    await sub.cancel();
  });

  test('уборка не трогает соседнее рабочее место', () async {
    final mine = await refunds.startWithoutReceipt(7, m(1, 0));
    final theirs = await refunds.startWithoutReceipt(9, m(2, 0));

    await refunds.abandon(7);

    expect((await refunds.watch(7).first).started, isFalse);
    final still = await refunds.watch(9).first;
    expect(still.started, isTrue);
    expect(still.draftNo, theirs.draftNo);
    expect(still.draftNo, isNot(mine.draftNo));
  });

  // ── три правила изменяющей команды ──────────────────────────────────────

  test('чужой черновик командой не достать', () async {
    await completeSale(
      receiptNo: 13,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );

    final mine = await refunds.loadReceipt(7, 13, posId, m(1, 0));
    expect(mine.lines, hasLength(1));

    final neighbour = await refunds.currentView(8);
    expect(
      neighbour.started,
      isFalse,
      reason: 'черновик соседнего места показан своим',
    );
    expect(neighbour.lines, isEmpty);

    // Соседнее место не получает отказ «не тот черновик» — оно вообще не
    // видит, что черновик где-то есть: у него своего нет. Черновик за
    // общий (без владельца) этот тест и ловит.
    await expectLater(
      () => refunds.addProduct(8, 100, Decimal.one, mv(mine, 2)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundNotStartedCode),
      ),
    );
    expect((await refunds.currentView(7)).lines.single.quantity, Decimal.one);
  });

  test('повтор команды с тем же ключом не удваивает количество', () async {
    var view = await refunds.startWithoutReceipt(7, m(1, 0));
    final meta = mv(view, 2);

    view = await refunds.addProduct(7, 200, d('2'), meta);
    final repeated = await refunds.addProduct(7, 200, d('2'), meta);

    expect(repeated, view, reason: 'повтор обязан вернуть тот же снимок');
    expect(repeated.lines, hasLength(1));
    expect(repeated.lines.single.quantity, d('2'));
  });

  test(
    'две одновременные команды с одним ключом не удваивают количество',
    () async {
      final start = await refunds.startWithoutReceipt(7, m(1, 0));
      final meta = mv(start, 2);

      final both = await Future.wait([
        refunds.addProduct(7, 200, d('2'), meta),
        refunds.addProduct(7, 200, d('2'), meta),
      ]);

      for (final view in both) {
        expect(view.lines, hasLength(1));
        expect(view.lines.single.quantity, d('2'));
      }
      final now = await refunds.currentView(7);
      expect(now.lines.single.quantity, d('2'));
      expect(now.version, start.version + 1);
    },
  );

  test('из двух одновременных команд от одной версии проходит одна', () async {
    final start = await refunds.startWithoutReceipt(7, m(1, 0));

    final views = <RefundView>[];
    final refusals = <WireRefusal>[];
    Future<void> send(int productId, CartCommandMeta meta) async {
      try {
        views.add(await refunds.addProduct(7, productId, Decimal.one, meta));
      } on WireRefusal catch (refusal) {
        refusals.add(refusal);
      }
    }

    await Future.wait([send(100, mv(start, 2)), send(200, mv(start, 3))]);

    expect(views, hasLength(1), reason: 'обе команды прошли от одной версии');
    expect(refusals, hasLength(1));
    expect(refusals.single.code, refundStaleCode);

    final now = await refunds.currentView(7);
    expect(now.lines, hasLength(1));
    expect(now.version, start.version + 1);
  });

  test('команда от устаревшей версии отвергается названным отказом', () async {
    final start = await refunds.startWithoutReceipt(7, m(1, 0));
    final stale = mv(start, 2);
    await refunds.addProduct(7, 200, Decimal.one, stale);

    await expectLater(
      () => refunds.addProduct(
        7,
        100,
        Decimal.one,
        CartCommandMeta(
          key: 'k3',
          baseVersion: start.version,
          receiptNo: start.draftNo,
        ),
      ),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundStaleCode),
      ),
    );
  });

  test(
    'запоздавшая команда не ложится в черновик, начатый после неё',
    () async {
      final first = await refunds.startWithoutReceipt(7, m(1, 0));
      final late1 = mv(first, 2);

      // Кассир бросил возврат и начал новый. Страховка от вырождения пробы:
      // версия у нового черновика обязана **совпасть** с базовой версией
      // запоздавшей команды — иначе тест доказывал бы работу сверки версий,
      // а не опознания черновика (тот же приём, что в круге правки 2 задачи
      // 7).
      final second = await refunds.startWithoutReceipt(7, mv(first, 3));
      expect(second.version, late1.baseVersion);
      expect(second.draftNo, isNot(first.draftNo));

      await expectLater(
        () => refunds.addProduct(7, 100, Decimal.one, late1),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            refundWrongDraftCode,
          ),
        ),
      );
      expect((await refunds.currentView(7)).lines, isEmpty);
    },
  );

  test('команда без черновика получает «возврат не начат»', () async {
    await expectLater(
      () => refunds.addProduct(7, 100, Decimal.one, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundNotStartedCode),
      ),
    );
    await expectLater(
      () => refunds.complete(7, m(2, 0)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundNotStartedCode),
      ),
    );
  });

  test(
    'повтор завершения отдаёт тот же итог и не возвращает товар дважды',
    () async {
      await completeSale(
        receiptNo: 14,
        lines: [(ucode: 100, quantity: '2', price: '500')],
      );
      final stockBefore = await stockOf(100);

      final loaded = await refunds.loadReceipt(7, 14, posId, m(1, 0));
      final meta = mv(loaded, 2);
      final first = await refunds.complete(7, meta);
      final again = await refunds.complete(7, meta);

      expect(again, first);
      expect(
        await stockOf(100),
        stockBefore + d('2'),
        reason: 'повтор завершения вернул товар второй раз',
      );
    },
  );

  // ── работа с чеком ──────────────────────────────────────────────────────

  test('чека нет — названный отказ, а не пустой черновик', () async {
    await expectLater(
      () => refunds.loadReceipt(7, 999, posId, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundReceiptNotFoundCode,
        ),
      ),
    );
    expect((await refunds.currentView(7)).started, isFalse);
  });

  test('по возвращённому чеку второй возврат не заводится', () async {
    await completeSale(
      receiptNo: 15,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );

    final loaded = await refunds.loadReceipt(7, 15, posId, m(1, 0));
    await refunds.complete(7, mv(loaded, 2));

    await expectLater(
      () => refunds.loadReceipt(7, 15, posId, m(3, 0)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundAlreadyRefundedCode,
        ),
      ),
    );
  });

  test(
    'строки одного товара с разной ценой не сводятся, и цена не усредняется',
    () async {
      // Корзина разводит один товар по строкам, когда цены разные
      // (опт, ручная цена) — задача 7, круг правки 5.
      await completeSale(
        receiptNo: 16,
        lines: [
          (ucode: 100, quantity: '3', price: '100'),
          (ucode: 100, quantity: '1', price: '90'),
        ],
      );
      final stockBefore = await stockOf(100);

      final view = await refunds.loadReceipt(7, 16, posId, m(1, 0));
      expect(view.lines, hasLength(2));
      expect(
        view.lines.map((l) => l.price),
        containsAll(<Decimal>[d('100'), d('90')]),
        reason: 'цена усреднена — ни одна проданная единица столько не стоила',
      );
      expect(view.total, d('390'));

      // Возвращают одну штуку из тех, что проданы по сотне.
      final expensive = view.lines.firstWhere((l) => l.price == d('100'));
      final cheap = view.lines.firstWhere((l) => l.price == d('90'));
      var next = await refunds.setLineQuantity(
        7,
        cheap.id,
        Decimal.zero,
        mv(view, 2),
      );
      next = await refunds.setLineQuantity(
        7,
        expensive.id,
        Decimal.one,
        mv(next, 3),
      );

      final tillBefore = await balanceOf(cashAccountId);
      final outcome = await refunds.complete(7, mv(next, 4));

      expect(outcome.amount, d('100'), reason: 'заплачена средняя цена');
      expect(await balanceOf(cashAccountId), tillBefore - d('100'));
      expect(await stockOf(100), stockBefore + Decimal.one);

      // «Как продано» — числа этой строки чека, а не выдуманные: они уезжают
      // в фискальный документ возврата.
      final written = await db.refundDao.findProductsByRefund(
        outcome.refundLocalId,
      );
      expect(written, hasLength(1));
      expect(written.single.price, d('100'));
      expect(written.single.inSalePrice, d('100'));
      expect(written.single.inSaleQuantity, d('3'));
    },
  );

  test('строки одного товара с одной ценой сводятся в одну', () async {
    await completeSale(
      receiptNo: 28,
      lines: [
        (ucode: 100, quantity: '2', price: '100'),
        (ucode: 100, quantity: '1', price: '100'),
      ],
    );

    final view = await refunds.loadReceipt(7, 28, posId, m(1, 0));
    expect(view.lines, hasLength(1));
    expect(view.lines.single.quantity, d('3'));
    expect(view.lines.single.price, d('100'));
    expect(view.total, d('300'));
  });

  test('в возврат по чеку кладут только то, что в чеке было', () async {
    await completeSale(
      receiptNo: 17,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );

    final view = await refunds.loadReceipt(7, 17, posId, m(1, 0));
    await expectLater(
      () => refunds.addProduct(7, 200, Decimal.one, mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundLineNotInReceiptCode,
        ),
      ),
    );
  });

  test('больше проданного по чеку не возвращают', () async {
    await completeSale(
      receiptNo: 18,
      lines: [(ucode: 100, quantity: '2', price: '500')],
    );

    final view = await refunds.loadReceipt(7, 18, posId, m(1, 0));
    await expectLater(
      () => refunds.setLineQuantity(7, lineOf(view, 100), d('3'), mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundInvalidAmountCode,
        ),
      ),
    );
  });

  test(
    'снятая строка возвращается в возврат, а не пропадает навсегда',
    () async {
      await completeSale(
        receiptNo: 19,
        lines: [
          (ucode: 100, quantity: '2', price: '500'),
          (ucode: 200, quantity: '1', price: '300'),
        ],
      );

      var view = await refunds.loadReceipt(7, 19, posId, m(1, 0));
      final second = lineOf(view, 200);
      view = await refunds.setLineQuantity(
        7,
        second,
        Decimal.zero,
        mv(view, 2),
      );
      expect(view.lines, hasLength(1));

      view = await refunds.setLineQuantity(7, second, Decimal.one, mv(view, 3));
      expect(view.lines, hasLength(2));
      expect(view.total, d('1300'));
    },
  );

  test('пустой возврат не завершается', () async {
    await completeSale(
      receiptNo: 20,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );

    var view = await refunds.loadReceipt(7, 20, posId, m(1, 0));
    view = await refunds.setLineQuantity(
      7,
      lineOf(view, 100),
      Decimal.zero,
      mv(view, 2),
    );

    await expectLater(
      () => refunds.complete(7, mv(view, 3)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundEmptyCode),
      ),
    );
  });

  test('товара без цены нельзя вернуть без чека', () async {
    await seedProduct(
      ucode: 300,
      barcode: 4870009999999,
      price: '0',
      name: 'Без цены',
    );

    final view = await refunds.startWithoutReceipt(7, m(1, 0));
    await expectLater(
      () => refunds.addProduct(7, 300, Decimal.one, mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundInvalidAmountCode,
        ),
      ),
    );
  });

  test('товара нет в каталоге — названный отказ', () async {
    final view = await refunds.startWithoutReceipt(7, m(1, 0));
    await expectLater(
      () => refunds.addProduct(7, 999, Decimal.one, mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundProductNotFoundCode,
        ),
      ),
    );
  });

  test('отрицательное количество отвергается названным отказом', () async {
    final view = await refunds.startWithoutReceipt(7, m(1, 0));
    await expectLater(
      () => refunds.addProduct(7, 100, d('-1'), mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundInvalidAmountCode,
        ),
      ),
    );
  });

  test('чек, оплаченный чужим эквайрингом, не возвращается здесь', () async {
    // `ThisPos.acquiringAccountId` у этой кассы пуст, а платёж прошёл через
    // счёт с эквайрингом — `CanSaleBeRefundedUseCase` этот случай и знает.
    const foreignAcquiring = 88;
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(foreignAcquiring),
            type: 0,
            acquirerId: const Value(5),
            value: Value(Decimal.zero),
          ),
        );
    await completeSale(
      receiptNo: 23,
      lines: [(ucode: 100, quantity: '1', price: '500')],
      accountId: foreignAcquiring,
    );

    await expectLater(
      () => refunds.loadReceipt(7, 23, posId, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundNotRefundableCode,
        ),
      ),
    );
  });

  test('чек без строк не превращается в пустой возврат', () async {
    await completeSale(receiptNo: 24, lines: const []);

    await expectLater(
      () => refunds.loadReceipt(7, 24, posId, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundEmptyCode),
      ),
    );
  });

  test('в возврате без чека строка снимается тем же нулём', () async {
    var view = await refunds.startWithoutReceipt(7, m(1, 0));
    view = await refunds.addProduct(7, 200, d('2'), mv(view, 2));
    expect(view.lines, hasLength(1));

    view = await refunds.setLineQuantity(
      7,
      lineOf(view, 200),
      Decimal.zero,
      mv(view, 3),
    );
    expect(view.lines, isEmpty);
    expect(view.total, Decimal.zero);
  });

  test(
    'завершение от устаревшей версии отвергается названным отказом',
    () async {
      await completeSale(
        receiptNo: 25,
        lines: [(ucode: 100, quantity: '2', price: '500')],
      );
      final stockBefore = await stockOf(100);

      final loaded = await refunds.loadReceipt(7, 25, posId, m(1, 0));
      final staleMeta = mv(loaded, 2);
      await refunds.setLineQuantity(
        7,
        lineOf(loaded, 100),
        Decimal.one,
        staleMeta,
      );

      await expectLater(
        () => refunds.complete(
          7,
          CartCommandMeta(
            key: 'k3',
            baseVersion: loaded.version,
            receiptNo: loaded.draftNo,
          ),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', refundStaleCode),
        ),
      );
      expect(
        await stockOf(100),
        stockBefore,
        reason: 'товар вернулся по отказу',
      );
    },
  );

  test('чек, исчезнувший между загрузкой и завершением, отказывает', () async {
    await completeSale(
      receiptNo: 26,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );

    final loaded = await refunds.loadReceipt(7, 26, posId, m(1, 0));
    await (db.delete(db.sales)..where((s) => s.receiptNo.equals(26))).go();

    await expectLater(
      () => refunds.complete(7, mv(loaded, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundReceiptNotFoundCode,
        ),
      ),
    );
  });

  test(
    'возврат, заведённый соседом между загрузкой и завершением, отказывает',
    () async {
      await completeSale(
        receiptNo: 27,
        lines: [(ucode: 100, quantity: '1', price: '500')],
      );
      final stockBefore = await stockOf(100);

      final loaded = await refunds.loadReceipt(7, 27, posId, m(1, 0));
      // Тот же чек вернули помимо этого черновика: у `Refunds` уникальность
      // по паре чека, и вторая строка не записалась бы вовсе — терминал
      // получил бы нарушение ограничения базы вместо причины.
      await db
          .into(db.refunds)
          .insert(
            RefundsCompanion.insert(
              userId: cashierId,
              time: 1700000100,
              state: const Value(1),
              saleReceiptNo: const Value(27),
              salePosId: const Value(posId),
            ),
          );

      await expectLater(
        () => refunds.complete(7, mv(loaded, 2)),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            refundAlreadyRefundedCode,
          ),
        ),
      );
      expect(await stockOf(100), stockBefore);
    },
  );

  // ── круг правки 1: совершён ли чек ──────────────────────────────────────

  /// Меняет состояние чека, минуя сервис, — как это делают откладывание,
  /// подъём отложенного и слияние при обмене.
  Future<void> setSaleState(int receiptNo, int state) async {
    await (db.update(db.sales)..where((s) => s.receiptNo.equals(receiptNo)))
        .write(SalesCompanion(state: Value(state)));
  }

  test('чек в работе не возвращается — это чужая живая корзина', () async {
    // Состояние 0 — корзина рабочего места: с задачи 7 она лежит в тех же
    // `Sales`/`SaleProducts` с первой команды.
    await completeSale(
      receiptNo: 30,
      lines: [(ucode: 100, quantity: '2', price: '500')],
    );
    await setSaleState(30, 0);
    final stockBefore = await stockOf(100);
    final tillBefore = await balanceOf(cashAccountId);

    await expectLater(
      () => refunds.loadReceipt(7, 30, posId, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundSaleNotCompletedCode,
        ),
      ),
    );
    expect(await stockOf(100), stockBefore);
    expect(await balanceOf(cashAccountId), tillBefore);
  });

  test('отложенный чек не возвращается', () async {
    await completeSale(
      receiptNo: 31,
      lines: [(ucode: 100, quantity: '2', price: '500')],
    );
    await setSaleState(31, 3);
    final tillBefore = await balanceOf(cashAccountId);

    await expectLater(
      () => refunds.loadReceipt(7, 31, posId, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundSaleNotCompletedCode,
        ),
      ),
    );
    expect(await balanceOf(cashAccountId), tillBefore);
  });

  test('чек без состояния не возвращается', () async {
    await completeSale(
      receiptNo: 32,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );
    await (db.update(db.sales)..where((s) => s.receiptNo.equals(32))).write(
      const SalesCompanion(state: Value(null)),
    );

    await expectLater(
      () => refunds.loadReceipt(7, 32, posId, m(1, 0)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundSaleNotCompletedCode,
        ),
      ),
    );
  });

  test(
    'чек, ушедший в работу между загрузкой и завершением, отказывает',
    () async {
      await completeSale(
        receiptNo: 33,
        lines: [(ucode: 100, quantity: '2', price: '500')],
      );
      final stockBefore = await stockOf(100);
      final tillBefore = await balanceOf(cashAccountId);

      final loaded = await refunds.loadReceipt(7, 33, posId, m(1, 0));
      await setSaleState(33, 0);

      await expectLater(
        () => refunds.complete(7, mv(loaded, 2)),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            refundSaleNotCompletedCode,
          ),
        ),
      );
      expect(await stockOf(100), stockBefore);
      expect(await balanceOf(cashAccountId), tillBefore);
    },
  );

  // ── круг правки 1: слот повтора и сырое исключение ──────────────────────

  test('повтор ключа после нового черновика не подделывает исход', () async {
    await completeSale(
      receiptNo: 34,
      lines: [(ucode: 100, quantity: '1', price: '300')],
    );
    await completeSale(
      receiptNo: 35,
      lines: [(ucode: 100, quantity: '5', price: '300')],
    );

    final first = await refunds.loadReceipt(7, 34, posId, m(1, 0));
    final oldKey = mv(first, 2);
    final firstOutcome = await refunds.complete(7, oldKey);
    expect(firstOutcome.amount, d('300'));

    final second = await refunds.loadReceipt(7, 35, posId, m(3, 0));
    final stockBefore = await stockOf(100);

    // Тот же ключ, что у уже завершённого возврата. Раньше он возвращал
    // **старый исход** — терминал получал успех с чужой суммой, новый
    // возврат не выполнялся, черновик оставался на месте.
    await expectLater(
      () => refunds.complete(7, oldKey),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', refundWrongDraftCode),
      ),
    );
    expect(await stockOf(100), stockBefore);
    expect((await refunds.currentView(7)).draftNo, second.draftNo);
  });

  test('две незавершённые строки возврата дают отказ значением', () async {
    await completeSale(
      receiptNo: 36,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );
    final loaded = await refunds.loadReceipt(7, 36, posId, m(1, 0));

    // Экранный путь возврата зовёт `RefundInitiationUseCase` мимо очереди
    // этого сервиса — две строки состояния 0 достижимы, и `findWithState`
    // (`getSingleOrNull`) на них падает `StateError`.
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.refunds)
          .insert(
            RefundsCompanion.insert(
              userId: cashierId,
              time: 1700000200 + i,
              state: const Value(0),
            ),
          );
    }

    await expectLater(
      () => refunds.complete(7, mv(loaded, 2)),
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', refundBusyCode)),
    );
  });

  // ── круг правки 2: нулевой чек ──────────────────────────────────────────

  test(
    'чек, роздан целиком по акции, возвращается — товар едет на склад',
    () async {
      // Стопроцентная скидка или подарок акцией: чек стоит ноль, но товар
      // покупатель принёс обратно, и на складе он обязан появиться.
      // `RefundUseCaseImpl._validateRefund` этот случай оговаривает
      // (`isTotalDiscountSale`), экранный путь его проводит.
      await completeSale(
        receiptNo: 40,
        lines: [(ucode: 100, quantity: '1', price: '0')],
      );
      final stockBefore = await stockOf(100);
      final tillBefore = await balanceOf(cashAccountId);

      final view = await refunds.loadReceipt(7, 40, posId, m(1, 0));
      expect(view.total, Decimal.zero);

      final outcome = await refunds.complete(7, mv(view, 2));

      expect(outcome.amount, Decimal.zero);
      expect(outcome.lineCount, 1);
      expect(
        await stockOf(100),
        stockBefore + Decimal.one,
        reason: 'товар не вернулся на склад — возврат нулевого чека отвергнут',
      );
      expect(
        await balanceOf(cashAccountId),
        tillBefore,
        reason: 'из кассы ушли деньги за бесплатный товар',
      );
    },
  );

  test('из платного чека возвращают только его подарочную строку', () async {
    // Граница послабления: `_validateRefund` считает `isTotalDiscountSale`
    // по **возвращаемым строкам**, а не по всему чеку, — значит подарок из
    // платного чека возвращается отдельно, и это законно. Тест закрепляет
    // именно это, а не выдуманное «весь чек обязан быть нулевым»:
    // измерено, что экранный путь ведёт себя так же.
    await completeSale(
      receiptNo: 41,
      lines: [
        (ucode: 100, quantity: '1', price: '0'),
        (ucode: 200, quantity: '1', price: '300'),
      ],
    );
    final gift = await stockOf(100);
    final paid = await stockOf(200);
    final tillBefore = await balanceOf(cashAccountId);

    var view = await refunds.loadReceipt(7, 41, posId, m(1, 0));
    view = await refunds.setLineQuantity(
      7,
      lineOf(view, 200),
      Decimal.zero,
      mv(view, 2),
    );

    final outcome = await refunds.complete(7, mv(view, 3));

    expect(outcome.amount, Decimal.zero);
    expect(await stockOf(100), gift + Decimal.one);
    expect(
      await stockOf(200),
      paid,
      reason: 'вернулся платный товар, который кассир из возврата убрал',
    );
    expect(await balanceOf(cashAccountId), tillBefore);
  });

  test('нулевой возврат без чека по-прежнему отвергается', () async {
    // Послабление именно **по чеку**: без чека нулевая цена значит
    // «товар без цены», и это отдельный отказ.
    await seedProduct(
      ucode: 400,
      barcode: 4870004444444,
      price: '0',
      name: 'Без цены',
    );
    final view = await refunds.startWithoutReceipt(7, m(1, 0));

    await expectLater(
      () => refunds.addProduct(7, 400, Decimal.one, mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundInvalidAmountCode,
        ),
      ),
    );
  });

  test('нулём в addProduct строка возврата без чека тоже снимается', () async {
    var view = await refunds.startWithoutReceipt(7, m(1, 0));
    view = await refunds.addProduct(7, 200, d('2'), mv(view, 2));
    expect(view.lines, hasLength(1));

    // Тот же ноль, что у `setLineQuantity`: терминал вправе снять строку
    // тем вызовом, которым он её положил.
    view = await refunds.addProduct(7, 200, Decimal.zero, mv(view, 3));
    expect(view.lines, isEmpty);
  });

  test('строку возврата без чека нельзя набрать по чужому имени', () async {
    await completeSale(
      receiptNo: 37,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );
    final view = await refunds.loadReceipt(7, 37, posId, m(1, 0));

    await expectLater(
      () => refunds.setLineQuantity(7, 'p100', Decimal.one, mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundLineNotFoundCode,
        ),
      ),
    );
  });

  // ── смена и касса ───────────────────────────────────────────────────────

  test('без открытой смены возврат не оформляется', () async {
    await completeSale(
      receiptNo: 21,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );
    final stockBefore = await stockOf(100);

    final view = await refunds.loadReceipt(7, 21, posId, m(1, 0));
    await (db.update(db.shifts)..where((s) => s.userId.equals(cashierId)))
        .write(const ShiftsCompanion(isOpened: Value(false)));

    await expectLater(
      () => refunds.complete(7, mv(view, 2)),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', 'shift_not_open'),
      ),
    );
    expect(
      await stockOf(100),
      stockBefore,
      reason: 'товар вернулся, хотя возврат отказал',
    );
  });

  test(
    'ненастроенная касса отвечает отказом значением, а не броском',
    () async {
      await db.delete(db.thisPosEntries).go();

      await expectLater(
        () => refunds.startWithoutReceipt(7, m(1, 0)),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            'till_not_configured',
          ),
        ),
      );
      await expectLater(
        refunds.watch(7).first,
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

  // ── подписка ────────────────────────────────────────────────────────────

  test(
    'подписка отдаёт пустой снимок сразу, а не ждёт первого возврата',
    () async {
      final first = await refunds.watch(7).first;
      expect(first.started, isFalse);
      expect(first.version, 0);
      expect(first.posId, posId);
      expect(first.terminalId, 7);
    },
  );

  test('подписка приносит черновик после команды', () async {
    final seen = <RefundView>[];
    final subscription = refunds.watch(7).listen(seen.add);
    await pumpEventQueue();

    final view = await refunds.startWithoutReceipt(7, m(1, 0));
    await refunds.addProduct(7, 200, d('2'), mv(view, 2));
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.first.started, isFalse);
    expect(seen.last.lines.single.quantity, d('2'));
    expect(seen.map((v) => v.version), isNot(contains(-1)));
  });

  test('после завершения подписка показывает пустой черновик', () async {
    await completeSale(
      receiptNo: 22,
      lines: [(ucode: 100, quantity: '1', price: '500')],
    );

    final seen = <RefundView>[];
    final subscription = refunds.watch(7).listen(seen.add);
    await pumpEventQueue();

    final view = await refunds.loadReceipt(7, 22, posId, m(1, 0));
    await refunds.complete(7, mv(view, 2));
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.last.started, isFalse);
    expect(seen.last.lines, isEmpty);
  });

  // ── равенство по значению ───────────────────────────────────────────────

  test('снимки сравниваются по значению, а не по ссылке', () async {
    final a = await refunds.currentView(7);
    final b = await refunds.currentView(7);
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    final started = await refunds.startWithoutReceipt(7, m(1, 0));
    expect(started, isNot(a));

    const key1 = ReceiptKey(
      receiptNo: 11,
      posId: 1,
      meta: CartCommandMeta(key: 'k', baseVersion: 0, receiptNo: null),
    );
    const key2 = ReceiptKey(
      receiptNo: 11,
      posId: 1,
      meta: CartCommandMeta(key: 'k', baseVersion: 0, receiptNo: null),
    );
    expect(key1, key2);
    expect(key1.hashCode, key2.hashCode);
    expect(
      key1,
      isNot(
        ReceiptKey(
          receiptNo: 12,
          posId: 1,
          meta: const CartCommandMeta(
            key: 'k',
            baseVersion: 0,
            receiptNo: null,
          ),
        ),
      ),
    );

    final line1 = RefundLineRequest(
      productId: 100,
      quantity: d('2'),
      meta: m(1, 0),
    );
    final line2 = RefundLineRequest(
      productId: 100,
      quantity: d('2'),
      meta: m(1, 0),
    );
    expect(line1, line2);
    expect(line1.hashCode, line2.hashCode);
    expect(
      line1,
      isNot(RefundLineRequest(productId: 100, quantity: d('3'), meta: m(1, 0))),
    );

    final outcome1 = RefundOutcome(
      refundLocalId: 1,
      amount: d('500'),
      lineCount: 1,
      paymentCount: 1,
      saleReceiptNo: 11,
      salePosId: 1,
    );
    final outcome2 = RefundOutcome(
      refundLocalId: 1,
      amount: d('500'),
      lineCount: 1,
      paymentCount: 1,
      saleReceiptNo: 11,
      salePosId: 1,
    );
    expect(outcome1, outcome2);
    expect(outcome1.hashCode, outcome2.hashCode);
    expect(
      outcome1,
      isNot(
        RefundOutcome(
          refundLocalId: 1,
          amount: d('400'),
          lineCount: 1,
          paymentCount: 1,
          saleReceiptNo: 11,
          salePosId: 1,
        ),
      ),
    );
  });
}
