import 'dart:io';

import 'package:telepos/hardware/printer/bluetooth_printer.dart';
import 'package:telepos/hardware/printer/linux_printer.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';
import 'package:telepos/hardware/printer/windows_printer.dart';

class PrinterFactory {
  PrinterFactory._();

  static PrinterManager create(
    PrinterConnectionType type, {
    String? address,
    int? port,
  }) {
    switch (type) {
      case PrinterConnectionType.usb:
        return _createUsbPrinter();
      case PrinterConnectionType.bluetooth:
        return BluetoothPrinterManager();
      case PrinterConnectionType.wifi:
        if (address == null) {
          throw ArgumentError('Wi-Fi принтер требует IP адрес');
        }
        return WifiPrinterManager(
          host: address,
          port: port ?? WifiPrinterManager.defaultPort,
        );
      case PrinterConnectionType.serial:
        return _createSerialPrinter(address);
    }
  }

  static PrinterManager _createUsbPrinter() {
    if (Platform.isWindows) {
      return WindowsPrinterManager();
    } else if (Platform.isLinux) {
      return LinuxPrinterManager();
    } else if (Platform.isMacOS) {
      return LinuxPrinterManager(devicePath: '/dev/cu.usbserial');
    } else {
      throw UnsupportedError(
        'USB принтеры не поддерживаются на ${Platform.operatingSystem}',
      );
    }
  }

  static PrinterManager _createSerialPrinter(String? devicePath) {
    if (Platform.isLinux || Platform.isMacOS) {
      return LinuxPrinterManager(
        devicePath: devicePath ?? LinuxPrinterManager.defaultDevicePath,
      );
    }
    throw UnsupportedError(
      'Serial принтеры не поддерживаются на ${Platform.operatingSystem}',
    );
  }

  static List<PrinterConnectionType> getAvailableTypes() {
    if (Platform.isWindows) {
      return [PrinterConnectionType.usb, PrinterConnectionType.wifi];
    } else if (Platform.isLinux || Platform.isMacOS) {
      return [
        PrinterConnectionType.usb,
        PrinterConnectionType.serial,
        PrinterConnectionType.wifi,
      ];
    } else if (Platform.isAndroid || Platform.isIOS) {
      return [PrinterConnectionType.bluetooth, PrinterConnectionType.wifi];
    }
    return [PrinterConnectionType.wifi];
  }

  static bool get isBluetoothSupported {
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get isUsbSupported {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }
}

enum PrinterConnectionType {
  usb(label: 'USB', icon: 'usb'),

  bluetooth(label: 'Bluetooth', icon: 'bluetooth'),

  wifi(label: 'Wi-Fi', icon: 'wifi'),

  serial(label: 'Serial', icon: 'serial_port');

  const PrinterConnectionType({required this.label, required this.icon});

  final String label;

  final String icon;
}

class PrinterConfig {
  const PrinterConfig({
    required this.connectionType,
    this.name,
    this.address,
    this.port,
    this.paperWidth = 58,
    this.autoCut = true,
    this.openDrawerOnSale = false,
  });

  final PrinterConnectionType connectionType;

  final String? name;

  final String? address;

  final int? port;

  final int paperWidth;

  final bool autoCut;

  final bool openDrawerOnSale;

  int get charWidth => paperWidth == 58 ? 32 : 42;

  Map<String, dynamic> toJson() => {
    'connectionType': connectionType.name,
    'name': name,
    'address': address,
    'port': port,
    'paperWidth': paperWidth,
    'autoCut': autoCut,
    'openDrawerOnSale': openDrawerOnSale,
  };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      connectionType: PrinterConnectionType.values.firstWhere(
        (t) => t.name == json['connectionType'],
        orElse: () => PrinterConnectionType.wifi,
      ),
      name: json['name'] as String?,
      address: json['address'] as String?,
      port: json['port'] as int?,
      paperWidth: json['paperWidth'] as int? ?? 58,
      autoCut: json['autoCut'] as bool? ?? true,
      openDrawerOnSale: json['openDrawerOnSale'] as bool? ?? false,
    );
  }

  PrinterConfig copyWith({
    PrinterConnectionType? connectionType,
    String? name,
    String? address,
    int? port,
    int? paperWidth,
    bool? autoCut,
    bool? openDrawerOnSale,
  }) {
    return PrinterConfig(
      connectionType: connectionType ?? this.connectionType,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      paperWidth: paperWidth ?? this.paperWidth,
      autoCut: autoCut ?? this.autoCut,
      openDrawerOnSale: openDrawerOnSale ?? this.openDrawerOnSale,
    );
  }
}
