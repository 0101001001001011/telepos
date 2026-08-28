/// Сторож, пропускающий любую операцию, — для тестов транспортной механики.
///
/// Наборы `till_wire_test.dart` и `till_wire_run_test.dart` проверяют
/// доставку, закрытие и порядок кадров, а не право доступа: за него отвечает
/// `till_wire_guard_test.dart`. У части операций имена придуманы для теста
/// (`demo.echo`, `nope`), у части — настоящие, из каталога (`setup.restore`);
/// этому сторожу всё равно — он пропускает любое имя, не сверяясь ни с каким
/// словарём. `WireGuard` с настоящим словарём отказал бы части операций по
/// умолчанию, и набор проверял бы не то, что заявлено в его же названии.
library;

import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

/// Сеансов не знает ни одного — ровно то, что видит провод, когда терминал
/// вопроса не задавал или сеанс истёк. Публичный, потому что тот же приём
/// нужен и `till_wire_guard_test.dart`: заводить вторую копию незачем.
class NoSession implements SessionLookup {
  const NoSession();

  @override
  AuthSession? sessionFor(String token) => null;
}

class _OpenGuard extends WireGuard {
  const _OpenGuard()
    : super(
        access: const {},
        sessions: const NoSession(),
        isTillConfigured: _never,
        selfTerminalId: _noSelf,
      );

  static Future<bool> _never() async => false;
  static Future<int?> _noSelf() async => null;

  @override
  Future<WireVerdict> check(
    String op,
    Map<String, Object?> body,
    String? token,
  ) async => const WireAllowed(null);
}

/// Один и тот же пропускающий сторож на оба набора — заводить второй незачем.
const openGuard = _OpenGuard();
