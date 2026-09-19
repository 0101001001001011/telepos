library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
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
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import '../../emulators/webkassa/emulator.dart';
import '../../emulators/webkassa/state.dart';
import '../../helpers/cash_drawer.dart';

/// Строка отказа фискализации — задача 11.
///
/// # Что здесь доказывается, и почему не набором заглушек
///
/// Утверждение задачи звучит так: **ключ строки отказа — тот самый, с
/// которым к оператору ходил провайдер**. Проверить это подставным
/// провайдером нельзя: подставной вернёт тот ключ, который ему велели
/// вернуть, и проба докажет саму себя. Единственный свидетель настоящего
/// ключа — **оператор**: он видит `ExternalCheckNumber` в теле запроса.
/// Поэтому здесь стоит эмулятор WebKassa, и утверждение делается против
/// его журнала, а не против нашей памяти.
///
/// Цепочка настоящая целиком: `LocalPaymentService` → `FiscalServiceImpl`
/// (он и собирает `FiscalSaleRequest`) → `OfflineQueueingProvider` →
/// `WebKassaProvider` → HTTP → эмулятор. Подставлены только принтер и
/// ящик, которых здесь нет вовсе.
///
/// # Три измеренных дефекта самой строки, каждый со своим утверждением
///
/// 1. **Ключ был чужой** — `'sale-unfiscalized:$posId-$receiptNo'` против
///    провайдерского `'sale-$receiptNo-$posId'`. Человеческий повтор по
///    такой строке дедупликация оператора **не узнала бы**, и на одну
///    продажу приехали бы два фискальных документа.
/// 2. **Payload был запиской** `{receiptNo, posId, amount}` — повторять
///    нечем; пересборка из базы чека уехала бы с другим ключом и с
///    другими числами.
/// 3. **ИИН/БИН покупателя** в строку не кладётся: это персональные
///    данные, а строка живёт до тех пор, пока её не разберёт человек.
void main() {
  late AppDatabase db;
  WebKassaEmulator? emulator;
  late EmulatorState emulState;
  late String baseUrl;
  late DriftFiscalQueueStore store;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late FiscalService fiscal;
  late Talker logger;

  const barcode = '4870001234567';
  const posAccountId = 11;
  const cashbox = 'SWK00000001';
  const regNumber = '000000000001';

  /// Адрес **отдельно поднятого** эмулятора, если он есть — тогда это
  /// настоящий чужой процесс на настоящем сокете, и от боевой WebKassa он
  /// отличается только адресом.
  ///
  /// ```
  /// dart run test/emulators/webkassa/emulator.dart --port 8085 --token-ttl 1h
  /// TELEPOS_EMUL_URL=http://127.0.0.1:8085 flutter test test/data/fiscal/unfiscalized_row_test.dart
  /// ```
  final external = Platform.environment['TELEPOS_EMUL_URL'];
  final inProcess = external == null || external.isEmpty;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n, int base, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$n', baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  /// Пульт эмулятора — по HTTP, как им пользуется человек, а не через
  /// внутренности процесса.
  Future<void> console(String path, Map<String, Object?> body) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$baseUrl$path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close();
      await res.drain<void>();
    } finally {
      client.close();
    }
  }

  /// Журнал — из памяти процесса, когда эмулятор в процессе, и через
  /// пульт `/_emul/journal`, когда он чужой. Читать память теста при
  /// внешнем эмуляторе было бы самообманом: она пуста при любом исходе.
  Future<List<JournalEntry>> journal() async =>
      inProcess ? emulState.journal : await _externalJournal(baseUrl);

  /// Чек на 1000: две штуки товара по 500. Латиница — наследие находки №1
  /// эмулятора (кириллица не доезжала до сервера; починено 2026-09-13,
  /// русское название закрывает `cyrillic_receipt_fiscalized_test.dart`).
  Future<CartView> receipt({int terminalId = 7}) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(1, 0),
    );
    view = await cart.addByBarcode(terminalId, barcode, mv(view, 2));
    return cart.setQuantity(terminalId, view.lines.single.id, d('2'), mv(view, 3));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            cashBoxName: Value('Kassa 1'),
            companyName: Value('TOO Romashka'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Aigul')));
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
            name: 'Emulated bread',
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
            name: const Value('Kassa'),
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
    if (inProcess) {
      final started = WebKassaEmulator(state: emulState, echo: false);
      await started.start('127.0.0.1', 0);
      emulator = started;
      baseUrl = started.baseUri.toString();
    } else {
      emulator = null;
      baseUrl = external;
      // Чужой процесс держит состояние между прогонами: без сброса вторая
      // продажа получила бы код 14 и была бы принята за дефект.
      await _resetExternal(baseUrl);
    }

    final settings = FiscalSettings(
      operatorType: FiscalOperatorType.webkassa,
      testMode: true,
      baseUrl: baseUrl,
      login: 'emul',
      password: 'emul',
      apiKey: 'emulated-integrator-key',
      cashboxUniqueNumber: cashbox,
      registrationNumber: regNumber,
    );

    logger = Talker();
    store = DriftFiscalQueueStore(db);
    final registry = FiscalProviderRegistry()
      ..register(
        FiscalOperatorType.webkassa,
        (s) => OfflineQueueingProvider(
          inner: WebKassaProvider(settings: s, logger: logger),
          store: store,
          isReachable: () async => true,
        ),
      );
    fiscal = FiscalServiceImpl(
      db: db,
      registry: registry,
      settingsSource: _StaticSettings(settings),
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
  });

  tearDown(() async {
    await emulator?.stop();
    await db.close();
  });

  test(
    'строка отказа несёт документ и ТОТ ЖЕ ключ, которым ходил провайдер',
    () async {
      // Код 1 — `badCredentials`: нетранзиентный отказ, очередь его не
      // берёт, и чек становится ровно тем случаем, ради которого задача
      // существует: деньги взяты, документа нет.
      await console('/_emul/fault', {
        'path': '/api/v4/check',
        'code': 1,
        'count': 1,
      });

      final view = await receipt();
      final outcome = await payments.complete(
        7,
        PaymentRequest(
          type: PaymentType.cash,
          cashReceived: d('1000'),
          customerBin: '901010300455',
        ),
        mv(view, 9),
      );

      // Журнал эмулятора печатается целиком — он и есть свидетель ключа.
      final log = await journal();
      // ignore: avoid_print
      print(
        '\n--- Журнал эмулятора (${log.length} записей, '
        '${inProcess ? 'в процессе' : 'внешний: $baseUrl'}) ---',
      );
      for (final e in log) {
        // ignore: avoid_print
        print(e.line);
      }

      expect(outcome.paid, d('1000'), reason: 'деньги взяты');
      expect(outcome.fiscal.state, FiscalState.failed);

      // Ключ, который **видел оператор**, а не тот, который мы помним.
      final check = log.firstWhere((e) => e.path == '/api/v4/check');
      final sentKey = check.request['ExternalCheckNumber'] as String;

      final failed = await store.failed();
      expect(failed, hasLength(1));
      expect(
        failed.single.idempotencyKey,
        sentKey,
        reason:
            'сегодня ключ чужой: sale-unfiscalized:posId-receiptNo — '
            'дедупликация оператора его не узнает, и человеческий повтор '
            'дал бы второй фискальный документ на одну продажу',
      );

      final payload = failed.single.payload;
      expect(
        payload['positions'],
        isNotEmpty,
        reason: 'сегодня payload — записка {receiptNo, posId, amount}',
      );
      expect(
        payload['idempotencyKey'],
        sentKey,
        reason: 'документ обязан нести тот же ключ, что и строка',
      );
      // **Покупатель в чеке ЕСТЬ** (`customerBin` выше) — иначе это
      // утверждение зеленело бы в пустоте: `customer` отсутствовал бы в
      // конверте и без всякой вырезки. Измерено диверсией: с чеком без
      // покупателя проба остаётся зелёной, даже если вырезку убрать.
      expect(
        payload.containsKey('customer'),
        isFalse,
        reason: 'binIin — персональные данные; при повторе берётся из продажи',
      );

      // Строка обязана быть повторяемой: это и есть «повторять есть чем».
      expect(failed.single.carriesDocument, isTrue);
    },
  );

  test('строка отказа несёт номер чека — по нему её и находят', () async {
    await console('/_emul/fault', {
      'path': '/api/v4/check',
      'code': 1,
      'count': 1,
    });
    final view = await receipt();
    final outcome = await payments.complete(
      7,
      PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
      mv(view, 9),
    );

    final failed = await store.failed();
    expect(failed.single.payload['localOperationId'], outcome.receiptNo);
    expect(await store.failedCount(), 1);
    expect(
      await store.pendingCount(),
      0,
      reason: 'нетранзиентный отказ не встаёт в очередь автоматического повтора',
    );
  });

  test(
    'повтор из сохранённого документа доезжает до оператора тем же ключом',
    () async {
      await console('/_emul/fault', {
        'path': '/api/v4/check',
        'code': 1,
        'count': 1,
      });
      final view = await receipt();
      await payments.complete(
        7,
        PaymentRequest(type: PaymentType.cash, cashReceived: d('1000')),
        mv(view, 9),
      );

      final entry = (await store.failed()).single;

      // Повтор идёт **нынешним** провайдером, собранным заново из нынешних
      // настроек, — ровно как его соберёт экран нефискализованных чеков.
      final resolved = OfflineQueueingProvider(
        inner: WebKassaProvider(
          settings: FiscalSettings(
            operatorType: FiscalOperatorType.webkassa,
            testMode: true,
            baseUrl: baseUrl,
            login: 'emul',
            password: 'emul',
            apiKey: 'emulated-integrator-key',
            cashboxUniqueNumber: cashbox,
            registrationNumber: regNumber,
          ),
          logger: logger,
        ),
        store: store,
        isReachable: () async => true,
      );

      final result = await resolved.retryFailed(entry);

      final log = await journal();
      // ignore: avoid_print
      print(
        '\n--- Журнал эмулятора на повторе '
        '(${inProcess ? 'в процессе' : 'внешний: $baseUrl'}) ---',
      );
      for (final e in log) {
        // ignore: avoid_print
        print(e.line);
      }

      expect(
        result.success,
        isTrue,
        reason: 'повтор: ${result.errorCode.name} ${result.errorMessage}',
      );
      expect(result.hasFiscalSign, isTrue);
      expect(
        await store.failedCount(),
        0,
        reason: 'удавшийся повтор снимает строку',
      );

      final checks = log.where((e) => e.path == '/api/v4/check').toList();
      expect(checks, hasLength(2), reason: 'первый отказ и повтор');
      expect(
        checks.last.request['ExternalCheckNumber'],
        checks.first.request['ExternalCheckNumber'],
        reason:
            'повтор идёт ТЕМ ЖЕ ключом — иначе дедупликация оператора его не '
            'узнает и на одну продажу приедут два документа',
      );
      expect(
        checks.last.request['Positions'],
        checks.first.request['Positions'],
        reason: 'повтор идёт сохранённым документом, а не пересобранным',
      );
    },
  );
}

/// Сброс состояния чужого эмулятора перед прогоном.
Future<void> _resetExternal(String baseUrl) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$baseUrl/_emul/reset'));
    req.headers.contentType = ContentType.json;
    req.write('{}');
    final resp = await req.close();
    await resp.drain<void>();
  } finally {
    client.close(force: true);
  }
}

/// Журнал внешнего эмулятора — через пульт, а не через память процесса.
Future<List<JournalEntry>> _externalJournal(String baseUrl) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('$baseUrl/_emul/journal'));
    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final raw in decoded['journal'] as List)
        JournalEntry(
          seq: (raw['seq'] as num).toInt(),
          at: DateTime.parse(raw['at'] as String),
          path: raw['path'] as String,
          request: (raw['request'] as Map).cast<String, Object?>(),
          response: (raw['response'] as Map).cast<String, Object?>(),
          reasons: (raw['reasons'] as List).map((e) => e.toString()).toList(),
          outcome: raw['outcome'] as String,
        ),
    ];
  } finally {
    client.close(force: true);
  }
}

class _StaticSettings implements FiscalSettingsSource {
  _StaticSettings(this._settings);
  final FiscalSettings _settings;
  @override
  Future<FiscalSettings> load() async => _settings;
}
