import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/file_log_observer.dart';
import 'package:telepos/core/logging/log_sink.dart';

class AppLogger {
  AppLogger._();

  static FileLogObserver? _fileObserver;

  static String? logDir;

  static Talker create({
    required bool isProduction,
    required String logDirectory,
    String? appVersion,
  }) {
    logDir = logDirectory;
    _fileObserver = FileLogObserver(logDirectory: logDirectory);
    _fileObserver!.writeSessionStart(appVersion: appVersion);

    return Talker(
      settings: TalkerSettings(useConsoleLogs: !isProduction),
      observer: _fileObserver,
    );
  }

  /// Hands the observer a sink for records that leave the machine.
  ///
  /// Separate from [create] because opening the sink starts an isolate and
  /// loads a native library, and startup must not wait on either. Returns
  /// whether the sink delivers, so the caller can say so in the log.
  static bool attachSink(LogSink sink) {
    final observer = _fileObserver;
    if (observer == null) return false;
    observer.sink = sink;
    return sink.unavailableReason == null;
  }

  static Future<void> redirectStdStreams({required String logDirectory}) async {
    if (kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    final dir = Directory(logDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final outFile = File('$logDirectory${Platform.pathSeparator}out.txt');
    final errFile = File('$logDirectory${Platform.pathSeparator}err.txt');

    stdout.nonBlocking;
    final outSink = outFile.openWrite(mode: FileMode.append);
    outSink.writeln(
      '--- TelePOS stdout started: ${DateTime.now().toIso8601String()} ---',
    );

    final errSink = errFile.openWrite(mode: FileMode.append);
    errSink.writeln(
      '--- TelePOS stderr started: ${DateTime.now().toIso8601String()} ---',
    );

    await outSink.flush();
    await errSink.flush();
    await outSink.close();
    await errSink.close();
  }

  static Future<void> dispose() async {
    await _fileObserver?.dispose();
  }
}
