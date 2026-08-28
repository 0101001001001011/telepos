import 'dart:io';
import 'dart:typed_data';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/device/terminal_device_binding_resolver.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_service.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/display/display_config.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/bluetooth_printer.dart';
import 'package:telepos/hardware/printer/linux_printer.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';
import 'package:telepos/hardware/printer/windows_printer.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';

class HardwareModule {
  HardwareModule._();

  static Future<void> register(GetIt getIt) async {
    final logger = getIt<Talker>();
    await registerHardwareServices(getIt, logger: logger);
  }
}

/// Registers every hardware service for **this terminal** — resolved from
/// its `DeviceBinding`s (docs/system-architecture.md, section 8, И27),
/// never from the old installation-wide `hardware_settings` blob
/// (`SharedPreferences`), which no longer exists (plan 2, task 3).
///
/// Async because resolving "this terminal's bindings" means asking
/// `TerminalRepository.self()` (a `Future`) and then reading
/// `TerminalDeviceBindings` for that terminal's id — both must finish before
/// any `getIt.registerLazySingleton` call below can know what to build.
/// Callers must `await` this (see `HardwareModule.register` and
/// `lib/app/di/service_locator.dart`).
Future<void> registerHardwareServices(GetIt getIt, {Talker? logger}) async {
  final log = logger ?? getIt<Talker>();

  log.info('Registering Hardware Module...');

  final bindings = await _resolveOwnBindings(getIt, log);

  // Resolved once, here, and both registered *and* published: every lazy
  // singleton below captures the binding it was built from, and
  // [LiveDeviceBindings] is the same four values written down so a later
  // reader can ask "what is the live driver of this class pointed at?".
  // `DeviceCheckLocal` is that reader — without this it cannot tell whether
  // the binding it just read out of the database still describes the device
  // the app is already holding, and would open a rival connection to an
  // endpoint that admits one client (finding I2's mitigation).
  final receiptPrinterBinding = _resolveSingleBinding(
    bindings,
    DeviceClass.receiptPrinter,
    log,
    'receipt printer',
  );
  final cashDrawerBinding = _resolveSingleBinding(
    bindings,
    DeviceClass.cashDrawer,
    log,
    'cash drawer',
  );
  final scaleBinding = _resolveSingleBinding(
    bindings,
    DeviceClass.scale,
    log,
    'scale',
  );
  final labelPrinterBinding = _resolveSingleBinding(
    bindings,
    DeviceClass.labelPrinter,
    log,
    'label printer',
  );

  getIt.registerSingleton<LiveDeviceBindings>(
    LiveDeviceBindings(
      receiptPrinter: receiptPrinterBinding,
      cashDrawer: cashDrawerBinding,
      scale: scaleBinding,
      labelPrinter: labelPrinterBinding,
    ),
  );

  _registerPrinterManager(getIt, log, receiptPrinterBinding);

  _registerPrinterFactory(getIt, log);

  _registerDisplayService(getIt, log, bindings);

  // No _registerScannerService here any more (fix round 1, task 5(c), plan
  // 2b): `BarcodeScannerService` was a second, parallel implementation of
  // keyboard-wedge decoding that nothing ever started — every real screen
  // scans through `BarcodeScannerMixin`
  // (`lib/presentation/common/mixins/barcode_scanner_mixin.dart`) instead,
  // which reads its own settings (including `scannerTimeoutMs`) directly.
  // Deleted rather than kept as a second source — see `ScannerMode`'s doc
  // comment in that file for the full reasoning.

  _registerCashDrawerService(getIt, log, cashDrawerBinding);

  _registerScalesService(getIt, log, scaleBinding);

  _registerLabelPrinterService(getIt, log, labelPrinterBinding);

  log.info('Hardware Module registered');
}

/// The bindings the live hardware singletons in the DI graph were built from.
///
/// Captured when [registerHardwareServices] ran and **never updated** — that
/// is the point: it records what the running drivers are pointed at, not what
/// the database says now. `DeviceCheckLocal` compares the two, and the answer
/// decides whether a check can borrow the live driver or must build its own
/// (see `describesSameDeviceAs` on `DeviceBinding`).
///
/// A `null` field means the class has no binding on this terminal — none
/// saved, or more than one, which `_resolveSingleBinding` refuses to choose
/// between (И30). The corresponding singleton may still exist, built from
/// nothing; a check then always builds its own driver, because there is no
/// binding to establish that the live one points anywhere in particular.
class LiveDeviceBindings {
  const LiveDeviceBindings({
    this.receiptPrinter,
    this.cashDrawer,
    this.scale,
    this.labelPrinter,
  });

  final DeviceBinding? receiptPrinter;
  final DeviceBinding? cashDrawer;
  final DeviceBinding? scale;
  final DeviceBinding? labelPrinter;
}

/// The current terminal's device bindings, or an empty list if there is no
/// current terminal yet (setup wizard not completed —
/// `InstallationNotConfiguredException`), no `TerminalRepository`/`AppDatabase`
/// registered (some tests register only what they need), or resolution fails
/// for any other reason. Every one of those is the same case from a device's
/// point of view: nothing configured, so nothing is registered for it — И30
/// never lets a configuration gap block the rest of startup.
Future<List<DeviceBinding>> _resolveOwnBindings(
  GetIt getIt,
  Talker logger,
) async {
  if (!getIt.isRegistered<TerminalRepository>() ||
      !getIt.isRegistered<AppDatabase>()) {
    return const [];
  }

  try {
    final terminal = await getIt<TerminalRepository>().self();
    return await resolveTerminalDeviceBindings(
      database: getIt<AppDatabase>(),
      terminalId: terminal.id,
      catalog: BuiltinDeviceProfileCatalog(),
    );
  } on InstallationNotConfiguredException {
    logger.debug(
      'HardwareModule: setup wizard not completed yet — no terminal, no '
      'device bindings.',
    );
    return const [];
  } catch (e) {
    logger.warning('HardwareModule: failed to resolve device bindings: $e');
    return const [];
  }
}

// `_resolveScannerBusinessRules`/`_registerScannerService` removed (fix
// round 1, task 5(c), plan 2b): they existed only to feed the now-deleted
// `BarcodeScannerService`, a parallel implementation nothing ever started.
// `barcodeMinLength`/`barcodeMaxLength`/`scannerTimeoutMs` (И142) are read
// directly by `BarcodeScannerMixin._loadScannerSettings`
// (`lib/presentation/common/mixins/barcode_scanner_mixin.dart`) instead —
// the actual live reader.

/// Picks the one binding of [deviceClass] to actually use, or refuses.
///
/// **Design decision (plan 2, task 3):** when more than one enabled, valid
/// binding of the same class exists on this terminal, this refuses to guess
/// rather than picking one — first-by-key, most-recently-added, or any other
/// implicit ordering would be exactly the "plausible wrong value" this
/// project has been bitten by repeatedly (see e.g.
/// `lib/domain/terminal/device_binding.dart`'s own refusal to substitute a
/// similar profile, or `resolveReceiptPrinterProfileId`'s refusal to guess
/// between two profiles a legacy value doesn't uniquely narrow). There is no
/// "primary" flag on `TerminalDeviceBindings`
/// (`lib/data/database/tables/terminal_tables.dart`) to make this an honest
/// choice instead of an invented one — adding one is a schema change this
/// task does not make. Until a real primary marker exists, "which printer do
/// I print to" for a terminal with two receipt printers is answered with "no
/// printer, and a warning" rather than a silent pick — consistent with И30:
/// refusing to choose a device is safe, choosing the wrong one is not.
DeviceBinding? _resolveSingleBinding(
  List<DeviceBinding> bindings,
  DeviceClass deviceClass,
  Talker logger,
  String label,
) {
  final matches = bindings
      .where((b) => b.deviceClass == deviceClass)
      .toList(growable: false);
  if (matches.isEmpty) return null;
  if (matches.length == 1) return matches.single;

  logger.warning(
    'HardwareModule: terminal has ${matches.length} enabled $label bindings '
    '(${matches.map((b) => b.profileId).join(', ')}) — refusing to guess '
    'which one to use. Disable all but one in device settings. No $label '
    'will be registered.',
  );
  return null;
}

void _registerPrinterManager(
  GetIt getIt,
  Talker logger,
  DeviceBinding? binding,
) {
  if (binding == null) {
    logger.info(
      'HardwareModule: no receipt printer binding for this terminal — '
      'PrinterManager not registered. A missing printer must never block a '
      'sale (И30) — every printer consumer in this codebase already checks '
      'GetIt.isRegistered<PrinterManager>() before use.',
    );
    return;
  }

  getIt.registerLazySingleton<PrinterManager>(
    () => buildReceiptPrinterManager(binding, logger),
  );
}

/// The receipt-printer driver a [DeviceBinding] describes.
///
/// **Extracted (final-fix round, finding I2) so the *same* function serves
/// two callers, not two parallel ones:** the lazy singleton above, built once
/// per process from the bindings that existed at startup, and
/// `DeviceCheckLocal`, which must build a driver from the binding **as saved
/// now** — otherwise "проверить" answers for the configuration the process
/// started with and can report `ok` for a port the operator has already
/// changed away from. Everything that decides *how* to reach a receipt
/// printer lives here and nowhere else.
PrinterManager buildReceiptPrinterManager(
  DeviceBinding binding,
  Talker logger,
) {
  return resolvePrinterManager(
    receiptType: _printerTransportFor(binding),
    receiptAddress: binding.parameters['ipAddress']?.trim(),
    receiptPort: int.tryParse(binding.parameters['port'] ?? ''),
    receiptDevicePath:
        binding.parameters['devicePath'] ?? binding.parameters['comPort'],
    receiptMacAddress: binding.parameters['macAddress'],
    logger: logger,
  );
}

/// Which transport a receipt-printer [binding]'s declared *parameters* imply
/// — never `binding`'s profile `protocol`, which is `DeviceProtocol.escPos`
/// for every receipt-printer profile in the catalogue regardless of
/// transport (docs/system-architecture.md, section 8: ESC/POS is one
/// protocol, USB/network/Bluetooth/serial are different transports of it).
/// Mirrors `_transportPredicateForPrinterConnectionKind`
/// (`lib/data/database/migrations/device_binding_migration.dart`), which
/// makes the same decision from the *old* raw settings during migration;
/// this one makes it from an already-saved `DeviceBinding`.
String _printerTransportFor(DeviceBinding binding) {
  if (binding.parameters.containsKey('ipAddress')) return 'wifi';
  if (binding.parameters.containsKey('macAddress')) return 'bluetooth';
  if (binding.parameters.containsKey('comPort')) return 'serial';
  return 'usb'; // printer.escpos.usb's one parameter (devicePath) is optional.
}

/// Builds a [PrinterManager] from already-known connection facts. Kept
/// generic (a set of transport-specific fields, not a `DeviceBinding`)
/// rather than folded into `_registerPrinterManager`, because it is
/// independently tested
/// (`test/unit/hardware/resolve_printer_manager_test.dart`) and the mapping
/// it does — which transport picks which concrete `PrinterManager` — has
/// nothing to do with where the caller got its facts from.
///
/// **Every branch below must be reachable in production**, not just from a
/// test that calls this function directly — a final-review finding: before
/// this fix, `_registerPrinterManager` always passed a hardcoded
/// `receiptType: 'wifi'`, so the Windows/Linux/Bluetooth/mobile branches
/// below were dead code from the real app's point of view even though they
/// existed and had tests. [_printerTransportFor] above is what makes them
/// reachable again: it derives the transport from what the binding actually
/// declares, instead of assuming every printer is networked.
PrinterManager resolvePrinterManager({
  required String? receiptType,
  required String? receiptAddress,
  required int? receiptPort,
  String? receiptDevicePath,
  String? receiptMacAddress,
  required Talker logger,
}) {
  if (receiptType == 'wifi' &&
      receiptAddress != null &&
      receiptAddress.isNotEmpty) {
    logger.debug(
      'Registering WifiPrinterManager (bound network receipt printer '
      '$receiptAddress:${receiptPort ?? WifiPrinterManager.defaultPort})',
    );
    return WifiPrinterManager(host: receiptAddress, port: receiptPort);
  }

  if (receiptType == 'bluetooth' &&
      receiptMacAddress != null &&
      receiptMacAddress.isNotEmpty) {
    logger.debug(
      'Registering BluetoothPrinterManager (bound $receiptMacAddress)',
    );
    return BluetoothPrinterManager(deviceAddress: receiptMacAddress);
  }

  try {
    if (Platform.isWindows) {
      logger.debug(
        'Registering WindowsPrinterManager (Windows'
        '${receiptDevicePath != null ? ', port $receiptDevicePath' : ', auto-detect'})',
      );
      return WindowsPrinterManager(portName: receiptDevicePath);
    }

    if (Platform.isLinux) {
      logger.debug(
        'Registering LinuxPrinterManager (Linux'
        '${receiptDevicePath != null ? ', device $receiptDevicePath' : ', auto-detect'})',
      );
      return LinuxPrinterManager(devicePath: receiptDevicePath);
    }

    if (Platform.isMacOS) {
      logger.debug('Registering MockPrinterManager (macOS)');
      return MockPrinterManager(logger: logger);
    }

    if (Platform.isAndroid || Platform.isIOS) {
      logger.debug('Registering BluetoothPrinterManager (mobile)');
      return BluetoothPrinterManager();
    }
  } catch (_) {}

  logger.debug('Registering MockPrinterManager (Web/Unknown)');
  return MockPrinterManager(logger: logger);
}

void _registerPrinterFactory(GetIt getIt, Talker logger) {
  getIt.registerLazySingleton<PrinterServiceFactory>(
    () => PrinterServiceFactory(logger: logger),
  );

  logger.debug('PrinterServiceFactory registered');
}

/// Reads this terminal's `customerDisplay` binding (docs/system-architecture.md,
/// section 8, И27) and builds a real [CustomerDisplayConfig] from it.
///
/// **Final review finding C2, fixed here.** Before this fix, this function
/// ignored [bindings] entirely and hardcoded `enabled: false` — meanwhile
/// `hardware_settings_screen.dart` presented a complete `customerDisplay`
/// editor (profile picker, COM port field) and `LocalDeviceBindingRepository`
/// faithfully saved whatever the operator chose. A settings screen that
/// saves something nothing reads is the exact defect this whole plan exists
/// to remove — worse than a missing feature, because it looks configured.
///
/// The migration still never *infers* a `customerDisplay` binding from the
/// old blob (`lib/data/database/migrations/device_binding_migration.dart`'s
/// blob-key inventory: `displayModel`'s taxonomy doesn't correspond to
/// either catalogue profile) — that gap is unchanged and stays open. What
/// changes here is that a binding saved *directly* through the settings
/// screen (which does not go through that inference at all) is now actually
/// read.
void _registerDisplayService(
  GetIt getIt,
  Talker logger,
  List<DeviceBinding> bindings,
) {
  final binding = _resolveSingleBinding(
    bindings,
    DeviceClass.customerDisplay,
    logger,
    'customer display',
  );
  final profile = binding == null
      ? null
      : BuiltinDeviceProfileCatalog().byId(binding.profileId);

  final config = (binding != null && profile != null)
      ? CustomerDisplayConfig(
          enabled: binding.enabled,
          port: binding.parameters['comPort'] ?? '',
          model: _displayModelFor(profile, logger),
          baudRate: profile.capabilities.defaultBaudRate ?? 9600,
        )
      : const CustomerDisplayConfig(
          enabled: false,
          port: '',
          model: DisplayModel.led8,
          baudRate: 9600,
        );

  if (_isDesktop) {
    getIt.registerLazySingleton<CustomerDisplayManager>(() {
      logger.debug(
        'CustomerDisplayManager registered (desktop, '
        '${config.enabled ? 'bound to ${profile?.id}' : 'disabled'})',
      );
      return CustomerDisplayManager.create(config);
    });
  } else {
    getIt.registerLazySingleton<CustomerDisplayManager>(
      () => _DummyDisplayManager(),
    );
    logger.debug('CustomerDisplayManager registered (stub)');
  }
}

/// Picks the `DisplayModel` whose character width matches [profile]'s
/// declared `displayColumns`.
///
/// **Final review finding, fixed here.** This used to ignore [profile]
/// entirely and always return `DisplayModel.vfd20` — a hardcoded constant
/// dressed up as a function of its argument. That made `DisplayModel.led8`
/// (a real value the enum has always declared —
/// `lib/hardware/display/display_config.dart`) unreachable no matter which
/// profile a binding named, and — worse — meant any future 8-character
/// profile added to the catalogue would silently keep resolving to vfd20
/// instead of picking it up. Now genuinely derived: `display.serial.led8`
/// declares `displayColumns: 8` and resolves to `DisplayModel.led8`;
/// `display.serial.vfd`/`display.serial.lcd-2x20` declare `20` and resolve
/// to `DisplayModel.vfd20`, same as before.
///
/// `null` (no `displayColumns` declared at all) falls back to `vfd20`
/// quietly — that is an ordinary, expected shape for a profile with nothing
/// to say about display width. A *non-null* `displayColumns` that matches no
/// `DisplayModel.chars` is a different case entirely: someone declared a
/// number the enum cannot express, which is exactly the kind of "quietly
/// guessed the wrong default" this function was a debt for in the first
/// place (fix round 1). That case now logs a warning naming the mismatch
/// instead of silently guessing `vfd20` — visible in the log even though the
/// return value still has to be *something*.
DisplayModel _displayModelFor(DeviceProfile profile, Talker logger) {
  final columns = profile.capabilities.displayColumns;
  if (columns == null) return DisplayModel.vfd20;
  for (final model in DisplayModel.values) {
    if (model.chars == columns) return model;
  }
  logger.warning(
    'HardwareModule: profile ${profile.id} declares displayColumns: '
    '$columns, which matches no DisplayModel (${DisplayModel.values.map((m) => '${m.name}=${m.chars}').join(', ')}) '
    '— falling back to vfd20. This is a catalogue data error, not a '
    'legitimate "no preference" case; fix the profile\'s displayColumns.',
  );
  return DisplayModel.vfd20;
}

void _registerCashDrawerService(
  GetIt getIt,
  Talker logger,
  DeviceBinding? binding,
) {
  getIt.registerLazySingleton<CashDrawerService>(
    () => buildCashDrawerService(binding, logger),
  );
  logger.debug(
    'CashDrawerService registered${_isDesktop ? ' (desktop)' : ' (stub)'}',
  );
}

/// The cash-drawer driver a [binding] describes, or the dummy one on a
/// platform with no serial support at all.
///
/// Extracted for the same reason as [buildReceiptPrinterManager] — see that
/// function's comment (finding I2).
CashDrawerService buildCashDrawerService(
  DeviceBinding? binding,
  Talker logger,
) {
  if (!_isDesktop) return CashDrawerService.dummy();

  final isStandalone = binding?.profileId == 'drawer.rj11.standalone';
  return CashDrawerService(
    logger: logger,
    mode: isStandalone ? CashDrawerMode.serialPort : CashDrawerMode.viaPrinter,
    serialPort: binding?.parameters['comPort'],
  );
}

void _registerScalesService(
  GetIt getIt,
  Talker logger,
  DeviceBinding? binding,
) {
  getIt.registerLazySingleton<ScalesService>(
    () => buildScalesService(binding, logger),
  );
  logger.debug(
    'ScalesService registered${_isDesktop ? ' (desktop)' : ' (stub)'}',
  );
}

/// The scale driver a [binding] describes — port from the binding, baud rate
/// and protocol from the profile it names.
///
/// Extracted for the same reason as [buildReceiptPrinterManager] — see that
/// function's comment (finding I2).
ScalesService buildScalesService(DeviceBinding? binding, Talker logger) {
  final profile = binding == null
      ? null
      : BuiltinDeviceProfileCatalog().byId(binding.profileId);
  final port = binding?.parameters['comPort'];

  return ScalesService(
    logger: logger,
    port: (port != null && port.isNotEmpty) ? port : null,
    baudRate: profile?.capabilities.defaultBaudRate ?? 9600,
    protocol: profile?.protocol == DeviceProtocol.casScale
        ? ScalesProtocol.cas
        : ScalesProtocol.generic,
  );
}

void _registerLabelPrinterService(
  GetIt getIt,
  Talker logger,
  DeviceBinding? binding,
) {
  getIt.registerLazySingleton<LabelPrinterService>(
    () => buildLabelPrinterService(binding, logger),
  );
  logger.debug('LabelPrinterService registered');
}

/// The label-printer driver a [binding] describes.
///
/// Extracted for the same reason as [buildReceiptPrinterManager] — see that
/// function's comment (finding I2).
LabelPrinterService buildLabelPrinterService(
  DeviceBinding? binding,
  Talker logger,
) {
  final profile = binding == null
      ? null
      : BuiltinDeviceProfileCatalog().byId(binding.profileId);

  final host = binding?.parameters['ipAddress']?.trim();
  final port = int.tryParse(binding?.parameters['port'] ?? '');
  final widthMm = int.tryParse(binding?.options['paperWidthMm'] ?? '');
  // Restored as configurable (final review "cheap fix" item): this used to
  // come from the pre-branch blob's per-installation `labelHeightMm`, so
  // hardcoding 40 here was a lost setting, not merely an unmodelled field.
  // Now that DeviceCapabilities.labelHeightsMm exists
  // (lib/domain/device/device_profile.dart), the profile can carry it as
  // an operator-selectable option, the same way paperWidthMm already did.
  final heightMm = int.tryParse(binding?.options['labelHeightMm'] ?? '');

  return LabelPrinterService(
    logger: logger,
    host: (host != null && host.isNotEmpty) ? host : null,
    port: port ?? 9100,
    language: _labelLanguageFor(profile),
    labelWidthMm: widthMm ?? 58,
    labelHeightMm: heightMm ?? 40,
  );
}

LabelLanguage _labelLanguageFor(DeviceProfile? profile) {
  return switch (profile?.protocol) {
    DeviceProtocol.epl => LabelLanguage.epl,
    _ => LabelLanguage.zpl,
  };
}

bool get _isDesktop {
  try {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

class PrinterServiceFactory {
  PrinterServiceFactory({required this.logger});

  final Talker logger;
  PrinterManager? _currentPrinter;

  PrinterManager? get currentPrinter => _currentPrinter;

  PrinterManager createWifiPrinter({required String host, int port = 9100}) {
    logger.debug('Creating Wi-Fi printer: $host:$port');
    final printer = WifiPrinterManager(host: host, port: port);
    _currentPrinter = printer;
    return printer;
  }

  PrinterManager createBluetoothPrinter({
    String? deviceAddress,
    String? deviceName,
  }) {
    logger.debug('Creating Bluetooth printer: $deviceName ($deviceAddress)');
    final printer = BluetoothPrinterManager(
      deviceAddress: deviceAddress,
      deviceName: deviceName,
    );
    _currentPrinter = printer;
    return printer;
  }

  PrinterManager createWindowsPrinter({String? printerName}) {
    logger.debug('Creating Windows printer: $printerName');
    final printer = WindowsPrinterManager(printerName: printerName);
    _currentPrinter = printer;
    return printer;
  }

  PrinterManager createLinuxPrinter({String? devicePath, int? baudRate}) {
    logger.debug('Creating Linux printer: $devicePath');
    final printer = LinuxPrinterManager(
      devicePath: devicePath,
      baudRate: baudRate,
    );
    _currentPrinter = printer;
    return printer;
  }

  PrinterManager createMockPrinter() {
    logger.debug('Creating Mock printer');
    final printer = MockPrinterManager(logger: logger);
    _currentPrinter = printer;
    return printer;
  }

  PrinterManager createDefaultPrinter() {
    try {
      if (Platform.isWindows) {
        return createWindowsPrinter();
      }
      if (Platform.isLinux) {
        return createLinuxPrinter();
      }
      if (Platform.isMacOS) {
        return createMockPrinter();
      }
      if (Platform.isAndroid || Platform.isIOS) {
        return createBluetoothPrinter();
      }
    } catch (_) {}
    return createMockPrinter();
  }

  PrinterManager createFromConfig(PrinterConfig config) {
    switch (config.type) {
      case PrinterType.wifi:
        return createWifiPrinter(
          host: config.address!,
          port: config.port ?? 9100,
        );
      case PrinterType.bluetooth:
        return createBluetoothPrinter(
          deviceAddress: config.address,
          deviceName: config.name,
        );
      case PrinterType.usb:
        try {
          if (Platform.isWindows) {
            return createWindowsPrinter(printerName: config.name);
          }
          if (Platform.isLinux) {
            return createLinuxPrinter(devicePath: config.address);
          }
        } catch (_) {}
        if (config.address != null) {
          return createWifiPrinter(host: config.address!);
        }
        throw UnsupportedError(
          'USB принтеры не поддерживаются на этой платформе',
        );
      case PrinterType.mock:
        return createMockPrinter();
    }
  }

  Future<void> disconnect() async {
    await _currentPrinter?.disconnect();
    _currentPrinter = null;
  }
}

class PrinterConfig {
  const PrinterConfig({
    required this.type,
    this.name,
    this.address,
    this.port,
    this.paperWidth = 58,
  });

  final PrinterType type;
  final String? name;
  final String? address;
  final int? port;
  final int paperWidth;

  factory PrinterConfig.fromMap(Map<String, dynamic> map) {
    return PrinterConfig(
      type: PrinterType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => PrinterType.wifi,
      ),
      name: map['name'] as String?,
      address: map['address'] as String?,
      port: map['port'] as int?,
      paperWidth: map['paperWidth'] as int? ?? 58,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'name': name,
    'address': address,
    'port': port,
    'paperWidth': paperWidth,
  };

  factory PrinterConfig.defaultForPlatform() {
    try {
      if (Platform.isWindows) {
        return const PrinterConfig(type: PrinterType.usb);
      }
      if (Platform.isLinux) {
        return const PrinterConfig(
          type: PrinterType.usb,
          address: '/dev/usb/lp0',
        );
      }
      if (Platform.isMacOS) {
        return const PrinterConfig(type: PrinterType.wifi);
      }
      if (Platform.isAndroid || Platform.isIOS) {
        return const PrinterConfig(type: PrinterType.bluetooth);
      }
    } catch (_) {}
    return const PrinterConfig(type: PrinterType.mock);
  }
}

enum PrinterType { wifi, bluetooth, usb, mock }

class MockPrinterManager extends BufferedPrinterManager {
  MockPrinterManager({this.logger});

  final Talker? logger;

  bool _isConnected = false;
  PrinterInfo? _printerInfo;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<PrinterConnectionResult> connect() async {
    logger?.debug('MockPrinter: connect()');
    _isConnected = true;
    _printerInfo = const PrinterInfo(
      name: 'Mock Printer',
      address: 'mock://localhost',
      model: 'Virtual ESC/POS',
      paperWidth: 58,
    );
    return PrinterConnectionResult.ok(_printerInfo!);
  }

  @override
  Future<void> disconnect() async {
    logger?.debug('MockPrinter: disconnect()');
    _isConnected = false;
    _printerInfo = null;
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (!_isConnected) {
      return PrinterStatus.offline;
    }
    return PrinterStatus.ok;
  }

  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    // Подключение — часть записи: см. контракт `PrinterManager.writeRaw`.
    // Mock, отвечающий «не подключен» на первой записи после запуска, вёл бы
    // себя иначе, чем живые провода, и прятал бы дефект вместо его показа.
    if (!_isConnected) await connect();

    logger?.debug('MockPrinter: writeRaw(${data.length} bytes)');

    await Future.delayed(const Duration(milliseconds: 50));

    return PrintResult.ok(bytesSent: data.length);
  }
}

class _DummyDisplayManager implements CustomerDisplayManager {
  @override
  CustomerDisplayConfig get config => const CustomerDisplayConfig(
    port: '',
    model: DisplayModel.led8,
    baudRate: 9600,
  );

  @override
  bool get isConnected => false;

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> showPrice(dynamic price) async {}

  @override
  Future<void> showTotal(dynamic total) async {}

  @override
  Future<void> showText(String text) async {}

  @override
  Future<void> showWelcome() async {}

  @override
  Future<void> showChange(dynamic change) async {}
}
