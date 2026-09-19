/// После обновления кассы браузер получает новый бандл — задача 42.
///
/// Измерено живой приёмкой 2026-09-07: пересобранный бандл открытой вкладке
/// не виден — хэш на диске и в отдаче совпадал, а вкладка исполняла прежний
/// код. `main.dart.js` и `flutter_bootstrap.js` подключаются без версии в
/// адресе, а касса отдавала их без `Cache-Control`. Без этого заголовка
/// браузер кэширует по эвристике (доля возраста файла от `Last-Modified`) и
/// **не спрашивает** кассу вовсе — «обновление не помогло».
///
/// Проверяется настоящий сервер поверх настоящего TLS, тем же способом, каким
/// бандл прочитает планшет: заголовок, выставленный в обход сокета, доказывал
/// бы только то, что метод его возвращает.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/data/database/app_database.dart';

import 'support/noop_api_server.dart';
import 'support/noop_auth.dart';

void main() {
  late AppDatabase db;
  late Directory bundle;

  File bundleFile(String name) =>
      File('${bundle.path}${Platform.pathSeparator}$name');

  ApiServer build() => ApiServer(
    db: db,
    bootstrap: NoopBootstrap(),
    setup: NoopSetup(),
    terminals: NoopTerminals(),
    deviceBindings: NoopBindings(),
    auth: NoopAuth(),
    port: 0,
    frontendDirectory: bundle.path,
    invites: PairingInvites(),
    certificateThrottle: CertificateThrottle(),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bundle = Directory.systemTemp.createTempSync('telepos-bundle-cache');
    bundleFile(
      'index.html',
    ).writeAsStringSync('<html><head></head><body>till</body></html>');
    bundleFile('main.dart.js').writeAsStringSync('// build 1');
    bundleFile('flutter_bootstrap.js').writeAsStringSync('// bootstrap 1');
  });

  tearDown(() async {
    await db.close();
    bundle.deleteSync(recursive: true);
  });

  Future<ApiServer> started() async {
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);
    return server;
  }

  Future<HttpClientResponse> get(
    ApiServer server,
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient(context: _trustingTestRoot());
    addTearDown(() => client.close(force: true));
    final request = await client.getUrl(Uri.parse('${server.url!}$path'));
    headers.forEach(request.headers.set);
    return request.close();
  }

  Future<String> body(HttpClientResponse response) =>
      response.transform(const SystemEncoding().decoder).join();

  test('скрипты бандла отдаются с обязательной проверкой у кассы', () async {
    final server = await started();

    for (final path in ['/main.dart.js', '/flutter_bootstrap.js']) {
      final response = await get(server, path);
      await body(response);
      expect(response.statusCode, 200, reason: 'предпосылка: $path отдан');
      expect(
        response.headers.value(HttpHeaders.cacheControlHeader),
        'no-cache',
        reason:
            '$path без версии в адресе: без no-cache браузер держит его по '
            'эвристике и после обновления кассы исполняет прежний код',
      );
    }
  });

  test('документ не хранится вовсе', () async {
    final server = await started();

    final response = await get(server, '/');
    expect(await body(response), contains('TELEPOS_TOKEN'));
    expect(
      response.headers.value(HttpHeaders.cacheControlHeader),
      'no-store',
      reason:
          'документ собирается на лету (впрыснуты токен и отпечаток листа '
          'QUIC), проверять его нечем — и хранить в кэше браузера незачем',
    );
  });

  test('после пересборки повторный запрос получает новый бандл', () async {
    final server = await started();

    final first = await get(server, '/main.dart.js');
    expect(await body(first), '// build 1');
    final validator = first.headers.value(HttpHeaders.lastModifiedHeader);
    expect(validator, isNotNull, reason: 'предпосылка: проверять есть чем');

    // Пересборка: другой файл, более позднее время. Время двигается явно —
    // `Last-Modified` с точностью до секунды, и запись в ту же секунду
    // ответила бы 304 на законном основании.
    bundleFile('main.dart.js')
      ..writeAsStringSync('// build 2')
      ..setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));

    // Ровно то, что делает браузер под `no-cache`: спрашивает с валидатором.
    final second = await get(
      server,
      '/main.dart.js',
      headers: {HttpHeaders.ifModifiedSinceHeader: validator!},
    );

    expect(second.statusCode, 200);
    expect(await body(second), '// build 2');
  });

  test('без пересборки проверка стоит 304, а не повторной закачки', () async {
    final server = await started();

    final first = await get(server, '/main.dart.js');
    await body(first);
    final validator = first.headers.value(HttpHeaders.lastModifiedHeader)!;

    final second = await get(
      server,
      '/main.dart.js',
      headers: {HttpHeaders.ifModifiedSinceHeader: validator},
    );
    await body(second);

    expect(
      second.statusCode,
      304,
      reason:
          'no-cache дёшев ровно потому, что проверка отвечает 304: иначе '
          'каждое открытие страницы качало бы бандл целиком. shelf_static '
          '1.1.3 сам этого не делает на Windows — оставляет микросекунды '
          'времени файла, и оно всегда «позже» валидатора',
    );
    expect(second.headers.value(HttpHeaders.cacheControlHeader), 'no-cache');
  });

  test('документ с условием всё равно отдаётся целиком', () async {
    final server = await started();

    final first = await get(server, '/');
    await body(first);
    // У документа валидатора нет — берётся время самого файла, как если бы
    // браузер унёс его из прежней, ещё не запрещавшей хранение отдачи.
    final stamp = HttpDate.format(
      bundleFile('index.html').lastModifiedSync().add(const Duration(hours: 1)),
    );

    final second = await get(
      server,
      '/',
      headers: {HttpHeaders.ifModifiedSinceHeader: stamp},
    );

    expect(
      second.statusCode,
      200,
      reason:
          '304 на собранный на лету документ отдал бы вкладке прежний токен',
    );
    expect(await body(second), contains('TELEPOS_TOKEN'));
  });
}

SecurityContext _testContext() => SecurityContext(withTrustedRoots: false)
  ..useCertificateChain('test/backend/fixtures/insecure_test_leaf.crt')
  ..usePrivateKey('test/backend/fixtures/insecure_test_leaf.key');

SecurityContext _trustingTestRoot() => SecurityContext(withTrustedRoots: false)
  ..setTrustedCertificates('test/backend/fixtures/insecure_test_ca.crt');
