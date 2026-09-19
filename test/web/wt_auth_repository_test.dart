/// `WtAuthRepository` поверх подставного провода — то же устройство, что у
/// `wt_repositories_test.dart`: диспетчер настоящий, поток — сценарий кадров.
///
/// Разбор кадра под `ask` уже покрыт `auth_wire_test.dart` (не в этом плане) и
/// `till_ops_test.dart`; здесь проверяется не разбор, а то, что делает
/// репозиторий с каждым родом ответа — включая тот, что касса даёт редко и в
/// неудачный момент.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_auth_repository.dart';

import '../data/transport/fake_quic_server.dart';
import '../data/transport/till_operations_stubs.dart';
import 'support/fake_dispatcher.dart';

void main() {
  group('вход', () {
    test('вход отдаёт сеанс, пришедший с кассы', () async {
      final auth = WtAuthRepository(
        answering(
          '{"ok":true,"body":{"ok":true,"session":{'
          '"token":"tok","userId":7,"name":"Айгуль","role":"Кассир",'
          '"permissions":["nav.sale"],"operatingMode":0,'
          '"pointMode":"cashier","shiftOpen":true,'
          '"issuedAt":"2026-08-20T10:00:00.000Z",'
          '"expiresAt":"2026-08-20T10:30:00.000Z","terminalId":1}}}',
        ),
      );

      final outcome = await auth.login(
        const AuthAttempt(pin: '1234', terminalId: 1, userId: 7),
      );

      expect(outcome, isA<AuthSession>());
      final session = outcome as AuthSession;
      expect(session.token, 'tok');
      expect(session.permissions, {'nav.sale'});
    });

    test('отказ кассы доезжает причиной, а не исключением', () async {
      // Отличие от следующего теста — это весь смысл проверки: причина
      // приезжает **значением** внутри успешного обмена (`ok: true` на уровне
      // кадра, `ok: false` внутри тела), а не исключением. Не различить их
      // означало бы посылать кассира переподбирать PIN, когда виновата сеть.
      final auth = WtAuthRepository(
        answering('{"ok":true,"body":{"ok":false,"reason":"ambiguousPin"}}'),
      );

      final outcome = await auth.login(
        const AuthAttempt(pin: '1234', terminalId: 1),
      );

      expect(outcome, isA<AuthRejection>());
      expect(
        (outcome as AuthRejection).reason,
        AuthRejectionReason.ambiguousPin,
      );
    });

    test('недоступная касса — это исключение обмена, а не отказ входа', () async {
      // Разница видна человеку: «неверный PIN» и «касса не отвечает»
      // требуют разных действий. Здесь поток не открывается вовсе
      // (`dispatcherThatRefuses`), поэтому `login` обязан бросить, а не
      // вернуть `AuthOutcome` — слить оба случая в одно значение значило бы
      // спрятать отказ сети под текстом отказа PIN.
      final auth = WtAuthRepository(dispatcherThatRefuses());

      await expectLater(
        auth.login(const AuthAttempt(pin: '1234', terminalId: 1)),
        throwsA(anything),
      );
    });

    // Задача 2б: провод даёт `WireRefusal` со своим кодом на незаведённый
    // `terminalId` (`till_operations.dart`, `unknown_terminal`), и
    // `WtAuthRepository` опознаёт этот случай по коду, а не по тексту.
    //
    // Кадр здесь не фабрикуется: он проведён через настоящий обработчик
    // (`TillOperations`, с настоящим `LocalAuthRepository` поверх базы в
    // памяти) и настоящий `TillWire` — тот же стенд, что у
    // `till_operations_auth_test.dart`, только доведённый до кадра. Кадр,
    // сфабрикованный вручную, остался бы зелёным и тогда, когда обработчик
    // вовсе перестанет бросать отказ (это и произошло после задачи 2).
    test(
      'незаведённый terminalId переводится в UnknownTerminalException',
      () async {
        final frame = await _unknownTerminalErrorFrame();
        final auth = WtAuthRepository(answering(frame));

        await expectLater(
          auth.login(const AuthAttempt(pin: '1234', terminalId: 999)),
          throwsA(isA<UnknownTerminalException>()),
        );
      },
    );

    test(
      'handler_failed без кода unknown_terminal остаётся обычным '
      'исключением обмена',
      () async {
        // Тот же общий код (`handler_failed`), другая причина — эта проверка
        // ловит слишком широкое совпадение: если бы `WtAuthRepository`
        // переводил в `UnknownTerminalException` по коду `handler_failed`
        // самому по себе, любой упавший обработчик выглядел бы как забытый
        // терминал.
        final auth = WtAuthRepository(
          answering(
            '{"ok":false,"code":"handler_failed",'
            '"detail":"TypeError"}',
          ),
        );

        await expectLater(
          auth.login(const AuthAttempt(pin: '1234', terminalId: 1)),
          throwsA(isNot(isA<UnknownTerminalException>())),
        );
      },
    );
  });

  group('кассиры', () {
    test('список кассиров — подписка, первое значение уже пришло', () async {
      final auth = WtAuthRepository(
        answering(
          '{"kind":"update","body":{"users":[{"id":1,"name":"Айгуль",'
          '"role":"Кассир","hasPin":true}]}}',
        ),
      );

      final users = await auth.watchUsers().first;

      expect(users.single.id, 1);
      expect(users.single.hasPin, isTrue);
    });
  });

  group('сеанс', () {
    test('погашенный сеанс приходит null, а не отказом', () async {
      // Погашенный сеанс — законное состояние (выход, бездействие, перезапуск
      // кассы), а не поломка обмена: см. `AuthRepository.watchSession`.
      final auth = WtAuthRepository(
        answering('{"kind":"update","body":{"session":null}}'),
      );

      expect(await auth.watchSession('tok').first, isNull);
    });

    test('выход зовёт кассу и не бросает на успешном ответе', () async {
      final auth = WtAuthRepository(answering('{"ok":true,"body":{"ok":true}}'));

      await expectLater(auth.logout('tok'), completes);
    });
  });
}

/// Настоящий обработчик `authLogin` и настоящий `TillWire` на терминале с
/// `id: 999`, которого касса не знает. Возвращает закодированный кадр отказа
/// как его увидел бы терминал — тот же текст, который `answering()` кладёт в
/// подставной поток.
///
/// Стенд собран по образцу `test/backend/till_watch_test.dart` (`ask()`,
/// `FakeQuicServer`) и `test/backend/till_operations_auth_test.dart`
/// (настоящий `LocalAuthRepository` поверх базы в памяти).
Future<String> _unknownTerminalErrorFrame() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final server = FakeQuicServer();
  final sessions = SessionRegistry();
  final guard = wireGuardForTill(
    db: db,
    access: {for (final op in TillOps.all) op.name: op.access},
    sessions: sessions,
  );
  final operations = TillOperations(
    db: db,
    bootstrap: NoopBootstrap(),
    setup: NoopSetupRepository(),
    terminals: EmptyTerminalRepository(),
    deviceBindings: NoopDeviceBindingRepository(),
    auth: LocalAuthRepository(
      db: db,
      sessions: sessions,
      throttle: LoginThrottle(),
    ),
  );

  final wire = TillWire(server, operations.askHandlers, guard: guard)..start();
  server.emitStreamOpened(sessionId: 1, streamId: 8);
  server.emitStreamData(
    sessionId: 1,
    streamId: 8,
    message: jsonEncode({
      'op': TillOps.authLogin.name,
      'body': {'pin': '1234', 'terminalId': 999, 'userId': null},
    }),
  );
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await wire.stop();
  await db.close();
  return server.sentFrames.single;
}
