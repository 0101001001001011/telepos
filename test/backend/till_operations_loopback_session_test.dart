/// Правка 3 волны закрытия долга безопасности (2026-08-22): `loopback`
/// поднимает два листенера (петля IPv4 и петля IPv6, `webtransport_endpoint
/// .dart`), и `rk_quic` заводит `sessionId` независимым счётчиком **на
/// каждый** (`packages/rk_quic/rust/src/transport.rs`, `next_session` —
/// счётчик внутри функции подъёма листенера, не статика процесса). Значит
/// `sessionId=1` существует независимо на обоих, а `TillOperations` —
/// одна на всё развёртывание, и до этой правки её `_sessionTerminals` не
/// отличала вкладку одного листенера от вкладки другого: они делили один
/// и тот же ключ карты.
///
/// Здесь это воспроизведено буквально: два `FakeQuicServer`, два `TillWire`
/// (`listenerId: 0` и `listenerId: 1` — то, чем `main.dart` их и заводит по
/// проводу), одна `TillOperations`. На каждом листенере — своя QUIC-сессия
/// с одним и тем же сырым `sessionId = 1`, и каждая регистрирует свой
/// терминал. Дыра — если `auth.login` листенера A увидит терминал,
/// заведённый на листенере B, или наоборот.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

import '../data/transport/fake_quic_server.dart';

/// Ни одна операция здесь не спрашивает сеанс: `terminals.register` и
/// `auth.login` — обе `OpenAccess`. Тот же приём, что `till_operations_test
/// .dart`'s `_NeverSession` — не подделывать метод, который сторож просто
/// не позовёт.
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

/// Заводит настоящий, увеличивающийся `id` на каждую регистрацию — в
/// отличие от `_StubTerminals` в `till_operations_auth_test.dart`, которая
/// нарочно отдаёт один и тот же терминал всегда: здесь дыра именно в том,
/// различает ли касса **разные** терминалы разных листенеров, и одинаковый
/// id этого не показал бы.
class _IncrementingTerminals implements TerminalRepository {
  final List<domain.Terminal> _registered = [];
  int _nextId = 101;

  @override
  Future<List<domain.Terminal>> list() async => List.unmodifiable(_registered);

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async {
    final terminal = domain.Terminal(
      id: _nextId++,
      name: name,
      pointMode: domain.PointMode.cashier,
    );
    _registered.add(terminal);
    return (terminal: terminal, secret: 'fake-secret-not-a-real-terminal-secret');
  }

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) async => throw UnimplementedError();

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield await list();
    await Completer<void>().future;
  }

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {}

  @override
  Future<void> delete(int terminalId) async {}

  @override
  Future<domain.Terminal> self() => throw UnimplementedError();

  @override
  Stream<domain.Terminal?> watchSelf() async* {
    yield null;
    await Completer<void>().future;
  }
}

/// Не проверяет PIN — записывает, каким `terminalId` его позвали. Дыра
/// правки 3 видна не в исходе входа, а в том, какой терминал вообще дошёл
/// до этой точки.
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
  late _IncrementingTerminals terminals;
  late _RecordingAuth auth;
  late TillOperations operations;
  // Задача 6 плана «знакомство терминала с кассой»: `terminals.register`
  // требует код привязки — этот набор про коллизии `sessionId` на двух
  // листенерах петли, не про сам гейт код/секрет.
  late PairingInvites invites;
  late FakeQuicServer serverA;
  late FakeQuicServer serverB;
  late TillWire wireA;
  late TillWire wireB;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    terminals = _IncrementingTerminals();
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
    serverA = FakeQuicServer();
    serverB = FakeQuicServer();
    // Ровно то, чем main.dart заводит `TillWire` на каждый листенер
    // `webTransport.servers` — здесь двух в цикле не было бы (это два
    // подставных сервера теста, не листенеры одного `WebTransportEndpoint`),
    // но `listenerId` — тот же индекс, каким его завёл бы такой цикл.
    wireA = TillWire(
      serverA,
      operations.askHandlers,
      guard: _guardFor(db),
      onSessionClosed: operations.forgetSession,
      listenerId: 0,
    )..start();
    wireB = TillWire(
      serverB,
      operations.askHandlers,
      guard: _guardFor(db),
      onSessionClosed: operations.forgetSession,
      listenerId: 1,
    )..start();
  });

  tearDown(() async {
    await wireA.stop();
    await wireB.stop();
    await serverA.dispose();
    await serverB.dispose();
    await db.close();
  });

  /// Один обмен: открыть поток, прислать вопрос, закрыть половину отправки
  /// — тот же приём, что и в `till_wire_test.dart`. `sessionId` — сырой,
  /// одинаковый на обоих серверах (1) намеренно: это и есть условие, при
  /// котором коллизия раньше случалась.
  Future<Map<String, Object?>> ask(
    FakeQuicServer server,
    String op,
    Map<String, Object?> body, {
    int streamId = 4,
  }) async {
    final before = server.sentFrames.length;
    server.emitStreamOpened(sessionId: 1, streamId: streamId);
    server.emitStreamData(
      sessionId: 1,
      streamId: streamId,
      message: jsonEncode({'op': op, 'body': body}),
    );
    server.emitStreamClosed(sessionId: 1, streamId: streamId);
    await Future<void>.delayed(Duration.zero);
    final frame = WireFrame.decode(server.sentFrames[before]);
    expect(frame, isA<OkFrame>(), reason: '$op: ${server.sentFrames[before]}');
    return (frame as OkFrame).body;
  }

  test(
    'две сессии с одинаковым sessionId от разных слушателей не видят '
    'терминалов друг друга',
    () async {
      // Обе сессии несут один и тот же сырой sessionId = 1 — ровно то, что
      // rk_quic реально отдаёт на двух независимых листенерах loopback.
      final registeredA = await ask(serverA, TillOps.terminalRegister.name, {
        'name': 'Слушатель A',
        'code': invites.mint().code,
      });
      final registeredB = await ask(serverB, TillOps.terminalRegister.name, {
        'name': 'Слушатель B',
        'code': invites.mint().code,
      });

      final terminalIdA = (registeredA['terminal']! as Map)['id'] as int;
      final terminalIdB = (registeredB['terminal']! as Map)['id'] as int;

      // Термины разные — сама регистрация работает как ожидается, дыра не
      // здесь.
      expect(terminalIdA, isNot(terminalIdB));

      await ask(serverA, TillOps.authLogin.name, {
        'pin': '0000',
        'userId': null,
      });
      await ask(serverB, TillOps.authLogin.name, {
        'pin': '0000',
        'userId': null,
      });

      expect(
        auth.loggedTerminalIds,
        [terminalIdA, terminalIdB],
        reason:
            'вход листенера A обязан назвать терминал A, вход листенера B — '
            'терминал B, несмотря на одинаковый сырой sessionId на обоих; до '
            'правки 3 они делили одну запись в _sessionTerminals, и второй '
            'вход перезаписывал первый',
      );
    },
  );

  test(
    'listenerId=0 (единственный слушатель, "everywhere") не меняет поведение',
    () async {
      // Прод `everywhere` — один сокет, один TillWire, listenerId остаётся
      // 0 по умолчанию: составной ключ равен сырому sessionId, и всё
      // работает так же, как до правки 3.
      final registered = await ask(serverA, TillOps.terminalRegister.name, {
        'name': 'Единственный слушатель',
        'code': invites.mint().code,
      });
      final terminalId = (registered['terminal']! as Map)['id'] as int;

      await ask(serverA, TillOps.authLogin.name, {
        'pin': '0000',
        'userId': null,
      });

      expect(auth.loggedTerminalIds, [terminalId]);
    },
  );
}
