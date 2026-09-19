library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
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
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import '../../emulators/webkassa/emulator.dart';
import '../../emulators/webkassa/state.dart';
import '../../helpers/cash_drawer.dart';

/// Чек с **русским названием товара** доходит до оператора — через всю
/// цепочку кассы и настоящий сокет.
///
/// # Что было
///
/// Живая приёмка 2026-09-13: `POST /api/v4/check` бросал `Contains invalid
/// characters` в `WebKassaApiClient._defaultSend` (`request.write` =
/// latin1), клиент отдавал `-3`, провайдер — `network`, очередь — «в
/// очереди», `success: true`, `fiscalSign: null`. Эмулятор получил только
/// `Authorize`. Документа не было ни у одной продажи с кириллицей.
///
/// # Чем эта проба отличается от соседних
///
/// `unfiscalized_row_test.dart` и `live_till_test.dart` проходят ту же
/// цепочку, но с названием **латиницей, выбранной намеренно** — чтобы обойти
/// этот дефект. Обход и спрятал его на шесть дней. Здесь название
/// русское, и больше ничего не подменено: `LocalPaymentService` →
/// `FiscalServiceImpl` → `OfflineQueueingProvider` → `WebKassaProvider` →
/// `WebKassaApiClient._defaultSend` → эмулятор.
///
/// # Второй дефект того же места
///
/// Отказ, который **при повторе повторится детерминированно** (запрос не
/// собирается — адрес без узла, чужая схема), тоже приходил `-3` → `network`
/// и уходил «в очередь». Очередь повторяет `pending` только при старте
/// кассы (`replayPendingFiscal`), на `network` останавливается **целиком** и
/// попыток не считает — строка стояла бы вечно, загораживая всех, кто за
/// ней, пока окно 72 ч не спишет её с чужой причиной «превышено автономное
/// окно». Экран нефискализованных чеков читает только `failed`, и кассир её
/// не видел. Последние три пробы закрепляют различение.
void main() {
  late AppDatabase db;
  late WebKassaEmulator emulator;
  late EmulatorState emulState;
  late String baseUrl;
  late DriftFiscalQueueStore store;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late FiscalService fiscal;
  late Talker logger;
  var reachable = true;

  const barcode = '4870001234567';
  const posAccountId = 11;
  const cashbox = 'SWK00000001';
  const regNumber = '000000000001';
  const coffee = 'Кофе молотый';

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: v.version, receiptNo: v.receiptNo);

  FiscalSettings settingsAt(String url) => FiscalSettings(
    operatorType: FiscalOperatorType.webkassa,
    testMode: true,
    baseUrl: url,
    login: 'emul',
    password: 'emul',
    apiKey: 'emulated-integrator-key',
    cashboxUniqueNumber: cashbox,
    registrationNumber: regNumber,
  );

  OfflineQueueingProvider providerAt(String url) => OfflineQueueingProvider(
    inner: WebKassaProvider(settings: settingsAt(url), logger: logger),
    store: store,
    isReachable: () async => reachable,
  );

  /// Собирает кассу против адреса [url]. Провайдер строится реестром на
  /// каждый чек — как в `service_locator.dart`.
  void wire(String url) {
    final registry = FiscalProviderRegistry()
      ..register(FiscalOperatorType.webkassa, (s) => providerAt(s.baseUrl!));
    fiscal = FiscalServiceImpl(
      db: db,
      registry: registry,
      settingsSource: _StaticSettings(settingsAt(url)),
      logger: logger,
    );
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
      fiscal: fiscal,
      fiscalQueue: store,
      drawer: drawerOpens,
    );
  }

  /// Чек на 1000: две пачки «Кофе молотый» по 500.
  Future<SaleOutcome> sell({int terminalId = 7}) async {
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
    return payments.complete(
      terminalId,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );
  }

  void printJournal(String title) {
    // ignore: avoid_print
    print('\n--- $title (${emulState.journal.length} записей) ---');
    for (final e in emulState.journal) {
      // ignore: avoid_print
      print(e.line);
    }
  }

  setUp(() async {
    reachable = true;
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
            barcode: int.parse(barcode),
            name: coffee,
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
            name: const Value('Касса'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
          ),
        );

    emulState = EmulatorState(
      cashboxes: {
        cashbox: EmulatedCashbox(
          uniqueNumber: cashbox,
          registrationNumber: regNumber,
          now: DateTime.now(),
        ),
      },
      login: 'emul',
      password: 'emul',
      tokenTtl: const Duration(hours: 1),
      vat: VatMode.off,
    );
    emulator = WebKassaEmulator(state: emulState, echo: false);
    await emulator.start('127.0.0.1', 0);
    baseUrl = emulator.baseUri.toString();

    logger = Talker(settings: TalkerSettings(enabled: false));
    store = DriftFiscalQueueStore(db);
    wire(baseUrl);
  });

  tearDown(() async {
    await emulator.stop();
    await db.close();
  });

  test('продажа «Кофе молотый» фискализована: документ есть, очереди нет', () async {
    final outcome = await sell();
    printJournal('Журнал эмулятора');

    expect(outcome.paid, d('1000'));
    expect(
      outcome.fiscal.state,
      FiscalState.done,
      reason:
          'чек с русским названием не фискализован: ${outcome.fiscal.state} '
          '${outcome.fiscal.message}',
    );
    expect(outcome.fiscal.sign, isNotNull);
    expect(outcome.fiscal.sign, isNotEmpty);

    final check = emulState.journal.singleWhere(
      (e) => e.path == '/api/v4/check',
    );
    expect(check.outcome, 'ok');
    final position = (check.request['Positions'] as List).single as Map;
    expect(
      position['PositionName'],
      coffee,
      reason: 'название взято из ProductInfos и доехало тем же текстом',
    );

    final receipts = await db.select(db.webkassaReceipts).get();
    expect(receipts, hasLength(1));
    expect(receipts.single.fiscalNo, outcome.fiscal.sign);

    expect(await store.pendingCount(), 0, reason: 'успех не должен стоять в очереди');
    expect(await store.failedCount(), 0);
  });

  test(
    'чек с кириллицей, уже стоящий в очереди, при повторе уходит тем же ключом',
    () async {
      // Строка ложится ровно так, как ложилась у кассы на стенде: провайдер
      // вернул «в очереди», документ сохранён в payload.
      reachable = false;
      final queuedSale = await sell();
      expect(queuedSale.fiscal.state, FiscalState.queued);
      final queued = await store.pending();
      expect(queued, hasLength(1));
      final key = queued.single.idempotencyKey;
      expect(
        ((queued.single.payload['positions'] as List).single as Map)['name'],
        coffee,
      );
      expect(
        emulState.journal.where((e) => e.path == '/api/v4/check'),
        isEmpty,
        reason: 'пока оператор недоступен, до него ничего не доходит',
      );

      reachable = true;
      final report = await providerAt(baseUrl).replay();
      printJournal('Журнал эмулятора на повторе');

      expect(report.fiscalized, 1);
      expect(report.remaining, 0);
      expect(report.failed, 0);
      expect(report.stoppedOnNetwork, isFalse);
      expect(await store.pendingCount(), 0);
      expect(await store.failedCount(), 0);

      final check = emulState.journal.singleWhere(
        (e) => e.path == '/api/v4/check',
      );
      expect(check.outcome, 'ok');
      expect(check.request['ExternalCheckNumber'], key);
      expect(
        ((check.request['Positions'] as List).single as Map)['PositionName'],
        coffee,
      );
    },
  );

  test(
    'запрос не собирается (адрес без узла) — «документ не выдан» с причиной, '
    'а не «в очереди»',
    () async {
      wire('http://');

      final outcome = await sell();

      expect(
        outcome.fiscal.state,
        FiscalState.failed,
        reason:
            'повтор такого отказа детерминированно повторит его; «в очереди» '
            'обещает лечение, которого нет',
      );
      expect(await store.pendingCount(), 0);
      final failed = await store.failed();
      expect(failed, hasLength(1));
      expect(
        failed.single.carriesDocument,
        isTrue,
        reason: 'после исправления адреса человек повторит ровно этот документ',
      );
      expect(
        FiscalFailureReason.parse(failed.single.lastError)?.kind,
        FiscalFailureKind.requestNotBuilt,
        reason: 'причина — код словаря, а не русская фраза data-слоя',
      );
      expect(
        failed.single.lastError,
        isNot(contains('emul')),
        reason: 'ни логин, ни токен, ни тело в причину не попадают',
      );
      expect(outcome.fiscal.message, failed.single.lastError);
    },
  );

  test(
    'строки в очереди с несобираемым запросом повтор разбирает в failed, '
    'а не стоит на них вечно',
    () async {
      // Строки легли, пока оператор был недоступен, — это верная очередь.
      reachable = false;
      wire('http://');
      await sell(terminalId: 7);
      await sell(terminalId: 8);
      expect(await store.pendingCount(), 2);

      reachable = true;
      final replayer = providerAt('http://');
      final first = await replayer.replay();
      final second = await replayer.replay();

      // ignore: avoid_print
      print(
        'replay#1 fiscalized=${first.fiscalized} failed=${first.failed} '
        'remaining=${first.remaining} stoppedOnNetwork=${first.stoppedOnNetwork}\n'
        'replay#2 fiscalized=${second.fiscalized} failed=${second.failed} '
        'remaining=${second.remaining} stoppedOnNetwork=${second.stoppedOnNetwork}',
      );
      final rows = [...await store.pending(), ...await store.failed()];
      for (final r in rows) {
        // ignore: avoid_print
        print(
          '  ${r.idempotencyKey} status=${r.status.name} '
          'attempts=${r.attempts} lastError=${r.lastError}',
        );
      }

      expect(
        first.stoppedOnNetwork,
        isFalse,
        reason: 'несобираемый запрос — не сеть; остановка на нём загораживает всех',
      );
      expect(first.failed, 2);
      expect(first.remaining, 0);
      expect(second.failed, 0, reason: 'разобранное повтор больше не трогает');
      final failed = await store.failed();
      expect(failed, hasLength(2));
      for (final r in failed) {
        expect(r.attempts, 1);
        expect(
          FiscalFailureReason.parse(r.lastError)?.kind,
          FiscalFailureKind.requestNotBuilt,
        );
      }
      expect(
        emulState.journal,
        isEmpty,
        reason: 'до оператора такой запрос не доходит ни разу',
      );
    },
  );
}

class _StaticSettings implements FiscalSettingsSource {
  _StaticSettings(this._settings);
  final FiscalSettings _settings;
  @override
  Future<FiscalSettings> load() async => _settings;
}
