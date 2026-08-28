import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// [SessionAdmin] по проводу — задача «второй порядок» закрытия долга
/// безопасности (2026-08-22), пункт 6.
///
/// # Единственный вызывающий двух операций провода стал вторым
///
/// `TillOps.authSessions`/`TillOps.authSessionRevoke` заведены задачей 19 с
/// готовым обработчиком на кассе (`till_operations.dart`), но до этой правки
/// их звал только настольный экран, и тот — в обход провода: `SessionsScreen`
/// достаёт `SessionRegistry` напрямую через `GetIt` (тот же процесс кассы,
/// `sessions_controller.dart`). У самих операций провода вызывающего в `lib/`
/// не было вовсе — только `test/manual/wt_lock_probe.dart` и тесты. Живая
/// проверка это подтвердила: отозвать сеанс из браузера было нечем.
///
/// Этот класс — тот же приём, что `WtTerminalRepository`/
/// `WtDeviceBindingRepository`: домену (`SessionAdmin`) всё равно, кто на
/// другом конце — касса напрямую (`SessionRegistry`, десктоп) или касса по
/// проводу (этот класс, браузер). `sessions_controller.dart` после этой
/// правки читает `SessionAdmin` через `GetIt`, не `SessionRegistry` — тем
/// самым он перестаёт быть файлом, которому браузерная сборка не может
/// достаться: `lib/backend/` запрещён из `lib/presentation/` тестом
/// `test/architecture/layering_test.dart` (`forbiddenFromUi`).
class WtSessionAdminRepository implements SessionAdmin {
  const WtSessionAdminRepository(this._wire);

  final WtDispatcher _wire;

  @override
  Stream<List<LiveSession>> watchLiveSessions() =>
      _wire.watch(TillOps.authSessions, null);

  @override
  Future<bool> revokeSession(int terminalId) =>
      _wire.ask(TillOps.authSessionRevoke, terminalId);
}
