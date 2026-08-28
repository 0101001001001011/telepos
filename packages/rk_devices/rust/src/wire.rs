//! Partial writes, which are not the same thing on three different wires.
//!
//! This is the module that exists because flattening the difference cost this
//! product a receipt. A short write reported as a successful print
//! (`windows_printer.dart:106` puts the byte count into a *successful*
//! result without ever comparing it to the buffer length) and a whole job
//! re-sent up to four hundred times on a serial line are the same mistake
//! seen from two sides: treating "how many bytes did you take" as if it were
//! the same question on every transport.
//!
//! It is not:
//!
//! | wire | what the write returns | what a remainder means |
//! | --- | --- | --- |
//! | serial | a byte count (`libserialport`) | a **continuation** — send the rest, never the whole thing again |
//! | socket | nothing at all (`Socket.add` + `flush()` return `void`) | unknowable — a failed `flush` does not say how much reached the wire |
//! | raw USB node | nothing at all (`writeFromSync` either returns or throws) | unknowable, and worse: the driver may have taken part of it |
//!
//! Reasoning and the measurements behind it:
//! `docs/superpowers/specs/2026-07-31-rk_escpos-design.md`, question 3.
//!
//! FFI creates no information the transport does not have. What this module
//! does is refuse to let a caller pretend otherwise.

use crate::status::{Result, Status};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Wire {
    /// A serial port through `libserialport`. `write()` returns the number of
    /// bytes it accepted, or a negative value carrying no count.
    Serial,
    /// A TCP socket through `dart:io`. Neither `add` nor `flush` returns a
    /// count, so the only two states are "flushed" and "threw".
    Socket,
    /// A character device such as `/dev/usb/lp0`, written with
    /// `writeFromSync`. Either it returns or it throws; the `usblp` driver
    /// may have accepted part of the buffer either way.
    UsbRaw,
}

impl Wire {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "serial" => Ok(Wire::Serial),
            "socket" => Ok(Wire::Socket),
            "usb_raw" => Ok(Wire::UsbRaw),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Wire::Serial => "serial",
            Wire::Socket => "socket",
            Wire::UsbRaw => "usb_raw",
        }
    }

    /// Whether this wire can tell a caller how much of a buffer it took.
    pub const fn reports_partial_writes(self) -> bool {
        match self {
            Wire::Serial => true,
            Wire::Socket | Wire::UsbRaw => false,
        }
    }
}

/// What the wire said after a write was attempted.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Report {
    /// The wire returned a byte count.
    Accepted(usize),
    /// The write failed and carried no count with it.
    Failed,
}

/// What the caller may now do, and nothing more.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Resume {
    /// Everything reached the wire.
    Done,
    /// `offset` bytes reached the wire. Send `payload[offset..]` next — and
    /// only that. Re-sending from zero here duplicates bytes the device has
    /// already acted on, which on a receipt printer means a doubled line and
    /// on a drawer means a second kick.
    Continue { offset: usize },
    /// How much reached the device is not knowable. Neither continuing nor
    /// repeating is safe on the byte level, so the decision belongs one layer
    /// up, to whatever owns the *job* — and it is safe there only because a
    /// print job is idempotent by identifier (И29), not because the bytes
    /// are.
    Unknown,
}

impl Resume {
    pub const fn name(self) -> &'static str {
        match self {
            Resume::Done => "done",
            Resume::Continue { .. } => "continue",
            Resume::Unknown => "unknown",
        }
    }

    pub const fn offset(self) -> usize {
        match self {
            Resume::Continue { offset } => offset,
            _ => 0,
        }
    }
}

/// Turn "the wire said this" into "you may do that".
///
/// A partial count from a wire that cannot produce one is refused with
/// [`Status::InvalidArgument`] rather than believed. That refusal is the
/// point of the whole module: a socket that reports it wrote 40 of 80 bytes
/// is a caller that has invented a number, and acting on it would resume from
/// the wrong place. If a future transport genuinely counts, it gets its own
/// name here.
pub fn resolve(wire: Wire, total: usize, report: Report) -> Result<Resume> {
    match report {
        Report::Failed => Ok(Resume::Unknown),
        Report::Accepted(n) => {
            if n > total {
                return Err(Status::InvalidArgument);
            }
            if n == total {
                return Ok(Resume::Done);
            }
            if !wire.reports_partial_writes() {
                return Err(Status::InvalidArgument);
            }
            Ok(Resume::Continue { offset: n })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_short_serial_write_is_a_continuation_and_names_the_offset() {
        assert_eq!(
            resolve(Wire::Serial, 80, Report::Accepted(40)).unwrap(),
            Resume::Continue { offset: 40 }
        );
        assert_eq!(
            resolve(Wire::Serial, 80, Report::Accepted(40))
                .unwrap()
                .offset(),
            40
        );
    }

    #[test]
    fn a_complete_write_is_done_on_every_wire() {
        for w in [Wire::Serial, Wire::Socket, Wire::UsbRaw] {
            assert_eq!(resolve(w, 80, Report::Accepted(80)).unwrap(), Resume::Done);
        }
    }

    #[test]
    fn a_failed_write_is_unknown_on_every_wire_including_serial() {
        // `libserialport` returns -1 without a count. Serial reports partial
        // writes only when it succeeds partially; a failure tells us nothing.
        for w in [Wire::Serial, Wire::Socket, Wire::UsbRaw] {
            assert_eq!(resolve(w, 80, Report::Failed).unwrap(), Resume::Unknown);
        }
    }

    #[test]
    fn a_socket_cannot_report_a_partial_write_and_is_not_allowed_to_claim_one() {
        assert_eq!(
            resolve(Wire::Socket, 80, Report::Accepted(40)),
            Err(Status::InvalidArgument)
        );
        assert_eq!(
            resolve(Wire::UsbRaw, 80, Report::Accepted(40)),
            Err(Status::InvalidArgument)
        );
    }

    #[test]
    fn a_count_larger_than_the_buffer_is_refused_rather_than_clamped() {
        assert_eq!(
            resolve(Wire::Serial, 80, Report::Accepted(81)),
            Err(Status::InvalidArgument)
        );
    }

    #[test]
    fn the_wires_differ_in_what_they_can_report_and_say_so() {
        assert!(Wire::Serial.reports_partial_writes());
        assert!(!Wire::Socket.reports_partial_writes());
        assert!(!Wire::UsbRaw.reports_partial_writes());
    }

    #[test]
    fn draining_a_serial_write_terminates_and_never_repeats_a_byte() {
        // The shape a caller is meant to use, exercised end to end: three
        // short writes of an eight-byte payload leave exactly one copy.
        let payload: Vec<u8> = (0u8..8).collect();
        let mut sent: Vec<u8> = Vec::new();
        let mut offset = 0usize;
        let accepts = [3usize, 2, 3];
        for accepted in accepts {
            let chunk = &payload[offset..];
            sent.extend_from_slice(&chunk[..accepted]);
            match resolve(Wire::Serial, chunk.len(), Report::Accepted(accepted)).unwrap() {
                Resume::Done => break,
                Resume::Continue { offset: taken } => offset += taken,
                Resume::Unknown => panic!("a counted serial write is never unknown"),
            }
        }
        assert_eq!(sent, payload);
    }
}
