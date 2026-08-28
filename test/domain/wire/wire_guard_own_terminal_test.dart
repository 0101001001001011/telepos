/// Владение терминалом — задача 10 закрытия долга.
///
/// До этой задачи `terminals.rename`, `terminals.deviceBindings`,
/// `terminals.deviceBindingSave` и `terminals.deviceCheck` брали `terminalId`
/// из тела запроса, и никто не сверял его с сеансом: кассир с правом
/// `settings.hardware` мог напечатать пробный чек и открыть денежный ящик
/// **чужого** терминала. `terminals.delete` (задача 9) устроен наоборот — он
/// не должен нацелиться на терминал, под которым сидит сама вкладка.
///
/// `wire_guard_test.dart` (задача 4) проверяет `check` без `ownTerminal` —
/// здесь только то, что добавила задача 10: сам довод, обе его полярности и
/// тело без `terminalId`.
library;

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

AuthSession _session({required int terminalId}) => AuthSession(
  token: 'tok',
  userId: 1,
  name: 'Айгуль',
  role: 'cashier',
  permissions: const {PermissionKeys.settingsHardware},
  operatingMode: 0,
  pointMode: 'cashier',
  shiftOpen: false,
  issuedAt: DateTime.utc(2026, 8, 21, 10),
  expiresAt: DateTime.utc(2026, 8, 21, 10, 30),
  terminalId: terminalId,
);

void main() {
  WireGuard guard({
    required Map<String, WireAccess> access,
    required int sessionTerminalId,
    int? selfTerminalId,
  }) => WireGuard(
    access: access,
    sessions: _Sessions({'tok': _session(terminalId: sessionTerminalId)}),
    isTillConfigured: () async => true,
    selfTerminalId: () async => selfTerminalId,
  );

  group('TerminalOwnership.same — rename, deviceBindings, deviceBindingSave, '
      'deviceCheck', () {
    for (final op in const [
      'terminals.rename',
      'terminals.deviceBindings',
      'terminals.deviceBindingSave',
      'terminals.deviceCheck',
    ]) {
      final access = {
        op: const SessionAccess(
          needs: PermissionKeys.settingsHardware,
          ownTerminal: TerminalOwnership.same,
        ),
      };

      test('$op: чужой terminalId в теле — отказ forbidden', () async {
        final g = guard(access: access, sessionTerminalId: 1);

        final verdict =
            await g.check(op, {'terminalId': 2}, 'tok') as WireDenied;

        expect(verdict.code, WireDenied.forbidden);
      });

      test('$op: свой terminalId в теле — проход', () async {
        final g = guard(access: access, sessionTerminalId: 1);

        final verdict = await g.check(op, {'terminalId': 1}, 'tok');

        expect(verdict, isA<WireAllowed>());
      });

      test(
        '$op: тело без terminalId — отказ, а не проход умолчанием',
        () async {
          final g = guard(access: access, sessionTerminalId: 1);

          final verdict = await g.check(op, const {}, 'tok') as WireDenied;

          expect(
            verdict.code,
            WireDenied.forbidden,
            reason:
                'операция с ownTerminal обязана требовать terminalId, а не '
                'молча пускать его отсутствие',
          );
        },
      );

      test(
        '$op: terminalId не целым числом — отказ, как и отсутствие вовсе',
        () async {
          final g = guard(access: access, sessionTerminalId: 1);

          final verdict =
              await g.check(op, {'terminalId': '1'}, 'tok') as WireDenied;

          expect(verdict.code, WireDenied.forbidden);
        },
      );
    }
  });

  group(
    'регрессия фазы 3/4: терминал самой кассы — законный второй владелец',
    () {
      // `hardware_settings_screen.dart` и его соседи (`printer_settings_screen
      // .dart`, `label_printer_settings_screen.dart`) берут `terminalId` через
      // `TerminalRepository.self()`, а не из сеанса. В браузере это
      // `terminals.selfEnsure` — строка **самой кассы** (`isSelf`), а не
      // терминал вызывающей вкладки (`session.terminalId`, заведённый
      // `terminals.register`). Эти два числа никогда не совпадают в браузере,
      // и до этой правки сторож требовал именно `session.terminalId` —
      // все четыре операции отвечали `forbidden`, а `catch (_)` в
      // `_loadSettings` открывал экран пустым, будто оборудование не
      // настроено.
      for (final op in const [
        'terminals.rename',
        'terminals.deviceBindings',
        'terminals.deviceBindingSave',
        'terminals.deviceCheck',
      ]) {
        final access = {
          op: const SessionAccess(
            needs: PermissionKeys.settingsHardware,
            ownTerminal: TerminalOwnership.same,
          ),
        };

        test(
          '$op: terminalId терминала самой кассы — проход, хотя сеанс '
          'сидит на другом терминале',
          () async {
            final g = guard(
              access: access,
              sessionTerminalId: 1, // терминал вкладки (register())
              selfTerminalId: 7, // терминал кассы (isSelf)
            );

            final verdict = await g.check(op, {'terminalId': 7}, 'tok');

            expect(
              verdict,
              isA<WireAllowed>(),
              reason:
                  'браузер настраивает оборудование кассы, к которой '
                  'подключён — HostCapabilities.browser говорит это прямым '
                  'текстом',
            );
          },
        );

        test(
          '$op: чужой terminalId, не совпадающий ни с сеансом, ни с '
          'кассой — по-прежнему отказ',
          () async {
            final g = guard(
              access: access,
              sessionTerminalId: 1,
              selfTerminalId: 7,
            );

            final verdict =
                await g.check(op, {'terminalId': 999}, 'tok') as WireDenied;

            expect(verdict.code, WireDenied.forbidden);
          },
        );

        test(
          '$op: своего терминала кассы ещё нет (мастер не проходил) — '
          'чужой terminalId всё равно отказ, не крах',
          () async {
            final g = guard(
              access: access,
              sessionTerminalId: 1,
              selfTerminalId: null,
            );

            final verdict =
                await g.check(op, {'terminalId': 999}, 'tok') as WireDenied;

            expect(verdict.code, WireDenied.forbidden);
          },
        );
      }
    },
  );

  group('TerminalOwnership.different — terminals.delete', () {
    const access = {
      'terminals.delete': SessionAccess(
        needs: PermissionKeys.settingsHardware,
        ownTerminal: TerminalOwnership.different,
      ),
    };

    test('свой terminalId в теле — отказ cannot_delete_self', () async {
      final g = guard(access: access, sessionTerminalId: 1);

      final verdict =
          await g.check('terminals.delete', {'terminalId': 1}, 'tok')
              as WireDenied;

      expect(verdict.code, 'cannot_delete_self');
    });

    test('чужой terminalId в теле — проход', () async {
      final g = guard(access: access, sessionTerminalId: 1);

      final verdict = await g.check('terminals.delete', {
        'terminalId': 2,
      }, 'tok');

      expect(verdict, isA<WireAllowed>());
    });

    test('тело без terminalId — отказ, а не проход умолчанием', () async {
      final g = guard(access: access, sessionTerminalId: 1);

      final verdict =
          await g.check('terminals.delete', const {}, 'tok') as WireDenied;

      expect(verdict.code, WireDenied.forbidden);
    });
  });

  test(
    'операция без ownTerminal не смотрит в тело вовсе — не задевает соседей',
    () async {
      // `terminals.list` в настоящем каталоге устроен именно так: сеанс
      // нужен, терминал — нет. Тело с чужим `terminalId` не должно мешать —
      // сторож его попросту не читает, когда `ownTerminal` не задан.
      final g = guard(
        access: {'terminals.list': const SessionAccess()},
        sessionTerminalId: 1,
      );

      final verdict = await g.check('terminals.list', {
        'terminalId': 999,
      }, 'tok');

      expect(verdict, isA<WireAllowed>());
    },
  );
}
