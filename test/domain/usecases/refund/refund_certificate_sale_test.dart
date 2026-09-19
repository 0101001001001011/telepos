/// Сертификат в **настоящем** пути продажи — решения заказчика 2026-09-16.
///
/// # Чем эта проба отличается от соседей
///
/// `refund_certificate_reissue_test.dart` сеет чек и строки оплаты прямо в
/// таблицы: так меряется раскладка возврата, и это правильно — она читает
/// строки, а не то, как они появились. Здесь наоборот: настоящая корзина,
/// настоящий `LocalPaymentService`, настоящий `SaleUseCaseImpl`. Мерится
/// **путь**, а не арифметика, и ровно поэтому только здесь достижим запрет
/// «сертификатом за сертификат»: он живёт в раскладке оплаты, до которой
/// посеянный чек не доходит вовсе.
///
/// # Что измерено этим файлом до правки
///
/// Он и был пробой, доказавшей дефект. На `86ff105e` возврат чека, которым
/// продан сертификат, печатал в журнал
/// `parts=[RefundPart(drawer 5000)]` и оставлял бумажку
/// `GiftCertificate(C-1, 5000 из 5000, active)`: покупатель уносил и 5000
/// наличными из ящика, и **годный сертификат на 5000**. Две беды разом —
/// непогашенная бумажка (решение 1) и наличные за аванс (решение 3).
///
/// Сегодня тот же чек получает **названный отказ**: наличными за сертификат
/// не возвращают. Гашение при этом меряется там, где возврат вообще
/// возможен, — на безналичной оплате, в соседнем файле.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../../helpers/cash_drawer.dart';

import '../../../helpers/discount_authority.dart';

class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late CertificateIssuer issuer;
  late Talker logger;

  /// Позиция «подарочный сертификат» — товар рода
  /// [ProductType.giftCertificate], то, что покупают.
  const barcodeCertificate = '4870009999999';
  const posAccountId = 11;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: null);

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

  /// Чек на 5000: один сертификат номиналом 5000.
  Future<CartView> sellCertificate() async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeCertificate, mv(view, 2));
    return view;
  }

  Future<int> refund(int receiptNo, Decimal amount) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: 4, time: 2000));
    final refundId = (await db.select(db.refunds).get()).last.localId;

    await RefundUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: const RefusingFiscalService(),
    ).perform(
      refundLocalId: refundId,
      amount: amount,
      userId: 4,
      saleReceiptNo: receiptNo,
      salePosId: 1,
      products: const [],
    );
    return refundId;
  }

  Future<GiftCertificate> cert(String number) async =>
      (await db.certificateDao.byNumber(number))!;

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

  Future<void> boot() async {
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
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(200),
            barcode: int.parse(barcodeCertificate),
            name: 'Подарочный сертификат 5000',
            type: ProductType.giftCertificate.index,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(200),
            barcode: int.parse(barcodeCertificate),
            sellingPrice: Value(d('5000')),
          ),
        );
    await seedAccount(posAccountId, AccountType.pos);

    logger = Talker();
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
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    issuer = LocalCertificateIssuer(db: db, logger: logger);
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
      ).copyWith(isActive: true),
    );
  }

  setUp(() {
    GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await GetIt.I.unregister<RefundProductService>();
    await db.close();
  });

  test('наличными за проданный сертификат вернуть нельзя', () async {
    await boot();
    final view = await sellCertificate();
    await payments.complete(
      7,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('5000')),
      mv(view, 9),
    );
    final receiptNo = view.receiptNo!;
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('5000'),
      receiptNo: receiptNo,
    );
    expect(await balanceOf(posAccountId), d('5000'));

    // До правки этот возврат проходил: 5000 уходили из ящика, а бумажка
    // оставалась годной. Теперь он обязан получить **названный отказ**.
    await expectLater(
      refund(receiptNo, d('5000')),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          certificateCashRefundRefusedCode,
        ),
      ),
    );

    // **Откат целиком.** Ящик не тронут, бумажка цела: отказ не имеет права
    // оставить кассу в половине операции.
    expect(
      await balanceOf(posAccountId),
      d('5000'),
      reason: 'из ящика не вышло ни тенге',
    );
    expect((await cert('C-1')).balance, d('5000'));
    expect((await cert('C-1')).status, CertificateStatus.active);
  });

  test('сертификатом нельзя оплатить покупку сертификата', () async {
    await boot();
    // Бумажка, которой пытаются заплатить за другую бумажку.
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-PAY',
      nominal: d('5000'),
    );

    final view = await sellCertificate();

    await expectLater(
      payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          certificates: const [CertificateTender(number: 'C-PAY')],
        ),
        mv(view, 9),
      ),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          certificatePaysCertificateCode,
        ),
      ),
    );

    // Бумажка-плательщик не тронута: отказ стоит до всякого гашения.
    expect(
      (await cert('C-PAY')).balance,
      d('5000'),
      reason: 'бесконечный цикл аванса остановлен до списания',
    );
  });

  test('обычный товар сертификатом оплачивается по-прежнему', () async {
    // Сторож против чрезмерного запрета: он обязан ловить **позицию рода
    // «сертификат»**, а не любую оплату сертификатом. Без этой пробы
    // запрет, написанный на один символ шире, закрыл бы сертификаты вовсе,
    // и набор остался бы зелёным.
    await boot();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(300),
            barcode: 4870001111111,
            name: 'Кофе',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(300),
            barcode: 4870001111111,
            sellingPrice: Value(d('1000')),
          ),
        );
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-PAY',
      nominal: d('5000'),
    );

    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, '4870001111111', mv(view, 2));

    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-PAY')],
      ),
      mv(view, 9),
    );

    expect(
      (await cert('C-PAY')).balance,
      d('4000'),
      reason: 'за кофе сертификатом платить можно — списалась 1000',
    );
  });
}
