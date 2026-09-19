/// Стенд фискальных проб: эмулятор WebKassa на **настоящем сокете** и
/// настоящий `WebKassaApiClient._defaultSend`, без подмены `send:`.
///
/// # Почему без `send:`
///
/// Подменённый транспорт полгода прятал латиницу-1 в теле запроса: он не
/// смотрит в байты и не бросает тех исключений, которые бросает сокет. Здесь
/// всё, что между кассой и оператором, — настоящее; подставлен только сам
/// оператор.
///
/// # Почему порты 18300–18399, а не `0`
///
/// Правило машины: эмуляторы этой линии — только в этом окне. Порт `0` дал
/// бы эфемерный порт где угодно, в том числе на месте чужого стенда.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

import '../../../emulators/webkassa/emulator.dart';
import '../../../emulators/webkassa/state.dart';

const String kRigCashbox = 'SWK00000001';
const String kRigRegNumber = '000000000001';

class WebKassaRig {
  WebKassaRig._(
    this.emulator,
    this.state,
    this.settings,
    this.provider,
    this.store,
    this.queued,
  );

  final WebKassaEmulator emulator;
  final EmulatorState state;
  final FiscalSettings settings;
  final WebKassaProvider provider;
  final InMemoryFiscalQueueStore store;
  final OfflineQueueingProvider queued;

  /// Взять токен заранее — иначе отказ пульта придётся на `Authorize`, а не
  /// на сам документ.
  Future<void> warm() => provider.authorize(settings);

  Future<void> console(
    String path, [
    Map<String, Object?> body = const {},
  ]) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(emulator.baseUri.replace(path: path));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      final resp = await req.close();
      await resp.drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  /// Ключи документов, **дошедших до оператора** путём [path].
  ///
  /// Запись `delayed` пропускается: пульт задержки пишет в журнал **свою**
  /// строку до ответа, и один запрос под задержкой иначе считался бы дважды
  /// (так первый замер и показал «четыре отправки» там, где их было две).
  List<String> sentKeys([String path = '/api/v4/check']) => [
    for (final e in state.journal)
      if (e.path == path && e.outcome != 'delayed')
        '${e.request['ExternalCheckNumber']}',
  ];

  /// Ключи документов, которые оператор **принял**.
  List<String> acceptedKeys([String path = '/api/v4/check']) => [
    for (final e in state.journal)
      if (e.path == path && e.outcome == 'ok')
        '${e.request['ExternalCheckNumber']}',
  ];

  Future<void> stop() async {
    provider.dispose();
    await emulator.stop();
  }
}

/// Поднять эмулятор в окне 18300–18399 и собрать кассу против него.
///
/// [scheme] `https` — адрес кассы с чужой схемой к порту без TLS: так
/// производится `HandshakeException` на настоящем сокете.
Future<WebKassaRig> startWebKassaRig({
  Duration clientTimeout = const Duration(seconds: 30),
  String scheme = 'http',
  FiscalReachabilityCheck? isReachable,
  void Function()? onOperatorReached,
}) async {
  final state = EmulatorState(
    cashboxes: {
      kRigCashbox: EmulatedCashbox(
        uniqueNumber: kRigCashbox,
        registrationNumber: kRigRegNumber,
        now: DateTime.now(),
      ),
    },
    login: 'emul',
    password: 'emul',
    tokenTtl: const Duration(hours: 1),
    vat: VatMode.off,
  );
  final emulator = WebKassaEmulator(state: state, echo: false);
  await bindInLineWindow(emulator);

  final url = '$scheme://127.0.0.1:${emulator.baseUri.port}';
  final settings = FiscalSettings(
    operatorType: FiscalOperatorType.webkassa,
    testMode: true,
    baseUrl: url,
    login: 'emul',
    password: 'emul',
    apiKey: 'emulated-integrator-key',
    cashboxUniqueNumber: kRigCashbox,
    registrationNumber: kRigRegNumber,
  );
  final logger = Talker(settings: TalkerSettings(enabled: false));
  final provider = WebKassaProvider(
    settings: settings,
    logger: logger,
    client: WebKassaApiClient(
      baseUrl: url,
      apiKey: settings.apiKey,
      logger: logger,
      timeout: clientTimeout,
    ),
  );
  final store = InMemoryFiscalQueueStore();
  final queued = OfflineQueueingProvider(
    inner: provider,
    store: store,
    isReachable: isReachable ?? () async => true,
    onOperatorReached: onOperatorReached,
  );
  return WebKassaRig._(emulator, state, settings, provider, store, queued);
}

/// Занять первый свободный порт окна 18300–18399.
Future<void> bindInLineWindow(WebKassaEmulator emulator) async {
  SocketException? last;
  for (var port = 18300; port <= 18399; port++) {
    try {
      await emulator.start('127.0.0.1', port);
      return;
    } on SocketException catch (e) {
      last = e;
    }
  }
  throw StateError('окно 18300–18399 занято целиком: $last');
}

Decimal rigD(String v) => Decimal.parse(v);

/// Продажа на [amount] одной позицией, наличными.
FiscalSaleRequest rigSale(
  String key, {
  String amount = '100',
  DateTime? at,
  String name = 'Кофе молотый',
}) => FiscalSaleRequest(
  idempotencyKey: key,
  localOperationId: key.hashCode.abs() % 100000,
  positions: [
    FiscalPosition(
      name: name,
      quantity: Decimal.one,
      unitPrice: rigD(amount),
      lineTotal: rigD(amount),
      tax: FiscalTax.none(),
    ),
  ],
  payments: [FiscalPayment(kind: FiscalPaymentKind.cash, amount: rigD(amount))],
  totalDiscount: Decimal.zero,
  totalMarkup: Decimal.zero,
  occurredAt: at ?? DateTime.now(),
);

/// Возврат. [basisKey] — ключ документа-основания, если он назван.
///
/// По умолчанию **не назван**, и это не лень: строки, легшие до правки
/// 2026-09-19, и возвраты без чека приходят именно такими, а прежние пробы
/// очереди меряют как раз их. Осторожное правило на них обязано работать
/// по-прежнему.
FiscalRefundRequest rigRefund(
  String key, {
  String amount = '100',
  DateTime? at,
  String? basisKey,
  String basisSign = '',
}) => FiscalRefundRequest(
  sale: rigSale(key, amount: amount, at: at),
  basis: FiscalRefundBasis(
    originalFiscalSign: basisSign,
    originalDateTime: at ?? DateTime.now(),
    originalRegistrationNumber: kRigRegNumber,
    originalTotal: rigD(amount),
    originalWasOffline: true,
    originalIdempotencyKey: basisKey,
  ),
);

/// Изъятие из ящика — документ, зависящий от **остатка**, а не от
/// основания.
FiscalMoneyRequest rigMoneyOut(
  String key, {
  String amount = '50',
  DateTime? at,
}) => FiscalMoneyRequest(
  idempotencyKey: key,
  amount: rigD(amount),
  occurredAt: at ?? DateTime.now(),
  comment: 'инкассация',
);

/// Строка очереди ровно того вида, какой кладёт `OfflineQueueingProvider`.
FiscalQueueEntry rigSaleRow(FiscalSaleRequest req) => FiscalQueueEntry(
  idempotencyKey: req.idempotencyKey,
  opType: FiscalQueueOp.sale,
  payload: req.toJson(),
  occurredAt: req.occurredAt,
);

FiscalQueueEntry rigRefundRow(FiscalRefundRequest req) => FiscalQueueEntry(
  idempotencyKey: req.sale.idempotencyKey,
  opType: FiscalQueueOp.refund,
  payload: req.toJson(),
  occurredAt: req.sale.occurredAt,
);

FiscalQueueEntry rigMoneyOutRow(FiscalMoneyRequest req) => FiscalQueueEntry(
  idempotencyKey: req.idempotencyKey,
  opType: FiscalQueueOp.moneyOut,
  payload: req.toJson(),
  occurredAt: req.occurredAt,
);
