import 'dart:io';
import 'dart:typed_data';

import 'package:telepos/hardware/printer/bluetooth_printer.dart';
import 'package:telepos/hardware/printer/linux_printer.dart';
import 'package:telepos/hardware/printer/printer_factory.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';
import 'package:telepos/hardware/printer/windows_printer.dart';

class PrintUtility {
  PrintUtility._();

  static Future<List<DiscoveredPrinter>> discoverPrinters({
    Duration timeout = const Duration(seconds: 10),
    bool includeUsb = true,
    bool includeBluetooth = true,
    bool includeWifi = true,
  }) async {
    final printers = <DiscoveredPrinter>[];

    if (includeUsb && PrinterFactory.isUsbSupported) {
      final usbPrinters = await _discoverUsbPrinters();
      printers.addAll(usbPrinters);
    }

    if (includeBluetooth && PrinterFactory.isBluetoothSupported) {
      final btPrinters = await _discoverBluetoothPrinters(timeout);
      printers.addAll(btPrinters);
    }

    if (includeWifi) {
      final wifiPrinters = await _discoverWifiPrinters(timeout);
      printers.addAll(wifiPrinters);
    }

    return printers;
  }

  static Future<List<DiscoveredPrinter>> _discoverUsbPrinters() async {
    final printers = <DiscoveredPrinter>[];

    if (Platform.isWindows) {
      final windowsPrinters = await WindowsPrinterScanner.scanPrinters();
      for (final p in windowsPrinters) {
        printers.add(
          DiscoveredPrinter(
            name: p.name,
            address: p.portName,
            connectionType: PrinterConnectionType.usb,
            isDefault: p.isDefault,
          ),
        );
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      final linuxPrinters = await LinuxPrinterScanner.scanDevices();
      for (final p in linuxPrinters) {
        printers.add(
          DiscoveredPrinter(
            name: p.description,
            address: p.devicePath,
            connectionType: PrinterConnectionType.usb,
            vendorId: p.vendorId,
            productId: p.productId,
          ),
        );
      }
    }

    return printers;
  }

  static Future<List<DiscoveredPrinter>> _discoverBluetoothPrinters(
    Duration timeout,
  ) async {
    final printers = <DiscoveredPrinter>[];

    final bonded = await BluetoothPrinterScanner.getBondedDevices();
    for (final d in bonded) {
      if (BluetoothPrinterScanner.isPrinterDevice(d.name)) {
        printers.add(
          DiscoveredPrinter(
            name: d.name,
            address: d.address,
            connectionType: PrinterConnectionType.bluetooth,
            isBonded: true,
          ),
        );
      }
    }

    final scanned = await BluetoothPrinterScanner.scan(timeout: timeout);
    for (final d in scanned) {
      if (!printers.any((p) => p.address == d.address)) {
        printers.add(
          DiscoveredPrinter(
            name: d.name,
            address: d.address,
            connectionType: PrinterConnectionType.bluetooth,
            rssi: d.rssi,
          ),
        );
      }
    }

    return printers;
  }

  static Future<List<DiscoveredPrinter>> _discoverWifiPrinters(
    Duration timeout,
  ) async {
    final printers = <DiscoveredPrinter>[];

    final subnet = await WifiPrinterScanner.getDeviceSubnet();
    if (subnet == null) return printers;

    await for (final p in WifiPrinterScanner.scan(subnet: subnet)) {
      printers.add(
        DiscoveredPrinter(
          name: 'Network Printer',
          address: p.address,
          connectionType: PrinterConnectionType.wifi,
        ),
      );
    }

    return printers;
  }

  static Future<TestPrintResult> testPrint(
    PrinterManager printer, {
    String? customText,
  }) async {
    try {
      if (!printer.isConnected) {
        final result = await printer.connect();
        if (!result.success) {
          return TestPrintResult.error(
            'Не удалось подключиться: ${result.errorMessage}',
          );
        }
      }

      await printer.initialize();

      final testData = _buildTestPage(customText);

      final result = await printer.printReceipt(testData);
      if (!result.success) {
        return TestPrintResult.error('Ошибка печати: ${result.errorMessage}');
      }

      return TestPrintResult.success(
        bytesSent: result.bytesSent ?? testData.length,
      );
    } catch (e) {
      return TestPrintResult.error('Исключение: $e');
    }
  }

  static Uint8List _buildTestPage(String? customText) {
    final buffer = <int>[];

    // Reset *and* reselect CP866 (code page 17) in the same breath — ESC @
    // alone resets the printer to its own default code page, which silently
    // undoes whatever `PrinterManager.initialize()` (`EscPosCommands.init` =
    // `[0x1B, 0x40, 0x1B, 0x74, 17]`) had just selected. Every Cyrillic byte
    // this method writes below is CP866-encoded (`_encodeCP866`); without
    // the reselect, a printer whose own default code page is not CP866
    // renders those bytes as mojibake even though real sale receipts
    // (`ReceiptBuilder.init`, same four bytes) print correctly — found while
    // building the device-check contract (plan 2b, task 2) that this
    // function's only caller (`testPrint`) is for.
    buffer.addAll([0x1B, 0x40, 0x1B, 0x74, 17]);

    buffer.addAll([0x1B, 0x61, 0x01]);

    buffer.addAll([0x1B, 0x45, 0x01]);
    buffer.addAll(_encodeCP866('TEST PRINT'));
    buffer.addAll([0x1B, 0x45, 0x00]);
    buffer.add(0x0A);

    buffer.addAll([0x1B, 0x61, 0x00]);
    buffer.addAll(_encodeCP866('--------------------------------'));
    buffer.add(0x0A);

    buffer.addAll(
      _encodeCP866('Date: ${DateTime.now().toString().substring(0, 19)}'),
    );
    buffer.add(0x0A);

    if (customText != null) {
      buffer.add(0x0A);
      buffer.addAll(_encodeCP866(customText));
      buffer.add(0x0A);
    }

    buffer.add(0x0A);
    buffer.addAll(
      _encodeCP866(
        'Тест кириллицы: АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя',
      ),
    );
    buffer.add(0x0A);

    buffer.addAll(_encodeCP866('--------------------------------'));
    buffer.add(0x0A);

    buffer.addAll([0x1B, 0x61, 0x01]);
    buffer.addAll(_encodeCP866('TelePOS'));
    buffer.add(0x0A);

    buffer.addAll([0x1B, 0x64, 0x03]);
    buffer.addAll([0x1D, 0x56, 0x01]);

    return Uint8List.fromList(buffer);
  }

  static List<int> _encodeCP866(String text) {
    final bytes = <int>[];
    for (final char in text.runes) {
      if (char < 128) {
        bytes.add(char);
      } else if (char >= 0x410 && char <= 0x42F) {
        bytes.add(char - 0x410 + 0x80);
      } else if (char >= 0x430 && char <= 0x43F) {
        bytes.add(char - 0x430 + 0xA0);
      } else if (char >= 0x440 && char <= 0x44F) {
        bytes.add(char - 0x440 + 0xE0);
      } else if (char == 0x401) {
        bytes.add(0xF0);
      } else if (char == 0x451) {
        bytes.add(0xF1);
      } else {
        bytes.add(0x3F);
      }
    }
    return bytes;
  }

  static Future<PrinterDetailInfo?> getPrinterInfo(
    PrinterManager printer,
  ) async {
    if (!printer.isConnected) {
      final result = await printer.connect();
      if (!result.success) return null;
    }

    final status = await printer.getStatus();

    return PrinterDetailInfo(
      isOnline: status.isOnline,
      isPaperPresent: status.isPaperPresent,
      isCoverClosed: status.isCoverClosed,
      errorCode: status.errorCode,
      errorMessage: status.errorMessage,
    );
  }
}

class DiscoveredPrinter {
  const DiscoveredPrinter({
    required this.name,
    required this.address,
    required this.connectionType,
    this.isDefault = false,
    this.isBonded = false,
    this.rssi,
    this.vendorId,
    this.productId,
  });

  final String name;

  final String address;

  final PrinterConnectionType connectionType;

  final bool isDefault;

  final bool isBonded;

  final int? rssi;

  final int? vendorId;

  final int? productId;

  @override
  String toString() => 'DiscoveredPrinter($name @ $address)';
}

class TestPrintResult {
  const TestPrintResult({
    required this.success,
    this.bytesSent,
    this.errorMessage,
  });

  final bool success;
  final int? bytesSent;
  final String? errorMessage;

  factory TestPrintResult.success({int? bytesSent}) =>
      TestPrintResult(success: true, bytesSent: bytesSent);

  factory TestPrintResult.error(String message) =>
      TestPrintResult(success: false, errorMessage: message);

  @override
  String toString() {
    if (success) return 'TestPrintResult.success($bytesSent bytes)';
    return 'TestPrintResult.error($errorMessage)';
  }
}

class PrinterDetailInfo {
  const PrinterDetailInfo({
    required this.isOnline,
    required this.isPaperPresent,
    required this.isCoverClosed,
    this.errorCode,
    this.errorMessage,
  });

  final bool isOnline;
  final bool isPaperPresent;
  final bool isCoverClosed;
  final int? errorCode;
  final String? errorMessage;

  bool get isReady => isOnline && isPaperPresent && isCoverClosed;
}
