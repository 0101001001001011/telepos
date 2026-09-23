// Фискальный порт `LocalPaymentService` — **необнуляемый довод**, и сторожит
// это компилятор, а не проба.
//
// # Что здесь доказывается и чем
//
// Строка ниже (`_build()`) не собралась бы, будь `fiscal` пропущен: довод
// объявлен `required FiscalService fiscal`. То есть настоящая проверка —
// **сборка дерева**, и происходит она у каждого, кто вообще запускает
// `flutter test` или `flutter build`. Забыть порт нельзя: это не забывчивость,
// а ошибка компиляции.
//
// Проба существует не вместо этой проверки, а ради следующего читателя:
// чтобы он увидел, что здесь сторожит, и не завёл третьего сторожа —
// исходно-сканирующую пробу «нет полей вида `XxxService?`». Такая проба
// бывает зелена по построению (ни одного поля не нашла — прошла) и
// обходится переименованием поля.
//
// # Почему `RefusingFiscalService`, а не `null`
//
// До этой задачи «фискального узла в сборке нет» выражалось нулём: довод
// пропускали, и `_fiscalize` тихо выходил первой строкой. Пропуск довода
// одинаково выглядел и как решение («узла нет»), и как забывчивость («не
// дописал»), а компилятор молчал в обоих случаях.
//
// Теперь это выражается **типом**: собравший кассу без фискального узла
// обязан назвать его вслух — `const RefusingFiscalService()`. Отсюда и
// вторая половина пробы: этот тип обязан отказывать **каждым** членом.
// Заглушка, возвращающая успех, — ровно та ложь, которую задача 2 убрала у
// провайдеров; повторять её на уровне службы нельзя.
import 'package:decimal/decimal.dart';
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
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import '../../helpers/cash_drawer.dart';

void main() {
  test('LocalPaymentService нельзя собрать без фискального порта', () {
    // Довод `fiscal:` ниже **обязателен**. Уберите его — и этот файл
    // перестанет компилироваться, а вместе с ним и весь набор: красное
    // придёт не отсюда, а от анализатора, и это ровно то, чего задача
    // добивалась.
    final service = _build();
    expect(service, isNotNull);
  });

  group('RefusingFiscalService', () {
    const fiscal = RefusingFiscalService();

    test('не включён: политика чека до него не доходит', () async {
      // `isOfdSale` спрашивает `isEnabled()` первым. Если бы заглушка
      // отвечала `true`, касса без фискального узла пошла бы дальше и
      // получила отказ вместо названного состояния сборки.
      expect(await fiscal.isEnabled(), isFalse);
      expect(
        (await fiscal.currentSettings()).operatorType,
        FiscalOperatorType.none,
      );
    });

    test('ни один член не возвращает успеха', () async {
      final zero = Decimal.zero;

      expect(
        (await fiscal.fiscalizeSale(
          saleReceiptNo: 1,
          salePosId: 1,
          amount: zero,
          cashAmount: zero,
          cardAmount: zero,
          mobileAmount: Decimal.zero,
          bonusAmount: zero,
          offsetAmount: Decimal.zero,
          offsetLayout: OffsetFiscalLayout.discount,
          excludeCertificatePositions: false,
        )).success,
        isFalse,
      );
      expect(
        (await fiscal.fiscalizeRefund(
          refundLocalId: 1,
          originalSaleReceiptNo: 1,
          amount: zero,
          cashAmount: zero,
          cardAmount: Decimal.zero,
          mobileAmount: Decimal.zero,
          bonusAmount: zero,
          creditAmount: zero,
          offsetAmount: Decimal.zero,
          offsetLayout: OffsetFiscalLayout.discount,
          excludeCertificatePositions: false,
        )).success,
        isFalse,
      );
      expect((await fiscal.fiscalizePurchase(_saleRequest())).success, isFalse);
      expect(
        (await fiscal.fiscalizePurchaseReturn(_refundRequest())).success,
        isFalse,
      );
      expect((await fiscal.moneyIn(amount: zero)).success, isFalse);
      expect((await fiscal.moneyOut(amount: zero)).success, isFalse);
      expect((await fiscal.openShift()).success, isFalse);
      expect((await fiscal.closeShift()).result.success, isFalse);
      expect((await fiscal.xReport()).result.success, isFalse);
      expect((await fiscal.correction(_correctionRequest())).success, isFalse);

      final status = await fiscal.status();
      expect(status.configured, isFalse);
      expect(status.canFiscalize, isFalse);
    });

    test('ни один член не обещает очереди', () async {
      // Та же ловушка, что у `NoOpFiscalProvider`: `queued` означает «чек
      // уедет сам», а за этой заглушкой никакой очереди нет — её даёт
      // `OfflineQueueingProvider`, оборачивающий **настоящих**
      // исполнителей. Заглушка подставляется вместо всей цепочки.
      expect(
        (await fiscal.fiscalizeSale(
          saleReceiptNo: 1,
          salePosId: 1,
          amount: Decimal.zero,
          cashAmount: Decimal.zero,
          cardAmount: Decimal.zero,
          mobileAmount: Decimal.zero,
          bonusAmount: Decimal.zero,
          offsetAmount: Decimal.zero,
          offsetLayout: OffsetFiscalLayout.discount,
          excludeCertificatePositions: false,
        )).queued,
        isFalse,
      );
      expect((await fiscal.openShift()).queued, isFalse);
    });
  });
}

LocalPaymentService _build() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final logger = Talker();
  final cart = LocalCartService(
    db: db,
    logger: logger,
    initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
    deferred: DeferredSaleServiceImpl(db: db, logger: logger),
    rounding: SaleRoundOptionUseCaseImpl(),
    findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
    searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
  );
  return LocalPaymentService(
    db: db,
    checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
    sale: SaleUseCaseImpl(db: db, logger: logger),
    logger: logger,
    fiscal: const RefusingFiscalService(),
    drawer: drawerOpens,
  );
}

FiscalSaleRequest _saleRequest() => FiscalSaleRequest(
  idempotencyKey: 'k',
  localOperationId: 1,
  positions: const [],
  payments: const [],
  totalDiscount: Decimal.zero,
  totalMarkup: Decimal.zero,
  occurredAt: DateTime(2026),
);

FiscalRefundRequest _refundRequest() => FiscalRefundRequest(
  sale: _saleRequest(),
  basis: FiscalRefundBasis(
    originalFiscalSign: '',
    originalDateTime: DateTime(2026),
    originalRegistrationNumber: '',
    originalTotal: Decimal.zero,
  ),
);

FiscalCorrectionRequest _correctionRequest() => const FiscalCorrectionRequest(
  idempotencyKey: 'k',
  positions: [],
  payments: [],
);
