import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';

/// The device profile catalog TelePOS ships with, out of the box.
///
/// This is the fixture as much as it is the product: every `DeviceClass`
/// needs at least one profile or a terminal cannot be configured for that
/// kind of device at all, and every class here carries more than one
/// profile where more than one real model is common, so that "return
/// everything for this class" is distinguishable from "return the right
/// profile" in tests.
///
/// Plan 2b makes this editable from the UI (И124: reference data, not
/// constants in code). Until then, this is the one and only
/// `DeviceProfileCatalog` implementation.
class BuiltinDeviceProfileCatalog implements DeviceProfileCatalog {
  static const List<DeviceProfile> _profiles = <DeviceProfile>[
    // Receipt printers — ESC/POS is the de-facto standard (см.
    // docs/system-architecture.md, section 8). ESC/POS is a *protocol*; USB,
    // network, Bluetooth and serial are *transports* the same protocol runs
    // over — a printer wired to one till's USB port is the ordinary,
    // default case (section 8: "умолчание остаётся прежним: один принтер на
    // одну кассу"), not an exception. The "принтеры сетевые" rule two
    // profiles below cite is scoped to installations where one machine
    // serves several tills — a USB printer physically cannot be reached
    // from a second machine — and does not apply to the common single-till
    // case, which is why this catalogue also ships USB/spooler, Bluetooth
    // and serial profiles below rather than only networked ones. Fixed
    // during final review (2026-07-30): shipping only the two networked
    // profiles here made every USB-attached printer — the majority of real
    // tills — unrepresentable, and therefore unable to print at all.
    DeviceProfile(
      id: 'printer.escpos.80mm',
      deviceClass: DeviceClass.receiptPrinter,
      title: 'Чековый принтер ESC/POS 80 мм',
      protocol: DeviceProtocol.escPos,
      capabilities: DeviceCapabilities(
        paperWidthsMm: [58, 80],
        canCutPaper: true,
        codePages: ['CP866', 'CP1251', 'UTF-8'],
        supportsOpenDrawer: true,
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'ipAddress',
          isRequired: true,
          description: 'IP-адрес сетевого принтера',
        ),
        DeviceConnectionParam(
          key: 'port',
          isRequired: false,
          description: 'TCP-порт, по умолчанию 9100',
        ),
      ],
    ),
    DeviceProfile(
      id: 'printer.escpos.58mm-compact',
      deviceClass: DeviceClass.receiptPrinter,
      title: 'ESC/POS Receipt Printer 58mm (compact, no cutter)',
      protocol: DeviceProtocol.escPos,
      capabilities: DeviceCapabilities(
        paperWidthsMm: [58],
        codePages: ['CP866'],
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'ipAddress',
          isRequired: true,
          description: 'Network printer IP address',
        ),
        // Missing until task 5 of plan 2b (device-discovery-and-tests): this
        // profile is also networked (see its `ipAddress` param above), same
        // as `printer.escpos.80mm`, but declared no way to carry a non-default
        // port — a binding to this profile could not address a printer
        // listening on anything but the transport's own hardcoded fallback
        // (hardware_module.dart's `9100`). Unreachable today (no discovery
        // path binds to it yet), but a real inconsistency: two networked
        // ESC/POS profiles should offer the same connection surface.
        DeviceConnectionParam(
          key: 'port',
          isRequired: false,
          description: 'TCP port, default 9100',
        ),
      ],
    ),

    // USB/spooler receipt printer — same ESC/POS protocol as the two
    // networked profiles above, different transport. `devicePath` is
    // deliberately *optional*: `WindowsPrinterManager`/`LinuxPrinterManager`
    // (lib/hardware/printer/windows_printer.dart,
    // lib/hardware/printer/linux_printer.dart) both auto-detect a connected
    // printer when given no explicit port/device — the same behaviour this
    // product always had before device bindings existed at all, restored
    // here rather than forcing every operator to type a device path just to
    // get a binding to exist.
    DeviceProfile(
      id: 'printer.escpos.usb',
      deviceClass: DeviceClass.receiptPrinter,
      title: 'Чековый принтер ESC/POS, USB/спулер',
      protocol: DeviceProtocol.escPos,
      capabilities: DeviceCapabilities(
        paperWidthsMm: [58, 80],
        canCutPaper: true,
        codePages: ['CP866', 'CP1251', 'UTF-8'],
        supportsOpenDrawer: true,
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'devicePath',
          isRequired: false,
          description:
              'USB-устройство или очередь спулера (COM-порт на Windows, '
              '/dev/usb/lp* на Linux) — оставьте пустым для автоопределения',
        ),
      ],
    ),

    // Bluetooth receipt printer — same shape as scanner.bluetooth.hid
    // below: the MAC address of a paired device is the one thing that
    // actually addresses it, and there is no sensible default for it.
    DeviceProfile(
      id: 'printer.escpos.bluetooth',
      deviceClass: DeviceClass.receiptPrinter,
      title: 'Чековый принтер ESC/POS, Bluetooth',
      protocol: DeviceProtocol.escPos,
      capabilities: DeviceCapabilities(
        paperWidthsMm: [58],
        codePages: ['CP866'],
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'macAddress',
          isRequired: true,
          description: 'MAC-адрес сопряжённого Bluetooth-принтера',
        ),
      ],
    ),

    // Serial receipt printer — a genuine COM port the operator names
    // explicitly, unlike the USB/spooler profile above where a port is
    // optional. Same reasoning as scale.cas.pd2/display.serial.vfd: the baud
    // rate is fixed by the model, the port differs per unit.
    DeviceProfile(
      id: 'printer.escpos.serial',
      deviceClass: DeviceClass.receiptPrinter,
      title: 'Чековый принтер ESC/POS, последовательный порт',
      protocol: DeviceProtocol.escPos,
      capabilities: DeviceCapabilities(
        paperWidthsMm: [58, 80],
        canCutPaper: true,
        defaultBaudRate: 9600,
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Последовательный порт принтера, например COM4',
        ),
      ],
    ),

    // Label printers — ZPL and EPL, both networked.
    DeviceProfile(
      id: 'printer.label.zpl.104mm',
      deviceClass: DeviceClass.labelPrinter,
      title: 'Label Printer ZPL 104mm',
      protocol: DeviceProtocol.zpl,
      // labelHeightsMm restores what used to be the blob's per-installation
      // `labelHeightMm` (default 40) as an operator-selectable option
      // (DeviceProfile.options), instead of hardware_module.dart hardcoding
      // 40mm for every installation regardless of the label stock actually
      // loaded — a review finding on this plan.
      capabilities: DeviceCapabilities(
        paperWidthsMm: [104],
        labelHeightsMm: [40, 60, 80, 150],
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'ipAddress',
          isRequired: true,
          description: 'Network label printer IP address',
        ),
        // Optional, same reasoning as the receipt printer network profiles'
        // `port` — most installations never touch it. Added while closing a
        // related review finding: `hardware_module.dart`'s
        // `_registerLabelPrinterService` already read
        // `binding.parameters['port']`, but no label-printer profile ever
        // declared it, so `DeviceBinding.validateAgainst` would have
        // rejected any binding that tried to supply one.
        DeviceConnectionParam(
          key: 'port',
          isRequired: false,
          description: 'TCP-порт, по умолчанию 9100',
        ),
      ],
    ),
    DeviceProfile(
      id: 'printer.label.epl.58mm',
      deviceClass: DeviceClass.labelPrinter,
      title: 'Принтер этикеток EPL 58 мм',
      protocol: DeviceProtocol.epl,
      capabilities: DeviceCapabilities(
        paperWidthsMm: [40, 58],
        labelHeightsMm: [30, 40],
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'ipAddress',
          isRequired: true,
          description: 'IP-адрес принтера этикеток',
        ),
        DeviceConnectionParam(
          key: 'port',
          isRequired: false,
          description: 'TCP-порт, по умолчанию 9100',
        ),
      ],
    ),

    // Scanners — HID keyboard-wedge covers the large majority of models,
    // wired or Bluetooth; camera scanning is software reading the host's
    // camera and needs neither an address nor a required parameter at all.
    DeviceProfile(
      id: 'scanner.usb.hid',
      deviceClass: DeviceClass.scanner,
      title: 'USB HID Barcode Scanner',
      protocol: DeviceProtocol.hidKeyboard,
      capabilities: DeviceCapabilities(
        barcodeSymbologies: ['EAN-13', 'EAN-8', 'CODE-128', 'QR'],
      ),
      // No connection parameters: the OS enumerates it as a keyboard, and
      // there is nothing for an operator to address.
    ),
    DeviceProfile(
      id: 'scanner.bluetooth.hid',
      deviceClass: DeviceClass.scanner,
      title: 'Bluetooth-сканер штрихкода (HID)',
      protocol: DeviceProtocol.hidKeyboard,
      capabilities: DeviceCapabilities(
        barcodeSymbologies: ['EAN-13', 'CODE-128'],
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'macAddress',
          isRequired: true,
          description: 'MAC-адрес сопряжённого Bluetooth-сканера',
        ),
      ],
    ),
    DeviceProfile(
      id: 'scanner.camera',
      deviceClass: DeviceClass.scanner,
      title: 'Сканер по камере устройства',
      protocol: DeviceProtocol.cameraScan,
      capabilities: DeviceCapabilities(
        barcodeSymbologies: ['EAN-13', 'CODE-128', 'QR'],
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'cameraId',
          isRequired: false,
          description:
              'Which camera to use, when the host has more than one. '
              'Defaults to the system camera.',
        ),
      ],
    ),
    // The third connection kind this product has always supported —
    // ScannerMode.serialPort
    // (lib/presentation/common/mixins/barcode_scanner_mixin.dart) — a
    // scanner wired to a COM port rather than presenting as a keyboard or
    // reading a camera. Same shape as the serial scale/display profiles
    // below: the baud rate is fixed by the model, so it lives on
    // capabilities.defaultBaudRate; the port differs per unit, so it is the
    // one connection parameter.
    DeviceProfile(
      id: 'scanner.serial',
      deviceClass: DeviceClass.scanner,
      title: 'Сканер штрихкода, последовательный порт',
      protocol: DeviceProtocol.serialScanner,
      capabilities: DeviceCapabilities(
        barcodeSymbologies: ['EAN-13', 'EAN-8', 'CODE-128'],
        defaultBaudRate: 9600,
      ),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Последовательный порт сканера, например COM5',
        ),
      ],
    ),

    // Scales — CAS is the de-facto protocol assumed by the existing
    // ScaleType.serial connection kind. Exactly one connection parameter:
    // the COM port. The baud rate is fixed by the model, so it lives on
    // capabilities.defaultBaudRate, not here.
    DeviceProfile(
      id: 'scale.cas.pd2',
      deviceClass: DeviceClass.scale,
      title: 'Весы CAS PD-II (последовательные)',
      protocol: DeviceProtocol.casScale,
      capabilities: DeviceCapabilities(defaultBaudRate: 9600),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Последовательный порт весов, например COM3',
        ),
      ],
    ),
    DeviceProfile(
      id: 'scale.cas.er-plus',
      deviceClass: DeviceClass.scale,
      title: 'CAS ER-Plus Scale',
      protocol: DeviceProtocol.casScale,
      capabilities: DeviceCapabilities(defaultBaudRate: 9600),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Serial port the scale is attached to, e.g. COM4',
        ),
      ],
    ),

    // Cash drawers — the drawer-kick command is ESC/POS. A drawer wired
    // through the receipt printer has nothing of its own to address; a
    // standalone one needs its own serial port.
    DeviceProfile(
      id: 'drawer.rj11.via-printer',
      deviceClass: DeviceClass.cashDrawer,
      title: 'Cash Drawer via Printer (RJ11 kick-out)',
      protocol: DeviceProtocol.escPos,
      capabilities: DeviceCapabilities(supportsOpenDrawer: true),
      // No connection parameters: it rides the receipt printer's binding.
    ),
    DeviceProfile(
      id: 'drawer.rj11.standalone',
      deviceClass: DeviceClass.cashDrawer,
      title: 'Автономный денежный ящик (RJ11)',
      protocol: DeviceProtocol.escPos,
      capabilities: DeviceCapabilities(supportsOpenDrawer: true),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Последовательный порт интерфейсной платы ящика',
        ),
      ],
    ),

    // Customer displays — serial pole displays. One connection parameter,
    // same reasoning as scales. `capabilities.displayColumns` is the fixed
    // character width `hardware_module.dart`'s `_displayModelFor` reads to
    // pick a `DisplayModel` (task 5, plan 2b) — both profiles below are
    // 20-character-class displays, same as before this fix.
    DeviceProfile(
      id: 'display.serial.vfd',
      deviceClass: DeviceClass.customerDisplay,
      title: 'Дисплей покупателя VFD (последовательный)',
      protocol: DeviceProtocol.serialDisplay,
      capabilities: DeviceCapabilities(defaultBaudRate: 9600, displayColumns: 20),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Последовательный порт дисплея покупателя',
        ),
      ],
    ),
    DeviceProfile(
      id: 'display.serial.lcd-2x20',
      deviceClass: DeviceClass.customerDisplay,
      title: 'Customer Display LCD 2x20',
      protocol: DeviceProtocol.serialDisplay,
      capabilities: DeviceCapabilities(defaultBaudRate: 2400, displayColumns: 20),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Serial port the display is attached to',
        ),
      ],
    ),
    // Added closing a review finding (task 5, plan 2b): before this profile
    // existed, `DisplayModel.led8` — a real value the enum has always
    // declared (`lib/hardware/display/display_config.dart`) — could never be
    // produced by any binding, because every customer-display profile in
    // this catalogue was 20-character-class. This is the 8-character
    // counterpart.
    DeviceProfile(
      id: 'display.serial.led8',
      deviceClass: DeviceClass.customerDisplay,
      title: 'Дисплей покупателя LED (8 символов)',
      protocol: DeviceProtocol.serialDisplay,
      capabilities: DeviceCapabilities(defaultBaudRate: 9600, displayColumns: 8),
      connectionParams: [
        DeviceConnectionParam(
          key: 'comPort',
          isRequired: true,
          description: 'Последовательный порт дисплея покупателя',
        ),
      ],
    ),

    // Payment terminals — the integration this codebase already talks to
    // (see lib/domain/setup/setup_draft.dart PaymentTerminalConfigInfo). It
    // needs more than the single address a printer or a scale needs —
    // exactly the case a lone `address: String?` field could not express.
    //
    // Rahmet used to have a profile here too (`payment.rahmet.qr`). Removed
    // along with the rest of the integration — product owner decision, see
    // lib/data/database/migrations/device_binding_migration.dart's blob-key
    // inventory for why the migration deliberately never read its blob keys.
    DeviceProfile(
      id: 'payment.kaspi.pos',
      deviceClass: DeviceClass.paymentTerminal,
      title: 'Kaspi POS Terminal',
      protocol: DeviceProtocol.kaspiPos,
      connectionParams: [
        DeviceConnectionParam(
          key: 'ipAddress',
          isRequired: true,
          description: 'IP-адрес терминала Kaspi POS',
        ),
        DeviceConnectionParam(
          key: 'port',
          isRequired: true,
          description: 'Порт терминала, обычно 8888',
        ),
      ],
    ),
  ];

  @override
  List<DeviceProfile> forClass(DeviceClass deviceClass) => _profiles
      .where((profile) => profile.deviceClass == deviceClass)
      .toList(growable: false);

  @override
  DeviceProfile? byId(String id) {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }
}
