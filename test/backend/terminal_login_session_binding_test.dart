/// Пункт 2 фазы 3/4 закрытия долга: `terminalId` для `auth.login` берётся
/// из того, что эта же QUIC-сессия сама зарегистрировала, а не из тела кадра.
///
/// До этой правки `auth.login` проверял о `terminalId` из тела только одно —
/// что такая строка существует (`terminals.list()`). Кассир со своим
/// действительным PIN мог объявить себя чужим терминалом: список терминалов
/// виден через `terminals.list` любому сеансу, а сама проверка не сверяла
/// заявленный id ни с чем, что контролирует касса.
///
/// Настоящий клиентский путь целиком — `FakeQuicServer` + `TillWire` +
/// `TillOperations` — с **двумя различными QUIC-сессиями**, потому что смысл
/// правки именно в этом: касса верит только тому, какая сессия что сама
/// зарегистрировала, а `sessionId` берёт из события `rk_quic`, не из тела,
/// которым распоряжается клиент.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import '../data/transport/fake_quic_server.dart';

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late TillWire wire;
  late int victimId;
  // Задача 6 плана «знакомство терминала с кассой»: `terminals.register`
  // требует код привязки — этот набор про владение сессией, не про сам гейт
  // код/секрет.
  late PairingInvites invites;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
    invites = PairingInvites();

    await db.thisPosDao.insertInitialConfig(
      companyName: 'ЖШС «Тест»',
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
    victimId = await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            name: const Value('Айгуль'),
            role: const Value(3),
            status: const Value('active'),
            passwordEnc: Value(PinCredential.create('1234')),
          ),
        );

    final operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      auth: LocalAuthRepository(
        db: db,
        sessions: SessionRegistry(),
        throttle: LoginThrottle(),
      ),
      invites: invites,
    );
    wire = TillWire(
      server,
      operations.askHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: SessionRegistry(),
      ),
      onSessionClosed: operations.forgetSession,
    )..start();
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  /// Один обмен на своём потоке — так же, как настоящий клиент открывает
  /// новый поток на каждый вопрос.
  ///
  /// Ждёт настоящее (не виртуальное) время, а не один оборот микрозадачи:
  /// `auth.login` проходит через `LocalAuthRepository._matchAll`, который
  /// считает PBKDF2 в отдельном изоляте (`Isolate.run`, ~206 мс) — это
  /// настоящий переход через границу изолята, не микрозадача текущего, и
  /// одного `Duration.zero` для него не хватает (доказано первым падением
  /// этого теста без цикла ниже).
  Future<WireFrame> ask(
    int sessionId,
    int streamId,
    String op,
    Map<String, Object?> body,
  ) async {
    final before = server.sentFrames.length;
    server.emitStreamOpened(sessionId: sessionId, streamId: streamId);
    server.emitStreamData(
      sessionId: sessionId,
      streamId: streamId,
      message: jsonEncode({'op': op, 'body': body}),
    );
    server.emitStreamClosed(sessionId: sessionId, streamId: streamId);
    for (var i = 0; i < 50 && server.sentFrames.length == before; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return WireFrame.decode(server.sentFrames.last);
  }

  test(
    'сессия, ничего не зарегистрировавшая, не входит чужим terminalId из тела',
    () async {
      // Сессия 1 (жертва) заводит себе терминал по-настоящему.
      final registered = await ask(1, 1, TillOps.terminalRegister.name, {
        'name': 'Терминал жертвы',
        'code': invites.mint().code,
      });
      final victimTerminalId =
          ((registered as OkFrame).body['terminal']! as Map)['id'] as int;

      // Сессия 2 (нападающий) НИЧЕГО не регистрировала — просто пробует
      // войти чужим id, назвав его прямо в теле, с настоящим PIN жертвы.
      final attack = await ask(2, 1, TillOps.authLogin.name, {
        'pin': '1234',
        'terminalId': victimTerminalId,
        'userId': victimId,
      });

      expect(
        attack,
        isA<ErrorFrame>(),
        reason:
            'сессия 2 не регистрировала ни одного терминала — тело не '
            'источник истины для terminalId',
      );
      expect((attack as ErrorFrame).code, 'unknown_terminal');
    },
  );

  test(
    'своя сессия с чужим terminalId в теле входит СВОИМ терминалом, не чужим',
    () async {
      final registered1 = await ask(1, 1, TillOps.terminalRegister.name, {
        'name': 'Терминал жертвы',
        'code': invites.mint().code,
      });
      final victimTerminalId =
          ((registered1 as OkFrame).body['terminal']! as Map)['id'] as int;

      // Нападающий регистрирует СВОЙ терминал на своей сессии — честно, как
      // и полагается любому клиенту.
      final registered2 = await ask(2, 1, TillOps.terminalRegister.name, {
        'name': 'Терминал нападающего',
        'code': invites.mint().code,
      });
      final attackerTerminalId =
          ((registered2 as OkFrame).body['terminal']! as Map)['id'] as int;
      expect(attackerTerminalId, isNot(victimTerminalId));

      // Вход на сессии 2 называет в теле terminalId ЖЕРТВЫ — старая дыра.
      final outcome = await ask(2, 2, TillOps.authLogin.name, {
        'pin': '1234',
        'terminalId': victimTerminalId,
        'userId': victimId,
      });

      expect(outcome, isA<OkFrame>(), reason: 'верный PIN входит всегда');
      final session = (outcome as OkFrame).body['session']! as Map;
      expect(
        session['terminalId'],
        attackerTerminalId,
        reason:
            'сеанс обязан получить терминал СЕССИИ (то, что она сама '
            'зарегистрировала), а не тот, что нападающий подставил в тело',
      );
    },
  );
}
