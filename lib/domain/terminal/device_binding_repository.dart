import 'package:meta/meta.dart';

import 'package:telepos/domain/terminal/device_binding.dart';

/// Persists and reads back a terminal's [DeviceBinding]s — plan 2, task 4's
/// answer to "how does a settings screen save what the operator chose".
///
/// **Why this is not a method on `TerminalRepository`
/// (`lib/domain/terminal/terminal_repository.dart`):** that contract is
/// implemented on two sides — `LocalTerminalRepository`
/// (`lib/data/terminal/terminal_repository_local.dart`) and
/// `HttpTerminalRepository` (`lib/web/http_terminal_repository.dart`, a file
/// this task must not touch — it belongs to plan 2's task 5, "Настройки
/// устройств по HTTP", running concurrently on this branch). Dart's
/// `implements` never inherits a method body, so adding one abstract method
/// to `TerminalRepository` would break `HttpTerminalRepository`'s
/// compilation immediately, on a file this task does not own.
/// `lib/data/database/tables/terminal_tables.dart`'s own doc comment
/// confirms this is deliberate sequencing, not an oversight: the seven raw
/// `Terminals` columns remain `TerminalRepository.setDevices`'s live storage
/// "до задачи 5" — migrating that contract onto `TerminalDeviceBindings` is
/// task 5's job. This interface is additive instead: a second, narrower
/// contract, implemented only locally for now, that a settings screen can
/// use today without waiting for task 5 or touching any file outside this
/// task's remit.
@immutable
abstract interface class DeviceBindingRepository {
  /// Every binding on [terminalId], enabled or not — a settings screen needs
  /// to redraw a disabled device's last-saved profile and parameters, not
  /// just the ones `hardware_module.dart` would actually register.
  Future<List<DeviceBinding>> forTerminal(int terminalId);

  /// То же самое потоком: устройство появилось или отвалилось — экран
  /// настроек видит это сразу, а не при следующем открытии.
  ///
  /// Почему рядом с [forTerminal], а не вместо него — см. то же обоснование на
  /// `TerminalRepository.watchAll`: `DeviceCheckLocal` читает привязки один раз
  /// внутри проверки устройства, и подписка там была бы `forTerminal`,
  /// написанным руками.
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId);

  /// Saves [binding] for [terminalId], replacing any existing binding of the
  /// same [DeviceBinding.deviceClass] on that terminal — never accumulating
  /// a second row for a class this one-binding-per-class settings UI
  /// manages (docs/system-architecture.md, И30/И31).
  ///
  /// Throws [ArgumentError] — naming the offending profile id, parameter, or
  /// option key, via [DeviceBinding.validateAgainst] — if [binding] does not
  /// validate against this repository's catalog. Nothing is written when
  /// this throws: a partially-valid binding is never saved.
  Future<void> save(int terminalId, DeviceBinding binding);
}
