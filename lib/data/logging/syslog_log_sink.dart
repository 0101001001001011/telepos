/// The [LogSink] that delivers records through `rk_syslog`.
///
/// # Why this file is in `lib/data/`
///
/// It imports `package:rk_syslog`, which imports `dart:ffi`, which does not
/// exist in a browser. Section 3а puts native code strictly below the
/// contract, and И143 is checked by `flutter build web -t lib/web/main_web.dart`:
/// nothing above this layer may name this file. The contract it implements —
/// `lib/core/logging/log_sink.dart` — is pure Dart and is what shared code
/// sees.
///
/// # Why an isolate
///
/// И145: no call into a native library runs on the interface isolate. That is
/// not a formality here. [RkSyslogSink.open] creates the spool directory,
/// reads a certificate bundle and starts a worker thread — real blocking work,
/// at startup, on the isolate that draws the till. So the sink is *owned* by a
/// worker isolate and reached over a port; an FFI handle cannot cross an
/// isolate boundary, so the sink has to be opened on the far side rather than
/// passed there.
///
/// # What this does not do
///
/// It does not mask anything (И68 stays open), it carries no correlation
/// identifier (И69 stays open), and there is no audit chain anywhere in this
/// application (И66, И67 stay open). This is a transport for records that
/// already exist. See `docs/system-architecture.md` section 15.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:rk_syslog/rk_syslog.dart';
import 'package:telepos/core/logging/log_sink.dart';

/// Environment variables that point the technical log at a collector.
///
/// There is no settings table for this yet, and inventing one would be a
/// screen nobody asked for. Section 15 says an external collector is used
/// "if the customer named one"; until the interface can name one, the
/// environment is where it is named — and by default nothing is named, so
/// nothing is opened outward.
const String syslogCollectorHostVar = 'TELEPOS_SYSLOG_COLLECTOR_HOST';

/// The collector's port. Defaults to the package's own default (6514).
const String syslogCollectorPortVar = 'TELEPOS_SYSLOG_COLLECTOR_PORT';

/// Path to a PEM bundle of roots the collector's certificate is verified
/// against.
const String syslogTlsRootsVar = 'TELEPOS_SYSLOG_TLS_ROOTS_PEM';

/// A pinned SHA-256 fingerprint of the collector's certificate, as an
/// alternative to a root bundle.
const String syslogTlsFingerprintVar = 'TELEPOS_SYSLOG_TLS_FINGERPRINT';

/// Builds the settings the native sink is opened with.
///
/// A pure function on purpose: it is the part of this file that can be proved
/// on a machine with no Rust toolchain, and the part where a wrong answer is
/// silent. **Closed by default** — with no collector named the map says
/// `collector_scheme: none` explicitly rather than leaning on the package's
/// default, so reading the map answers the question.
Map<String, String> buildSyslogConfig({
  required String spoolDirectory,
  required String hostName,
  required String appName,
  required String procId,
  Map<String, String> environment = const <String, String>{},
}) {
  final config = <String, String>{
    'spool_dir': spoolDirectory,
    'host_name': sanitiseHeaderField(hostName, 255),
    'app_name': sanitiseHeaderField(appName, 48),
    'proc_id': sanitiseHeaderField(procId, 128),
    // The technical log of section 15: debugging and device work, rotated,
    // and the one of the three logs that may lose its oldest records rather
    // than refuse new ones. Audit and security are `reject`, and neither
    // exists in this application yet.
    'facility': RkFacility.local0.wireName,
    'spool_policy': 'drop_oldest',
  };

  final host = (environment[syslogCollectorHostVar] ?? '').trim();
  if (host.isEmpty) {
    // Stated, not defaulted.
    config['collector_scheme'] = 'none';
    return config;
  }

  config['collector_scheme'] = 'tls';
  config['collector_host'] = host;

  final port = (environment[syslogCollectorPortVar] ?? '').trim();
  if (port.isNotEmpty) config['collector_port'] = port;

  final roots = (environment[syslogTlsRootsVar] ?? '').trim();
  if (roots.isNotEmpty) config['tls_roots_pem'] = roots;

  final fingerprint = (environment[syslogTlsFingerprintVar] ?? '').trim();
  if (fingerprint.isNotEmpty) {
    config['tls_server_fingerprint_sha256'] = fingerprint;
  }

  // Neither a bundle nor a fingerprint is deliberately left to the package to
  // refuse: it owns that rule, and two places enforcing it is one place too
  // many to keep in step.
  return config;
}

/// Cuts a string down to what RFC 5424 §6.2 allows in a header field:
/// printable ASCII, no spaces, bounded length.
///
/// A machine whose name carries a Cyrillic letter is ordinary in this
/// product's market, and an unsanitised one would make the sink refuse to open
/// with `invalidHeaderField` — a whole log lost to a hostname.
String sanitiseHeaderField(String value, int maxLength) {
  final buffer = StringBuffer();
  for (final unit in value.codeUnits) {
    if (unit >= 33 && unit <= 126) buffer.writeCharCode(unit);
    if (buffer.length >= maxLength) break;
  }
  final out = buffer.toString();
  return out.isEmpty ? '-' : out;
}

/// Cuts a talker title down to something RFC 5424 accepts as a MSGID.
///
/// Same rules as a header field, bounded at 32 (§6.2.7).
String sanitiseMsgid(String? title) {
  if (title == null || title.isEmpty) return '-';
  return sanitiseHeaderField(title.toUpperCase(), 32);
}

/// Opens the technical log's sink for this installation.
///
/// Never throws and never returns null: an installation with no native
/// library, or one whose collector settings the library refuses, gets an
/// [UnavailableLogSink] carrying the reason, and the application goes on
/// writing its local file exactly as before.
Future<LogSink> openTeleposSyslogSink({
  required String logDirectory,
  Map<String, String>? environment,
  Duration timeout = const Duration(seconds: 10),
}) async {
  String hostName;
  try {
    hostName = Platform.localHostname;
  } on Object {
    hostName = '-';
  }
  final config = buildSyslogConfig(
    spoolDirectory: '$logDirectory${Platform.pathSeparator}syslog',
    hostName: hostName,
    appName: 'telepos',
    procId: '$pid',
    environment: environment ?? Platform.environment,
  );
  return openSyslogSink(config: config, timeout: timeout);
}

/// Starts the worker isolate that owns the native sink.
Future<LogSink> openSyslogSink({
  required Map<String, String> config,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final responses = ReceivePort();
  final Isolate isolate;
  try {
    isolate = await Isolate.spawn(
      syslogWorkerMain,
      <Object?>[responses.sendPort, config],
      onError: responses.sendPort,
      onExit: responses.sendPort,
      debugName: 'rk_syslog',
    );
  } on Object catch (error) {
    responses.close();
    return UnavailableLogSink(
      'the syslog isolate could not be started: $error',
    );
  }

  final firstReply = Completer<Object?>();
  final subscription = responses.listen((message) {
    if (!firstReply.isCompleted) firstReply.complete(message);
  });

  Object? first;
  try {
    first = await firstReply.future.timeout(timeout);
  } on TimeoutException {
    await subscription.cancel();
    responses.close();
    isolate.kill(priority: Isolate.immediate);
    return UnavailableLogSink(
      'the syslog sink did not answer within ${timeout.inSeconds}s',
    );
  }

  if (first is SendPort) {
    return SyslogLogSink._(first, isolate, responses, subscription);
  }

  await subscription.cancel();
  responses.close();
  isolate.kill(priority: Isolate.immediate);
  return UnavailableLogSink(_describeFailure(first));
}

String _describeFailure(Object? reply) => switch (reply) {
  final String reason => 'the syslog sink did not open: $reason',
  null => 'the syslog isolate exited without answering',
  final List<Object?> error =>
    'the syslog isolate failed: ${error.isEmpty ? 'no detail' : error.first}',
  _ => 'the syslog isolate answered with something unexpected: $reply',
};

/// A sink whose records are handed to a worker isolate.
///
/// [submit] is a port send: it copies a small list and returns. It does not
/// wait for the worker, let alone for a disk or a collector — logging is not
/// on the money path and this is where that is kept true.
class SyslogLogSink implements LogSink {
  SyslogLogSink._(
    this._commands,
    this._isolate,
    this._responses,
    this._subscription,
  );

  final SendPort _commands;
  final Isolate _isolate;
  final ReceivePort _responses;
  final StreamSubscription<Object?> _subscription;
  bool _closed = false;

  @override
  String? get unavailableReason => null;

  @override
  void submit({
    required LogSinkSeverity severity,
    String? msgid,
    String? message,
  }) {
    if (_closed) return;
    try {
      _commands.send(<Object?>[
        _submitCommand,
        severity.name,
        sanitiseMsgid(msgid),
        message,
      ]);
    } on Object {
      // A closed port is the only way this fails, and a log record is not
      // worth an exception in whoever was logging.
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final done = ReceivePort();
    try {
      _commands.send(<Object?>[_closeCommand, done.sendPort]);
      await done.first.timeout(const Duration(seconds: 5));
    } on Object {
      // Whatever went wrong, the isolate is killed below regardless.
    } finally {
      done.close();
      await _subscription.cancel();
      _responses.close();
      _isolate.kill(priority: Isolate.beforeNextEvent);
    }
  }
}

const String _submitCommand = 'submit';
const String _closeCommand = 'close';

/// The worker isolate: it owns the native sink and nothing else.
///
/// Top-level, because [Isolate.spawn] takes nothing else. Every failure inside
/// is answered with a sentence on [SendPort] rather than a throw — an
/// exception here would reach nobody (И144 in the shape this application can
/// observe it).
void syslogWorkerMain(List<Object?> boot) {
  final reply = boot[0]! as SendPort;
  final config = (boot[1]! as Map<Object?, Object?>).cast<String, String>();

  RkSyslogSink? sink;
  try {
    final spool = config['spool_dir'] ?? '';
    if (spool.isEmpty) {
      reply.send('spool_dir was not set');
      return;
    }
    final settings = RkSyslogConfig(spoolDirectory: spool);
    for (final entry in config.entries) {
      if (entry.key == 'spool_dir') continue;
      settings.set(entry.key, entry.value);
    }
    final opened = RkSyslogSink.open(settings);
    if (opened case RkSyslogFailure(:final status, :final detail)) {
      reply.send('${status.wireName}${detail.isEmpty ? '' : ': $detail'}');
      return;
    }
    sink = opened.valueOrNull;
  } on Object catch (error) {
    reply.send('opening the sink threw: $error');
    return;
  }

  if (sink == null) {
    reply.send('the sink reported success and produced nothing');
    return;
  }
  final live = sink;

  final commands = ReceivePort();
  reply.send(commands.sendPort);

  commands.listen((message) {
    final parts = message as List<Object?>;
    switch (parts[0]) {
      case _submitCommand:
        final severity = RkSeverity.fromName(parts[1]! as String);
        if (severity == null) return;
        try {
          live.submit(
            severity: severity,
            msgid: parts[2] as String?,
            message: parts[3] as String?,
          );
        } on Object {
          // Framing failures come back as values; anything that still throws
          // must not take the worker down with it.
        }
      case _closeCommand:
        try {
          live.flush();
        } on Object {
          // Nothing useful to do: the close below happens either way.
        }
        live.close();
        (parts[1]! as SendPort).send(null);
        commands.close();
    }
  });
}
