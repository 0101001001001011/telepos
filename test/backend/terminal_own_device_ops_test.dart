/// Регрессия фазы 3/4 закрытия долга: браузерные настройки оборудования
/// всегда `forbidden`.
///
/// Задача 10 завела `SessionAccess.ownTerminal: TerminalOwnership.same` для
/// `terminals.rename`, `terminals.deviceBindings`, `terminals.deviceBindingSave`
/// и `terminals.deviceCheck` — сторож сверяет `terminalId` из тела с
/// `session.terminalId`. Но настоящий клиентский путь этих четырёх операций
/// (`hardware_settings_screen.dart` и соседи) берёт `terminalId` не из
/// сеанса, а через `TerminalRepository.self()` — в браузере это
/// `terminals.selfEnsure`, который всегда отдаёт строку **самой кассы**
/// (`isSelf`), а не терминал вызывающей вкладки. Эти два числа не совпадают
/// никогда, и до правки все четыре операции отвечали `forbidden` на каждый
/// браузерный запрос.
///
/// Это и есть тест, которого не было: настоящий клиентский путь целиком —
/// `FakeQuicServer` + `TillWire` + `wireGuardForTill`, тот же приём, что
/// `terminal_delete_test.dart` уже применяет к `different`. Сеанс вкладки
/// сидит на терминале, заведённом через `register()` (как в браузере), а
/// операции запрашиваются с `terminalId` терминала **самой кассы**
/// (`isSelf`, как отдаёт настоящий `self()`), а не терминала сеанса.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

import '../data/transport/fake_quic_server.dart';
import 'support/noop_auth.dart';

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _ScriptedCheck implements DeviceCheck {
  @override
  Future<DeviceCheckOutcome> check({
    required int terminalId,
    required DeviceClass deviceClass,
  }) async => DeviceCheckOutcome.wire(
    reason: DeviceCheckReason.notConfigured,
    message: 'Ящик не привязан',
  );
}

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late SessionRegistry sessions;
  late TillWire wire;
  late int selfTerminalId;
  late int tabTerminalId;
  late String token;

  TillOperations build() => TillOperations(
    db: db,
    bootstrap: _NoopBootstrap(),
    setup: _NoopSetup(),
    terminals: LocalTerminalRepository(db),
    deviceBindings: LocalDeviceBindingRepository(
      db,
      BuiltinDeviceProfileCatalog(),
    ),
    auth: NoopAuth(),
    deviceCheck: _ScriptedCheck(),
  );

  WireGuard guard() => wireGuardForTill(
    db: db,
    access: {for (final op in TillOps.all) op.name: op.access},
    sessions: sessions,
  );

  Future<WireFrame> askAndSettle(String op, Map<String, Object?> body) async {
    final operations = build();
    wire = TillWire(server, operations.askHandlers, guard: guard())..start();
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message:
          '{"op":"$op","body":${_json(body)},"token":"$token"}',
    );
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);
    await wire.stop();
    return WireFrame.decode(server.sentFrames.single);
  }

  Future<WireFrame> subscribeAndSettle(
    String op,
    Map<String, Object?> body,
  ) async {
    final operations = build();
    wire = TillWire(
      server,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      guard: guard(),
    )..start();
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message:
          '{"op":"$op","body":${_json(body)},"token":"$token"}',
    );
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);
    return WireFrame.decode(server.sentFrames.single);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
    sessions = SessionRegistry();

    // Терминал самой кассы — то, что `self()`/`terminals.selfEnsure` отдаёт
    // в браузере.
    final self = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    selfTerminalId = self.id;

    // Терминал вкладки — то, что `register()` заводит в браузере, и то, на
    // чём сидит сеанс, mint-нутый ниже (ровно как в настоящем входе).
    final tab = (await LocalTerminalRepository(
      db,
    ).register(name: 'Терминал вкладки')).terminal;
    tabTerminalId = tab.id;

    token = sessions
        .mint(
          userId: 1,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {PermissionKeys.settingsHardware},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: tabTerminalId,
        )
        .token;
  });

  tearDown(() async {
    await server.dispose();
    await db.close();
  });

  test(
    'terminals.rename с terminalId самой кассы — проход настоящим клиентским '
    'путём',
    () async {
      final frame = await askAndSettle(TillOps.terminalRename.name, {
        'terminalId': selfTerminalId,
        'name': 'Касса у входа',
      });

      expect(
        frame,
        isA<OkFrame>(),
        reason:
            'hardware_settings_screen.dart шлёт terminalId из self(), а не из '
            'сеанса — сторож обязан пустить это, а не ответить forbidden',
      );
    },
  );

  test(
    'terminals.deviceBindingSave с terminalId самой кассы — проход',
    () async {
      final frame = await askAndSettle(TillOps.deviceBindingSave.name, {
        'terminalId': selfTerminalId,
        'binding': {
          'deviceClass': DeviceClass.receiptPrinter.name,
          'profileId': 'printer.escpos.usb',
          'parameters': <String, String>{},
          'options': <String, String>{},
        },
      });

      expect(frame, isA<OkFrame>());
    },
  );

  test('terminals.deviceCheck с terminalId самой кассы — проход', () async {
    final frame = await askAndSettle(TillOps.deviceCheck.name, {
      'terminalId': selfTerminalId,
      'deviceClass': DeviceClass.cashDrawer.name,
    });

    expect(frame, isA<OkFrame>());
  });

  test('terminals.deviceBindings с terminalId самой кассы — проход', () async {
    final frame = await subscribeAndSettle(TillOps.deviceBindings.name, {
      'terminalId': selfTerminalId,
    });

    expect(
      frame,
      isA<UpdateFrame>(),
      reason: 'подписка обязана дойти до первого значения, а не до отказа',
    );
  });

  test(
    'terminalId терминала вкладки (не самой кассы, не своего) — по-прежнему '
    'forbidden',
    () async {
      // Третий терминал — ни сеанс, ни касса им не являются.
      final stranger = (await LocalTerminalRepository(
        db,
      ).register(name: 'Соседняя вкладка')).terminal;

      final frame = await askAndSettle(TillOps.terminalRename.name, {
        'terminalId': stranger.id,
        'name': 'X',
      });

      expect((frame as ErrorFrame).code, 'forbidden');
    },
  );
}

String _json(Map<String, Object?> body) {
  final buffer = StringBuffer('{');
  var first = true;
  body.forEach((key, value) {
    if (!first) buffer.write(',');
    first = false;
    buffer.write('"$key":');
    buffer.write(_jsonValue(value));
  });
  buffer.write('}');
  return buffer.toString();
}

String _jsonValue(Object? value) {
  if (value == null) return 'null';
  if (value is num) return value.toString();
  if (value is String) return '"${value.replaceAll('"', '\\"')}"';
  if (value is Map) return _json(value.cast<String, Object?>());
  throw ArgumentError('тип не поддержан в этом лёгком JSON: $value');
}
