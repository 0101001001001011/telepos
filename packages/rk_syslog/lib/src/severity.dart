/// Severity and facility, the two RFC 5424 enumerations.
///
/// Both cross into the native library as **names** (И147). The numbers here
/// are the ones the standard assigns and are exposed so a caller can read
/// them, not so they can be sent: PRI is `facility * 8 + severity`, and an
/// index that shifted by one would relabel every record in the journal
/// without a single error anywhere.
///
/// [RkSyslogSink.verifyNameTables] checks these tables against the loaded
/// library, which is the point of naming rather than numbering: the two sides
/// can be compared instead of assumed equal.
library;

/// RFC 5424 §6.2.1 severity.
enum RkSeverity {
  /// System is unusable.
  emergency('emergency', 0),

  /// Action must be taken immediately.
  alert('alert', 1),

  /// Critical conditions.
  critical('critical', 2),

  /// Error conditions.
  error('error', 3),

  /// Warning conditions.
  warning('warning', 4),

  /// Normal but significant condition.
  notice('notice', 5),

  /// Informational messages.
  informational('informational', 6),

  /// Debug-level messages.
  debug('debug', 7);

  const RkSeverity(this.wireName, this.code);

  /// The name that crosses the boundary.
  final String wireName;

  /// The number RFC 5424 assigns. Read it; do not send it.
  final int code;

  /// Looks a severity up by name, or `null` if there is no such severity.
  static RkSeverity? fromName(String name) {
    for (final severity in RkSeverity.values) {
      if (severity.wireName == name) return severity;
    }
    return null;
  }
}

/// RFC 5424 §6.2.1 facility.
///
/// The two clock-daemon facilities (9 and 15) are `cron` and `clock`. The
/// standard gives both the same description and no names, so the crate picked
/// the ones collectors already use and wrote them down.
enum RkFacility {
  /// 0 — kernel messages.
  kern('kern', 0),

  /// 1 — user-level messages.
  user('user', 1),

  /// 2 — mail system.
  mail('mail', 2),

  /// 3 — system daemons.
  daemon('daemon', 3),

  /// 4 — security and authorization messages.
  auth('auth', 4),

  /// 5 — messages generated internally by syslogd.
  syslog('syslog', 5),

  /// 6 — line printer subsystem.
  lpr('lpr', 6),

  /// 7 — network news subsystem.
  news('news', 7),

  /// 8 — UUCP subsystem.
  uucp('uucp', 8),

  /// 9 — clock daemon.
  cron('cron', 9),

  /// 10 — security and authorization messages, kept apart.
  authpriv('authpriv', 10),

  /// 11 — FTP daemon.
  ftp('ftp', 11),

  /// 12 — NTP subsystem.
  ntp('ntp', 12),

  /// 13 — log audit.
  audit('audit', 13),

  /// 14 — log alert.
  alert('alert', 14),

  /// 15 — clock daemon, the second one.
  clock('clock', 15),

  /// 16 — local use 0.
  local0('local0', 16),

  /// 17 — local use 1.
  local1('local1', 17),

  /// 18 — local use 2.
  local2('local2', 18),

  /// 19 — local use 3.
  local3('local3', 19),

  /// 20 — local use 4.
  local4('local4', 20),

  /// 21 — local use 5.
  local5('local5', 21),

  /// 22 — local use 6.
  local6('local6', 22),

  /// 23 — local use 7.
  local7('local7', 23);

  const RkFacility(this.wireName, this.code);

  /// The name that crosses the boundary.
  final String wireName;

  /// The number RFC 5424 assigns. Read it; do not send it.
  final int code;

  /// Looks a facility up by name, or `null` if there is no such facility.
  static RkFacility? fromName(String name) {
    for (final facility in RkFacility.values) {
      if (facility.wireName == name) return facility;
    }
    return null;
  }
}

/// The PRI value RFC 5424 puts between the angle brackets.
int rkPrival(RkFacility facility, RkSeverity severity) =>
    facility.code * 8 + severity.code;
