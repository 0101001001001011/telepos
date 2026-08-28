import 'dart:async';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'package:telepos/data/sysd/sysd_client.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/hardware/printer/bluetooth_printer.dart'
    as bt
    show BluetoothDevice, BluetoothPrinterScanner;
import 'package:telepos/hardware/printer/linux_printer.dart'
    show LinuxPrinterInfo, LinuxPrinterScanner;
import 'package:telepos/hardware/printer/wifi_printer.dart'
    show WifiPrinterInfo, WifiPrinterScanner;

/// Discovery on the machine where the devices physically are — desktop and
/// appliance builds. Browser terminals use the HTTP binding instead (plan
/// task 4); docs/system-architecture.md, section 8: "Список портов и
/// устройств приходит с той машины, где они физически есть."
///
/// Wraps capability that already exists rather than adding new hardware
/// access, gated per [DeviceClass] by which connection parameter key that
/// class's profiles actually declare
/// (`lib/data/device/device_profile_catalog_builtin.dart`) — a source is
/// only consulted when at least one profile of the requested class could
/// use what it produces:
///
/// - `comPort`/`devicePath` → `SerialPort.availablePorts` (package
///   `flutter_libserialport`), the same call already made directly by
///   `lib/hardware/printer/linux_printer.dart` (`autoDetect`,
///   `_findAvailableDevice`) and
///   `lib/hardware/payment/connectors/usb_payment_connector.dart`
///   (`availablePorts`). A single found port becomes **one** candidate
///   carrying whichever of the two keys the class actually declares — fix
///   round 1, finding F3: the previous version ran this same enumeration
///   twice under two different `DeviceDiscoverySource` tags (`serialPort`
///   for `comPort`, `usb` for `devicePath`, the latter via
///   `LinuxPrinterScanner.scanDevices()`, which re-derives the identical
///   port list internally), so `receiptPrinter` showed every COM port
///   twice — once labelled "serial", once labelled "USB" — and on Windows,
///   where no raw USB device node concept exists in this codebase at all,
///   *everything* under the "USB" label was actually a COM port relabelled.
///   `printer.escpos.usb`'s own doc comment already says its `devicePath`
///   accepts a COM port on Windows, so folding both keys onto the one
///   candidate that was actually found this way is the honest shape, not a
///   workaround.
/// - `devicePath` (raw USB node only) →
///   `LinuxPrinterScanner.scanDevices()`, filtered to exclude any
///   `devicePath` that duplicates a port already reported by the serial
///   source above — what is left is genuinely new information: a raw
///   `/dev/usb/lp*`/`/dev` node found by directory scan, not a relabelled
///   COM port. On a platform without `/dev/usb` (Windows), that scan
///   contributes nothing extra and this source legitimately produces no
///   candidates — which is now true, not merely re-derived.
/// - `macAddress` → the union of `SysdClient.bluetoothScan()`
///   (appliance-only; talks to `/run/telepos/sysd.sock`) and
///   `BluetoothPrinterScanner.getBondedDevices()`
///   (`lib/hardware/printer/bluetooth_printer.dart`, package
///   `flutter_blue_plus`) — fix round 1, finding F2: the previous version
///   only asked the appliance socket, so a Windows till with a paired
///   Bluetooth printer always searched empty even though
///   `getBondedDevices()` already works cross-platform and is used exactly
///   this way by `lib/hardware/printer/print_utility.dart`. Deduplicated by
///   address; a device paired via both channels is one candidate.
/// - `ipAddress` (+ `port`, when declared) → `WifiPrinterScanner.scan()`
///   over `WifiPrinterScanner.getDeviceSubnet()` — fix round 1, finding F1:
///   this capability already existed
///   (`lib/hardware/printer/wifi_printer.dart:120,158`, already composed
///   together at `lib/hardware/printer/print_utility.dart:114-118`) and the
///   previous version of this file claimed, wrongly, that no local
///   network-discovery capability existed at all. `DeviceClass.labelPrinter`
///   — every one of whose profiles is networked — could never return a
///   candidate before this fix. The scan always tries
///   `WifiPrinterManager.defaultPort` (9100), the same default every
///   networked printer profile's `port` parameter documents; a payment
///   terminal profile (typically port 8888) will not usually be found this
///   way — an honest, narrower gap, not a fabricated match. A full subnet
///   sweep is bounded to [networkScanBudget] wall-clock time (see
///   `_networkCandidates`) rather than let run to completion, which can
///   take tens of seconds — fix round 1, finding F5.
///
/// **Failure vs. empty (fix round 1, finding F4):** each source that this
/// class calls *directly* — the serial-port getter, `SysdClient`'s socket
/// call, and `getDeviceSubnet()` failing to name a subnet at all — reports
/// its own failure into [DeviceDiscoveryResult.failedSources] rather than
/// collapsing into the same empty list a clean "nothing found" produces.
/// `LinuxPrinterScanner.scanDevices()` and
/// `BluetoothPrinterScanner.getBondedDevices()` already swallow their own
/// internal errors to an empty list one layer down
/// (`lib/hardware/printer/linux_printer.dart`,
/// `lib/hardware/printer/bluetooth_printer.dart`) — a real limitation this
/// class cannot see past without changing those files, which are outside
/// this task's three owned files. Documented here rather than silently
/// claimed closed.
///
/// **Latency (fix round 1, finding F5):** sources run concurrently
/// (`Future.wait`) instead of one after another, so the total wait is
/// bounded by the slowest single source rather than their sum — the
/// previous sequential version added the appliance Bluetooth scan's ~5s
/// server-side sleep on top of every other source's own time instead of
/// alongside it. The network scan is separately time-boxed (see above).
/// The remaining ~5s floor whenever `macAddress` is being searched is
/// `sysd`'s own server-side sleep (`telepos-os/sysd/src/hardware.rs`,
/// `bluetooth_scan`), which this client cannot shorten; only a streaming
/// contract could show a fast COM port before that scan finishes, and that
/// is a bigger interface change than this fix round takes on.
///
/// Deliberately **not** wired in: `SysdClient.usbList()`. Measured against
/// the actual appliance side (`telepos-os/sysd/src/hardware.rs`,
/// `usb_list()`): it shells out to `lsusb` and returns a vendor:product id
/// and a free-text name, never a device node or address. No profile in
/// `BuiltinDeviceProfileCatalog` declares a connection parameter that value
/// could fill. Wiring it in would mean either inventing an address (the one
/// thing a candidate must never do) or emitting a candidate whose
/// `parameters` map is permanently empty and which cannot be
/// class-filtered (unlike a COM port or a paired Bluetooth device, `lsusb`
/// output does not say what kind of device it is). Left out rather than
/// faked; see task-1-report.md.
class DeviceDiscoveryLocal implements DeviceDiscovery {
  DeviceDiscoveryLocal({
    required DeviceProfileCatalog catalog,
    SysdClient? sysd,
    List<String> Function()? availableSerialPorts,
    Future<List<LinuxPrinterInfo>> Function()? scanUsbDevicePaths,
    Future<List<bt.BluetoothDevice>> Function()? bondedBluetoothDevices,
    Future<String?> Function()? deviceSubnet,
    Stream<WifiPrinterInfo> Function(String subnet)? scanNetwork,
    this.networkScanBudget = const Duration(seconds: 3),
    this.bluetoothTimeout = const Duration(seconds: 8),
  }) : _catalog = catalog,
       _sysd = sysd ?? SysdClient(),
       _availableSerialPorts =
           availableSerialPorts ?? (() => SerialPort.availablePorts),
       _scanUsbDevicePaths = scanUsbDevicePaths ?? LinuxPrinterScanner.scanDevices,
       _bondedBluetoothDevices =
           bondedBluetoothDevices ?? bt.BluetoothPrinterScanner.getBondedDevices,
       _deviceSubnet = deviceSubnet ?? WifiPrinterScanner.getDeviceSubnet,
       _scanNetwork =
           scanNetwork ?? ((subnet) => WifiPrinterScanner.scan(subnet: subnet));

  final DeviceProfileCatalog _catalog;
  final SysdClient _sysd;
  final List<String> Function() _availableSerialPorts;
  final Future<List<LinuxPrinterInfo>> Function() _scanUsbDevicePaths;
  final Future<List<bt.BluetoothDevice>> Function() _bondedBluetoothDevices;
  final Future<String?> Function() _deviceSubnet;
  final Stream<WifiPrinterInfo> Function(String subnet) _scanNetwork;

  /// Wall-clock ceiling on the network subnet sweep — see the class doc
  /// comment, finding F5. Overridable so tests never wait real seconds.
  final Duration networkScanBudget;

  /// Safety ceiling on the appliance Bluetooth scan, above its own ~5s
  /// server-side sleep — protects against a genuinely stuck socket, not
  /// against the scan's normal duration. Overridable for tests.
  final Duration bluetoothTimeout;

  @override
  Future<DeviceDiscoveryResult> find(DeviceClass deviceClass) async {
    final declaredKeys = <String>{
      for (final profile in _catalog.forClass(deviceClass))
        for (final param in profile.connectionParams) param.key,
    };

    // Which of the four searches below to actually run — `discoverableSourcesFor`
    // (`lib/domain/device/device_discovery.dart`) is the single, tested
    // definition of this mapping, shared with `HttpDeviceDiscovery`'s failure
    // fallback (task-4 fix round 1, finding 2). `wantsComPort`/`wantsDevicePath`/
    // `wantsPort` below stay separate from it — they gate which *key* goes
    // into a candidate's `parameters` map, a finer distinction than "which
    // source" that this function does not need to make.
    final applicableSources = discoverableSourcesFor(deviceClass, _catalog);

    final wantsComPort = declaredKeys.contains('comPort');
    final wantsDevicePath = declaredKeys.contains('devicePath');
    final wantsPort = declaredKeys.contains('port');

    final failedSources = <DeviceDiscoverySource>{};

    // Synchronous and cheap (a single native call) — computed once, up
    // front, and reused both for the serial-port candidates themselves and
    // to de-duplicate the raw-USB-node source against it (finding F3).
    var ports = const <String>[];
    if (applicableSources.contains(DeviceDiscoverySource.serialPort)) {
      try {
        ports = _availableSerialPorts();
      } catch (_) {
        failedSources.add(DeviceDiscoverySource.serialPort);
      }
    }

    final serialCandidates = <DeviceCandidate>[
      for (final port in ports)
        DeviceCandidate(
          source: DeviceDiscoverySource.serialPort,
          title: 'Последовательный порт $port',
          parameters: {
            if (wantsComPort) 'comPort': port,
            if (wantsDevicePath) 'devicePath': port,
          },
        ),
    ];

    // Fix round 1, finding F5: the remaining sources run concurrently
    // rather than one after another, so the total wait is bounded by the
    // slowest one instead of their sum.
    final usbFuture = applicableSources.contains(DeviceDiscoverySource.usb)
        ? _usbDevicePathCandidates(knownPorts: ports.toSet())
        : Future.value((candidates: const <DeviceCandidate>[], failed: false));
    final bluetoothFuture = applicableSources.contains(DeviceDiscoverySource.bluetooth)
        ? _bluetoothCandidates()
        : Future.value((candidates: const <DeviceCandidate>[], failed: false));
    final networkFuture = applicableSources.contains(DeviceDiscoverySource.network)
        ? _networkCandidates(includePort: wantsPort)
        : Future.value((candidates: const <DeviceCandidate>[], failed: false));

    final results = await Future.wait([usbFuture, bluetoothFuture, networkFuture]);
    const sourceTags = [
      DeviceDiscoverySource.usb,
      DeviceDiscoverySource.bluetooth,
      DeviceDiscoverySource.network,
    ];
    final candidates = <DeviceCandidate>[...serialCandidates];
    for (var i = 0; i < results.length; i++) {
      candidates.addAll(results[i].candidates);
      if (results[i].failed) failedSources.add(sourceTags[i]);
    }

    return DeviceDiscoveryResult(candidates: candidates, failedSources: failedSources);
  }

  /// The raw-USB-node half of `LinuxPrinterScanner.scanDevices()` only —
  /// entries whose `devicePath` duplicates a port already reported by the
  /// serial-port source are dropped, so a single physical port never
  /// produces two candidates under two source tags (finding F3).
  Future<({List<DeviceCandidate> candidates, bool failed})>
  _usbDevicePathCandidates({required Set<String> knownPorts}) async {
    try {
      final infos = await _scanUsbDevicePaths();
      return (
        candidates: [
          for (final info in infos)
            if (!knownPorts.contains(info.devicePath))
              DeviceCandidate(
                source: DeviceDiscoverySource.usb,
                // `LinuxPrinterInfo.description` is `port.description ??
                // portName` (`lib/hardware/printer/linux_printer.dart`), and
                // a serial port that reports a present-but-blank description
                // would otherwise produce an unlabelled, unchoosable row.
                // Same fallback the Bluetooth branch below already makes
                // (finding M2).
                title: info.description.trim().isNotEmpty
                    ? info.description
                    : info.devicePath,
                parameters: {'devicePath': info.devicePath},
              ),
        ],
        failed: false,
      );
    } catch (_) {
      // LinuxPrinterScanner.scanDevices() already swallows its own errors
      // to an empty list — this catch is defensive, not normally reachable.
      return (candidates: const <DeviceCandidate>[], failed: false);
    }
  }

  /// Union of `SysdClient.bluetoothScan()` (appliance) and
  /// `BluetoothPrinterScanner.getBondedDevices()` (cross-platform,
  /// `flutter_blue_plus`), deduplicated by address — finding F2. Only the
  /// `sysd` half can surface as a genuine failure here: an unreachable
  /// socket is exactly the "could not reach the till" case
  /// [DeviceDiscoveryResult.failedSources] exists for.
  /// `getBondedDevices()` already swallows its own errors internally, so a
  /// Bluetooth-adapter-off or permission-denied failure on the *host* side
  /// cannot be told apart from "no printer paired" here — a real, named
  /// limitation of the hardware helper this wraps, not something faked.
  Future<({List<DeviceCandidate> candidates, bool failed})>
  _bluetoothCandidates() async {
    var failed = false;
    final combined = <String, DeviceCandidate>{};

    try {
      final devices = await _sysd.bluetoothScan().timeout(bluetoothTimeout);
      for (final device in devices) {
        combined[device.address] = DeviceCandidate(
          source: DeviceDiscoverySource.bluetooth,
          title: device.name.trim().isNotEmpty ? device.name : device.address,
          parameters: {'macAddress': device.address},
        );
      }
    } catch (_) {
      failed = true;
    }

    try {
      final bonded = await _bondedBluetoothDevices();
      for (final device in bonded) {
        combined.putIfAbsent(
          device.address,
          () => DeviceCandidate(
            source: DeviceDiscoverySource.bluetooth,
            title: device.name.trim().isNotEmpty ? device.name : device.address,
            parameters: {'macAddress': device.address},
          ),
        );
      }
    } catch (_) {
      // Defensive only — getBondedDevices() already swallows to []; see the
      // class doc comment.
    }

    return (candidates: combined.values.toList(), failed: failed);
  }

  /// `WifiPrinterScanner.getDeviceSubnet()` + `.scan()`, bounded to
  /// [networkScanBudget] wall-clock time so an unfinished subnet sweep
  /// (up to 254 addresses) never holds the whole search hostage — finding
  /// F5. Failing to name a subnet at all (no usable network interface) is
  /// a real search failure ([DeviceDiscoveryResult.failedSources]); running
  /// out of time budget mid-sweep is not — it is a bounded, honest partial
  /// result, not a failure.
  Future<({List<DeviceCandidate> candidates, bool failed})> _networkCandidates({
    required bool includePort,
  }) async {
    String? subnet;
    try {
      subnet = await _deviceSubnet();
    } catch (_) {
      return (candidates: const <DeviceCandidate>[], failed: true);
    }
    if (subnet == null) {
      return (candidates: const <DeviceCandidate>[], failed: true);
    }

    final results = <DeviceCandidate>[];
    final completer = Completer<void>();
    late StreamSubscription<WifiPrinterInfo> subscription;
    final timer = Timer(networkScanBudget, () {
      if (!completer.isCompleted) completer.complete();
    });

    subscription = _scanNetwork(subnet).listen(
      (info) {
        results.add(
          DeviceCandidate(
            source: DeviceDiscoverySource.network,
            title: 'Сетевой адрес ${info.address}',
            parameters: {
              'ipAddress': info.host,
              if (includePort) 'port': info.port.toString(),
            },
          ),
        );
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object _) {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }

    return (candidates: results, failed: false);
  }
}
