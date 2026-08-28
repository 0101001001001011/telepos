//! C ABI over the **stable subset** of Zenoh.
//!
//! See `doc/stable-subset.md` in the enclosing Dart package for what is left
//! out and why. The short version: the `unstable` feature of the `zenoh` crate
//! is not enabled, so Advanced Pub/Sub — cache, history for late joiners, miss
//! detection and recovery — is absent, and the offline story is built above
//! this library rather than inside it.
//!
//! ## Conventions, all four of them load-bearing
//!
//! * **Failure is a returned value.** Every `extern "C"` function returns
//!   [`status::RkzStatus`]; `0` succeeds, non-zero fails, and the kind is read
//!   by name from `rkz_last_error_kind`. Panics are caught at the boundary.
//! * **Ownership is one-way.** Anything this library hands back as a
//!   `*mut Rkz…` is owned by the caller until the caller passes it to the
//!   matching `rkz_…_drop`. This library never frees a handle by itself.
//! * **Enums cross by name.** Sample kinds, congestion control, priority and
//!   session modes are NUL-terminated strings, never indices.
//! * **Nothing blocks forever.** Every receive takes a timeout in
//!   milliseconds and reports `timeout` as an ordinary outcome.

#![deny(clippy::undocumented_unsafe_blocks)]

pub mod config;
pub mod handle;
pub mod names;
pub mod pubsub;
pub mod session;
pub mod status;

pub use status::{rkz_last_error_kind, rkz_last_error_message, RkzStatus, RKZ_OK};

/// The version of this native library, as a NUL-terminated string.
///
/// The pointer is static. The Dart side compares it against its own version
/// and refuses to run against a library it was not built for.
#[no_mangle]
pub extern "C" fn rkz_native_version() -> *const std::ffi::c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr().cast()
}
