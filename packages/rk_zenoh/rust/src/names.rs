//! Enums cross the boundary by name (И147).
//!
//! Not one of these is passed as an index. An index is a promise that nobody
//! ever inserts a case in the middle of a list, and upstream makes no such
//! promise: `Priority` alone has seven cases whose order is an implementation
//! detail. A name that no longer exists fails loudly as `unknown_enum_name`;
//! an index that no longer means what it did fails silently, months later, as
//! a receipt printed at the wrong priority.

use zenoh::qos::{CongestionControl, Priority};
use zenoh::sample::SampleKind;

use crate::status::{ErrorKind, RkzError, RkzResult};

fn unknown(what: &str, got: &str) -> RkzError {
    RkzError::new(
        ErrorKind::UnknownEnumName,
        format!("{what} has no case named {got:?}"),
    )
}

/// `"drop"` or `"block"`.
pub fn congestion_control(name: &str) -> RkzResult<CongestionControl> {
    match name {
        "drop" => Ok(CongestionControl::Drop),
        "block" => Ok(CongestionControl::Block),
        other => Err(unknown("congestion control", other)),
    }
}

/// One of the seven Zenoh priorities, in `snake_case`.
pub fn priority(name: &str) -> RkzResult<Priority> {
    match name {
        "real_time" => Ok(Priority::RealTime),
        "interactive_high" => Ok(Priority::InteractiveHigh),
        "interactive_low" => Ok(Priority::InteractiveLow),
        "data_high" => Ok(Priority::DataHigh),
        "data" => Ok(Priority::Data),
        "data_low" => Ok(Priority::DataLow),
        "background" => Ok(Priority::Background),
        other => Err(unknown("priority", other)),
    }
}

// Reliability is deliberately absent. `zenoh::qos::Reliability` is gated
// behind the crate's `unstable` feature in 1.9.0 — verified by compiling
// against it — so this package cannot offer a per-message reliability choice
// without leaving the stable subset. Callers get Zenoh's default.

/// The name a sample kind carries back out, NUL-terminated for C.
pub fn sample_kind_name(kind: SampleKind) -> &'static str {
    match kind {
        SampleKind::Put => "put\0",
        SampleKind::Delete => "delete\0",
    }
}

/// `"peer"`, `"client"` or `"router"` — validated here so a typo in a
/// configuration is refused at the boundary instead of quietly defaulting.
pub fn session_mode(name: &str) -> RkzResult<&'static str> {
    match name {
        "peer" => Ok("peer"),
        "client" => Ok("client"),
        "router" => Ok("router"),
        other => Err(unknown("session mode", other)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_priority_name_round_trips_to_a_distinct_case() {
        let names = [
            "real_time",
            "interactive_high",
            "interactive_low",
            "data_high",
            "data",
            "data_low",
            "background",
        ];
        let mut seen = std::collections::HashSet::new();
        for name in names {
            let p = priority(name).unwrap_or_else(|_| panic!("{name} must parse"));
            assert!(
                seen.insert(format!("{p:?}")),
                "{name} collided with an earlier case"
            );
        }
        assert_eq!(seen.len(), 7);
    }

    #[test]
    fn an_unknown_name_is_refused_rather_than_defaulted() {
        for err in [
            priority("urgent").unwrap_err(),
            congestion_control("Drop").unwrap_err(),
            congestion_control("").unwrap_err(),
            session_mode("gateway").unwrap_err(),
        ] {
            assert_eq!(err.kind, ErrorKind::UnknownEnumName);
        }
    }

    #[test]
    fn sample_kind_names_are_nul_terminated() {
        assert_eq!(sample_kind_name(SampleKind::Put), "put\0");
        assert_eq!(sample_kind_name(SampleKind::Delete), "delete\0");
    }
}
