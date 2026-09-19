/// Врезка сторожа в провод: одна точка проверки в `_onRequest`, три рода
/// обмена и одна открытая операция.
///
/// Разбор кадра и `WireGuard.check` покрыты отдельно (`wire_guard_test.dart`
/// задачи 4) — здесь проверяется только то, что не проверить оттуда: что
/// `TillWire` действительно зовёт сторожа **до** обработчика, а не вместе с
/// ним и не после.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

import 'fake_quic_server.dart';
import 'open_guard.dart' show NoSession;
import 'package:telepos/domain/shift/shift_status.dart';

Future<bool> _neverConfigured() async => false;

/// Один сеанс на один известный ей токен — для проверки кода `forbidden`,
/// которому нужен живой сеанс без нужного права, а не `NoSession`.
class _OneSession implements SessionLookup {
  const _OneSession(this._token, this._session);
  final String _token;
  final AuthSession _session;

  @override
  AuthSession? sessionFor(String token) => token == _token ? _session : null;
}

/// Живой сеанс без `settings.hardware` — что угодно, кроме него.
AuthSession _sessionWithoutHardware() => AuthSession(
  token: 'tok',
  userId: 1,
  name: 'Айгуль',
  role: 'cashier',
  permissions: const {PermissionKeys.navSale},
  operatingMode: 0,
  pointMode: 'cashier',
  shift: ShiftStatus.closed,
  issuedAt: DateTime.utc(2026, 8, 21, 10),
  expiresAt: DateTime.utc(2026, 8, 21, 10, 30),
  terminalId: 1,
);

void main() {
  late FakeQuicServer server;
  late TillWire wire;

  setUp(() => server = FakeQuicServer());
  tearDown(() async {
    await wire.stop();
    await server.dispose();
  });

  /// Тот же обмен целиком, что и в `till_wire_test.dart`: `streamClosed` идёт
  /// сразу за запросом, потому что касса читает сообщение до конца, прежде
  /// чем оно станет событием.
  Future<void> askAndSettle(String message) async {
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(sessionId: 1, streamId: 4, message: message);
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);
  }

  TillWire wireWith({
    Map<String, WireHandler> handlers = const {},
    Map<String, WireWatchHandler> watchHandlers = const {},
    Map<String, WireRunHandler> runHandlers = const {},
    required Map<String, WireAccess> access,
    // Настроенность здесь по умолчанию ни при чём — проверяемые операции
    // требуют сеанса, а не смотрят на неё. Перекрывается там, где сторожу
    // самому надо упасть.
    Future<bool> Function() isTillConfigured = _neverConfigured,
    // `NoSession` не знает ни одного токена — ровно то, что нужно ветке «нет
    // сеанса». Ветке «сеанс живой, права не хватает» нужен настоящий сеанс —
    // перекрывается там, где он проверяется.
    SessionLookup sessions = const NoSession(),
    // Задача 21 закрытия долга безопасности: `TillWire.onDenied` — единственная
    // точка, через которую отказ сторожа сегодня доходит до журнала событий
    // безопасности (`test/backend/security_journal_test.dart` проверяет сам
    // журнал; здесь проверяется только то, что `TillWire` действительно
    // зовёт его на `WireDenied`, а не на `WireAllowed`).
    void Function(String op, WireDenied denied, int sessionKey, Map<String, Object?> body)?
    onDenied,
  }) => TillWire(
    server,
    handlers,
    watchHandlers: watchHandlers,
    runHandlers: runHandlers,
    guard: WireGuard(
      access: access,
      sessions: sessions,
      isTillConfigured: isTillConfigured,
      // Владение терминалом здесь не проверяется ни одним тестом файла —
      // тем не менее `TerminalOwnership.same` — не задача этого набора
      // (`wire_guard_own_terminal_test.dart`).
      selfTerminalId: () async => null,
    ),
    onDenied: onDenied,
  )..start();

  test(
    'Ask без сеанса — кадр отказа unauthorized, обработчик не звался',
    () async {
      var called = false;
      wire = wireWith(
        handlers: {
          'terminals.rename': (_, [_, _]) async {
            called = true;
            return {};
          },
        },
        access: {'terminals.rename': const SessionAccess()},
      );

      await askAndSettle('{"op":"terminals.rename","body":{}}');

      final frame = WireFrame.decode(server.sentFrames.single);
      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, 'unauthorized');
      expect(called, isFalse, reason: 'обработчик не должен быть вызван вовсе');
    },
  );

  test('Watch без сеанса — отказ, подписка не заводится', () async {
    var called = false;
    wire = wireWith(
      watchHandlers: {
        'terminals.list': (_, [_, _]) {
          called = true;
          return const Stream.empty();
        },
      },
      access: {'terminals.list': const SessionAccess()},
    );

    await askAndSettle('{"op":"terminals.list","body":{}}');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'unauthorized');
    expect(called, isFalse, reason: 'подписка не должна заводиться вовсе');
    expect(
      wire.liveSubscriptions,
      0,
      reason: 'отказ не оставляет за собой открытую подписку',
    );
  });

  test('Run без сеанса — отказ, работа не начинается', () async {
    var called = false;
    wire = wireWith(
      runHandlers: {
        'setup.restore': (_) {
          called = true;
          return const Stream.empty();
        },
      },
      access: {'setup.restore': const SessionAccess()},
    );

    await askAndSettle('{"op":"setup.restore","body":{}}');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'unauthorized');
    expect(called, isFalse, reason: 'работа не должна начинаться вовсе');
  });

  test('открытая операция проходит без токена', () async {
    wire = wireWith(
      handlers: {
        'startup.boot': (_, [_, _]) async => {'ok': true},
      },
      access: {'startup.boot': const OpenAccess()},
    );

    await askAndSettle('{"op":"startup.boot","body":{}}');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(
      frame,
      isA<OkFrame>(),
      reason: 'открытая операция не имеет права запереть кассу от самой себя',
    );
    expect((frame as OkFrame).body, {'ok': true});
  });

  test(
    'сторож бросает исключение — отказ guard_failed закрыто, обработчик не звался',
    () async {
      // `SetupOnlyAccess` — единственный род доступа, который сам зовёт
      // `isTillConfigured`; в рабочей сборке это чтение базы
      // (`readSetupStateOf`), и запертая или закрытая база бросает ровно так.
      var called = false;
      wire = wireWith(
        handlers: {
          'setup.restore': (_, [_, _]) async {
            called = true;
            return {};
          },
        },
        access: {'setup.restore': const SetupOnlyAccess()},
        isTillConfigured: () async => throw StateError('база заперта'),
      );

      await askAndSettle('{"op":"setup.restore","body":{}}');

      final frame = WireFrame.decode(server.sentFrames.single);
      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, 'guard_failed');
      expect(
        called,
        isFalse,
        reason: 'упавший сторож не повод пустить запрос к обработчику',
      );
    },
  );

  group('код в кадре различает причину отказа — круг правок 1', () {
    // Три ветки ниже — то, что «Ask без сеанса» выше не покрывает: живой
    // сеанс без права, уже настроенная касса, операция мимо словаря. До
    // круга 1 все они уходили тем же `unauthorized`, что и «нет сеанса».

    test(
      'Ask с сеансом, но без права — кадр отказа forbidden, не unauthorized',
      () async {
        var called = false;
        wire = wireWith(
          handlers: {
            'terminals.deviceCheck': (_, [_, _]) async {
              called = true;
              return {};
            },
          },
          access: {
            'terminals.deviceCheck': const SessionAccess(
              needs: PermissionKeys.settingsHardware,
            ),
          },
          sessions: _OneSession('tok', _sessionWithoutHardware()),
        );

        await askAndSettle(
          '{"op":"terminals.deviceCheck","body":{},"token":"tok"}',
        );

        final frame = WireFrame.decode(server.sentFrames.single);
        expect(frame, isA<ErrorFrame>());
        expect((frame as ErrorFrame).code, 'forbidden');
        expect(
          called,
          isFalse,
          reason: 'обработчик не должен быть вызван вовсе',
        );
      },
    );

    test('Ask мастера на настроенной кассе — кадр отказа already_configured, '
        'не unauthorized', () async {
      var called = false;
      wire = wireWith(
        handlers: {
          'setup.complete': (_, [_, _]) async {
            called = true;
            return {};
          },
        },
        access: {'setup.complete': const SetupOnlyAccess()},
        isTillConfigured: () async => true,
      );

      await askAndSettle('{"op":"setup.complete","body":{}}');

      final frame = WireFrame.decode(server.sentFrames.single);
      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, 'already_configured');
      expect(
        called,
        isFalse,
        reason: 'мастер не перезаписывает настроенную кассу',
      );
    });

    test('Ask операции мимо словаря доступа — кадр отказа unknown_op, '
        'не unauthorized', () async {
      // Словарь доступа этого `wire` не знает `demo.ghost` вовсе — то же
      // расхождение каталога и карт обработчиков, что описано в
      // `wire_guard.dart` (`WireDenied.unknownOp`).
      wire = wireWith(access: const {});

      await askAndSettle('{"op":"demo.ghost","body":{}}');

      final frame = WireFrame.decode(server.sentFrames.single);
      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, 'unknown_op');
    });
  });

  group('onDenied — задача 21 закрытия долга безопасности', () {
    // До этой задачи `_guard.check → WireDenied → _refuse` не звал ни
    // одного обращения к журналу событий безопасности (бриф задачи 21).
    // ГЛАВНЫЙ ТЕСТ группы: `onDenied` действительно зовётся на `WireDenied`
    // и не зовётся на `WireAllowed` — без вызова в `till_wire.dart`
    // `calls` остался бы пуст на первом тесте, доказывая, что тест краснеет
    // без реализации, а не просто существует.
    test(
      'ГЛАВНЫЙ ТЕСТ: отказ сторожа зовёт onDenied с кодом и телом запроса',
      () async {
        final calls =
            <({String op, String code, int sessionKey, Map<String, Object?> body})>[];
        wire = wireWith(
          access: {'terminals.rename': const SessionAccess()},
          onDenied: (op, denied, sessionKey, body) => calls.add((
            op: op,
            code: denied.code,
            sessionKey: sessionKey,
            body: body,
          )),
        );

        await askAndSettle(
          '{"op":"terminals.rename","body":{"terminalId":42}}',
        );

        expect(calls, hasLength(1));
        expect(calls.single.op, 'terminals.rename');
        expect(calls.single.code, 'unauthorized');
        expect(calls.single.body, {'terminalId': 42});
      },
    );

    test('разрешённая операция не зовёт onDenied вовсе', () async {
      var calls = 0;
      wire = wireWith(
        handlers: {
          'startup.boot': (_, [_, _]) async => {'ok': true},
        },
        access: {'startup.boot': const OpenAccess()},
        onDenied: (_, _, _, _) => calls++,
      );

      await askAndSettle('{"op":"startup.boot","body":{}}');

      expect(calls, 0);
    });

    test(
      'forbidden несёт найденный сеанс — терминал и кассир для журнала '
      'настоящие, а не угаданные',
      () async {
        WireDenied? denied;
        wire = wireWith(
          handlers: {
            'terminals.deviceCheck': (_, [_, _]) async => {},
          },
          access: {
            'terminals.deviceCheck': const SessionAccess(
              needs: PermissionKeys.settingsHardware,
            ),
          },
          sessions: _OneSession('tok', _sessionWithoutHardware()),
          onDenied: (_, d, _, _) => denied = d,
        );

        await askAndSettle(
          '{"op":"terminals.deviceCheck","body":{},"token":"tok"}',
        );

        expect(denied, isNotNull);
        expect(denied!.code, 'forbidden');
        expect(
          denied!.session?.userId,
          _sessionWithoutHardware().userId,
          reason:
              'сеанс найден до отказа — журналу незачем гадать terminalId/'
              'userId по телу или по сессии провода',
        );
        expect(denied!.session?.terminalId, _sessionWithoutHardware().terminalId);
      },
    );

    test('unauthorized не несёт сеанса — сеанса и не было', () async {
      WireDenied? denied;
      wire = wireWith(
        access: {'terminals.rename': const SessionAccess()},
        onDenied: (_, d, _, _) => denied = d,
      );

      await askAndSettle('{"op":"terminals.rename","body":{}}');

      expect(denied, isNotNull);
      expect(denied!.code, 'unauthorized');
      expect(
        denied!.session,
        isNull,
        reason: 'нет сеанса — журналу нечем его выдать, кроме body/sessionKey',
      );
    });

    // ГЛАВНЫЙ ТЕСТ пункта 7 брифа закрытия долга безопасности (2026-08-22):
    // до этой правки упавший сторож (`_guard.check` бросил, не вернул
    // `WireDenied`) отвечал кадром `guard_failed`, но не звал `onDenied`
    // вовсе — «отказ есть, записи нет», дыра в той же функции, что и
    // обычный `WireDenied` выше в этой группе.
    test(
      'ГЛАВНЫЙ ТЕСТ: упавший сторож (guard_failed) тоже зовёт onDenied, не '
      'только отвечает кадром отказа',
      () async {
        WireDenied? denied;
        wire = wireWith(
          access: {'setup.complete': const SetupOnlyAccess()},
          // `isTillConfigured` — то немногое, что сторож зовёт изнутри
          // `check` до возврата вердикта; бросая здесь, симулируем
          // настоящий сбой сторожа (база настройки закрыта/заперта), а не
          // придуманный.
          isTillConfigured: () async => throw StateError('база заперта'),
          onDenied: (_, d, _, _) => denied = d,
        );

        await askAndSettle('{"op":"setup.complete","body":{}}');

        final frame = WireFrame.decode(server.sentFrames.single);
        expect(frame, isA<ErrorFrame>());
        expect((frame as ErrorFrame).code, 'guard_failed');

        expect(
          denied,
          isNotNull,
          reason: 'guard_failed обязан дойти до журнала events так же, как '
              'и обычный WireDenied',
        );
        expect(denied!.code, 'guard_failed');
      },
    );
  });
}
