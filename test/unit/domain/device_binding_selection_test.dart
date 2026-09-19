import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/device_binding.dart';

/// Tests for [singleEnabledBindingOfClass] — the small, pure, presentation-
/// safe helper extracted while closing final-review finding C4
/// (`print_price_tag_dialog.dart` used to read
/// `ThisPosEntries.labelPrinterConnectionType`/etc. directly, a `lib/data`
/// import from a presentation file, instead of going through
/// `DeviceBindingRepository`, a `lib/domain` contract).
void main() {
  const printer = DeviceBinding(
    deviceClass: DeviceClass.labelPrinter,
    profileId: 'printer.label.zpl.104mm',
    parameters: {'ipAddress': '10.0.0.1'},
  );
  const disabledPrinter = DeviceBinding(
    deviceClass: DeviceClass.labelPrinter,
    profileId: 'printer.label.epl.58mm',
    parameters: {'ipAddress': '10.0.0.2'},
    enabled: false,
  );
  const scanner = DeviceBinding(
    deviceClass: DeviceClass.scanner,
    profileId: 'scanner.usb.hid',
  );

  test('пустой список — ничего не найдено', () {
    expect(singleEnabledBindingOfClass(const [], DeviceClass.labelPrinter), isNull);
  });

  test('ровно одна включённая привязка нужного класса — найдена', () {
    final result = singleEnabledBindingOfClass(
      [scanner, printer],
      DeviceClass.labelPrinter,
    );
    expect(result, isNotNull);
    expect(result!.profileId, 'printer.label.zpl.104mm');
  });

  test('привязка другого класса не возвращается', () {
    expect(
      singleEnabledBindingOfClass([scanner], DeviceClass.labelPrinter),
      isNull,
    );
  });

  test('отключённая привязка — то же самое, что отсутствующая', () {
    expect(
      singleEnabledBindingOfClass([disabledPrinter], DeviceClass.labelPrinter),
      isNull,
      reason: 'enabled: false должно вести себя как "нет привязки"',
    );
  });

  test(
    'две включённые привязки одного класса — отказ выбирать, а не первая '
    'попавшаяся',
    () {
      const secondPrinter = DeviceBinding(
        deviceClass: DeviceClass.labelPrinter,
        profileId: 'printer.label.epl.58mm',
        parameters: {'ipAddress': '10.0.0.3'},
      );
      expect(
        singleEnabledBindingOfClass([printer, secondPrinter], DeviceClass.labelPrinter),
        isNull,
        reason:
            'два реальных принтера этикеток — не угадывание, а видимая '
            'проблема настройки; функция не должна молча вернуть первую',
      );
    },
  );

  test(
    'отключённая привязка не мешает найти единственную включённую того же класса',
    () {
      final result = singleEnabledBindingOfClass(
        [disabledPrinter, printer],
        DeviceClass.labelPrinter,
      );
      expect(result?.profileId, 'printer.label.zpl.104mm');
    },
  );

  // `describesSameDeviceAs` decides whether `DeviceCheckLocal` may borrow the
  // app's live driver instead of building a rival one that would be refused
  // by an endpoint admitting a single client. A false positive reuses a
  // driver pointed at the wrong device -- finding I2 all over again; a false
  // negative opens the second connection the mitigation exists to avoid. So
  // both directions are pinned, field by field.
  group('describesSameDeviceAs', () {
    const base = DeviceBinding(
      deviceClass: DeviceClass.receiptPrinter,
      profileId: 'printer.escpos.80mm',
      parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
      options: {'paperWidthMm': '80'},
    );

    test('a binding describes the same device as itself', () {
      expect(base.describesSameDeviceAs(base), isTrue);
    });

    test('an identical but separately constructed binding matches', () {
      const same = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
        options: {'paperWidthMm': '80'},
      );
      expect(base.describesSameDeviceAs(same), isTrue);
      expect(same.describesSameDeviceAs(base), isTrue);
    });

    test('a changed parameter value is a different device', () {
      const moved = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '192.168.1.99', 'port': '9100'},
        options: {'paperWidthMm': '80'},
      );
      expect(base.describesSameDeviceAs(moved), isFalse);
    });

    test('a dropped parameter is a different device, not a partial match', () {
      const fewer = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '192.168.1.77'},
        options: {'paperWidthMm': '80'},
      );
      expect(base.describesSameDeviceAs(fewer), isFalse);
      expect(
        fewer.describesSameDeviceAs(base),
        isFalse,
        reason:
            'and in the other direction too - a subset must not read as '
            'equal just because every key it does have matches',
      );
    });

    test('a changed profile is a different device', () {
      const otherModel = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.58mm',
        parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
        options: {'paperWidthMm': '80'},
      );
      expect(base.describesSameDeviceAs(otherModel), isFalse);
    });

    test(
      'a changed option is a different device - buildLabelPrinterService '
      'reads options, so ignoring them would leave a driver checking the '
      'label size the operator just changed away from',
      () {
        const narrower = DeviceBinding(
          deviceClass: DeviceClass.receiptPrinter,
          profileId: 'printer.escpos.80mm',
          parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
          options: {'paperWidthMm': '58'},
        );
        expect(base.describesSameDeviceAs(narrower), isFalse);
      },
    );

    test('a different device class never matches', () {
      const asScale = DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
        options: {'paperWidthMm': '80'},
      );
      expect(base.describesSameDeviceAs(asScale), isFalse);
    });

    test(
      'enabled is deliberately ignored: two bindings differing only there '
      'still name the same endpoint',
      () {
        // Задача 33: прежнее имя утверждало ещё и «ни один сборщик драйверов
        // не читает `enabled`» — это неверно (`_registerDisplayService` в
        // `lib/app/di/hardware_module.dart` кладёт `binding.enabled` в
        // конфигурацию дисплея), и проба этого не проверяла вовсе. Имя
        // оставлено при том, что проверяется: тождество адреса устройства.
        const disabled = DeviceBinding(
          deviceClass: DeviceClass.receiptPrinter,
          profileId: 'printer.escpos.80mm',
          parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
          options: {'paperWidthMm': '80'},
          enabled: false,
        );
        expect(base.describesSameDeviceAs(disabled), isTrue);
      },
    );

    test('two bindings with nothing configured at all match', () {
      const bare = DeviceBinding(
        deviceClass: DeviceClass.cashDrawer,
        profileId: 'drawer.rj11.via-printer',
      );
      const alsoBare = DeviceBinding(
        deviceClass: DeviceClass.cashDrawer,
        profileId: 'drawer.rj11.via-printer',
      );
      expect(bare.describesSameDeviceAs(alsoBare), isTrue);
    });
  });
}
