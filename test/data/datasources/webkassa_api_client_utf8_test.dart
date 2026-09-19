library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

import '../../emulators/webkassa/emulator.dart';
import '../../emulators/webkassa/state.dart';

/// Тело запроса к WebKassa уходит **байтами UTF-8** — через настоящий
/// `_defaultSend`, а не подставленный `send:`.
///
/// # Почему здесь нет `send:`, и это главное в файле
///
/// До этой пробы кириллица до оператора не доезжала никогда:
/// `_defaultSend` писал тело `request.write(body)`, а `HttpClientRequest`
/// без `charset` в типе содержимого кодирует **latin1** и бросает
/// `Invalid argument (string): Contains invalid characters` на первой же
/// русской букве. Исключение становилось кодом `-3` → `network` → «в
/// очереди», `success: true`.
///
/// Набор этого не видел по трём независимым причинам, и каждая была
/// достаточной:
///
/// 1. четыре набора вокруг WebKassa подставляют `send:` — то есть обходят
///    ровно ту функцию, которая пишет тело в сокет;
/// 2. пробы, ходившие по настоящему сокету (`probe.dart`,
///    `live_till_test.dart`, `unfiscalized_row_test.dart`), брали названия
///    **латиницей намеренно** — «кириллица не доезжает, см. находку №1»;
/// 3. сама находка была закреплена в `probe.dart` **как дефект**: случай
///    ждал `network:-3` и сходился, пока дефект жив. Зелёный цвет означал
///    «дефект на месте», а `probe.dart` — скрипт `dart run`, не `flutter
///    test`, и в набор не входит вовсе.
///
/// # Как доказывается «побайтно»
///
/// Между клиентом и эмулятором стоит отвод ([_Tap]): он записывает сырые
/// байты тела и заголовки, а потом пересылает те же байты эмулятору.
/// Эмулятор декодирует тело строгим `utf8.decoder` — битый UTF-8 он не
/// принял бы вовсе.
void main() {
  const cashbox = 'SWK00000001';
  const regNumber = '000000000001';
  const coffee = 'Кофе молотый';
  const kumys = 'Қымыз ұлттық ₸';

  late EmulatorState state;
  late WebKassaEmulator emulator;
  late _Tap tap;
  late Uri tapUri;
  final logger = Talker(settings: TalkerSettings(enabled: false));

  setUp(() async {
    state = EmulatorState(
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
    emulator = WebKassaEmulator(state: state, echo: false);
    await emulator.start('127.0.0.1', 0);
    tap = _Tap(emulator.baseUri);
    tapUri = await tap.start();
  });

  tearDown(() async {
    await tap.stop();
    await emulator.stop();
  });

  FiscalSettings settingsAt(String baseUrl) => FiscalSettings(
    operatorType: FiscalOperatorType.webkassa,
    testMode: true,
    baseUrl: baseUrl,
    login: 'emul',
    password: 'emul',
    apiKey: 'emulated-integrator-key',
    cashboxUniqueNumber: cashbox,
    registrationNumber: regNumber,
  );

  FiscalPosition pos(String name, int price) => FiscalPosition(
    name: name,
    quantity: Decimal.one,
    unitPrice: Decimal.fromInt(price),
    lineTotal: Decimal.fromInt(price),
    tax: FiscalTax.none(),
  );

  test(
    'кириллица и казахские буквы доезжают до оператора теми же байтами UTF-8',
    () async {
      final settings = settingsAt(tapUri.toString());
      // Клиент БЕЗ `send:` — ходит настоящий `_defaultSend`.
      final provider = WebKassaProvider(
        settings: settings,
        logger: logger,
        client: WebKassaApiClient(
          baseUrl: settings.baseUrl!,
          apiKey: settings.apiKey,
          logger: logger,
        ),
      );

      final result = await provider.fiscalizeSale(
        FiscalSaleRequest(
          idempotencyKey: 'utf8-coffee-1',
          localOperationId: 1,
          positions: [pos(coffee, 1250), pos(kumys, 800)],
          payments: [
            FiscalPayment(
              kind: FiscalPaymentKind.cash,
              amount: Decimal.fromInt(2050),
            ),
          ],
          totalDiscount: Decimal.zero,
          totalMarkup: Decimal.zero,
          occurredAt: DateTime.now(),
        ),
      );

      expect(
        result.success,
        isTrue,
        reason:
            'чек с русским названием не фискализован: '
            '${result.errorCode.name} ${result.rawErrorCode} '
            '${result.errorMessage}',
      );
      expect(result.queued, isFalse, reason: 'успех очередью — не документ');
      expect(result.hasFiscalSign, isTrue);

      // --- что ушло в сокет ---
      final sent = tap.seen.where((s) => s.path == '/api/v4/check').toList();
      expect(sent, hasLength(1), reason: 'check до сокета не дошёл');
      final raw = sent.single;
      for (final name in [coffee, kumys]) {
        expect(
          _indexOf(raw.bytes, utf8.encode(name)),
          greaterThanOrEqualTo(0),
          reason: 'в теле нет байтов UTF-8 названия «$name»',
        );
      }
      expect(
        raw.contentLength,
        raw.bytes.length,
        reason: 'Content-Length обязан считать байты, а не буквы',
      );
      final type = ContentType.parse(raw.contentType ?? '');
      expect(type.mimeType, 'application/json');
      expect(type.charset?.toLowerCase(), 'utf-8');

      // --- что увидел оператор ---
      final check = state.journal.singleWhere(
        (e) => e.path == '/api/v4/check',
      );
      expect(check.outcome, 'ok');
      final names = [
        for (final p in (check.request['Positions'] as List).cast<Map>())
          p['PositionName'],
      ];
      expect(names, [coffee, kumys]);
    },
  );

  test(
    'запрос, который касса не может собрать, — код -4, а не сеть; '
    'токен и тело в текст отказа не попадают',
    () async {
      for (final baseUrl in ['http://', 'ftp://127.0.0.1:1']) {
        final client = WebKassaApiClient(
          baseUrl: baseUrl,
          apiKey: 'k',
          logger: logger,
        );
        try {
          final resp = await client.check({
            'Token': 'secret-token-XYZ',
            'Positions': [
              {'PositionName': coffee},
            ],
          });
          expect(resp.success, isFalse);
          expect(
            resp.errorCode,
            -4,
            reason:
                '«$baseUrl»: повтор такого запроса детерминированно повторит '
                'отказ; объявлять его сетью значит крутить очередь вечно. '
                'Пришло ${resp.errorCode}: ${resp.errorMessage}',
          );
          expect(resp.errorMessage, isNot(contains('secret-token-XYZ')));
          expect(resp.errorMessage, isNot(contains(coffee)));
        } finally {
          client.dispose();
        }
      }
    },
  );

  test('обрыв сокета остаётся сетью (-1) — очередь для него верна', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final client = WebKassaApiClient(
      baseUrl: 'http://127.0.0.1:$port',
      apiKey: 'k',
      logger: logger,
    );
    try {
      final resp = await client.check({
        'Positions': [
          {'PositionName': coffee},
        ],
      });
      expect(resp.errorCode, -1);
    } finally {
      client.dispose();
    }
  });

  test(
    'битые байты в ОТВЕТЕ — после отправки, значит сеть (-3), а не «не собран»',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        await req.drain<void>();
        req.response
          ..statusCode = 200
          ..add([0xFF, 0xFE, 0x7B]);
        await req.response.close();
      });
      final client = WebKassaApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        apiKey: 'k',
        logger: logger,
      );
      try {
        final resp = await client.check({
          'Positions': [
            {'PositionName': coffee},
          ],
        });
        expect(
          resp.errorCode,
          -3,
          reason:
              'запрос ушёл — документ у оператора мог появиться; это не '
              '«касса не собрала запрос»',
        );
      } finally {
        client.dispose();
        await server.close(force: true);
      }
    },
  );
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

class _Seen {
  _Seen({
    required this.path,
    required this.contentType,
    required this.contentLength,
    required this.bytes,
  });

  final String path;
  final String? contentType;
  final int contentLength;
  final Uint8List bytes;
}

/// Отвод между клиентом и эмулятором: пишет сырые байты и заголовки, потом
/// пересылает те же байты дальше. Тело не декодируется — иначе «побайтно»
/// превратилось бы в «после нашего же разбора».
class _Tap {
  _Tap(this.target);

  final Uri target;
  final List<_Seen> seen = [];
  HttpServer? _server;

  Future<Uri> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_forward);
    return Uri.parse('http://127.0.0.1:${server.port}');
  }

  Future<void> stop() async => _server?.close(force: true);

  Future<void> _forward(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    seen.add(
      _Seen(
        path: request.uri.path,
        contentType: request.headers.value(HttpHeaders.contentTypeHeader),
        contentLength: request.headers.contentLength,
        bytes: bytes,
      ),
    );

    final client = HttpClient();
    try {
      final out = await client.openUrl(
        request.method,
        target.replace(path: request.uri.path),
      );
      request.headers.forEach((name, values) {
        if (const {
          'host',
          'content-length',
          'connection',
          'transfer-encoding',
        }.contains(name)) {
          return;
        }
        out.headers.set(name, values);
      });
      out.contentLength = bytes.length;
      out.add(bytes);
      final resp = await out.close();
      final back = BytesBuilder(copy: false);
      await for (final chunk in resp) {
        back.add(chunk);
      }
      request.response.statusCode = resp.statusCode;
      final type = resp.headers.value(HttpHeaders.contentTypeHeader);
      if (type != null) {
        request.response.headers.set(HttpHeaders.contentTypeHeader, type);
      }
      request.response.add(back.takeBytes());
    } finally {
      client.close(force: true);
      await request.response.close();
    }
  }
}
