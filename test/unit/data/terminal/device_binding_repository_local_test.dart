import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/device_binding.dart';

/// Plan 2, task 4: proves the settings screens' save path — a real drift
/// database, the real shipped catalog (`BuiltinDeviceProfileCatalog`, which
/// carries several profiles per class — scanner alone has four — so
/// "resolved the right profile" is distinguishable from "resolved
/// something", per the qa-depth skill's rule of zero).
void main() {
  late AppDatabase db;
  late LocalDeviceBindingRepository repo;
  late int terminalId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog());
    final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    terminalId = terminal.id;
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'choosing a profile and filling its required parameters saves a '
    'binding that the repository returns afterwards',
    () async {
      final binding = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.80mm',
        parameters: const {'ipAddress': '10.0.0.5'},
        options: const {'paperWidthMm': '80'},
      );

      await repo.save(terminalId, binding);

      final saved = await repo.forTerminal(terminalId);
      expect(saved, hasLength(1));
      expect(saved.single.deviceClass, DeviceClass.receiptPrinter);
      expect(saved.single.profileId, 'printer.escpos.80mm');
      expect(saved.single.parameters['ipAddress'], '10.0.0.5');
      expect(saved.single.options['paperWidthMm'], '80');
      expect(saved.single.enabled, isTrue);
    },
  );

  test(
    'leaving a required parameter empty refuses to save and names it, '
    'rather than saving a partial binding',
    () async {
      final binding = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.80mm',
        parameters: const {}, // missing required ipAddress
      );

      await expectLater(
        () => repo.save(terminalId, binding),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.invalidValue,
            'value (the missing parameter key)',
            'ipAddress',
          ),
        ),
      );

      final saved = await repo.forTerminal(terminalId);
      expect(
        saved,
        isEmpty,
        reason: 'the invalid binding must not be written at all — not even '
            'partially.',
      );
    },
  );

  test(
    'an option value the profile does not permit refuses to save and '
    'names the value',
    () async {
      final binding = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.58mm-compact', // only supports 58mm
        parameters: const {'ipAddress': '10.0.0.5'},
        options: const {'paperWidthMm': '80'}, // not permitted for this model
      );

      await expectLater(
        () => repo.save(terminalId, binding),
        throwsA(
          isA<ArgumentError>().having((e) => e.invalidValue, 'value', '80'),
        ),
      );

      expect(await repo.forTerminal(terminalId), isEmpty);
    },
  );

  test(
    'switching a terminal\'s profile for a class replaces its binding '
    'rather than accumulating a second one',
    () async {
      await repo.save(
        terminalId,
        DeviceBinding(
          deviceClass: DeviceClass.scale,
          profileId: 'scale.cas.pd2',
          parameters: const {'comPort': 'COM3'},
        ),
      );
      await repo.save(
        terminalId,
        DeviceBinding(
          deviceClass: DeviceClass.scale,
          profileId: 'scale.cas.er-plus',
          parameters: const {'comPort': 'COM4'},
        ),
      );

      final saved = await repo.forTerminal(terminalId);
      final scaleBindings = saved
          .where((b) => b.deviceClass == DeviceClass.scale)
          .toList();
      expect(
        scaleBindings,
        hasLength(1),
        reason: 'must replace, not accumulate a sibling row for the same '
            'class.',
      );
      expect(scaleBindings.single.profileId, 'scale.cas.er-plus');
      expect(scaleBindings.single.parameters['comPort'], 'COM4');
    },
  );

  test(
    'the rendered/resolved profile changes when the chosen profile changes '
    '— proving resolution is not hardcoded to one model',
    () async {
      // Two different scanner profiles declare two different required
      // connection parameters (macAddress vs comPort) — if this repository
      // (or a screen built on it) hardcoded a field list, only one of these
      // two would ever validate.
      await repo.save(
        terminalId,
        DeviceBinding(
          deviceClass: DeviceClass.scanner,
          profileId: 'scanner.bluetooth.hid',
          parameters: const {'macAddress': 'AA:BB:CC:DD:EE:FF'},
        ),
      );
      var saved = await repo.forTerminal(terminalId);
      expect(saved.single.profileId, 'scanner.bluetooth.hid');
      expect(saved.single.parameters, {'macAddress': 'AA:BB:CC:DD:EE:FF'});

      await repo.save(
        terminalId,
        DeviceBinding(
          deviceClass: DeviceClass.scanner,
          profileId: 'scanner.serial',
          parameters: const {'comPort': 'COM7'},
        ),
      );
      saved = await repo.forTerminal(terminalId);
      final scannerBindings = saved
          .where((b) => b.deviceClass == DeviceClass.scanner)
          .toList();
      expect(scannerBindings, hasLength(1));
      expect(scannerBindings.single.profileId, 'scanner.serial');
      expect(scannerBindings.single.parameters, {'comPort': 'COM7'});
    },
  );

  test(
    'bindings of different device classes coexist — saving one class does '
    'not disturb another',
    () async {
      await repo.save(
        terminalId,
        DeviceBinding(
          deviceClass: DeviceClass.scanner,
          profileId: 'scanner.serial',
          parameters: const {'comPort': 'COM5'},
        ),
      );
      await repo.save(
        terminalId,
        DeviceBinding(
          deviceClass: DeviceClass.cashDrawer,
          profileId: 'drawer.rj11.standalone',
          parameters: const {'comPort': 'COM6'},
        ),
      );

      final saved = await repo.forTerminal(terminalId);
      expect(saved, hasLength(2));
      expect(
        saved.any(
          (b) =>
              b.deviceClass == DeviceClass.scanner &&
              b.profileId == 'scanner.serial',
        ),
        isTrue,
      );
      expect(
        saved.any(
          (b) =>
              b.deviceClass == DeviceClass.cashDrawer &&
              b.profileId == 'drawer.rj11.standalone',
        ),
        isTrue,
      );
    },
  );

  test(
    // Задача 33: имя говорило «экран настроек обязан его перерисовать» —
    // экран здесь не исполняется. Его читатель —
    // `hardware_settings_screen.dart` (`binding?.enabled`).
    'forTerminal returns a disabled binding too, with its parameters',
    () async {
      await repo.save(
        terminalId,
        DeviceBinding(
          deviceClass: DeviceClass.paymentTerminal,
          profileId: 'payment.kaspi.pos',
          parameters: const {'ipAddress': '192.168.1.50', 'port': '8888'},
          enabled: false,
        ),
      );

      final saved = await repo.forTerminal(terminalId);
      expect(saved, hasLength(1));
      expect(saved.single.enabled, isFalse);
      expect(saved.single.parameters['ipAddress'], '192.168.1.50');
    },
  );

  test('an unknown profile id refuses to save, naming it', () async {
    final binding = DeviceBinding(
      deviceClass: DeviceClass.scanner,
      profileId: 'scanner.does-not-exist',
    );

    await expectLater(
      () => repo.save(terminalId, binding),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.invalidValue,
          'value',
          'scanner.does-not-exist',
        ),
      ),
    );

    expect(await repo.forTerminal(terminalId), isEmpty);
  });

  test(
    'a binding of the wrong class for its profile refuses to save',
    () async {
      final binding = DeviceBinding(
        deviceClass: DeviceClass.scale, // scanner.serial belongs to scanner
        profileId: 'scanner.serial',
        parameters: const {'comPort': 'COM3'},
      );

      await expectLater(
        () => repo.save(terminalId, binding),
        throwsA(isA<ArgumentError>()),
      );

      expect(await repo.forTerminal(terminalId), isEmpty);
    },
  );
}
