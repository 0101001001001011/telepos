//! Severity and facility, the two enumerations RFC 5424 packs into PRI.
//!
//! И147 is not decoration here. PRI is `facility * 8 + severity`, so an index
//! that shifts by one does not produce an error — it produces a log where
//! every record carries the wrong level, and nothing anywhere says so. A
//! `warning` silently becomes a `notice`, an operator's alerting rule stops
//! firing, and the first evidence is an outage nobody was paged for.
//!
//! So both cross the boundary as **names**. A name this version does not know
//! is a returned failure, not a fallback to zero.

use crate::status::{Failure, Fallible, Status};

/// RFC 5424 §6.2.1 severity, numerically 0–7.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
pub enum Severity {
    /// System is unusable.
    Emergency = 0,
    /// Action must be taken immediately.
    Alert = 1,
    /// Critical conditions.
    Critical = 2,
    /// Error conditions.
    Error = 3,
    /// Warning conditions.
    Warning = 4,
    /// Normal but significant condition.
    Notice = 5,
    /// Informational messages.
    Informational = 6,
    /// Debug-level messages.
    Debug = 7,
}

impl Severity {
    pub const ALL: [Severity; 8] = [
        Severity::Emergency,
        Severity::Alert,
        Severity::Critical,
        Severity::Error,
        Severity::Warning,
        Severity::Notice,
        Severity::Informational,
        Severity::Debug,
    ];

    pub const fn name(self) -> &'static str {
        match self {
            Severity::Emergency => "emergency",
            Severity::Alert => "alert",
            Severity::Critical => "critical",
            Severity::Error => "error",
            Severity::Warning => "warning",
            Severity::Notice => "notice",
            Severity::Informational => "informational",
            Severity::Debug => "debug",
        }
    }

    pub fn from_name(name: &str) -> Fallible<Severity> {
        Severity::ALL
            .into_iter()
            .find(|s| s.name() == name)
            .ok_or_else(|| {
                Failure::new(
                    Status::UnknownSeverity,
                    format!(
                        "severity '{name}' is not one of: {}",
                        Severity::ALL
                            .iter()
                            .map(|s| s.name())
                            .collect::<Vec<_>>()
                            .join(", ")
                    ),
                )
            })
    }
}

/// RFC 5424 §6.2.1 facility, numerically 0–23.
///
/// The names follow the ones collectors already use, because the point of
/// speaking a standard is that the other end needs no translation table. The
/// two clock-daemon facilities (9 and 15) are `cron` and `clock`; RFC 5424
/// gives both the same description and a "note 2" and no names at all, so
/// something had to be chosen and written down.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
pub enum Facility {
    /// 0 — kernel messages.
    Kern = 0,
    /// 1 — user-level messages.
    User = 1,
    /// 2 — mail system.
    Mail = 2,
    /// 3 — system daemons.
    Daemon = 3,
    /// 4 — security/authorization messages.
    Auth = 4,
    /// 5 — messages generated internally by syslogd.
    Syslog = 5,
    /// 6 — line printer subsystem.
    Lpr = 6,
    /// 7 — network news subsystem.
    News = 7,
    /// 8 — UUCP subsystem.
    Uucp = 8,
    /// 9 — clock daemon.
    Cron = 9,
    /// 10 — security/authorization messages.
    Authpriv = 10,
    /// 11 — FTP daemon.
    Ftp = 11,
    /// 12 — NTP subsystem.
    Ntp = 12,
    /// 13 — log audit.
    Audit = 13,
    /// 14 — log alert.
    Alert = 14,
    /// 15 — clock daemon (note 2).
    Clock = 15,
    /// 16 — local use 0.
    Local0 = 16,
    /// 17 — local use 1.
    Local1 = 17,
    /// 18 — local use 2.
    Local2 = 18,
    /// 19 — local use 3.
    Local3 = 19,
    /// 20 — local use 4.
    Local4 = 20,
    /// 21 — local use 5.
    Local5 = 21,
    /// 22 — local use 6.
    Local6 = 22,
    /// 23 — local use 7.
    Local7 = 23,
}

impl Facility {
    pub const ALL: [Facility; 24] = [
        Facility::Kern,
        Facility::User,
        Facility::Mail,
        Facility::Daemon,
        Facility::Auth,
        Facility::Syslog,
        Facility::Lpr,
        Facility::News,
        Facility::Uucp,
        Facility::Cron,
        Facility::Authpriv,
        Facility::Ftp,
        Facility::Ntp,
        Facility::Audit,
        Facility::Alert,
        Facility::Clock,
        Facility::Local0,
        Facility::Local1,
        Facility::Local2,
        Facility::Local3,
        Facility::Local4,
        Facility::Local5,
        Facility::Local6,
        Facility::Local7,
    ];

    pub const fn name(self) -> &'static str {
        match self {
            Facility::Kern => "kern",
            Facility::User => "user",
            Facility::Mail => "mail",
            Facility::Daemon => "daemon",
            Facility::Auth => "auth",
            Facility::Syslog => "syslog",
            Facility::Lpr => "lpr",
            Facility::News => "news",
            Facility::Uucp => "uucp",
            Facility::Cron => "cron",
            Facility::Authpriv => "authpriv",
            Facility::Ftp => "ftp",
            Facility::Ntp => "ntp",
            Facility::Audit => "audit",
            Facility::Alert => "alert",
            Facility::Clock => "clock",
            Facility::Local0 => "local0",
            Facility::Local1 => "local1",
            Facility::Local2 => "local2",
            Facility::Local3 => "local3",
            Facility::Local4 => "local4",
            Facility::Local5 => "local5",
            Facility::Local6 => "local6",
            Facility::Local7 => "local7",
        }
    }

    pub fn from_name(name: &str) -> Fallible<Facility> {
        Facility::ALL
            .into_iter()
            .find(|f| f.name() == name)
            .ok_or_else(|| {
                Failure::new(
                    Status::UnknownFacility,
                    format!("facility '{name}' is not one of the 24 in RFC 5424"),
                )
            })
    }
}

/// The PRI value RFC 5424 §6.2.1 puts between the angle brackets.
pub fn prival(facility: Facility, severity: Severity) -> u8 {
    facility as u8 * 8 + severity as u8
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn severity_names_are_pinned_to_their_numbers() {
        // The table from RFC 5424 §6.2.1, spelled out. If a variant is ever
        // inserted in the middle of the enum, this goes red — which is the
        // only reason it exists.
        let expected: &[(&str, u8)] = &[
            ("emergency", 0),
            ("alert", 1),
            ("critical", 2),
            ("error", 3),
            ("warning", 4),
            ("notice", 5),
            ("informational", 6),
            ("debug", 7),
        ];
        assert_eq!(expected.len(), Severity::ALL.len());
        for (name, value) in expected {
            let parsed = Severity::from_name(name).expect("name must resolve");
            assert_eq!(parsed as u8, *value, "severity '{name}' changed number");
        }
    }

    #[test]
    fn facility_names_are_pinned_to_their_numbers() {
        let expected: &[(&str, u8)] = &[
            ("kern", 0),
            ("user", 1),
            ("mail", 2),
            ("daemon", 3),
            ("auth", 4),
            ("syslog", 5),
            ("lpr", 6),
            ("news", 7),
            ("uucp", 8),
            ("cron", 9),
            ("authpriv", 10),
            ("ftp", 11),
            ("ntp", 12),
            ("audit", 13),
            ("alert", 14),
            ("clock", 15),
            ("local0", 16),
            ("local1", 17),
            ("local2", 18),
            ("local3", 19),
            ("local4", 20),
            ("local5", 21),
            ("local6", 22),
            ("local7", 23),
        ];
        assert_eq!(expected.len(), Facility::ALL.len());
        for (name, value) in expected {
            let parsed = Facility::from_name(name).expect("name must resolve");
            assert_eq!(parsed as u8, *value, "facility '{name}' changed number");
        }
    }

    #[test]
    fn unknown_name_is_a_failure_not_a_default() {
        // The failure mode worth guarding: an unknown severity must not
        // quietly become emergency (0) or debug (7).
        let err = Severity::from_name("warn").unwrap_err();
        assert_eq!(err.status, Status::UnknownSeverity);
        assert!(err.detail.contains("warn"));

        let err = Facility::from_name("local8").unwrap_err();
        assert_eq!(err.status, Status::UnknownFacility);
    }

    #[test]
    fn prival_matches_the_rfc_example() {
        // RFC 5424 §6.2.1: facility 4, severity 2 -> PRI 34.
        assert_eq!(prival(Facility::Auth, Severity::Critical), 34);
        // And the full range stays inside 0..=191.
        for f in Facility::ALL {
            for s in Severity::ALL {
                assert!(prival(f, s) <= 191);
            }
        }
    }
}
