//! The RFC 5424 TIMESTAMP, formatted from a caller-supplied instant.
//!
//! The instant is supplied, never read from the clock here, for two reasons.
//! A till's timezone is known to the layer above and guessing it in native
//! code would be guessing. And a formatter with no hidden input is a
//! formatter that can be tested exactly, which is what a timestamp deserves:
//! it is the field an investigation sorts by.
//!
//! Grammar (RFC 5424 §6.2.3, itself a subset of RFC 3339):
//!
//! ```text
//! TIMESTAMP  = NILVALUE / FULL-DATE "T" FULL-TIME
//! FULL-DATE  = 4DIGIT "-" 2DIGIT "-" 2DIGIT
//! FULL-TIME  = PARTIAL-TIME TIME-OFFSET
//! PARTIAL-TIME = 2DIGIT ":" 2DIGIT ":" 2DIGIT [TIME-SECFRAC]
//! TIME-SECFRAC = "." 1*6DIGIT
//! TIME-OFFSET  = "Z" / ("+" / "-") 2DIGIT ":" 2DIGIT
//! ```

use crate::status::{Failure, Fallible, Status};

const MICROS_PER_SEC: i64 = 1_000_000;
const MICROS_PER_DAY: i64 = 86_400 * MICROS_PER_SEC;

/// Formats `epoch_micros` (microseconds since 1970-01-01T00:00:00Z) at
/// `offset_minutes` east of UTC.
///
/// Fails rather than clamps. A year outside 0000–9999 has no four-digit
/// representation and an offset beyond a day is not a timezone, and in both
/// cases a wrong-but-plausible timestamp is worse than a refusal — this is
/// exactly the field a wrong value would send an investigation down the wrong
/// hour.
pub fn format_timestamp(epoch_micros: i64, offset_minutes: i32) -> Fallible<String> {
    if !(-1439..=1439).contains(&offset_minutes) {
        return Err(Failure::new(
            Status::InvalidMessage,
            format!("utc offset {offset_minutes} minutes is outside -1439..=1439"),
        ));
    }

    let offset_micros = offset_minutes as i64 * 60 * MICROS_PER_SEC;
    let local = epoch_micros.checked_add(offset_micros).ok_or_else(|| {
        Failure::new(
            Status::InvalidMessage,
            format!("timestamp {epoch_micros}us overflows when shifted to local time"),
        )
    })?;

    let days = local.div_euclid(MICROS_PER_DAY);
    let micros_of_day = local.rem_euclid(MICROS_PER_DAY);

    let (year, month, day) = civil_from_days(days);
    if !(0..=9999).contains(&year) {
        return Err(Failure::new(
            Status::InvalidMessage,
            format!("year {year} has no four-digit form; RFC 5424 requires DATE-FULLYEAR"),
        ));
    }

    let secs_of_day = micros_of_day / MICROS_PER_SEC;
    let frac = micros_of_day % MICROS_PER_SEC;
    let (hour, minute, second) = (
        secs_of_day / 3600,
        (secs_of_day / 60) % 60,
        secs_of_day % 60,
    );

    let mut out =
        format!("{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}.{frac:06}");
    if offset_minutes == 0 {
        out.push('Z');
    } else {
        let sign = if offset_minutes < 0 { '-' } else { '+' };
        let abs = offset_minutes.unsigned_abs();
        out.push_str(&format!("{sign}{:02}:{:02}", abs / 60, abs % 60));
    }
    Ok(out)
}

/// Days since 1970-01-01 to a proleptic Gregorian civil date.
///
/// Howard Hinnant's `civil_from_days`, which is the reference implementation
/// everyone uses because the obvious loop over years is where off-by-one leap
/// year bugs live.
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097; // [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365; // [0, 399]
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
    let mp = (5 * doy + 2) / 153; // [0, 11]
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32; // [1, 31]
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32; // [1, 12]
    (if m <= 2 { y + 1 } else { y }, m, d)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats_the_rfc_5424_example_instant() {
        // RFC 5424 §6.5 example 1 is 2003-10-11T22:14:15.003Z. We always
        // print six fractional digits, which the grammar allows.
        let micros = 1_065_910_455_003_000;
        assert_eq!(
            format_timestamp(micros, 0).unwrap(),
            "2003-10-11T22:14:15.003000Z"
        );
    }

    #[test]
    fn formats_a_negative_offset() {
        // RFC 5424 §6.5 example 2: 2003-08-24T05:14:15.000003-07:00.
        let utc_micros = 1_061_727_255_000_003; // 2003-08-24T12:14:15.000003Z
        assert_eq!(
            format_timestamp(utc_micros, -7 * 60).unwrap(),
            "2003-08-24T05:14:15.000003-07:00"
        );
    }

    #[test]
    fn formats_epoch_and_a_half_hour_zone() {
        assert_eq!(
            format_timestamp(0, 0).unwrap(),
            "1970-01-01T00:00:00.000000Z"
        );
        // Kathmandu, +05:45 — the case that catches an implementation that
        // assumed offsets are whole hours.
        assert_eq!(
            format_timestamp(0, 345).unwrap(),
            "1970-01-01T05:45:00.000000+05:45"
        );
    }

    #[test]
    fn handles_instants_before_the_epoch() {
        // -1us must be the last microsecond of 1969, not a negative field.
        assert_eq!(
            format_timestamp(-1, 0).unwrap(),
            "1969-12-31T23:59:59.999999Z"
        );
    }

    #[test]
    fn handles_leap_days_and_century_rules() {
        // 2000 was a leap year, 1900 was not. A hand-rolled calendar that
        // only checks %4 gets 2000-02-29 right and 1900-03-01 wrong.
        let leap_2000 = 951_782_400_000_000; // 2000-02-29T00:00:00Z
        assert_eq!(
            format_timestamp(leap_2000, 0).unwrap(),
            "2000-02-29T00:00:00.000000Z"
        );
        let march_1900 = -2_203_891_200_000_000; // 1900-03-01T00:00:00Z
        assert_eq!(
            format_timestamp(march_1900, 0).unwrap(),
            "1900-03-01T00:00:00.000000Z"
        );
    }

    #[test]
    fn rejects_an_impossible_offset() {
        let err = format_timestamp(0, 1440).unwrap_err();
        assert_eq!(err.status, Status::InvalidMessage);
        assert!(err.detail.contains("1440"));
    }

    #[test]
    fn rejects_a_year_with_no_four_digit_form() {
        // Far past: the grammar has no room for it, so we refuse instead of
        // printing a five-digit or negative year a collector would misparse.
        let err = format_timestamp(i64::MIN / 2, 0).unwrap_err();
        assert_eq!(err.status, Status::InvalidMessage);
    }

    #[test]
    fn round_trips_every_day_across_four_centuries() {
        // Compares the fast formula against a straightforward day counter,
        // which is the only cheap way to be sure of a calendar.
        fn is_leap(y: i64) -> bool {
            (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
        }
        const LENGTHS: [u32; 12] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

        let mut days = -25_567; // 1900-01-01
        let (mut y, mut m, mut d) = (1900i64, 1u32, 1u32);
        while y < 2300 {
            assert_eq!(civil_from_days(days), (y, m, d), "day {days}");
            days += 1;
            let len = if m == 2 && is_leap(y) {
                29
            } else {
                LENGTHS[(m - 1) as usize]
            };
            d += 1;
            if d > len {
                d = 1;
                m += 1;
                if m > 12 {
                    m = 1;
                    y += 1;
                }
            }
        }
    }
}
