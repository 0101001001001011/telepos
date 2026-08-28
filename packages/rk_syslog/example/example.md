# Example

Build the native part first: `cd rust && cargo build --release`.

```dart
import 'dart:io';

import 'package:rk_syslog/rk_syslog.dart';

void main() {
  // Keys are set by name. A typo in a key stops the sink from opening rather
  // than going unnoticed.
  final config = RkSyslogConfig(spoolDirectory: '/var/lib/telepos/syslog')
    ..identify(hostName: 'till-01', appName: 'telepos', procId: '$pid')
    ..facility = RkFacility.local0
    ..set('spool_max_bytes', '33554432')   // 32 MiB
    ..set('spool_policy', 'drop_oldest')
    // A pinned fingerprint instead of a certificate authority: a collector in
    // a shop usually has none we could trust in advance.
    ..set('collector_scheme', 'tls')
    ..set('collector_host', 'logs.shop.example')
    ..set('tls_server_fingerprint_sha256',
        '5e:88:48:98:da:28:04:71:51:d0:e5:6f:8d:c6:29:27'
        ':73:60:3d:0d:6a:ab:bd:d6:2a:11:ef:72:1d:15:42:d8');

  // A failure arrives as a value, not as an exception out of a foreign stack.
  final opened = RkSyslogSink.open(config);
  if (opened case RkSyslogFailure(:final status, :final detail)) {
    stderr.writeln('sink did not open: ${status.wireName}: $detail');
    return;
  }
  final sink = opened.valueOrThrow();

  // Structured data is built, not concatenated: the native side does the
  // escaping, exactly once and per §6.3.3.
  final sale = RkStructuredData()
    ..element('sale@0').param('receipt', '000123').param('total', '1250.00')
    ..element('till@0').param('id', 'till-01');

  final submitted = sink.submit(
    severity: RkSeverity.informational,
    msgid: 'SALE',
    structuredData: sale,
    message: 'receipt closed',
  );
  // A record that cannot be framed is reported here and now, naming the
  // field — rather than disappearing on the way.
  if (submitted case RkSyslogFailure(:final detail)) {
    stderr.writeln('record not accepted: $detail');
  }

  // Nothing waited on the network while control got this far. The collector
  // can be unreachable for a week; the till keeps selling at full speed.
  print('in the spool: ${sink.stat('spool_records').valueOrNull}');
  print('sent: ${sink.stat('sent').valueOrNull}');
  print('lost at the bound: '
      '${sink.stat('spool_dropped_records').valueOrNull}');

  // The only blocking call, and it blocks only whoever called it.
  sink.flush(timeout: const Duration(seconds: 5));

  // Mandatory: Dart's garbage collector knows nothing about the spool, the
  // worker thread, or the socket.
  sink.close();
}
```

## Checking that the two sides agree

The point of enumerations crossing the boundary by name is that the
tables can be **compared**, rather than assumed identical:

```dart
final problems = RkSyslogSink.verifyNameTables();
if (problems.isNotEmpty) {
  stderr.writeln('package and library have diverged:\n${problems.join('\n')}');
}
```
