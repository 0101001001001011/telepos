import 'package:meta/meta.dart';

/// Попытка входа: что уезжает на кассу.
///
/// [userId] может быть `null` — это walk-up, когда человек набрал PIN, никого
/// не выбрав. Разрешён он или нет, решает **касса** по настройке точки, а не
/// экран: настройка живёт там же, где база, и второй её копии в браузере быть
/// не должно.
///
/// [terminalId] едет всегда: право считается у пары «кто» и «откуда»
/// (docs/system-architecture.md, раздел 11), и вход без «откуда» посчитать
/// нечем.
///
/// [sessionKey] — ключ справедливости для [Pbkdf2Gate] (правка А волны
/// закрытия долга безопасности, 2026-08-22): составной `sessionId`
/// QUIC-сессии, приславшей эту попытку (`WireHandler`'s `sessionId`,
/// `TillOperations.authLogin`), а не сырой `userId` — нападающий выбирает
/// `userId` жертвы свободно, а сессий у него ровно столько, сколько он смог
/// завести. `null` — десктопный вызов в обход провода
/// (`LocalAuthRepository.login` зовётся напрямую), где сессии нет вовсе;
/// все такие вызовы делят одну общую очередь, что при единственном
/// десктопном источнике попыток ничего не меняет.
@immutable
class AuthAttempt {
  const AuthAttempt({
    required this.pin,
    required this.terminalId,
    this.userId,
    this.sessionKey,
  });

  final String pin;

  final int terminalId;

  final int? userId;

  final int? sessionKey;
}
