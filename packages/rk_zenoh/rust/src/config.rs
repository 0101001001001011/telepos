//! Building a Zenoh configuration, including the one decision this package
//! exists to make explicit: **whether the Zenoh ID is pinned**.
//!
//! A Zenoh session gets a fresh Zenoh ID (ZID) every time it opens unless the
//! configuration says otherwise. For a till that restarts on updates, crashes
//! and changes bindings, "every time it opens" is a routine event, and any
//! peer that recorded the old ZID as *the address of that till* now holds a
//! dead one. See `doc/stale-zid.md` for the measurement.
//!
//! This module offers both answers and refuses to choose for the caller:
//!
//! * leave the ZID unset — it is an ephemeral handle, and the durable identity
//!   is the terminal identity carried in key expressions;
//! * pin it with [`RkzConfigBuilder::pin_zid`] — routes survive a restart, and
//!   the caller must then also supply mutual TLS, because a pinned ZID on its
//!   own cannot tell a restart from an impostor.

use std::fmt::Write as _;
use std::str::FromStr as _;

use zenoh::config::Config;
use zenoh::session::ZenohId;

use crate::names;
use crate::status::{ErrorKind, RkzError, RkzResult};

/// A Zenoh ID: 1 to 16 bytes, written as lowercase hex.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Zid(String);

impl Zid {
    /// Parse a ZID from hex.
    ///
    /// Validation is delegated to Zenoh's own `ZenohId` rather than
    /// reimplemented, because reimplementing it was already wrong once: a
    /// hand-written "even number of hex digits, at most sixteen bytes" check
    /// looks right and misses that **a leading zero is refused** — Zenoh
    /// stores the id as a little-endian `u128` and prints it without leading
    /// zeros, so `0a0b` is not a canonical id at all. A configuration built
    /// from such a value is rejected only when the session tries to open,
    /// which is far too late to be useful.
    pub fn parse(hex: &str) -> RkzResult<Zid> {
        let lowered = hex.trim().to_ascii_lowercase();
        ZenohId::from_str(&lowered).map_err(|e| {
            RkzError::new(
                ErrorKind::InvalidConfig,
                format!("{hex:?} is not a zenoh id: {e}"),
            )
        })?;
        Ok(Zid(lowered))
    }

    /// Derive a stable ZID from a durable identity string.
    ///
    /// This is the bridge between the two answers: a caller that wants pinned
    /// routes but has no ZID to remember can derive one from the terminal
    /// identity it already has. The derivation is a plain FNV-1a over the
    /// bytes — it is **not** a secret and **not** an authenticator. Two
    /// different identities colliding would be a routing collision, so the
    /// full 16 bytes are used and the identity is included verbatim in the
    /// certificate subject that actually authenticates the peer.
    ///
    /// The top nibble is forced away from zero when the hash lands there,
    /// because Zenoh refuses an id with a leading zero. That costs at most one
    /// value out of sixteen at the top of the space and nothing anywhere else.
    pub fn derive(identity: &str) -> Zid {
        // FNV-1a, twice with different offsets, to fill 16 bytes.
        fn fnv(bytes: &[u8], mut hash: u64) -> u64 {
            for b in bytes {
                hash ^= u64::from(*b);
                hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
            }
            hash
        }
        let a = fnv(identity.as_bytes(), 0xcbf2_9ce4_8422_2325);
        let b = fnv(identity.as_bytes(), 0x9e37_79b9_7f4a_7c15);
        let a = if a >> 60 == 0 {
            a | 0x1000_0000_0000_0000
        } else {
            a
        };
        let mut out = String::with_capacity(32);
        write!(out, "{a:016x}{b:016x}").expect("writing to a String cannot fail");
        Zid(out)
    }

    /// The hex form, lowercase.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Everything the Dart side is allowed to set, gathered before a session opens.
///
/// Deliberately narrow. The full Zenoh configuration is a large JSON5 document
/// and exposing it whole would make every field of it our compatibility
/// promise; a caller that genuinely needs the rest passes it as
/// [`RkzConfigBuilder::extra_json5`] and owns the consequences.
#[derive(Debug, Clone, Default)]
pub struct RkzConfigBuilder {
    mode: Option<String>,
    zid: Option<Zid>,
    connect: Vec<String>,
    listen: Vec<String>,
    multicast_scouting: Option<bool>,
    gossip_scouting: Option<bool>,
    extra_json5: Option<String>,
}

impl RkzConfigBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    /// `"peer"`, `"client"` or `"router"`, by name (И147).
    pub fn mode(&mut self, name: &str) -> RkzResult<&mut Self> {
        self.mode = Some(names::session_mode(name)?.to_string());
        Ok(self)
    }

    /// Pin the Zenoh ID so a recreated session keeps the identity its peers
    /// already route to.
    ///
    /// Only meaningful together with mutual TLS: without it, a pinned ZID is
    /// an unauthenticated claim, and the fabric cannot tell the till that
    /// restarted from a machine asserting that it is the till.
    pub fn pin_zid(&mut self, zid: Zid) -> &mut Self {
        self.zid = Some(zid);
        self
    }

    /// An endpoint this session dials, such as `tcp/10.0.0.2:7447`.
    pub fn connect(&mut self, endpoint: &str) -> &mut Self {
        self.connect.push(endpoint.to_string());
        self
    }

    /// An endpoint this session listens on.
    pub fn listen(&mut self, endpoint: &str) -> &mut Self {
        self.listen.push(endpoint.to_string());
        self
    }

    /// Whether to look for peers by UDP multicast.
    ///
    /// Off is the honest default for us: multicast works on one shop LAN and
    /// nowhere across it, and the fabric does not traverse NAT in any case.
    pub fn multicast_scouting(&mut self, on: bool) -> &mut Self {
        self.multicast_scouting = Some(on);
        self
    }

    /// Whether to learn about further peers from the ones already known.
    pub fn gossip_scouting(&mut self, on: bool) -> &mut Self {
        self.gossip_scouting = Some(on);
        self
    }

    /// A JSON5 object merged underneath everything set above.
    ///
    /// This is how TLS material reaches the session without this crate growing
    /// a field per certificate path.
    pub fn extra_json5(&mut self, json5: &str) -> &mut Self {
        self.extra_json5 = Some(json5.to_string());
        self
    }

    /// Whether a ZID is pinned, which the session uses to refuse an
    /// unauthenticated pin.
    pub fn has_pinned_zid(&self) -> bool {
        self.zid.is_some()
    }

    /// Whether anything in the configuration turns on TLS or QUIC.
    ///
    /// A blunt test on purpose: it looks for a TLS endpoint or a `tls` block,
    /// which is what actually causes certificates to be checked.
    pub fn appears_authenticated(&self) -> bool {
        fn endpoint_is_secure(e: &str) -> bool {
            let e = e.to_ascii_lowercase();
            e.starts_with("tls/") || e.starts_with("quic/")
        }
        self.connect.iter().any(|e| endpoint_is_secure(e))
            || self.listen.iter().any(|e| endpoint_is_secure(e))
            || self.extra_json5.as_deref().is_some_and(|extra| {
                extra.contains("root_ca_certificate") || extra.contains("enable_mtls")
            })
    }

    /// Render the effective configuration, as Zenoh itself holds it.
    ///
    /// Exposed so a caller can log exactly what a session was opened with —
    /// the commonest cause of a fabric that does not converge is a
    /// configuration nobody looked at. This is the built document, not the
    /// caller's intent, so it can never drift from what [`build`] produces.
    ///
    /// [`build`]: RkzConfigBuilder::build
    pub fn to_json5(&self) -> String {
        match self.build() {
            Ok(config) => config.to_string(),
            Err(e) => format!("<not a valid configuration: {}>", e.detail),
        }
    }

    /// Turn this into a Zenoh configuration, or say why it cannot be one.
    ///
    /// Typed settings are applied **on top of** `extra_json5` through Zenoh's
    /// own insertion, one key at a time. Concatenating them into a single
    /// document instead looks simpler and is wrong: JSON5 rejects a duplicated
    /// key outright, so a caller who set `id` in `extra_json5` and also pinned
    /// one would lose the whole configuration rather than have the pin win.
    pub fn build(&self) -> RkzResult<Config> {
        let base = self.extra_json5.as_deref().unwrap_or("{}");
        let mut config = Config::from_json5(base).map_err(|e| {
            RkzError::new(
                ErrorKind::InvalidConfig,
                format!("zenoh refused the supplied json5 {base}: {e}"),
            )
        })?;

        fn insert(config: &mut Config, key: &str, value: &str) -> RkzResult<()> {
            config.insert_json5(key, value).map_err(|e| {
                RkzError::new(
                    ErrorKind::InvalidConfig,
                    format!("zenoh refused {key} = {value}: {e}"),
                )
            })
        }

        if let Some(zid) = &self.zid {
            insert(&mut config, "id", &format!("\"{}\"", zid.as_str()))?;
        }
        if let Some(mode) = &self.mode {
            insert(&mut config, "mode", &format!("\"{mode}\""))?;
        }
        if !self.connect.is_empty() {
            insert(
                &mut config,
                "connect/endpoints",
                &json_string_array(&self.connect),
            )?;
        }
        if !self.listen.is_empty() {
            insert(
                &mut config,
                "listen/endpoints",
                &json_string_array(&self.listen),
            )?;
        }
        if let Some(on) = self.multicast_scouting {
            insert(&mut config, "scouting/multicast/enabled", &on.to_string())?;
        }
        if let Some(on) = self.gossip_scouting {
            insert(&mut config, "scouting/gossip/enabled", &on.to_string())?;
        }
        Ok(config)
    }
}

fn json_string_array(items: &[String]) -> String {
    let mut out = String::from("[");
    for (i, item) in items.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        let _ = write!(
            out,
            "\"{}\"",
            item.replace('\\', "\\\\").replace('"', "\\\"")
        );
    }
    out.push(']');
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_zid_is_lowercase_hex_without_a_leading_zero() {
        assert!(Zid::parse("a1b2").is_ok());
        assert_eq!(Zid::parse("A1B2").unwrap().as_str(), "a1b2");
        assert!(
            Zid::parse("abc").is_ok(),
            "an odd number of digits is a valid id"
        );
        assert!(Zid::parse("").is_err());
        assert!(Zid::parse("zz").is_err());
        assert!(
            Zid::parse("0a0b").is_err(),
            "a leading zero must be refused here rather than when the session opens"
        );
        assert!(
            Zid::parse(&"ab".repeat(17)).is_err(),
            "over 16 bytes must be refused"
        );
        assert!(Zid::parse(&"ab".repeat(16)).is_ok());
    }

    #[test]
    fn derivation_is_stable_and_distinguishes_identities() {
        let a = Zid::derive("till-17.shop-3.telepos");
        assert_eq!(a, Zid::derive("till-17.shop-3.telepos"));
        assert_ne!(a, Zid::derive("till-18.shop-3.telepos"));
        assert_eq!(a.as_str().len(), 32);
        assert!(
            Zid::parse(a.as_str()).is_ok(),
            "a derived zid must also be a valid one"
        );
    }

    /// The leading-zero rule bites roughly one identity in sixteen, so a
    /// handful of examples proves nothing. This walks enough of the space to
    /// be sure the guard in `derive` is doing its job.
    #[test]
    fn no_derived_zid_can_ever_be_refused() {
        for n in 0..5000 {
            let identity = format!("till-{n}.shop-{}.telepos", n % 37);
            let zid = Zid::derive(&identity);
            assert!(
                !zid.as_str().starts_with('0'),
                "{identity} derived {zid:?}, which zenoh refuses"
            );
            Zid::parse(zid.as_str())
                .unwrap_or_else(|e| panic!("{identity} derived an invalid zid: {}", e.detail));
        }
    }

    /// What zenoh itself reads back out of the built configuration, so that a
    /// pin which is present in the text but inert — commented out, in the
    /// wrong place, shadowed by `extra_json5` — cannot pass for a pin.
    fn built_id(b: &RkzConfigBuilder) -> String {
        b.build()
            .expect("the configuration must be valid")
            .get_json("id")
            .unwrap_or_default()
    }

    #[test]
    fn the_pin_is_the_one_zenoh_reads_back() {
        let mut b = RkzConfigBuilder::new();
        b.mode("peer").unwrap().pin_zid(Zid::parse("a0b").unwrap());
        assert!(b.has_pinned_zid());
        assert_eq!(built_id(&b), "\"a0b\"", "rendered as {}", b.to_json5());
    }

    #[test]
    fn without_a_pin_zenoh_reads_back_no_id() {
        let mut b = RkzConfigBuilder::new();
        b.mode("peer").unwrap();
        assert!(!b.has_pinned_zid());
        assert_eq!(built_id(&b), "null", "rendered as {}", b.to_json5());
    }

    #[test]
    fn a_typed_pin_wins_over_one_smuggled_through_extra_json5() {
        let mut b = RkzConfigBuilder::new();
        b.mode("peer")
            .unwrap()
            .extra_json5("{ id: \"dead\" }")
            .pin_zid(Zid::parse("a0b").unwrap());
        assert_eq!(built_id(&b), "\"a0b\"", "rendered as {}", b.to_json5());
    }

    #[test]
    fn a_plain_tcp_configuration_is_not_authenticated() {
        let mut b = RkzConfigBuilder::new();
        b.connect("tcp/127.0.0.1:7447");
        assert!(!b.appears_authenticated());
    }

    #[test]
    fn a_tls_endpoint_counts_as_authenticated() {
        let mut b = RkzConfigBuilder::new();
        b.connect("tls/shop-3.telepos:7447");
        assert!(b.appears_authenticated());
    }

    #[test]
    fn the_built_configuration_is_accepted_by_zenoh() {
        let mut b = RkzConfigBuilder::new();
        b.mode("peer")
            .unwrap()
            .pin_zid(Zid::derive("till-17"))
            .listen("tcp/127.0.0.1:0")
            .multicast_scouting(false)
            .gossip_scouting(true);
        b.build().expect("zenoh must accept what we render");
    }

    #[test]
    fn an_endpoint_with_a_quote_cannot_change_another_setting() {
        let mut b = RkzConfigBuilder::new();
        b.mode("peer")
            .unwrap()
            .connect("tcp/1.2.3.4:1\", mode: \"router");
        // Either zenoh refuses the endpoint or it keeps it as one opaque
        // string. What must never happen is the smuggled `mode` taking effect,
        // so the assertion is about the built configuration, not about the
        // text: a test that only greps the text passes when nothing was built.
        match b.build() {
            Ok(config) => assert_eq!(
                config.get_json("mode").unwrap_or_default(),
                "\"peer\"",
                "the smuggled mode took effect"
            ),
            Err(e) => assert_eq!(e.kind, ErrorKind::InvalidConfig),
        }
    }
}
