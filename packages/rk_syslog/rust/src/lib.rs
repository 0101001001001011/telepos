//! `rk_syslog` — the sink under a logging library, not a logging library.
//!
//! # What this is, and what it deliberately is not
//!
//! This crate takes a record that already exists and gets it framed to
//! RFC 5424, spooled to disk, and delivered to a collector over TLS per
//! RFC 5425. That is the whole job.
//!
//! It is **not** a way to stop writing logging calls. Whether a class logs at
//! all, what it logs, and which of its fields are secret are decisions made
//! at the call site, in the language the call site is written in. A native
//! library sits underneath all of that and never sees those classes. Anyone
//! hoping a Rust crate would remove logging boilerplate from application code
//! is hoping for something no sink can do, at either end of a foreign
//! function interface. Redaction in particular belongs to the caller: this
//! crate cannot know that a field is a PIN, and it does not guess.
//!
//! What it does buy is worth having on its own. Records outlive a crash.
//! A till whose collector is unreachable keeps selling at full speed. The
//! journal can be handed to whatever collector a customer already runs,
//! because it is in the format that collector already reads.
//!
//! # Shape
//!
//! ```text
//!   caller's thread                worker thread
//!   ---------------                -------------
//!   submit
//!     frame (RFC 5424)   ──push──▶  spool.append   ──▶  disk, bounded
//!     hand off                      transport.send ──▶  TLS, octet-counted
//! ```
//!
//! Framing happens on the caller's thread so a record that cannot be framed
//! is refused where the mistake was made. Everything that can wait happens on
//! the worker, so nothing the caller does waits on a network.
//!
//! # The modules, in the order they matter
//!
//! - [`rfc5424`] — framing, and the rule that an unframeable record is
//!   reported rather than dropped.
//! - [`spool`] — the bounded on-disk queue, the two rules for what gives when
//!   it is full, and what each costs.
//! - [`queue`] — the hand-off, and why submitting cannot block.
//! - [`transport`] — RFC 5425, octet counting, and who is trusted.
//! - [`sink`] — the worker, the counters, and the ordering and duplicate
//!   guarantees.
//! - [`ffi`] — the C ABI: panics caught, failures returned, who frees what.
//!
//! # Building
//!
//! A plain `cdylib`/`staticlib` with a C ABI and no build script. The
//! per-platform Flutter wiring lives one level up, in the package's `src/`,
//! `android/` and `apple/` directories, and points at this crate.
//!
//! One thing that wiring must not do: set `panic = "abort"`. The boundary in
//! [`ffi`] catches panics so a failure reaches the caller as a value, and
//! aborting makes that promise false.

#![deny(clippy::undocumented_unsafe_blocks)]
#![warn(missing_debug_implementations)]

pub mod config;
pub mod ffi;
pub mod queue;
pub mod rfc5424;
pub mod severity;
pub mod sink;
pub mod spool;
pub mod status;
pub mod time;
pub mod transport;

pub use config::{ConfigBuilder, Settings};
pub use rfc5424::{frame, Oversize, Record, SinkIdentity, StructuredData};
pub use severity::{Facility, Severity};
pub use sink::Sink;
pub use spool::{Spool, SpoolLimits, SpoolPolicy};
pub use status::{Failure, Fallible, Status};

/// The version this library reports about itself.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
