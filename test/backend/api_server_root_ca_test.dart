/// Корень магазина отдаётся в тот момент, когда человек привязывает планшет,
/// и ни в какой другой.
///
/// Проверяется настоящий сервер поверх настоящего TLS: ответ читается по HTTPS
/// тем же способом, каким его прочитает планшет. Ответ, собранный вызовом
/// метода в обход сокета, доказывал бы, что метод возвращает строку, и ничего
/// — о том, что эту строку отдают.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';

import 'support/noop_auth.dart';

/// Не сам корень кассы: `rk_pki` под `flutter test` не грузится. Здесь важно
/// одно — что отдаётся ровно то, что кассе дали, и только по коду.
const String _root = '-----BEGIN CERTIFICATE-----\nZmFrZQ==\n-----END '
    'CERTIFICATE-----\n';

void main() {
  late AppDatabase db;
  late Directory bundle;

  ApiServer build({String? rootPem = _root, PairingInvites? invites}) =>
      ApiServer(
        db: db,
        bootstrap: _NoopBootstrap(),
        setup: _NoopSetup(),
        terminals: _NoopTerminals(),
        deviceBindings: _NoopBindings(),
        auth: NoopAuth(),
        port: 0,
        frontendDirectory: bundle.path,
        rootCertificatePem: rootPem,
        // Пункт 3 волны правок «касса говорит, что набирать» (2026-08-23):
        // `invites` стал обязательным доводом ApiServer — этот `build()`
        // держит свой параметр `invites` опциональным для удобства теста, но
        // подставляет умолчание сам, а не полагается на умолчание конструктора
        // (его больше нет).
        invites: invites ?? PairingInvites(),
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bundle = Directory.systemTemp.createTempSync('telepos-ca-bundle');
    File(
      '${bundle.path}${Platform.pathSeparator}index.html',
    ).writeAsStringSync('<html><head></head><body>till</body></html>');
    // Второй признак бандла — см. kWebBundleMarkers.
    File(
      '${bundle.path}${Platform.pathSeparator}main.dart.js',
    ).writeAsStringSync('// stub');
  });

  tearDown(() async {
    await db.close();
    bundle.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> get(ApiServer server, String path) async {
    final client = HttpClient(context: _trustingTestRoot());
    final request = await client.getUrl(Uri.parse('${server.url!}$path'));
    final response = await request.close();
    addTearDown(() => client.close(force: true));
    return response;
  }

  // Пункт 5 волны правок «касса говорит, что набирать» (2026-08-23): до
  // правки диспетчеризация шла только по пути — любой метод доходил до
  // `_rootCertificate` и тратил код. Этот помощник открывает запрос
  // произвольным методом, а не только GET.
  Future<HttpClientResponse> request(
    ApiServer server,
    String method,
    String path,
  ) async {
    final client = HttpClient(context: _trustingTestRoot());
    final request = await client.openUrl(
      method,
      Uri.parse('${server.url!}$path'),
    );
    final response = await request.close();
    addTearDown(() => client.close(force: true));
    return response;
  }

  test('без кода корень не отдаётся', () async {
    // Корень, который отдают кому угодно, попадает на устройство без человека,
    // который в эту секунду решил ему доверять. Установка корня — это и есть
    // решение доверять, и принимать его должен тот, кто стоит у кассы.
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final response = await get(server, '/ca.crt');

    expect(response.statusCode, 403);
    final body = await response.transform(const SystemEncoding().decoder).join();
    expect(body, isNot(contains('BEGIN CERTIFICATE')));
    expect(body, isNotEmpty, reason: 'отказ обязан быть названным');
  });

  test('с чужим кодом — тот же отказ', () async {
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final response = await get(server, '/ca.crt?invite=ZZZZZZZZZZZZZZZZ');

    expect(response.statusCode, 403);
  });

  test('по действующему коду корень отдаётся целиком', () async {
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final invite = server.invites.mint();
    final response = await get(server, '/ca.crt?invite=${invite.code}');
    final body = await response.transform(const SystemEncoding().decoder).join();

    expect(response.statusCode, 200);
    expect(body, _root, reason: 'отдаётся ровно тот корень, что дали кассе');
    expect(
      response.headers.value('content-type'),
      contains('x-x509-ca-cert'),
      reason: 'по этому типу планшет открывает диалог установки, а не '
          'кладёт файл в загрузки',
    );
  });

  test('код тратится один раз', () async {
    // Пропуск, годный дважды, — это пропуск, оставшийся у того, кто им уже
    // воспользовался: планшет отдали, код в истории браузера, корень уедет на
    // второе устройство без второго решения человека.
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final invite = server.invites.mint();
    final first = await get(server, '/ca.crt?invite=${invite.code}');
    expect(first.statusCode, 200);
    await first.drain<void>();

    final second = await get(server, '/ca.crt?invite=${invite.code}');
    expect(second.statusCode, 403);
  });

  test(
    'код, мятый через тот же синглтон get_it, что получит экран '
    'привязки, принимается /ca.crt',
    () async {
      // Не голый `PairingInvites()` — а тот приём, которым `main.dart`
      // передаёт `invites` в `ApiServer` (`GetIt.I<PairingInvites>()`,
      // зарегистрированный `configureDependencies` в
      // `lib/app/di/service_locator.dart`). Тест воспроизводит эту цепочку,
      // чтобы доказать: список, из которого мятит код будущий экран привязки
      // (задача 2), и список, который тратит `/ca.crt`, — один и тот же
      // объект, а не два, которые кто-то забыл бы держать в согласии. Второй
      // список означал бы код, потраченный на одном и оставшийся годным на
      // другом — ровно то, что докстринг `invites` в `ApiServer` называет
      // ошибкой прямо.
      final shared = PairingInvites();
      GetIt.I.registerSingleton<PairingInvites>(shared);
      addTearDown(() => GetIt.I.unregister<PairingInvites>());

      final server = build(invites: GetIt.I<PairingInvites>());
      expect(await server.start(context: _testContext()), isA<String>());
      addTearDown(server.stop);

      // Мятит код тем способом, каким это сделает будущий экран: через
      // GetIt, а не через `server.invites` напрямую.
      final invite = GetIt.I<PairingInvites>().mint();
      final response = await get(server, '/ca.crt?invite=${invite.code}');
      final body = await response
          .transform(const SystemEncoding().decoder)
          .join();

      expect(response.statusCode, 200);
      expect(body, _root, reason: 'корень отдан по коду из общего списка');
    },
  );

  test('просроченный код не действует', () async {
    // Код живёт минуты. Просроченный, найденный в истории через неделю, — это
    // ровно та ситуация, ради которой у него есть срок.
    var now = DateTime(2026, 8, 5, 12);
    final invites = PairingInvites(
      lifetime: const Duration(minutes: 15),
      clock: () => now,
    );
    final server = build(invites: invites);
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final invite = invites.mint();
    now = now.add(const Duration(minutes: 16));

    final response = await get(server, '/ca.crt?invite=${invite.code}');
    expect(response.statusCode, 403);
  });

  test(
    'HEAD не выдаёт корень и не тратит код — назван отказ, а не 200',
    () async {
      // До пункта 5 диспетчер решал только по пути: HEAD доходил до
      // `_rootCertificate`, звал `redeem()` и отвечал 200 с тем же телом,
      // что и GET — сжигая код, ничего не доставив по-настоящему тому, кто
      // послал HEAD ради проверки, а не человеку с планшетом.
      final server = build();
      expect(await server.start(context: _testContext()), isA<String>());
      addTearDown(server.stop);

      final invite = server.invites.mint();
      final headResponse = await request(
        server,
        'HEAD',
        '/ca.crt?invite=${invite.code}',
      );
      expect(headResponse.statusCode, 405);
      expect(headResponse.headers.value('allow'), 'GET');

      // Главное доказательство: код пережил HEAD. Настоящий GET тем же кодом
      // всё ещё отдаёт корень — HEAD его не тронул.
      final getResponse = await get(server, '/ca.crt?invite=${invite.code}');
      expect(
        getResponse.statusCode,
        200,
        reason: 'HEAD не имел права потратить код, который GET ещё не видел',
      );
    },
  );

  test('POST — тот же названный отказ, код не тратится', () async {
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final invite = server.invites.mint();
    final postResponse = await request(
      server,
      'POST',
      '/ca.crt?invite=${invite.code}',
    );
    expect(postResponse.statusCode, 405);

    final getResponse = await get(server, '/ca.crt?invite=${invite.code}');
    expect(getResponse.statusCode, 200);
  });

  test('нет центра — это другое состояние, а не отказ по коду', () async {
    // «Корня нет» и «корень не отдам» требуют разных действий от человека,
    // стоящего с планшетом, и один код ответа на оба отправил бы его не туда.
    final server = build(rootPem: null);
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final invite = server.invites.mint();
    final response = await get(server, '/ca.crt?invite=${invite.code}');

    expect(response.statusCode, 503);
  });

  test('страница по-прежнему отдаётся рядом с этой выдачей', () async {
    // Маршрут корня встал перед статическим раздатчиком. Проверка, что он не
    // съел всё остальное.
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    final response = await get(server, '/');
    final body = await response.transform(const SystemEncoding().decoder).join();

    expect(response.statusCode, 200);
    expect(body, contains('till'));
  });
}

SecurityContext _testContext() => SecurityContext(withTrustedRoots: false)
  ..useCertificateChain('test/backend/fixtures/insecure_test_leaf.crt')
  ..usePrivateKey('test/backend/fixtures/insecure_test_leaf.key');

SecurityContext _trustingTestRoot() => SecurityContext(withTrustedRoots: false)
  ..setTrustedCertificates('test/backend/fixtures/insecure_test_ca.crt');

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopTerminals implements TerminalRepository {
  @override
  Future<List<domain.Terminal>> list() async => const [];

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield const <domain.Terminal>[];
    await Completer<void>().future;
  }

  @override
  Stream<domain.Terminal?> watchSelf() async* {
    yield null;
    await Completer<void>().future;
  }

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) => throw UnimplementedError();

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) => throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<domain.Terminal> self() => throw UnimplementedError();

  @override
  Future<void> delete(int terminalId) async {}
}

class _NoopBindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield const <DeviceBinding>[];
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}
