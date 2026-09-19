/// Два числа сертификатов за смену — **источник и сходимость**.
///
/// Строки X/Z-отчёта «выпущено» и «погашено» отвечают на разные вопросы, и
/// собрать их можно из разных мест. Эта проба утверждает не то, что числа
/// печатаются, а то, что они **сходятся со счётом обязательства**:
///
///     остаток на конец == остаток на начало + выпущено − погашено
///
/// Равенство не украшение. Оно и есть проверка выбора источника: возьми
/// «выпущено» из строк продажи (цена, за которую бумажку продали) вместо
/// номинала — и на акционной бумажке 5000 за 4500 равенство разойдётся на
/// 500 молча, без единого красного теста где-либо ещё.
///
/// # Чего эта проба НЕ доказывает
///
/// Не доказывает, что числа попадают на бумагу: это сторож
/// `test/unit/hardware/certificate_shift_line_wire_test.dart`, и он меряет
/// байты у эмулятора принтера. Здесь только арифметика и источник.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';

import '../../helpers/cash_drawer.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late CertificateIssuer issuer;

  const barcodeA = '4870001234567';
  const posAccountId = 11;
  const cashierId = 4;

  /// Окно смены: открыта час назад, ещё идёт (сутки — предел
  /// `ShiftAgeRule`, и продажа на такой смене отказывается).
  late int shiftOpen;
  int shiftClose() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

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

  Future<Decimal> liabilityBalance() async {
    final accounts = await db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    if (accounts.isEmpty) return Decimal.zero;
    return accounts.first.value ?? Decimal.zero;
  }

  Future<Decimal> issued() => db.certificateDao.issuedNominalBetween(
    from: shiftOpen,
    to: shiftClose(),
    userId: cashierId,
  );

  Future<Decimal> redeemed() =>
      db.paymentDao.sumCertificateRedemptionsBetween(
        userId: cashierId,
        startDate: shiftOpen,
        endDate: shiftClose(),
      );

  setUp(() async {
    shiftOpen = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
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
        .insert(
          const UsersCompanion(id: Value(cashierId), name: Value('Айгуль')),
        );
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: const Value(cashierId),
            openTime: Value(shiftOpen),
            isOpened: const Value(true),
            isSynced: const Value(false),
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
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(posAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
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
    final checkout = LocalSaleCheckoutService(
      db: db,
      cart: cart,
      logger: logger,
    );
    payments = LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    issuer = LocalCertificateIssuer(db: db, logger: logger);
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
      ).copyWith(isActive: true),
    );
  });

  tearDown(() => db.close());

  group('выпущено — это номинал, а не цена продажи', () {
    test('номинал берётся с бумажки, а не со строк чека', () async {
      // Акция: бумажка номиналом 5000 продана за 4500. Должна касса
      // **5000** — ровно столько, сколько напечатано на бумажке, и ровно
      // столько лежит обязательством на счёте.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      expect(await issued(), d('5000'));
      expect(
        await liabilityBalance(),
        d('5000'),
        reason: 'число отчёта обязано совпасть со счётом обязательства',
      );
    });

    test('две бумажки складываются целыми тысячными', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('1500.125'),
      );
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-2',
        nominal: d('2500.875'),
      );

      expect(await issued(), d('4001.000'));
      expect(await liabilityBalance(), d('4001.000'));
    });

    test('отозванная бумажка из числа НЕ выпадает', () async {
      // Отзыв переводит состояние и **не трогает счёт обязательства**
      // (`CertificateDao.cancel`). Отбор по `status = 'active'` увёл бы
      // число от счёта ровно на отозванные за смену бумажки.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await issuer.cancel('C-1');

      expect(await issued(), d('5000'));
      expect(await liabilityBalance(), d('5000'));
    });

    test('бумажка прошлой смены в окно не входит', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-OLD',
        nominal: d('7000'),
      );
      // Отодвигаем выпуск на двое суток назад — до открытия смены.
      await (db.update(db.giftCertificates)
            ..where((c) => c.number.equals('C-OLD')))
          .write(GiftCertificatesCompanion(issuedAt: Value(shiftOpen - 86400)));

      expect(
        await issued(),
        Decimal.zero,
        reason: 'отчёт смены отвечает за смену, а не за весь тираж',
      );
      expect(
        await liabilityBalance(),
        d('7000'),
        reason: 'обязательство живёт годами — оно и не обязано совпадать с '
            'движением одной смены',
      );
    });
  });

  group('погашено — это строки оплаты, а не остаток бумажки', () {
    test('гашение считается, выпуск в него не попадает', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      final view = await receiptWith(); // 500

      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      expect(await redeemed(), d('500'));
      expect(
        await issued(),
        d('500'),
        reason: 'выпуск и гашение — разные числа, и оба за эту смену',
      );
    });

    test('частичное гашение считается тем, что списано, а не номиналом',
        () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      final view = await receiptWith(); // 500

      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      expect(
        await redeemed(),
        d('500'),
        reason: 'товара отдано на 500 — столько и погашено, а не 5000',
      );
      expect((await db.certificateDao.byNumber('C-1'))!.balance, d('4500'));
    });

    test('чек без сертификата в число не попадает', () async {
      final view = await receiptWith();
      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('500')),
        mv(view, 9),
      );

      expect(await redeemed(), Decimal.zero);
    });
  });

  group('числа сходятся со счётом обязательства', () {
    test('остаток на конец == остаток на начало + выпущено − погашено',
        () async {
      // Начало смены: на кассе уже лежит обязательство прошлых смен.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-OLD',
        nominal: d('3000'),
      );
      await (db.update(db.giftCertificates)
            ..where((c) => c.number.equals('C-OLD')))
          .write(GiftCertificatesCompanion(issuedAt: Value(shiftOpen - 86400)));
      final opening = await liabilityBalance();
      expect(opening, d('3000'));

      // Смена: выпустили две бумажки, одной расплатились за товар.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-2',
        nominal: d('2000'),
      );
      final view = await receiptWith(quantity: 2); // 1000
      await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-1')],
        ),
        mv(view, 9),
      );

      final grew = await issued();
      final closed = await redeemed();
      expect(grew, d('7000'));
      expect(closed, d('1000'));

      expect(
        await liabilityBalance(),
        opening + grew - closed,
        reason: 'расхождение здесь означает, что одно из двух чисел взято '
            'не из того места — и увидеть это в отчёте будет неоткуда',
      );
    });
  });
}
