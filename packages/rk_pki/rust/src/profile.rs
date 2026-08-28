//! Certificate profiles and the one rotation rule that covers all of them.

use serde::{Deserialize, Serialize};

use crate::error::{PkiError, PkiResult};

const DAY: i64 = 24 * 60 * 60;

/// The hard ceiling the WebTransport specification puts on a certificate a
/// browser trusts by hash rather than by chain: 14 days. Anything at or above
/// it is refused by the browser, so the browser-facing profile must stay
/// comfortably below it rather than sit on the line.
pub const BROWSER_FACING_CEILING_SECS: i64 = 14 * DAY;

/// A machine holds more than one leaf certificate at a time, from one
/// authority, differing only in lifetime and in who is asked to trust it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CertProfile {
    /// Internal mutual TLS: till to shop server to chain server to relay.
    /// A browser never sees it, so no browser rule applies to it.
    Machine,
    /// Presented to a browser over WebTransport, where the browser may be
    /// pinning the hash instead of walking a chain.
    BrowserFacing,
}

impl CertProfile {
    /// The name this value has on the wire, in a file name and in a log.
    /// И147: never an index — inserting a third profile must not change what
    /// an already-stored value means.
    pub const fn wire_name(self) -> &'static str {
        match self {
            Self::Machine => "machine",
            Self::BrowserFacing => "browserFacing",
        }
    }

    pub fn from_wire_name(name: &str) -> PkiResult<Self> {
        match name {
            "machine" => Ok(Self::Machine),
            "browserFacing" => Ok(Self::BrowserFacing),
            other => Err(PkiError::bad_request(format!(
                "unknown certificate profile name: {other:?}"
            ))),
        }
    }

    /// How long a freshly issued certificate of this profile is valid.
    pub const fn lifetime_secs(self) -> i64 {
        match self {
            Self::Machine => 30 * DAY,
            Self::BrowserFacing => 7 * DAY,
        }
    }

    /// Rotation starts when a third of the lifetime is left — one rule for
    /// every profile, so a new profile cannot arrive without a rotation
    /// policy. For the machine profile that is 10 days, which is more than
    /// three times the only autonomy figure that exists in the product today
    /// (the 72-hour offline fiscal window).
    pub const fn rotate_when_remaining_secs(self) -> i64 {
        self.lifetime_secs() / 3
    }

    /// The moment rotation becomes due for a certificate expiring at `not_after`.
    pub const fn rotate_at(self, not_after: i64) -> i64 {
        not_after - self.rotate_when_remaining_secs()
    }

    pub const fn all() -> [Self; 2] {
        [Self::Machine, Self::BrowserFacing]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_round_trip_and_unknown_names_are_refused() {
        for p in CertProfile::all() {
            assert_eq!(CertProfile::from_wire_name(p.wire_name()).unwrap(), p);
        }
        assert!(CertProfile::from_wire_name("0").is_err());
        assert!(CertProfile::from_wire_name("browserfacing").is_err());
    }

    #[test]
    fn serde_uses_the_same_names_as_wire_name() {
        for p in CertProfile::all() {
            let json = serde_json::to_value(p).unwrap();
            assert_eq!(json.as_str().unwrap(), p.wire_name());
        }
    }

    #[test]
    fn the_browser_profile_stays_under_the_webtransport_ceiling() {
        assert!(
            CertProfile::BrowserFacing.lifetime_secs() < BROWSER_FACING_CEILING_SECS,
            "a browser refuses a hash-pinned certificate at or over 14 days"
        );
        // and with room to rotate, not on the line
        assert!(CertProfile::BrowserFacing.lifetime_secs() * 2 <= BROWSER_FACING_CEILING_SECS);
    }

    #[test]
    fn rotation_leaves_a_third_of_the_life() {
        assert_eq!(CertProfile::Machine.rotate_when_remaining_secs(), 10 * DAY);
        assert_eq!(
            CertProfile::Machine.rotate_at(1_000_000 + 30 * DAY),
            1_000_000 + 20 * DAY
        );
    }
}
