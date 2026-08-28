import 'package:flutter/foundation.dart';

import 'platform_info_native.dart'
    if (dart.library.js_interop) 'platform_info_web.dart'
    as host;

/// The single place the app asks what it is running on.
///
/// Import this rather than `dart:io` when all you need is to branch on the
/// platform. `dart:io` cannot be imported at all in a web build, so a file that
/// reaches for `Platform.isWindows` becomes uncompilable on web even when the
/// call is already guarded by `kIsWeb` — the guard runs too late to matter.
class PlatformInfo {
  PlatformInfo._();

  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && host.isAndroid;
  static bool get isIOS => !kIsWeb && host.isIOS;
  static bool get isWindows => !kIsWeb && host.isWindows;
  static bool get isLinux => !kIsWeb && host.isLinux;
  static bool get isMacOS => !kIsWeb && host.isMacOS;

  static bool get isDesktop => isWindows || isLinux || isMacOS;
  static bool get isMobile => isAndroid || isIOS;

  /// Lowercase host identifier — `windows`, `linux`, `macos`, `android`,
  /// `ios`, or `web`.
  static String get operatingSystem =>
      kIsWeb ? 'web' : host.operatingSystem;

  static String get operatingSystemVersion =>
      kIsWeb ? 'browser' : host.operatingSystemVersion;

  /// `\` on Windows, `/` everywhere else including web.
  static String get pathSeparator => kIsWeb ? '/' : host.pathSeparator;

  /// Locale of the host or browser, e.g. `ru_RU`.
  static String get localeName => host.localeName;

  /// Dart runtime version string; `web` in a browser.
  static String get version => host.version;

  static int get numberOfProcessors => host.numberOfProcessors;

  /// Process environment. Always empty on web — a browser has none.
  static Map<String, String> get environment =>
      kIsWeb ? const {} : host.environment;

  static String get name {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }
}
