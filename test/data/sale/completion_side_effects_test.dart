import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart'
    show FiscalQueueStatus;
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/stock/local_stock_changes.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/wire/pay_ops.dart';

/// Фискализация, печать и денежный ящик по команде терминала — задача 16.
///
/// # Что здесь доказывается
///
/// Решение заказчика №1: терминал продаёт полностью, но **железо и база
/// остаются кассой**. Значит три действия завершения оплаты — фискальный
/// чек, печать и ящик — исполняет `LocalPaymentService`, а не экран: у
/// вкладки браузера нет ни принтера, ни ящика, ни базы, и до этой задачи
/// печать с ящиком жили в `payment_screen.dart`, то есть на терминале.
///
/// # Правило, которое здесь главное
///
/// «Оплата не ждёт железа»: печать **отправляется, а не ожидается**.
/// Отсутствующий `/dev/usb/lp*` стоил когда-то ~2,8 с уже после того, как
/// деньги взяты; по проводу к этой задержке прибавилась бы ещё и сеть.
/// Проба на время имеет силу только вместе с доказательством, что
/// подставной принтер **действительно висит** — иначе она зеленеет сама
/// собой (см. `_HangingPrinter.started`/`finished`).
///
/// # Настоящее всё, кроме железа и фискального оператора
///
/// База, корзина, подготовка чека и `SaleUseCaseImpl` — настоящие: доказать
/// надо не «сервис позвал то, что ему велели», а что деньги легли в базу и
/// остались там, когда принтер или оператор отказали.
/// Комментарии и строки документации — вон.
///
/// Разбор, почему это не послабление, — у круга правки 2 в пробе «узел
/// оплаты в интерфейсе не знает ни принтера, ни ящика, ни ОФД».
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late LocalPaymentService payments;

  /// Счётчик ревизии остатков кассы — пункт 12 ревизии 2026-09-19.
  /// Настоящий, а не подделка: у него нет ни одного состояния, которое
  /// стоило бы подменять, а подделка проверяла бы «позвали ли метод», а не
  /// «изменился ли номер, который увидят рабочие места».
  late LocalStockChanges stockChanges;
  late _FakeFiscalService fiscal;
  late _HangingPrinter printer;
  late _RecordingDrawer drawer;
  late _CapturingObserver observed;
  late Talker logger;
  late List<String> sequence;

  const barcodeA = '4870001234567';
  const barcodeC = '4870003333333';
  const barcodeD = '4870004444444';

  const posAccountId = 11;
  const bankAccountId = 12;
  const cashbackAccountId = 13;
  const agentMainAccountId = 14;
  const customerId = 5;

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

  /// Покупатель лояльности: бонусный счёт для списания, расчётный — для
  /// долга. Имя с казахскими буквами — оно печатается строкой «Клиент:».
  Future<void> seedCustomer({String bonus = '0'}) async {
    await seedAccount(
      cashbackAccountId,
      AccountType.agentCashback,
      value: bonus,
    );
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
  }

  /// Чек на 1000: две штуки товара «Кофе» по 500.
  Future<CartView> receipt({int terminalId = 7}) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(terminalId, barcodeA, mv(view, 2));
    view = await cart.setQuantity(
      terminalId,
      view.lines.single.id,
      d('2'),
      mv(view, 3),
    );
    return view;
  }

  PaymentRequest cashFor(String received) =>
      PaymentRequest(type: PaymentType.cash, cashReceived: d(received));

  Future<Sale> saleRow(int receiptNo) async =>
      (await db.saleDao.findByKey(receiptNo, 1))!;

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
    // Имя с казахскими буквами и кавычками: чек собирает касса, и то, что
    // она печатает, обязано дойти до бумаги буквой в букву.
    await seedProduct(
      ucode: 100,
      barcode: barcodeA,
      price: '500',
      name: 'Кофе «Дүкен» №2',
    );
    // Две копейные цены — для пробы про `double` (группа «деньги»).
    await seedProduct(ucode: 300, barcode: barcodeC, price: '0.1');
    await seedProduct(ucode: 400, barcode: barcodeD, price: '0.2');
    await seedAccount(posAccountId, AccountType.pos);
    await seedAccount(bankAccountId, AccountType.customBank);

    observed = _CapturingObserver();
    logger = Talker(observer: observed);
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
    sequence = [];
    fiscal = _FakeFiscalService(db, sequence);
    printer = _HangingPrinter(sequence);
    printer.watcher = fiscal;
    drawer = _RecordingDrawer();
    stockChanges = LocalStockChanges();
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: fiscal,
      fiscalQueue: DriftFiscalQueueStore(db),
      printer: printer,
      drawer: drawer.open,
      stockChanges: stockChanges,
    );
  });

  tearDown(() async {
    // Отправленное надо доиграть **до** закрытия базы: печать уходит
    // `unawaited`, и оборванная на середине сборка чека уронила бы
    // следующую пробу чужим `Bad state: database closed`.
    printer.release();
    await payments.pendingSideEffects;
    await db.close();
  });

  /// Дождаться условия — не дольше [cap].
  ///
  /// Нужно ровно затем, чтобы доказать, что принтер **вошёл** в работу и
  /// из неё не вышел: сборка чека уходит за границу `complete` вместе с
  /// печатью, и в момент возврата кассиру в принтер ещё не постучались.
  Future<bool> until(
    bool Function() done, {
    Duration cap = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(cap);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return done();
  }

  /// «Остатки изменились» уходит отсюда — пункт 12 ревизии 2026-09-19.
  ///
  /// # Почему именно здесь
  ///
  /// Завершение продажи с **любого** рабочего места проходит через эту
  /// службу — кассир за кассой, кассир за планшетом. Прежний счётчик
  /// поднимал только свой контейнер (`refreshAfterSaleCompleted`), и
  /// соседний экран о проданном товаре не узнавал ничем.
  ///
  /// # Чего эти пробы НЕ доказывают
  ///
  /// Что сообщение доедет до вкладки — это `wt_stock_changes_test.dart`. И
  /// что остаток к этому моменту уже списан: за это отвечает `SaleUseCase`,
  /// который отработал до этой строки.
  group('остатки изменились — сказано один раз на проведённую продажу', () {
    test('успешная оплата поднимает ревизию', () async {
      final view = await receipt();
      expect(
        stockChanges.revision,
        0,
        reason: 'предпосылка: ноль отличим от единицы',
      );

      await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(stockChanges.revision, 1);
    });

    test('повтор той же команды второй раз не поднимает', () async {
      // Повтор ничего не двигал (задача 16, `_outcomeOf(repeat: true)`), и
      // второе «остатки изменились» заставило бы каждое рабочее место
      // перечитать себя впустую — а в магазине с тремя экранами это три
      // лишних выборки на каждый обрыв провода.
      final view = await receipt();
      final meta = mv(view, 9);

      final first = await payments.complete(7, cashFor('1000'), meta);
      final second = await payments.complete(7, cashFor('1000'), meta);

      expect(first.repeat, isFalse);
      expect(second.repeat, isTrue, reason: 'предпосылка: это повтор');
      expect(stockChanges.revision, 1);
    });

    test('отказ оплаты ревизию не поднимает', () async {
      // Управляющая проба: «починка», поднимающая счётчик на входе в
      // `complete`, прошла бы обе предыдущие. Остаток не двигался —
      // говорить не о чем, а сказанное зря учит не верить сообщению.
      final view = await receipt();

      await expectLater(
        payments.complete(7, cashFor('1'), mv(view, 9)),
        throwsA(isA<Object>()),
      );

      expect(stockChanges.revision, 0);
    });
  });

  group('печать отправляется, а не ожидается', () {
    test('оплата возвращается кассиру, не дожидаясь принтера', () async {
      final view = await receipt();
      printer.hangFor(const Duration(seconds: 5));

      final started = DateTime.now();
      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));
      final elapsed = DateTime.now().difference(started);

      // `isNotNull` на ненулимом `int` не проверяет ничего — сверяем с
      // чеком, который набирали (круг правки 1).
      expect(outcome.receiptNo, view.receiptNo);
      expect(outcome.paid, d('1000'));
      expect(elapsed.inMilliseconds, lessThan(500));

      // **Доказательство, что принтер висит.** Без него проба зеленеет
      // сама собой: подставной принтер, который на самом деле отвечает
      // мгновенно, уложится в 500 мс при любой реализации, в том числе
      // при ожидающей. Здесь видно, что в принтер вошли и из него **не
      // вышли** — то есть 500 мс измерены против настоящего
      // пятисекундного ожидания, а не против мгновенного ответа.
      expect(await until(() => printer.started), isTrue, reason: 'вошли');
      expect(printer.finished, isFalse, reason: 'и всё ещё висим');
      expect(
        DateTime.now().difference(started).inSeconds,
        lessThan(5),
        reason: 'ожидание принтера ещё идёт — пять секунд не прошли',
      );
    });

    test(
      'печать всё-таки происходит — «не ожидается» это не «не бывает»',
      () async {
        final view = await receipt();

        final outcome = await payments.complete(
          7,
          cashFor('1000'),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        expect(printer.receipts, hasLength(1));
        final data = printer.receipts.single;
        expect(data.receiptNo, outcome.receiptNo);
        expect(data.posId, 1);
        expect(data.totalAmount, d('1000'));
        expect(data.change, d('0'));
        expect(data.posName, 'Касса 1');
        expect(data.cashierName, 'Айгуль');
        // Строки чека собраны кассой из своей базы, а не из состояния
        // вкладки: у браузерного терминала состояния экрана кассе не видно.
        expect(data.products.single.name, 'Кофе «Дүкен» №2');
        expect(data.products.single.quantity, d('2'));
        expect(data.products.single.total, d('1000'));
        expect(data.payments.single.isCash, isTrue);
        expect(data.payments.single.amount, d('1000'));
      },
    );

    test('сдача попадает в напечатанный чек', () async {
      final view = await receipt();

      await payments.complete(7, cashFor('5000'), mv(view, 9));
      await payments.pendingSideEffects;

      expect(printer.receipts.single.change, d('4000'));
    });
  });

  group('чек собирается из базы кассы', () {
    /// Правило нуля наоборот: в базе есть то, чего в чеке быть **не
    /// должно**. Проба на пустой базе доказала бы только, что сборка не
    /// падает.
    test('чужие строки и чужие платежи в чек не попадают', () async {
      // Соседний чек другого рабочего места — оплачен, со своими
      // строками и своим платежом.
      final other = await receipt(terminalId: 8);
      await payments.complete(8, cashFor('1000'), mv(other, 20));
      await payments.pendingSideEffects;
      printer.receipts.clear();

      final mine = await receipt();
      await payments.complete(7, cashFor('1000'), mv(mine, 9));
      await payments.pendingSideEffects;

      expect(mine.receiptNo, isNot(other.receiptNo));
      final data = printer.receipts.single;
      expect(data.receiptNo, mine.receiptNo);
      expect(data.products, hasLength(1));
      expect(data.payments, hasLength(1));
      expect(data.totalAmount, d('1000'));
    });
  });

  group('исход фискализации доезжает до терминала', () {
    /// Касса и вкладка — разные процессы: исход, не переживший кодек,
    /// терминалу не виден вовсе, а значит «приходит значением» было бы
    /// неправдой.
    test('состояние, признак и причина переживают провод', () {
      SaleOutcome round(SaleFiscalization fiscal) => saleOutcomeFromWireJson(
        saleOutcomeToWireJson(
          SaleOutcome(
            receiptNo: 9,
            posId: 1,
            amount: d('1000'),
            change: Decimal.zero,
            paid: d('1000'),
            debt: Decimal.zero,
            fiscal: fiscal,
          ),
        ),
      );

      final done = round(
        const SaleFiscalization(FiscalState.done, sign: 'ФП-777'),
      );
      expect(done.fiscal.state, FiscalState.done);
      expect(done.fiscal.sign, 'ФП-777');

      final failed = round(
        const SaleFiscalization(FiscalState.failed, message: 'ОФД недоступен'),
      );
      expect(failed.fiscal.state, FiscalState.failed);
      expect(failed.fiscal.message, 'ОФД недоступен');

      expect(
        round(SaleFiscalization.unchanged).fiscal.state,
        FiscalState.unchanged,
      );
      expect(
        round(SaleFiscalization.notRequired).fiscal.state,
        FiscalState.notRequired,
      );
    });

    /// Провод сверяет **по имени члена**, а не по его номеру
    /// (`pay_ops.dart`: `for (final state in FiscalState.values) if
    /// (state.name == name)`). Значит новые члены — задача 5 вставила два
    /// в **середину** перечисления — едут сами, без правки провода.
    ///
    /// Сторож перебирает `FiscalState.values`, а не список слов: список
    /// пришлось бы дописывать руками, и первый же забытый член поехал бы
    /// молча. Здесь новый член ломает пробу до релиза.
    test('каждое состояние переживает провод — включая ещё не написанные', () {
      for (final state in FiscalState.values) {
        final back = saleOutcomeFromWireJson(
          saleOutcomeToWireJson(
            SaleOutcome(
              receiptNo: 9,
              posId: 1,
              amount: d('1000'),
              change: Decimal.zero,
              paid: d('1000'),
              debt: Decimal.zero,
              fiscal: SaleFiscalization(state),
            ),
          ),
        );
        expect(
          back.fiscal.state,
          state,
          reason: '${state.name} не пережил провод',
        );
      }
    });

    /// Три «документа нет» различимы **на терминале**, а не только на
    /// кассе: до задачи 5 они приезжали одним словом, и вкладка не могла
    /// отличить сломанную сборку от ненастроенного оператора.
    test('три причины «документа нет» приезжают разными словами', () {
      String word(FiscalState s) =>
          saleOutcomeToWireJson(
                SaleOutcome(
                  receiptNo: 9,
                  posId: 1,
                  amount: d('1000'),
                  change: Decimal.zero,
                  paid: d('1000'),
                  debt: Decimal.zero,
                  fiscal: SaleFiscalization(s),
                ),
              )['fiscal']!
              as String;

      expect(word(FiscalState.notRequired), 'notRequired');
      expect(word(FiscalState.operatorAbsent), 'operatorAbsent');
      expect(word(FiscalState.fiscalModuleAbsent), 'fiscalModuleAbsent');
      expect(
        {
          word(FiscalState.notRequired),
          word(FiscalState.operatorAbsent),
          word(FiscalState.fiscalModuleAbsent),
        },
        hasLength(3),
      );
    });

    /// **Умолчание менять нельзя, и это выбор, а не недосмотр.** Заменить
    /// `notRequired` на `failed` значило бы превращать любое незнакомое
    /// слово — например, состояние из будущей версии кассы — в «деньги
    /// взяты, чек не фискален», то есть врать в противоположную сторону
    /// и гнать кассира разбираться с бедой, которой нет.
    ///
    /// Задача 5 добавила два новых члена и умолчания **не тронула**:
    /// `operatorAbsent` тоже нельзя ставить умолчанием, хотя оно и мягче.
    /// Старая касса поля не пришлёт вовсе, а утверждать по её молчанию,
    /// что у неё не настроен оператор, — то же самое враньё, только тише.
    test('незнакомое слово остаётся «не требуется», а не отказом', () {
      SaleOutcome withWord(String? word) => saleOutcomeFromWireJson({
        'receiptNo': 9,
        'posId': 1,
        'amount': '1000',
        'change': '0',
        'paid': '1000',
        'debt': '0',
        if (word != null) 'fiscal': word,
      });

      for (final word in [
        null,
        'что-то из будущего',
        'operator_absent', // змеиный регистр — не имя члена
        'OperatorAbsent', // чужой регистр
        '',
      ]) {
        final state = withWord(word).fiscal.state;
        expect(
          state,
          FiscalState.notRequired,
          reason: 'слово «$word» не имеет права стать $state',
        );
        expect(
          state,
          isNot(FiscalState.failed),
          reason: 'молчание кассы — не «деньги взяты, чек не фискален»',
        );
        expect(
          state,
          isNot(FiscalState.operatorAbsent),
          reason: 'молчание кассы — не утверждение о её настройке',
        );
      }
    });

    test('касса без поля и с незнакомым словом — «не требуется»', () {
      expect(
        saleOutcomeFromWireJson(const {
          'receiptNo': 9,
          'posId': 1,
          'amount': '1000',
          'change': '0',
          'paid': '1000',
          'debt': '0',
        }).fiscal.state,
        FiscalState.notRequired,
      );
      expect(
        saleOutcomeFromWireJson(const {
          'receiptNo': 9,
          'posId': 1,
          'amount': '1000',
          'change': '0',
          'paid': '1000',
          'debt': '0',
          'fiscal': 'что-то из будущего',
        }).fiscal.state,
        FiscalState.notRequired,
      );
    });
  });

  group('фискализация — на кассе', () {
    test('чек фискализуется на кассе, а не на терминале', () async {
      final view = await receipt();

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(fiscal.calls, hasLength(1));
      final call = fiscal.calls.single;
      expect(call.receiptNo, outcome.receiptNo);
      expect(call.posId, 1, reason: 'номер кассы, а не рабочего места');
      // Сумма — та, что вывела касса из строк своей базы.
      expect(call.amount, d('1000'));
      expect(call.cashAmount, d('1000'));
      expect(call.cardAmount, Decimal.zero);
      expect(outcome.fiscal.state, FiscalState.done);
      expect(outcome.fiscal.sign, 'ФП-777');
    });

    /// **Круг правки 1: проба утверждала только порядок.**
    ///
    /// Поле `SaleReceiptData.fiscal` не проверялось нигде в файле и было
    /// `null` во всех пробах — то есть «признак доезжает» не значило
    /// ничего. Теперь подделка оператора пишет строку в
    /// `WebkassaReceipts` ровно так, как это делает
    /// `FiscalServiceImpl._persistReceipt`, и проба сверяет **номер на
    /// бумаге**.
    ///
    /// **Круг правки 2: «порядок проверяется сам собой» было неправдой.**
    /// Померено диверсией — `_dispatchHardware`, переставленный перед
    /// `await _fiscalize`, оставлял весь файл зелёным, включая
    /// `finishedBeforePrint`: подделка оператора отвечала мгновенно, а
    /// компоновка чека успевала сходить в базу. Настоящий сетевой
    /// оператор пропустил бы такую перестановку в продукт, и на бумаге
    /// не оказалось бы фискального номера. Теперь порядок утверждается
    /// **журналом вызовов**, а подделка отвечает через 30 мс.
    test('фискальный номер доезжает до напечатанного чека', () async {
      final view = await receipt();

      await payments.complete(7, cashFor('1000'), mv(view, 9));
      await payments.pendingSideEffects;

      // Порядок утверждается **журналом вызовов**, а не гонкой на часах:
      // подделка оператора отвечает через 30 мс (её докстринг), и
      // перестановка `_dispatchHardware` перед `await _fiscalize` даёт
      // здесь `['print', 'fiscal']`.
      expect(sequence, ['fiscal', 'print']);
      expect(fiscal.finishedBeforePrint, isTrue);
      final printed = printer.receipts.single.fiscal;
      expect(printed, isNotNull);
      expect(printed!.fiscalNumber, 'ФД-100500');
      expect(printer.receipts.single.isFiscal, isTrue);
    });

    /// Вторая половина «а не на терминале»: у вкладки браузера этих
    /// портов нет вовсе.
    ///
    /// Сторож обязан был покраснеть и покраснел: до правки
    /// `payment_screen.dart` импортировал и `ReceiptPrintService`, и
    /// `CashDrawerService` и звал их сам.
    test('узел оплаты в интерфейсе не знает ни принтера, ни ящика, ни ОФД', () {
      const roots = <String>[
        'lib/presentation/screens/payment',
        'lib/presentation/controllers/payment',
        'lib/web',
      ];
      const forbidden = <String>[
        'ReceiptPrintService',
        'CashDrawerService',
        'FiscalService',
      ];

      final offenders = <String>[];
      var scanned = 0;
      for (final root in roots) {
        final dir = Directory(root);
        expect(
          dir.existsSync(),
          isTrue,
          reason: 'корень $root переехал — сторож смотрит в пустоту',
        );
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          scanned += 1;
          final text = _withoutComments(file.readAsStringSync());
          for (final name in forbidden) {
            if (text.contains(name)) {
              offenders.add('${file.path}: $name');
            }
          }
        }
      }

      // **Круг правки 1.** Прежняя версия молча пропускала несуществующий
      // корень (`if (!dir.existsSync()) continue;`): переименуй все три —
      // и проба зелёная, просмотрев ноль файлов. Пустая проба выглядит
      // ровно как соблюдённое правило.
      //
      // **Круг правки 2 (2026-09-18).** Сторож читал файл целиком, вместе с
      // комментариями, и покраснел на докстринге
      // `wt_receipt_template_setup.dart`, который **объясняет**, почему
      // текст предпросмотра собирает касса, а не вкладка, — и называет для
      // этого `ReceiptPrintService.renderSalePreviewText`. Ни импорта, ни
      // вызова там нет; запрет на имя в комментарии — это запрет объяснять
      // правило на примере, то есть способ отучить писать комментарии. Тот
      // же довод уже записан у `browser_routes_test`, который нашёл
      // `context.go('/login')` внутри документации о дефекте.
      //
      // Снятие комментариев **ничего не ослабляет**: настоящее нарушение —
      // это импорт или вызов, а они не бывают комментарием. Проверено
      // диверсией: живой `GetIt.I<ReceiptPrintService>()`, вписанный в
      // `lib/web/wt_receipt_template_setup.dart`, красит эту пробу
      // по-прежнему.
      expect(
        scanned,
        greaterThan(10),
        reason: 'сторож обязан хоть что-то прочитать',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'железо и фискальный оператор — кассы: терминал их только '
            'запускает командой оплаты',
      );
    });
  });

  group('отказ принтера', () {
    test('деньги взяты, чек фискален, отказ печати назван вслух', () async {
      final view = await receipt();
      printer.reject('бумаги нет');

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));
      await payments.pendingSideEffects;

      // 1. Оплата не отменена.
      expect(outcome.paid, d('1000'));
      expect(outcome.change, Decimal.zero);
      final sale = await saleRow(outcome.receiptNo);
      // `isNot(0)` пропустил бы `null` — сверяем с настоящим состоянием
      // «ожидает отправки» (`SaleUseCaseImpl._pendingSync`).
      expect(sale.state, 1, reason: 'чек оплачен, а не в работе');
      expect(await db.paymentDao.countBySale(outcome.receiptNo, 1), 1);
      expect(
        (await db.accountDao.findById(posAccountId))?.value,
        d('1000'),
        reason: 'деньги легли на счёт кассы',
      );

      // 2. Чек фискален.
      expect(outcome.fiscal.state, FiscalState.done);

      // 3. Отказ виден названно, а не молча: запись уровня `error`, с
      //    номером чека и с причиной, которую назвала очередь.
      expect(
        observed.errorsWith(['чек ${outcome.receiptNo}', 'бумаги нет']),
        isNotEmpty,
      );
    });

    test('принтер бросил — оплата всё равно завершена', () async {
      final view = await receipt();
      printer.throwOnPrint = StateError('/dev/usb/lp0: нет такого устройства');

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));
      await payments.pendingSideEffects;

      expect(outcome.paid, d('1000'));
      expect((await saleRow(outcome.receiptNo)).state, 1);
      expect(
        observed.errorsWith(['чека ${outcome.receiptNo}']),
        isNotEmpty,
        reason: 'исключение принтера не имеет права пройти молча',
      );
    });
  });

  group('отказ фискализации', () {
    /// **Решение задачи 16, а не умолчание.** Деньги остаются взятыми.
    ///
    /// Транзакция продажи (остаток, платежи, балансы) закрыта до того, как
    /// фискализация вообще началась, и обратного хода у неё в дереве нет:
    /// `reverseSaleStock` не трогает ни склад WMS, ни серийные номера, ни
    /// ингредиенты, и вызывающих у него ноль. «Откат» был бы враньём.
    /// Отказать после того, как деньги в ящике, — хуже: кассир возьмёт их
    /// второй раз. Нефискализованный чек в дереве уже имеет своё лечение —
    /// очередь фискализации и разбор `FiscErrorsService`.
    ///
    /// Что меняется этой задачей: отказ перестаёт быть **молчаливым**.
    test('оператор отказал — деньги взяты, отказ назван в исходе', () async {
      final view = await receipt();
      fiscal.result = const FiscalResult(
        success: false,
        errorMessage: 'ОФД недоступен',
        errorCode: FiscalErrorCode.network,
      );

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(outcome.paid, d('1000'), reason: 'деньги взяты');
      expect((await saleRow(outcome.receiptNo)).state, 1);
      expect(await db.paymentDao.countBySale(outcome.receiptNo, 1), 1);

      expect(outcome.fiscal.state, FiscalState.failed);
      // Причина — код словаря (`FiscalFailureReason.encode`), а не текст
      // провайдера: «ОФД недоступен» написан по-русски и до кассира с
      // другой локалью доехал бы как есть.
      expect(outcome.fiscal.message, 'fiscal(network)');
    });

    test('фискализация бросила — оплата не роняется', () async {
      final view = await receipt();
      fiscal.throws = StateError('нет связи');

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(outcome.paid, d('1000'));
      expect(outcome.fiscal.state, FiscalState.failed);
      expect(outcome.fiscal.message, isNotNull);
      // Текст исключения наружу не уходит — I144.
      expect(outcome.fiscal.message, isNot(contains('нет связи')));
    });

    test('очередь — не отказ: чек уедет сам', () async {
      final view = await receipt();
      fiscal.result = const FiscalResult(success: true, queued: true);

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(outcome.fiscal.state, FiscalState.queued);
    });

    /// Три «документа нет» — три разных ответа (задача 5).
    ///
    /// До задачи 5 все три пути возвращали одно `notRequired`, и проба
    /// ниже была одна. Разница не косметическая: одно лечится настройкой
    /// оператора, другое пересборкой кассы, третье не лечится вовсе,
    /// потому что и не сломано. Пробы разведены по причинам, а не по
    /// значению — иначе слияние трёх обратно в одно осталось бы зелёным.
    test(
      'оператора у кассы нет — не отказ и не «политика», а operatorAbsent',
      () async {
        final view = await receipt();
        fiscal.enabled = false;

        final outcome = await payments.complete(
          7,
          cashFor('1000'),
          mv(view, 9),
        );

        expect(outcome.fiscal.state, FiscalState.operatorAbsent);
        expect(
          outcome.fiscal.state,
          isNot(FiscalState.notRequired),
          reason: 'ненастроенный оператор — утверждение о кассе, не о чеке',
        );
        expect(outcome.fiscal.isFailed, isFalse, reason: 'это не беда');
        expect(fiscal.calls, isEmpty);
        // И печать всё равно идёт: нефискальный чек — тоже чек.
        await payments.pendingSideEffects;
        expect(printer.receipts, hasLength(1));
        // **Причина доезжает до бумаги.** Утверждение о значении в
        // `SaleOutcome` не доказывает, что подвал чека её увидит: чек
        // собирается отдельным путём, из базы, а исхода фискализации
        // `Sales` не хранит (колонка — задача 14). Здесь проверяется
        // именно то, что придёт в принтер.
        expect(
          printer.receipts.single.fiscalState,
          FiscalState.operatorAbsent,
        );
      },
    );

    test(
      'узла фискализации нет в сборке — fiscalModuleAbsent, и это в журнале',
      () async {
        // Касса, собранная без фискального узла вовсе. До задачи 3 это
        // писалось нулём (`fiscal: null`) и получалось также молчанием —
        // любой, кто про довод забыл, собирал слепую кассу не желая того.
        // Теперь это утверждение, и написано оно именем типа.
        // Не то же, что выключенный оператор, — и проба обязана уметь
        // отличить одно от другого, иначе разделение не доказано.
        final blind = LocalPaymentService(
          db: db,
          checkout: checkout,
          sale: SaleUseCaseImpl(db: db, logger: logger),
          logger: logger,
          fiscal: const RefusingFiscalService(),
          fiscalQueue: DriftFiscalQueueStore(db),
          printer: printer,
          drawer: drawer.open,
        );
        final view = await receipt();

        final outcome = await blind.complete(7, cashFor('1000'), mv(view, 9));

        expect(outcome.fiscal.state, FiscalState.fiscalModuleAbsent);
        expect(outcome.fiscal.isModuleAbsent, isTrue);
        expect(
          outcome.fiscal.state,
          isNot(FiscalState.operatorAbsent),
          reason: 'сломанная сборка — не ненастроенный оператор',
        );
        expect(
          outcome.fiscal.state,
          isNot(FiscalState.notRequired),
          reason: 'сломанная сборка — не «документ не нужен»',
        );
        // Деньги взяты, и это не отменяется.
        expect(outcome.paid, d('1000'));
        // Каждый раз, а не однажды: `error` в журнал, со словом «чек» и
        // **настоящим** номером — иначе запись не найти среди тысяч.
        // Номер берётся из исхода, а не пишется числом в пробе: `mv(v, 9)`
        // задаёт ключ повтора `k9`, а вовсе не номер чека, и проба с
        // литералом `9` зеленела бы или краснела по чужой причине.
        expect(
          observed.errorsWith([
            'узла фискализации',
            'чек ${outcome.receiptNo}',
          ]),
          isNotEmpty,
          reason: 'сломанная сборка обязана попадать в журнал каждым чеком',
        );
        await blind.pendingSideEffects;
      },
    );

    test(
      'оператор есть, но политика чека сказала «не в этот раз» — notRequired',
      () async {
        // `ofdSyncType == 2` — фискализовать только чеки, оплаченные
        // целиком безналично. Этот оплачен наличными, значит документа
        // ему не положено. Оператор при этом настроен и включён:
        // утверждение делается о **чеке**, а не о кассе.
        await db
            .update(db.thisPosEntries)
            .write(const ThisPosEntriesCompanion(ofdSyncType: Value(2)));
        final view = await receipt();

        final outcome = await payments.complete(
          7,
          cashFor('1000'),
          mv(view, 9),
        );

        expect(outcome.fiscal.state, FiscalState.notRequired);
        expect(
          outcome.fiscal.state,
          isNot(FiscalState.operatorAbsent),
          reason: 'оператор настроен — про кассу здесь ничего не сказано',
        );
        expect(fiscal.calls, isEmpty);
        await payments.pendingSideEffects;
      },
    );
  });

  group('денежный ящик', () {
    test('наличные открывают ящик кассы', () async {
      final view = await receipt();

      await payments.complete(7, cashFor('1000'), mv(view, 9));
      await payments.pendingSideEffects;

      expect(drawer.opens, 1);
    });

    test('оплата картой ящик не открывает', () async {
      final view = await receipt();

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.card),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      expect(drawer.opens, 0);
    });

    /// **Проба, которая провалилась бы на `double`.**
    ///
    /// Чек из двух строк по 0,1 и 0,2 — сумма 0,3. Оплачен картой целиком,
    /// значит наличная часть ровно ноль и ящику открываться незачем. На
    /// `double` `0.1 + 0.2` даёт `0.30000000000000004`, разность с
    /// карточной частью выходит `4e-17` — «больше нуля», — и ящик
    /// открылся бы от ошибки округления, на глазах у покупателя, который
    /// не давал наличных.
    test('ящик не открывается от ошибки округления', () async {
      var view = await cart.start(
        terminalId: 7,
        wholesale: false,
        meta: m(1, 0),
      );
      view = await cart.addByBarcode(7, barcodeC, mv(view, 2));
      view = await cart.addByBarcode(7, barcodeD, mv(view, 3));
      expect(view.total, d('0.3'), reason: 'страховка от вырождения пробы');

      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.card),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      expect(outcome.paid, d('0.3'));
      expect(drawer.opens, 0);
      // И в чек уходит `0.3`, а не `0.30000000000000004`.
      expect(printer.receipts.single.totalAmount.toString(), '0.3');
    });

    test('одновременный повтор открывает ящик один раз', () async {
      final view = await receipt();
      final meta = mv(view, 9);

      // Две вкладки (или два нажатия), не дождавшиеся ответа. Последовательный
      // вызов этого не проверяет — гонка возникает именно при
      // одновременности.
      final both = await Future.wait([
        payments.complete(7, cashFor('1000'), meta),
        payments.complete(7, cashFor('1000'), meta),
      ]);
      await payments.pendingSideEffects;

      expect(both.map((o) => o.receiptNo).toSet(), {view.receiptNo});
      expect(drawer.opens, 1);
      expect(printer.receipts, hasLength(1));
      expect(fiscal.calls, hasLength(1));
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 1);
    });

    test('ящик не открывается дважды при повторе команды', () async {
      final view = await receipt();
      final meta = mv(view, 9);

      final first = await payments.complete(7, cashFor('1000'), meta);
      await payments.pendingSideEffects;
      final second = await payments.complete(7, cashFor('1000'), meta);
      await payments.pendingSideEffects;

      expect(second.repeat, isTrue);
      expect(second.paid, first.paid);
      expect(
        drawer.opens,
        1,
        reason: 'повтор команды не имеет права открыть ящик второй раз',
      );
      expect(
        printer.receipts,
        hasLength(1),
        reason: 'и напечатать второй чек тоже',
      );
      expect(
        fiscal.calls,
        hasLength(1),
        reason: 'и фискализовать чек второй раз',
      );
      expect(
        second.fiscal.state,
        FiscalState.unchanged,
        reason: 'повтор ничего не делал заново и не притворяется',
      );
      expect(await db.paymentDao.countBySale(first.receiptNo, 1), 1);
    });
  });

  group('беды железа доезжают до кассира — круг правки 1', () {
    /// Печать уходит `unawaited`, значит в `SaleOutcome` её исход попасть
    /// не может. Но и пропасть не имеет права: до задачи 16 экран
    /// показывал оранжевое «Ошибка печати» и при отказе очереди, и при
    /// исключении, а первая редакция задачи сняла этот сигнал вовсе.
    test('отказ очереди печати возвращается вызывающему названно', () async {
      final view = await receipt();
      printer.reject('бумаги нет');

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));
      final troubles = await payments.hardwareTroubles(7, outcome.receiptNo);

      expect(troubles, hasLength(1));
      expect(troubles.single.kind, CompletionTroubleKind.print);
      expect(troubles.single.receiptNo, outcome.receiptNo);
      expect(troubles.single.message, 'бумаги нет');
    });

    test('исключение принтера возвращается без текста исключения', () async {
      final view = await receipt();
      printer.throwOnPrint = StateError('/dev/usb/lp0: нет такого устройства');

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));
      final troubles = await payments.hardwareTroubles(7, outcome.receiptNo);

      expect(troubles.single.kind, CompletionTroubleKind.print);
      // I144: наружу уходит тип, а не текст.
      expect(troubles.single.message, 'StateError');
    });

    test('ящик, который не открылся, тоже беда', () async {
      final view = await receipt();
      drawer.answer = false;

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));
      final troubles = await payments.hardwareTroubles(7, outcome.receiptNo);

      expect(troubles.map((t) => t.kind), [CompletionTroubleKind.drawer]);
    });

    test('всё прошло — сказать нечего', () async {
      final view = await receipt();

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(await payments.hardwareTroubles(7, outcome.receiptNo), isEmpty);
    });

    /// Круг правки 2: без владения любой сеанс с `nav.sale` мог не
    /// только прочитать чужую беду, но и **съесть** её — чтение
    /// разрушающее, а номера чеков последовательны по кассе.
    test('чужое рабочее место беды не видит и не съедает', () async {
      final view = await receipt();
      printer.reject('бумаги нет');

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(await payments.hardwareTroubles(8, outcome.receiptNo), isEmpty);
      // И владелец по-прежнему видит свою.
      expect(
        await payments.hardwareTroubles(7, outcome.receiptNo),
        hasLength(1),
      );
    });

    test('читается один раз: второй спрос уже пуст', () async {
      final view = await receipt();
      printer.reject('бумаги нет');

      final outcome = await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(
        await payments.hardwareTroubles(7, outcome.receiptNo),
        hasLength(1),
      );
      expect(await payments.hardwareTroubles(7, outcome.receiptNo), isEmpty);
    });

    test('беды переживают провод', () {
      final back = troublesFromWireJson(
        troublesToWireJson(const [
          CompletionTrouble(
            kind: CompletionTroubleKind.print,
            receiptNo: 9,
            message: 'бумаги нет',
          ),
          CompletionTrouble(
            kind: CompletionTroubleKind.drawer,
            receiptNo: 9,
            message: 'порт занят',
          ),
        ]),
      );

      expect(back, hasLength(2));
      expect(back.first.kind, CompletionTroubleKind.print);
      expect(back.first.message, 'бумаги нет');
      expect(back.last.kind, CompletionTroubleKind.drawer);

      // Незнакомый вид пропускается, а не читается как печать.
      expect(
        troublesFromWireJson(const {
          'troubles': [
            {'kind': 'вид из будущего', 'receiptNo': 9, 'message': 'x'},
          ],
        }),
        isEmpty,
      );
    });
  });

  group('отказ фискализации оставляет след — круг правки 1', () {
    test(
      'строка ложится в очередь фискализации со состоянием failed',
      () async {
        final view = await receipt();
        fiscal.result = const FiscalResult(
          success: false,
          errorMessage: 'ОФД недоступен',
          errorCode: FiscalErrorCode.network,
        );

        final outcome = await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('1000'),
            customerBin: '870915300123',
          ),
          mv(view, 9),
        );
        expect(outcome.fiscal.state, FiscalState.failed);

        final rows = await db.select(db.fiscalQueueEntries).get();
        expect(rows, hasLength(1));
        expect(
          rows.single.idempotencyKey,
          'sale-unfiscalized:1-${view.receiptNo}',
        );
        expect(rows.single.status, FiscalQueueStatus.failed.index);
        // Код причины словаря, а не русский текст провайдера (дорожка D).
        expect(rows.single.lastError, 'fiscal(network)');
        expect(rows.single.payload, contains('"receiptNo":${view.receiptNo}'));
        // **Персональных данных в строке нет** (круг правки 2): её никто не
        // читает и никто не чистит — `remove()` зовёт только `replay()`, и
        // только по `pending`. ИИН/БИН покупателя копился бы там вечно.
        expect(rows.single.payload, isNot(contains('customerBin')));
        expect(rows.single.payload, isNot(contains('870915300123')));

        // **И не подбирается повтором.** `replay()` читает только
        // `pending`; положить сюда `pending` значило бы завести вечный
        // цикл на отказе, который слепым повтором не лечится.
        final store = DriftFiscalQueueStore(db);
        expect(await store.pending(), isEmpty);
        expect(await store.pendingCount(), 0);
      },
    );

    test('удача следа не оставляет', () async {
      final view = await receipt();

      await payments.complete(7, cashFor('1000'), mv(view, 9));

      expect(await db.select(db.fiscalQueueEntries).get(), isEmpty);
    });
  });

  group('покупатель лояльности и деньги возврата — круг правки 2', () {
    /// **Проба про деньги, и не про эту задачу — про соседнюю.**
    ///
    /// `Sales.customerLocalId` читает возврат:
    /// `refund_controller.dart:262` кладёт его в `ReceiptInfo`, `:507`
    /// отдаёт в `RefundUseCase.perform`, а `refund_use_case_impl.dart:111`
    /// по нему **безусловно** правит расчётный счёт покупателя — при
    /// любом виде оплаты. Значит стоит записать сюда клиента, чей телефон
    /// кассир набрал ради бонусов, и возврат обычной наличной продажи
    /// начнёт двигать ему баланс сверх наличных из ящика.
    ///
    /// Круг правки 1 это и сделал, круг правки 2 снял. Проба сторожит
    /// снятое: имя на чеке берётся из строк оплаты, а поле, которое
    /// читает возврат, остаётся пустым.
    test('телефон ради бонусов не делает покупателя должником чека', () async {
      await seedCustomer(bonus: '300');
      final view = await receipt();

      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('700'),
          bonusUsed: d('300'),
          customerId: customerId,
        ),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      // 1. То, что прочитает возврат, — пусто.
      final sale = await saleRow(view.receiptNo!);
      expect(
        sale.customerLocalId,
        isNull,
        reason: 'это поле уходит в RefundUseCase.perform(customerLocalId:)',
      );

      // 2. **И возврат этого чека баланса не рисует.** Круг правки 3:
      //    прежнее утверждение «расчётный счёт нулевой после продажи»
      //    покраснеть не могло никогда — продажа этот счёт не двигает ни
      //    с дефектом, ни без. Несущее утверждение — это: настоящий
      //    `RefundUseCaseImpl.perform`, позванный ровно тем значением,
      //    которое ему отдаёт `refund_controller.dart:507`.
      await db
          .into(db.refunds)
          .insert(RefundsCompanion.insert(userId: 4, time: 2000));
      final refundId = (await db.select(db.refunds).get()).single.localId;

      GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());
      addTearDown(() => GetIt.I.unregister<RefundProductService>());

      await RefundUseCaseImpl(
        db: db,
        logger: logger,
        fiscal: const RefusingFiscalService(),
      ).perform(
        refundLocalId: refundId,
        amount: d('1000'),
        userId: 4,
        saleReceiptNo: view.receiptNo,
        salePosId: 1,
        // Ровно то, что кладёт экран возврата.
        customerLocalId: sale.customerLocalId,
        products: const [],
      );

      expect(
        (await db.accountDao.findById(agentMainAccountId))?.value,
        Decimal.zero,
        reason:
            'refund_use_case_impl.dart:111 правит баланс по этому полю '
            'безусловно, при любом виде оплаты',
      );

      // 3. И при этом чек покупателя называет.
      expect(printer.receipts.single.customerName, 'Айгүл Дүйсенова');
    });

    test('агент, привязанный к корзине, полем возврата остаётся', () async {
      await seedCustomer();
      var view = await receipt();
      await db
          .update(db.sales)
          .replace(
            (await saleRow(
              view.receiptNo!,
            )).copyWith(customerLocalId: const Value(customerId)),
          );
      view = await cart.watch(7).first;

      await payments.complete(7, cashFor('1000'), mv(view, 9));

      // Привязанный агент — намеренное действие кассира, и его возврат
      // по-прежнему видит. Снято только то, что приезжало из телефона.
      expect((await saleRow(view.receiptNo!)).customerLocalId, customerId);
    });
  });

  group('чек называет покупателя и вид денег — круг правки 1', () {
    test('имя покупателя доезжает до чека', () async {
      await seedCustomer();
      final view = await receipt();

      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('1000'),
          customerId: customerId,
        ),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      expect(printer.receipts.single.customerName, 'Айгүл Дүйсенова');
    });

    /// Бонусная строка пишется на `agentCashback`. Первая редакция
    /// композитора звала «Картой» всё, что не счёт кассы, — и печатала
    /// «Карта» на сумму списанного бонуса.
    test('списанный бонус называется бонусом, а не картой', () async {
      await seedCustomer(bonus: '300');
      final view = await receipt();

      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('700'),
          bonusUsed: d('300'),
          customerId: customerId,
        ),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      final lines = printer.receipts.single.payments;
      expect(lines.map((l) => l.name), containsAll(['Наличные', 'Бонус']));
      expect(lines.where((l) => l.name.startsWith('Карта')), isEmpty);
      final bonusLine = lines.firstWhere((l) => l.name == 'Бонус');
      expect(bonusLine.amount, d('300'));
      expect(bonusLine.isCash, isFalse);
    });
  });
}

// ── подделки ─────────────────────────────────────────────────────────────

class _FiscalCall {
  const _FiscalCall({
    required this.receiptNo,
    required this.posId,
    required this.amount,
    required this.cashAmount,
    required this.cardAmount,
  });

  final int receiptNo;
  final int posId;
  final Decimal amount;
  final Decimal cashAmount;
  final Decimal cardAmount;
}

class _FakeFiscalService implements FiscalService {
  _FakeFiscalService(this._db, this.sequence);

  final AppDatabase _db;

  /// Общий журнал вызовов: фискализация и печать пишут в него по порядку.
  final List<String> sequence;

  /// **Оператор отвечает не мгновенно, и это обязательно** (круг правки
  /// 2). Померено диверсией: с мгновенной подделкой перестановка
  /// `_dispatchHardware` **перед** `await _fiscalize` оставляла весь файл
  /// зелёным — компоновка чека успевала сходить в базу, пока
  /// фискализация «шла». Настоящий сетевой оператор пропустил бы такую
  /// перестановку в продукт, и на бумаге не оказалось бы фискального
  /// номера. Задержка делает порядок проверяемым, а не подброшенным
  /// часами.
  Duration latency = const Duration(milliseconds: 30);

  final List<_FiscalCall> calls = [];

  bool enabled = true;
  Object? throws;
  FiscalResult result = const FiscalResult(
    success: true,
    fiscalSign: 'ФП-777',
    registrationNumber: 'РНМ-1',
  );

  bool _done = false;
  bool? _printSawFiscalDone;

  /// Фискализация закончилась **до** того, как в принтер вошли.
  bool get finishedBeforePrint => _printSawFiscalDone ?? false;

  void notePrintStarted() => _printSawFiscalDone ??= _done;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  }) async {
    calls.add(
      _FiscalCall(
        receiptNo: saleReceiptNo,
        posId: salePosId,
        amount: amount,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
      ),
    );
    await Future<void>.delayed(latency);
    sequence.add('fiscal');
    final boom = throws;
    if (boom != null) throw boom;
    // Строка чека пишется ровно так же, как это делает
    // `FiscalServiceImpl._persistReceipt`: только на успехе с признаком.
    // Без неё «фискальный номер доезжает до чека» проверять нечем —
    // реквизиты чек берёт из `WebkassaReceipts`.
    if (result.success && result.hasFiscalSign) {
      await _db.webkassaReceiptDao.insertReceipt(
        WebkassaReceiptsCompanion(
          operationId: Value(saleReceiptNo),
          receiptNo: Value(saleReceiptNo),
          isSale: const Value(true),
          fiscalNo: const Value('ФД-100500'),
          registrationNumber: Value(result.registrationNumber),
        ),
      );
    }
    _done = true;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

/// Принтер, который умеет **висеть** — иначе проба на время не значит
/// ничего.
class _HangingPrinter implements ReceiptPrintService {
  _HangingPrinter(this.sequence);

  /// Тот же журнал, что у подделки оператора, — см. её докстринг.
  final List<String> sequence;

  final List<SaleReceiptData> receipts = [];
  final List<String> drawerCalls = [];

  bool started = false;
  bool finished = false;
  Object? throwOnPrint;
  String? _rejectReason;
  Completer<void>? _gate;
  Timer? _timer;
  _FakeFiscalService? watcher;

  void hangFor(Duration d) {
    final gate = Completer<void>();
    _gate = gate;
    _timer = Timer(d, () {
      if (!gate.isCompleted) gate.complete();
    });
  }

  void reject(String reason) => _rejectReason = reason;

  /// Отпустить зависший принтер — иначе набор ждал бы таймер до конца.
  void release() {
    _timer?.cancel();
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<PrintSubmitOutcome> printSaleReceipt(SaleReceiptData data) async {
    sequence.add('print');
    started = true;
    watcher?.notePrintStarted();
    final boom = throwOnPrint;
    if (boom != null) throw boom;
    final gate = _gate;
    if (gate != null) await gate.future;
    finished = true;
    receipts.add(data);
    final reason = _rejectReason;
    return reason == null
        ? PrintSubmitOutcome.accepted('sale-${data.receiptNo}')
        : PrintSubmitOutcome.rejected('sale-${data.receiptNo}', reason);
  }

  @override
  Future<bool> openCashDrawer() async {
    drawerCalls.add('printer');
    return true;
  }

  @override
  Future<bool> isPrinterAvailable() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

class _RecordingDrawer {
  int opens = 0;
  bool answer = true;

  Future<bool> open() async {
    opens += 1;
    return answer;
  }
}

/// Сторож «названно, а не молча».
///
/// **Уровень записи входит в утверждение, и это не придирка** — измерено
/// диверсией: первая версия сторожа искала подстроку в тексте **любой**
/// записи, и понижение `Talker.error` до `Talker.debug` (то есть ровно то,
/// что значит «молча») её не красило. Хуже: номер чека `1` находился в
/// отметке времени самой записи, так что и текст сверялся не с тем, с чем
/// думалось. Теперь ищется запись **уровня `error`**, а номер чека — со
/// словом «чек» перед ним.
class _CapturingObserver extends TalkerObserver {
  final List<_LogRecord> captured = [];

  Iterable<String> errorsWith(List<String> parts) => captured
      .where((r) => r.isError && parts.every((p) => r.text.contains(p)))
      .map((r) => r.text);

  @override
  void onError(TalkerError err) =>
      captured.add(_LogRecord(err.generateTextMessage(), isError: true));

  @override
  void onException(TalkerException err) =>
      captured.add(_LogRecord(err.generateTextMessage(), isError: true));

  @override
  void onLog(TalkerData log) => captured.add(
    _LogRecord(
      log.generateTextMessage(),
      isError: log.logLevel == LogLevel.error,
    ),
  );
}

class _LogRecord {
  const _LogRecord(this.text, {required this.isError});

  final String text;
  final bool isError;
}

/// Возврат без строк товара: `RefundUseCaseImpl.perform` резолвит эту
/// службу из `GetIt` **внутри** себя, и без регистрации проба до денежного
/// утверждения не доходит. Пустышка — потому что список товаров пуст, и
/// ни один её метод не зовётся.
class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}
