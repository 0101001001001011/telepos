/// `WtSessionAdminRepository` поверх подставного провода — то же устройство,
/// что у `wt_auth_repository_test.dart`: диспетчер настоящий, поток —
/// сценарий кадров. Разбор кадра под `authSessions`/`authSessionRevoke` уже
/// покрыт `till_ops_test.dart`; здесь проверяется то, что делает репозиторий
/// с ответом — задача «второй порядок» закрытия долга безопасности
/// (2026-08-22), пункт 6: до этого класса у `TillOps.authSessions`/
/// `authSessionRevoke` не было ни одного вызывающего в `lib/`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/web/wt_session_admin_repository.dart';

import 'support/fake_dispatcher.dart';

void main() {
  group('watchLiveSessions', () {
    test('подписка — первое значение уже пришло со списком сеансов', () async {
      final repo = WtSessionAdminRepository(
        answering(
          '{"kind":"update","body":{"sessions":[{'
          '"terminalId":5,"userId":7,"name":"Айгуль","role":"cashier",'
          '"issuedAt":"2026-08-20T10:00:00.000Z",'
          '"expiresAt":"2026-08-20T10:30:00.000Z"}]}}',
        ),
      );

      final sessions = await repo.watchLiveSessions().first;

      expect(sessions, hasLength(1));
      expect(sessions.single.terminalId, 5);
      expect(sessions.single.name, 'Айгуль');
    });

    test('пустой список — законное «никто не вошёл», не отказ', () async {
      final repo = WtSessionAdminRepository(
        answering('{"kind":"update","body":{"sessions":[]}}'),
      );

      expect(await repo.watchLiveSessions().first, isEmpty);
    });
  });

  group('revokeSession', () {
    test('true — было что гасить', () async {
      final repo = WtSessionAdminRepository(
        answering('{"ok":true,"body":{"ok":true}}'),
      );

      expect(await repo.revokeSession(5), isTrue);
    });

    test('false — терминал уже без живого сеанса, не ошибка вызова', () async {
      final repo = WtSessionAdminRepository(
        answering('{"ok":true,"body":{"ok":false}}'),
      );

      expect(await repo.revokeSession(5), isFalse);
    });
  });
}
