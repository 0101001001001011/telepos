/// Задача 5 плана «знакомство терминала с кассой» (шаг 2 спеки): вкладка,
/// пережившая F5 или закрытие/повторное открытие, предъявляет секрет обратно
/// вместо того, чтобы заводить новую строку терминала заново.
///
/// # Почему настоящий `LocalTerminalRepository`, а не подделка
///
/// Каждый другой набор в `test/backend/` подделывает `TerminalRepository`
/// (`RecordingTerminals`, `_StubTerminals`, `_IncrementingTerminals`) — и это
/// верно для того, что они проверяют: полноту карт обработчиков, изоляцию
/// листенеров. Здесь предмет теста — сама проверка секрета
/// (`TerminalSecret.matches`, отпечаток, хранение), а подделка её не несёт
/// вовсе. Достижимость — не через тестовый двойник: `FakeQuicServer` +
/// `TillWire` + `TillOperations` — тот же провод, каким браузер говорит с
/// кассой по-настоящему (`login_controller.dart`'s `_resolveTerminalId`
/// зовёт `terminals.register`/`terminals.resume` этими же именами операций
/// через `WtTerminalRepository`), а `LocalTerminalRepository` поверх базы в
/// памяти — тот же класс, что заведён на настоящей кассе.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

import '../data/transport/fake_quic_server.dart';

/// `terminals.register`/`terminals.resume`/`auth.login` — все три
/// `OpenAccess`/по сессии, никто здесь не проверяет `SessionAccess.needs`, у
/// которого есть свой сторож в `wire_guard_test.dart`.
class _NeverSession implements SessionLookup {
  const _NeverSession();

  @override
  AuthSession? sessionFor(String token) =>
      throw StateError('этот набор не проверяет SessionAccess');
}

WireGuard _guardFor(AppDatabase db) => wireGuardForTill(
  db: db,
  access: {for (final op in TillOps.all) op.name: op.access},
  sessions: const _NeverSession(),
);

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}

/// Не проверяет PIN — записывает, каким `terminalId` вход был позван. Тот же
/// приём, что `till_operations_loopback_session_test.dart`'s
/// `_RecordingAuth`: достижимость `auth.login` после `terminals.resume`
/// доказывается тем, что оно видит **тот же** id, а не подделкой исхода.
class _RecordingAuth implements AuthRepository {
  final List<int> loggedTerminalIds = [];

  @override
  Future<AuthOutcome> login(AuthAttempt attempt) async {
    loggedTerminalIds.add(attempt.terminalId);
    return const AuthRejection(AuthRejectionReason.wrongPin);
  }

  @override
  Stream<List<AuthUser>> watchUsers() async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<void> logout(String token) async {}

  @override
  Stream<AuthSession?> watchSession(String token) async* {
    yield null;
    await Completer<void>().future;
  }
}

void main() {
  late AppDatabase db;
  late LocalTerminalRepository terminals;
  late _RecordingAuth auth;
  late TillOperations operations;
  late FakeQuicServer server;
  late TillWire wire;
  // Задача 6 плана «знакомство терминала с кассой»: `terminals.register`
  // требует код привязки — этот набор про секрет и F5 (задача 5), не про сам
  // гейт код/секрет; каждый вызов ниже мятит себе свежий код.
  late PairingInvites invites;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    terminals = LocalTerminalRepository(db);
    auth = _RecordingAuth();
    invites = PairingInvites();
    operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: terminals,
      deviceBindings: _NoopBindings(),
      auth: auth,
      invites: invites,
    );
    server = FakeQuicServer();
    wire = TillWire(
      server,
      operations.askHandlers,
      guard: _guardFor(db),
      onSessionClosed: operations.forgetSession,
    )..start();
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  /// Один обмен, ответивший `OkFrame` — тот же приём, что и в
  /// `till_operations_loopback_session_test.dart`.
  Future<Map<String, Object?>> askOk(
    int sessionId,
    String op,
    Map<String, Object?> body, {
    int streamId = 4,
  }) async {
    final before = server.sentFrames.length;
    server.emitStreamOpened(sessionId: sessionId, streamId: streamId);
    server.emitStreamData(
      sessionId: sessionId,
      streamId: streamId,
      message: jsonEncode({'op': op, 'body': body}),
    );
    server.emitStreamClosed(sessionId: sessionId, streamId: streamId);
    await Future<void>.delayed(Duration.zero);
    final frame = WireFrame.decode(server.sentFrames[before]);
    expect(frame, isA<OkFrame>(), reason: '$op: ${server.sentFrames[before]}');
    return (frame as OkFrame).body;
  }

  /// Тот же обмен, но требующий отказа — возвращает код и текст, а не тело.
  Future<(String code, String detail)> askError(
    int sessionId,
    String op,
    Map<String, Object?> body, {
    int streamId = 4,
  }) async {
    final before = server.sentFrames.length;
    server.emitStreamOpened(sessionId: sessionId, streamId: streamId);
    server.emitStreamData(
      sessionId: sessionId,
      streamId: streamId,
      message: jsonEncode({'op': op, 'body': body}),
    );
    server.emitStreamClosed(sessionId: sessionId, streamId: streamId);
    await Future<void>.delayed(Duration.zero);
    final frame = WireFrame.decode(server.sentFrames[before]);
    expect(frame, isA<ErrorFrame>(), reason: '$op: ${server.sentFrames[before]}');
    final error = frame as ErrorFrame;
    return (error.code, error.detail);
  }

  test(
    'F5 (новая QUIC-сессия, тот же секрет) возвращает тот же terminalId и не '
    'заводит новой строки',
    () async {
      // Первая вкладка — сессия 1 — заводит себя через terminals.register.
      final registered = await askOk(1, TillOps.terminalRegister.name, {
        'name': 'Терминал у окна',
        'code': invites.mint().code,
      });
      final terminalId = (registered['terminal']! as Map)['id'] as int;
      final secret = registered['secret'] as String;
      expect(secret, isNotEmpty);

      // F5: старая QUIC-сессия закрывается (rk_quic шлёт SessionClosed),
      // страница открывается заново на новой сессии — тот же приём, каким
      // `TillWire.onSessionClosed` узнаёт об обрыве в проде.
      server.emitSessionClosed(sessionId: 1);
      await Future<void>.delayed(Duration.zero);

      // Новая сессия (2) предъявляет сохранённый секрет вместо повторного
      // register().
      final resumed = await askOk(2, TillOps.terminalResume.name, {
        'terminalId': terminalId,
        'secret': secret,
      });
      final resumedId = (resumed['terminal']! as Map)['id'] as int;

      expect(
        resumedId,
        terminalId,
        reason: 'возврат по секрету обязан отдать ТОТ ЖЕ terminalId',
      );

      final rows = await db.select(db.terminals).get();
      expect(
        rows,
        hasLength(1),
        reason:
            'ГЛАВНАЯ ПРОВЕРКА ЗАДАЧИ 5: F5 не имеет права завести вторую '
            'строку терминала — до этой задачи заводил (докстринг брифа: '
            '«сегодня заводит»)',
      );

      // Достижимость: сессия 2, только что предъявившая секрет, доходит до
      // auth.login тем же terminalId — тот же путь, каким браузер продолжил
      // бы вход после resume(), а не только что resume() сама по себе
      // отвечает разумно.
      await askOk(2, TillOps.authLogin.name, {'pin': '0000', 'userId': null});
      expect(auth.loggedTerminalIds, [terminalId]);
    },
  );

  test(
    'несколько F5 подряд — по-прежнему одна строка, id не меняется',
    () async {
      final registered = await askOk(1, TillOps.terminalRegister.name, {
        'name': 'Терминал у кассы',
        'code': invites.mint().code,
      });
      final terminalId = (registered['terminal']! as Map)['id'] as int;
      final secret = registered['secret'] as String;

      var lastSeenId = terminalId;
      for (var sessionId = 2; sessionId <= 5; sessionId++) {
        server.emitSessionClosed(sessionId: sessionId - 1);
        await Future<void>.delayed(Duration.zero);
        final resumed = await askOk(sessionId, TillOps.terminalResume.name, {
          'terminalId': terminalId,
          'secret': secret,
        });
        lastSeenId = (resumed['terminal']! as Map)['id'] as int;
        expect(lastSeenId, terminalId);
      }

      expect(
        await db.select(db.terminals).get(),
        hasLength(1),
        reason: 'четыре F5 подряд — всё равно одна строка',
      );
    },
  );

  test(
    'чужой секрет получает отказ, а не чужой terminalId — и не привязывает '
    'сессию',
    () async {
      final owner = await askOk(1, TillOps.terminalRegister.name, {
        'name': 'Терминал владельца',
        'code': invites.mint().code,
      });
      final ownerTerminalId = (owner['terminal']! as Map)['id'] as int;

      final impostor = await askOk(2, TillOps.terminalRegister.name, {
        'name': 'Терминал самозванца',
        'code': invites.mint().code,
      });
      final impostorSecret = impostor['secret'] as String;

      // Сессия 3 пробует терминал владельца, но с чужим секретом.
      final (code, detail) = await askError(3, TillOps.terminalResume.name, {
        'terminalId': ownerTerminalId,
        'secret': impostorSecret,
      });
      expect(code, 'terminal_secret_invalid');
      expect(
        detail,
        isNot(contains(impostorSecret)),
        reason:
            'ГЛАВНАЯ ПРОВЕРКА: текст отказа — WireRefusal.message, единственный '
            'вид исключения, доезжающий до терминала целиком (докстринг '
            'WireRefusal) — не имеет права нести ни свой, ни чужой секрет '
            'значением',
      );

      // Сессия 3 не привязана ни к какому терминалу — отказ resume() не
      // имеет права оставить побочный эффект в _sessionTerminals.
      final (loginCode, _) = await askError(3, TillOps.authLogin.name, {
        'pin': '0000',
        'userId': null,
      });
      expect(
        loginCode,
        'unknown_terminal',
        reason:
            'сессия, которой отказали в resume(), не должна иметь права '
            'входить ни от чьего имени',
      );
      expect(
        auth.loggedTerminalIds,
        isEmpty,
        reason: 'до LocalAuthRepository/подделки дело дойти не должно было',
      );

      expect(
        await db.select(db.terminals).get(),
        hasLength(2),
        reason: 'отказ resume() не создаёт и не портит ни одной строки',
      );
    },
  );

  test('несуществующий terminalId в resume — отказ тем же кодом', () async {
    final (code, _) = await askError(1, TillOps.terminalResume.name, {
      'terminalId': 999999,
      'secret': 'что угодно',
    });
    expect(code, 'terminal_secret_invalid');
  });
}
