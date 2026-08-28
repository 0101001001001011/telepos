//! Device protocols that carry their own timing — framed, parsed, and never
//! waited on.
//!
//! Four peripherals whose conversations this product had written more than
//! once each: weighing scales, customer displays, cash drawers, and MDB
//! vending framing. One implementation instead of one per transport.
//!
//! # The rule the whole crate is shaped by
//!
//! **Timing that a peripheral controller owns stays there.** MDB's
//! five-millisecond reply window and a stepper's 1,9 µs pulse are held by
//! hardware timers and UARTs, not by a general-purpose host running a till.
//! So this crate speaks protocols and holds no deadlines: it frames, parses
//! and reports. It performs no I/O, opens nothing, sleeps never, and spawns
//! no thread — which is why И30 ("no device failure may block taking money")
//! is structural here rather than promised. Nothing that cannot wait can
//! make anyone wait.
//!
//! The one place time appears at all is [`scale::Stabilizer`], and it does
//! not hold a clock either: the caller supplies the elapsed milliseconds on
//! every offer, and the rule answers. Its budget is expressed in time and not
//! in attempts, because a port that answers every 5 ms and one that answers
//! every 5 s would otherwise get wildly different real deadlines out of the
//! same number.
//!
//! # Layout
//!
//! * [`scale`] — the request, the frame, and the settling rule.
//! * [`display`] — the command set and the code page, per model.
//! * [`drawer`] — the kick pulse, and an honest "cannot report".
//! * [`mdb`] — nine-bit words, the checksum, the command table.
//! * [`wire`] — what a partial write means, which differs per transport.
//! * [`ffi`] — the C ABI, where every enumeration crosses by name.

// И144: a failure crosses as a value. Under `panic = "abort"` a bug in this
// crate would kill the host process from inside a foreign stack instead —
// exactly what the invariant forbids — and `catch_unwind` at the boundary
// would be decoration. Refuse to build rather than ship the decoration.
#[cfg(panic = "abort")]
compile_error!(
    "rk_devices must be built with panic=unwind: И144 requires a native failure to be \
     returned as a value, and catch_unwind cannot catch an abort."
);

pub mod display;
pub mod drawer;
pub mod ffi;
pub mod mdb;
pub mod scale;
pub mod status;
pub mod wire;

pub use status::Status;

/// The version this build reports about itself.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
