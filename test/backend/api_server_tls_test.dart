import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';

import 'support/noop_auth.dart';

/// Почему этот файл вообще есть.
///
/// `WebTransport` в браузере помечен `[SecureContext]`. На `http://127.0.0.1`
/// он существует по исключению для петли; на `http://192.168.1.50:8787`
/// конструктора **нет вовсе** — не «не соединяется», а отсутствует. Значит
/// терминал на отдельном устройстве требует, чтобы саму страницу отдавали по
/// HTTPS, и `serverCertificateHashes` этого не решает: отпечаток спасает
/// рукопожатие QUIC, а страницу браузер грузит раньше и другим протоколом.
void main() {
  late AppDatabase db;
  late Directory bundle;

  ApiServer build({
    int port = 0,
    ListenScope scope = ListenScope.loopback,
    String? publicHost,
  }) => ApiServer(
    db: db,
    bootstrap: _NoopBootstrap(),
    setup: _NoopSetup(),
    terminals: _NoopTerminals(),
    deviceBindings: _NoopBindings(),
    auth: NoopAuth(),
    port: port,
    scope: scope,
    publicHost: publicHost,
    frontendDirectory: bundle.path,
    // Пункт 3 волны правок «касса говорит, что набирать» (2026-08-23):
    // `invites` стал обязательным доводом — см. докстринг у поля `invites`
    // в `ApiServer`. Этому набору сам список не важен, только TLS.
    invites: PairingInvites(),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bundle = Directory.systemTemp.createTempSync('telepos-bundle');
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

  test('без сертификата сервер не поднимается молча', () async {
    // Молчаливый откат на HTTP выглядел бы как работающая касса и не
    // работающий провод: страница открывается, экран рисуется, а
    // `new WebTransport(...)` бросает `ReferenceError`, потому что
    // конструктора на незащищённой странице не существует. Искать причину
    // будут в QUIC — то есть не там.
    final server = build();
    final outcome = await server.start(context: null);

    expect(outcome, isA<ApiServerUnavailable>());
    expect((outcome as ApiServerUnavailable).reason, isNotEmpty);
    expect(server.url, isNull, reason: 'ничего не слушает — нечего и открывать');
  });

  test('с сертификатом страница отдаётся по HTTPS', () async {
    final server = build();
    final outcome = await server.start(context: _testContext());
    addTearDown(server.stop);

    expect(
      outcome,
      isA<String>(),
      reason: outcome is ApiServerUnavailable ? outcome.reason : '',
    );
    expect(outcome as String, startsWith('https://'));

    final client = HttpClient(context: _trustingTestRoot());
    final request = await client.getUrl(Uri.parse('${server.url!}/'));
    final response = await request.close();
    final body = await response.transform(const SystemEncoding().decoder).join();
    client.close();

    expect(response.statusCode, 200);
    expect(body, contains('TELEPOS_TOKEN'));
    expect(body, contains('till'), reason: 'это тот самый бандл, а не заглушка');
  });

  test('чужой корень отвергается — TLS настоящий, а не декорация', () async {
    // Проверка на то, что рукопожатие действительно состоялось по правилам:
    // клиент, не знающий корня, обязан отказаться. Без неё зелёный тест выше
    // доказывал бы только то, что кто-то что-то отдал.
    final server = build();
    await server.start(context: _testContext());
    addTearDown(server.stop);

    final stranger = HttpClient(context: SecurityContext(withTrustedRoots: true));
    await expectLater(
      stranger.getUrl(Uri.parse('${server.url!}/')).then((r) => r.close()),
      throwsA(isA<HandshakeException>()),
    );
    stranger.close(force: true);
  });

  test('порт занят — отказ значением, а не исключением', () async {
    // Вторая копия кассы на той же машине — обычное дело, и она не должна
    // ронять первую падением на `bind`.
    final first = build();
    expect(await first.start(context: _testContext()), isA<String>());
    addTearDown(first.stop);

    final second = build(port: first.boundPort!);
    final outcome = await second.start(context: _testContext());

    expect(outcome, isA<ApiServerUnavailable>());
    expect((outcome as ApiServerUnavailable).reason, isNotEmpty);
    expect(second.url, isNull);
  });

  test('адрес в документе — тот, по которому его открыли, а не петля', () async {
    // Страница, отданная планшету, обязана называть кассу так, как планшет её
    // достанет. Петля в этом поле означала бы, что терминал ищет кассу в
    // самом себе.
    final server = build(publicHost: 'till-3.local');
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    expect(server.url, startsWith('https://till-3.local:'));
  });

  // --- двойной стек --------------------------------------------------------
  //
  // Почему это отдельная группа и почему проверка именно такая.
  //
  // Дефект 2026-08-06: слушатель поднимался на `0.0.0.0`, а Windows разрешает
  // `localhost` и имя машины СНАЧАЛА в IPv6. Браузер уходил на `::1`/`fe80::…`
  // и получал `ERR_FAILED`, страница не открывалась вовсе. Обнаружить это
  // `curl`-ом нельзя: он отвечал 200 по всем адресам, потому что выбирает
  // семейство иначе. Поэтому здесь соединение открывается по КАЖДОМУ адресу
  // поимённо, а не по имени, — иначе тест проверял бы решение резолвера, а не
  // слушателя.

  test('петля слушает оба семейства — и ::1, и 127.0.0.1', () async {
    final server = build();
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    // Два сокета, а не один: `::1` не принимает соединение на `127.0.0.1` —
    // это отдельный адрес, а не подсеть, покрывающая IPv4.
    expect(
      server.listeningOn,
      containsAll(<String>['::1', '127.0.0.1']),
      reason: 'односемейная петля — тот же дефект, только внутри машины',
    );

    for (final address in ['::1', '127.0.0.1']) {
      expect(
        await _reaches(address, server.boundPort!),
        isTrue,
        reason:
            'страница недостижима по $address — браузер, чей резолвер выбрал '
            'это семейство, увидит ERR_FAILED и ничего больше',
      );
    }
  });

  test('все адреса — это оба семейства, а не 0.0.0.0', () async {
    // Краснеет при возврате к `0.0.0.0`: тот слушатель не отвечает по `::1`.
    final server = build(scope: ListenScope.everywhere);
    expect(await server.start(context: _testContext()), isA<String>());
    addTearDown(server.stop);

    for (final address in ['::1', '127.0.0.1']) {
      expect(
        await _reaches(address, server.boundPort!),
        isTrue,
        reason: 'ListenScope.everywhere не отвечает по $address',
      );
    }
  });

  test('петля остаётся узкой — порт наружу не открыт', () async {
    // Вторая половина того же решения, и она про безопасность: касса без
    // терминалов не обязана быть достижима с чужой машины. Молчаливое
    // расширение петли до всех адресов хуже, чем неудобство, и заметить его
    // без этой проверки было бы нечем — по петле такой сервер отвечает
    // одинаково в обоих случаях.
    final outside = await _firstExternalIPv4();
    expect(
      outside,
      isNotNull,
      reason:
          'у машины нет ни одного адреса, кроме петли — доказать узость '
          'нечем, и молча пройти эта проверка не должна',
    );

    final narrow = build();
    expect(await narrow.start(context: _testContext()), isA<String>());
    addTearDown(narrow.stop);

    expect(
      await _reaches(outside!, narrow.boundPort!),
      isFalse,
      reason:
          'петля отвечает по $outside — порт открыт в сеть, чего касса без '
          'терминалов не просила',
    );

    // И контроль на то, что проверка вообще способна что-то увидеть: на
    // `everywhere` тот же адрес обязан отвечать. Без этой половины тест был бы
    // зелёным и на сломанном `_reaches`, который всегда возвращает false.
    final wide = build(scope: ListenScope.everywhere);
    expect(await wide.start(context: _testContext()), isA<String>());
    addTearDown(wide.stop);

    expect(
      await _reaches(outside, wide.boundPort!),
      isTrue,
      reason: 'ListenScope.everywhere не отвечает по $outside',
    );
  });
}

/// Открывается ли TLS-соединение по этому адресу и порту.
///
/// Именно соединение, а не запрос по имени: смысл проверки в том, на каком
/// адресе слушатель есть, а `Uri`, отданный резолверу, выбрал бы адрес сам и
/// проверял бы уже его решение.
///
/// Корень — тот же тестовый; хост для проверки имени берётся `localhost`,
/// потому что в SAN тестового листа есть именно он, а адрес здесь задаёт
/// маршрут, а не идентичность.
Future<bool> _reaches(String address, int port) async {
  Socket? plain;
  try {
    plain = await Socket.connect(
      address,
      port,
      timeout: const Duration(seconds: 3),
    );
    // Рукопожатие, а не просто открытый TCP: слушатель без TLS-контекста
    // принял бы соединение и разорвал его молча, и проверка «дошли» была бы
    // зелёной там, где браузер не откроет страницу.
    final secure = await SecureSocket.secure(
      plain,
      // Имя для проверки листа берётся отдельно от адреса маршрута: в SAN
      // тестового листа есть `localhost`, но нет `::1`, а смысл проверки — на
      // каком адресе есть слушатель, а не что записано в сертификате.
      host: 'localhost',
      context: _trustingTestRoot(),
    );
    secure.destroy();
    return true;
  } on Object {
    plain?.destroy();
    return false;
  }
}

/// Первый адрес IPv4 машины, который не петля, или `null`, если такого нет.
Future<String?> _firstExternalIPv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback) return address.address;
    }
  }
  return null;
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
