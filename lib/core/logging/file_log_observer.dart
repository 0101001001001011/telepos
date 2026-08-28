import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/log_sink.dart';

/// The one place every talker record passes through.
///
/// [AppLogger.create] gives [Talker] exactly one observer, so `onLog`,
/// `onError` and `onException` here are the whole of the application's
/// logging output. That is why the syslog sink plugs in here and nowhere
/// else: one insertion point rather than one per call site.
///
/// **The file is written first, the sink second, and the sink cannot stop the
/// file.** A native library that failed to load, a full disk on the spool, a
/// worker isolate that died — none of them may cost the local log a line, and
/// none of them may throw into whoever was logging. Logging is not on the
/// money path and this class is where it is kept off it.
class FileLogObserver extends TalkerObserver {
  FileLogObserver({
    required String logDirectory,
    this.minLevel = LogLevel.verbose,
    LogSink? sink,
  }) : _logDirectory = logDirectory,
       _sink = sink;

  final String _logDirectory;
  final LogLevel minLevel;

  LogSink? _sink;

  /// Attaches the sink once it has opened.
  ///
  /// Opening it involves a worker isolate and a native library, so it finishes
  /// after startup has already logged a few lines. Those lines are in the file
  /// and not in the sink, and that is the honest cost of not making the till
  /// wait for a log transport to come up.
  set sink(LogSink? value) => _sink = value;

  static const String filePrefix = 'app-';
  static const String fileSuffix = '.log';

  IOSink? _fileSink;
  String? _currentDate;

  @override
  void onError(TalkerError err) => _writeToFile(
    level: 'ERROR',
    severity: LogSinkSeverity.error,
    title: err.title,
    message: err.displayMessage,
    error: err.error,
    stackTrace: err.stackTrace,
  );

  @override
  void onException(TalkerException err) => _writeToFile(
    level: 'ERROR',
    severity: LogSinkSeverity.error,
    title: err.title,
    message: err.displayMessage,
    error: err.exception,
    stackTrace: err.stackTrace,
  );

  @override
  void onLog(TalkerData log) {
    if (log is TalkerLog) {
      final logLevel = log.logLevel;
      if (logLevel == null) return;
      if (!includes(logLevel, minLevel)) return;
      _writeToFile(
        level: logLevel.name.toUpperCase(),
        severity: logSinkSeverityFor(logLevel),
        title: log.title,
        message: log.message,
      );
    }
  }

  void writeSessionStart({String? appVersion}) {
    try {
      _ensureFileReady();
      final v = appVersion != null ? ' | v$appVersion' : '';
      _fileSink?.writeln('');
      _fileSink?.writeln(
        '===== APP START ${_formatTimestamp(DateTime.now())}$v =====',
      );
      _fileSink?.flush();
    } catch (_) {}
  }

  void _writeToFile({
    required String level,
    required LogSinkSeverity severity,
    String? title,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final messagePart = message ?? error?.toString() ?? '';
    try {
      _ensureFileReady();
      final fileSink = _fileSink;
      if (fileSink != null) {
        final ts = _formatTimestamp(DateTime.now());
        final titlePart = (title != null && title.isNotEmpty)
            ? '[$title] '
            : '';
        fileSink.writeln('$ts $level $titlePart$messagePart');
        if (error != null && message != error.toString()) {
          fileSink.writeln('  $error');
        }
        if (stackTrace != null) {
          fileSink.writeln(stackTrace.toString());
        }
      }
    } catch (_) {}

    // Second, and in its own guard. A sink that throws must cost nothing —
    // not the line above, and not an exception in the caller.
    try {
      _sink?.submit(severity: severity, msgid: title, message: messagePart);
    } catch (_) {}
  }

  void _ensureFileReady() {
    final today = _todayString();
    if (_currentDate == today && _fileSink != null) return;

    _fileSink?.flush();
    _fileSink?.close();

    final dir = Directory(_logDirectory);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    _currentDate = today;
    final path =
        '$_logDirectory${Platform.pathSeparator}$filePrefix$today$fileSuffix';
    _fileSink = File(path).openWrite(mode: FileMode.append);
  }

  String _todayString() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String _formatTimestamp(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '${dt.year}-$m-$d $h:$min:$s.$ms';
  }

  Future<void> dispose() async {
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
    final sink = _sink;
    _sink = null;
    try {
      await sink?.close();
    } catch (_) {
      // Shutting the sink down is the sink's problem. A till closing its shift
      // does not get an exception because a log transport misbehaved.
    }
  }
}

/// Whether a record at [level] passes a floor of [minimum].
///
/// **`LogLevel.index` is not severity.** talker declares the enum in the order
/// `error, critical, info, debug, verbose, warning`, so the comparison this
/// used to make — `level.index < minimum.index` — dropped errors, criticals,
/// infos and debugs at the default floor of `verbose` and let only `verbose`
/// and `warning` through. The file log has been missing every `talker.info`
/// and every `talker.error` for as long as this class has existed; nothing
/// asserted otherwise, because nothing asserted anything about this class.
///
/// `logLevelPriorityList` is talker's own ordering, most severe first, and is
/// the only thing that means what this comparison needs.
@visibleForTesting
bool includes(LogLevel level, LogLevel minimum) {
  final levelRank = logLevelPriorityList.indexOf(level);
  final minimumRank = logLevelPriorityList.indexOf(minimum);
  if (levelRank < 0 || minimumRank < 0) return true;
  return levelRank <= minimumRank;
}

/// Maps a talker level onto RFC 5424 §6.2.1 severity.
///
/// talker has six levels and the standard has eight; `emergency`, `alert` and
/// `notice` have no talker equivalent and are never produced from here. That
/// is a gap in what the application can say, not in the mapping.
@visibleForTesting
LogSinkSeverity logSinkSeverityFor(LogLevel level) => switch (level) {
  LogLevel.critical => LogSinkSeverity.critical,
  LogLevel.error => LogSinkSeverity.error,
  LogLevel.warning => LogSinkSeverity.warning,
  LogLevel.info => LogSinkSeverity.informational,
  LogLevel.debug => LogSinkSeverity.debug,
  LogLevel.verbose => LogSinkSeverity.debug,
};
