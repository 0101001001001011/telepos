import 'package:telepos/domain/auth/live_session.dart';

/// Управление чужими сеансами — не своим, тем ([AuthRepository]), а всеми
/// живыми сеансами этой кассы разом. Узкий порт, тем же приёмом, что
/// [SessionLookup]/[TerminalSessionCheck] рядом
/// (`lib/domain/auth/session_lookup.dart`,
/// `lib/domain/auth/terminal_session_check.dart`): экран списка сеансов
/// (задача 19 закрытия долга безопасности) не должен получать весь
/// `SessionRegistry`, ему нужно ровно два действия — смотреть и гасить.
///
/// Отзыв чужого сеанса — не то же самое, что настройка оборудования: право
/// `settings.hardware` решает, что можно сделать со своим железом, а тут
/// решение — кого вообще пускать в кассу дальше. Это тот же периметр, что и
/// у `settings.users`/`/auth-settings` (задача 18, закрытие И31): «кто и
/// как входит», а не «что подключено». Поэтому обе операции
/// (`TillOps.authSessions`, `TillOps.authSessionRevoke`) требуют
/// `PermissionKeys.settingsUsers`, не `settingsHardware` — реализация в
/// `till_ops.dart`.
abstract interface class SessionAdmin {
  /// Живые сеансы этой кассы. Первое значение — снимок на момент подписки,
  /// дальше — любое изменение множества (новый вход, отзыв, истечение по
  /// бездействию).
  Stream<List<LiveSession>> watchLiveSessions();

  /// Погасить сеанс, выписанный на этот терминал. `true` — было что гасить,
  /// `false` — терминал уже без живого сеанса (истёк сам, или его уже
  /// отозвали); оба исхода — не ошибка вызова, та же логика, что у
  /// `AuthRepository.logout`: «выход из погасшего сеанса — это тот же
  /// выход».
  Future<bool> revokeSession(int terminalId);
}
