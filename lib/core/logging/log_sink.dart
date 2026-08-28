/// Where a log record goes **besides** the local file.
///
/// This file is the seam between the application's logging and whatever
/// delivers records off the machine. It is deliberately poor: pure Dart, no
/// `dart:io`, no `dart:ffi`, no Flutter, no `package:rk_*`. That is what lets
/// `lib/core/logging/` stay compilable for a browser while the thing that
/// implements it — `lib/data/logging/syslog_log_sink.dart` — is a Rust library
/// behind `dart:ffi` (И143, section 3а).
///
/// **A sink is not a logger and not a facade.** Nothing here removes a
/// logging call from a call site, and nothing here masks anything: a sink is
/// handed a record that already exists, and it does not know that a string is
/// a PIN. Masking stays where the record is written, which is the only place
/// that knows what the fields mean. Section 15 (И68) is therefore *not*
/// answered by anything in this file.
library;

/// RFC 5424 §6.2.1 severity.
///
/// Named here rather than imported from the package that implements delivery,
/// so that a caller of [LogSink] — including one compiled for a browser, where
/// no implementation exists at all — needs nothing native to name a severity.
enum LogSinkSeverity {
  /// System is unusable.
  emergency,

  /// Action must be taken immediately.
  alert,

  /// Critical conditions.
  critical,

  /// Error conditions.
  error,

  /// Warning conditions.
  warning,

  /// Normal but significant condition.
  notice,

  /// Informational messages.
  informational,

  /// Debug-level messages.
  debug,
}

/// A destination for log records.
///
/// # What an implementation must promise
///
/// [submit] **never throws and never blocks.** Logging is not on the money
/// path and must not become so: a collector that is unreachable, a disk that
/// is full, or a native library that failed to load are all conditions under
/// which the till goes on selling and this sink goes on returning quietly.
/// There is no return value for the same reason — a caller in the middle of
/// closing a receipt has nothing useful to do with one.
abstract interface class LogSink {
  /// Why this sink delivers nothing, or `null` when it delivers.
  ///
  /// A sink that silently does nothing and says nothing is the defect this
  /// property exists to prevent: the application writes this string into the
  /// local file at startup, so "the syslog sink is off" is a sentence someone
  /// can read rather than a silence someone has to notice.
  String? get unavailableReason;

  /// Hands over one record. Does not block, does not throw.
  void submit({
    required LogSinkSeverity severity,
    String? msgid,
    String? message,
  });

  /// Releases whatever the sink owns.
  Future<void> close();
}

/// The sink used when there is no delivery — a browser, a build whose native
/// library did not load, an installation with no collector configured.
///
/// [submit] does nothing **on purpose**, and that is not the "plausible value
/// from a stub" defect: the reason it does nothing is carried in
/// [unavailableReason] and printed, so the state is stated rather than
/// impersonated.
class UnavailableLogSink implements LogSink {
  const UnavailableLogSink(this.unavailableReason);

  @override
  final String unavailableReason;

  @override
  void submit({
    required LogSinkSeverity severity,
    String? msgid,
    String? message,
  }) {}

  @override
  Future<void> close() async {}
}
