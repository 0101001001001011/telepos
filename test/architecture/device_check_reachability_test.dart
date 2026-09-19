/// Таблица достижимости `DeviceCheckReason` — **не покрытие.**
///
/// Разница решающая. Покрытие говорит «строка исполнялась». Эта таблица
/// требует трёх вещей сразу:
///
/// 1. она покрывает `DeviceCheckReason.values` **целиком** — новое значение
///    красит сторожа в день добавления, а не через полгода;
/// 2. **каждая строка исполняется** настоящим `DeviceCheckLocal.check()`, и
///    исход сверяется с названной причиной. Не «такая причина существует», а
///    «вот сценарий, вот прогон, вот причина»;
/// 3. сценарий, у которого **нет производителя**, объявляется явно и
///    **виден** (`skip` с доводом), а не тихо отсутствует. Тихо отсутствующая
///    строка — это ровно тот способ, которым недостижимая ветка живёт годами.
///
/// # Эмулятор здесь условие, а не украшение
///
/// `connectionFailed` до эмулятора требовал **выдернутого кабеля**: живой
/// проверкой её никто ни разу не проходил. С эмулятором это `emulator.stop()`
/// — одна строка. `deviceRefused` и `unexpectedError` так же: их производит
/// эмулятор спулера отказами `writeFails` и `throws`.
///
/// # Что таблица показывает сразу, числом
///
/// У `scanner`, `customerDisplay` и `paymentTerminal` проверка отвечает
/// `notImplemented` (`device_check_local.dart`). Их **три**, и это число
/// закреплено пробой: после эмулятора Kaspi у `paymentTerminal` может
/// появиться настоящая проверка, и тогда `notImplemented` обязан сжаться до
/// двух. Сжатие станет видно числом, а не рассказом.
///
/// # Чего таблица НЕ доказывает
///
/// Что причина **верна для оператора**: что «нет бумаги» действительно
/// значит нет бумаги на настоящем принтере. Это доказывает живая проверка со
/// стендом, а таблица — только то, что каждая наша ветка исполнима и
/// приводит к тому, что обещает.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/device/composite_device_profile_catalog.dart';
import 'package:telepos/data/device/device_check_local.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/emulators/emulated_device_profile_catalog.dart';
import 'package:telepos/emulators/emulated_spooler_printer.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_service.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

import '../emulators/escpos/emulator.dart';
import '../emulators/escpos/faults.dart';

const int _terminalId = 1;

/// Кто производит эту причину. Строка описания, а не enum: её читает
/// человек, разбирающий отчёт.
const Map<DeviceCheckReason, String> kReachability = {
  DeviceCheckReason.ok:
      'настоящий WifiPrinterManager против эмулятора ESC/POS на сокете',
  DeviceCheckReason.notConfigured: 'терминал без единой привязки',
  DeviceCheckReason.invalidBinding: 'привязка называет профиль, которого нет',
  DeviceCheckReason.driverNotLive:
      'граф зависимостей без строителя драйвера — В МАГАЗИННОЙ СБОРКЕ '
      'НЕДОСТИЖИМО, см. докстринг самой причины',
  DeviceCheckReason.connectionFailed: 'эмулятор ESC/POS погашен (--stop)',
  DeviceCheckReason.deviceRefused: 'эмулятор спулера, отказ «writeFails»',
  DeviceCheckReason.notSupportedOnPlatform:
      'CashDrawerService.dummy() — сборка без поддержки ящика',
  DeviceCheckReason.notImplemented:
      'три класса без проверки: scanner, customerDisplay, paymentTerminal',
  DeviceCheckReason.unexpectedError: 'эмулятор спулера, отказ «throws»',
};

void main() {
  final catalog = CompositeDeviceProfileCatalog([
    BuiltinDeviceProfileCatalog(),
    const EmulatedDeviceProfileCatalog(),
  ]);

  group('Таблица достижимости DeviceCheckReason', () {
    test('покрывает перечисление целиком', () {
      expect(
        kReachability.keys.toSet(),
        DeviceCheckReason.values.toSet(),
        reason:
            'новое значение DeviceCheckReason без сценария — это ветка, про '
            'которую никто не знает, достижима ли она. Допиши строку в '
            'kReachability и пробу к ней',
      );
    });

    test('ok — настоящий сетевой принтер против эмулятора', () async {
      final emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false);
      await emulator.start('127.0.0.1', 0);
      try {
        final outcome = await _check(
          catalog: catalog,
          binding: _binding(DeviceClass.receiptPrinter, 'printer.escpos.80mm', {
            'ipAddress': '127.0.0.1',
            'port': '${emulator.port}',
          }),
          receiptPrinterFor: (b) => WifiPrinterManager(
            host: b.parameters['ipAddress']!,
            port: int.parse(b.parameters['port']!),
          ),
          deviceClass: DeviceClass.receiptPrinter,
        );
        expect(outcome.reason, DeviceCheckReason.ok, reason: outcome.message);
        // Задание оседает у эмулятора по тишине в сокете, а проверка к тому
        // времени уже отключилась. Ждём осадка, а не спим наугад.
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (emulator.jobs.isEmpty && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(emulator.jobs, isNotEmpty, reason: 'чек до принтера не доехал');
      } finally {
        await emulator.stop();
      }
    });

    test('notConfigured — ни одной привязки', () async {
      final outcome = await _check(
        catalog: catalog,
        deviceClass: DeviceClass.receiptPrinter,
      );
      expect(outcome.reason, DeviceCheckReason.notConfigured);
    });

    test('invalidBinding — профиля с таким именем в каталоге нет', () async {
      final outcome = await _check(
        catalog: catalog,
        binding: _binding(DeviceClass.receiptPrinter, 'нет.такого.профиля'),
        receiptPrinterFor: (_) => EmulatedSpoolerPrinter(file: _spoolFile()),
        deviceClass: DeviceClass.receiptPrinter,
      );
      expect(outcome.reason, DeviceCheckReason.invalidBinding);
      expect(outcome.message, isNotEmpty);
    });

    test(
      'driverNotLive — граф без строителя драйвера',
      () async {
        final outcome = await _check(
          catalog: catalog,
          binding: _binding(DeviceClass.receiptPrinter, kEmulatedSpoolerProfileId, {
            kEmulatedFileParam: _spoolFile(),
          }),
          // receiptPrinterFor намеренно не передан.
          deviceClass: DeviceClass.receiptPrinter,
        );
        expect(outcome.reason, DeviceCheckReason.driverNotLive);
      },
      skip:
          'ОБЪЯВЛЕНО ЯВНО: в магазинной сборке эта причина НЕ ПРОИЗВОДИТСЯ — '
          'service_locator.dart передаёт строителя для каждого из четырёх '
          'проверяемых классов безусловно. Проба исполнима только на '
          'графе, собранном иначе, и оставлена видимой пропуском, а не '
          'удалена: тихо отсутствующая строка — это способ, которым '
          'недостижимая ветка живёт годами',
    );

    test('connectionFailed — эмулятор погашен, дозвониться некуда', () async {
      final emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false);
      await emulator.start('127.0.0.1', 0);
      final port = emulator.port;
      // Дверь остановки — и есть способ вызвать отказ связи. До эмулятора
      // эта строка требовала выдернутого кабеля.
      await emulator.stop();

      final outcome = await _check(
        catalog: catalog,
        binding: _binding(DeviceClass.receiptPrinter, 'printer.escpos.80mm', {
          'ipAddress': '127.0.0.1',
          'port': '$port',
        }),
        receiptPrinterFor: (b) => WifiPrinterManager(
          host: b.parameters['ipAddress']!,
          port: int.parse(b.parameters['port']!),
          maxConnectAttempts: 1,
          retryBudget: const Duration(seconds: 2),
          timeout: const Duration(seconds: 2),
        ),
        deviceClass: DeviceClass.receiptPrinter,
      );
      expect(outcome.reason, DeviceCheckReason.connectionFailed);
      expect(
        outcome.message,
        isNotEmpty,
        reason: '«не удалось» без причины — не диагноз',
      );
    });

    test('deviceRefused — прибор достижим и отказал', () async {
      final outcome = await _check(
        catalog: catalog,
        binding: _binding(DeviceClass.receiptPrinter, kEmulatedSpoolerProfileId, {
          kEmulatedFileParam: _spoolFile(),
          kEmulatedRefuseParam: 'writeFails',
        }),
        receiptPrinterFor: (b) => EmulatedSpoolerPrinter(
          file: b.parameters[kEmulatedFileParam]!,
          refuse: b.parameters[kEmulatedRefuseParam] ?? '',
        ),
        deviceClass: DeviceClass.receiptPrinter,
      );
      expect(outcome.reason, DeviceCheckReason.deviceRefused);
      expect(outcome.message, contains('writeFails'));
    });

    test('notSupportedOnPlatform — сборка без поддержки ящика', () async {
      // Ящик «через принтер» требует ВТОРОЙ привязки — самого принтера:
      // без неё это driverNotLive («некуда послать удар»), а не отказ
      // платформы. Разница измерена этой же пробой: первый заход дал
      // driverNotLive, и это верный ответ продукта на неполный стенд.
      final outcome = await _check(
        catalog: catalog,
        bindings: [
          _binding(DeviceClass.cashDrawer, 'drawer.rj11.via-printer'),
          _binding(DeviceClass.receiptPrinter, kEmulatedSpoolerProfileId, {
            kEmulatedFileParam: _spoolFile(),
          }),
        ],
        cashDrawerFor: (_) => CashDrawerService.dummy(),
        receiptPrinterFor: (_) => EmulatedSpoolerPrinter(file: _spoolFile()),
        deviceClass: DeviceClass.cashDrawer,
      );
      expect(outcome.reason, DeviceCheckReason.notSupportedOnPlatform);
    });

    test('unexpectedError — драйвер выбросил исключение', () async {
      final outcome = await _check(
        catalog: catalog,
        binding: _binding(DeviceClass.receiptPrinter, kEmulatedSpoolerProfileId, {
          kEmulatedFileParam: _spoolFile(),
          kEmulatedRefuseParam: 'throws',
        }),
        receiptPrinterFor: (b) => EmulatedSpoolerPrinter(
          file: b.parameters[kEmulatedFileParam]!,
          refuse: b.parameters[kEmulatedRefuseParam] ?? '',
        ),
        deviceClass: DeviceClass.receiptPrinter,
      );
      expect(outcome.reason, DeviceCheckReason.unexpectedError);
      expect(
        outcome.message,
        isNot(contains('throws')),
        reason:
            'наружу уходит безопасный текст, а не внутренности драйвера — '
            'safeErrorText',
      );
    });

    test('notImplemented — и ровно три класса, а не «какие-то»', () async {
      final without = <DeviceClass>[];
      for (final deviceClass in DeviceClass.values) {
        final profile = catalog.forClass(deviceClass).firstOrNull;
        if (profile == null) continue;
        final outcome = await _check(
          catalog: catalog,
          binding: DeviceBinding(
            deviceClass: deviceClass,
            profileId: profile.id,
            parameters: {
              for (final p in profile.connectionParams)
                if (p.isRequired) p.key: _plausible(p.key),
            },
          ),
          receiptPrinterFor: (_) => EmulatedSpoolerPrinter(file: _spoolFile()),
          cashDrawerFor: (_) => CashDrawerService.dummy(),
          deviceClass: deviceClass,
        );
        if (outcome.reason == DeviceCheckReason.notImplemented) {
          without.add(deviceClass);
        }
      }

      // ЧИСЛО, а не рассказ: когда у paymentTerminal появится настоящая
      // проверка через эмулятор Kaspi, эта проба покраснеет и потребует
      // записать сжатие. Так сжатие становится видимым.
      expect(
        without.toSet(),
        {
          DeviceClass.scanner,
          DeviceClass.customerDisplay,
          DeviceClass.paymentTerminal,
        },
        reason:
            'классов без проверки должно быть ровно три. Стало меньше — '
            'впиши сжатие сюда и в докстринг; стало больше — проверка '
            'потерялась',
      );
      expect(without, hasLength(3));
    });
  });
}

/// Один прогон настоящего `DeviceCheckLocal.check()`.
Future<DeviceCheckOutcome> _check({
  required CompositeDeviceProfileCatalog catalog,
  required DeviceClass deviceClass,
  DeviceBinding? binding,
  List<DeviceBinding> bindings = const [],
  DeviceDriverBuilder<dynamic>? receiptPrinterFor,
  DeviceDriverBuilder<CashDrawerService>? cashDrawerFor,
}) async {
  final repository = _Bindings();
  if (binding != null) await repository.save(_terminalId, binding);
  for (final b in bindings) {
    await repository.save(_terminalId, b);
  }
  final check = DeviceCheckLocal(
    bindingRepository: repository,
    catalog: catalog,
    receiptPrinterFor: receiptPrinterFor == null
        ? null
        : (b) => receiptPrinterFor(b),
    cashDrawerFor: cashDrawerFor,
  );
  return check.check(terminalId: _terminalId, deviceClass: deviceClass);
}

DeviceBinding _binding(
  DeviceClass deviceClass,
  String profileId, [
  Map<String, String> parameters = const {},
]) => DeviceBinding(
  deviceClass: deviceClass,
  profileId: profileId,
  parameters: parameters,
);

/// Правдоподобное значение параметра — правило нулевое из `qa-depth`:
/// привязка обязана быть такой, какую система действительно производит.
String _plausible(String key) => switch (key) {
  'ipAddress' => '127.0.0.1',
  'port' => '9100',
  'comPort' => 'COM1',
  'devicePath' => '/dev/usb/lp0',
  'macAddress' => '00:11:22:33:44:55',
  kEmulatedFileParam => _spoolFile(),
  _ => 'x',
};

String _spoolFile() =>
    '${Directory.systemTemp.path}/telepos-emul-spool-'
    '${DateTime.now().microsecondsSinceEpoch}.bin';

class _Bindings implements DeviceBindingRepository {
  final Map<int, List<DeviceBinding>> _byTerminal = {};

  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async =>
      _byTerminal[terminalId] ?? const <DeviceBinding>[];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) =>
      Stream.fromFuture(forTerminal(terminalId));

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {
    final list = _byTerminal.putIfAbsent(terminalId, () => <DeviceBinding>[]);
    list.removeWhere((b) => b.deviceClass == binding.deviceClass);
    list.add(binding);
  }
}
