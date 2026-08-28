//! Cash drawers: one pulse, and an honest answer about what comes back.
//!
//! An RJ11 drawer is a solenoid on a kick-out connector. `ESC p m t1 t2`
//! energises it for `t1`, then guarantees a rest of `t2` before the next
//! pulse; the units are two milliseconds each, which caps a single field at
//! 510 ms. That is the whole protocol.
//!
//! What is *not* here is any way to ask a drawer whether it is open. The kick
//! wire is one-directional. Some receipt printers sense a separate pin and
//! report it in their own status byte, but that is the printer answering, not
//! the drawer, and this product has no printer status path that carries it.
//! Reporting the difference is the point: the previous implementation's
//! `checkStatus()` returned its own `_isOpen` field — the value it had set
//! itself when the write succeeded — which is a guess wearing the clothes of
//! a measurement.

use crate::status::{Result, Status};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Model {
    /// The kick-out connector on an ESC/POS printer or on a standalone
    /// interface board. Both cash-drawer profiles in this product's catalogue
    /// (`drawer.rj11.via-printer`, `drawer.rj11.standalone`) declare
    /// `DeviceProtocol.escPos`, and the bytes are the same either way — only
    /// the wire they travel down differs.
    EscPosKick,
}

impl Model {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "escpos_kick" => Ok(Model::EscPosKick),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Model::EscPosKick => "escpos_kick",
        }
    }
}

/// Which of the two pins on the kick-out connector to energise.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Pin {
    /// `m = 0`. The default, and what a single-drawer till uses.
    Pin2,
    /// `m = 1`. The second drawer, where a till has two.
    Pin5,
}

impl Pin {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "pin2" => Ok(Pin::Pin2),
            "pin5" => Ok(Pin::Pin5),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Pin::Pin2 => "pin2",
            Pin::Pin5 => "pin5",
        }
    }

    const fn selector(self) -> u8 {
        match self {
            Pin::Pin2 => 0x00,
            Pin::Pin5 => 0x01,
        }
    }
}

/// Whether anything can be learned about the drawer over the same wire.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Reporting {
    /// Nothing comes back. A caller must not claim the drawer opened; the
    /// most it can honestly say is that the pulse was written.
    CannotReport,
}

impl Reporting {
    pub const fn name(self) -> &'static str {
        match self {
            Reporting::CannotReport => "cannot_report",
        }
    }
}

/// The pulse this product has always sent: 64 ms on, 320 ms off.
pub const DEFAULT_ON_MS: u32 = 64;
pub const DEFAULT_OFF_MS: u32 = 320;

/// The longest either field can express: 255 units of two milliseconds.
pub const MAX_MS: u32 = 510;

pub const fn reporting(model: Model) -> Reporting {
    match model {
        Model::EscPosKick => Reporting::CannotReport,
    }
}

/// `ESC p m t1 t2`, with the times given in milliseconds and rounded up to
/// the protocol's two-millisecond units.
///
/// Rounded *up*, not down: rounding down would let a caller ask for 3 ms and
/// get 2 ms, and a solenoid that is under-energised does not open the drawer
/// while reporting nothing wrong.
pub fn pulse(model: Model, pin: Pin, on_ms: u32, off_ms: u32) -> Result<Vec<u8>> {
    let Model::EscPosKick = model;
    if on_ms > MAX_MS || off_ms > MAX_MS {
        return Err(Status::OutOfRange);
    }
    let t1 = on_ms.div_ceil(2) as u8;
    let t2 = off_ms.div_ceil(2) as u8;
    Ok(vec![0x1B, 0x70, pin.selector(), t1, t2])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_default_pulse_is_byte_for_byte_what_the_product_already_sends() {
        // lib/hardware/cash_drawer/cash_drawer_service.dart:29
        assert_eq!(
            pulse(Model::EscPosKick, Pin::Pin2, DEFAULT_ON_MS, DEFAULT_OFF_MS).unwrap(),
            vec![0x1B, 0x70, 0x00, 0x20, 0xA0]
        );
        // lib/hardware/cash_drawer/cash_drawer_service.dart:31
        assert_eq!(
            pulse(Model::EscPosKick, Pin::Pin5, DEFAULT_ON_MS, DEFAULT_OFF_MS).unwrap(),
            vec![0x1B, 0x70, 0x01, 0x20, 0xA0]
        );
    }

    #[test]
    fn times_are_two_millisecond_units_rounded_up() {
        assert_eq!(
            pulse(Model::EscPosKick, Pin::Pin2, 3, 3).unwrap(),
            vec![0x1B, 0x70, 0x00, 0x02, 0x02]
        );
        assert_eq!(
            pulse(Model::EscPosKick, Pin::Pin2, 510, 510).unwrap(),
            vec![0x1B, 0x70, 0x00, 0xFF, 0xFF]
        );
        assert_eq!(
            pulse(Model::EscPosKick, Pin::Pin2, 0, 0).unwrap(),
            vec![0x1B, 0x70, 0x00, 0x00, 0x00]
        );
    }

    #[test]
    fn a_pulse_longer_than_the_protocol_can_carry_is_refused_not_truncated() {
        assert_eq!(
            pulse(Model::EscPosKick, Pin::Pin2, 511, 100),
            Err(Status::OutOfRange)
        );
        assert_eq!(
            pulse(Model::EscPosKick, Pin::Pin2, 100, 511),
            Err(Status::OutOfRange)
        );
    }

    #[test]
    fn the_drawer_admits_it_cannot_answer() {
        assert_eq!(reporting(Model::EscPosKick), Reporting::CannotReport);
        assert_eq!(reporting(Model::EscPosKick).name(), "cannot_report");
    }
}
