//! MDB: nine-bit frames, the checksum, and the command names — and no bus
//! timing whatsoever.
//!
//! # What this module refuses to do
//!
//! MDB gives a peripheral five milliseconds to begin answering and tolerates
//! no arbitrary pause inside a frame; at 9600 baud with nine data bits a byte
//! is about 0,94 ms and a bit about 104 µs. Those numbers are real, and they
//! are exactly why nothing here holds them.
//!
//! Two independent reasons, both measured in
//! `docs/superpowers/specs/2026-07-31-rk_rt-design.md`:
//!
//! * **Electrical.** A standard PC UART gives eight data bits plus parity.
//!   The MDB mode bit is a ninth *data* bit, not a parity bit, and cannot be
//!   set from a host program at all without bit-banging the line at
//!   sub-bit resolution.
//! * **Scheduling.** The host is a till: a Flutter app, a database, printing,
//!   video. Even a tuned `PREEMPT_RT` kernel — which `telepos-os` does not
//!   ship, and whose x86 route is a paid subscription — leaves jitter on the
//!   order of the window on a Pi and unmaskable 50–300 µs SMI spikes on x86.
//!   A missed reply would land exactly when the till is busy, which is when
//!   it is selling.
//!
//! So the bus timing belongs to a bridge microcontroller, where a hardware
//! UART sets the ninth bit and a hardware timer holds the window. This module
//! produces the frames that bridge sends and reads the frames it returns.
//! [`RESPONSE_WINDOW_MS`] is published as a number to *configure the bridge
//! with*, never as a deadline anything here enforces.
//!
//! # Provenance of the constants
//!
//! The NAMA MDB/ICP standard is not freely distributed. The address and
//! command bytes below come from secondary engineering sources that agree
//! with one another (Abrantix' write-up of the ninth bit, mdbconverter.com)
//! and are **unverified against the standard and never tested against a
//! device**. That is why [`encode_raw`] exists: a caller holding the real
//! document, or the datasheet of the bridge it bought, is never blocked by
//! this table.

use crate::status::{Result, Status};

/// The window a peripheral has to begin replying, in milliseconds.
///
/// Published so a caller can configure a bridge with it. Nothing in this
/// crate waits, so nothing in this crate can enforce it.
pub const RESPONSE_WINDOW_MS: u32 = 5;

/// One bit time at the standard 9600 baud, in microseconds.
pub const BIT_TIME_US: u32 = 104;

/// The mode bit: the ninth bit of an MDB word.
///
/// Master to peripheral, it marks the address byte that opens a frame.
/// Peripheral to master, it marks the checksum byte that closes one.
pub const MODE_BIT: u16 = 0x0100;

/// Peripheral addresses — the top five bits of a command byte.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Address {
    CoinChanger,
    Cashless1,
    CommsGateway,
    BillValidator,
    Cashless2,
}

impl Address {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "coin_changer" => Ok(Address::CoinChanger),
            "cashless_1" => Ok(Address::Cashless1),
            "comms_gateway" => Ok(Address::CommsGateway),
            "bill_validator" => Ok(Address::BillValidator),
            "cashless_2" => Ok(Address::Cashless2),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Address::CoinChanger => "coin_changer",
            Address::Cashless1 => "cashless_1",
            Address::CommsGateway => "comms_gateway",
            Address::BillValidator => "bill_validator",
            Address::Cashless2 => "cashless_2",
        }
    }

    pub const fn base(self) -> u8 {
        match self {
            Address::CoinChanger => 0x08,
            Address::Cashless1 => 0x10,
            Address::CommsGateway => 0x18,
            Address::BillValidator => 0x30,
            Address::Cashless2 => 0x60,
        }
    }
}

/// The command table, as data: address, command name, low three bits.
///
/// A table and not a `match` arm per model, for the same reason the device
/// profile catalogue is a table: adding a peripheral must not be programming.
const COMMANDS: &[(Address, &str, u8)] = &[
    (Address::CoinChanger, "reset", 0),
    (Address::CoinChanger, "setup", 1),
    (Address::CoinChanger, "tube_status", 2),
    (Address::CoinChanger, "poll", 3),
    (Address::CoinChanger, "coin_type", 4),
    (Address::CoinChanger, "dispense", 5),
    (Address::BillValidator, "reset", 0),
    (Address::BillValidator, "setup", 1),
    (Address::BillValidator, "security", 2),
    (Address::BillValidator, "poll", 3),
    (Address::BillValidator, "bill_type", 4),
    (Address::BillValidator, "escrow", 5),
    (Address::BillValidator, "stacker", 6),
    (Address::BillValidator, "expansion", 7),
    (Address::Cashless1, "reset", 0),
    (Address::Cashless1, "setup", 1),
    (Address::Cashless1, "poll", 2),
    (Address::Cashless1, "vend", 3),
    (Address::Cashless1, "reader", 4),
    (Address::Cashless1, "revalue", 5),
    (Address::Cashless1, "expansion", 7),
    (Address::Cashless2, "reset", 0),
    (Address::Cashless2, "setup", 1),
    (Address::Cashless2, "poll", 2),
    (Address::Cashless2, "vend", 3),
    (Address::Cashless2, "reader", 4),
    (Address::Cashless2, "revalue", 5),
    (Address::Cashless2, "expansion", 7),
];

/// The command byte for a named command on a named address.
///
/// Unknown names are refused rather than resolved to something nearby: a
/// `poll` sent to the wrong peripheral is not a smaller mistake than no poll
/// at all.
pub fn command_byte(address: Address, command: &str) -> Result<u8> {
    for (addr, name, low) in COMMANDS {
        if *addr == address && *name == command {
            return Ok(address.base() | low);
        }
    }
    Err(Status::UnknownName)
}

/// The MDB checksum: the low eight bits of the sum of every preceding byte.
pub fn checksum(bytes: &[u8]) -> u8 {
    bytes.iter().fold(0u8, |acc, b| acc.wrapping_add(*b))
}

/// Build a master-to-peripheral frame as nine-bit words.
///
/// `words[0]` carries the mode bit; the data bytes and the checksum do not.
/// The caller hands these to a bridge that can actually set a ninth bit.
pub fn encode(address: Address, command: &str, data: &[u8]) -> Result<Vec<u16>> {
    encode_raw(command_byte(address, command)?, data)
}

/// The same frame, from a command byte the caller supplies itself.
///
/// The escape hatch out of [`COMMANDS`]: this crate's table is transcribed
/// from secondary sources, and no caller should be unable to talk to its own
/// hardware because of that.
pub fn encode_raw(command: u8, data: &[u8]) -> Result<Vec<u16>> {
    if data.len() > 254 {
        // A block is 36 bytes at most in every peripheral this table covers;
        // 254 is the point past which the checksum can no longer be the last
        // byte of a single block under any reading of the protocol.
        return Err(Status::OutOfRange);
    }
    let mut bytes = Vec::with_capacity(data.len() + 2);
    bytes.push(command);
    bytes.extend_from_slice(data);
    let chk = checksum(&bytes);

    let mut words: Vec<u16> = Vec::with_capacity(bytes.len() + 1);
    words.push(u16::from(command) | MODE_BIT);
    for b in &bytes[1..] {
        words.push(u16::from(*b));
    }
    words.push(u16::from(chk));
    Ok(words)
}

/// What came back from a peripheral.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Reply {
    /// A data block, checksum verified. The payload excludes the checksum.
    Block(Vec<u8>),
    /// `0x00` with the mode bit set.
    Ack,
    /// `0xFF` with the mode bit set — "I heard you and I am refusing".
    Nak,
    /// `0xAA` with the mode bit set — "repeat the last block".
    Ret,
    /// No word with the mode bit set yet: the block has not finished
    /// arriving. Nothing may be dropped.
    Incomplete,
    /// A complete block whose checksum does not add up. The caller should
    /// retransmit, which in MDB is what `Ret` is for.
    BadChecksum,
}

impl Reply {
    pub const fn kind_name(&self) -> &'static str {
        match self {
            Reply::Block(_) => "block",
            Reply::Ack => "ack",
            Reply::Nak => "nak",
            Reply::Ret => "ret",
            Reply::Incomplete => "incomplete",
            Reply::BadChecksum => "bad_checksum",
        }
    }
}

/// A reply together with how many words it accounted for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Decoded {
    pub reply: Reply,
    pub consumed: usize,
}

/// Read one peripheral-to-master frame out of `words`.
///
/// The mode bit closes the frame, so the terminator is found rather than
/// counted — which is what makes a short read distinguishable from a bad one.
pub fn decode(words: &[u16]) -> Decoded {
    let Some(end) = words.iter().position(|w| w & MODE_BIT != 0) else {
        return Decoded {
            reply: Reply::Incomplete,
            consumed: 0,
        };
    };

    if end == 0 {
        let control = (words[0] & 0x00FF) as u8;
        let reply = match control {
            0x00 => Reply::Ack,
            0xFF => Reply::Nak,
            0xAA => Reply::Ret,
            // A lone byte with the mode bit set that is none of the three
            // control words is a zero-length block whose checksum is itself,
            // which is only consistent when that byte is zero — and that case
            // is already `Ack`. Anything else is a framing error.
            _ => Reply::BadChecksum,
        };
        return Decoded { reply, consumed: 1 };
    }

    let payload: Vec<u8> = words[..end].iter().map(|w| (w & 0x00FF) as u8).collect();
    let chk = (words[end] & 0x00FF) as u8;
    let reply = if checksum(&payload) == chk {
        Reply::Block(payload)
    } else {
        Reply::BadChecksum
    };
    Decoded {
        reply,
        consumed: end + 1,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_poll_to_the_coin_changer_is_the_documented_byte() {
        assert_eq!(command_byte(Address::CoinChanger, "poll").unwrap(), 0x0B);
        assert_eq!(command_byte(Address::CoinChanger, "reset").unwrap(), 0x08);
        assert_eq!(command_byte(Address::BillValidator, "poll").unwrap(), 0x33);
        assert_eq!(command_byte(Address::Cashless1, "vend").unwrap(), 0x13);
        assert_eq!(command_byte(Address::Cashless2, "poll").unwrap(), 0x62);
    }

    #[test]
    fn a_command_a_peripheral_does_not_have_is_refused() {
        // The changer has no `escrow`; the bill validator does.
        assert_eq!(
            command_byte(Address::CoinChanger, "escrow"),
            Err(Status::UnknownName)
        );
        assert!(command_byte(Address::BillValidator, "escrow").is_ok());
    }

    #[test]
    fn only_the_first_word_of_a_master_frame_carries_the_mode_bit() {
        let f = encode(Address::CoinChanger, "poll", &[]).unwrap();
        assert_eq!(f, vec![0x0B | MODE_BIT, 0x0B]);
        assert_eq!(f[0] & MODE_BIT, MODE_BIT);
        assert_eq!(f[1] & MODE_BIT, 0);
    }

    #[test]
    fn the_checksum_is_the_sum_of_the_frame_and_it_wraps() {
        assert_eq!(checksum(&[0x0B]), 0x0B);
        assert_eq!(checksum(&[0xFF, 0x02]), 0x01);
        let f = encode(Address::CoinChanger, "coin_type", &[0xFF, 0xFF, 0x00, 0x00]).unwrap();
        assert_eq!(
            f,
            vec![0x0C | MODE_BIT, 0x00FF, 0x00FF, 0x0000, 0x0000, 0x000A]
        );
    }

    #[test]
    fn a_raw_command_byte_bypasses_the_table_entirely() {
        assert_eq!(
            encode_raw(0x7B, &[0x01]).unwrap(),
            vec![0x7B | MODE_BIT, 0x0001, 0x007C]
        );
    }

    #[test]
    fn ack_nak_and_ret_are_told_apart_by_name() {
        assert_eq!(decode(&[MODE_BIT]).reply, Reply::Ack);
        assert_eq!(decode(&[0xFF | MODE_BIT]).reply, Reply::Nak);
        assert_eq!(decode(&[0xAA | MODE_BIT]).reply, Reply::Ret);
        assert_eq!(decode(&[MODE_BIT]).consumed, 1);
    }

    #[test]
    fn a_block_is_returned_without_its_checksum() {
        // Tube status style payload, checksum on the last word.
        let payload = [0x01u8, 0x02, 0x03];
        let chk = checksum(&payload);
        let words: Vec<u16> = payload
            .iter()
            .map(|b| u16::from(*b))
            .chain(core::iter::once(u16::from(chk) | MODE_BIT))
            .collect();
        let d = decode(&words);
        assert_eq!(d.reply, Reply::Block(vec![0x01, 0x02, 0x03]));
        assert_eq!(d.consumed, 4);
    }

    #[test]
    fn a_block_missing_its_mode_bit_is_incomplete_and_consumes_nothing() {
        let d = decode(&[0x0001, 0x0002]);
        assert_eq!(d.reply, Reply::Incomplete);
        assert_eq!(d.consumed, 0);
    }

    #[test]
    fn a_wrong_checksum_is_reported_rather_than_returned_as_data() {
        let d = decode(&[0x0001, 0x0002, 0x0009 | MODE_BIT]);
        assert_eq!(d.reply, Reply::BadChecksum);
        assert_eq!(d.consumed, 3);
    }

    #[test]
    fn a_frame_encoded_here_decodes_back_to_its_own_payload() {
        // The master frame's own checksum, re-read with the mode bit moved to
        // the last word as a peripheral would send it: proves encode and
        // decode agree on the checksum, not merely that each runs.
        let master = encode(
            Address::BillValidator,
            "bill_type",
            &[0xFF, 0xFF, 0x00, 0x03],
        )
        .unwrap();
        let mut as_peripheral: Vec<u16> = master.iter().map(|w| w & 0x00FF).collect::<Vec<u16>>();
        let last = as_peripheral.len() - 1;
        as_peripheral[last] |= MODE_BIT;
        match decode(&as_peripheral).reply {
            Reply::Block(payload) => {
                assert_eq!(payload, vec![0x34, 0xFF, 0xFF, 0x00, 0x03]);
            }
            other => panic!("expected a block, got {other:?}"),
        }
    }

    #[test]
    fn the_response_window_is_published_and_not_enforced() {
        // Nothing in this module can wait, so this is a number to configure a
        // bridge with. The test exists so the constant cannot be quietly
        // changed into something a caller might treat as a promise.
        assert_eq!(RESPONSE_WINDOW_MS, 5);
        assert_eq!(BIT_TIME_US, 104);
    }
}
