//! Customer displays: the command set, the code page, and the differences
//! between the models the catalogue declares.
//!
//! Measured off four implementations in TelePOS that disagreed with each
//! other. Two of the disagreements are defects, and they are the reason this
//! module exists:
//!
//! 1. `lib/hardware/display/vfd_display.dart` maps Cyrillic as
//!    `0x410..=0x44F -> 0x80 + offset`, one contiguous run of 64. CP866 is not
//!    contiguous: `А..Я` is `0x80..=0x9F`, `а..п` is `0xA0..=0xAF`, and `р..я`
//!    jumps to `0xE0..=0xEF`. Everything from `р` to `я` therefore came out as
//!    a different letter — and `lib/hardware/display/led_display_extended.dart`
//!    has a `Cp866Encoder` right next to it that gets it right. Two writers,
//!    two encodings, one of them wrong: the shape of bug this codebase has
//!    already been bitten by twice.
//! 2. `lib/hardware/display/led_display.dart` writes `text.codeUnits` straight
//!    into a `Uint8List`, which truncates every code unit above 255 to its low
//!    byte. Cyrillic on an LED pole display was never encoded at all.
//!
//! CP866 has no slot for Kazakh or Kyrgyz letters and none for `₸`. That is a
//! property of the code page, not a bug to fix here, so the substitution is
//! *counted* and reported rather than performed in silence.

use crate::status::{Result, Status};

/// The models the device catalogue declares
/// (`lib/data/device/device_profile_catalog_builtin.dart`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Model {
    /// One line of eight characters. No cursor addressing: the only way to
    /// place text is to go home and overwrite.
    Led8,
    /// Two lines of twenty, with `ESC $ column line` cursor addressing.
    Vfd20,
    /// Two lines of twenty. Declared separately by the catalogue
    /// (`display.serial.lcd-2x20`, 2400 baud rather than 9600), and given the
    /// VFD command set here because that is exactly what the product does
    /// today: `hardware_module.dart`'s `_displayModelFor` picks a model by
    /// column count, so every twenty-column profile already runs the VFD
    /// driver. If a real LCD turns out to want a different command set, that
    /// is a finding from a device, not a guess to bake in now.
    Lcd2x20,
}

impl Model {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "led8" => Ok(Model::Led8),
            "vfd20" => Ok(Model::Vfd20),
            "lcd2x20" => Ok(Model::Lcd2x20),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Model::Led8 => "led8",
            Model::Vfd20 => "vfd20",
            Model::Lcd2x20 => "lcd2x20",
        }
    }

    pub const fn lines(self) -> u32 {
        match self {
            Model::Led8 => 1,
            Model::Vfd20 | Model::Lcd2x20 => 2,
        }
    }

    pub const fn columns(self) -> u32 {
        match self {
            Model::Led8 => 8,
            Model::Vfd20 | Model::Lcd2x20 => 20,
        }
    }

    /// Whether the model can be told to put the cursor at an arbitrary cell.
    pub const fn addressable(self) -> bool {
        match self {
            Model::Led8 => false,
            Model::Vfd20 | Model::Lcd2x20 => true,
        }
    }
}

/// What to tell a display to do.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Op {
    Reset,
    Clear,
    Home,
    DisplayOn,
    DisplayOff,
    Blink,
    SetBrightness,
    SetCursor,
    WriteLine,
}

impl Op {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "reset" => Ok(Op::Reset),
            "clear" => Ok(Op::Clear),
            "home" => Ok(Op::Home),
            "display_on" => Ok(Op::DisplayOn),
            "display_off" => Ok(Op::DisplayOff),
            "blink" => Ok(Op::Blink),
            "set_brightness" => Ok(Op::SetBrightness),
            "set_cursor" => Ok(Op::SetCursor),
            "write_line" => Ok(Op::WriteLine),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Op::Reset => "reset",
            Op::Clear => "clear",
            Op::Home => "home",
            Op::DisplayOn => "display_on",
            Op::DisplayOff => "display_off",
            Op::Blink => "blink",
            Op::SetBrightness => "set_brightness",
            Op::SetCursor => "set_cursor",
            Op::WriteLine => "write_line",
        }
    }
}

/// Bytes to send, plus how many characters had no byte to be sent as.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Encoded {
    pub bytes: Vec<u8>,
    /// Characters replaced by a space because CP866 has no slot for them —
    /// `ә`, `ң`, `ү`, `₸`. Zero for pure Russian or ASCII. A caller that gets
    /// a non-zero count here knows the customer is being shown something
    /// other than what it asked for, which is the whole point of counting.
    pub substitutions: usize,
}

/// Build the bytes for one operation.
///
/// `line` and `column` are used by `SetCursor` and `WriteLine`; `brightness`
/// by `SetBrightness`; `text` by `WriteLine`. Arguments an operation does not
/// use are ignored rather than rejected — an operation's shape is its own
/// business, and a caller building a command table should not have to know
/// which of five arguments each row cares about.
pub fn encode(
    model: Model,
    op: Op,
    line: u32,
    column: u32,
    brightness: u32,
    text: &str,
) -> Result<Encoded> {
    match op {
        Op::Reset => match model {
            // Neither LED implementation in the product ever sent a reset,
            // and no LED pole display documented here answers `ESC @`.
            // Refusing is the honest answer; sending `ESC @` on a guess would
            // be the "plausibly working device of the wrong model" failure.
            Model::Led8 => Err(Status::UnsupportedOperation),
            _ => Ok(plain(vec![0x1B, 0x40])),
        },
        Op::Clear => Ok(plain(vec![0x0C])),
        Op::Home => match model {
            Model::Led8 => Ok(plain(vec![0x0B])),
            _ => Ok(plain(vec![0x1B, 0x5B, 0x48])),
        },
        Op::DisplayOn => match model {
            Model::Led8 => Ok(plain(vec![0x14])),
            _ => Ok(plain(vec![0x1B, 0x28])),
        },
        Op::DisplayOff => match model {
            Model::Led8 => Ok(plain(vec![0x15])),
            _ => Ok(plain(vec![0x1B, 0x29])),
        },
        Op::Blink => match model {
            Model::Led8 => Err(Status::UnsupportedOperation),
            _ => Ok(plain(vec![0x1B, 0x25])),
        },
        Op::SetBrightness => {
            if brightness > 7 {
                return Err(Status::OutOfRange);
            }
            Ok(plain(vec![0x1B, 0x2A, brightness as u8]))
        }
        Op::SetCursor => {
            if !model.addressable() {
                return Err(Status::UnsupportedOperation);
            }
            check_cell(model, line, column)?;
            Ok(plain(vec![0x1B, 0x24, column as u8, line as u8]))
        }
        Op::WriteLine => {
            check_cell(model, line, 0)?;
            let mut bytes = if model.addressable() {
                vec![0x1B, 0x24, 0x00, line as u8]
            } else {
                // Home, then a full-width overwrite. Deliberately not `0x0C`
                // (form feed), which `led_display.dart` used: clearing the
                // whole display to write one line makes the price flicker
                // off and back on at every keystroke, and padding to the
                // full width overwrites just as completely.
                vec![0x0B]
            };
            let encoded = encode_text(fit(text, model.columns() as usize).as_str());
            bytes.extend_from_slice(&encoded.bytes);
            Ok(Encoded {
                bytes,
                substitutions: encoded.substitutions,
            })
        }
    }
}

fn plain(bytes: Vec<u8>) -> Encoded {
    Encoded {
        bytes,
        substitutions: 0,
    }
}

fn check_cell(model: Model, line: u32, column: u32) -> Result<()> {
    if line >= model.lines() || column >= model.columns() {
        return Err(Status::OutOfRange);
    }
    Ok(())
}

/// Truncate or pad to exactly `columns` characters.
///
/// Characters, not bytes: the padding has to land in display cells, and one
/// CP866 byte is one cell.
fn fit(text: &str, columns: usize) -> String {
    let mut out: String = text.chars().take(columns).collect();
    let have = out.chars().count();
    for _ in have..columns {
        out.push(' ');
    }
    out
}

/// CP866, and a count of what would not fit in it.
pub fn encode_text(text: &str) -> Encoded {
    let mut bytes = Vec::with_capacity(text.len());
    let mut substitutions = 0usize;
    for ch in text.chars() {
        match cp866(ch) {
            Some(b) => bytes.push(b),
            None => {
                bytes.push(0x20);
                substitutions += 1;
            }
        }
    }
    Encoded {
        bytes,
        substitutions,
    }
}

/// One character to one CP866 byte, or `None` when the page has no slot.
fn cp866(ch: char) -> Option<u8> {
    let c = ch as u32;
    match c {
        0x00..=0x7F => Some(c as u8),
        // А..Я
        0x410..=0x42F => Some((c - 0x410 + 0x80) as u8),
        // а..п
        0x430..=0x43F => Some((c - 0x430 + 0xA0) as u8),
        // р..я — the jump that `vfd_display.dart` missed.
        0x440..=0x44F => Some((c - 0x440 + 0xE0) as u8),
        0x401 => Some(0xF0), // Ё
        0x451 => Some(0xF1), // ё
        // Everything else, including every Kazakh and Kyrgyz letter and the
        // tenge sign. CP866 does not contain them, and no single-byte ESC/POS
        // code page does.
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_catalogue_columns_are_the_ones_the_product_declares() {
        assert_eq!(Model::Led8.columns(), 8);
        assert_eq!(Model::Vfd20.columns(), 20);
        assert_eq!(Model::Lcd2x20.columns(), 20);
        assert_eq!(Model::Led8.lines(), 1);
        assert_eq!(Model::Vfd20.lines(), 2);
    }

    #[test]
    fn vfd_write_line_addresses_the_cursor_then_pads_to_the_full_width() {
        let e = encode(Model::Vfd20, Op::WriteLine, 1, 0, 0, "ИТОГО:").unwrap();
        assert_eq!(&e.bytes[..4], &[0x1B, 0x24, 0x00, 0x01]);
        assert_eq!(e.bytes.len(), 4 + 20);
        // И Т О Г О : then fourteen spaces.
        assert_eq!(
            &e.bytes[4..],
            &[
                0x88, 0x92, 0x8E, 0x83, 0x8E, 0x3A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
                0x20, 0x20, 0x20, 0x20, 0x20, 0x20
            ]
        );
        assert_eq!(e.substitutions, 0);
    }

    #[test]
    fn led_write_line_goes_home_rather_than_clearing_the_display() {
        let e = encode(Model::Led8, Op::WriteLine, 0, 0, 0, "12.50").unwrap();
        assert_eq!(
            e.bytes,
            vec![0x0B, b'1', b'2', b'.', b'5', b'0', 0x20, 0x20, 0x20]
        );
    }

    #[test]
    fn led_has_no_second_line_and_says_so() {
        assert_eq!(
            encode(Model::Led8, Op::WriteLine, 1, 0, 0, "x"),
            Err(Status::OutOfRange)
        );
        assert_eq!(
            encode(Model::Led8, Op::SetCursor, 0, 0, 0, ""),
            Err(Status::UnsupportedOperation)
        );
        assert_eq!(
            encode(Model::Led8, Op::Reset, 0, 0, 0, ""),
            Err(Status::UnsupportedOperation)
        );
    }

    #[test]
    fn led_and_vfd_switch_themselves_on_with_different_bytes() {
        assert_eq!(
            encode(Model::Led8, Op::DisplayOn, 0, 0, 0, "")
                .unwrap()
                .bytes,
            vec![0x14]
        );
        assert_eq!(
            encode(Model::Vfd20, Op::DisplayOn, 0, 0, 0, "")
                .unwrap()
                .bytes,
            vec![0x1B, 0x28]
        );
    }

    #[test]
    fn brightness_is_bounded_by_the_protocol_not_clamped_into_silence() {
        assert_eq!(
            encode(Model::Vfd20, Op::SetBrightness, 0, 0, 7, "")
                .unwrap()
                .bytes,
            vec![0x1B, 0x2A, 0x07]
        );
        assert_eq!(
            encode(Model::Vfd20, Op::SetBrightness, 0, 0, 8, ""),
            Err(Status::OutOfRange)
        );
    }

    #[test]
    fn lowercase_cyrillic_lands_where_cp866_actually_puts_it() {
        // The bug this module exists for: `р` is 0xE0, not 0xB0.
        let e = encode_text("ар");
        assert_eq!(e.bytes, vec![0xA0, 0xE0]);
        assert_eq!(e.substitutions, 0);
        // The whole lowercase range, both halves.
        assert_eq!(encode_text("абвгдеёжзийклмноп").bytes.len(), 17);
        assert_eq!(encode_text("п").bytes, vec![0xAF]);
        assert_eq!(encode_text("я").bytes, vec![0xEF]);
        assert_eq!(encode_text("А").bytes, vec![0x80]);
        assert_eq!(encode_text("Я").bytes, vec![0x9F]);
        assert_eq!(encode_text("Ё").bytes, vec![0xF0]);
        assert_eq!(encode_text("ё").bytes, vec![0xF1]);
    }

    #[test]
    fn a_character_cp866_cannot_hold_is_counted_not_swallowed() {
        let e = encode_text("100 ₸");
        assert_eq!(e.bytes, vec![b'1', b'0', b'0', b' ', 0x20]);
        assert_eq!(e.substitutions, 1);

        let kazakh = encode_text("әңүқғ");
        assert_eq!(kazakh.bytes, vec![0x20; 5]);
        assert_eq!(kazakh.substitutions, 5);
    }

    #[test]
    fn a_line_longer_than_the_display_is_truncated_not_wrapped() {
        let e = encode(Model::Led8, Op::WriteLine, 0, 0, 0, "1234567890").unwrap();
        assert_eq!(
            e.bytes,
            vec![0x0B, b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8']
        );
    }

    #[test]
    fn clear_is_the_same_form_feed_on_every_model() {
        for m in [Model::Led8, Model::Vfd20, Model::Lcd2x20] {
            assert_eq!(encode(m, Op::Clear, 0, 0, 0, "").unwrap().bytes, vec![0x0C]);
        }
    }

    #[test]
    fn an_unknown_model_is_never_substituted_for_a_similar_one() {
        assert_eq!(Model::from_name("vfd21"), Err(Status::UnknownName));
        assert_eq!(Op::from_name("scroll"), Err(Status::UnknownName));
    }
}
