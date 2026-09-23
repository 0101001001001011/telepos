import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
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
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/agent/bonus_service.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_config.dart';
import '../../helpers/cash_drawer.dart';

/// Оплата чека — задача 14.
///
/// Настоящая база, настоящая корзина, настоящая подготовка чека и
/// **настоящий** `SaleUseCaseImpl` под сервисом. Мок доказал бы, что
/// сервис зовёт то, что ему велели звать; доказать надо другое: что
/// деньги в базе легли так, как сказала касса, что повтор не берёт их
/// второй раз и что число, присланное вкладкой, до денег не доходит.
///
/// Единственная подделка — драйвер платёжного терминала: он открывает
/// сокет к настоящему устройству, и без шва тесты оплаты картой могли бы
/// существовать только с железом на столе.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late LocalPaymentService payments;
  late _RecordingCardTerminal terminal;

  const barcodeA = '4870001234567';
  const barcodeB = '4870007654321';

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
    bool markable = false,
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

  /// Клиент лояльности: бонусный счёт для списания бонуса, расчётный —
  /// для долга.
  Future<void> seedCustomer({
    int? cashback = cashbackAccountId,
    int? main = agentMainAccountId,
    String bonus = '0',
    String balance = '0',
  }) async {
    if (cashback != null) {
      await seedAccount(cashback, AccountType.agentCashback, value: bonus);
    }
    if (main != null) {
      await seedAccount(main, AccountType.agentMain, value: balance);
    }
    await db
        .into(db.agents)
        .insert(
          AgentsCompanion.insert(
            localId: const Value(customerId),
            name: const Value('Айгуль'),
            phone: const Value(77015550000),
            cashbackAccountId: Value(cashback),
            mainAccountId: Value(main),
          ),
        );
  }

  /// Чек с одной строкой товара [barcodeA] по 500 за штуку.
  Future<CartView> receiptWith({int quantity = 1, int terminalId = 7}) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(terminalId, barcodeA, mv(view, 2));
    if (quantity > 1) {
      view = await cart.setQuantity(
        terminalId,
        view.lines.single.id,
        d('$quantity'),
        mv(view, 3),
      );
    }
    return view;
  }

  Future<Sale> saleRow(int receiptNo) async =>
      (await db.saleDao.findByKey(receiptNo, 1))!;

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  Future<Decimal> stockOf(int ucode) async =>
      (await db.productInfoDao.findByUcode(ucode))?.quantity ?? Decimal.zero;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
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
    await seedProduct(ucode: 200, barcode: barcodeB, price: '1490');
    await seedAccount(posAccountId, AccountType.pos);
    await seedAccount(bankAccountId, AccountType.customBank);

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
    terminal = _RecordingCardTerminal();
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      cardTerminal: terminal.charge,
      // Порт обязателен (задача 3): эти пробы про деньги, а не про
      // фискализацию, и «узла нет» здесь — сознательный выбор, а не
      // пропущенный довод. До задачи он получался молчанием.
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('сдача', () {
    test('сдача считается кассой, а не приходит из браузера', () async {
      // Чек на 1990: одна штука по 500 и одна по 1490.
      var view = await receiptWith();
      view = await cart.addByBarcode(7, barcodeB, mv(view, 3));
      expect(view.total, d('1990'), reason: 'страховка от вырождения пробы');

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('5000'),
          claimedChange: d('9999'), // подделка
        ),
        mv(view, 9),
      );

      expect(outcome.change, d('3010'));
      // И в базе тоже: экран мог бы показать одно, а чек унести другое.
      expect((await saleRow(view.receiptNo!)).change, d('3010'));
    });

    test('сдача есть только с наличной части смешанной оплаты', () async {
      final view = await receiptWith(quantity: 2); // 1000

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.mixed,
          cardAmount: d('400'),
          cashReceived: d('1000'),
        ),
        mv(view, 9),
      );

      // Картой 400, наличными нужно 600, дали 1000 — сдача 400.
      expect(outcome.change, d('400'));
      expect(outcome.paid, d('1000'));
      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows.map((p) => p.amount).toList(), [d('600'), d('400')]);
    });

    test('картой сдачи не бывает', () async {
      final view = await receiptWith(quantity: 2);

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.card,
          cashReceived: d('9000'), // экран мог оставить прошлый ввод
          claimedChange: d('8000'),
        ),
        mv(view, 9),
      );

      expect(outcome.change, Decimal.zero);
      expect(await balanceOf(bankAccountId), d('1000'));
    });

    test('наличных меньше суммы — названный отказ, чек цел', () async {
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('999')),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payInsufficientCode),
        ),
      );

      final sale = await saleRow(view.receiptNo!);
      expect(sale.state, 0, reason: 'чек остался в работе');
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });
  });

  group('повтор', () {
    test('повтор с тем же ключом не берёт деньги дважды', () async {
      final view = await receiptWith(quantity: 2);
      final meta = mv(view, 9);

      final first = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        meta,
      );
      final second = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        meta,
      );

      expect(second.repeat, isTrue);
      expect(second.change, first.change);
      expect(second.amount, first.amount);
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 1);
      // Деньги: счёт кассы сдвинут один раз, остаток списан один раз.
      expect(await balanceOf(posAccountId), d('1000'));
      expect(await stockOf(100), d('98'));
    });

    test('вторая оплата другим ключом отвергается названным отказом', () async {
      final view = await receiptWith(quantity: 2);

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
          mv(view, 10),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payAlreadyTakenCode),
        ),
      );

      expect(await balanceOf(posAccountId), d('1000'));
    });
  });

  group('второй оплаты уже оплаченного чека нет', () {
    test('другой ключ отвергается и деньги не двигаются', () async {
      // Отмена уже проведённой оплаты убрана целиком (круг правки 1):
      // у неё не было ни одного производителя в `lib/`, она была достижима
      // только рукописным кадром и приносила с собой дыру в правах,
      // невозвращаемый склад и двойное списание при переоплате. Отказ —
      // сознательный тупик: взять деньги дважды хуже, чем не взять их
      // автоматически.
      final view = await receiptWith(quantity: 2);
      final receiptNo = view.receiptNo!;

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.card),
          m(11, 0, receiptNo: receiptNo),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payAlreadyTakenCode),
        ),
      );

      expect(await db.paymentDao.countBySale(receiptNo, 1), 1);
      expect(await balanceOf(posAccountId), d('1000'));
      expect(await balanceOf(bankAccountId), Decimal.zero);
      expect(await stockOf(100), d('98'));
    });

    test('долг тоже не отменяет прежнюю оплату', () async {
      // C1 круга правки 1 в его денежной части: кадр с типом «долг»
      // сваливал всю сумму оплаченного чека на покупателя, снимая деньги
      // со счёта кассы. Теперь путь закрыт до всякой проверки прав —
      // второй оплаты нет вовсе.
      await seedCustomer(balance: '0');
      final view = await receiptWith(quantity: 2);
      final receiptNo = view.receiptNo!;

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.debt, customerId: customerId),
          m(11, 0, receiptNo: receiptNo),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payAlreadyTakenCode),
        ),
      );

      expect(await balanceOf(posAccountId), d('1000'));
      expect(await balanceOf(agentMainAccountId), Decimal.zero);
      expect(await db.paymentDao.countBySale(receiptNo, 1), 1);
    });
  });

  group('остатки', () {
    test('отказ подготовки чека не прибавляет остаток товару', () async {
      // Касса настроена запрещать продажу сверх остатка.
      await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
        const ThisPosEntriesCompanion(blockOversell: Value(true)),
      );
      var view = await receiptWith();
      view = await cart.setQuantity(
        7,
        view.lines.single.id,
        d('500'), // больше остатка (100)
        mv(view, 3),
      );
      final before = await stockOf(100);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('999999')),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            checkoutInsufficientStockCode,
          ),
        ),
      );

      expect(
        await stockOf(100),
        before,
        reason:
            'отказ подготовки прибавил остаток товару, у которого его '
            'никто не отнимал',
      );
    });
  });

  group('бонус', () {
    test('бонус урезается остатком бонусного счёта', () async {
      await seedCustomer(bonus: '120');

      expect(await payments.reserveBonus(customerId, d('500')), d('120'));
      expect(await payments.reserveBonus(customerId, d('100')), d('100'));
      expect(await payments.reserveBonus(customerId, d('120')), d('120'));
    });

    test('бонус неизвестного клиента — названный отказ', () async {
      await expectLater(
        payments.reserveBonus(999, d('10')),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payCustomerUnknownCode,
          ),
        ),
      );
    });

    test(
      'бонус больше чека урезается суммой чека, и деньги сходятся',
      () async {
        await seedCustomer(bonus: '5000');
        final view = await receiptWith(quantity: 2); // 1000

        final outcome = await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            bonusUsed: d('5000'),
            customerId: customerId,
          ),
          mv(view, 9),
        );

        expect(outcome.paid, d('1000'));
        expect(outcome.change, Decimal.zero);
        // Списано ровно 1000, а не 5000: остаток бонуса 4000.
        expect(await balanceOf(cashbackAccountId), d('4000'));
        expect(await balanceOf(posAccountId), Decimal.zero);
      },
    );

    test(
      'чек, оплаченный бонусом ЦЕЛИКОМ, всё равно имеет строку оплаты',
      () async {
        // **Инвариант «Σ строк оплаты == сумма чека» — задача 14.**
        //
        // Строка `Payments` пишется **всегда**, даже когда денег в кассу
        // не пришло ни копейки: журналом (задача 13) заменена только
        // запись бонусного *баланса*, а не сама строка оплаты. Без
        // строки чек, оплаченный бонусом целиком, остался бы вообще без
        // строк оплаты — и нарушать уникальный ключ гонщику стало бы
        // нечем, то есть защита от двойного взятия денег на этом чеке
        // просто отсутствовала бы.
        await seedCustomer(bonus: '5000');
        final view = await receiptWith(quantity: 2); // 1000

        final outcome = await payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            bonusUsed: d('1000'),
            customerId: customerId,
          ),
          mv(view, 9),
        );

        expect(outcome.paid, d('1000'));

        final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
        expect(rows, isNotEmpty, reason: 'строка пишется ВСЕГДА');
        expect(
          rows.fold(Decimal.zero, (Decimal sum, p) => sum + p.amount),
          d('1000'),
        );
        expect(rows.single.kindId, SystemPaymentKindIds.bonus);
        expect(rows.single.seq, 0);

        // Наличных в ящик не пришло — и не должно.
        expect(await balanceOf(posAccountId), Decimal.zero);
      },
    );

    test('вид, ВЫКЛЮЧЕННЫЙ оператором, касса не принимает', () async {
      // **Справочник — читатель, а не окно.** Оператор снял галочку с
      // «Наличных»; без этой проверки касса продолжала бы их принимать, и
      // настройка была бы обманом. Настройка, которая ничего не меняет,
      // хуже отсутствующей: на неё полагаются.
      final catalog = PaymentKindCatalogImpl(db);
      final cashKind = (await catalog.byId(SystemPaymentKindIds.cash))!;
      await catalog.upsert(cashKind.copyWith(isActive: false));

      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payKindInactiveCode),
        ),
      );

      // Отказ пришёл **до денег**: чек цел, строк оплаты нет, ящик пуст.
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      expect(await balanceOf(posAccountId), Decimal.zero);
    });

    test('включённый вид принимается как обычно', () async {
      // Обратный полюс: проверка обязана пускать. Сторож, который только
      // запрещает, зелен и на коде, запрещающем всё.
      final view = await receiptWith(quantity: 2);
      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );
      expect(outcome.paid, d('1000'));
    });

    test('бонус неизвестного клиента при оплате — названный отказ', () async {
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('1000'),
            bonusUsed: d('100'),
            customerId: 999,
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payCustomerUnknownCode,
          ),
        ),
      );
    });

    test('бонус клиенту без бонусного счёта — названный отказ', () async {
      await seedCustomer(cashback: null);
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.cash,
            cashReceived: d('1000'),
            bonusUsed: d('100'),
            customerId: customerId,
          ),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payBonusAccountMissingCode,
          ),
        ),
      );
    });
  });

  group('счета кассы', () {
    test('чек оплачивается на кассе без назначенного счёта', () async {
      // `ThisPos.accountId` пуст, но счёт кассы в базе есть — деньги
      // ложатся на него, а не в новый.
      await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
        const ThisPosEntriesCompanion(accountId: Value(null)),
      );
      final view = await receiptWith(quantity: 2);

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      expect(await balanceOf(posAccountId), d('1000'));
      expect(await db.accountDao.countByType(AccountType.pos), 1);
    });

    test('счёт кассы заводится, когда его нет вовсе', () async {
      // Отказать здесь значило бы остановить торговлю на кассе, где
      // мастер настройки прошёл криво. Заведение — то же поведение, что
      // было в `processPayment`, и оно названо в докстринге, а не
      // подразумевается.
      await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
        const ThisPosEntriesCompanion(accountId: Value(null)),
      );
      await (db.delete(
        db.accounts,
      )..where((a) => a.id.equals(posAccountId))).go();
      final view = await receiptWith(quantity: 2);

      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      expect(outcome.paid, d('1000'));
      expect(await db.accountDao.countByType(AccountType.pos), 1);
    });

    test('счёт эквайринга заводится, когда его нет вовсе', () async {
      await (db.delete(
        db.accounts,
      )..where((a) => a.id.equals(bankAccountId))).go();
      final view = await receiptWith(quantity: 2);

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.card),
        mv(view, 9),
      );

      final bank = await db.accountDao.findByType(AccountType.customBank);
      expect(bank, hasLength(1));
      expect(bank.single.value, d('1000'));
    });
  });

  group('счёт называет касса, а не браузер', () {
    test('чужой счёт агента деньги не получает', () async {
      // C3 круга правки 1. Проба разбора уводила выручку на расчётный
      // счёт агента: номер счёта брался из кадра как есть.
      await seedCustomer();
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.card, accountId: agentMainAccountId),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payAccountNotAllowedCode,
          ),
        ),
      );

      expect(await balanceOf(agentMainAccountId), Decimal.zero);
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });

    test('оплата картой не уменьшает бонусный счёт покупателя', () async {
      // Вторая проба того же дефекта, и она страшнее первой: списание
      // бонусного счёта в `perform` идёт в **минус** — оплата картой
      // съедала бы бонусы покупателя.
      await seedCustomer(bonus: '500');
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.card, accountId: cashbackAccountId),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payAccountNotAllowedCode,
          ),
        ),
      );

      expect(await balanceOf(cashbackAccountId), d('500'));
    });

    test('несуществующий счёт отвергается', () async {
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.card, accountId: 4242),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payAccountNotAllowedCode,
          ),
        ),
      );
    });

    test('наличная оплата со счётом кассы — умолчание экрана', () async {
      // **Проба, которой не было, и потому C3 принёс поломку денежного
      // пути.** Экран при нажатии «Наличные» сам выбирает счёт с
      // признаком умолчания — то есть кассовый — и шлёт его в теле при
      // **любом** виде оплаты. Проверка счёта звалась безусловно, до
      // разбора вида оплаты, и принимала только банковские: наличная
      // оплата переставала проходить вовсе.
      final offered = await payments.accounts();
      final byDefault = offered.firstWhere((a) => a.isDefault);
      // Задача 33: доводом было «экран выберет именно его» — утверждение
      // о `payment_controller.dart` (выбор по `isDefault`), которое эта
      // проба не исполняет. Проверяется то, что отдаёт сервис.
      expect(
        byDefault.id,
        posAccountId,
        reason: 'умолчанием accounts() отдаёт кассовый счёт',
      );
      final view = await receiptWith(quantity: 2);

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('1000'),
          accountId: byDefault.id,
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('1000'));
      expect(await balanceOf(posAccountId), d('1000'));
    });

    test('счёт кассы принимается и под безналичную часть', () async {
      // Вторая половина той же правки: список проверяется **целиком**, а
      // не половиной. Кассовый счёт под карту допускался и до всякой
      // проверки — умолчание падает на него, когда банковского нет вовсе.
      final view = await receiptWith(quantity: 2);

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.card, accountId: posAccountId),
        mv(view, 9),
      );

      expect(await balanceOf(posAccountId), d('1000'));
      expect(await balanceOf(bankAccountId), Decimal.zero);
    });

    test('скрытый от кассы счёт не предлагается и не принимается', () async {
      // Круг правки 3: кассовые счета шли в список мимо признака
      // видимости, а банковские — через него. Скрытый кассовый счёт
      // **предлагался** браузеру и потому принимался; скрытый банковский
      // в тех же условиях отвергался. Раз круг 2 сделал этот список
      // границей безопасности, граница обязана фильтровать весь список.
      await seedAccount(21, AccountType.pos, value: '0');
      await (db.update(db.accounts)..where((a) => a.id.equals(21))).write(
        const AccountsCompanion(visibleToPos: Value(false)),
      );

      expect(
        (await payments.accounts()).map((a) => a.id),
        isNot(contains(21)),
        reason: 'скрытый счёт кассе предлагать нечего',
      );

      final view = await receiptWith(quantity: 2);
      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.card, accountId: 21),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payAccountNotAllowedCode,
          ),
        ),
      );
      expect(await balanceOf(21), Decimal.zero);
    });

    test('счёт из списка кассы проходит', () async {
      // Страховка от вырождения: если бы проверка отвергала любой
      // названный счёт, три пробы выше прошли бы и ничего не доказывали.
      final offered = await payments.accounts();
      expect(offered.map((a) => a.id), contains(bankAccountId));
      final view = await receiptWith(quantity: 2);

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.card, accountId: bankAccountId),
        mv(view, 9),
      );

      expect(await balanceOf(bankAccountId), d('1000'));
    });
  });

  group('наличная и безналичная части на одном счёте', () {
    test('две строки на один счёт — законны, и различаются ВИДОМ', () async {
      // **Здесь стоял отказ `payment_account_conflict`, и задача 14 его
      // сняла.** Он существовал ровно потому, что существовал старый
      // уникальный ключ `Payments` `{receiptNo, posId, payeeAccountId}`:
      // наличная и безналичная части, обе упавшие на счёт кассы,
      // сталкивались в базе сырым `SqliteException(2067)`. Правильным
      // ответом на это была не проверка, а ключ: строки различаются не
      // счётом, а **видом оплаты**, и до v41 колонки вида в `Payments`
      // не было вовсе.
      //
      // Проба переписана в свою противоположность осознанно: то, что
      // раньше обязано было отказать, теперь обязано **пройти и оставить
      // две различимые строки**.
      final view = await receiptWith(quantity: 2);

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.mixed,
          cardAmount: d('400'),
          cashReceived: d('600'),
          accountId: posAccountId,
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('1000'));

      final rows = await db.paymentDao.findBySale(view.receiptNo!, 1);
      expect(rows, hasLength(2));
      expect(
        rows.map((p) => p.payeeAccountId).toSet(),
        {posAccountId},
        reason:
            'обе строки на счёте кассы — ровно то, что старый ключ '
            'запрещал',
      );
      expect(rows.map((p) => p.kindId).toList(), [
        SystemPaymentKindIds.cash,
        SystemPaymentKindIds.card,
      ]);
      expect(rows.map((p) => p.seq).toList(), [0, 1]);
      expect(
        rows.fold(Decimal.zero, (Decimal sum, p) => sum + p.amount),
        d('1000'),
      );
    });

    test('чистая карта на счёт кассы столкнуться не с чем', () async {
      // Страховка от вырождения: запрет держится на **наличной части**, а
      // не на самом кассовом счёте. Без наличных строка одна, и путь
      // «банковского счёта нет вовсе» обязан остаться рабочим — ради него
      // умолчание и падало на счёт кассы.
      final view = await receiptWith(quantity: 2);

      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.card, accountId: posAccountId),
        mv(view, 9),
      );

      expect(await balanceOf(posAccountId), d('1000'));
    });
  });

  group('кэшбэк', () {
    test('начисляется от заплаченного, без бонусной части', () async {
      await seedCustomer(bonus: '200');
      final bonuses = _RecordingBonuses();
      payments = LocalPaymentService(
        db: db,
        checkout: checkout,
        sale: SaleUseCaseImpl(db: db, logger: Talker()),
        logger: Talker(),
        bonuses: bonuses,
        cardTerminal: terminal.charge,
        // Порт обязателен (задача 3): эти пробы про деньги, а не про
        // фискализацию, и «узла нет» здесь — сознательный выбор, а не
        // пропущенный довод. До задачи он получался молчанием.
        fiscal: const RefusingFiscalService(),
        drawer: drawerOpens,
      );
      final view = await receiptWith(quantity: 2); // 1000

      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('1000'),
          bonusUsed: d('200'),
          customerId: customerId,
        ),
        mv(view, 9),
      );

      // База начисления — 800, а не 1000: за бонусную часть кэшбэк
      // второй раз не начисляют.
      expect(bonuses.accruedOn, d('800'));
      expect(bonuses.phone, 77015550000);
    });

    test('упавшее начисление не отменяет оплату', () async {
      await seedCustomer();
      payments = LocalPaymentService(
        db: db,
        checkout: checkout,
        sale: SaleUseCaseImpl(db: db, logger: Talker()),
        logger: Talker(),
        bonuses: _RecordingBonuses(fail: true),
        cardTerminal: terminal.charge,
        // Порт обязателен (задача 3): эти пробы про деньги, а не про
        // фискализацию, и «узла нет» здесь — сознательный выбор, а не
        // пропущенный довод. До задачи он получался молчанием.
        fiscal: const RefusingFiscalService(),
        drawer: drawerOpens,
      );
      final view = await receiptWith(quantity: 2);

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('1000'),
          customerId: customerId,
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('1000'));
      expect(await balanceOf(posAccountId), d('1000'));
    });
  });

  group('продажа в долг', () {
    /// Тумблер кассы «Разрешить продажу в кредит» — задача 16.
    ///
    /// До неё `ThisPosEntries.sellInDebt` не читал никто, и долг проходил
    /// на кассе, где кредита нет вовсе. Теперь его читает
    /// `LocalPaymentService._requireDebtSoldHere`, и пробы **про сам
    /// долг** обязаны сказать, что торгуют в кредит здесь намеренно, —
    /// иначе они мерили бы новый отказ вместо старой беды. Что делает
    /// выключенный тумблер, проверяет
    /// `local_payment_service_debt_toggle_test.dart`.
    setUp(() async {
      await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
        const ThisPosEntriesCompanion(sellInDebt: Value(true)),
      );
    });

    test('остаток чека ложится на баланс покупателя', () async {
      await seedCustomer(balance: '0');
      final view = await receiptWith(quantity: 2); // 1000

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.debt,
          cashReceived: d('300'),
          customerId: customerId,
        ),
        mv(view, 9),
      );

      expect(outcome.paid, d('300'));
      expect(outcome.debt, d('700'));
      expect(await balanceOf(posAccountId), d('300'));
      expect(await balanceOf(agentMainAccountId), d('-700'));
    });

    test('в долг на неизвестного клиента — названный отказ', () async {
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.debt, customerId: 999),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payCustomerUnknownCode,
          ),
        ),
      );
    });

    test('в долг без покупателя — названный отказ', () async {
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.debt),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payDebtorRequiredCode,
          ),
        ),
      );
    });

    test('в долг покупателю без расчётного счёта — названный отказ', () async {
      await seedCustomer(main: null);
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.debt, customerId: customerId),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payDebtorAccountMissingCode,
          ),
        ),
      );
      // Ни товара, ни записи: долг, который некуда записать, не продажа.
      expect(await stockOf(100), d('100'));
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });
  });

  group('владелец и версия', () {
    test('чек соседнего рабочего места не оплачивается', () async {
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          8, // чужое рабочее место
          PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
          mv(view, 9),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payNotOwnerCode),
        ),
      );
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });

    test('оплата от устаревшей версии корзины отвергается', () async {
      final view = await receiptWith(quantity: 2);

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
          CartCommandMeta(
            key: 'k9',
            baseVersion: view.version - 1,
            receiptNo: view.receiptNo,
          ),
        ),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'cart_stale')),
      );
    });

    test('оплата чека, которого на кассе нет', () async {
      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash),
          m(9, 0, receiptNo: 4242),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payReceiptNotFoundCode,
          ),
        ),
      );
    });

    test('команда оплаты без номера чека', () async {
      await expectLater(
        payments.complete(7, PaymentRequest(type: PaymentType.cash), m(9, 0)),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payReceiptNotFoundCode,
          ),
        ),
      );
    });
  });

  group('счета и лояльность', () {
    test('счёт кассы идёт первым и помечен умолчанием', () async {
      final list = await payments.accounts();

      expect(list.first.id, posAccountId);
      expect(list.first.isDefault, isTrue);
      expect(
        list.map((a) => a.id),
        containsAllInOrder([posAccountId, bankAccountId]),
      );
      expect(list.where((a) => a.isDefault), hasLength(1));
    });

    test('клиент лояльности приходит с остатком бонуса', () async {
      await seedCustomer(bonus: '340');

      final found = await payments.findLoyalty('+7 701 555 00 00');

      expect(found, isNotNull);
      expect(found!.id, customerId);
      expect(found.name, 'Айгуль');
      expect(found.bonusBalance, d('340'));
    });

    test('клиент без бонусного счёта — остаток ноль, а не отказ', () async {
      // Ветка, которую прогон не касался до этой пробы: у клиента может
      // не быть бонусного счёта вовсе, и это обычное состояние картотеки,
      // а не поломка. Ноль здесь — настоящий остаток, а не умолчание «мы
      // не смогли прочитать».
      await seedCustomer(cashback: null);

      final found = await payments.findLoyalty('77015550000');

      expect(found, isNotNull);
      expect(found!.bonusBalance, Decimal.zero);
    });

    test('чужого номера нет — это ответ, а не отказ', () async {
      await seedCustomer();
      expect(await payments.findLoyalty('77019999999'), isNull);
      expect(await payments.findLoyalty('не номер'), isNull);
    });
  });

  group('карта', () {
    Future<void> bindTerminal(int terminalId) async {
      await db
          .into(db.terminals)
          .insert(
            TerminalsCompanion.insert(
              id: Value(terminalId),
              name: 'Касса-$terminalId',
              createdAt: 1000,
            ),
          );
      await db
          .into(db.terminalDeviceBindings)
          .insert(
            TerminalDeviceBindingsCompanion.insert(
              terminalId: terminalId,
              deviceClass: DeviceClass.paymentTerminal.name,
              profileId: 'payment.kaspi.pos',
              bindingKey: 'payment.kaspi.pos',
              parametersJson: const Value(
                '{"ipAddress":"10.0.0.5","port":"2000"}',
              ),
            ),
          );
    }

    test('без привязки — ручной путь карты, а не отказ', () async {
      final view = await receiptWith(quantity: 2);

      final charge = await payments.chargeCard(7, d('1000'), mv(view, 9));

      expect(charge.outcome, CardChargeOutcome.notConfigured);
      expect(terminal.calls, isEmpty);
    });

    // Задача 41: «терминала нет» и «привязка сломана» давали один и тот же
    // `null` из `_kaspiConfig`. Первое — законный ручной путь карты; второе —
    // ошибка настройки, на которой касса молча принимала код одобрения,
    // проверить который ей было нечем. Красные на `9ac079a5`: сломанная
    // привязка отдавала `notConfigured`, а завершение оплачивало чек.
    Future<void> bindBroken(int terminalId, {required bool twice}) async {
      await db
          .into(db.terminals)
          .insert(
            TerminalsCompanion.insert(
              id: Value(terminalId),
              name: 'Касса-$terminalId',
              createdAt: 1000,
            ),
          );
      for (var i = 0; i < (twice ? 2 : 1); i++) {
        await db
            .into(db.terminalDeviceBindings)
            .insert(
              TerminalDeviceBindingsCompanion.insert(
                terminalId: terminalId,
                deviceClass: DeviceClass.paymentTerminal.name,
                profileId: 'payment.kaspi.pos',
                bindingKey: 'payment.kaspi.pos#$i',
                // Две привязки — с адресом; одна — без адреса.
                parametersJson: Value(
                  twice
                      ? '{"ipAddress":"10.0.0.${5 + i}","port":"2000"}'
                      : '{"port":"2000"}',
                ),
              ),
            );
      }
    }

    test(
      'две привязки терминала — названный отказ, а не ручной путь',
      () async {
        await bindBroken(7, twice: true);
        final view = await receiptWith(quantity: 2);

        await expectLater(
          payments.chargeCard(7, d('1000'), mv(view, 9)),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'card_terminal_misconfigured',
            ),
          ),
        );
        expect(
          terminal.calls,
          isEmpty,
          reason: 'касса не выбирает терминал сама',
        );
      },
    );

    test(
      'привязка без адреса не пропускает код одобрения, введённый руками',
      () async {
        await bindBroken(7, twice: false);
        final view = await receiptWith(quantity: 2);

        await expectLater(
          payments.complete(
            7,
            PaymentRequest(type: PaymentType.card, approvalCode: '123456'),
            mv(view, 9),
          ),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'card_terminal_misconfigured',
            ),
          ),
        );
        expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      },
    );

    test('сумма больше стоимости чека в эквайринг не уходит', () async {
      await bindTerminal(7);
      final view = await receiptWith(quantity: 2); // 1000

      await expectLater(
        payments.chargeCard(7, d('1000.001'), mv(view, 9)),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payAmountExceedsReceiptCode,
          ),
        ),
      );
      expect(terminal.calls, isEmpty);

      // Ровно сумма чека — проходит. Правило нуля: потолок включает свою
      // границу, иначе «больше» и «равно» отвергались бы вместе.
      final ok = await payments.chargeCard(7, d('1000'), mv(view, 10));
      expect(ok.outcome, CardChargeOutcome.approved);
      expect(terminal.calls, [100000]);
    });

    test('повтор с тем же ключом не идёт в устройство второй раз', () async {
      await bindTerminal(7);
      final view = await receiptWith(quantity: 2);
      final meta = mv(view, 9);

      final first = await payments.chargeCard(7, d('500'), meta);
      final second = await payments.chargeCard(7, d('500'), meta);

      expect(terminal.calls, hasLength(1));
      expect(second.approvalCode, first.approvalCode);
      expect(second.transactionId, first.transactionId);
    });

    test('тот же ключ с другой суммой — это не повтор', () async {
      // C2 круга правки 1. Память ключевалась одним ключом команды и
      // отдавалась до всех проверок: запрос на 400 получал ответ **на
      // 1000**, к устройству не обращаясь. Ключ экрана мнётся один раз на
      // попытку и переживает и отказ завершения, и правку корзины.
      await bindTerminal(7);
      final view = await receiptWith(quantity: 2);
      final meta = mv(view, 9);

      final first = await payments.chargeCard(7, d('1000'), meta);
      final second = await payments.chargeCard(7, d('400'), meta);

      expect(terminal.calls, [100000, 40000]);
      expect(first.amount, d('1000'));
      expect(second.amount, d('400'));
    });

    test('тот же ключ на другом чеке — это не повтор', () async {
      // Вторая половина C2: чужое одобрение и чужая сумма доставались
      // следующему чеку. Достижимо экраном — ключ переживает смену чека.
      await bindTerminal(7);
      final first = await receiptWith(quantity: 2);
      final meta = mv(first, 9);
      await payments.chargeCard(7, d('1000'), meta);

      // Первый чек оплачен и закрыт, начат второй.
      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.card, approvalCode: '123456'),
        mv(first, 10),
      );
      final second = await receiptWith(quantity: 1);
      expect(second.receiptNo, isNot(first.receiptNo));

      await payments.chargeCard(
        7,
        d('500'),
        CartCommandMeta(
          key: 'k9',
          baseVersion: second.version,
          receiptNo: second.receiptNo,
        ),
      );

      expect(terminal.calls, [
        100000,
        50000,
      ], reason: 'второй чек получил одобрение и сумму от первого');
    });

    test(
      'код одобрения, которого касса не выдавала, не оплачивает чек',
      () async {
        // I5 круга правки 1: касса помнит проведение, но завершение его не
        // спрашивало — кадр с выдуманным кодом делал чек оплаченным без
        // единого обращения к эквайрингу.
        await bindTerminal(7);
        final view = await receiptWith(quantity: 2);

        await expectLater(
          payments.complete(
            7,
            PaymentRequest(type: PaymentType.card, approvalCode: '000000'),
            mv(view, 9),
          ),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              payChargeUnprovenCode,
            ),
          ),
        );

        expect(terminal.calls, isEmpty);
        expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      },
    );

    test('проведённая карта чек оплачивает', () async {
      // Страховка от вырождения: если бы проверка отвергала любой код,
      // проба выше проходила бы и ничего не сторожила.
      await bindTerminal(7);
      final view = await receiptWith(quantity: 2);
      final charge = await payments.chargeCard(7, d('1000'), mv(view, 9));

      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.card,
          approvalCode: charge.approvalCode,
          cardMask: charge.cardMask,
          transactionId: charge.transactionId,
        ),
        mv(view, 10),
      );

      expect(outcome.paid, d('1000'));
      expect(await balanceOf(bankAccountId), d('1000'));
    });

    test('проведение по чужому чеку этот чек не оплачивает', () async {
      // Круг правки 2: `_requireCardProof` сверял **только код
      // одобрения** — без чека, суммы и рабочего места, — хотя ключ
      // памяти составной именно ради этих трёх.
      //
      // **Первая версия этой пробы зеленела и под диверсией**, и это
      // важнее самой находки: она оплачивала первый чек, а оплата
      // снимает его записи (`_forgetCharges`) — доказательства не
      // оставалось вовсе, и отказ приходил не потому, что ключ
      // составной. Здесь оба чека живы, и разводит их только ключ:
      // проведение на 500 по чеку A на месте 7 против чека B на 1000 на
      // месте 8.
      await bindTerminal(7);
      await bindTerminal(8);
      final first = await receiptWith(quantity: 1); // 500, место 7
      final charge = await payments.chargeCard(7, d('500'), mv(first, 9));
      expect(charge.approvalCode, isNotNull);

      final second = await receiptWith(quantity: 2, terminalId: 8); // 1000
      expect(second.receiptNo, isNot(first.receiptNo));

      await expectLater(
        payments.complete(
          8,
          PaymentRequest(
            type: PaymentType.card,
            approvalCode: charge.approvalCode,
          ),
          mv(second, 11),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payChargeUnprovenCode,
          ),
        ),
      );
      expect(await balanceOf(bankAccountId), Decimal.zero);
      expect(await db.paymentDao.countBySale(second.receiptNo!, 1), 0);
    });

    test('проведение на другую сумму этот чек не оплачивает', () async {
      // Та же проба со стороны суммы: провели 500, а в чек записали бы
      // 1000 — разница ушла бы молча.
      await bindTerminal(7);
      final view = await receiptWith(quantity: 2); // 1000
      final charge = await payments.chargeCard(7, d('500'), mv(view, 9));

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(
            type: PaymentType.card,
            approvalCode: charge.approvalCode,
          ),
          mv(view, 10),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payChargeUnprovenCode,
          ),
        ),
      );
    });

    test(
      'без привязанного эквайринга код не проверяется — предел назван',
      () async {
        // Ручной путь карты: кассир проводит её на отдельном устройстве и
        // переписывает код. Доказательства у кассы нет ни в каком виде, и
        // отказ здесь недостижим — предел, а не упущение.
        final view = await receiptWith(quantity: 2);

        final outcome = await payments.complete(
          7,
          PaymentRequest(type: PaymentType.card, approvalCode: '000000'),
          mv(view, 9),
        );

        expect(outcome.paid, d('1000'));
      },
    );

    test('два одновременных одинаковых запроса — одно списание', () async {
      // **Проба на одновременность, а не на последовательность.** В этой
      // работе трижды выяснялось, что последовательные пробы гонок не
      // видят: память читалась, потом **ждала устройство**, и только
      // потом писалась — два одновременных запроса проходили лукап оба и
      // списывали карту дважды (`terminal.calls == [50000, 50000]`).
      await bindTerminal(7);
      final view = await receiptWith(quantity: 2);
      final meta = mv(view, 9);

      final both = await Future.wait([
        payments.chargeCard(7, d('500'), meta),
        payments.chargeCard(7, d('500'), meta),
      ]);

      expect(terminal.calls, [50000], reason: 'устройство позвали дважды');
      expect(both.first.approvalCode, both.last.approvalCode);
      expect(both.first.amount, d('500'));
      expect(both.last.amount, d('500'));
    });

    test('две одновременные разные суммы — два списания', () async {
      // Страховка от вырождения: закрыт **повтор**, а не всякая
      // одновременность. Разные суммы — разные платежи, и каждый обязан
      // дойти до устройства.
      await bindTerminal(7);
      final view = await receiptWith(quantity: 2);
      final meta = mv(view, 9);

      await Future.wait([
        payments.chargeCard(7, d('400'), meta),
        payments.chargeCard(7, d('600'), meta),
      ]);

      expect(terminal.calls..sort(), [40000, 60000]);
    });

    test('неудача устройства ключ навсегда не запирает', () async {
      // Обещание, кончившееся ошибкой, из памяти снимается — иначе одна
      // занятость терминала запирала бы ключ до перезапуска кассы.
      await bindTerminal(7);
      terminal.throwOnce = true;
      final view = await receiptWith(quantity: 2);
      final meta = mv(view, 9);

      await expectLater(
        payments.chargeCard(7, d('500'), meta),
        throwsA(isA<Exception>()),
      );

      final second = await payments.chargeCard(7, d('500'), meta);
      expect(second.outcome, CardChargeOutcome.approved);
      expect(terminal.calls, hasLength(2));
    });

    test('отказ терминала запоминается тем же ключом', () async {
      await bindTerminal(7);
      terminal.decline = true;
      final view = await receiptWith(quantity: 2);
      final meta = mv(view, 9);

      final first = await payments.chargeCard(7, d('500'), meta);
      final second = await payments.chargeCard(7, d('500'), meta);

      expect(first.outcome, CardChargeOutcome.declined);
      expect(second.outcome, CardChargeOutcome.declined);
      expect(terminal.calls, hasLength(1));
    });

    test('карта без чека в работе — названный отказ', () async {
      await bindTerminal(7);

      await expectLater(
        payments.chargeCard(7, d('500'), m(9, 0)),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payReceiptNotFoundCode,
          ),
        ),
      );
    });
  });

  // Потолок возраста смены — `shift_over_age_on_till_test.dart` (задача 27):
  // порта смены у службы больше нет, и пробы строят её без него.

  group('ненастроенная касса', () {
    test('отказ приходит значением, а не броском из глубины', () async {
      await db.delete(db.thisPosEntries).go();

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash),
          m(9, 0, receiptNo: 1),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            'till_not_configured',
          ),
        ),
      );
    });
  });
}

/// Смена, которая отвечает про свой возраст то, что ей велели.
/// Бонусная программа, которая ничего не начисляет и всё запоминает.
class _RecordingBonuses implements BonusService {
  _RecordingBonuses({this.fail = false});

  final bool fail;
  Decimal? accruedOn;
  int? phone;

  @override
  Future<BonusAccrualResult> accrualBonuses({
    required int phone,
    required Decimal saleAmount,
    required int saleReceiptNo,
  }) async {
    this.phone = phone;
    accruedOn = saleAmount;
    if (fail) throw const NoInternetConnectionException();
    return BonusAccrualResult(
      success: true,
      transactionId: 'tx',
      accruedAmount: Decimal.zero,
      newBalance: Decimal.zero,
    );
  }

  @override
  Future<BonusBalance> getBonusBalance(int phone) => throw UnimplementedError();
}

/// Драйвер платёжного терминала, который ничего не открывает и всё
/// запоминает.
class _RecordingCardTerminal {
  final calls = <int>[];
  bool decline = false;

  /// Одна неудача обращения к устройству — «терминал занят».
  bool throwOnce = false;

  Future<CardCharge> charge(
    KaspiPosConfig config, {
    required int amountTiyn,
    required String receiptNo,
  }) async {
    calls.add(amountTiyn);
    // Ожидание настоящее: без него обе половины одновременной пробы
    // выполнились бы по очереди и гонки не показали бы.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (throwOnce) {
      throwOnce = false;
      throw Exception('терминал занят');
    }
    if (decline) {
      return const CardCharge(
        outcome: CardChargeOutcome.declined,
        message: 'отказ банка',
      );
    }
    return const CardCharge(
      outcome: CardChargeOutcome.approved,
      approvalCode: '123456',
      cardMask: '**** 4242',
      transactionId: 'tx-1',
    );
  }
}
