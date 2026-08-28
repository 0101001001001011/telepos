import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/di/hardware_module.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

void main() {
  final logger = Talker();

  group('resolvePrinterManager', () {
    test('wifi + address → WifiPrinterManager with host/port', () {
      final pm = resolvePrinterManager(
        receiptType: 'wifi',
        receiptAddress: '192.168.1.50',
        receiptPort: 9100,
        logger: logger,
      );
      expect(pm, isA<WifiPrinterManager>());
      final wifi = pm as WifiPrinterManager;
      expect(wifi.host, '192.168.1.50');
      expect(wifi.port, 9100);
    });

    test('wifi + address with null port → default port 9100', () {
      final pm = resolvePrinterManager(
        receiptType: 'wifi',
        receiptAddress: '10.0.0.7',
        receiptPort: null,
        logger: logger,
      );
      expect(pm, isA<WifiPrinterManager>());
      expect((pm as WifiPrinterManager).port, WifiPrinterManager.defaultPort);
    });

    test(
      'wifi WITHOUT address → falls back to platform default (not wifi)',
      () {
        final pm = resolvePrinterManager(
          receiptType: 'wifi',
          receiptAddress: '',
          receiptPort: null,
          logger: logger,
        );
        expect(pm, isNot(isA<WifiPrinterManager>()));
      },
    );

    test('usb saved → platform manager, never Wi-Fi', () {
      final pm = resolvePrinterManager(
        receiptType: 'usb',
        receiptAddress: '/dev/usb/lp0',
        receiptPort: null,
        logger: logger,
      );
      expect(pm, isNot(isA<WifiPrinterManager>()));
    });

    test('unset (null type) → platform manager, never Wi-Fi', () {
      final pm = resolvePrinterManager(
        receiptType: null,
        receiptAddress: null,
        receiptPort: null,
        logger: logger,
      );
      expect(pm, isNot(isA<WifiPrinterManager>()));
    });
  });
}
