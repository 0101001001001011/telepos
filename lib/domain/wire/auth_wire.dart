/// Пары «в кадр» и «из кадра» для входа.
///
/// По одной паре на тип и в одном месте: разбор, размазанный по репозиториям,
/// приходится чинить столько раз, сколько мест его повторяют
/// (`terminal_wire.dart:1-31`).
library;

import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_rejection.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// Пишет [AuthUser] в форму провода. Обратная — [authUserFromWireJson].
///
/// Хэша PIN здесь нет и быть не может: см. `AuthUser`. Сторож —
/// `test/domain/wire/auth_wire_test.dart` («в кадре кассира нет ключей,
/// похожих на хэш»), сверяющий кадр по множеству ключей, а не по типу.
Map<String, Object?> authUserToWireJson(AuthUser user) => {
  'id': user.id,
  'name': user.name,
  'role': user.role,
  'hasPin': user.hasPin,
};

/// Читает [AuthUser] из формы провода. Обратная — [authUserToWireJson].
AuthUser authUserFromWireJson(Map<String, Object?> json) => AuthUser(
  id: json['id']! as int,
  name: json['name'] as String? ?? 'N/A',
  role: json['role'] as String? ?? '',
  // Отсутствие — это «нет»: умолчание обязано быть тем, которое ничего не
  // утверждает.
  hasPin: json['hasPin'] == true,
);

/// Пишет [AuthSession] в форму провода. Обратная — [authSessionFromWireJson].
Map<String, Object?> authSessionToWireJson(AuthSession session) => {
  'token': session.token,
  'userId': session.userId,
  'name': session.name,
  'role': session.role,
  'permissions': session.permissions.toList(),
  'operatingMode': session.operatingMode,
  // Режим — именем, никогда индексом: вставка члена в PointMode иначе
  // поменяла бы смысл уже выписанного сеанса.
  'pointMode': session.pointMode,
  // Задача 47: пишется только измеренное. «Не знаю» не пишется вовсе, и
  // отсутствие ключа на той стороне читается «не знаю», а не «закрыта».
  if (session.shift != ShiftStatus.unknown)
    'shiftOpen': session.shift == ShiftStatus.open,
  'issuedAt': session.issuedAt.toUtc().toIso8601String(),
  'expiresAt': session.expiresAt.toUtc().toIso8601String(),
  'terminalId': session.terminalId,
};

/// Читает [AuthSession] из формы провода. Обратная —
/// [authSessionToWireJson]. `null` — законное «сеанса нет», не отказ разбора:
/// то же прочтение, что у [`terminalFromWireJson`] для отсутствующего
/// терминала (`terminal_wire.dart`).
AuthSession? authSessionFromWireJson(Map<String, Object?>? json) {
  if (json == null || json['token'] == null) return null;
  return AuthSession(
    token: json['token']! as String,
    userId: json['userId']! as int,
    name: json['name'] as String? ?? 'N/A',
    role: json['role'] as String? ?? '',
    permissions: {...?(json['permissions'] as List?)?.cast<String>()},
    operatingMode: json['operatingMode'] as int? ?? 0,
    pointMode: json['pointMode'] as String? ?? 'selfService',
    // Прежде `== true`: ключа нет — «закрыта». Касса старше терминала или
    // испорченный кадр выдавали незнание за измерение (задача 47).
    shift: switch (json['shiftOpen']) {
      true => ShiftStatus.open,
      false => ShiftStatus.closed,
      _ => ShiftStatus.unknown,
    },
    issuedAt: DateTime.parse(json['issuedAt']! as String),
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    // Обязательное на `AuthSession` — тот же non-null assert, что и у
    // `userId` выше: кадр без `terminalId` пришёл не от этой кассы (она
    // всегда пишет его, `SessionRegistry.mint`) и не заслуживает тихого
    // умолчания.
    terminalId: json['terminalId']! as int,
  );
}

/// Пишет [LiveSession] в форму провода. Обратная — [liveSessionFromWireJson].
///
/// Токена здесь нет и не может быть — [LiveSession] его не несёт по
/// устройству типа (см. докстринг типа). Это не то же самое, что
/// [authSessionToWireJson]:
/// та пара отдаёт токен ровно тому, кто его и прислал (`auth.session`,
/// собственный сеанс вкладки); эта — списку чужих сеансов, который читает
/// не хозяин, а тот, кто решает их отозвать.
Map<String, Object?> liveSessionToWireJson(LiveSession session) => {
  'terminalId': session.terminalId,
  'userId': session.userId,
  'name': session.name,
  'role': session.role,
  'issuedAt': session.issuedAt.toUtc().toIso8601String(),
  'expiresAt': session.expiresAt.toUtc().toIso8601String(),
};

/// Читает [LiveSession] из формы провода. Обратная — [liveSessionToWireJson].
LiveSession liveSessionFromWireJson(Map<String, Object?> json) => (
  terminalId: json['terminalId']! as int,
  userId: json['userId']! as int,
  name: json['name'] as String? ?? 'N/A',
  role: json['role'] as String? ?? '',
  issuedAt: DateTime.parse(json['issuedAt']! as String),
  expiresAt: DateTime.parse(json['expiresAt']! as String),
);

/// Пишет [AuthOutcome] в форму провода. Обратная — [authOutcomeFromWireJson].
Map<String, Object?> authOutcomeToWireJson(AuthOutcome outcome) =>
    switch (outcome) {
      AuthSession() => {'ok': true, 'session': authSessionToWireJson(outcome)},
      AuthRejection() => {'ok': false, 'reason': outcome.reason.name},
    };

/// Нераспознанный исход читается как отказ [AuthRejectionReason.unknown].
///
/// Не как вход: касса новее терминала — обычное состояние при обновлении по
/// одной машине, и выдать непонятый ответ за успешный вход значило бы впустить
/// человека без прав, которых никто не считал. Та же симметрия, что у
/// `_decodeBootStatus`/`_decodeFirstLaunch` в `till_ops.dart`: непонятое
/// читается как самый узкий исход, а не как успех.
AuthOutcome authOutcomeFromWireJson(Map<String, Object?> json) {
  if (json['ok'] == true) {
    final session = authSessionFromWireJson(
      (json['session'] as Map?)?.cast<String, Object?>(),
    );
    if (session != null) return session;
    return const AuthRejection(AuthRejectionReason.unknown);
  }

  final name = json['reason'];
  final reason = AuthRejectionReason.values.firstWhere(
    (r) => r.name == name,
    orElse: () => AuthRejectionReason.unknown,
  );
  return AuthRejection(reason);
}
