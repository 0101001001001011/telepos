import 'package:flutter/foundation.dart';
import 'package:telepos/core/platform/platform_info.dart';
import 'package:flutter/services.dart';

class MobileConfig {
  MobileConfig._();

  static bool get isMobile =>
      !kIsWeb && (PlatformInfo.isAndroid || PlatformInfo.isIOS);

  static Future<void> init() async {
    if (!isMobile) return;

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFFFFFFF),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
