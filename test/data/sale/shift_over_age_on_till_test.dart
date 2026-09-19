import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
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
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

/// Задача 27 плана «Продажа с браузерного терминала»: правило «смена не
/// старше суток» проверяет **касса**, и проверить его ей всегда есть чем.
///
/// # Что было измерено на `9ac079a5`
///
/// - Оплата: `LocalPaymentService._requireShiftNotOverAge` начинался с
///   `if (shifts == null) return;`, а порт `shifts:` был необязательным
///   доводом (`service_locator.dart` — `isRegistered<ShiftService>() ? … :
///   null`). Касса, собранная без него, брала деньги в смене любого возраста.
/// - Начало чека: на кассе правила не было вовсе. Его держал **клиент** —
///   `SaleNotifier._ensureShiftNotOverAge`, — и в браузере, где
///   `ShiftService` не привязан, его `catch` возвращал `true`: продажа шла.
///
/// # Почему пробы строят службы без единого порта смены
///
/// Ровно это и есть утверждение: отсутствие порта больше не значит
/// «проверки нет». Проба, передавшая порт, доказывала бы, что порт умеет
/// отвечать, — а дыра была в том, что его можно не передать.
void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;

  const barcode = '4870001234567';

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: 0, receiptNo: null);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  int secondsAgo(Duration age) =>
      DateTime.now().subtract(age).millisecondsSinceEpoch ~/ 1000;

  Future<void> ageShift(Duration age) =>
      db.update(db.shifts).write(ShiftsCompanion(openTime: Value(secondsAgo(age))));

  Matcher overAge() => throwsA(
    isA<WireRefusal>().having((r) => r.code, 'code', payShiftOverAgeCode),
  );

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
            userId: const Value(4),
            openTime: Value(secondsAgo(const Duration(hours: 1))),
            isOpened: const Value(true),
            isSynced: const Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(barcode),
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
            barcode: int.parse(barcode),
            sellingPrice: Value(d('500')),
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
    // Ни одного порта смены — см. докстринг файла.
    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('начало чека', () {
    test('смена старше суток — чек не начинается, строки в базе нет', () async {
      await ageShift(const Duration(hours: 25));

      await expectLater(
        () => cart.start(terminalId: 7, wholesale: false, meta: m(1)),
        overAge(),
      );
      expect(await db.saleDao.countWithState(0), 0);
    });

    test('ровно сутки — уже нельзя; без минуты сутки — ещё можно', () async {
      // Граница та же, что у прежней клиентской проверки
      // (`ShiftServiceImpl.isShiftOverAge`: `ageSec >= maxAge`).
      await ageShift(const Duration(hours: 24));
      await expectLater(
        () => cart.start(terminalId: 7, wholesale: false, meta: m(1)),
        overAge(),
      );

      await ageShift(const Duration(hours: 23, minutes: 59));
      final view = await cart.start(terminalId: 7, wholesale: false, meta: m(2));
      expect(view.receiptNo, isNotNull);
    });
  });

  group('оплата', () {
    test(
      'смена перевалила за сутки, пока чек набирался, — деньги не берутся',
      () async {
        var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1));
        view = await cart.addByBarcode(7, barcode, mv(view, 2));
        await ageShift(const Duration(hours: 25));

        await expectLater(
          payments.complete(
            7,
            PaymentRequest(type: PaymentType.cash, cashReceived: d('500')),
            mv(view, 3),
          ),
          overAge(),
        );
        expect(await db.paymentDao.countBySale(view.receiptNo!, 1), 0);
      },
    );

    test('свежая смена оплату пропускает — проверка не запирает всё', () async {
      var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1));
      view = await cart.addByBarcode(7, barcode, mv(view, 2));

      final outcome = await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('500')),
        mv(view, 3),
      );
      expect(outcome.paid, d('500'));
    });
  });
}
