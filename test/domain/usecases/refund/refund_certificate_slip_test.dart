/// Возврат по сертификату печатает слип **новой** бумажки — решение
/// заказчика 2026-09-16.
///
/// # Почему проба идёт путём возврата, а не вызовом принтера
///
/// Потому что доказывать надо **достижимость**. Что `printCertificateSlip`
/// собирает документ, меряет соседняя проба через эмулятор ESC/POS; здесь
/// меряется то, что до неё вообще доходит дело — из настоящей продажи, через
/// настоящую раскладку возврата, до настоящего журнала связи (v48).
///
/// Ровно этот класс дефекта дерево ловило не раз: код печати написан, пробы
/// печати зелены, а ни один живой путь его не зовёт.
///
/// # Что было до правки
///
/// Возврат выпускал бумажку с номером вида `<исходный>-R<возврат>` и **не
/// печатал ничего**: кассир переписывал бы номер от руки, а покупатель
/// уходил бы, не зная, что у него есть сертификат.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/payment/local_certificate_slip_printer.dart';
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
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import '../../../helpers/cash_drawer.dart';

import '../../../helpers/discount_authority.dart';

class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

/// Служба печати, запоминающая слипы. Чеки продажи и возврата ей тоже
/// приходят — они здесь не предмет, и ответ на них «принято».
class _SlipSpy implements ReceiptPrintService {
  final slips = <CertificateSlipData>[];

  @override
  Future<PrintSubmitOutcome> printCertificateSlip(
    CertificateSlipData data,
  ) async {
    slips.add(data);
    return PrintSubmitOutcome.accepted('slip-${data.number}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<PrintSubmitOutcome>.value(PrintSubmitOutcome.accepted('other'));
}

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late CertificateIssuer issuer;
  late LocalCertificateSlipPrinter slips;
  late _SlipSpy spy;
  late Talker logger;

  const barcodeA = '4870001234567';
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

  /// Чек на 1000: две штуки по 500.
  Future<CartView> receipt() async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    view = await cart.setQuantity(7, view.lines.single.id, d('2'), mv(view, 3));
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
      slips: slips,
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
            userId: const Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
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
            ucode: const Value(100),
            barcode: int.parse(barcodeA),
            sellingPrice: Value(d('500')),
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
    slips = LocalCertificateSlipPrinter(db: db, logger: logger);
    issuer = LocalCertificateIssuer(db: db, logger: logger);
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
      ).copyWith(isActive: true),
    );
  }

  setUp(() async {
    await GetIt.I.reset();
    GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());
    spy = _SlipSpy();
    GetIt.I.registerSingleton<ReceiptPrintService>(spy);
  });

  tearDown(() async {
    await payments.pendingSideEffects;
    await GetIt.I.reset();
    await db.close();
  });

  test('возврат по сертификату печатает слип НОВОЙ бумажки', () async {
    await boot();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('1000'),
    );
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );

    final refundId = await refund(view.receiptNo!, d('1000'));
    await slips.pending;

    expect(
      spy.slips,
      hasLength(1),
      reason:
          'бумажка выпущена, а на руки не выдана: её номер живёт только на '
          'слипе',
    );
    final slip = spy.slips.single;
    expect(
      slip.number,
      'C-1-R$refundId',
      reason: 'печатается НОВАЯ бумажка, а не исходная',
    );
    expect(slip.amount, d('1000'));
    expect(
      slip.refundLocalId,
      refundId,
      reason: 'слип обязан объяснить, откуда бумажка взялась',
    );
    expect(
      slip.sourceNumber,
      'C-1',
      reason:
          'без исходного номера покупатель придёт со старой бумажкой, а она '
          'погашена навсегда',
    );
  });

  test('слип печатается на долю — столько, сколько ушло на бумажку', () async {
    await boot();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('1000'),
    );
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );

    final refundId = await refund(view.receiptNo!, d('500'));
    await slips.pending;

    expect(spy.slips.single.number, 'C-1-R$refundId');
    expect(
      spy.slips.single.amount,
      d('500'),
      reason: 'на бумажке — возвращённая доля, а не цена всего чека',
    );
  });

  test('возврат наличного чека слипов не печатает', () async {
    // Сторож против «печатаем всегда»: чек без сертификата новых бумажек не
    // рождает, и слипу взяться неоткуда. Без этой пробы ветка «печатать по
    // журналу» могла бы печатать по любому возврату и выглядеть рабочей.
    await boot();
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );

    await refund(view.receiptNo!, d('1000'));
    await slips.pending;

    expect(spy.slips, isEmpty);
  });

  test('касса без принтера слипов возврат проводит так же', () async {
    await boot();
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('1000'),
    );
    final view = await receipt();
    await payments.complete(
      7,
      PaymentRequest(
        type: PaymentType.cash,
        certificates: const [CertificateTender(number: 'C-1')],
      ),
      mv(view, 9),
    );

    // `slips` не передан вовсе — печати нет, и это не ошибка.
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
      amount: d('1000'),
      userId: 4,
      saleReceiptNo: view.receiptNo!,
      salePosId: 1,
      products: const [],
    );

    expect(
      (await db.certificateDao.byNumber('C-1-R$refundId'))!.balance,
      d('1000'),
      reason: 'бумажка выпущена и без принтера — деньги важнее бумаги',
    );
    expect(spy.slips, isEmpty);
  });
}
