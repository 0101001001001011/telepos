import 'dart:async';

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
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/sale/cart_service.dart' show cartStaleCode;
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

/// «Занятие чека» под оплату — гонка двух завершений (задача 8).
///
/// # Почему `Future.wait` здесь ничего не доказывает — замерено, а не
/// выведено из чтения
///
/// Первая проба этой задачи пускала два завершения разом
/// (`Future.wait([complete(A), complete(B)])`) и **зеленела на
/// неисправленном коде**: второй гонщик получал `cart_stale`. Журнал
/// прогона показал почему — оба дошли до `prepare` (927 мс), но запись
/// «занять чек» у второго случилась **после** транзакции `perform`
/// первого (958 → 960 мс), а та уже перевела `state` в 1. То есть
/// защитой сработало не занятие чека, а побочное действие чужой
/// транзакции, и проба мерила совпадение расписания, а не устройство
/// кода. Drift на одном соединении выстраивает запросы в очередь, и
/// одновременность на уровне `Future` до настоящего чередования
/// «прочитал → записал» не доводит.
///
/// # Чем гонка показана вместо этого
///
/// Оба гонщика разводятся во времени **на швах, объявленных самим
/// продуктом**: `SaleCheckoutService` и `SaleUseCase` — доводы
/// конструктора [LocalPaymentService], ровно как драйвер платёжного
/// терминала. Расписание выстраивается ровно то, ради которого условная
/// запись и существует:
///
/// 1. первый читает чек (`saleDao.findByKey` — «в работе») и встаёт до
///    подготовки ([_GatedCheckout]);
/// 2. второй читает тот же чек и видит **то же самое** — заняться ещё
///    никто не успел;
/// 3. первый идёт дальше, занимает чек и встаёт перед деньгами
///    ([_GatedSaleUseCase]);
/// 4. второй идёт занимать уже занятое, держа в руках прочитанное до
///    занятия состояние.
///
/// Второй шаг — то, чего не даёт ни `Future.wait`, ни одна остановка:
/// без него второй гонщик читает чек **после** чужого занятия, и
/// отвергает его проверка при чтении, а не условная запись. Разница
/// измерена диверсией: со снятым условием по ключу проба с одной
/// остановкой оставалась зелёной, с двумя — краснеет (2000 с чека
/// на 1000).
///
/// Вторая половина замысла — **разные счета получателя**. Уникальный
/// ключ `Payments` — `{receiptNo, posId, payeeAccountId}`, и два
/// одинаковых наличных завершения он бы столкнул сам (сырым
/// `SqliteException(2067)`, уже после взятия денег). Наличные против
/// карты ложатся на **разные** счета, ключ молчит — и видно то, что он
/// сегодня прикрывает собой: деньги взяты дважды.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late _GatedCheckout checkout;
  late LocalPaymentService payments;
  late _GatedSaleUseCase gate;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const bankAccountId = 12;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

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

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  Future<Decimal> stockOf(int ucode) async =>
      (await db.productInfoDao.findByUcode(ucode))?.quantity ?? Decimal.zero;

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
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(barcodeA),
            name: 'Товар',
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
            barcode: int.parse(barcodeA),
            sellingPrice: Value(d('500')),
          ),
        );
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
    checkout = _GatedCheckout(db: db, cart: cart, logger: logger);
    gate = _GatedSaleUseCase(db: db, logger: logger);
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: gate,
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    if (gate.holdFirst && !gate.released) gate.release();
    checkout.releaseAll();
    await db.close();
  });

  test('второе завершение отвергается ДО записи денег, а не после', () async {
    final view = await receiptWith(quantity: 2); // 1000
    final receiptNo = view.receiptNo!;
    checkout.holding = true;
    gate.holdFirst = true;

    // Первый гонщик: наличные. Останавливается сразу после того, как
    // прочитал чек, — до занятия.
    final first = payments.complete(
      7,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );
    await checkout.arrived(0);

    // Второй гонщик: **другой ключ, тот же чек, та же версия**. Другой
    // ключ обязателен — одинаковый ключ снимает карта `_completions`,
    // которая живёт в памяти процесса и потому защитой не является.
    // Он тоже успевает прочитать чек до всякого занятия: **оба видят
    // «в работе»**, и это и есть гонка, которую заслон обязан разнять.
    final second = payments.complete(
      7,
      PaymentRequest(type: PaymentType.card, approvalCode: '000000'),
      mv(view, 10),
    );
    await checkout.arrived(1);

    // Первый идёт дальше: занимает чек и встаёт перед записью денег.
    checkout.release(0);
    await gate.atDoor;
    expect(
      await db.paymentDao.countBySale(receiptNo, 1),
      0,
      reason: 'страховка от вырождения: денег ещё нет',
    );

    // Второй идёт занимать уже занятое — с прочитанным до занятия
    // состоянием на руках.
    checkout.release(1);
    Object? refusal;
    try {
      await second;
    } catch (e) {
      refusal = e;
    }

    gate.release();
    await first;

    // Деньги — первым утверждением: именно они и есть беда, а отказ
    // второму гонщику лишь способ её не допустить.
    final collected =
        await balanceOf(posAccountId) + await balanceOf(bankAccountId);
    expect(
      collected,
      d('1000'),
      reason: 'с чека на 1000 собрано $collected — деньги взяты дважды',
    );
    final rows = await db.paymentDao.findBySale(receiptNo, 1);
    expect(
      rows,
      hasLength(1),
      reason: 'две строки оплаты на один чек — деньги взяты дважды',
    );
    expect(await stockOf(100), d('98'), reason: 'остаток списан дважды');
    expect((await saleRow(receiptNo)).amount, d('1000'));

    expect(
      refusal,
      isA<WireRefusal>(),
      reason: 'второй обязан получить названный отказ, а не пройти',
    );
  });

  test('свою же попытку, упавшую на записи денег, повторить можно', () async {
    // Обратная сторона занятия: если бы «занято» не снималось при
    // неудаче, чек оставался бы заперт навсегда, и кассир не смог бы
    // его оплатить вовсе. Ключ провода мнётся на каждую попытку заново,
    // поэтому повтор приходит **с новым ключом** — именно он и обязан
    // пройти.
    final view = await receiptWith(quantity: 2);
    final receiptNo = view.receiptNo!;

    gate.failFirst = true;
    await expectLater(
      payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await db.paymentDao.countBySale(receiptNo, 1), 0);

    final second = await payments.complete(
      7,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 11),
    );

    expect(second.paid, d('1000'));
    expect(await db.paymentDao.countBySale(receiptNo, 1), 1);
    expect(await balanceOf(posAccountId), d('1000'));
  });

  group('касса умерла с занятым чеком', () {
    /// Занятие, пережившее перезапуск: снять его в процессе было некому.
    /// Пишется прямо в базу, потому что достижимо оно только смертью
    /// процесса между условной записью и транзакцией `perform`, а
    /// убивать процесс проба не умеет.
    Future<void> leaveClaimed(int receiptNo, String key) async {
      final touched =
          await (db.update(db.sales)..where(
                (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(1),
              ))
              .write(
                SalesCompanion(
                  state: const Value(2),
                  lastCommandKey: Value(key),
                ),
              );
      expect(touched, 1, reason: 'страховка от вырождения пробы');
    }

    test('тот же ключ дооплачивает чек', () async {
      final view = await receiptWith(quantity: 2);
      final receiptNo = view.receiptNo!;
      await leaveClaimed(receiptNo, 'k9');

      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      expect(outcome.repeat, isFalse, reason: 'денег на чеке не было');
      expect(outcome.paid, d('1000'));
      expect(await balanceOf(posAccountId), d('1000'));
      expect(await db.paymentDao.countBySale(receiptNo, 1), 1);
    });

    test('чужой ключ получает cart_stale, а не «чек уже оплачен»', () async {
      // Разница не косметическая: `payment_already_taken` — тупик без
      // лечения (докстринг кода), и сказать его о чеке, за которым нет
      // ни одной строки `Payments`, значит соврать кассиру.
      final view = await receiptWith(quantity: 2);
      final receiptNo = view.receiptNo!;
      await leaveClaimed(receiptNo, 'k9');

      await expectLater(
        payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
          mv(view, 12),
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartStaleCode),
        ),
      );
      expect(await db.paymentDao.countBySale(receiptNo, 1), 0);
      expect(await balanceOf(posAccountId), Decimal.zero);
    });
  });
}

/// `SaleUseCase`, который останавливает **первый** `perform`.
///
/// Шов объявлен продуктом: `SaleUseCase` — довод конструктора
/// [LocalPaymentService]. Ничего, кроме расписания, здесь не подделано:
/// работу делает настоящий [SaleUseCaseImpl].
class _GatedSaleUseCase extends SaleUseCaseImpl {
  _GatedSaleUseCase({required super.db, required super.logger});

  final _atDoor = Completer<void>();
  final _hold = Completer<void>();

  /// Первый гонщик занял чек и стоит перед записью денег.
  Future<void> get atDoor => _atDoor.future;

  bool get released => _hold.isCompleted;

  void release() => _hold.complete();

  /// Останавливать ли первый `perform`. По умолчанию нет: окно нужно
  /// только пробе про гонку, остальным оно было бы вечным ожиданием.
  bool holdFirst = false;

  /// Уронить первый `perform` — для пробы про снятие занятия.
  bool failFirst = false;

  var _seen = 0;

  @override
  Future<void> perform({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required List<ReceiptLine> lines,
    required List<PaymentEntry> payments,
    required Decimal change,
    required bool selectiveOfd,
    String? customerBin,
    int? agentLocalId,
    int? agentServerId,
    List<CustomFieldEntry>? customFields,
    WithdrawalEntry? withdrawal,
    CreditContractDraft? credit,
  }) async {
    final n = _seen++;
    if (n == 0) {
      if (failFirst) throw StateError('perform упал');
      if (holdFirst) {
        _atDoor.complete();
        await _hold.future;
      }
    }
    return super.perform(
      receiptNo: receiptNo,
      posId: posId,
      amount: amount,
      lines: lines,
      payments: payments,
      change: change,
      selectiveOfd: selectiveOfd,
      customerBin: customerBin,
      agentLocalId: agentLocalId,
      agentServerId: agentServerId,
      customFields: customFields,
      withdrawal: withdrawal,
      credit: credit,
    );
  }
}

/// `SaleCheckoutService`, умеющий задержать подготовку чека.
///
/// Тот же шов, что у [_GatedSaleUseCase]: `SaleCheckoutService` — довод
/// конструктора [LocalPaymentService]. Держит **первые два** вызова
/// `prepare`, и держит именно там, где нужно: `_complete` читает чек
/// (`saleDao.findByKey`) **до** подготовки, а занимает — после. Значит
/// оба гонщика успевают прочитать «чек в работе» прежде, чем хоть один
/// его займёт, — а это и есть та гонка «прочитал → записал», ради
/// которой условная запись существует.
class _GatedCheckout extends LocalSaleCheckoutService {
  _GatedCheckout({
    required super.db,
    required super.cart,
    required super.logger,
  });

  /// Держать ли подготовку. По умолчанию нет: остальным пробам это было
  /// бы вечным ожиданием.
  bool holding = false;

  final _arrived = [Completer<void>(), Completer<void>()];
  final _hold = [Completer<void>(), Completer<void>()];
  var _n = 0;

  /// Гонщик [i] прочитал чек и стоит до подготовки.
  Future<void> arrived(int i) => _arrived[i].future;

  void release(int i) => _hold[i].complete();

  void releaseAll() {
    for (final c in _hold) {
      if (!c.isCompleted) c.complete();
    }
  }

  @override
  Future<CheckoutPreparation> prepare({
    required int receiptNo,
    required int posId,
  }) async {
    final n = _n++;
    if (holding && n < 2) {
      _arrived[n].complete();
      await _hold[n].future;
    }
    return super.prepare(receiptNo: receiptNo, posId: posId);
  }
}
