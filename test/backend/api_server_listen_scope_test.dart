import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/transport/host_addresses.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';

import 'support/noop_auth.dart';

/// Чем доказано, что касса без терминалов не открывает порт.
///
/// Не строкой в логе и не значением перечисления, а **настоящими сокетами**:
/// сервер поднимается дважды, и во второй раз с того же сетевого адреса, с
/// которого в первый раз соединиться не удалось, страница отдаётся. Проверка
/// одной только области (`ListenScope.loopback`) была бы проверкой того, что
/// мы передали то, что передали, — она осталась бы зелёной и в тот день, когда
/// `_required` подставил бы под петлю `0.0.0.0`.
///
/// Обе половины нужны вместе. Без «широкой» проверки «узкая» была бы зелёной у
/// сервера, который вообще ни на чём не поднимается.
void main() {
  late AppDatabase db;
  late Directory bundle;

  ApiServer build(ListenScope scope) => ApiServer(
    db: db,
    bootstrap: _NoopBootstrap(),
    setup: _NoopSetup(),
    terminals: _NoopTerminals(),
    deviceBindings: _NoopBindings(),
    auth: NoopAuth(),
    port: 0,
    scope: scope,
    frontendDirectory: bundle.path,
    // Пункт 3 волны правок «касса говорит, что набирать» (2026-08-23):
    // `invites` стал обязательным доводом — второго списка кодов заводить
    // нельзя (см. докстринг у поля `invites` в `ApiServer`). Этому набору
    // сам `PairingInvites` не важен, только область прослушивания.
    invites: PairingInvites(),
    certificateThrottle: CertificateThrottle(),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bundle = Directory.systemTemp.createTempSync('telepos-scope-bundle');
    File(
      '${bundle.path}${Platform.pathSeparator}index.html',
    ).writeAsStringSync('<html><head></head><body>till</body></html>');
    // `main.dart.js` — второй признак бандла (kWebBundleMarkers). Каталог с
    // одним `index.html` касса бандлом не считает: так выглядит `build/web`
    // после неудавшейся сборки, и раньше она в этом случае рапортовала, что
    // страница на месте.
    File(
      '${bundle.path}${Platform.pathSeparator}main.dart.js',
    ).writeAsStringSync('// stub');
  });

  tearDown(() async {
    await db.close();
    bundle.deleteSync(recursive: true);
  });

  test('петля занимает оба петлевых адреса и ни одного чужого', () async {
    final server = build(ListenScope.loopback);
    final outcome = await server.start(context: _testContext());
    addTearDown(server.stop);

    expect(
      outcome,
      isA<String>(),
      reason: outcome is ApiServerUnavailable ? outcome.reason : '',
    );

    // Оба, а не один: слушатель на `::1` не принимает соединение на
    // `127.0.0.1`, и наоборот. На Windows `localhost` — это `::1`, на многих
    // Linux `/etc/hosts` ставит первым `127.0.0.1`; поднять одну петлю значило
    // бы воспроизвести парный дефект 2026-08-06 внутри одной машины.
    expect(server.listeningOn, hasLength(2));
    for (final address in server.listeningOn) {
      expect(
        InternetAddress(address).isLoopback,
        isTrue,
        reason: 'касса на петле слушает $address — это не петля',
      );
    }
  });

  test('касса на петле недостижима со своего же сетевого адреса', () async {
    final lan = await _firstNonLoopbackIPv4();
    if (lan == null) {
      markTestSkipped(_noLanReason);
      return;
    }

    final server = build(ListenScope.loopback);
    final outcome = await server.start(context: _testContext());
    addTearDown(server.stop);
    expect(
      outcome,
      isA<String>(),
      reason: outcome is ApiServerUnavailable ? outcome.reason : '',
    );
    final port = server.boundPort!;

    // Сначала — что сервер вообще отвечает. Без этого «соединение отвергнуто»
    // ниже доказывало бы лишь то, что сервер не поднялся.
    expect(await _statusOver(InternetAddress.loopbackIPv4.address, port), 200);

    expect(
      await _statusOver(lan, port),
      isNull,
      reason:
          'касса, которой оператор не поручал обслуживать терминалы, отвечает '
          'на $lan:$port — то есть открыла порт в сеть магазина сама',
    );
  });

  test('включённая оператором касса отвечает с сетевого адреса', () async {
    final lan = await _firstNonLoopbackIPv4();
    if (lan == null) {
      markTestSkipped(_noLanReason);
      return;
    }

    final server = build(ListenScope.everywhere);
    final outcome = await server.start(context: _testContext());
    addTearDown(server.stop);
    expect(
      outcome,
      isA<String>(),
      reason: outcome is ApiServerUnavailable ? outcome.reason : '',
    );

    expect(
      await _statusOver(lan, server.boundPort!),
      200,
      reason:
          'без этой половины проверка петли была бы зелёной и у сервера, '
          'который не поднимается ни на чём',
    );
  });
}

/// Первый собственный адрес IPv4, не петлевой. `null`, если такого нет.
///
/// Тот же источник, которым касса набивает SAN сертификата и объявление mDNS —
/// `localIPv4Addresses()`. Свой перебор интерфейсов означал бы, что проверка
/// смотрит не на те адреса, которыми пользуется касса.
Future<String?> _firstNonLoopbackIPv4() async {
  final addresses = await localIPv4Addresses();
  return addresses.isEmpty ? null : addresses.first;
}

/// Почему проверка пропущена, когда пропущена, — названной причиной.
///
/// Машина без сетевого интерфейса (контейнер сборки с одной петлёй) не может
/// ответить на вопрос «достижима ли касса из сети», и красный тест там означал
/// бы не дефект, а отсутствие сети. Пропуск с причиной отличается от зелёного
/// прохода: он виден в выводе набора, а `markTestSkipped` — в отличие от
/// `skip:` — позволяет задать этот вопрос на той машине, где сеть есть.
const _noLanReason =
    'у этой машины нет ни одного непетлевого адреса IPv4 — вопрос «достижима '
    'ли касса из сети» здесь не задаётся';

/// Код ответа на `GET /` или `null`, если соединиться не удалось.
///
/// `null`, а не исключение: «соединение отвергнуто» — это и есть ожидаемый
/// результат половины проверок, и превращать его в отказ теста значило бы
/// писать `try/catch` вокруг успеха.
Future<int?> _statusOver(String host, int port) async {
  final client = HttpClient(context: _trustingTestRoot())
    // Лист выписан на `localhost`, а стучимся мы по адресу: расхождение имени
    // здесь ожидаемо и к вопросу «слушает ли сокет» отношения не имеет.
    ..badCertificateCallback = ((cert, host, port) => true)
    ..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.getUrl(Uri.parse('https://$host:$port/'));
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
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
  Stream<List<domain.Terminal>> watchAll() => const Stream.empty();

  @override
  Future<domain.Terminal> self() async =>
      throw const InstallationNotConfiguredException();

  @override
  Stream<domain.Terminal?> watchSelf() => const Stream.empty();

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async => throw UnimplementedError();

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) async => throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {}

  @override
  Future<void> delete(int terminalId) async {}
}

class _NoopBindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) =>
      const Stream.empty();

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}
