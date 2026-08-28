/// What the one insertion point of the application's logging actually does.
///
/// Before this file `FileLogObserver` had no tests at all, which is how its
/// level filter came to drop every `talker.info` and every `talker.error` for
/// as long as it existed (see [includes]).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/file_log_observer.dart';
import 'package:telepos/core/logging/log_sink.dart';

/// Records what it was handed, so a test can say what reached the sink rather
/// than that "nothing threw".
class _RecordingSink implements LogSink {
  final List<({LogSinkSeverity severity, String? msgid, String? message})>
  submitted = [];
  int closed = 0;

  @override
  String? get unavailableReason => null;

  @override
  void submit({
    required LogSinkSeverity severity,
    String? msgid,
    String? message,
  }) => submitted.add((severity: severity, msgid: msgid, message: message));

  @override
  Future<void> close() async => closed++;
}

/// Fails at every call, the way a sink whose worker isolate has died would.
class _ThrowingSink implements LogSink {
  @override
  String? get unavailableReason => null;

  @override
  void submit({
    required LogSinkSeverity severity,
    String? msgid,
    String? message,
  }) => throw StateError('the sink is broken');

  @override
  Future<void> close() async => throw StateError('the sink is broken');
}

void main() {
  late Directory logDirectory;

  setUp(() {
    logDirectory = Directory.systemTemp.createTempSync('file_log_observer');
  });

  tearDown(() {
    if (logDirectory.existsSync()) {
      logDirectory.deleteSync(recursive: true);
    }
  });

  String readLog() {
    final files = logDirectory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(FileLogObserver.fileSuffix))
        .toList();
    if (files.isEmpty) return '';
    return files.map((f) => f.readAsStringSync()).join();
  }

  group('the record reaches the sink', () {
    test('an info line is handed over, with its message and its title', () async {
      final sink = _RecordingSink();
      final observer = FileLogObserver(
        logDirectory: logDirectory.path,
        sink: sink,
      );

      observer.onLog(TalkerLog('receipt closed', logLevel: LogLevel.info, title: 'SALE'));
      await observer.dispose();

      expect(sink.submitted, hasLength(1));
      expect(sink.submitted.single.severity, LogSinkSeverity.informational);
      expect(sink.submitted.single.message, 'receipt closed');
      expect(sink.submitted.single.msgid, 'SALE');
    });

    test('an error observed by talker arrives at error severity', () async {
      final sink = _RecordingSink();
      final observer = FileLogObserver(
        logDirectory: logDirectory.path,
        sink: sink,
      );

      observer.onError(TalkerError(ArgumentError('bad drawer'), message: 'drawer'));
      observer.onException(
        TalkerException(Exception('no printer'), message: 'printer'),
      );
      await observer.dispose();

      expect(sink.submitted, hasLength(2));
      expect(
        sink.submitted.map((s) => s.severity),
        everyElement(LogSinkSeverity.error),
      );
    });

    test('a sink attached after construction receives what follows', () async {
      final observer = FileLogObserver(logDirectory: logDirectory.path);
      observer.onLog(TalkerLog('before', logLevel: LogLevel.info));

      final sink = _RecordingSink();
      observer.sink = sink;
      observer.onLog(TalkerLog('after', logLevel: LogLevel.info));
      await observer.dispose();

      // Startup logs before the isolate is up; those lines are in the file and
      // not in the sink, and that is the stated cost of not waiting.
      expect(sink.submitted.map((s) => s.message), ['after']);
      expect(readLog(), contains('before'));
    });

    test('dispose closes the sink', () async {
      final sink = _RecordingSink();
      final observer = FileLogObserver(
        logDirectory: logDirectory.path,
        sink: sink,
      );
      await observer.dispose();
      expect(sink.closed, 1);
    });
  });

  group('the sink cannot cost the till anything', () {
    test(
      'a sink that throws neither escapes onLog nor loses the file line',
      () async {
        final observer = FileLogObserver(
          logDirectory: logDirectory.path,
          sink: _ThrowingSink(),
        );

        expect(
          () => observer.onLog(TalkerLog('sale 42', logLevel: LogLevel.info)),
          returnsNormally,
        );
        expect(
          () => observer.onError(TalkerError(StateError('x'), message: 'x')),
          returnsNormally,
        );
        await observer.dispose();

        expect(readLog(), contains('sale 42'));
      },
    );

    test('no sink at all is the ordinary case and writes the file', () async {
      final observer = FileLogObserver(logDirectory: logDirectory.path);
      observer.onLog(TalkerLog('sale 43', logLevel: LogLevel.info));
      await observer.dispose();
      expect(readLog(), contains('sale 43'));
    });
  });

  group('severity mapping', () {
    test('every talker level maps to the RFC 5424 severity it means', () {
      expect(logSinkSeverityFor(LogLevel.critical), LogSinkSeverity.critical);
      expect(logSinkSeverityFor(LogLevel.error), LogSinkSeverity.error);
      expect(logSinkSeverityFor(LogLevel.warning), LogSinkSeverity.warning);
      expect(logSinkSeverityFor(LogLevel.info), LogSinkSeverity.informational);
      expect(logSinkSeverityFor(LogLevel.debug), LogSinkSeverity.debug);
      expect(logSinkSeverityFor(LogLevel.verbose), LogSinkSeverity.debug);
    });
  });

  group('the level floor', () {
    // talker declares LogLevel as `error, critical, info, debug, verbose,
    // warning`, so comparing `.index` — which is what this class did — let
    // `verbose` and `warning` through at the default floor and dropped
    // everything else, errors included.
    test('the default floor of verbose lets every level through', () {
      for (final level in LogLevel.values) {
        expect(
          includes(level, LogLevel.verbose),
          isTrue,
          reason: '$level was dropped at the "log everything" floor',
        );
      }
    });

    test('a floor of warning keeps warning and above, and nothing below', () {
      expect(includes(LogLevel.critical, LogLevel.warning), isTrue);
      expect(includes(LogLevel.error, LogLevel.warning), isTrue);
      expect(includes(LogLevel.warning, LogLevel.warning), isTrue);
      expect(includes(LogLevel.info, LogLevel.warning), isFalse);
      expect(includes(LogLevel.debug, LogLevel.warning), isFalse);
      expect(includes(LogLevel.verbose, LogLevel.warning), isFalse);
    });

    test('a record below the floor reaches neither the file nor the sink', () async {
      final sink = _RecordingSink();
      final observer = FileLogObserver(
        logDirectory: logDirectory.path,
        minLevel: LogLevel.warning,
        sink: sink,
      );

      observer.onLog(TalkerLog('chatter', logLevel: LogLevel.debug));
      observer.onLog(TalkerLog('careful', logLevel: LogLevel.warning));
      await observer.dispose();

      expect(sink.submitted.map((s) => s.message), ['careful']);
      expect(readLog(), isNot(contains('chatter')));
      expect(readLog(), contains('careful'));
    });
  });
}
