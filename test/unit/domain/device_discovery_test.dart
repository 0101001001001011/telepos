import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/device/device_discovery_local.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/sysd/sysd_client.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/hardware/printer/bluetooth_printer.dart' as bt show BluetoothDevice;
import 'package:telepos/hardware/printer/linux_printer.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

/// A [SysdClient] whose `bluetoothScan` is swapped for a value a test
/// controls, so a test never touches the real Unix socket
/// (`/run/telepos/sysd.sock`) that only exists on the appliance. `SysdClient`
/// does no I/O in its constructor, so overriding the one method this
/// contract actually calls is safe.
class _FakeSysdClient extends SysdClient {
  _FakeSysdClient({
    this.bluetoothDevices = const [],
    this.failBluetooth = false,
    this.delay,
  });

  final List<BluetoothDevice> bluetoothDevices;
  final bool failBluetooth;
  final Duration? delay;

  @override
  Future<List<BluetoothDevice>> bluetoothScan() async {
    if (delay != null) await Future<void>.delayed(delay!);
    if (failBluetooth) {
      throw SysdException('sysd unreachable (test double)');
    }
    return bluetoothDevices;
  }
}

/// Seed data shared across tests — qa-depth "правило нуля": volume enough to
/// distinguish "the right ones for this class" from "everything", plus a
/// Cyrillic title.
///
/// Five serial ports (not one), so a test can tell "returned these five" from
/// "got lucky with one".
const _seedSerialPorts = <String>[
  'COM3',
  'COM4',
  'COM7',
  '/dev/ttyUSB0',
  '/dev/ttyACM1',
];

/// Three paired Bluetooth devices, one with a Cyrillic name — device names
/// come from the paired device itself, and Kazakh/Russian Cyrillic in a
/// device's advertised name is exactly the case that catches a lossy
/// encoding round-trip.
final _seedBluetoothDevices = <BluetoothDevice>[
  const BluetoothDevice(address: '00:11:22:33:44:55', name: 'Весы-Промо №2'),
  const BluetoothDevice(address: '00:11:22:33:44:66', name: 'BT Printer 58'),
  const BluetoothDevice(address: '00:11:22:33:44:77', name: 'Kaspi Reader'),
];

const _seedUsbInfos = <LinuxPrinterInfo>[
  LinuxPrinterInfo(devicePath: '/dev/usb/lp0', description: 'USB receipt printer (/dev/usb/lp0)'),
  LinuxPrinterInfo(devicePath: '/dev/usb/lp1', description: 'USB receipt printer (/dev/usb/lp1)'),
];

const _seedNetworkInfos = <WifiPrinterInfo>[
  WifiPrinterInfo(host: '192.168.1.50', port: 9100),
  WifiPrinterInfo(host: '192.168.1.77', port: 9100),
];

DeviceDiscoveryLocal _discoveryWith({
  List<String> serialPorts = const [],
  List<LinuxPrinterInfo> usbInfos = const [],
  List<BluetoothDevice> bluetoothDevices = const [],
  bool failBluetooth = false,
  bool throwOnSerialPorts = false,
  Duration? bluetoothDelay,
  List<bt.BluetoothDevice> bondedDevices = const [],
  String? subnet = '192.168.1',
  bool subnetThrows = false,
  List<WifiPrinterInfo> networkInfos = const [],
  Duration? networkDelay,
}) => DeviceDiscoveryLocal(
  catalog: BuiltinDeviceProfileCatalog(),
  sysd: _FakeSysdClient(
    bluetoothDevices: bluetoothDevices,
    failBluetooth: failBluetooth,
    delay: bluetoothDelay,
  ),
  availableSerialPorts: () {
    if (throwOnSerialPorts) {
      throw StateError('native serial library not available (test double)');
    }
    return serialPorts;
  },
  scanUsbDevicePaths: () async => usbInfos,
  bondedBluetoothDevices: () async => bondedDevices,
  deviceSubnet: () async {
    if (subnetThrows) throw StateError('no network interface (test double)');
    return subnet;
  },
  scanNetwork: (_) async* {
    if (networkDelay != null) await Future<void>.delayed(networkDelay);
    for (final info in networkInfos) {
      yield info;
    }
  },
  networkScanBudget: const Duration(milliseconds: 200),
  bluetoothTimeout: const Duration(milliseconds: 500),
);

void main() {
  final catalog = BuiltinDeviceProfileCatalog();

  test(
    'обнаружение для класса возвращает кандидатов с ключами параметров, '
    'которые объявляют профили этого класса',
    () async {
      final discovery = _discoveryWith(serialPorts: _seedSerialPorts);
      final result = await discovery.find(DeviceClass.scale);

      expect(result.candidates, isNotEmpty);
      expect(result.failedSources, isEmpty);
      final declaredKeys = <String>{
        for (final profile in catalog.forClass(DeviceClass.scale))
          for (final param in profile.connectionParams) param.key,
      };
      for (final candidate in result.candidates) {
        expect(
          declaredKeys.containsAll(candidate.parameters.keys),
          isTrue,
          reason:
              'ключ параметра кандидата ${candidate.parameters.keys} должен '
              'входить в объявленные ключи $declaredKeys — иначе экран '
              'настроек не сможет ими воспользоваться',
        );
      }
      // Weights are reached over a COM port (scale.cas.pd2, scale.cas.er-plus)
      // — every seeded port must show up as a candidate value.
      expect(
        result.candidates.map((c) => c.parameters['comPort']).toSet(),
        _seedSerialPorts.toSet(),
      );
    },
  );

  test(
    'источник, ничего не нашедший, — пустой список, а не ошибка и не '
    'выдуманный кандидат, и это не отражается как отказ',
    () async {
      final discovery = _discoveryWith(serialPorts: const []);
      final result = await discovery.find(DeviceClass.scale);
      expect(result.candidates, isEmpty);
      expect(
        result.failedSources,
        isEmpty,
        reason: 'a clean empty result from a successful search is not a failure',
      );
    },
  );

  test(
    'источники, не относящиеся к ключам класса, не просачиваются в его '
    'результат — доказывает фильтрацию по классу, а не "источник просто пуст"',
    () async {
      // scale.* profiles declare only comPort. USB, Bluetooth and network
      // data below are exactly the "records that must not appear" qa-depth
      // asks for.
      final discovery = _discoveryWith(
        serialPorts: _seedSerialPorts,
        usbInfos: _seedUsbInfos,
        bluetoothDevices: _seedBluetoothDevices,
        bondedDevices: const [bt.BluetoothDevice(address: 'AA:BB', name: 'Bonded')],
        networkInfos: _seedNetworkInfos,
      );
      final result = await discovery.find(DeviceClass.scale);

      expect(
        result.candidates.every((c) => c.source == DeviceDiscoverySource.serialPort),
        isTrue,
        reason:
            'scale profiles declare only comPort; usb/bluetooth/network '
            'candidates must not leak in even though those sources have data',
      );
      expect(result.candidates.length, _seedSerialPorts.length);
    },
  );

  test(
    'источник, недоступный на этой платформе, пропускается без падения '
    'всего поиска, и это отражается в failedSources',
    () async {
      // receiptPrinter reaches comPort/devicePath (printer.escpos.serial /
      // .usb), macAddress (printer.escpos.bluetooth) and ipAddress/port
      // (the two networked profiles). Bluetooth is made to fail the way it
      // genuinely does off the appliance (SysdException from an unreachable
      // socket); the search must still return what the other sources found,
      // and must say which source could not be searched.
      final discovery = _discoveryWith(
        serialPorts: _seedSerialPorts,
        usbInfos: _seedUsbInfos,
        failBluetooth: true,
      );
      final result = await discovery.find(DeviceClass.receiptPrinter);

      expect(result.candidates, isNotEmpty);
      expect(
        result.candidates.any((c) => c.source == DeviceDiscoverySource.bluetooth),
        isFalse,
        reason: 'bluetooth source failed and must contribute nothing',
      );
      expect(
        result.candidates.any((c) => c.source == DeviceDiscoverySource.serialPort),
        isTrue,
      );
      expect(
        result.failedSources,
        {DeviceDiscoverySource.bluetooth},
        reason:
            'exactly the failed source is named — not empty (that would '
            'hide the failure) and not every source (network/usb succeeded)',
      );
    },
  );

  test(
    'источник последовательных портов, недоступный на этой платформе, тоже '
    'помечается как отказавший, не роняя остальной поиск',
    () async {
      final discovery = _discoveryWith(
        throwOnSerialPorts: true,
        bluetoothDevices: _seedBluetoothDevices,
      );
      final result = await discovery.find(DeviceClass.receiptPrinter);

      expect(
        result.candidates.any((c) => c.source == DeviceDiscoverySource.serialPort),
        isFalse,
      );
      expect(
        result.candidates.any((c) => c.source == DeviceDiscoverySource.bluetooth),
        isTrue,
        reason: 'the failing serial-port source must not take bluetooth down with it',
      );
      expect(result.failedSources, contains(DeviceDiscoverySource.serialPort));
    },
  );

  test('кандидаты из двух разных источников различимы по source', () async {
    final discovery = _discoveryWith(
      serialPorts: _seedSerialPorts,
      bluetoothDevices: _seedBluetoothDevices,
    );
    final result = await discovery.find(DeviceClass.receiptPrinter);

    final sources = result.candidates.map((c) => c.source).toSet();
    expect(
      sources,
      containsAll(<DeviceDiscoverySource>[
        DeviceDiscoverySource.serialPort,
        DeviceDiscoverySource.bluetooth,
      ]),
    );

    final serialCandidate = result.candidates.firstWhere(
      (c) => c.source == DeviceDiscoverySource.serialPort,
    );
    final bluetoothCandidate = result.candidates.firstWhere(
      (c) => c.source == DeviceDiscoverySource.bluetooth,
    );
    // receiptPrinter declares both comPort (printer.escpos.serial) and
    // devicePath (printer.escpos.usb) — one physical port satisfies either,
    // per fix round 1 finding F3.
    expect(serialCandidate.parameters.keys, containsAll(['comPort', 'devicePath']));
    expect(bluetoothCandidate.parameters.keys, ['macAddress']);
  });

  test(
    'кириллица в человекочитаемом названии кандидата не повреждается',
    () async {
      final discovery = _discoveryWith(bluetoothDevices: _seedBluetoothDevices);
      final result = await discovery.find(DeviceClass.scanner);

      final withCyrillicName = result.candidates.firstWhere(
        (c) => c.parameters['macAddress'] == '00:11:22:33:44:55',
      );
      expect(withCyrillicName.title, 'Весы-Промо №2');
      expect(withCyrillicName.title.runes, contains('В'.runes.first));
    },
  );

  test(
    'название Bluetooth-кандидата возвращается к адресу, если у устройства '
    'нет имени',
    () async {
      final discovery = _discoveryWith(
        bluetoothDevices: const [BluetoothDevice(address: '00:AA:BB:CC:DD:EE', name: '')],
      );
      final result = await discovery.find(DeviceClass.scanner);
      final candidate = result.candidates.singleWhere(
        (c) => c.source == DeviceDiscoverySource.bluetooth,
      );
      expect(candidate.title, '00:AA:BB:CC:DD:EE');
    },
  );

  test(
    'USB-кандидат несёт devicePath и человекочитаемое описание из '
    'LinuxPrinterScanner, когда он не дублирует уже известный порт',
    () async {
      final discovery = _discoveryWith(usbInfos: _seedUsbInfos);
      final result = await discovery.find(DeviceClass.receiptPrinter);
      final usbCandidates = result.candidates
          .where((c) => c.source == DeviceDiscoverySource.usb)
          .toList();

      expect(usbCandidates.length, _seedUsbInfos.length);
      expect(
        usbCandidates.map((c) => c.parameters['devicePath']).toSet(),
        _seedUsbInfos.map((i) => i.devicePath).toSet(),
      );
      expect(
        usbCandidates.map((c) => c.title).toSet(),
        _seedUsbInfos.map((i) => i.description).toSet(),
      );
    },
  );

  test(
    'сканер: последовательный и Bluetooth профили дают candidates под '
    'своими ключами одновременно',
    () async {
      final discovery = _discoveryWith(
        serialPorts: _seedSerialPorts,
        bluetoothDevices: _seedBluetoothDevices,
      );
      final result = await discovery.find(DeviceClass.scanner);

      expect(
        result.candidates
            .where((c) => c.source == DeviceDiscoverySource.serialPort)
            .length,
        _seedSerialPorts.length,
      );
      expect(
        result.candidates.where((c) => c.source == DeviceDiscoverySource.bluetooth).length,
        _seedBluetoothDevices.length,
      );
      // scanner.usb.hid declares no connection parameters at all — nothing
      // from this contract's sources should invent a value for it, and none
      // of the returned candidates carry an unrecognised key.
      final declaredKeys = <String>{
        for (final profile in catalog.forClass(DeviceClass.scanner))
          for (final param in profile.connectionParams) param.key,
      };
      for (final candidate in result.candidates) {
        expect(declaredKeys.containsAll(candidate.parameters.keys), isTrue);
      }
    },
  );

  // Fix round 1 — findings F1, F2, F3, F4. Each test below would fail
  // against the pre-fix-round-1 implementation; see task-1-report.md for
  // the mutation that confirms each one specifically.

  group('F1 — обнаружение по сети (WifiPrinterScanner)', () {
    test(
      'принтер этикеток находит кандидатов по сети — раньше не находил ни '
      'при каких обстоятельствах, потому что источника не было вовсе',
      () async {
        final discovery = _discoveryWith(networkInfos: _seedNetworkInfos);
        final result = await discovery.find(DeviceClass.labelPrinter);

        final networkCandidates = result.candidates
            .where((c) => c.source == DeviceDiscoverySource.network)
            .toList();
        expect(networkCandidates.length, _seedNetworkInfos.length);
        expect(
          networkCandidates.map((c) => c.parameters['ipAddress']).toSet(),
          _seedNetworkInfos.map((i) => i.host).toSet(),
        );
        // labelPrinter profiles declare port as optional, but they do
        // declare it — every network candidate must carry a value for it.
        expect(
          networkCandidates.map((c) => c.parameters['port']).toSet(),
          _seedNetworkInfos.map((i) => i.port.toString()).toSet(),
        );
        final declaredKeys = <String>{
          for (final profile in catalog.forClass(DeviceClass.labelPrinter))
            for (final param in profile.connectionParams) param.key,
        };
        for (final candidate in networkCandidates) {
          expect(declaredKeys.containsAll(candidate.parameters.keys), isTrue);
        }
      },
    );

    test(
      'не найдя подсети, поиск по сети сообщает об отказе, а не '
      'о пустом, но успешном результате',
      () async {
        final discovery = _discoveryWith(subnet: null);
        final result = await discovery.find(DeviceClass.labelPrinter);
        expect(
          result.candidates.any((c) => c.source == DeviceDiscoverySource.network),
          isFalse,
        );
        expect(result.failedSources, contains(DeviceDiscoverySource.network));
      },
    );

    test(
      'подсеть найдена, сканирование ничего не нашло — это пустой результат, '
      'а не отказ',
      () async {
        final discovery = _discoveryWith(networkInfos: const []);
        final result = await discovery.find(DeviceClass.labelPrinter);
        expect(
          result.candidates.where((c) => c.source == DeviceDiscoverySource.network),
          isEmpty,
        );
        expect(result.failedSources, isNot(contains(DeviceDiscoverySource.network)));
      },
    );
  });

  group(
    'F2 — Bluetooth со стороны хоста (BluetoothPrinterScanner), не только '
    'приставки (SysdClient)',
    () {
      test(
        'sysd недоступен (не приставка) — сопряжённые устройства хоста всё '
        'равно находятся; раньше поиск в этом случае всегда был пуст',
        () async {
          final discovery = _discoveryWith(
            failBluetooth: true,
            bondedDevices: const [
              bt.BluetoothDevice(address: 'AA:BB:CC:DD:EE:01', name: 'Paired Printer'),
            ],
          );
          final result = await discovery.find(DeviceClass.receiptPrinter);

          final bluetoothCandidates = result.candidates
              .where((c) => c.source == DeviceDiscoverySource.bluetooth)
              .toList();
          expect(bluetoothCandidates, isNotEmpty);
          expect(
            bluetoothCandidates.single.parameters['macAddress'],
            'AA:BB:CC:DD:EE:01',
          );
          // sysd itself really did fail (this is the on-appliance-
          // reachability signal F4 exists for) — that fact is not erased
          // just because the other channel produced real candidates.
          expect(result.failedSources, contains(DeviceDiscoverySource.bluetooth));
        },
      );

      test(
        'устройство, сопряжённое и видимое приставке, и известное хосту, '
        'учитывается один раз',
        () async {
          final discovery = _discoveryWith(
            bluetoothDevices: const [
              BluetoothDevice(address: 'AA:BB:CC:DD:EE:02', name: 'Same Printer'),
            ],
            bondedDevices: const [
              bt.BluetoothDevice(address: 'AA:BB:CC:DD:EE:02', name: 'Same Printer'),
            ],
          );
          final result = await discovery.find(DeviceClass.receiptPrinter);
          final matching = result.candidates.where(
            (c) => c.parameters['macAddress'] == 'AA:BB:CC:DD:EE:02',
          );
          expect(matching.length, 1);
        },
      );
    },
  );

  group('F3 — физический COM-порт не дублируется между serialPort и usb', () {
    test(
      'порт, который LinuxPrinterScanner тоже перечисляет как USB-путь, '
      'даёт ровно одного кандидата, а не двух',
      () async {
        final discovery = _discoveryWith(
          serialPorts: const ['COM3', 'COM5'],
          usbInfos: const [
            // Simulates exactly what LinuxPrinterScanner.scanDevices()
            // produces on Windows: the same COM port, re-derived from the
            // same SerialPort.availablePorts call.
            LinuxPrinterInfo(devicePath: 'COM3', description: 'COM3'),
            // A genuinely new raw USB node — not a serial port at all.
            LinuxPrinterInfo(
              devicePath: '/dev/usb/lp0',
              description: 'USB receipt printer (/dev/usb/lp0)',
            ),
          ],
        );
        final result = await discovery.find(DeviceClass.receiptPrinter);

        final com3Candidates = result.candidates.where(
          (c) => c.parameters['devicePath'] == 'COM3' || c.parameters['comPort'] == 'COM3',
        );
        expect(
          com3Candidates.length,
          1,
          reason: 'COM3 must appear once, not once per source that can see it',
        );
        expect(com3Candidates.single.source, DeviceDiscoverySource.serialPort);
        expect(
          com3Candidates.single.parameters,
          {'comPort': 'COM3', 'devicePath': 'COM3'},
          reason:
              "one physical port can satisfy either printer.escpos.serial's "
              "comPort or printer.escpos.usb's devicePath",
        );

        final rawUsbCandidates = result.candidates.where(
          (c) => c.source == DeviceDiscoverySource.usb,
        );
        expect(rawUsbCandidates.length, 1);
        expect(rawUsbCandidates.single.parameters['devicePath'], '/dev/usb/lp0');

        // Total: COM3, COM5 (serialPort) + the one genuine raw node (usb).
        expect(result.candidates.length, 3);
      },
    );

    test(
      'на платформе без узлов /dev/usb (моделируется пустым '
      'LinuxPrinterScanner) источник usb искренне пуст, а не дублирует порты',
      () async {
        final discovery = _discoveryWith(
          serialPorts: const ['COM3'],
          usbInfos: const [LinuxPrinterInfo(devicePath: 'COM3', description: 'COM3')],
        );
        final result = await discovery.find(DeviceClass.receiptPrinter);
        expect(
          result.candidates.where((c) => c.source == DeviceDiscoverySource.usb),
          isEmpty,
          reason: 'the only "USB" entry duplicated a known COM port and must be dropped',
        );
      },
    );
  });

  test(
    'F5 — источники выполняются параллельно, поэтому общее время не '
    'складывается из времени каждого источника',
    () async {
      final discovery = _discoveryWith(
        serialPorts: _seedSerialPorts,
        bluetoothDelay: const Duration(milliseconds: 150),
        bluetoothDevices: _seedBluetoothDevices,
        networkDelay: const Duration(milliseconds: 150),
        networkInfos: _seedNetworkInfos,
      );
      final stopwatch = Stopwatch()..start();
      final result = await discovery.find(DeviceClass.receiptPrinter);
      stopwatch.stop();

      expect(result.candidates, isNotEmpty);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(250),
        reason:
            'bluetooth (150ms) and network (150ms) must overlap — run '
            'sequentially they would take at least 300ms',
      );
    },
  );

  group(
    'discoverableSourcesFor (task 4 fix round 1, finding 2 — the single '
    'definition find() gates on and HttpDeviceDiscovery reuses on failure)',
    () {
      final catalog = BuiltinDeviceProfileCatalog();

      test('scale: comPort-only profiles map to serialPort alone', () {
        expect(
          discoverableSourcesFor(DeviceClass.scale, catalog),
          {DeviceDiscoverySource.serialPort},
        );
      });

      test(
        'scanner: comPort + macAddress profiles map to serialPort and '
        'bluetooth — not usb, not network, even though usb.hid and camera '
        'profiles also exist on this class',
        () {
          expect(
            discoverableSourcesFor(DeviceClass.scanner, catalog),
            {DeviceDiscoverySource.serialPort, DeviceDiscoverySource.bluetooth},
          );
        },
      );

      test('paymentTerminal: ipAddress-only profile maps to network alone', () {
        expect(
          discoverableSourcesFor(DeviceClass.paymentTerminal, catalog),
          {DeviceDiscoverySource.network},
        );
      });

      test(
        'receiptPrinter: comPort, devicePath, macAddress and ipAddress '
        'profiles all exist, so all four sources apply',
        () {
          expect(
            discoverableSourcesFor(DeviceClass.receiptPrinter, catalog),
            {
              DeviceDiscoverySource.serialPort,
              DeviceDiscoverySource.usb,
              DeviceDiscoverySource.bluetooth,
              DeviceDiscoverySource.network,
            },
          );
        },
      );

      test(
        'the sources DeviceDiscoveryLocal.find actually searches for a class '
        'match exactly what this function names as applicable for it — the '
        'live cross-check that keeps the two from drifting apart, since '
        'find() gates on this same function rather than a separately '
        'hand-written copy',
        () async {
          final applicable = discoverableSourcesFor(
            DeviceClass.receiptPrinter,
            catalog,
          );
          final discovery = _discoveryWith(
            serialPorts: _seedSerialPorts,
            usbInfos: _seedUsbInfos,
            bluetoothDevices: _seedBluetoothDevices,
            networkInfos: _seedNetworkInfos,
          );

          final result = await discovery.find(DeviceClass.receiptPrinter);

          expect(
            result.candidates.map((c) => c.source).toSet(),
            applicable,
            reason: 'every source discoverableSourcesFor names as applicable '
                'must actually have been searched, and no other source '
                'searched',
          );
        },
      );
    },
  );
}
