/// The half of the wiring that only a real native library can prove.
///
/// # Why this file is tagged, and why the tag is not a way of avoiding it
///
/// `flutter test` does not build an FFI plugin's native part. On a machine
/// with no Rust toolchain the library is simply absent, and every test here
/// would fail — not because the application is broken but because the thing
/// under test was never built. So the file is tagged `native` and
/// `dart_test.yaml` keeps it out of the default run.
///
/// The reason that is not a hole: **these tests fail when the library is
/// missing, and a CI job runs them with it built.** Without a file that goes
/// red on an absent library, a green suite says nothing about which of the two
/// paths ran — and the fallback path is green either way.
///
/// To run them:
///
/// ```sh
/// cd packages/rk_syslog/rust && cargo build --release && cd ../../..
/// export RK_SYSLOG_LIB=$PWD/packages/rk_syslog/rust/target/release/librk_syslog.so
/// flutter test --tags native --run-skipped test/native/
/// ```
///
/// `--run-skipped` is not optional: `dart_test.yaml` skips the tag
/// unconditionally, and `--tags` alone selects suites without undoing a skip.
/// The `test-native` job in `.github/workflows/ci.yml` runs exactly this.
@Tags(['native'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_syslog/rk_syslog.dart';
import 'package:telepos/core/logging/log_sink.dart';
import 'package:telepos/data/logging/syslog_log_sink.dart';

void main() {
  test('the native library is loadable at all', () {
    expect(
      RkSyslogSink.isAvailable(),
      isTrue,
      reason:
          'librk_syslog/rk_syslog.dll was not found. Build it — cargo build '
          '--release in packages/rk_syslog/rust — and point RK_SYSLOG_LIB at '
          'the artefact. RK_SYSLOG_LIB is currently '
          '${Platform.environment['RK_SYSLOG_LIB'] ?? '(unset)'}.',
    );
  });

  test('the loaded library is the version this application depends on', () {
    expect(RkSyslogSink.nativeVersion(), '0.2.1');
  });

  test('the enumerations agree across the FFI boundary (И147)', () {
    expect(RkSyslogSink.verifyNameTables(), isEmpty);
  });

  test('a panic behind the boundary comes back as a value (И144)', () {
    final result = RkSyslogSink.provokePanicForTesting();
    expect(result, isA<RkSyslogFailure<void>>());
    expect(
      (result as RkSyslogFailure<void>).status,
      RkSyslogStatus.panicked,
      reason: 'the process is still here, and the failure is a value',
    );
  });

  group('the application really writes through it', () {
    late Directory logDirectory;

    setUp(() {
      logDirectory = Directory.systemTemp.createTempSync('rk_syslog_native');
    });

    tearDown(() {
      if (logDirectory.existsSync()) {
        logDirectory.deleteSync(recursive: true);
      }
    });

    test('the sink opens, spools a record, and the bytes are on disk', () async {
      final sink = await openTeleposSyslogSink(
        logDirectory: logDirectory.path,
        environment: const {},
        timeout: const Duration(seconds: 30),
      );

      expect(
        sink.unavailableReason,
        isNull,
        reason: 'the sink did not open with the library present',
      );
      expect(sink, isA<SyslogLogSink>());

      for (var i = 0; i < 50; i++) {
        sink.submit(
          severity: LogSinkSeverity.informational,
          msgid: 'SALE',
          message: 'receipt $i closed',
        );
      }

      // close() flushes on the worker isolate before it frees the sink, so
      // everything submitted is on disk by the time this returns.
      await sink.close();

      final spool = Directory(
        '${logDirectory.path}${Platform.pathSeparator}syslog',
      );
      expect(
        spool.existsSync(),
        isTrue,
        reason: 'the spool directory was not created',
      );
      final bytes = spool
          .listSync(recursive: true)
          .whereType<File>()
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
      expect(
        bytes,
        greaterThan(0),
        reason: 'the spool is empty: no record reached the disk',
      );
    });
  });
}
