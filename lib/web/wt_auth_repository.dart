import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Вход — по проводу. Проверки PIN здесь нет ни строки: она на кассе.
///
/// Та же пара, что и у `WtTerminalRepository`: `LocalAuthRepository` на кассе
/// держит всю логику входа и читает базу, а этот класс только переводит
/// доменный вопрос в кадр провода и кадр ответа — обратно в доменный тип.
/// PIN уезжает на кассу открытым текстом обмена; хэшей паролей в обратную
/// сторону не едет — см. `AuthUser`.
class WtAuthRepository implements AuthRepository {
  const WtAuthRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Stream<List<AuthUser>> watchUsers() => _wire.watch(TillOps.authUsers, null);

  @override
  Future<AuthOutcome> login(AuthAttempt attempt) async {
    try {
      return await _wire.ask(TillOps.authLogin, attempt);
    } on WtProtocolError catch (error) {
      // Код `unknown_terminal` — тот самый, которым `TillOperations`
      // отказывает через `WireRefusal` на `terminalId`, не заведённый в базе
      // кассы (`till_operations.dart`); переводится в доменный тип здесь,
      // один раз, а не в каждом вызывающем `login`.
      if (error.code == 'unknown_terminal') {
        throw const UnknownTerminalException();
      }
      rethrow;
    }
  }

  @override
  Future<void> logout(String token) => _wire.ask(TillOps.authLogout, token);

  @override
  Stream<AuthSession?> watchSession(String token) =>
      _wire.watch(TillOps.authSession, token);
}
