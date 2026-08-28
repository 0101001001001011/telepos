/// Tests for the Dart binding.
///
/// Two groups, on purpose. The first needs no native library and checks the
/// tables and the shapes. The second loads the library this package's crate
/// builds and drives it end to end — because a binding that has never called
/// anything has not been tested, it has been compiled.
///
/// Build the library first:
///
/// ```
/// cd rust && cargo build --release
/// ```
///
/// The tests find it under `rust/target/{release,debug}`, or wherever
/// `RK_SYSLOG_LIB` points.
library;

import 'dart:io';

import 'package:rk_syslog/rk_syslog.dart';
import 'package:test/test.dart';

/// Where the crate leaves its library after `cargo build`.
String? _builtLibrary() {
  final fromEnvironment = Platform.environment['RK_SYSLOG_LIB'];
  if (fromEnvironment != null && File(fromEnvironment).existsSync()) {
    return fromEnvironment;
  }
  final name = rkSyslogLibraryFileName();
  for (final profile in ['release', 'debug']) {
    for (final root in ['rust', '../rust', 'packages/rk_syslog/rust']) {
      final path = '$root/target/$profile/$name';
      if (File(path).existsSync()) return File(path).absolute.path;
    }
  }
  return null;
}

void main() {
  group('tables, without a native library', () {
    test('severity names and numbers are the ones RFC 5424 assigns', () {
      const expected = {
        'emergency': 0,
        'alert': 1,
        'critical': 2,
        'error': 3,
        'warning': 4,
        'notice': 5,
        'informational': 6,
        'debug': 7,
      };
      expect(RkSeverity.values.length, expected.length);
      for (final entry in expected.entries) {
        final severity = RkSeverity.fromName(entry.key);
        expect(severity, isNotNull, reason: 'no severity named ${entry.key}');
        expect(
          severity!.code,
          entry.value,
          reason: "severity '${entry.key}' changed number",
        );
      }
    });

    test('facility names and numbers are the ones RFC 5424 assigns', () {
      const expected = {
        'kern': 0,
        'user': 1,
        'mail': 2,
        'daemon': 3,
        'auth': 4,
        'syslog': 5,
        'lpr': 6,
        'news': 7,
        'uucp': 8,
        'cron': 9,
        'authpriv': 10,
        'ftp': 11,
        'ntp': 12,
        'audit': 13,
        'alert': 14,
        'clock': 15,
        'local0': 16,
        'local1': 17,
        'local2': 18,
        'local3': 19,
        'local4': 20,
        'local5': 21,
        'local6': 22,
        'local7': 23,
      };
      expect(RkFacility.values.length, expected.length);
      for (final entry in expected.entries) {
        final facility = RkFacility.fromName(entry.key);
        expect(facility, isNotNull, reason: 'no facility named ${entry.key}');
        expect(
          facility!.code,
          entry.value,
          reason: "facility '${entry.key}' changed number",
        );
      }
    });

    test('an unknown name resolves to null, never to a default', () {
      // The failure this guards: 'warn' quietly becoming emergency (0).
      expect(RkSeverity.fromName('warn'), isNull);
      expect(RkSeverity.fromName('WARNING'), isNull);
      expect(RkFacility.fromName('local8'), isNull);
    });

    test('PRI is facility times eight plus severity', () {
      expect(rkPrival(RkFacility.auth, RkSeverity.critical), 34);
      expect(rkPrival(RkFacility.local0, RkSeverity.informational), 134);
      for (final facility in RkFacility.values) {
        for (final severity in RkSeverity.values) {
          expect(rkPrival(facility, severity), lessThanOrEqualTo(191));
        }
      }
    });

    test('a status this binding has no name for is its own case', () {
      expect(RkSyslogStatus.fromName('ok'), RkSyslogStatus.ok);
      expect(RkSyslogStatus.fromName('spoolFull'), RkSyslogStatus.spoolFull);
      expect(
        RkSyslogStatus.fromName('somethingFromTheFuture'),
        RkSyslogStatus.unrecognised,
      );
      expect(RkSyslogStatus.fromName(null), RkSyslogStatus.unrecognised);
    });

    test('a failure is a value; only valueOrThrow throws', () {
      const failure = RkSyslogFailure<int>(RkSyslogStatus.spoolFull, 'full');
      expect(failure.isOk, isFalse);
      expect(failure.valueOrNull, isNull);
      expect(failure.cast<String>().status, RkSyslogStatus.spoolFull);
      expect(failure.valueOrThrow, throwsA(isA<RkSyslogException>()));

      const ok = RkSyslogOk<int>(7);
      expect(ok.isOk, isTrue);
      expect(ok.valueOrNull, 7);
      expect(ok.valueOrThrow(), 7);
    });

    test('asking whether the library is there never throws', () {
      // A web build, or a build whose native wiring has not landed, must get
      // an answer rather than a stack trace.
      expect(
        () => RkSyslogSink.isAvailable(libraryPath: 'no-such-library-anywhere'),
        returnsNormally,
      );
      final opened = RkSyslogSink.open(
        RkSyslogConfig(spoolDirectory: 'unused'),
        libraryPath: '/definitely/not/here/librk_syslog.so',
      );
      // It may still succeed if the real library is already in this process;
      // what must never happen is a throw.
      expect(opened, isA<RkSyslogResult<RkSyslogSink>>());
    });

    test('a configuration keeps what it was given, by name', () {
      final config = RkSyslogConfig(spoolDirectory: '/var/spool/x')
        ..identify(hostName: 'till-01', appName: 'telepos', procId: '9')
        ..facility = RkFacility.audit
        ..set('spool_policy', 'reject');
      expect(config.entries, {
        'spool_dir': '/var/spool/x',
        'host_name': 'till-01',
        'app_name': 'telepos',
        'proc_id': '9',
        'facility': 'audit',
        'spool_policy': 'reject',
      });
    });
  });

  group(
    'against the built native library',
    () {
      final libraryPath = _builtLibrary();

      setUpAll(() {
        if (libraryPath == null) {
          // Loud on purpose. A skipped group that nobody notices is how a
          // binding ships untested.
          stderr.writeln(
            'rk_syslog: the native library was not found. Build it with '
            '`cd rust && cargo build --release`, or set RK_SYSLOG_LIB. These '
            'tests did NOT run.',
          );
        }
      });

      test('the library reports a version', () {
        final version = RkSyslogSink.nativeVersion(libraryPath: libraryPath);
        expect(version, isNotNull);
        expect(version!.split('.'), hasLength(3));
      });

      test('this package and the library agree on every name and number', () {
        // The whole reason enums cross by name (И147): the two sides can be
        // compared rather than assumed equal.
        expect(
          RkSyslogSink.verifyNameTables(libraryPath: libraryPath),
          isEmpty,
        );
      });

      test('a panic behind the boundary comes back as a value', () {
        // И144. If it ever aborts instead, this test process dies, which is
        // unmistakable.
        final outcome = RkSyslogSink.provokePanicForTesting(
          libraryPath: libraryPath,
        );
        expect(outcome, isA<RkSyslogFailure<void>>());
        final failure = outcome as RkSyslogFailure<void>;
        expect(failure.status, RkSyslogStatus.panicked);
        expect(failure.detail, contains('panicked'));
      });

      test('opens, submits, flushes, counts and closes', () {
        final spool = Directory.systemTemp.createTempSync('rk_syslog_dart');
        addTearDown(() => spool.deleteSync(recursive: true));

        final config = RkSyslogConfig(spoolDirectory: spool.path)
          ..identify(hostName: 'till-01', appName: 'telepos', procId: '77')
          ..facility = RkFacility.audit;
        final sink = RkSyslogSink.open(
          config,
          libraryPath: libraryPath,
        ).valueOrThrow();
        addTearDown(sink.close);

        final sale = RkStructuredData()
          ..element('sale@0').param('total', '1250.00')
          ..element('till@0').param('id', 'till-01');
        final submitted = sink.submit(
          severity: RkSeverity.informational,
          msgid: 'SALE',
          structuredData: sale,
          message: 'sale closed',
          timestamp: DateTime.utc(2003, 10, 11, 22, 14, 15, 3),
        );
        expect(submitted.isOk, isTrue, reason: '$submitted');

        expect(sink.flush().isOk, isTrue);
        expect(sink.stat('submitted').valueOrThrow(), 1);
        expect(sink.stat('spooled').valueOrThrow(), 1);
        // Closed by default: no collector was configured, so nothing was sent.
        expect(sink.stat('sent').valueOrThrow(), 0);

        // The record is on disk.
        final segments = spool
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.spl'))
            .toList();
        expect(segments, isNotEmpty);
        final bytes = segments.first.readAsBytesSync();
        final text = String.fromCharCodes(bytes.skip(4));
        expect(text, startsWith('<110>1 2003-10-11T22:14:15.003000Z till-01 '));
        expect(text, contains('[sale@0 total="1250.00"][till@0 id="till-01"]'));
        expect(text, endsWith('sale closed'));
      });

      test(
        'a record that cannot be framed is refused, with the field named',
        () {
          final spool = Directory.systemTemp.createTempSync('rk_syslog_bad');
          addTearDown(() => spool.deleteSync(recursive: true));
          final sink = RkSyslogSink.open(
            RkSyslogConfig(spoolDirectory: spool.path),
            libraryPath: libraryPath,
          ).valueOrThrow();
          addTearDown(sink.close);

          final outcome = sink.submit(
            severity: RkSeverity.warning,
            msgid:
                'a msgid far longer than the thirty two bytes RFC 5424 allows',
            message: 'ignored',
          );
          expect(outcome, isA<RkSyslogFailure<void>>());
          final failure = outcome as RkSyslogFailure<void>;
          expect(failure.status, RkSyslogStatus.invalidHeaderField);
          expect(failure.detail, contains('msgid'));

          // A control character in structured data is refused too, before any of
          // it reaches the journal.
          final sd = RkStructuredData()
            ..element('note@0').param('text', 'line\nbreak');
          final second = sink.submit(
            severity: RkSeverity.warning,
            structuredData: sd,
            message: 'ignored',
          );
          expect(
            (second as RkSyslogFailure<void>).status,
            RkSyslogStatus.invalidStructuredData,
          );
        },
      );

      test('a misspelled configuration key stops the sink', () {
        final spool = Directory.systemTemp.createTempSync('rk_syslog_key');
        addTearDown(() => spool.deleteSync(recursive: true));
        final config = RkSyslogConfig(spoolDirectory: spool.path)
          ..set('spool_max_byte', '4096');
        final outcome = RkSyslogSink.open(config, libraryPath: libraryPath);
        expect(outcome, isA<RkSyslogFailure<RkSyslogSink>>());
        final failure = outcome as RkSyslogFailure<RkSyslogSink>;
        expect(failure.status, RkSyslogStatus.unknownConfigKey);
        expect(failure.detail, contains('spool_max_bytes'));
      });

      test('an unknown counter says so rather than answering zero', () {
        final spool = Directory.systemTemp.createTempSync('rk_syslog_stat');
        addTearDown(() => spool.deleteSync(recursive: true));
        final sink = RkSyslogSink.open(
          RkSyslogConfig(spoolDirectory: spool.path),
          libraryPath: libraryPath,
        ).valueOrThrow();
        addTearDown(sink.close);

        final outcome = sink.stat('recods_sent');
        expect(
          (outcome as RkSyslogFailure<int>).status,
          RkSyslogStatus.unknownStat,
        );
        expect(sink.counterNames, contains('spool_dropped_records'));
        expect(sink.configKeys, contains('spool_policy'));
      });

      test('submitting does not wait on an unreachable collector', () {
        // 192.0.2.1 is TEST-NET-1: it never answers, so a connect attempt runs
        // to the operating system's timeout. If a submit touched the network
        // this would take a minute rather than a moment.
        final spool = Directory.systemTemp.createTempSync('rk_syslog_block');
        addTearDown(() => spool.deleteSync(recursive: true));
        final config = RkSyslogConfig(spoolDirectory: spool.path)
          ..set('collector_scheme', 'tcp')
          ..set('collector_host', '192.0.2.1')
          ..set('connect_timeout_ms', '20000')
          ..set('queue_max_records', '50000');
        final sink = RkSyslogSink.open(
          config,
          libraryPath: libraryPath,
        ).valueOrThrow();
        addTearDown(sink.close);

        final watch = Stopwatch()..start();
        for (var i = 0; i < 2000; i++) {
          sink.submit(severity: RkSeverity.debug, message: 'record $i');
        }
        watch.stop();
        expect(
          watch.elapsed,
          lessThan(const Duration(seconds: 3)),
          reason: '2000 submits took ${watch.elapsed} against a black hole',
        );
      });

      test('closing twice is safe', () {
        final spool = Directory.systemTemp.createTempSync('rk_syslog_close');
        addTearDown(() => spool.deleteSync(recursive: true));
        final sink = RkSyslogSink.open(
          RkSyslogConfig(spoolDirectory: spool.path),
          libraryPath: libraryPath,
        ).valueOrThrow();
        sink.close();
        expect(sink.close, returnsNormally);
        // And a closed sink refuses rather than using a freed handle.
        final outcome = sink.submit(
          severity: RkSeverity.debug,
          message: 'too late',
        );
        expect(
          (outcome as RkSyslogFailure<void>).status,
          RkSyslogStatus.closed,
        );
      });
    },
    skip: _builtLibrary() == null
        ? 'the native library is not built; run `cd rust && cargo build '
              '--release`'
        : null,
  );
}
