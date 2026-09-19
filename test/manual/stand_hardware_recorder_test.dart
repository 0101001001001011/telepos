/// Записывающие заглушки железа стенда — проверка, что они записывают
/// **настоящую продажу**, а не факт вызова и не константу.
///
/// # Зачем эта проба, если заглушки живут в стенде
///
/// Стенд драйвит человек из браузера, и доказать там нечего: журнал непуст —
/// значит ли это, что в нём верный чек? Заглушка, записывающая постоянный
/// номер, дала бы непустой журнал на любой продаже, и приёмка сценария 6
/// прошла бы зелёной ровно так же, как проходила с `null`. Это был бы второй
/// ложный зелёный на месте первого.
///
/// Поэтому все сверки здесь — **против базы кассы**, а не против литералов:
/// номер чека, сумма и состав берутся из строк `Sales`/`SaleProducts`,
/// которые записал настоящий `SaleUseCaseImpl`, и сравниваются с тем, что
/// заглушка записала у себя. Заглушка, отвечающая константой, красит эту
/// пробу немедленно — проверено сломом, см. отчёт задачи 21.
///
/// # Чего эта проба НЕ доказывает
///
/// Того же, чего не доказывают сами заглушки: что чек напечатался и что ОФД
/// принял документ. Здесь нет ни принтера, ни оператора. Доказывается ровно
/// одно — **касса собрала документ по своей же базе и отдала его своему
/// порту**, то есть решение заказчика №1 («железо и база остаются кассой»)
/// исполняется, а не декларируется.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

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
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';

import 'stand_hardware_recorder.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late StandHardwareJournal hardware;

  const barcode = '4870001234567';
  const posAccountId = 11;
  const terminalId = 7;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  /// Чек «Молоко 3.2%» × 2 по 500 — тот же состав, что засеян на стенде,
  /// чтобы читаемое в приёмке и проверяемое здесь были одним чеком.
  Future<CartView> receipt() async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(terminalId, barcode, mv(view, 2));
    view = await cart.setQuantity(
      terminalId,
      view.lines.single.id,
      d('2'),
      mv(view, 3),
    );
    return view;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            cashBoxName: Value('POS-1'),
            companyName: Value('Магазин Приёмка'),
          ),
        );
    await db
        .into(db.users)
        .insert(
          const UsersCompanion(id: Value(1), name: Value('Кассир С PIN')),
        );
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: Value(1),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(barcode),
            name: 'Молоко 3.2%',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(barcode),
            sellingPrice: Value(d('500')),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(posAccountId),
            type: AccountType.pos,
            value: Value(Decimal.zero),
          ),
        );

    final logger = Talker();
    // `echo: false` — журнал читается возвратом, а не консолью; на стенде
    // он, наоборот, печатается.
    hardware = StandHardwareJournal(echo: false);
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
      fiscal: RecordingFiscalService(hardware),
      fiscalQueue: RecordingFiscalQueueStore(hardware),
      printer: RecordingPrinter(hardware),
      drawer: () => recordingDrawer(hardware),
    );
  });

  tearDown(() async {
    // Печать уходит `unawaited` — недоигранная уронила бы следующую пробу
    // чужим «database closed».
    await payments.pendingSideEffects;
    await db.close();
  });

  test('журнал пуст, пока продажи не было', () async {
    expect(hardware.entries, isEmpty);
  });

  test('оператор и принтер получают ТОТ ЖЕ чек, что лёг в базу', () async {
    final view = await receipt();
    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );
    await payments.pendingSideEffects;

    // Истина — строка кассы, а не литерал: если заглушка запишет константу,
    // именно это сравнение и покраснеет.
    final sale = (await db.saleDao.findByKey(outcome.receiptNo, 1))!;
    final soldLines = await db.saleProductDao.findBySale(outcome.receiptNo, 1);

    final fiscalCalls = hardware.of('fiscal');
    expect(fiscalCalls, hasLength(1), reason: 'оператора зовут ровно раз');
    final f = fiscalCalls.single;
    expect(f['call'], 'fiscalizeSale');
    expect(f['receiptNo'], sale.receiptNo);
    expect(f['posId'], sale.posId);
    expect(f['amount'], sale.amount.toString());
    // Наличная продажа: вся сумма наличными, картой — ноль. Разбивку
    // считает касса по счетам получателей, а не заявка терминала.
    expect(f['cashAmount'], sale.amount.toString());
    expect(f['cardAmount'], Decimal.zero.toString());
    expect(f['customerBinGiven'], isFalse);

    final printCalls = hardware.of('printer');
    expect(printCalls, hasLength(1), reason: 'печать отправляется ровно раз');
    final p = printCalls.single;
    expect(p['call'], 'printSaleReceipt');
    expect(p['receiptNo'], sale.receiptNo);
    expect(p['posId'], sale.posId);
    expect(p['totalAmount'], sale.amount.toString());

    // Состав на бумаге — тот же, что продан.
    final printed = (p['products']! as List).cast<Map<String, Object?>>();
    expect(printed, hasLength(soldLines.length));
    expect(printed.single['name'], 'Молоко 3.2%');
    expect(printed.single['quantity'], soldLines.single.quantity.toString());
    expect(printed.single['price'], soldLines.single.price.toString());

    final paid = (p['payments']! as List).cast<Map<String, Object?>>();
    expect(paid, hasLength(1));
    expect(paid.single['isCash'], isTrue);
    expect(paid.single['amount'], sale.amount.toString());

    // Ящик открыт своим портом оплаты, а не методом принтера: перепутанная
    // сборка видна только по имени вызова.
    final drawerCalls = hardware.of('drawer');
    expect(drawerCalls, hasLength(1));
    expect(drawerCalls.single['call'], 'paymentDrawerPort');
  });

  test('оператор отвечает РАНЬШЕ печати', () async {
    final view = await receipt();
    await payments.complete(
      terminalId,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );
    await payments.pendingSideEffects;

    // Порядок читается номерами записей, а не полем на чеке.
    //
    // **Круг правки 1, и он про измерение, а не про продукт.** Сперва здесь
    // стояло `expect(printed['fiscalNumber'], isNotNull)` — и покраснело.
    // Разбор показал, что доказать порядок этим полем нельзя ни при каком
    // операторе: `SaleReceiptComposer` верхнее `fiscalNumber` не заполняет
    // вовсе, а `SaleReceiptData.fiscal` собирается из строки
    // `FiscalReceipts`, которую пишет настоящий оператор и не пишет (и не
    // должна писать) заглушка. Проба мерила бы не порядок, а наличие
    // подделанной строки в базе.
    final fiscalSeq = hardware.of('fiscal').single['seq']! as int;
    final printSeq = hardware.of('printer').single['seq']! as int;
    expect(
      fiscalSeq,
      lessThan(printSeq),
      reason: 'фискальный номер обязан быть готов до сборки бумаги',
    );
  });

  test(
    'пустой фискальный номер на бумаге — свойство заглушки, а не дефект',
    () async {
      final view = await receipt();
      await payments.complete(
        terminalId,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      // Записано пробой, чтобы читающий живой журнал стенда не принял пустоту
      // за находку приёмки: строки `FiscalReceipts` заглушка не пишет.
      final printed = hardware.of('printer').single;
      expect(printed['fiscalNumber'], isNull);
      expect(printed['fiscalInfo'], isNull);
    },
  );

  test('два чека подряд записываются РАЗНЫМИ номерами', () async {
    for (var i = 0; i < 2; i++) {
      final view = await receipt();
      await payments.complete(
        terminalId,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 100 + i),
      );
      await payments.pendingSideEffects;
    }

    final numbers = hardware.of('fiscal').map((e) => e['receiptNo']).toList();
    expect(numbers, hasLength(2));
    // Заглушка, отвечающая константой, дала бы здесь два одинаковых числа
    // при двух разных чеках — и журнал остался бы «непустым».
    expect(numbers.first, isNot(numbers.last));
  });

  test(
    'отказ оператора: беда названа и легла в очередь с тем же чеком',
    () async {
      hardware.fiscalMode = StandHardwareMode.fail;

      final view = await receipt();
      final outcome = await payments.complete(
        terminalId,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );
      await payments.pendingSideEffects;

      // Деньги взяты несмотря на отказ оператора — отказ фискализации не
      // отменяет состоявшуюся продажу.
      final sale = (await db.saleDao.findByKey(outcome.receiptNo, 1))!;
      expect(sale.amount, d('1000'));

      final queued = hardware.of('fiscalQueue');
      expect(queued, hasLength(1), reason: 'беда пережила бы перезапуск');
      final q = queued.single;
      expect(q['call'], 'enqueue');
      expect(q['status'], 'failed');
      expect(q['idempotencyKey'], 'sale-unfiscalized:1-${sale.receiptNo}');
      final payload = q['payload']! as Map<String, Object?>;
      expect(payload['receiptNo'], sale.receiptNo);
      expect(payload['amount'], sale.amount.toString());
      // Персональных данных в записи о беде нет — их туда не кладут намеренно.
      expect(payload.containsKey('customerBin'), isFalse);

      // На бумаге фискального номера нет, и это правда, а не пропуск.
      expect(hardware.of('printer').single['fiscalNumber'], isNull);
    },
  );

  test('отказ очереди печати не отменяет продажу и назван', () async {
    hardware.printerMode = StandHardwareMode.fail;

    final view = await receipt();
    final outcome = await payments.complete(
      terminalId,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );
    await payments.pendingSideEffects;

    final sale = (await db.saleDao.findByKey(outcome.receiptNo, 1))!;
    expect(sale.amount, d('1000'));
    // Принтер всё равно позван — отказ виден по режиму, а не по молчанию.
    expect(hardware.of('printer'), hasLength(1));
    expect(hardware.of('printer').single['mode'], 'fail');
  });
}
