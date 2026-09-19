/// Пустые реализации шести обязательных доводов [TillOperations].
///
/// # Зачем отдельный файл
///
/// `TillOperations` требует шесть узлов кассы даже тогда, когда проба
/// спрашивает **одну** операцию, которая ни одного из них не касается.
/// Копия этих шести классов уже жила в `pay_operations_test.dart`; вторая
/// копия рядом означала бы, что следующий обязательный довод придётся
/// дописывать в двух местах, и одно из них однажды забудут.
///
/// Здесь **ничего не подделано по существу**: каждый метод возвращает
/// пустоту или бросает `UnimplementedError`. Проба, которая случайно
/// заденет один из этих узлов, упадёт с именем метода, а не пройдёт по
/// выдуманному ответу.
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

class BareBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class BareSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class BareTerminals implements TerminalRepository {
  static const int selfId = 7;

  @override
  Future<List<domain.Terminal>> list() async => const [];

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield const [];
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
  }) async => (terminal: await self(), secret: 'секрет');

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) => throw UnimplementedError('resume');

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {}

  @override
  Future<void> delete(int terminalId) async {}

  @override
  Future<domain.Terminal> self() async => const domain.Terminal(
    id: selfId,
    name: 'Касса',
    pointMode: domain.PointMode.cashier,
  );
}

class BareBindings implements DeviceBindingRepository {
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
