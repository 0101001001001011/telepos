/// Обработчики списка сеансов и их отзыва — задача 19 закрытия долга
/// безопасности.
///
/// `SessionRegistry.revokeAll()` существовал с задачи 9 и не звался ни одной
/// строкой рабочего кода; эти два обработчика — вместе с экраном настроек и
/// местами смены PIN/деактивации — и есть тот самый вызывающий код.
///
/// Тот же приём, что у `till_operations_auth_test.dart`: отказ и успех
/// называются поимённо, а не подделкой SessionAdmin — здесь используется
/// настоящий `SessionRegistry`, тот же класс, что несёт эту работу на кассе.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

void main() {
  late AppDatabase db;
  late SessionRegistry registry;

  TillOperations build({bool withSessionAdmin = true}) => TillOperations(
    db: db,
    bootstrap: _StubBootstrap(),
    setup: _StubSetup(),
    terminals: _StubTerminals(),
    deviceBindings: _StubBindings(),
    auth: LocalAuthRepository(db: db, sessions: registry, throttle: LoginThrottle()),
    sessionAdmin: withSessionAdmin ? registry : null,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    registry = SessionRegistry();
  });
  tearDown(() => db.close());

  test('у обеих операций есть обработчик', () {
    final operations = build();

    expect(operations.watchHandlers, contains(TillOps.authSessions.name));
    expect(operations.askHandlers, contains(TillOps.authSessionRevoke.name));
  });

  test('список сеансов отдаёт то, что реально выписал SessionRegistry', () async {
    final session = registry.mint(
      userId: 7,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {'nav.sale'},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 5,
    );

    final operations = build();
    final body = await operations.watchHandlers[TillOps.authSessions.name]!(
      const {},
    ).first;

    final sessions = body['sessions']! as List;
    expect(sessions, hasLength(1));
    final entry = (sessions.single as Map).cast<String, Object?>();
    expect(entry['terminalId'], 5);
    expect(entry['userId'], 7);
    expect(entry['name'], 'Айгуль');
    expect(
      entry.containsKey('token'),
      isFalse,
      reason:
          'токен не покидает эту функцию — экран списка сеансов не то же '
          'самое, что "мой сеанс" (auth.session)',
    );
    // Сам токен по-прежнему живой — список его не тронул.
    expect(registry.lookup(session.token), isNotNull);
  });

  test('отзыв гасит сеанс терминала', () async {
    final session = registry.mint(
      userId: 7,
      name: 'A',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 5,
    );

    final operations = build();
    final body = await operations.askHandlers[TillOps.authSessionRevoke.name]!(
      const {'terminalId': 5},
    );

    expect(body['ok'], isTrue);
    expect(registry.lookup(session.token), isNull);
  });

  test('отзыв терминала без сеанса отвечает ok: false, а не ошибкой', () async {
    final operations = build();
    final body = await operations.askHandlers[TillOps.authSessionRevoke.name]!(
      const {'terminalId': 999},
    );

    expect(body['ok'], isFalse);
  });

  test(
    'без собранного SessionAdmin обе операции отказывают названной '
    'причиной, а не молчат и не роняют обмен непонятно как',
    () async {
      final operations = build(withSessionAdmin: false);

      // Синхронный отказ, не отложенный до первого значения потока: тот же
      // приём, что у `deviceBindings` (`till_operations.dart`) — плохой
      // довод обязан стать кадром отказа сразу, а не подпиской, которая
      // заведётся и упадёт на первом же обновлении.
      expect(
        () => operations.watchHandlers[TillOps.authSessions.name]!(const {}),
        throwsA(
          isA<WireRefusal>().having(
            (refusal) => refusal.code,
            'code',
            'no_session_registry',
          ),
        ),
      );

      await expectLater(
        operations.askHandlers[TillOps.authSessionRevoke.name]!(
          const {'terminalId': 5},
        ),
        throwsA(
          isA<WireRefusal>().having(
            (refusal) => refusal.code,
            'code',
            'no_session_registry',
          ),
        ),
      );
    },
  );
}

class _StubBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _StubSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _StubTerminals implements TerminalRepository {
  @override
  Future<List<domain.Terminal>> list() async => const [
    domain.Terminal(id: 1, name: 'Касса-1', pointMode: domain.PointMode.cashier),
  ];

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async => (
    terminal: const domain.Terminal(
      id: 1,
      name: 'Касса-1',
      pointMode: domain.PointMode.cashier,
    ),
    secret: 'fake-secret-not-a-real-terminal-secret',
  );

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) async => throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) async {}

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

class _StubBindings implements DeviceBindingRepository {
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
