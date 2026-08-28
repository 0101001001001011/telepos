import 'package:telepos/core/platform/platform_info.dart';

import 'window_config_native.dart'
    if (dart.library.js_interop) 'window_config_web.dart'
    as host;

/// Desktop window setup and the single-instance guard.
///
/// Both are no-ops on web and on mobile: a browser tab has no window to size,
/// and `window_manager` is a desktop-only plugin whose `dart:io` dependency
/// cannot be compiled for web at all.
class WindowConfig {
  WindowConfig._();

  static bool get isDesktop => PlatformInfo.isDesktop;

  /// Not called at all in headless runs: the native runner never creates a
  /// visible window, so there is nothing here to configure. See
  /// windows/runner/main.cpp.
  static Future<void> init({bool isProduction = false}) =>
      host.initWindow(isProduction: isProduction);

  /// False when another copy of TelePOS already holds the lock. Always true
  /// where the concept does not apply.
  static Future<bool> acquireSingleInstanceLock() =>
      host.acquireSingleInstanceLock();

  static Future<void> releaseSingleInstanceLock() =>
      host.releaseSingleInstanceLock();
}
