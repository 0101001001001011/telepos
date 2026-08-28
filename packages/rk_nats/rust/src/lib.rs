//! `rk_nats` — core NATS and JetStream behind a C ABI.
//!
//! The crate exists for one reason that is not "Rust is faster". Dart has no
//! NATS client whose JetStream surface is anything but experimental, and
//! JetStream — durable streams and durable consumers — is the entire reason to
//! reach for NATS. See `doc/architecture.md` in the package.
//!
//! # The contract this crate refuses to leave to the operator
//!
//! JetStream acknowledges a write and fsyncs later. On a default server, later
//! means up to two minutes. Jepsen lost about 14 % of acknowledged messages to
//! a coordinated power cut because of it. So this crate does not accept
//! "acknowledged" as a synonym for "stored": every publish is gated against a
//! stated [`durability::Policy`], the default policy is the fsynced one, and
//! every successful publish reports what its ack actually meant. Choosing less
//! is possible and requires naming the weaker policy in the request.
//!
//! # Shape of the boundary
//!
//! Every exported function takes one NUL-terminated JSON string and returns one
//! NUL-terminated JSON string, owned by the caller and freed with
//! [`ffi::rk_nats_string_free`]. Three consequences, all deliberate:
//!
//! * enumerations cross as their names, because JSON has no other way to spell
//!   them (I147);
//! * adding a field is not an ABI change, so the binding and the library can be
//!   built at different times;
//! * there is exactly one rule about who frees what (I146).
//!
//! Connections are integers in a registry, not pointers. A stale integer
//! returns `handleClosed`; a stale pointer returns a crash. Integers also cross
//! isolates, which is what lets the Dart side keep every call off the interface
//! isolate (I145) without marshalling anything unsafe.

pub mod client;
pub mod codes;
pub mod durability;
pub mod ffi;
pub mod registry;

/// The shape of the C ABI, not the version of the package.
///
/// Bumped when an exported function is added, removed or changes meaning. A
/// binding that finds a version it does not know must refuse to run rather than
/// call into a library it is guessing about.
pub const ABI_VERSION: &str = "1";
