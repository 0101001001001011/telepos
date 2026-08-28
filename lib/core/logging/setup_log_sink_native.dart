import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Appends the wizard's log to a file beside the application.
class SetupLogSink {
  static String? _path;

  /// Where the log is being written, once [open] has succeeded. Null in a
  /// browser, and null here if the directory could not be created.
  static String? get location => _path;

  static Future<void> open(String header) async {
    try {
      final logDir = await _logDirectory();
      final dir = Directory(logDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      _path = '$logDir${Platform.pathSeparator}setup.log';
      File(_path!).writeAsStringSync(header, mode: FileMode.append);
    } catch (e) {
      debugPrint('[SetupLogger] Failed to init: $e');
    }
  }

  static void write(String line) {
    try {
      final path = _path;
      if (path != null) {
        File(path).writeAsStringSync(line, mode: FileMode.append);
        return;
      }
    } catch (_) {}
    debugPrint(line.trimRight());
  }

  static String describeHost() =>
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  static Future<String> _logDirectory() async {
    if (kReleaseMode) {
      final appDir = await getApplicationSupportDirectory();
      return '${appDir.path}${Platform.pathSeparator}logs';
    }
    return '${Directory.current.path}${Platform.pathSeparator}logs';
  }
}
