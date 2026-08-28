import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_user.dart';

/// Вход в кассу — одинаково для десктопа и браузера.
///
/// Реализаций две, а проверка PIN — одна: `LocalAuthRepository` живёт на кассе
/// и читает базу, `WtAuthRepository` в браузере зовёт её же по проводу.
/// Обработчик провода не содержит логики входа, он только вызывает первую.
abstract interface class AuthRepository {
  /// Кассиры, которых показывает экран входа. **Подписка:** заведённый на
  /// кассе пользователь появляется на терминале в момент заведения.
  Stream<List<AuthUser>> watchUsers();

  /// Проверить PIN и выписать сеанс.
  Future<AuthOutcome> login(AuthAttempt attempt);

  /// Погасить сеанс. Молчит, если сеанса уже нет: выход из погасшего сеанса —
  /// это тот же выход.
  Future<void> logout(String token);

  /// Следить за сеансом. `null` означает, что сеанс погас — по выходу, по
  /// бездействию или потому, что кассу перезапустили.
  Stream<AuthSession?> watchSession(String token);
}
