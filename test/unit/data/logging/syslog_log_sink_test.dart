/// The application side of `rk_syslog`, proved without a native library.
///
/// **Read this before trusting a green run of this file.** `flutter test` does
/// not build an FFI plugin's native part, so on an ordinary machine the
/// library is absent and everything here exercises the *fallback* path. That
/// is deliberate and it is what the default suite is for. The path that goes
/// through the native library is proved by `test/native/`, which the default
/// run skips and the `test-native` CI job requires — see docs/internal/testing-notes.md.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_syslog/rk_syslog.dart';
import 'package:telepos/core/logging/log_sink.dart';
import 'package:telepos/data/logging/syslog_log_sink.dart';

void main() {
  group('buildSyslogConfig', () {
    Map<String, String> build([Map<String, String> environment = const {}]) =>
        buildSyslogConfig(
          spoolDirectory: '/var/lib/telepos/syslog',
          hostName: 'till-01',
          appName: 'telepos',
          procId: '4242',
          environment: environment,
        );

    test('is closed when nothing names a collector', () {
      final config = build();
      expect(
        config['collector_scheme'],
        'none',
        reason:
            'a fresh installation must open nothing outward, and the map has '
            'to say so rather than lean on a default that could change',
      );
      expect(config.containsKey('collector_host'), isFalse);
    });

    test('carries the three header fields and the technical log settings', () {
      final config = build();
      expect(config['spool_dir'], '/var/lib/telepos/syslog');
      expect(config['host_name'], 'till-01');
      expect(config['app_name'], 'telepos');
      expect(config['proc_id'], '4242');
      expect(config['facility'], 'local0');
      expect(config['spool_policy'], 'drop_oldest');
    });

    test('a named collector turns TLS on and carries the trust material', () {
      final config = build({
        syslogCollectorHostVar: 'logs.shop.example',
        syslogCollectorPortVar: '7514',
        syslogTlsFingerprintVar: 'a1b2c3',
      });
      expect(config['collector_scheme'], 'tls');
      expect(config['collector_host'], 'logs.shop.example');
      expect(config['collector_port'], '7514');
      expect(config['tls_server_fingerprint_sha256'], 'a1b2c3');
    });

    test('a root bundle is passed through as a path', () {
      final config = build({
        syslogCollectorHostVar: 'logs.shop.example',
        syslogTlsRootsVar: '/etc/telepos/collector-roots.pem',
      });
      expect(config['tls_roots_pem'], '/etc/telepos/collector-roots.pem');
    });

    test('a blank collector variable is not a collector', () {
      expect(build({syslogCollectorHostVar: '   '})['collector_scheme'], 'none');
    });

    test('every key it produces is one the library accepts', () {
      // The library refuses an unknown key rather than ignoring it, so a
      // misspelling here would stop the sink opening at all. These are the
      // names from packages/rk_syslog/README.md.
      const known = {
        'spool_dir',
        'host_name',
        'app_name',
        'proc_id',
        'facility',
        'spool_max_bytes',
        'spool_segment_bytes',
        'spool_policy',
        'queue_max_records',
        'queue_policy',
        'collector_scheme',
        'collector_host',
        'collector_port',
        'tls_server_name',
        'tls_roots_pem',
        'tls_server_fingerprint_sha256',
        'tls_client_cert_pem',
        'tls_client_key_pem',
        'max_message_bytes',
        'oversize',
        'msg_bom',
        'connect_timeout_ms',
        'write_timeout_ms',
        'retry_min_ms',
        'retry_max_ms',
      };
      final all = {
        ...build().keys,
        ...build({
          syslogCollectorHostVar: 'h',
          syslogCollectorPortVar: '1',
          syslogTlsRootsVar: 'r',
          syslogTlsFingerprintVar: 'f',
        }).keys,
      };
      expect(all.difference(known), isEmpty);
    });
  });

  group('RFC 5424 header fields', () {
    test('a Cyrillic hostname does not cost the whole log', () {
      // Unsanitised this makes the sink refuse to open with
      // invalidHeaderField, and the till loses its journal to a machine name.
      expect(sanitiseHeaderField('касса-01', 255), '-01');
      expect(sanitiseHeaderField('', 255), '-');
      // Nothing printable survives, so the field becomes the NILVALUE rather
      // than an empty string, which RFC 5424 does not allow.
      expect(sanitiseHeaderField('касса', 255), '-');
    });

    test('a field is cut to the length the standard allows', () {
      expect(sanitiseHeaderField('x' * 400, 255).length, 255);
    });

    test('spaces are removed: they end the field in the wire format', () {
      expect(sanitiseHeaderField('till 01', 255), 'till01');
    });

    test('a msgid is upper case, bounded at 32, and never empty', () {
      expect(sanitiseMsgid('sale'), 'SALE');
      expect(sanitiseMsgid(null), '-');
      expect(sanitiseMsgid(''), '-');
      expect(sanitiseMsgid('a' * 60).length, 32);
    });
  });

  group('the two enumerations agree by name (И147)', () {
    test('every LogSinkSeverity is a name the package knows', () {
      // The contract's enum is deliberately its own — the browser build cannot
      // see RkSeverity. The two therefore have to be checked against each
      // other, not assumed equal: submit() sends `severity.name` across.
      for (final severity in LogSinkSeverity.values) {
        expect(
          RkSeverity.fromName(severity.name),
          isNotNull,
          reason: 'rk_syslog has no severity called ${severity.name}',
        );
      }
    });

    test('and the package has no severity the contract cannot express', () {
      final ours = LogSinkSeverity.values.map((s) => s.name).toSet();
      expect(RkSeverity.values.map((s) => s.wireName).toSet(), ours);
    });
  });

  group('opening the sink', () {
    late Directory spool;

    setUp(() {
      spool = Directory.systemTemp.createTempSync('syslog_sink');
    });

    tearDown(() {
      if (spool.existsSync()) spool.deleteSync(recursive: true);
    });

    test('never throws, and always yields a usable LogSink', () async {
      // Holds whichever way it went: with a library it opens, without one it
      // comes back unavailable. Neither is an exception in the caller, and in
      // both cases submit and close are safe to call.
      final sink = await openTeleposSyslogSink(
        logDirectory: spool.path,
        environment: const {},
        timeout: const Duration(seconds: 20),
      );
      expect(
        () => sink.submit(
          severity: LogSinkSeverity.informational,
          msgid: 'TEST',
          message: 'hello',
        ),
        returnsNormally,
      );
      await sink.close();
      // Closing twice is the shutdown path when something already closed it.
      await sink.close();
    });

    test('a configuration with no spool directory is refused, not guessed', () async {
      final sink = await openSyslogSink(
        config: const {'spool_dir': ''},
        timeout: const Duration(seconds: 20),
      );
      expect(sink.unavailableReason, contains('spool_dir'));
    });

    test('an unavailable sink names why, and does nothing quietly', () async {
      const sink = UnavailableLogSink('there is no native library here');
      expect(sink.unavailableReason, 'there is no native library here');
      expect(
        () => sink.submit(
          severity: LogSinkSeverity.error,
          message: 'the till still sells',
        ),
        returnsNormally,
      );
      await sink.close();
    });
  });
}
