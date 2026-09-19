// Политика `isOfdSale` стоит **раньше** провайдера — и это измерено, а не
// выведено из чтения.
//
// # Зачем эта проба существует
//
// Задача 2 заменила `NoOp*` на `Refusing*`: заглушка перестала возвращать
// успех и стала возвращать названный отказ. Само по себе такое изменение
// читается пугающе — «каждая продажа стала нефискальной»: ведь реестр
// подставляет отказывающего провайдера ровно там, где раньше подставлял
// молчаливо-успешного.
//
// Здесь доказано, что это не так, и доказано на **настоящей продаже**, а не
// на рассуждении о вызовах. Цепочка такая:
//
//   LocalPaymentService._fiscalize
//     → isOfdSale(...)
//       → FiscalService.isEnabled()      // = settings.operatorType != none
//     → если false — исход `operatorAbsent` (задача 5 развела три причины,
//       прежде слитые в `notRequired`), и провайдер **не резолвится вовсе**.
//
// То есть `operatorType == none` отсекается настройкой, до реестра. Отказ
// `Refusing*` достижим только тогда, когда оператор выбран, но не
// зарегистрирован, — и там отказ верен: оператор назван, а исполнителя за
// ним нет. Раньше в этом случае чек уходил покупателю с обещанием очереди,
// которой не существует.
//
// # Почему проба не зелена сама собой
//
// Шпион здесь двойной: он считает и `resolve` реестра, и вызовы
// провайдера. Проба «шпиона не позвали» ничего не стоит, если шпион
// подключён мимо — поэтому вторая проба в этой же группе **включает**
// оператора и требует, чтобы тот же самый шпион был позван. Ноль вызовов
// значим лишь рядом с измеренной единицей.
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import '../../helpers/cash_drawer.dart';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalSaleCheckoutService checkout;
  late Talker logger;
  late _SpyRegistry registry;

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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // `ofdSyncType` не задан — значит 0, «фискализовать всё». Самая
    // требовательная из настроек: если чек ускользает от провайдера даже
    // здесь, дело в операторе, а не в выборочности.
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
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(posAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(d('0')),
            visibleToPos: const Value(true),
          ),
        );

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
    checkout = LocalSaleCheckoutService(db: db, cart: cart, logger: logger);
    registry = _SpyRegistry();
  });

  tearDown(() async {
    await db.close();
  });

  LocalPaymentService paymentsWith(FiscalSettings settings) {
    final fiscal = FiscalServiceImpl(
      db: db,
      registry: registry,
      settingsSource: _FixedSettings(settings),
      logger: logger,
    );
    return LocalPaymentService(
      db: db,
      checkout: checkout,
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: fiscal,
      fiscalQueue: DriftFiscalQueueStore(db),
      printer: null,
      drawer: drawerOpens,
    );
  }

  Future<CartView> receipt() async {
    var view = await cart.start(terminalId: 7, wholesale: false, meta: m(1, 0));
    view = await cart.addByBarcode(7, barcodeA, mv(view, 2));
    return view;
  }

  group('политика стоит раньше провайдера', () {
    test(
      'касса без оператора: продажа даёт operatorAbsent, провайдер не позван',
      () async {
        final payments = paymentsWith(FiscalSettings());
        final view = await receipt();

        final outcome = await payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('500')),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        // Деньги взяты — продажа состоялась, а не отменилась отказом.
        expect(outcome.paid, d('500'));

        // Причина названа своим словом, а не слита с «документ не нужен по
        // политике чека»: оператора у кассы нет. Разведено задачей 5; до неё
        // здесь стоял `notRequired`, и по нему нельзя было отличить
        // ненастроенную кассу от законно нефискальной продажи.
        expect(outcome.fiscal.state, FiscalState.operatorAbsent);
        expect(
          outcome.fiscal.state,
          isNot(FiscalState.notRequired),
          reason: 'ненастроенная касса не имеет права выглядеть законной',
        );

        // Главное утверждение задачи: до реестра дело не дошло. Значит
        // `Refusing*` не участвовал, и продажа не стала нефискальной
        // из-за него.
        expect(
          registry.resolveCalls,
          0,
          reason: 'политика отсекла чек до реестра',
        );
        expect(registry.spy.calls, isEmpty, reason: 'провайдер не позван');
      },
    );

    test(
      'тот же шпион ПОЗВАН, когда оператор выбран — ноль выше не пустой',
      () async {
        final payments = paymentsWith(
          FiscalSettings(
            operatorType: FiscalOperatorType.webkassa,
            apiKey: 'WKD-1',
            login: 'a@b.kz',
            cashboxUniqueNumber: 'SWK1',
          ),
        );
        final view = await receipt();

        await payments.complete(
          7,
          PaymentRequest(type: PaymentType.cash, cashReceived: d('500')),
          mv(view, 9),
        );
        await payments.pendingSideEffects;

        expect(registry.resolveCalls, greaterThan(0));
        expect(
          registry.spy.calls,
          contains('fiscalizeSale'),
          reason: 'шпион подключён на настоящем пути — ноль выше значим',
        );
      },
    );
  });
}

/// Реестр-шпион: считает `resolve` и всегда выдаёт один и тот же
/// провайдер-шпион, какой бы оператор ни был назван.
class _SpyRegistry extends FiscalProviderRegistry {
  int resolveCalls = 0;
  final _SpyProvider spy = _SpyProvider();

  @override
  FiscalProvider resolve(FiscalSettings settings) {
    resolveCalls++;
    return spy;
  }
}

class _SpyProvider implements FiscalProvider {
  final List<String> calls = [];

  @override
  String get id => 'spy';

  @override
  FiscalCapabilities get capabilities => FiscalCapabilities.none;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async {
    calls.add('authorize');
    return FiscalAuthResult.ok();
  }

  @override
  String? validateConfig(FiscalSettings config) {
    calls.add('validateConfig');
    return null;
  }

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    calls.add('fiscalizeSale');
    return FiscalResult.ok(fiscalSign: 'SPY-1');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async {
    calls.add('fiscalizeRefund');
    return FiscalResult.ok(fiscalSign: 'SPY-2');
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async {
    calls.add('fiscalizePurchase');
    return FiscalResult.ok(fiscalSign: 'SPY-3');
  }

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async {
    calls.add('fiscalizePurchaseReturn');
    return FiscalResult.ok(fiscalSign: 'SPY-4');
  }

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async {
    calls.add('moneyIn');
    return FiscalResult.ok(fiscalSign: 'SPY-5');
  }

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async {
    calls.add('moneyOut');
    return FiscalResult.ok(fiscalSign: 'SPY-6');
  }

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async {
    calls.add('openShift');
    return const FiscalResult(success: true);
  }

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async {
    calls.add('closeShift');
    return const FiscalReportResult(result: FiscalResult(success: true));
  }

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async {
    calls.add('xReport');
    return const FiscalReportResult(result: FiscalResult(success: true));
  }

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async {
    calls.add('correctionReceipt');
    return const FiscalResult(success: true);
  }

  @override
  Future<FiscalStatus> getStatus() async {
    calls.add('getStatus');
    return const FiscalStatus(configured: true, active: true, online: true);
  }
}

class _FixedSettings implements FiscalSettingsSource {
  _FixedSettings(this.settings);

  final FiscalSettings settings;

  @override
  Future<FiscalSettings> load() async => settings;
}
