/// Задача 6 плана «знакомство терминала с кассой» (шаг 3 спеки):
/// `terminals.register` перестаёт быть открытой операцией. Принимается один
/// довод — код привязки (`PairingInvites`), потраченный ровно один раз; без
/// него или на потраченном — отказ названной причиной, а не тихий проход и
/// не падение обмена.
///
/// # Где проверяется — и почему не в стороже
///
/// `EnrolmentAccess` (`lib/domain/wire/wire_access.dart`) объявляет операцию
/// «структурно открытой» сторожу (`WireGuard` пропускает её тем же приёмом,
/// что и `OpenAccess`) — довод сверяет обработчик
/// (`TillOperations.askHandlers[TillOps.terminalRegister.name]`,
/// `lib/backend/till_operations.dart`) через `PairingInvites`, который
/// сторожу не дан и не должен быть дан: `PairingInvites` живёт в
/// `lib/backend/`, `WireGuard` — в `lib/domain/`, и протаскивать эту
/// зависимость в домен ради единственной операции значило бы нарушить
/// границу, которую сторожит `test/architecture/layering_test.dart`. Прошлая
/// работа (задача 10 закрытия долга безопасности) увела похожую проверку
/// («владение терминалом») в сторож ровно потому, что тот довод был общим
/// для нескольких операций сразу — здесь довод один и для одной операции, и
/// заводить общий механизм под единственного читателя было бы городить
/// второй ради него.
///
/// # Почему настоящий `LocalTerminalRepository` и настоящий `PairingInvites`
///
/// Тот же довод, что и в `terminal_resume_test.dart`: предмет этого набора —
/// сама проверка кода, а подделка репозитория или списка кодов её не несёт.
/// `FakeQuicServer` + `TillWire` + `TillOperations` — тот же провод, каким
/// браузер говорит с кассой по-настоящему.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
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

/// `terminals.register`/`auth.login` — оба не проверяют `SessionAccess.needs`
/// (`EnrolmentAccess`/`OpenAccess` — сеанс им не нужен вовсе), поэтому сторож
/// сессии здесь не должен звучать.
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
  late TillOperations operations;
  late PairingInvites invites;
  late FakeQuicServer server;
  late TillWire wire;
  late _RecordingAuth auth;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    invites = PairingInvites();
    auth = _RecordingAuth();
    operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
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
  /// `terminal_resume_test.dart`.
  Future<Map<String, Object?>> askOk(
    int sessionId,
    String op,
    Map<String, Object?> body, {
    int streamId = 1,
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
    int streamId = 1,
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
    expect(
      frame,
      isA<ErrorFrame>(),
      reason: '$op: ${server.sentFrames[before]}',
    );
    final error = frame as ErrorFrame;
    return (error.code, error.detail);
  }

  group('гейт регистрации (задача 6) — три исхода и потраченный код', () {
    test('код действительный — заводит новый терминал', () async {
      final code = invites.mint().code;

      final registered = await askOk(1, TillOps.terminalRegister.name, {
        'name': 'Терминал у примерочной',
        'code': code,
      });

      expect((registered['terminal']! as Map)['id'], isNotNull);
      expect(
        registered['secret'],
        isNotEmpty,
        reason: 'заведение по действительному коду обязано отдать секрет — '
            'та же форма ответа, что и до задачи 6',
      );
      expect(await db.terminalDao.all(), hasLength(1));
    });

    test(
      'секрет — существующий терминал возвращается через resume, минуя код',
      () async {
        // Заводим терминал честно, один раз, чтобы получить секрет — сам
        // код здесь ни при чём после этой точки: возврат по секрету
        // (terminals.resume) не был и не становится доводом задачи 6, он
        // защищён задачей 5 отдельно. Проверено здесь, а не только
        // упомянуто, чтобы «три исхода» были доказаны одним набором.
        final registered = await askOk(1, TillOps.terminalRegister.name, {
          'name': 'Терминал у кассы',
          'code': invites.mint().code,
        });
        final terminalId = (registered['terminal']! as Map)['id'] as int;
        final secret = registered['secret'] as String;

        server.emitSessionClosed(sessionId: 1);
        await Future<void>.delayed(Duration.zero);

        final resumed = await askOk(2, TillOps.terminalResume.name, {
          'terminalId': terminalId,
          'secret': secret,
        });

        expect(
          (resumed['terminal']! as Map)['id'],
          terminalId,
          reason: 'секрет обязан вернуть ТОТ ЖЕ терминал без единого кода',
        );
        expect(
          await db.terminalDao.all(),
          hasLength(1),
          reason: 'возврат по секрету не заводит вторую строку',
        );
      },
    );

    test(
      'ни кода, ни секрета — регистрация отказывает названной причиной',
      () async {
        final (code, detail) = await askError(1, TillOps.terminalRegister.name, {
          'name': 'Терминал без кода',
        });

        expect(code, 'pairing_code_invalid');
        expect(
          detail,
          isNotEmpty,
          reason: 'причина обязана быть словами, не пустой строкой',
        );
        expect(
          await db.terminalDao.all(),
          isEmpty,
          reason: 'отклонённая регистрация не заводит строку',
        );
      },
    );

    test('пустой код — тот же отказ, что и отсутствующий', () async {
      final (code, _) = await askError(1, TillOps.terminalRegister.name, {
        'name': 'Терминал с пустым кодом',
        'code': '',
      });

      expect(code, 'pairing_code_invalid');
    });

    test('выдуманный код (никогда не мятый) — тот же отказ', () async {
      final (code, _) = await askError(1, TillOps.terminalRegister.name, {
        'name': 'Терминал с чужим кодом',
        'code': 'этот-код-никто-не-мятил',
      });

      expect(code, 'pairing_code_invalid');
    });

    test(
      'потраченный код отказывает — вторая регистрация тем же кодом не '
      'проходит',
      () async {
        final code = invites.mint().code;

        final first = await askOk(1, TillOps.terminalRegister.name, {
          'name': 'Первая попытка',
          'code': code,
        });
        expect((first['terminal']! as Map)['id'], isNotNull);

        final (errorCode, detail) = await askError(
          2,
          TillOps.terminalRegister.name,
          {'name': 'Вторая попытка тем же кодом', 'code': code},
        );

        expect(errorCode, 'pairing_code_invalid');
        expect(
          detail,
          isNot(contains('Вторая попытка')),
          reason: 'отказ не обязан и не должен нести введённое имя терминала',
        );
        expect(
          await db.terminalDao.all(),
          hasLength(1),
          reason:
              'ГЛАВНАЯ ПРОВЕРКА: потраченный код не заводит вторую строку — '
              'ровно тот повторный проход, ради которого код одноразовый',
        );
      },
    );

    test(
      'касса без настроенного PairingInvites отказывает названной причиной, '
      'а не роняет обмен',
      () async {
        // `invites: null` — тот же довод, что у прочих опциональных портов
        // `TillOperations` (`_deviceDiscovery`/`_sessionAdmin`), но с другим
        // смыслом отсутствия: не «деталь недоступна», а «доказать право '
        // некому» — заведение отказывает целиком, а не проходит открыто.
        final bareOperations = TillOperations(
          db: db,
          bootstrap: _NoopBootstrap(),
          setup: _NoopSetup(),
          terminals: LocalTerminalRepository(db),
          deviceBindings: _NoopBindings(),
          auth: auth,
        );
        final bareServer = FakeQuicServer();
        final bareWire = TillWire(
          bareServer,
          bareOperations.askHandlers,
          guard: _guardFor(db),
          onSessionClosed: bareOperations.forgetSession,
        )..start();
        addTearDown(() async {
          await bareWire.stop();
          await bareServer.dispose();
        });

        bareServer.emitStreamOpened(sessionId: 1, streamId: 1);
        bareServer.emitStreamData(
          sessionId: 1,
          streamId: 1,
          message: jsonEncode({
            'op': TillOps.terminalRegister.name,
            'body': {'name': 'Терминал без привязчика', 'code': 'что-то'},
          }),
        );
        bareServer.emitStreamClosed(sessionId: 1, streamId: 1);
        await Future<void>.delayed(Duration.zero);

        final frame = WireFrame.decode(bareServer.sentFrames.single);
        expect(frame, isA<ErrorFrame>());
        expect((frame as ErrorFrame).code, 'pairing_code_invalid');
      },
    );

    test(
      'заведение по действительному коду доходит до auth.login тем же '
      'terminalId — достижимость, не только сам код',
      () async {
        final registered = await askOk(1, TillOps.terminalRegister.name, {
          'name': 'Терминал у входа',
          'code': invites.mint().code,
        });
        final terminalId = (registered['terminal']! as Map)['id'] as int;

        await askOk(1, TillOps.authLogin.name, {
          'pin': '0000',
          'userId': null,
        });

        expect(auth.loggedTerminalIds, [terminalId]);
      },
    );
  });

  group('свежая установка (задача 6) — десктопный путь не задет', () {
    test(
      'self() заводит свой терминал и логин проходит без единого '
      'PairingInvites в кадре',
      () async {
        // Ни один код здесь не мятится и не проверяется — сам факт того, что
        // `PairingInvites` этому блоку не нужен вовсе, доказывает, что
        // десктопный путь (`self()`/`ensureSelf()`, не `register()`) гейтом
        // задачи 6 не задет: у `LocalTerminalRepository.self()` в сигнатуре
        // нет довода `code`, и вызвать его без кода — единственный способ.
        final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(freshDb.close);

        await freshDb.thisPosDao.insertInitialConfig(
          companyName: 'ЖШС «Свежая касса»',
          iinbin: null,
          cashBoxName: 'Касса-1',
          countryCode: null,
          currencyCode: null,
          currencySymbol: null,
          currencyNameShort: null,
          paperWidth: null,
          printerHeader: null,
          printerFooter: null,
          accountId: null,
          acquiringAccountId: null,
          rsaPublicKey: null,
        );
        final ownerId = await freshDb
            .into(freshDb.users)
            .insert(
              UsersCompanion.insert(
                name: const Value('Владелец'),
                role: const Value(0),
                status: const Value('active'),
                passwordEnc: Value(PinCredential.create('7777')),
              ),
            );

        final terminals = LocalTerminalRepository(freshDb);
        final terminal = await terminals.self();
        expect(
          terminal.name,
          'Касса-1',
          reason: 'свежая установка заводит СВОЙ терминал по self(), не '
              'register() — код здесь структурно негде спросить',
        );
        expect(await freshDb.terminalDao.all(), hasLength(1));

        final realAuth = LocalAuthRepository(
          db: freshDb,
          sessions: SessionRegistry(),
          throttle: LoginThrottle(),
        );
        final outcome = await realAuth.login(
          AuthAttempt(pin: '7777', terminalId: terminal.id, userId: ownerId),
        );

        expect(
          outcome,
          isA<AuthSession>(),
          reason: 'ГЛАВНАЯ ПРОВЕРКА ЗАДАЧИ 6: свежая установка обязана '
              'заводить свой первый терминал и входить — гейт '
              '`terminals.register` не имеет права запереть кассу от самой '
              'себя',
        );
      },
    );
  });
}
