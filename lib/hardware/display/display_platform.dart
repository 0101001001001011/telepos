import 'dart:io';

import 'package:flutter/foundation.dart';

class DisplayPlatform {
  DisplayPlatform._();

  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get isWeb => kIsWeb;

  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  static String? get unsupportedReason {
    if (isSupported) return null;

    if (kIsWeb) {
      return 'Дисплей покупателя не поддерживается в Web-версии';
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return 'Дисплей покупателя не поддерживается на мобильных устройствах';
    }
    return 'Дисплей покупателя не поддерживается на данной платформе';
  }

  static List<String> get defaultPorts {
    if (!isSupported) return [];

    if (Platform.isWindows) {
      return ['COM1', 'COM2', 'COM3', 'COM4', 'COM5'];
    }
    if (Platform.isLinux) {
      return [
        '/dev/ttyUSB0',
        '/dev/ttyUSB1',
        '/dev/ttyACM0',
        '/dev/ttyACM1',
        '/dev/ttyS0',
        '/dev/ttyS1',
      ];
    }
    if (Platform.isMacOS) {
      return ['/dev/cu.usbserial', '/dev/cu.usbmodem', '/dev/tty.usbserial'];
    }
    return [];
  }

  static String? get defaultPort {
    if (!isSupported) return null;

    if (Platform.isWindows) return 'COM2';
    if (Platform.isLinux) return '/dev/ttyUSB0';
    if (Platform.isMacOS) return '/dev/cu.usbserial';
    return null;
  }
}

class DisplayUiVisibility {
  DisplayUiVisibility._();

  static bool get showSettings => DisplayPlatform.isSupported;

  static bool get showPortSelection => DisplayPlatform.isSupported;

  static bool get showTestButton => DisplayPlatform.isSupported;

  static bool get showUnsupportedWarning => !DisplayPlatform.isSupported;
}
