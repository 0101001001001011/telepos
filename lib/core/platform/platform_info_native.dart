import 'dart:io' as io;

/// Host-platform probes for every target except web.
///
/// Kept behind a conditional import because `dart:io` is a compile-time error
/// on web — a `kIsWeb` check does not help, since the import itself fails
/// before any code runs.
bool get isAndroid => io.Platform.isAndroid;
bool get isIOS => io.Platform.isIOS;
bool get isWindows => io.Platform.isWindows;
bool get isLinux => io.Platform.isLinux;
bool get isMacOS => io.Platform.isMacOS;

String get operatingSystem => io.Platform.operatingSystem;
String get operatingSystemVersion => io.Platform.operatingSystemVersion;
String get pathSeparator => io.Platform.pathSeparator;
String get localeName => io.Platform.localeName;
String get version => io.Platform.version;
int get numberOfProcessors => io.Platform.numberOfProcessors;

Map<String, String> get environment => io.Platform.environment;
