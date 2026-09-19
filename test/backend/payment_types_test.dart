/// Виды оплаты — свойство рабочего места (задача 15 плана «Продажа с
/// браузерного терминала»).
///
/// Решение заказчика №5 дословно: «Виды оплаты — настройка терминала:
/// планшет у кассы берёт всё, в зале — только безнал. **Отказ приходит от
/// кассы, а не спрятанной кнопкой.**»
///
/// Отсюда устройство этого набора: подделки `PaymentService` здесь **нет**.
/// Проба, где отказ бросает подделка, доказывала бы только то, что подделка
/// умеет бросать. Здесь стоит настоящая касса — настоящая база drift,
/// настоящая `LocalCartService`, настоящая подготовка чека, настоящий
/// `SaleUseCaseImpl`, настоящий `LocalPaymentService` и настоящие
/// `TillOperations`, — и кадры входят в неё тем же путём, каким входит
/// кадр из браузера: `ops.askHandlers[...](body, sessionKey)`. Экрана в
/// этом наборе нет вовсе, и это главное: спрятать кнопку он не может даже
/// теоретически.
///
/// Проверяются три разных утверждения, а не одно трижды:
///
/// 1. **пустое множество значит «все»** — иначе миграция онемила бы каждый
///    существующий терминал;
/// 2. **запрет запирает ровно названное** — терминал с `{card}` платит
///    картой, счета и лояльность у него работают, а наличные получают
///    отказ названным кодом;
/// 3. **половина смешанной оплаты не теряется молча** — запрещённая
///    наличная часть отвергает **всю** команду, а не проходит с
///    обнулённой половиной.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/terminal_wire.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/noop_auth.dart';
import '../helpers/cash_drawer.dart';

const _barcode = '4870001234567';
const _sessionKey = 42;

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late TerminalRepository terminals;
  late TillOperations ops;
  late int selfTerminalId;
  late PairingInvites invites;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  /// Чек на 1000 (две штуки по 500), набранный **кассой** на рабочем месте
  /// сеанса.
  Future<CartView> receipt() async {
    var view = await cart.start(
      terminalId: selfTerminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(selfTerminalId, _barcode, mv(view, 2));
    return cart.setQuantity(
      selfTerminalId,
      view.lines.single.id,
      d('2'),
      mv(view, 3),
    );
  }

  Map<String, Object?> body(
    CartView view, {
    required String type,
    String? cashReceived,
    String? cardAmount,
    int? customerId,
    String key = 'k9',
  }) => {
    'type': type,
    if (cashReceived != null) 'cashReceived': cashReceived,
    if (cardAmount != null) 'cardAmount': cardAmount,
    if (customerId != null) 'customerId': customerId,
    'key': key,
    'baseVersion': view.version,
    'receiptNo': view.receiptNo,
  };

  Future<Map<String, Object?>> complete(Map<String, Object?> frame) =>
      ops.askHandlers[PayOps.complete.name]!(frame, _sessionKey);

  Future<Terminal> self() async =>
      (await terminals.list()).firstWhere((t) => t.id == selfTerminalId);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
      // Порт обязателен (задача 3). Проба про виды оплаты на проводе, а не
      // про фискализацию: узла здесь нет, и это сказано, а не забыто.
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    terminals = LocalTerminalRepository(db);
    invites = PairingInvites();

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(11),
            cashBoxName: Value('Касса-1'),
            // Задача 16 завела тумблер кассы «продажа в кредит», и с
            // выключенным долг отбивается **до** набора видов. Этот файл
            // — про наборы видов рабочего места; выключенный тумблер
            // подменил бы его предмет и покрасил бы пробы про долг
            // отказом не о том. Что делает выключенный, проверяет
            // `test/data/sale/local_payment_service_debt_toggle_test.dart`.
            sellInDebt: Value(true),
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
            id: const Value(11),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(12),
            type: AccountType.customBank,
            name: const Value('Банк'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            name: 'Товар',
            type: 0,
            measure: 0,
            quantity: Value(Decimal.fromInt(100)),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            sellingPrice: Value(Decimal.fromInt(500)),
          ),
        );

    ops = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: terminals,
      deviceBindings: _NoBindings(),
      auth: NoopAuth(),
      invites: invites,
      payments: payments,
    );
    // Тем же путём, каким называет себя настоящая вкладка: рабочее место
    // касса берёт из сеанса, а не из тела кадра. Путь — `terminals.register`
    // с одноразовым кодом: запись в `_sessionTerminals` из
    // `terminals.selfEnsure` вырезана задачей 19 (она открывала строку самой
    // кассы любой сессии), и с ним осталось два писателя — регистрация и
    // возврат по секрету.
    final bound = await ops.askHandlers[TillOps.terminalRegister.name]!({
      'name': 'Вкладка',
      'code': invites.mint().code,
    }, _sessionKey);
    selfTerminalId = (bound['terminal']! as Map<String, Object?>)['id']! as int;
  });

  tearDown(() => db.close());

  group('пустое множество означает «все»', () {
    test(
      'терминал, которому видов не назначали, немым не становится',
      () async {
        // Ровно то, чем миграция v37 → v38 оставляет каждую существующую
        // строку: колонка пуста. Пустое множество обязано значить «все» —
        // иначе установка, поднявшаяся на новую версию, перестала бы
        // принимать деньги вовсе.
        final terminal = await self();

        expect(terminal.allowedPaymentTypes, isEmpty);
        for (final type in PaymentType.values) {
          expect(terminal.allows(type), isTrue, reason: type.name);
        }
      },
    );

    test('с пустым множеством проходят наличные', () async {
      final view = await receipt();

      final answer = await complete(
        body(view, type: 'cash', cashReceived: '5000'),
      );

      expect(saleOutcomeFromWireJson(answer).change, d('4000'));
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 1);
    });

    test('с пустым множеством проходит карта', () async {
      final view = await receipt();

      final answer = await complete(body(view, type: 'card'));

      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
    });

    test('с пустым множеством проходит смешанная', () async {
      final view = await receipt();

      final answer = await complete(
        body(view, type: 'mixed', cardAmount: '400', cashReceived: '600'),
      );

      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 2);
    });

    test('с пустым множеством долг доходит до проверок самого долга', () async {
      // Не «долг проходит» — у него свои требования (покупатель, счёт), и
      // они здесь не предмет. Предмет в том, что вид оплаты его **не
      // остановил**: отказ пришёл от долга, а не от набора видов.
      final view = await receipt();

      await expectLater(
        complete(body(view, type: 'debt')),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payDebtorRequiredCode,
          ),
        ),
      );
    });
  });

  group('отказ приходит от кассы', () {
    test('терминал без права на наличные получает отказ от кассы', () async {
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      await expectLater(
        complete(body(view, type: 'cash', cashReceived: '5000')),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payTypeNotAllowedCode,
          ),
        ),
      );
      // Отказ обязан быть **до денег**: ни платежа, ни закрытого чека.
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      final sale = await db.saleDao.findByKey(view.receiptNo!, 1);
      expect(sale!.state, 0);
    });

    test('после отказа по виду чек цел и платится законным видом', () async {
      // Круг правки 4. Прежде это стояло в отчёте **пределом** — «ни одна
      // проба не смотрит на состояние чека после такого отказа», — и
      // формулировка была неточной вдвойне: состояние и ноль платежей
      // проверяют две пробы выше, а непокрыто было другое — **сумма чека**
      // и то, что законное завершение после отказа проходит на ту же сумму.
      // Отказ приходит после `_checkout.prepare`, которая успела снять
      // платежи прошлой попытки, переписать цены строк и `sales.amount`;
      // проба и держит утверждение, что переписала она их в те же числа.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      // **Смешанная, а не наличные, и это существенно.** Наличные на
      // `{card}` отбивает **первая** проверка — до `_checkout.prepare`, то
      // есть до единственных записей, о целости которых проба и говорит.
      // Первая её редакция звала именно наличные и потому мимо предмета
      // проходила: диверсия, портившая сумму в подготовке, оставляла её
      // зелёной. Смешанная с наличной половиной проходит первую проверку
      // (смешанная не тендер), доходит до подготовки и отбивается **после**
      // неё — по составным частям.
      await expectLater(
        complete(
          body(
            view,
            type: 'mixed',
            cardAmount: '400',
            cashReceived: '600',
            key: 'k1',
          ),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payTypeNotAllowedCode,
          ),
        ),
      );

      final afterRefusal = await db.saleDao.findByKey(view.receiptNo!, 1);
      expect(afterRefusal!.state, 0);
      expect(afterRefusal.amount, d('1000'), reason: 'сумма чека не тронута');
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);

      // И главное: чек не «подготовлен наполовину» — законный вид платится
      // на ту же сумму, тем же чеком.
      final answer = await complete(body(view, type: 'card', key: 'k2'));
      expect(saleOutcomeFromWireJson(answer).amount, d('1000'));
      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 1);
    });

    test(
      'терминал с {card} платит картой — запрет не шире названного',
      () async {
        await terminals.setAllowedPaymentTypes(selfTerminalId, {
          PaymentType.card,
        });
        final view = await receipt();

        final answer = await complete(body(view, type: 'card'));

        expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
      },
    );

    test('pay.card на терминале без карты — отказ тем же кодом', () async {
      // Вторая денежная операция, которой отказ положен: проведение карты
      // через эквайринг — это оплата картой, чем бы её ни назвали в теле.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.cash,
      });
      await receipt();

      await expectLater(
        ops.askHandlers[PayOps.card.name]!({
          'amount': '500',
          'key': 'k9',
          'baseVersion': 3,
          'receiptNo': 9,
        }, _sessionKey),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payTypeNotAllowedCode,
          ),
        ),
      );
    });

    test('долг набором не сторожится и на наличном терминале тоже', () async {
      // Круг правки 2 перевернул эту пробу, и это не откат, а решение:
      // долг убран из словаря видов, потому что его уже сторожит право
      // `op.sellDebt`. Проба осталась, чтобы решение было видно с **обеих**
      // сторон — и на `{cash}`, и на `{card}` (соседняя проба) долг
      // проходит мимо набора и упирается в свои требования.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.cash,
      });
      final view = await receipt();

      await expectLater(
        complete(body(view, type: 'debt')),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payDebtorRequiredCode,
          ),
        ),
      );
    });
  });

  group('смешанная оплата не теряет половину молча', () {
    test('запрещённая наличная часть отвергает всю команду', () async {
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      await expectLater(
        complete(
          body(view, type: 'mixed', cardAmount: '400', cashReceived: '600'),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payTypeNotAllowedCode,
          ),
        ),
      );
      // Ни одной половины: ни карты на 400, ни чего-либо ещё.
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      final sale = await db.saleDao.findByKey(view.receiptNo!, 1);
      expect(sale!.state, 0);
    });

    test(
      'смешанная, у которой наличной половины нет, наличных не требует',
      () async {
        // Граница, ради которой составные части берутся из расчёта кассы, а
        // не из полей заявки: карта покрывает чек целиком, наличная часть —
        // ноль, и требовать `cash` было бы запретом шире названного.
        await terminals.setAllowedPaymentTypes(selfTerminalId, {
          PaymentType.card,
        });
        final view = await receipt();

        final answer = await complete(
          body(view, type: 'mixed', cardAmount: '1000', cashReceived: '0'),
        );

        expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
        expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 1);
      },
    );

    test('оплата картой не запирается забытым в кадре cashReceived', () async {
      // `PaymentType.card` не читает `cashReceived` вовсе (`_plan`), а экран
      // вполне может оставить прошлое число в поле. Проверка по полям
      // заявки отказала бы здесь — то есть заперла бы карту на терминале,
      // которому карта разрешена.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      final answer = await complete(
        body(view, type: 'card', cashReceived: '5000'),
      );

      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
      expect(saleOutcomeFromWireJson(answer).change, d('0'));
    });

    test('наличная половина в одну десятую тенге — всё ещё наличные', () async {
      // Граница `> Decimal.zero` на значении, где `double` уже врёт:
      // 1000 - 999.9 в двоичной плавающей даёт 0.09999999999999432, а
      // сравнение с нулём здесь решает, отказать или взять деньги.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      await expectLater(
        complete(
          body(view, type: 'mixed', cardAmount: '999.9', cashReceived: '0.1'),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payTypeNotAllowedCode,
          ),
        ),
      );
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });

    test('смешанной с нехваткой наличных касса не платит', () async {
      // Круг правки 3. Ветвь смешанной в проверке достаточности не
      // сторожилась **ничем**: разбор удалил её и получил всё дерево на тех
      // же двенадцати красных. Пробел старше круга 2, но круг 2 эту строку
      // перенёс и переписал — то есть правка была закрыта кодом без пробы.
      //
      // Цена, если сломается: чек закрывается, записав наличный платёж
      // **больше того, что кассиру дали в руки**. Ограничений на терминале
      // нет нарочно — предмет пробы достаточность, а не вид оплаты.
      final view = await receipt();

      await expectLater(
        complete(
          body(view, type: 'mixed', cardAmount: '400', cashReceived: '500'),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', payInsufficientCode),
        ),
      );
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      final sale = await db.saleDao.findByKey(view.receiptNo!, 1);
      expect(sale!.state, 0, reason: 'чек остаётся в работе, а не закрывается');
    });

    test('наличных ровно столько, сколько нужно, — оплата проходит', () async {
      // Страховка от вырождения соседней пробы: если бы смешанная не
      // проходила вовсе, отказ выше ничего не доказывал бы про нехватку.
      final view = await receipt();

      final answer = await complete(
        body(view, type: 'mixed', cardAmount: '400', cashReceived: '600'),
      );

      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
      expect(saleOutcomeFromWireJson(answer).change, d('0'));
    });

    test(
      'зеркальный случай: {cash} и смешанная с картой — вид, а не нехватка',
      () async {
        // Пара к пробе «отказ по смешанной называет вид»: та проверяла
        // `{card}` с наличной половиной, эта — `{cash}` с безналичной. Сумма
        // наличных нарочно мала: до правки круга 2 нехватка отбивала бы кадр
        // раньше, чем дело дошло бы до вида.
        await terminals.setAllowedPaymentTypes(selfTerminalId, {
          PaymentType.cash,
        });
        final view = await receipt();

        await expectLater(
          complete(
            body(view, type: 'mixed', cardAmount: '400', cashReceived: '100'),
          ),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              payTypeNotAllowedCode,
            ),
          ),
        );
      },
    );

    test('разрешённые обе половины проходят', () async {
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.cash,
        PaymentType.card,
      });
      final view = await receipt();

      final answer = await complete(
        body(view, type: 'mixed', cardAmount: '400', cashReceived: '600'),
      );

      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 2);
    });
  });

  group('mixed — форма, а не тендер (круг правки 1)', () {
    test('набор {mixed} не собирается — иначе рабочее место немеет', () async {
      // Разбор круга 1: `{mixed}` отбивал наличные и карту второй
      // проверкой, а карту, долг и наличные — первой. То есть «запретить
      // всё» этим полем было **возможно**, вопреки трижды обещанному
      // обратному, и достижимо с экрана одним снятием галочки.
      await expectLater(
        terminals.setAllowedPaymentTypes(selfTerminalId, {PaymentType.mixed}),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect((await self()).allowedPaymentTypes, isEmpty);
    });

    test('и по проводу тоже — отказ, а не немой терминал', () async {
      await expectLater(
        ops.askHandlers[TillOps.terminalSetPaymentTypes.name]!({
          'terminalId': selfTerminalId,
          'allowedPaymentTypes': ['card', 'mixed'],
        }, _sessionKey),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect((await self()).allowedPaymentTypes, isEmpty);
    });

    test('{card} проводит смешанную с нулевой наличной половиной', () async {
      // Дословный случай заказчика: «в зале — только безнал». Смешанная,
      // вся ушедшая на карту, — это оплата картой, и запирать её незачем.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      final answer = await complete(
        body(view, type: 'mixed', cardAmount: '1000', cashReceived: '0'),
      );

      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
    });

    test('{card} отвергает смешанную с ненулевой наличной половиной', () async {
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      await expectLater(
        complete(
          body(view, type: 'mixed', cardAmount: '400', cashReceived: '600'),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payTypeNotAllowedCode,
          ),
        ),
      );
      expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
    });

    test('pay.card и pay.complete согласны между собой', () async {
      // Худшее из трёх следствий разбора: на `{card}` касса **пропускала**
      // `pay.card` (дошла до устройства), а `complete(type: mixed)` затем
      // отказывала по виду — карта списана, чек завершить нельзя
      // (`card_charge_unsettled`). Здесь обе операции проходят: то, что
      // касса пропустила к устройству, она обязана дать и завершить.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      final charge = cardChargeFromWireJson(
        await ops.askHandlers[PayOps.card.name]!({
          'amount': '1000',
          'key': 'kc',
          'baseVersion': view.version,
          'receiptNo': view.receiptNo,
        }, _sessionKey),
      );
      // Эквайринга к рабочему месту не привязано — ручной путь карты; для
      // вопроса «согласны ли операции» это ровно то же самое: касса не
      // отбила проведение по виду оплаты.
      expect(charge.outcome, CardChargeOutcome.notConfigured);

      final answer = await complete(
        body(view, type: 'mixed', cardAmount: '1000', cashReceived: '0'),
      );
      expect(saleOutcomeFromWireJson(answer).paid, d('1000'));
    });

    test(
      'набор {debt} не собирается — тот же дефект на соседней галочке',
      () async {
        // Круг правки 2. `{debt}` собирал рабочее место, которое **не берёт ни
        // одного тенге** ни с кого, кроме заведённого должника со счётом:
        // наличные, карта и обе смешанные отбивались по виду, а долг доходил
        // до `debt_customer_required`. С экрана — два нажатия из умолчания
        // `{card}`: поставить «В долг», снять «Карта»; сторож «последнюю не
        // снять» пропускал, множество ведь непусто.
        await expectLater(
          terminals.setAllowedPaymentTypes(selfTerminalId, {PaymentType.debt}),
          throwsA(
            isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
          ),
        );
        await expectLater(
          terminals.setAllowedPaymentTypes(selfTerminalId, {
            PaymentType.card,
            PaymentType.debt,
          }),
          throwsA(
            isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
          ),
        );
        expect((await self()).allowedPaymentTypes, isEmpty);
      },
    );

    test('долг сторожит право, а не набор видов', () async {
      // Решение круга 2: долг из словаря убран, потому что он **уже**
      // загорожен `op.sellDebt` (`payExtraPermissions`, проверяется сторожем
      // по телу кадра до вызова обработчика). Третий способ запретить одно и
      // то же — это параллельный механизм, которого проект не держит.
      //
      // Следствие названо прямо: на `{card}` долг **проходит** мимо набора и
      // упирается в свои собственные требования. Кому долг в зале не нужен —
      // снимает `op.sellDebt` у тех, кто там работает.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      await expectLater(
        complete(body(view, type: 'debt')),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payDebtorRequiredCode,
          ),
        ),
      );
    });

    test(
      'перебор всех семи непустых наборов настоящей оплатой: немого рабочего '
      'места не собрать',
      () async {
        // Круг правки 2. Прежняя проба этого имени была **теоремой, а не
        // измерением**: она брала три одноэлементных набора и спрашивала
        // `tenderPaymentTypes.where(terminal.allows).isNotEmpty` — верно по
        // построению для любого непустого подмножества, и денег не двигало
        // вовсе. Разбор показал её зелёной в мире, где `{mixed}` отбивал все
        // четыре вида, — то есть ровно в том мире, который она объявляла
        // невозможным.
        //
        // Здесь перебираются **все семь** непустых подмножеств трёх видов,
        // которыми чек вообще можно закрыть, и по каждому идёт **настоящая
        // оплата** через обработчик кассы. Утверждение одно: набор, который
        // касса согласилась записать, обязан оставить хотя бы один способ
        // действительно взять деньги — платёж в базе, не ответ «ок».
        final all = [PaymentType.cash, PaymentType.card, PaymentType.debt];
        var key = 100;

        Future<bool> takesMoney(PaymentType tender) async {
          final view = await receipt();
          try {
            final answer = await complete(
              body(
                view,
                type: tender.name,
                cashReceived: tender == PaymentType.cash ? '5000' : null,
                key: 'k${key++}',
              ),
            );
            return saleOutcomeFromWireJson(answer).paid > Decimal.zero &&
                await db.paymentDao.countBySale(view.receiptNo!, 1) > 0;
          } on WireRefusal {
            return false;
          }
        }

        for (var mask = 1; mask < 8; mask++) {
          final subset = <PaymentType>{
            for (var bit = 0; bit < all.length; bit++)
              if (mask & (1 << bit) != 0) all[bit],
          };
          final label = paymentTypeNames(subset).join(',');

          var stored = true;
          try {
            await terminals.setAllowedPaymentTypes(selfTerminalId, subset);
          } on WireRefusal catch (refusal) {
            expect(refusal.code, 'bad_request', reason: label);
            stored = false;
          }
          // Набор, который касса записать отказалась, немым сделать не может
          // — проверять по нему нечего.
          if (!stored) continue;

          final taking = <PaymentType>[];
          for (final tender in subset) {
            if (await takesMoney(tender)) taking.add(tender);
          }
          expect(
            taking,
            isNotEmpty,
            reason:
                'набор {$label} записался и не оставил ни одного способа взять '
                'деньги — это немое рабочее место',
          );
        }
      },
    );

    test('отказ по смешанной называет вид, а не нехватку наличных', () async {
      // Круг правки 2. `{card}` плюс смешанная на 400 картой и ноль
      // наличными отвечала `payment_insufficient`: `_plan` считал наличную
      // половину (600) и бросал нехватку **раньше**, чем дело доходило до
      // проверки вида. Кассиру говорили «наличных меньше суммы» на
      // терминале, которому наличные запрещены вовсе.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      final view = await receipt();

      await expectLater(
        complete(body(view, type: 'mixed', cardAmount: '400')),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payTypeNotAllowedCode,
          ),
        ),
      );
    });
  });

  group('запрет не запирает лишнего', () {
    test('счета, лояльность и бонус вида оплаты не спрашивают', () async {
      // Три из пяти денежных операций отказу по виду оплаты не подлежат, и
      // это не упущение: счёт — не вид оплаты (терминалу с одной картой
      // список счетов нужен ровно так же), поиск клиента лояльности вида
      // оплаты не касается вовсе, а бонус — не член `PaymentType`: он
      // сопровождает любой вид, и отказывать по нему было бы отказом по
      // виду, которого не существует.
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });

      final accounts = accountsFromWireJson(
        await ops.askHandlers[PayOps.accounts.name]!(const {}, _sessionKey),
      );
      expect(accounts, isNotEmpty);

      expect(
        loyaltyFromWireJson(
          await ops.askHandlers[PayOps.loyalty.name]!({
            'phone': '77019999999',
          }, _sessionKey),
        ),
        isNull,
      );

      await expectLater(
        ops.askHandlers[PayOps.bonus.name]!({
          'customerId': 5,
          'amount': '100',
        }, _sessionKey),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            payCustomerUnknownCode,
          ),
        ),
        reason: 'отказ по картотеке, а не по виду оплаты',
      );
    });
  });

  group('набор переживает запись и провод', () {
    test('назначенный набор читается обратно', () async {
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.cash,
        PaymentType.card,
      });

      expect((await self()).allowedPaymentTypes, {
        PaymentType.cash,
        PaymentType.card,
      });
    });

    test('пустой набор возвращает терминалу все виды', () async {
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });
      await terminals.setAllowedPaymentTypes(selfTerminalId, const {});

      final terminal = await self();
      expect(terminal.allowedPaymentTypes, isEmpty);
      expect(terminal.allows(PaymentType.cash), isTrue);
    });

    test('набор переживает круг по проводу', () async {
      const terminal = Terminal(
        id: 7,
        name: 'Планшет в зале',
        pointMode: PointMode.cashier,
        allowedPaymentTypes: {PaymentType.card},
      );

      final back = terminalFromWireJson(
        terminalToWireJson(terminal).cast<String, dynamic>(),
      );

      expect(back.allowedPaymentTypes, {PaymentType.card});
      expect(back.allows(PaymentType.cash), isFalse);
    });

    test('операция провода назначает набор на кассе', () async {
      await ops.askHandlers[TillOps.terminalSetPaymentTypes.name]!({
        'terminalId': selfTerminalId,
        'allowedPaymentTypes': ['card'],
      }, _sessionKey);

      expect((await self()).allowedPaymentTypes, {PaymentType.card});
    });

    test('кадр без набора — отказ, а не молчаливое снятие запрета', () async {
      // Находка прохода `anti-gaps`. На чтении отсутствующий набор —
      // законное «пусто» (касса старше задачи 15 поля не шлёт), но на
      // записи то же умолчание сняло бы с рабочего места весь запрет из-за
      // опечатки клиента — и ответило бы «ok». Снять ограничение можно
      // только назвав это вслух: пустым списком (проба ниже).
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });

      await expectLater(
        ops.askHandlers[TillOps.terminalSetPaymentTypes.name]!({
          'terminalId': selfTerminalId,
        }, _sessionKey),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect((await self()).allowedPaymentTypes, {PaymentType.card});
    });

    test('пустой список снимает запрет — и это законный путь', () async {
      await terminals.setAllowedPaymentTypes(selfTerminalId, {
        PaymentType.card,
      });

      await ops.askHandlers[TillOps.terminalSetPaymentTypes.name]!({
        'terminalId': selfTerminalId,
        'allowedPaymentTypes': <String>[],
      }, _sessionKey);

      expect((await self()).allowedPaymentTypes, isEmpty);
    });

    test(
      'запрет ложится на названное рабочее место, а не на соседнее',
      () async {
        // Правило нуля из `qa-depth` наоборот: в базе есть строка, которой
        // здесь быть **не должно** — и проверяется, что её не тронули.
        final enrolment = await terminals.register(name: 'Планшет в зале');
        final other = enrolment.terminal.id;

        await terminals.setAllowedPaymentTypes(other, {PaymentType.card});

        expect((await self()).allowedPaymentTypes, isEmpty);
        final neighbour = (await terminals.list()).firstWhere(
          (t) => t.id == other,
        );
        expect(neighbour.allowedPaymentTypes, {PaymentType.card});
        expect(neighbour.allows(PaymentType.cash), isFalse);
      },
    );

    test(
      'несуществующее рабочее место — отказ, а не запись в никуда',
      () async {
        await expectLater(
          terminals.setAllowedPaymentTypes(9999, {PaymentType.card}),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'unknown_terminal',
            ),
          ),
        );
      },
    );
  });

  group('незнакомое имя вида не превращается в «все»', () {
    test(
      'строка с неизвестным именем — отказ, а не тихое расширение',
      () async {
        // Ловушка, ради которой здесь отказ, а не «выбросить незнакомое»:
        // пустое множество значит «все». Терминал, которому более новая
        // версия записала единственный вид, этой версии неизвестный, при
        // молчаливом выбрасывании получил бы **пустое** множество — то есть
        // разрешение на всё, включая ровно то, что ему запрещали.
        await db.customStatement(
          "UPDATE terminals SET allowed_payment_types = 'crypto' WHERE id = ?",
          [selfTerminalId],
        );

        expect(() => terminals.list(), throwsA(isA<StateError>()));
      },
    );
  });
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoBindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}
