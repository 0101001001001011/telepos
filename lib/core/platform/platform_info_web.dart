import 'dart:ui' as ui;

/// Web stand-in for the `dart:io` platform probes.
///
/// In a browser there is no host operating system to report, so every probe is
/// false and callers fall through to [PlatformInfo.isWeb].
bool get isAndroid => false;
bool get isIOS => false;
bool get isWindows => false;
bool get isLinux => false;
bool get isMacOS => false;

String get operatingSystem => 'web';
String get operatingSystemVersion => 'browser';
String get pathSeparator => '/';

/// The browser's UI language, in the same shape `Platform.localeName` returns.
String get localeName =>
    ui.PlatformDispatcher.instance.locale.toLanguageTag().replaceAll('-', '_');

/// No Dart VM version to report in a browser.
String get version => 'web';

/// Not discoverable without `navigator.hardwareConcurrency`; one is a safe
/// answer for the diagnostics this feeds.
int get numberOfProcessors => 1;

Map<String, String> get environment => const {};
