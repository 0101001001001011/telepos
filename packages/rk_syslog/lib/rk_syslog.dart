/// A syslog **sink**: RFC 5424 framing, RFC 5425 delivery over TLS, and a
/// bounded on-disk spool.
///
/// # What this package is, and the thing it cannot do
///
/// It takes a record that already exists and gets it framed, spooled and
/// delivered. That is the whole job.
///
/// It is **not** a way to stop writing logging calls. Whether a class logs,
/// what it logs, and which of its fields are secret are decisions made at the
/// call site, in the class itself. A native library sits below all of that and
/// never sees those classes — no wrapper around one, in any language, can
/// reach up and remove that code. Redaction in particular stays with the
/// caller: this package cannot know that a string is a PIN, and it does not
/// guess. If you came here hoping to delete logging boilerplate from every
/// Dart class, that is not something a sink can give you at either end of a
/// foreign function interface.
///
/// What it does give is worth having on its own:
///
/// - Records survive the process dying.
/// - A till whose collector is unreachable keeps selling at full speed:
///   [RkSyslogSink.submit] never waits on a network.
/// - The journal goes to whatever collector a customer already runs, because
///   it is in the format that collector already reads.
///
/// # Example
///
/// ```dart
/// final config = RkSyslogConfig(spoolDirectory: '/var/lib/telepos/syslog')
///   ..identify(hostName: 'till-01', appName: 'telepos', procId: '$pid')
///   ..facility = RkFacility.local0
///   ..set('collector_scheme', 'tls')
///   ..set('collector_host', 'logs.shop.example')
///   ..set('tls_server_fingerprint_sha256', 'a1b2...');
///
/// final opened = RkSyslogSink.open(config);
/// if (opened case RkSyslogFailure(:final status, :final detail)) {
///   // A failure is a value, never an exception out of the native stack.
///   return report(status, detail);
/// }
/// final sink = opened.valueOrThrow();
///
/// final sale = RkStructuredData()
///   ..element('sale@0').param('total', '1250.00');
/// sink.submit(
///   severity: RkSeverity.informational,
///   msgid: 'SALE',
///   structuredData: sale,
///   message: 'sale closed',
/// );
///
/// sink.flush();   // blocks: everything submitted is now on disk
/// sink.close();   // deterministic; nothing here waits for a collector
/// ```
///
/// # Rules a caller has to know
///
/// - **Failure is a value** (И144). Nothing in this package throws on a
///   native failure; see [RkSyslogResult].
/// - **Not on the interface isolate** (И145). Every call here is a foreign
///   call. [RkSyslogSink.flush] blocks on purpose.
/// - **[RkSyslogSink.close] must be called** (И146). Dart's collector does
///   not know about the spool, the worker thread or the socket.
/// - **Enums cross by name** (И147). [RkSyslogSink.verifyNameTables] checks
///   this package's tables against the loaded library rather than assuming
///   they agree.
///
/// # Delivery
///
/// In submission order, across a restart, **at least once**. Not exactly
/// once: RFC 5425 has no application-level acknowledgement, so a machine that
/// dies between writing a record to the socket and recording that it did
/// resends it. A duplicate in a journal is a nuisance; a hole is a defect.
///
/// # The spool bound
///
/// Bounded on disk, and never lossy in silence. Under `drop_oldest` the
/// oldest whole segment is deleted, the count is kept, and a record saying so
/// is written into the journal where the deleted ones were. Under `reject`
/// nothing is ever deleted and a submit past the bound comes back as
/// [RkSyslogStatus.spoolFull], so the caller decides. See the README for what
/// each of those costs.
library;

export 'src/bindings.dart' show rkSyslogLibraryFileName;
export 'src/severity.dart';
export 'src/sink.dart';
export 'src/status.dart';
export 'src/structured_data.dart' show RkSdElement, RkStructuredData;
