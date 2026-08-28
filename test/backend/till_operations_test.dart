import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/api_server.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/noop_auth.dart';

import '../data/transport/fake_quic_server.dart';

/// Ни один тест этого файла не касается [SessionAccess] — все три `TillWire`
/// здесь собраны вокруг операций настройки ([SetupOnlyAccess]), которые сеанс
/// не спрашивают вовсе. Заводить настоящий `SessionRegistry` ради того, чей
/// метод здесь никогда не позовут, — это подделка ровно там, где легче не
/// подделывать: сторож просто не дойдёт до вызова [sessionFor].
class _NeverSession implements SessionLookup {
  const _NeverSession();

  @override
  AuthSession? sessionFor(String token) =>
      throw StateError('этот набор не проверяет SessionAccess');
}

/// Настоящий словарь доступа и настоящая проверка настроенности по той же
/// базе, что видит сама операция — не выдуманное «всегда открыто»: каталог
/// берётся из `TillOps.all`, как на кассе (`ApiServer.access`), а сторож
/// собран той же `wireGuardForTill`, что и в `main.dart`.
WireGuard _guardFor(AppDatabase db) => wireGuardForTill(
  db: db,
  access: {for (final op in TillOps.all) op.name: op.access},
  sessions: const _NeverSession(),
);

void main() {
  late AppDatabase db;
  late CountingBootstrap bootstrap;
  late RecordingTerminals terminals;
  late RecordingBindings bindings;
  late ScriptedFirstLaunch firstLaunch;

  // Подделка, не настоящий `LocalAuthRepository`: этот файл сверяет только
  // полноту карт обработчиков (имя операции ↔ имя обработчика), а не отказы
  // входа — тем, кто хочет поймать настоящий отказ PIN поимённо, служит
  // `till_operations_auth_test.dart`, и там репозиторий настоящий.
  TillOperations build({bool offline = false, NetworkRepository? network}) =>
      TillOperations(
        db: db,
        bootstrap: bootstrap,
        setup: NoopSetup(),
        terminals: terminals,
        deviceBindings: bindings,
        auth: NoopAuth(),
        firstLaunch: offline ? null : firstLaunch,
        network: network,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bootstrap = CountingBootstrap();
    terminals = RecordingTerminals();
    bindings = RecordingBindings();
    firstLaunch = ScriptedFirstLaunch();
  });
  tearDown(() => db.close());

  test('у каждой операции каталога есть обработчик, и наоборот', () {
    // Проверяется не «есть ли обработчики», а то, что множества совпадают
    // **в обе стороны**.
    //
    // Влево: обработчик под именем, которого нет в каталоге, недостижим —
    // терминал такого имени не пошлёт. Имя, набранное строкой, — то самое
    // расхождение, которое до 2026-08-04 обнаруживалось только в браузере
    // кодом 404.
    //
    // Вправо: операция каталога без обработчика отвечает `unknown_op`. Именно
    // так до 2026-08-05 выглядели четыре подписки — объявленные и
    // неотвечаемые, — и заметить это можно было только открыв терминал.
    final operations = build();
    final declared = <String>{
      ...operations.askHandlers.keys,
      ...operations.watchHandlers.keys,
      ...operations.runHandlers.keys,
    };

    expect(declared, TillOps.all.map((op) => op.name).toSet());

    expect(operations.runHandlers.keys.toSet(), {
      TillOps.setupRestore.name,
      TillOps.setupLoadGlobalData.name,
    });
  });

  test('ApiServer.access — настоящий словарь кассы, читается геттером, а не '
      'собран тестом заново', () {
    // Остальные наборы (`till_watch_test.dart`, `wt_till_speaks_first_test.dart`,
    // сам `_guardFor` выше) собирают словарь доступа сами выражением
    // `{for (final op in TillOps.all) op.name: op.access}` — если бы
    // `ApiServer.access` подменили на «всё открыто», ни один из них этого
    // бы не заметил: они читают не геттер, а свою копию того же
    // перечисления. Здесь читается сам геттер — единственный словарь,
    // которым живёт настоящая касса (`api_server.dart`).
    final server = ApiServer(
      db: db,
      bootstrap: bootstrap,
      setup: NoopSetup(),
      terminals: terminals,
      deviceBindings: bindings,
      auth: NoopAuth(),
      // Пункт 3 волны правок «касса говорит, что набирать» (2026-08-23):
      // `invites` стал обязательным доводом.
      invites: PairingInvites(),
    );

    expect(server.access, {for (final op in TillOps.all) op.name: op.access});
  });

  test('подъём кассы считается один раз на оба транспорта', () async {
    // HTTP-маршрут и провод спрашивают одно и то же. Память о подъёме, заведённая
    // в каждом по отдельности, подняла бы кассу дважды: второй прогон
    // `AppBootstrap.start` на открытой смене — не «лишняя работа», а повторная
    // инициализация того, что уже работает.
    final operations = build();

    await operations.askHandlers[TillOps.startupBoot.name]!(const {});
    await operations.askHandlers[TillOps.startupBoot.name]!(const {});
    await operations.boot();

    expect(bootstrap.starts, 1);
  });

  test('офлайновая установка отказывает названной причиной', () async {
    // Транспорта резервных копий нет — это состояние, а не поломка. Через
    // провод оно обязано доехать кадром отказа, а не молчанием и не пустым
    // списком копий, который выглядел бы как «копий не существует».
    final server = FakeQuicServer();
    final operations = build(offline: true);
    final wire = TillWire(server, operations.askHandlers, guard: _guardFor(db))
      ..start();

    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message: '{"op":"${TillOps.setupBackups.name}","body":{}}',
    );
    await Future<void>.delayed(Duration.zero);

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    // `no_backup_transport`, а не общий `handler_failed`: причина — состояние
    // самой кассы (офлайновое развёртывание), а не поломка обработчика или
    // испорченное тело запроса.
    expect((frame as ErrorFrame).code, 'no_backup_transport');
    expect(frame.detail, contains('резервных копий'));

    await wire.stop();
    await server.dispose();
  });

  test('восстановление отдаёт ход выполнения несколькими числами', () async {
    // Ровно то, чего не было: `http_first_launch_repository.dart` писал о себе,
    // что канала для этого нет, и двигал полосу с 0.1 сразу на 1.0.
    firstLaunch.backups = [_backup(42)];
    firstLaunch.restoreProgress = [(0.2, 'Скачиваем'), (0.7, 'Разворачиваем')];
    final server = FakeQuicServer();
    final operations = build();
    final wire = TillWire(
      server,
      const {},
      runHandlers: operations.runHandlers,
      guard: _guardFor(db),
    )..start();

    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message:
          '{"op":"${TillOps.setupRestore.name}",'
          '"body":{"messageId":42}}',
    );
    await Future<void>.delayed(Duration.zero);

    final frames = server.sentFrames.map(WireFrame.decode).toList();
    expect(frames.whereType<ProgressFrame>().map((f) => f.value), [0.2, 0.7]);
    expect(frames.last, isA<DoneFrame>());
    expect(firstLaunch.restoredMessageId, 42);

    await wire.stop();
    await server.dispose();
  });

  test('копии с таким идентификатором нет — отказ, а не тишина', () async {
    // Полоса, которая начала двигаться и остановилась, хуже полосы, которая
    // не начиналась: первая выглядит как идущая работа.
    firstLaunch.backups = [_backup(42)];
    final server = FakeQuicServer();
    final wire = TillWire(
      server,
      const {},
      runHandlers: build().runHandlers,
      guard: _guardFor(db),
    )..start();

    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message:
          '{"op":"${TillOps.setupRestore.name}",'
          '"body":{"messageId":7}}',
    );
    await Future<void>.delayed(Duration.zero);

    final frames = server.sentFrames.map(WireFrame.decode).toList();
    expect(frames.whereType<DoneFrame>(), isEmpty);
    expect(frames.single, isA<ErrorFrame>());
    // Круг правок 1: этот тест проверял только род кадра — зелёный он был бы
    // и на кадре, потерявшем причину. Код и текст называют её поимённо, как
    // у остальных мест этой задачи.
    final refusal = frames.single as ErrorFrame;
    expect(refusal.code, 'backup_not_found');
    expect(refusal.detail, contains('messageId=7'));
    expect(firstLaunch.restoredMessageId, isNull);

    await wire.stop();
    await server.dispose();
  });

  test('переименование без имени не доходит до репозитория', () async {
    // Пустое имя — не «оставить как было», а испорченный запрос: терминал,
    // потерявший имя, выглядит в списке как безымянная строка, и оператор не
    // знает, какое устройство настраивает.
    final operations = build();

    // Задача 2б: `WireRefusal('bad_request', ...)`, а не `ArgumentError` —
    // тот же перевод, что и у `terminalRegister`.
    await expectLater(
      operations.askHandlers[TillOps.terminalRename.name]!({
        'terminalId': 1,
        'name': '   ',
      }),
      throwsA(
        isA<WireRefusal>().having(
          (refusal) => refusal.code,
          'code',
          'bad_request',
        ),
      ),
    );
    expect(terminals.renamed, isEmpty);
  });

  test(
    'привязка устройства едет через тот же разбор, что и читатель',
    () async {
      // Не через свой: два разбора одной формы уже расходились в этом проекте.
      final operations = build();

      await operations.askHandlers[TillOps.deviceBindingSave.name]!({
        'terminalId': 3,
        'binding': {
          'deviceClass': 'receiptPrinter',
          'profileId': 'escpos',
          'parameters': {'address': 'usb'},
          'enabled': true,
        },
      });

      expect(bindings.saved.single.$1, 3);
      expect(bindings.saved.single.$2.profileId, 'escpos');
      expect(bindings.saved.single.$2.parameters, {'address': 'usb'});
    },
  );

  test(
    'нераспознанный идентификатор терминала — отказ, а не умолчание',
    () async {
      // Незаметно подменённый нулём идентификатор записал бы привязку не туда, и
      // увидели бы это по неработающему принтеру у другого кассира.
      final operations = build();

      // Задача 2б, отложенная в задачу 10: `_requireInt` отдаёт `WireRefusal`,
      // а не голый `ArgumentError` — тот же перевод, что и у пустого имени
      // выше. `ArgumentError` доезжал бы до терминала только именем типа
      // (`safeErrorText`), а «ожидалось целое: terminalId» до человека не
      // доходило вовсе.
      await expectLater(
        operations.askHandlers[TillOps.deviceBindingSave.name]!({
          'terminalId': '3',
          'binding': const {
            'deviceClass': 'receiptPrinter',
            'profileId': 'escpos',
          },
        }),
        throwsA(
          isA<WireRefusal>().having(
            (refusal) => refusal.code,
            'code',
            'bad_request',
          ),
        ),
      );
      expect(bindings.saved, isEmpty);
    },
  );

  test(
    'привязка без объекта — отказ WireRefusal, а не ArgumentError',
    () async {
      // Задача 2б, отложенная в задачу 10: до неё `raw is! Map` бросал
      // `ArgumentError.value(raw, 'binding', 'ожидался объект привязки')`, и
      // «ожидался объект привязки» терялось за именем типа исключения.
      final operations = build();

      await expectLater(
        operations.askHandlers[TillOps.deviceBindingSave.name]!({
          'terminalId': 3,
          'binding': 'не объект',
        }),
        throwsA(
          isA<WireRefusal>()
              .having((refusal) => refusal.code, 'code', 'bad_request')
              .having(
                (refusal) => refusal.message,
                'message',
                contains('объект привязки'),
              ),
        ),
      );
      expect(bindings.saved, isEmpty);
    },
  );

  group('сеть кассы — задача «сетевые настройки по проводу», 2026-08-24', () {
    test(
      'без реализации все шесть операций отказывают названной причиной',
      () async {
        // `network: null` — тем же приёмом, что `bin/telepos_backend.dart`
        // передаёт для `deviceDiscovery`/`deviceCheck`: этот процесс не
        // завёл `NetworkRepository`. Отказ обязан быть кадром с именем
        // причины, а не пустотой и не крахом обработчика — И144.
        final operations = build();

        // Тела с уже заполненными обязательными полями — иначе `ssid`/
        // `iface` отказали бы раньше, чем дело дойдёт до `_requireNetwork()`
        // (это отдельно проверено ниже, «отказ до вызова реализации»), и
        // этот тест доказывал бы не то, что называет.
        const bodies = <String, Map<String, Object?>>{
          'network.status': {},
          'network.wifiScan': {},
          'network.wifiConnect': {'ssid': 'Кафе'},
          'network.wifiDisconnect': {},
          'network.ethernetStatus': {},
          'network.ethernetConfigure': {'iface': 'eth0', 'mode': 'dhcp'},
        };

        for (final entry in bodies.entries) {
          await expectLater(
            operations.askHandlers[entry.key]!(entry.value),
            throwsA(
              isA<WireRefusal>()
                  .having((r) => r.code, 'code', 'no_network_module')
                  .having(
                    (r) => r.message,
                    'message',
                    contains('не умеет управлять сетью'),
                  ),
            ),
            reason: entry.key,
          );
        }
      },
    );

    test('состояние сети едет через ту же пару, что её и пишет', () async {
      final network = _FakeNetwork(
        status: const NetworkStatus(
          wifiConnected: true,
          wifiSsid: 'Магазин-1',
          wifiSignal: 80,
          ethernetConnected: true,
          ethernetInterface: 'eth0',
          internet: true,
        ),
      );
      final operations = build(network: network);

      final body = await operations.askHandlers[TillOps.networkStatus.name]!(
        const {},
      );
      final decoded = TillOps.networkStatus.decode(body);

      expect(decoded.wifiSsid, 'Магазин-1');
      expect(decoded.ethernetInterface, 'eth0');
    });

    test('поиск сетей Wi-Fi отдаёт список через ту же пару', () async {
      final network = _FakeNetwork(
        wifiNetworks: const [
          WifiNetwork(ssid: 'Кафе', signal: 60, security: 'WPA2'),
        ],
      );
      final operations = build(network: network);

      final body = await operations.askHandlers[TillOps.networkWifiScan.name]!(
        const {},
      );
      final decoded = TillOps.networkWifiScan.decode(body);

      expect(decoded.single.ssid, 'Кафе');
    });

    test('подключение без ssid — отказ, а не попытка соединиться', () async {
      final network = _FakeNetwork();
      final operations = build(network: network);

      await expectLater(
        operations.askHandlers[TillOps.networkWifiConnect.name]!(const {
          'ssid': '  ',
        }),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect(network.connectCalls, isEmpty);
    });

    test('подключение доходит до реализации с ssid и паролем', () async {
      final network = _FakeNetwork(
        connectResult: (success: true, message: 'готово'),
      );
      final operations = build(network: network);

      final body =
          await operations.askHandlers[TillOps.networkWifiConnect.name]!(
            const {'ssid': 'Кафе', 'password': 'секрет'},
          );

      expect(network.connectCalls.single, ('Кафе', 'секрет'));
      expect(body['success'], isTrue);
      expect(body['message'], 'готово');
    });

    test('отключение зовёт реализацию и возвращает ok', () async {
      final network = _FakeNetwork(disconnectResult: true);
      final operations = build(network: network);

      final body =
          await operations.askHandlers[TillOps.networkWifiDisconnect.name]!(
            const {},
          );

      expect(network.disconnectCalled, isTrue);
      expect(body['ok'], isTrue);
    });

    test('подробности проводного интерфейса едут как отдала реализация', () async {
      final network = _FakeNetwork(
        ethernetStatus: const {
          'interfaces': [
            {'ifname': 'eth0'},
          ],
        },
      );
      final operations = build(network: network);

      final body =
          await operations.askHandlers[TillOps.networkEthernetStatus.name]!(
            const {},
          );

      expect(body['interfaces'], hasLength(1));
    });

    test('настройка Ethernet без iface — отказ до вызова реализации', () async {
      final network = _FakeNetwork();
      final operations = build(network: network);

      await expectLater(
        operations.askHandlers[TillOps.networkEthernetConfigure.name]!(const {
          'iface': '',
          'mode': 'dhcp',
        }),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect(network.dhcpCalls, isEmpty);
      expect(network.staticCalls, isEmpty);
    });

    test('настройка Ethernet DHCP зовёт нужный метод реализации', () async {
      final network = _FakeNetwork(
        dhcpResult: (success: true, mode: 'dhcp'),
      );
      final operations = build(network: network);

      final body =
          await operations.askHandlers[TillOps.networkEthernetConfigure.name]!(
            const {'iface': 'eth0', 'mode': 'dhcp'},
          );

      expect(network.dhcpCalls, ['eth0']);
      expect(network.staticCalls, isEmpty);
      expect(body['success'], isTrue);
      expect(body['mode'], 'dhcp');
    });

    test('статический Ethernet без ipCidr — отказ до вызова реализации', () async {
      final network = _FakeNetwork();
      final operations = build(network: network);

      await expectLater(
        operations.askHandlers[TillOps.networkEthernetConfigure.name]!(const {
          'iface': 'eth0',
          'mode': 'static',
        }),
        throwsA(
          isA<WireRefusal>()
              .having((r) => r.code, 'code', 'bad_request')
              .having((r) => r.message, 'message', contains('ipCidr')),
        ),
      );
      expect(network.staticCalls, isEmpty);
    });

    test('статический Ethernet несёт адрес, шлюз и DNS реализации', () async {
      final network = _FakeNetwork(
        staticResult: (success: true, mode: 'static'),
      );
      final operations = build(network: network);

      final body =
          await operations.askHandlers[TillOps.networkEthernetConfigure.name]!(
            const {
              'iface': 'eth0',
              'mode': 'static',
              'ipCidr': '192.168.1.50/24',
              'gateway': '192.168.1.1',
              'dns': '8.8.8.8',
            },
          );

      expect(network.staticCalls.single, (
        'eth0',
        '192.168.1.50/24',
        '192.168.1.1',
        '8.8.8.8',
      ));
      expect(body['success'], isTrue);
      expect(body['mode'], 'static');
    });
  });
}

FoundBackup _backup(int messageId) => FoundBackup(
  posKey: 'pos',
  posName: 'Касса-1',
  organizationName: 'ООО',
  createdAt: DateTime.utc(2026, 8, 4),
  messageId: messageId,
  checksum: 'sum',
  sizeBytes: 10,
);

class CountingBootstrap implements AppBootstrap {
  int starts = 0;

  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async {
    starts++;
    return AppInitStatus.success;
  }
}

class NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class RecordingTerminals implements TerminalRepository {
  final List<(int, String)> renamed = [];
  final List<int> deleted = [];

  @override
  Future<List<domain.Terminal>> list() async => const [];

  /// Подписка отдаёт то же, что и вопрос, и не завершается: подставной
  /// источник, который сам себя закрывает, доказывал бы про `TillWire`
  /// поведение на кончившемся источнике, а не на живом.
  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield await list();
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
  Future<void> rename(int terminalId, String name) async =>
      renamed.add((terminalId, name));

  @override
  Future<void> delete(int terminalId) async => deleted.add(terminalId);

  @override
  Future<domain.Terminal> self() => throw UnimplementedError();
}

class RecordingBindings implements DeviceBindingRepository {
  final List<(int, DeviceBinding)> saved = [];

  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield await forTerminal(terminalId);
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async =>
      saved.add((terminalId, binding));
}

class ScriptedFirstLaunch implements FirstLaunchRepository {
  List<FoundBackup> backups = const [];
  List<(double, String)> restoreProgress = const [];
  int? restoredMessageId;

  @override
  Future<FirstLaunchResult> determineResult() async =>
      FirstLaunchResult.newPosNoBackups;

  @override
  Future<List<FoundBackup>> findAvailableBackups() async => backups;

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) async {
    for (final (value, message) in restoreProgress) {
      onProgress?.call(value, message);
    }
    return true;
  }

  @override
  Future<bool> restoreFromBackup(
    FoundBackup backup, {
    BootProgress? onProgress,
  }) async {
    restoredMessageId = backup.messageId;
    for (final (value, message) in restoreProgress) {
      onProgress?.call(value, message);
    }
    return true;
  }

  @override
  Future<String> startNewPos() async => 'key';
}

/// Записывающий двойник [NetworkRepository] — задача «сетевые настройки по
/// проводу», спека 2026-08-24. Каждый вызов записывается доводами, которыми
/// его позвали, — тесты выше проверяют не только исход, но и то, что
/// обработчик передал реализации именно то, что пришло в теле кадра, ни
/// больше, ни меньше.
class _FakeNetwork implements NetworkRepository {
  _FakeNetwork({
    NetworkStatus? status,
    List<WifiNetwork>? wifiNetworks,
    ({bool success, String message})? connectResult,
    bool disconnectResult = false,
    Map<String, dynamic>? ethernetStatus,
    ({bool success, String mode})? dhcpResult,
    ({bool success, String mode})? staticResult,
  }) : _status = status,
       _wifiNetworks = wifiNetworks ?? const [],
       _connectResult = connectResult ?? (success: false, message: ''),
       _disconnectResult = disconnectResult,
       _ethernetStatus = ethernetStatus ?? const {},
       _dhcpResult = dhcpResult ?? (success: false, mode: 'dhcp'),
       _staticResult = staticResult ?? (success: false, mode: 'static');

  final NetworkStatus? _status;
  final List<WifiNetwork> _wifiNetworks;
  final ({bool success, String message}) _connectResult;
  final bool _disconnectResult;
  final Map<String, dynamic> _ethernetStatus;
  final ({bool success, String mode}) _dhcpResult;
  final ({bool success, String mode}) _staticResult;

  final List<(String, String?)> connectCalls = [];
  bool disconnectCalled = false;
  final List<String> dhcpCalls = [];
  final List<(String, String, String?, String?)> staticCalls = [];

  @override
  bool get bluetoothAvailable => true;

  @override
  Future<NetworkStatus> status() async =>
      _status ??
      const NetworkStatus(
        wifiConnected: false,
        wifiSsid: null,
        wifiSignal: null,
        ethernetConnected: false,
        ethernetInterface: null,
        internet: false,
      );

  @override
  Future<List<WifiNetwork>> wifiScan() async => _wifiNetworks;

  @override
  Future<({bool success, String message})> wifiConnect(
    String ssid, [
    String? password,
  ]) async {
    connectCalls.add((ssid, password));
    return _connectResult;
  }

  @override
  Future<bool> wifiDisconnect() async {
    disconnectCalled = true;
    return _disconnectResult;
  }

  @override
  Future<Map<String, dynamic>> ethernetStatus() async => _ethernetStatus;

  @override
  Future<({bool success, String mode})> ethernetConfigureDhcp(
    String iface,
  ) async {
    dhcpCalls.add(iface);
    return _dhcpResult;
  }

  @override
  Future<({bool success, String mode})> ethernetConfigureStatic(
    String iface, {
    required String ipCidr,
    String? gateway,
    String? dns,
  }) async {
    staticCalls.add((iface, ipCidr, gateway, dns));
    return _staticResult;
  }

  @override
  Future<List<({String address, String name})>> bluetoothScan() async =>
      const [];

  @override
  Future<({bool success, String message})> bluetoothPair(String address) async =>
      (success: false, message: '');
}
