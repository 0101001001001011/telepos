//! What a JetStream acknowledgement actually means, and whether the caller
//! agreed to it.
//!
//! This module is pure: no sockets, no clock, no globals. Everything it decides
//! is a function of two things the caller can print — what the server said about
//! itself, and how the stream is configured. That is deliberate. A durability
//! rule that can only be exercised against a live server is a rule nobody
//! exercises.
//!
//! # Why this module exists
//!
//! Jepsen's audit of NATS 2.12.1 (`jepsen.io/analyses/nats-2.12.1`, 2025-12-08)
//! found that JetStream acknowledges a write to the client immediately but
//! fsyncs on a timer. A coordinated power-failure test lost 131 418 of 930 005
//! acknowledged messages — about 14 %. That is nats-server#7564, still open.
//!
//! Measured here on 2026-07-31 against real servers, not read from a blog:
//!
//! | Server | `sync_interval` | `sync_always` |
//! | --- | --- | --- |
//! | 2.11.0, default config | 120 000 000 000 ns (2 min) | absent |
//! | 2.14.4, default config | 120 000 000 000 ns (2 min) | absent |
//! | 2.14.4, `sync_interval: "always"` | 120 000 000 000 ns (2 min) | `true` |
//!
//! Read that third row twice. **Turning fsync-on-write on does not change
//! `sync_interval`.** A probe that reads `sync_interval` and concludes "two
//! minutes, unsafe" is wrong on exactly the servers that are safe. `sync_always`
//! is the field that decides, and `sync_interval` only bounds the lag when
//! `sync_always` is false.
//!
//! The second trap is per-stream. nats-server 2.14 accepts `persist_mode` on a
//! stream; `"async"` is documented as "acknowledgement may be sent before
//! message is stored". Measured on one box, loopback, one replica, 500
//! sequential publish-and-await-ack:
//!
//! | Server config | stream `persist_mode` | msg/s |
//! | --- | --- | --- |
//! | default | default | 2 902 |
//! | default | async | 4 137 |
//! | `sync_interval: always` | default | **158** |
//! | `sync_interval: always` | async | 4 198 |
//!
//! An `async` stream on a fsync-always server runs at the speed of a server
//! that is not syncing at all. So `persist_mode: async` defeats `sync_always`,
//! and it does so silently — the ack looks identical. That is the precise shape
//! of "acknowledged that does not mean on disk", and it is why the stream's
//! persistence mode is an input to this decision and not a detail of setup.
//!
//! And the third: 2.11.0 accepts a stream created with `persist_mode: "async"`
//! and echoes the field back **absent**, with no error. Absence therefore does
//! not mean "default mode"; it means "default mode, or a server that has never
//! heard of the field". Only the `async` echo is informative, which is why
//! support is detected by asking for `async` and looking, never by comparing
//! version strings.

use serde::{Deserialize, Serialize};

use crate::codes::Code;

/// How a stream stores its messages. Crosses the boundary by name (I147).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum Storage {
    /// On disk. The only setting for which durability is even a question.
    #[default]
    File,
    /// In the server's memory. Survives nothing.
    Memory,
}

/// A stream's persistence mode, as nats-server 2.14 understands it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum PersistMode {
    /// The server's own default: the write is issued before the ack.
    #[default]
    Default,
    /// The ack may be sent before the message is stored. Faster, and worth
    /// exactly nothing to anyone counting money.
    Async,
}

/// What the caller demands an ack to mean. Crosses the boundary by name.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum Policy {
    /// **The default.** An ack means the message is fsynced to disk. Requires
    /// a server started with `sync_interval: "always"`, file storage, and a
    /// stream that is not in async persistence mode. If we cannot prove all
    /// three, the publish is refused rather than performed.
    #[default]
    FsyncOnAck,
    /// An ack means the server has written the message but may not have fsynced
    /// it yet. The caller must name the lag it is willing to lose, and the
    /// server's own window is checked against that number. Choosing this is
    /// choosing to lose up to that much on a power cut.
    FlushOnAck,
    /// An ack means the server has the message somewhere in RAM and nothing
    /// more. Named this way on purpose: the name is the warning.
    AckIsMemoryOnly,
}

/// What an ack means, given the server and the stream. Crosses by name.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AckMeaning {
    /// Nobody asked the server, or the answer could not be read. Satisfies
    /// nothing except a policy that promises nothing.
    Unknown,
    /// The message is on disk and fsynced before the ack was sent.
    FsyncedToDisk,
    /// The message was written; the fsync happens on the server's timer.
    WrittenNotFsynced,
    /// The stream acks before storing. The ack carries no information about
    /// the message's whereabouts.
    AckedBeforeStore,
    /// The stream lives in memory.
    MemoryOnly,
}

impl AckMeaning {
    /// The name as it crosses the boundary.
    pub fn as_str(self) -> &'static str {
        match self {
            AckMeaning::Unknown => "unknown",
            AckMeaning::FsyncedToDisk => "fsyncedToDisk",
            AckMeaning::WrittenNotFsynced => "writtenNotFsynced",
            AckMeaning::AckedBeforeStore => "ackedBeforeStore",
            AckMeaning::MemoryOnly => "memoryOnly",
        }
    }

    /// Every meaning, in a fixed order, so the Dart mirror can be compared
    /// against this list rather than against a person's recollection.
    pub fn all() -> &'static [AckMeaning] {
        &[
            AckMeaning::Unknown,
            AckMeaning::FsyncedToDisk,
            AckMeaning::WrittenNotFsynced,
            AckMeaning::AckedBeforeStore,
            AckMeaning::MemoryOnly,
        ]
    }
}

impl Policy {
    /// The name as it crosses the boundary.
    pub fn as_str(self) -> &'static str {
        match self {
            Policy::FsyncOnAck => "fsyncOnAck",
            Policy::FlushOnAck => "flushOnAck",
            Policy::AckIsMemoryOnly => "ackIsMemoryOnly",
        }
    }

    /// Every policy, in a fixed order. Same reason as `AckMeaning::all`.
    pub fn all() -> &'static [Policy] {
        &[
            Policy::FsyncOnAck,
            Policy::FlushOnAck,
            Policy::AckIsMemoryOnly,
        ]
    }
}

/// What a server said about its own durability, distilled from `varz`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerDurability {
    /// The server's version string, reported for the record, not used to decide
    /// anything. Behaviour is detected, not inferred from a number.
    pub version: String,
    /// True when the server was started with `sync_interval: "always"`.
    /// This, and only this, is what makes an ack mean fsynced.
    pub sync_always: bool,
    /// The server's fsync timer, in nanoseconds. Meaningful only when
    /// `sync_always` is false — see the module comment.
    pub sync_interval_nanos: u64,
    /// Where the server keeps its store, recorded so a diagnostic can say
    /// which filesystem the promise depends on.
    pub store_dir: String,
}

/// Reads the durability facts out of a `varz` document.
///
/// Accepts both shapes it can arrive in: the monitoring endpoint returns the
/// varz object itself, while `$SYS.REQ.SERVER.PING.VARZ` wraps it in
/// `{"server": ..., "data": {...}}`. Both were captured from a live 2.14.4 and
/// both are in `fixtures/`.
pub fn parse_varz(json: &str) -> Result<ServerDurability, String> {
    let root: serde_json::Value =
        serde_json::from_str(json).map_err(|e| format!("varz is not JSON: {e}"))?;
    let varz = root.get("data").unwrap_or(&root);

    let version = varz
        .get("version")
        .and_then(|v| v.as_str())
        .ok_or("varz has no version")?
        .to_string();

    let config = varz
        .get("jetstream")
        .and_then(|j| j.get("config"))
        .ok_or("varz has no jetstream.config: JetStream is not enabled on this server")?;

    // Absent means false. That is the server's own encoding (`omitempty`), and
    // reading it as "unknown" would refuse every safe server that happens to be
    // unsafe-by-default, which is all of them.
    let sync_always = config
        .get("sync_always")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let sync_interval_nanos = config
        .get("sync_interval")
        .and_then(|v| v.as_u64())
        .unwrap_or(0);

    let store_dir = config
        .get("store_dir")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    Ok(ServerDurability {
        version,
        sync_always,
        sync_interval_nanos,
        store_dir,
    })
}

/// What an ack means on this server, for a stream configured this way.
///
/// The order of the tests is the substance. A stream that acks before storing
/// tells you nothing about disks, no matter how the server is configured — so
/// that test comes before the one that looks at `sync_always`, and a caller
/// cannot buy safety back by fixing the server alone.
pub fn ack_meaning(
    server: Option<&ServerDurability>,
    storage: Storage,
    persist: PersistMode,
) -> AckMeaning {
    let Some(server) = server else {
        return AckMeaning::Unknown;
    };
    if storage == Storage::Memory {
        return AckMeaning::MemoryOnly;
    }
    if persist == PersistMode::Async {
        return AckMeaning::AckedBeforeStore;
    }
    if server.sync_always {
        return AckMeaning::FsyncedToDisk;
    }
    AckMeaning::WrittenNotFsynced
}

/// Whether a caller who asked for `policy` may be given an ack that means
/// `meaning`, and if not, which failure to return.
///
/// `accepted_lag_nanos` is only consulted for `FlushOnAck`, where the caller
/// has said out loud how much unsynced data it is prepared to lose.
pub fn gate(
    policy: Policy,
    meaning: AckMeaning,
    accepted_lag_nanos: u64,
    server: Option<&ServerDurability>,
) -> Option<Code> {
    match policy {
        // Promises nothing, so nothing can violate it. This is the escape
        // hatch, and it is spelled out loud.
        Policy::AckIsMemoryOnly => None,

        Policy::FsyncOnAck => match meaning {
            AckMeaning::FsyncedToDisk => None,
            AckMeaning::Unknown => Some(Code::DurabilityUnproven),
            _ => Some(Code::DurabilityWeakerThanRequested),
        },

        Policy::FlushOnAck => match meaning {
            AckMeaning::FsyncedToDisk => None,
            AckMeaning::Unknown => Some(Code::DurabilityUnproven),
            AckMeaning::WrittenNotFsynced => {
                // The server's window is only knowable when we have the server.
                let window = server.map(|s| s.sync_interval_nanos).unwrap_or(u64::MAX);
                if window > accepted_lag_nanos {
                    Some(Code::FsyncLagTooLong)
                } else {
                    None
                }
            }
            AckMeaning::AckedBeforeStore | AckMeaning::MemoryOnly => {
                Some(Code::DurabilityWeakerThanRequested)
            }
        },
    }
}

/// The whole decision table, as data.
///
/// Exported across the C ABI so the Dart mirror of these rules can be compared
/// against the rules themselves in a test, instead of the two drifting apart
/// the first time one side is edited.
pub fn gate_matrix(
    accepted_lag_nanos: u64,
    server: Option<&ServerDurability>,
) -> serde_json::Value {
    let mut rows = Vec::new();
    for policy in Policy::all() {
        for meaning in AckMeaning::all() {
            let verdict = gate(*policy, *meaning, accepted_lag_nanos, server);
            rows.push(serde_json::json!({
                "policy": policy.as_str(),
                "meaning": meaning.as_str(),
                "code": verdict.unwrap_or(Code::Ok).as_str(),
            }));
        }
    }
    serde_json::Value::Array(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn server(sync_always: bool, interval_nanos: u64) -> ServerDurability {
        ServerDurability {
            version: "2.14.4".into(),
            sync_always,
            sync_interval_nanos: interval_nanos,
            store_dir: "/var/lib/nats".into(),
        }
    }

    const TWO_MINUTES: u64 = 120_000_000_000;

    // --- what the server said -------------------------------------------------

    #[test]
    fn parses_the_monitoring_endpoint_shape() {
        let json = include_str!("../fixtures/varz_2_14_4_default.json");
        let d = parse_varz(json).unwrap();
        assert_eq!(d.version, "2.14.4");
        assert!(!d.sync_always, "default config does not fsync on write");
        assert_eq!(d.sync_interval_nanos, TWO_MINUTES);
    }

    #[test]
    fn parses_the_system_account_shape() {
        let json = include_str!("../fixtures/varz_2_14_4_sync_always_sys.json");
        let d = parse_varz(json).unwrap();
        assert_eq!(d.version, "2.14.4");
        assert!(d.sync_always);
    }

    #[test]
    fn sync_interval_stays_at_two_minutes_even_when_the_server_fsyncs_every_write() {
        // The measured trap. A probe that judged by sync_interval alone would
        // call this server unsafe, and would be wrong.
        let json = include_str!("../fixtures/varz_2_14_4_sync_always.json");
        let d = parse_varz(json).unwrap();
        assert_eq!(d.sync_interval_nanos, TWO_MINUTES);
        assert!(d.sync_always);
        assert_eq!(
            ack_meaning(Some(&d), Storage::File, PersistMode::Default),
            AckMeaning::FsyncedToDisk,
        );
    }

    #[test]
    fn an_old_server_looks_exactly_as_unsafe_as_it_is() {
        let json = include_str!("../fixtures/varz_2_11_0_default.json");
        let d = parse_varz(json).unwrap();
        assert_eq!(d.version, "2.11.0");
        assert!(!d.sync_always);
        assert_eq!(d.sync_interval_nanos, TWO_MINUTES);
    }

    #[test]
    fn a_server_without_jetstream_is_an_error_not_a_default() {
        let json = r#"{"version":"2.14.4"}"#;
        assert!(parse_varz(json).unwrap_err().contains("jetstream"));
    }

    #[test]
    fn garbage_is_reported_not_swallowed() {
        assert!(parse_varz("not json at all").is_err());
        assert!(parse_varz(r#"{"jetstream":{"config":{}}}"#).is_err());
    }

    // --- what an ack means ----------------------------------------------------

    #[test]
    fn no_evidence_means_unknown_never_a_hopeful_guess() {
        assert_eq!(
            ack_meaning(None, Storage::File, PersistMode::Default),
            AckMeaning::Unknown
        );
    }

    #[test]
    fn default_server_acks_before_fsync() {
        assert_eq!(
            ack_meaning(
                Some(&server(false, TWO_MINUTES)),
                Storage::File,
                PersistMode::Default
            ),
            AckMeaning::WrittenNotFsynced
        );
    }

    #[test]
    fn async_persistence_defeats_a_fsync_always_server() {
        // Measured: 4 198 msg/s on a sync_always server versus 158 msg/s for
        // the same server with the default mode. The ack is not waiting for a
        // disk, and it looks identical to one that is.
        assert_eq!(
            ack_meaning(
                Some(&server(true, TWO_MINUTES)),
                Storage::File,
                PersistMode::Async
            ),
            AckMeaning::AckedBeforeStore,
        );
    }

    #[test]
    fn memory_storage_outranks_every_other_consideration() {
        assert_eq!(
            ack_meaning(
                Some(&server(true, TWO_MINUTES)),
                Storage::Memory,
                PersistMode::Default
            ),
            AckMeaning::MemoryOnly,
        );
    }

    // --- the gate -------------------------------------------------------------

    #[test]
    fn the_default_policy_is_the_safe_one() {
        assert_eq!(Policy::default(), Policy::FsyncOnAck);
        assert_eq!(Storage::default(), Storage::File);
        assert_eq!(PersistMode::default(), PersistMode::Default);
    }

    #[test]
    fn fsync_on_ack_admits_only_a_fsynced_ack() {
        for meaning in AckMeaning::all() {
            let verdict = gate(Policy::FsyncOnAck, *meaning, 0, Some(&server(true, 0)));
            if *meaning == AckMeaning::FsyncedToDisk {
                assert_eq!(verdict, None, "{meaning:?} must pass");
            } else {
                assert!(verdict.is_some(), "{meaning:?} must not pass as fsynced");
            }
        }
    }

    #[test]
    fn fsync_on_ack_distinguishes_not_proven_from_proven_weaker() {
        // These two need different words because they need different fixes:
        // one is "go ask the server", the other is "your server is unsafe".
        assert_eq!(
            gate(Policy::FsyncOnAck, AckMeaning::Unknown, 0, None),
            Some(Code::DurabilityUnproven)
        );
        assert_eq!(
            gate(
                Policy::FsyncOnAck,
                AckMeaning::WrittenNotFsynced,
                0,
                Some(&server(false, TWO_MINUTES))
            ),
            Some(Code::DurabilityWeakerThanRequested)
        );
    }

    #[test]
    fn flush_on_ack_checks_the_window_the_caller_named() {
        let s = server(false, TWO_MINUTES);
        // Willing to lose five minutes: the server's two-minute window fits.
        assert_eq!(
            gate(
                Policy::FlushOnAck,
                AckMeaning::WrittenNotFsynced,
                300_000_000_000,
                Some(&s)
            ),
            None
        );
        // Willing to lose one second: it does not.
        assert_eq!(
            gate(
                Policy::FlushOnAck,
                AckMeaning::WrittenNotFsynced,
                1_000_000_000,
                Some(&s)
            ),
            Some(Code::FsyncLagTooLong)
        );
    }

    #[test]
    fn flush_on_ack_without_a_server_cannot_pass_on_an_unbounded_window() {
        assert_eq!(
            gate(
                Policy::FlushOnAck,
                AckMeaning::WrittenNotFsynced,
                u64::MAX - 1,
                None
            ),
            Some(Code::FsyncLagTooLong)
        );
    }

    #[test]
    fn flush_on_ack_still_refuses_an_ack_that_precedes_the_write() {
        assert_eq!(
            gate(
                Policy::FlushOnAck,
                AckMeaning::AckedBeforeStore,
                u64::MAX,
                Some(&server(true, 0))
            ),
            Some(Code::DurabilityWeakerThanRequested)
        );
        assert_eq!(
            gate(
                Policy::FlushOnAck,
                AckMeaning::MemoryOnly,
                u64::MAX,
                Some(&server(true, 0))
            ),
            Some(Code::DurabilityWeakerThanRequested)
        );
    }

    #[test]
    fn the_named_unsafe_policy_admits_everything_including_ignorance() {
        for meaning in AckMeaning::all() {
            assert_eq!(
                gate(Policy::AckIsMemoryOnly, *meaning, 0, None),
                None,
                "{meaning:?}"
            );
        }
    }

    #[test]
    fn the_matrix_covers_every_pair() {
        let m = gate_matrix(0, None);
        assert_eq!(
            m.as_array().unwrap().len(),
            Policy::all().len() * AckMeaning::all().len()
        );
    }

    #[test]
    fn every_name_round_trips_as_a_name() {
        for p in Policy::all() {
            assert_eq!(
                serde_json::to_string(p).unwrap(),
                format!("\"{}\"", p.as_str())
            );
        }
        for m in AckMeaning::all() {
            assert_eq!(
                serde_json::to_string(m).unwrap(),
                format!("\"{}\"", m.as_str())
            );
        }
        assert!(serde_json::from_str::<Policy>("0").is_err());
        assert!(serde_json::from_str::<AckMeaning>("1").is_err());
    }
}
