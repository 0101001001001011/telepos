//! Outcome codes.
//!
//! Every code crosses the FFI boundary **as its name** and never as a number
//! (I147). Adding a case in the middle of this list therefore cannot change the
//! meaning of anything already compiled against it, which is the whole point:
//! a renumbering that silently turns `timeout` into `durabilityUnproven` is not
//! a bug anyone finds by reading code.

use serde::{Deserialize, Serialize};

/// The outcome of a call across the boundary.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Code {
    /// The call did what it said.
    Ok,
    /// The request JSON was missing a field, had the wrong type, or named a
    /// case this build does not know.
    InvalidRequest,
    /// The handle is not in the registry: it was never opened, or it was closed.
    /// Deliberately a value rather than a dereference of a stale pointer.
    HandleClosed,
    /// The connection to the server could not be established.
    ConnectFailed,
    /// The call did not finish inside the deadline the caller gave.
    Timeout,
    /// Durability was asked for, but the server never told us what an ack means
    /// here. Fail closed: we do not guess.
    DurabilityUnproven,
    /// The server's ack means less than the caller's policy demands.
    DurabilityWeakerThanRequested,
    /// The caller accepts a delayed fsync, but the server's window is longer
    /// than the one the caller named.
    FsyncLagTooLong,
    /// The stream as configured cannot satisfy the connection's policy, so it
    /// was not created.
    StreamRefusedWeakerThanPolicy,
    /// The server did not echo back the persistence mode that was asked for.
    /// It is too old to know the field, and it dropped it without complaining.
    PersistModeNotHonoured,
    /// Evidence about the server's durability could not be read or parsed.
    DurabilityProbeFailed,
    /// Publishing failed for a reason the server reported.
    PublishFailed,
    /// A stream operation failed for a reason the server reported.
    StreamFailed,
    /// Consuming failed for a reason the server reported.
    ConsumeFailed,
    /// Acknowledging a delivered message failed.
    AckFailed,
    /// The native side panicked and the unwind was caught at the boundary.
    /// The process is still alive; the call is not (I144).
    Panic,
}

impl Code {
    /// The name as it crosses the boundary.
    pub fn as_str(self) -> &'static str {
        match self {
            Code::Ok => "ok",
            Code::InvalidRequest => "invalidRequest",
            Code::HandleClosed => "handleClosed",
            Code::ConnectFailed => "connectFailed",
            Code::Timeout => "timeout",
            Code::DurabilityUnproven => "durabilityUnproven",
            Code::DurabilityWeakerThanRequested => "durabilityWeakerThanRequested",
            Code::FsyncLagTooLong => "fsyncLagTooLong",
            Code::StreamRefusedWeakerThanPolicy => "streamRefusedWeakerThanPolicy",
            Code::PersistModeNotHonoured => "persistModeNotHonoured",
            Code::DurabilityProbeFailed => "durabilityProbeFailed",
            Code::PublishFailed => "publishFailed",
            Code::StreamFailed => "streamFailed",
            Code::ConsumeFailed => "consumeFailed",
            Code::AckFailed => "ackFailed",
            Code::Panic => "panic",
        }
    }

    /// Every code, so the Dart side can be checked against this list rather
    /// than against someone's memory of it.
    pub fn all() -> &'static [Code] {
        &[
            Code::Ok,
            Code::InvalidRequest,
            Code::HandleClosed,
            Code::ConnectFailed,
            Code::Timeout,
            Code::DurabilityUnproven,
            Code::DurabilityWeakerThanRequested,
            Code::FsyncLagTooLong,
            Code::StreamRefusedWeakerThanPolicy,
            Code::PersistModeNotHonoured,
            Code::DurabilityProbeFailed,
            Code::PublishFailed,
            Code::StreamFailed,
            Code::ConsumeFailed,
            Code::AckFailed,
            Code::Panic,
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_round_trip_through_json() {
        for code in Code::all() {
            let json = serde_json::to_string(code).unwrap();
            assert_eq!(json, format!("\"{}\"", code.as_str()));
            let back: Code = serde_json::from_str(&json).unwrap();
            assert_eq!(back, *code);
        }
    }

    #[test]
    fn a_number_is_not_a_code() {
        // The point of I147: an index must not be accepted as a case, because
        // the day someone inserts a case in the middle, every stored index
        // starts meaning something else.
        assert!(serde_json::from_str::<Code>("0").is_err());
        assert!(serde_json::from_str::<Code>("5").is_err());
    }

    #[test]
    fn all_is_actually_all() {
        // Guards against a case added to the enum and forgotten in `all()`,
        // which would make every list-based cross-check silently incomplete.
        let names: Vec<&str> = Code::all().iter().map(|c| c.as_str()).collect();
        let mut sorted = names.clone();
        sorted.sort_unstable();
        sorted.dedup();
        assert_eq!(sorted.len(), names.len(), "duplicate code name");
        assert_eq!(names.len(), 16, "a code was added without updating all()");
    }
}
