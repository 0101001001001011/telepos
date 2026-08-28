import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/auth/auth_rejection.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/wire/auth_wire.dart';

void main() {
  test('кассир едет туда и обратно без потерь', () {
    const user = AuthUser(id: 7, name: 'Айгуль', role: 'Кассир', hasPin: true);

    final back = authUserFromWireJson(authUserToWireJson(user));

    expect(back.id, 7);
    expect(back.name, 'Айгуль');
    expect(back.role, 'Кассир');
    expect(back.hasPin, isTrue);
  });

  test('в кадре кассира нет ключей, похожих на хэш', () {
    const user = AuthUser(id: 7, name: 'Айгуль', role: 'Кассир', hasPin: true);

    final json = authUserToWireJson(user);

    // Сверка по множеству ключей, а не по типу и не по подстрокам: тест
    // обязан покраснеть, если хэш (или любое другое поле) добавят под
    // любым именем — а не только если добавят поле, содержащее «hash».
    expect(json.keys, unorderedEquals(['id', 'name', 'role', 'hasPin']));
  });

  test('сеанс едет туда и обратно, включая права', () {
    final session = AuthSession(
      token: 'tok',
      userId: 7,
      name: 'Айгуль',
      role: 'Кассир',
      permissions: const {'nav.sale', 'op.editPrice'},
      operatingMode: 1,
      pointMode: 'cashier',
      shiftOpen: true,
      issuedAt: DateTime.utc(2026, 8, 20, 10),
      expiresAt: DateTime.utc(2026, 8, 20, 10, 30),
      terminalId: 42,
    );

    final back = authSessionFromWireJson(authSessionToWireJson(session))!;

    expect(back.token, 'tok');
    expect(back.userId, 7);
    expect(back.name, 'Айгуль');
    expect(back.role, 'Кассир');
    expect(back.permissions, {'nav.sale', 'op.editPrice'});
    expect(back.operatingMode, 1);
    expect(back.pointMode, 'cashier');
    expect(back.shiftOpen, isTrue);
    expect(back.issuedAt, session.issuedAt);
    expect(back.expiresAt, session.expiresAt);
    // Задача 9 закрытия долга: без этой строки тест не заметил бы, если
    // `authSessionToWireJson`/`authSessionFromWireJson` забудут кодировать
    // или раскодировать `terminalId` — обе половины проверены и на
    // `test/backend/session_registry_test.dart`.
    expect(back.terminalId, 42);
  });

  test('отсутствие сеанса на проводе — null, а не выдуманный', () {
    // Симметрия с terminalSelf (terminal_wire.dart): «нет сеанса» — законное
    // состояние (сеанс погас), а не отказ разбора.
    expect(authSessionFromWireJson(null), isNull);
    expect(authSessionFromWireJson(const {}), isNull);
  });

  test('отказ едет причиной, а не пустотой', () {
    const rejection = AuthRejection(AuthRejectionReason.ambiguousPin);

    final back = authOutcomeFromWireJson(authOutcomeToWireJson(rejection));

    expect((back as AuthRejection).reason, AuthRejectionReason.ambiguousPin);
  });

  test('каждая из шести причин отказа переживает круг без искажения', () {
    // Круговой тест доказывает согласие только тех значений, которые в нём
    // названы (terminal_wire.dart:14) — поэтому здесь перечислены все члены
    // AuthRejectionReason.values, а не выборочно две-три причины. Пропавшая
    // здесь причина (например, добавленный седьмой credentialUnreadable)
    // прошла бы кодировку/раскодировку неотличимо от unknown, и этот тест
    // обязан был бы покраснеть, если бы её забыли перечислить.
    //
    // Было семь причин; второй круг задачи 7 (2026-08-21, `login_throttle.dart`)
    // убрал `tooManyAttempts` вместе с пределом одновременных ожиданий,
    // который единственный её и порождал — осталось шесть.
    for (final reason in AuthRejectionReason.values) {
      final rejection = AuthRejection(reason);

      final back = authOutcomeFromWireJson(authOutcomeToWireJson(rejection));

      expect(
        (back as AuthRejection).reason,
        reason,
        reason: 'причина $reason не пережила круг',
      );
    }

    // И самих причин ровно шесть: если кто-то добавит седьмую и забудет
    // включить её в цикл выше (или наоборот, кто-то удалит одну из шести),
    // число здесь его поймает.
    expect(AuthRejectionReason.values, hasLength(6));
  });

  test('нераспознанная причина отказа читается как unknown, а не как вход', () {
    final back = authOutcomeFromWireJson({'ok': false, 'reason': 'сочинённое'});

    expect((back as AuthRejection).reason, AuthRejectionReason.unknown);
  });

  test('исход без session при ok:true читается как отказ, а не как вход', () {
    // Симметрия с _decodeBootStatus/_decodeFirstLaunch: непонятый кадр
    // обязан стать самым узким исходом (отказом), а не пропуском в сеанс.
    final back = authOutcomeFromWireJson({'ok': true});

    expect((back as AuthRejection).reason, AuthRejectionReason.unknown);
  });

  test('успешный исход везёт настоящий сеанс', () {
    final session = AuthSession(
      token: 'tok2',
      userId: 3,
      name: 'Данияр',
      role: 'Менеджер',
      permissions: const {'nav.reports'},
      operatingMode: 0,
      pointMode: 'manager',
      shiftOpen: false,
      issuedAt: DateTime.utc(2026, 8, 20),
      expiresAt: DateTime.utc(2026, 8, 20, 1),
      terminalId: 5,
    );

    final back = authOutcomeFromWireJson(authOutcomeToWireJson(session));

    expect(back, isA<AuthSession>());
    expect((back as AuthSession).token, 'tok2');
    expect(back.pointMode, 'manager');
  });
}
