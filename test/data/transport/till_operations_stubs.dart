/// Двойники `TillOperations`' конструктора, не привязанные к одному тесту.
///
/// # Зачем это существует
///
/// `till_wire_safe_error_test.dart` (`_StubBootstrap`, `_StubTerminals`,
/// `_StubBindings`) и `test/web/wt_auth_repository_test.dart`
/// (`_NoopBootstrap`, `_EmptyTerminals`, `_NoopBindings`) собирали один и тот
/// же `TillOperations` под свой сценарий, и три из четырёх двойников,
/// которые он требует, были дословными копиями друг друга под разными
/// именами — найдено разбором волны правок фазы 1 (задача 9). Здесь — по
/// одному определению на каждый.
///
/// `SetupRepository`, четвёртый обязательный аргумент, сюда не входит:
/// `till_wire_safe_error_test.dart` намеренно бросает из него настоящий
/// `SqliteException` — это тело теста, не переиспользуемый двойник, и
/// делить его с [NoopSetupRepository] значило бы либо потерять отказ, либо
/// завести параметр, которым пользуется одна строка. `NoopSetupRepository`
/// здесь — тот самый двойник, который нужен, когда `setup.complete` не
/// является предметом теста.
///
/// Тот же приём, что у `fake_quic_server.dart` и `open_guard.dart` в этом
/// каталоге: общий помощник рядом со сценарием, который его завёл.
library;

import 'dart:async';

import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';

/// Подъём кассы всегда удаётся — сценарии здесь не про запуск.
class NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

/// Финализация настройки всегда удаётся молча — сценарии здесь не про неё.
///
/// Тест, которому нужен отказ `setup.complete`, заводит свой собственный
/// `SetupRepository` (см. докстрок файла) — не этот класс.
class NoopSetupRepository implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

/// Список терминалов пуст всегда: любой `terminalId`, каким бы он ни был, не
/// заведён на этой кассе.
class EmptyTerminalRepository implements TerminalRepository {
  @override
  Future<List<domain.Terminal>> list() async => const [];

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) => throw UnimplementedError();

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) => throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<void> delete(int terminalId) async {}

  @override
  Future<domain.Terminal> self() => throw UnimplementedError();

  @override
  Stream<domain.Terminal?> watchSelf() async* {
    yield null;
    await Completer<void>().future;
  }
}

/// Привязок устройств нет ни у одного терминала.
class NoopDeviceBindingRepository implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}
