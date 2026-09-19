/// Подделки обязательных доводов `ApiServer` для проб, которым нужен сам
/// сервер поверх сокета, а не поведение этих договоров.
///
/// Вынесены из `api_server_root_ca_test.dart`, когда второй пробе
/// (`api_server_bundle_cache_test.dart`, задача 42) понадобились те же
/// четыре: копия рядом — ровно тот род повтора, который уже один раз
/// сведён в `noop_auth.dart`.
library;

import 'dart:async';

import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';

class NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class NoopTerminals implements TerminalRepository {
  @override
  Future<List<domain.Terminal>> list() async => const [];

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield const <domain.Terminal>[];
    await Completer<void>().future;
  }

  @override
  Stream<domain.Terminal?> watchSelf() async* {
    yield null;
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
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {}

  @override
  Future<domain.Terminal> self() => throw UnimplementedError();

  @override
  Future<void> delete(int terminalId) async {}
}

class NoopBindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield const <DeviceBinding>[];
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}
