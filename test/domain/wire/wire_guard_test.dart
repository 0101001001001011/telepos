import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

class _Sessions implements SessionLookup {
  _Sessions(this._byToken);
  final Map<String, AuthSession> _byToken;
  @override
  AuthSession? sessionFor(String token) => _byToken[token];
}

AuthSession _session({Set<String> permissions = const {}}) => AuthSession(
  token: 'tok',
  userId: 1,
  name: 'Айгуль',
  role: 'cashier',
  permissions: permissions,
  operatingMode: 0,
  pointMode: 'cashier',
  shiftOpen: false,
  issuedAt: DateTime.utc(2026, 8, 21, 10),
  expiresAt: DateTime.utc(2026, 8, 21, 10, 30),
  terminalId: 1,
);

void main() {
  WireGuard guard({
    required Map<String, WireAccess> access,
    Map<String, AuthSession> sessions = const {},
    bool configured = true,
  }) => WireGuard(
    access: access,
    sessions: _Sessions(sessions),
    isTillConfigured: () async => configured,
    // Ни один тест этого файла не проверяет `TerminalOwnership.same` — та
    // группа целиком в `wire_guard_own_terminal_test.dart`, включая ветку
    // «терминал самой кассы».
    selfTerminalId: () async => null,
  );

  test('открытая операция пускает без токена', () async {
    final g = guard(access: {'startup.boot': const OpenAccess()});

    expect(await g.check('startup.boot', const {}, null), isA<WireAllowed>());
  });

  test('закрытая операция без токена — отказ', () async {
    final g = guard(access: {'terminals.list': const SessionAccess()});

    final verdict = await g.check('terminals.list', const {}, null);

    expect(verdict, isA<WireDenied>());
  });

  test('неизвестный токен — отказ, а не пропуск', () async {
    final g = guard(access: {'terminals.list': const SessionAccess()});

    expect(
      await g.check('terminals.list', const {}, 'чужой'),
      isA<WireDenied>(),
    );
  });

  test('живой сеанс пускает и доезжает до вызывающего', () async {
    final g = guard(
      access: {'terminals.list': const SessionAccess()},
      sessions: {'tok': _session()},
    );

    final verdict = await g.check('terminals.list', const {}, 'tok');

    expect((verdict as WireAllowed).session?.userId, 1);
  });

  test('сеанс есть, права нет — отказ', () async {
    // Тот самый случай: deviceCheck печатает чек и открывает денежный ящик.
    final g = guard(
      access: {
        'terminals.deviceCheck': const SessionAccess(
          needs: PermissionKeys.settingsHardware,
        ),
      },
      sessions: {
        'tok': _session(permissions: const {PermissionKeys.navSale}),
      },
    );

    expect(
      await g.check('terminals.deviceCheck', const {}, 'tok'),
      isA<WireDenied>(),
    );
  });

  test('сеанс с правом — пускает', () async {
    final g = guard(
      access: {
        'terminals.deviceCheck': const SessionAccess(
          needs: PermissionKeys.settingsHardware,
        ),
      },
      sessions: {
        'tok': _session(permissions: const {PermissionKeys.settingsHardware}),
      },
    );

    expect(
      await g.check('terminals.deviceCheck', const {}, 'tok'),
      isA<WireAllowed>(),
    );
  });

  test('мастер открыт, пока касса не настроена', () async {
    final g = guard(
      access: {'setup.complete': const SetupOnlyAccess()},
      configured: false,
    );

    expect(await g.check('setup.complete', const {}, null), isA<WireAllowed>());
  });

  test('настроенную кассу мастером не перезаписать', () async {
    final g = guard(
      access: {'setup.complete': const SetupOnlyAccess()},
      configured: true,
    );

    expect(await g.check('setup.complete', const {}, null), isA<WireDenied>());
  });

  test('незнакомая операция — отказ, а не пропуск', () async {
    // Умолчание обязано быть закрытым: имя, которого нет в словаре, не должно
    // проскочить мимо проверки к поиску по картам обработчиков.
    final g = guard(access: const {});

    expect(await g.check('что.нибудь', const {}, 'tok'), isA<WireDenied>());
  });

  group('код отказа называет причину — круг правок 1', () {
    // До этой группы все четыре ветки `WireDenied` ниже уходили одним и тем
    // же кодом `unauthorized`. Задача 4 завела `SessionLost` именно из этого
    // кода и тут же обнаружила следствие: кассир с живым сеансом, которому
    // просто не хватает права, получил бы `SessionLost` и ходил бы по кругу
    // «войди заново — получи тот же отказ» — вход не чинит нехватку права.
    // Каждый тест здесь проверяет один код; последний — что все четыре кода
    // различны между собой, а не просто «не unauthorized»: без него слияние
    // двух любых кодов друг с другом (например, `forbidden` обратно в
    // `already_configured`) не покраснит ни один тест выше поодиночке.

    test('нет токена — unauthorized', () async {
      final g = guard(access: {'terminals.list': const SessionAccess()});

      final verdict =
          await g.check('terminals.list', const {}, null) as WireDenied;

      expect(verdict.code, WireDenied.unauthorized);
    });

    test('токен есть, сеанс неизвестен — unauthorized', () async {
      final g = guard(access: {'terminals.list': const SessionAccess()});

      final verdict =
          await g.check('terminals.list', const {}, 'чужой') as WireDenied;

      expect(verdict.code, WireDenied.unauthorized);
    });

    test(
      'сеанс живой, права не хватает — forbidden, не unauthorized',
      () async {
        // Тот самый случай: живой сеанс не лечится повторным входом.
        final g = guard(
          access: {
            'terminals.deviceCheck': const SessionAccess(
              needs: PermissionKeys.settingsHardware,
            ),
          },
          sessions: {
            'tok': _session(permissions: const {PermissionKeys.navSale}),
          },
        );

        final verdict =
            await g.check('terminals.deviceCheck', const {}, 'tok')
                as WireDenied;

        expect(verdict.code, WireDenied.forbidden);
      },
    );

    test('касса уже настроена — already_configured, не unauthorized', () async {
      final g = guard(
        access: {'setup.complete': const SetupOnlyAccess()},
        configured: true,
      );

      final verdict =
          await g.check('setup.complete', const {}, null) as WireDenied;

      expect(verdict.code, WireDenied.alreadyConfigured);
    });

    test('операция не в словаре — unknown_op, не unauthorized', () async {
      final g = guard(access: const {});

      final verdict =
          await g.check('что.нибудь', const {}, 'tok') as WireDenied;

      expect(verdict.code, WireDenied.unknownOp);
    });

    test(
      'все четыре кода различны — иначе они снова сольются в один',
      () async {
        final noToken = guard(
          access: {'terminals.list': const SessionAccess()},
        );
        final needsRight = guard(
          access: {
            'terminals.deviceCheck': const SessionAccess(
              needs: PermissionKeys.settingsHardware,
            ),
          },
          sessions: {
            'tok': _session(permissions: const {PermissionKeys.navSale}),
          },
        );
        final setup = guard(
          access: {'setup.complete': const SetupOnlyAccess()},
          configured: true,
        );
        final unknown = guard(access: const {});

        final codes = {
          (await noToken.check('terminals.list', const {}, null) as WireDenied)
              .code,
          (await needsRight.check('terminals.deviceCheck', const {}, 'tok')
                  as WireDenied)
              .code,
          (await setup.check('setup.complete', const {}, null) as WireDenied)
              .code,
          (await unknown.check('что.нибудь', const {}, 'tok') as WireDenied)
              .code,
        };

        expect(
          codes.length,
          4,
          reason: 'четыре разных отказа обязаны нести четыре разных кода',
        );
      },
    );
  });
}
