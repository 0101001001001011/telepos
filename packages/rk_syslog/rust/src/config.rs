//! Configuration, set one named key at a time.
//!
//! Not a C struct of fields, and not a JSON blob. A struct pins meaning to a
//! position, which is the mistake И147 exists to prevent, and adding a field
//! to one would break every already-built caller. A blob would need a parser
//! and would swallow a misspelled key.
//!
//! Named keys give the third thing, which is the one that matters: a key this
//! version does not recognise is a **returned failure**, so `spool_max_byte`
//! stops the sink from opening instead of quietly leaving the bound at its
//! default and letting a disk fill up months later.

use std::collections::BTreeMap;
use std::time::Duration;

use crate::queue::QueuePolicy;
use crate::rfc5424::{Oversize, SinkIdentity};
use crate::severity::Facility;
use crate::spool::{SpoolLimits, SpoolPolicy};
use crate::status::{Failure, Fallible, Status};
use crate::transport::{CollectorSettings, Scheme};

/// Every key this version accepts, with its default. A key with `None` has no
/// default and must be set.
///
/// Kept as one table so the answer to "what can I configure" is a place, not
/// a search.
pub const KEYS: &[(&str, Option<&str>)] = &[
    ("host_name", Some("-")),
    ("app_name", Some("-")),
    ("proc_id", Some("-")),
    ("facility", Some("local0")),
    ("spool_dir", None),
    ("spool_max_bytes", Some("67108864")),
    ("spool_segment_bytes", Some("1048576")),
    ("spool_policy", Some("drop_oldest")),
    ("queue_max_records", Some("4096")),
    ("queue_policy", Some("reject")),
    ("collector_scheme", Some("none")),
    ("collector_host", Some("")),
    ("collector_port", Some("6514")),
    ("tls_server_name", Some("")),
    ("tls_roots_pem", Some("")),
    ("tls_server_fingerprint_sha256", Some("")),
    ("tls_client_cert_pem", Some("")),
    ("tls_client_key_pem", Some("")),
    ("max_message_bytes", Some("8192")),
    ("oversize", Some("truncate")),
    ("msg_bom", Some("true")),
    ("connect_timeout_ms", Some("5000")),
    ("write_timeout_ms", Some("5000")),
    ("retry_min_ms", Some("500")),
    ("retry_max_ms", Some("30000")),
];

/// A bag of key/value pairs on its way to becoming a [`Settings`].
#[derive(Debug, Clone, Default)]
pub struct ConfigBuilder {
    values: BTreeMap<String, String>,
}

impl ConfigBuilder {
    pub fn new() -> ConfigBuilder {
        ConfigBuilder::default()
    }

    /// Sets one key. An unknown key is refused, with the near misses listed.
    pub fn set(&mut self, key: &str, value: &str) -> Fallible<()> {
        if !KEYS.iter().any(|(known, _)| *known == key) {
            let near: Vec<&str> = KEYS
                .iter()
                .map(|(k, _)| *k)
                .filter(|k| {
                    let head = key.split('_').next().unwrap_or(key);
                    !head.is_empty() && k.starts_with(head)
                })
                .collect();
            let hint = if near.is_empty() {
                String::new()
            } else {
                format!("; did you mean one of: {}", near.join(", "))
            };
            return Err(Failure::new(
                Status::UnknownConfigKey,
                format!("'{key}' is not a configuration key of this version{hint}"),
            ));
        }
        self.values.insert(key.to_string(), value.to_string());
        Ok(())
    }

    fn raw(&self, key: &str) -> Fallible<&str> {
        if let Some(value) = self.values.get(key) {
            return Ok(value);
        }
        match KEYS.iter().find(|(k, _)| *k == key) {
            Some((_, Some(default))) => Ok(default),
            _ => Err(Failure::new(
                Status::MissingConfigKey,
                format!("'{key}' has no default and was not set"),
            )),
        }
    }

    fn number<T: std::str::FromStr>(&self, key: &str) -> Fallible<T> {
        let raw = self.raw(key)?;
        raw.parse::<T>().map_err(|_| {
            Failure::new(
                Status::InvalidConfigValue,
                format!("'{key}' is '{raw}', which is not a number this key accepts"),
            )
        })
    }

    fn boolean(&self, key: &str) -> Fallible<bool> {
        match self.raw(key)? {
            "true" => Ok(true),
            "false" => Ok(false),
            other => Err(Failure::new(
                Status::InvalidConfigValue,
                format!("'{key}' is '{other}'; it takes 'true' or 'false'"),
            )),
        }
    }

    fn optional_path(&self, key: &str) -> Fallible<Option<String>> {
        let raw = self.raw(key)?;
        Ok(if raw.is_empty() {
            None
        } else {
            Some(raw.to_string())
        })
    }

    fn named<T>(&self, key: &str, parse: impl Fn(&str) -> Option<T>, allowed: &str) -> Fallible<T> {
        let raw = self.raw(key)?;
        parse(raw).ok_or_else(|| {
            Failure::new(
                Status::InvalidConfigValue,
                format!("'{key}' is '{raw}'; it takes one of: {allowed}"),
            )
        })
    }

    /// Turns the bag into settings, checking everything that can be checked
    /// before a single record exists.
    pub fn build(&self) -> Fallible<Settings> {
        let identity = SinkIdentity {
            hostname: self.raw("host_name")?.to_string(),
            app_name: self.raw("app_name")?.to_string(),
            proc_id: self.raw("proc_id")?.to_string(),
        };
        identity.validate()?;

        let facility = Facility::from_name(self.raw("facility")?)?;
        let max_message_bytes: usize = self.number("max_message_bytes")?;
        if max_message_bytes < 480 {
            // RFC 5425 §4.2 obliges a receiver to take 2048 octets and asks
            // for 8192. A limit below a few hundred cannot hold a header plus
            // anything useful, so it is a mistake rather than a preference.
            return Err(Failure::new(
                Status::InvalidConfigValue,
                format!(
                    "'max_message_bytes' is {max_message_bytes}; below 480 there is no \
                     room for a header and a message"
                ),
            ));
        }

        let spool = SpoolLimits {
            max_bytes: self.number("spool_max_bytes")?,
            segment_bytes: self.number("spool_segment_bytes")?,
            policy: self.named(
                "spool_policy",
                SpoolPolicy::from_name,
                "drop_oldest, reject",
            )?,
        };

        let collector = CollectorSettings {
            scheme: self.named("collector_scheme", Scheme::from_name, "none, tls, tcp")?,
            host: self.raw("collector_host")?.to_string(),
            port: self.number("collector_port")?,
            server_name: self.optional_path("tls_server_name")?,
            roots_pem: self.optional_path("tls_roots_pem")?,
            fingerprint_sha256: self.optional_path("tls_server_fingerprint_sha256")?,
            client_cert_pem: self.optional_path("tls_client_cert_pem")?,
            client_key_pem: self.optional_path("tls_client_key_pem")?,
            connect_timeout: Duration::from_millis(self.number("connect_timeout_ms")?),
            write_timeout: Duration::from_millis(self.number("write_timeout_ms")?),
        };

        let retry_min = Duration::from_millis(self.number("retry_min_ms")?);
        let retry_max = Duration::from_millis(self.number("retry_max_ms")?);
        if retry_min > retry_max || retry_min.is_zero() {
            return Err(Failure::new(
                Status::InvalidConfigValue,
                format!(
                    "'retry_min_ms' ({}) must be above zero and no larger than \
                     'retry_max_ms' ({})",
                    retry_min.as_millis(),
                    retry_max.as_millis()
                ),
            ));
        }

        Ok(Settings {
            identity,
            facility,
            spool_dir: self.raw("spool_dir")?.to_string(),
            spool,
            queue_capacity: self.number("queue_max_records")?,
            queue_policy: self.named(
                "queue_policy",
                QueuePolicy::from_name,
                "drop_oldest, reject",
            )?,
            collector,
            max_message_bytes,
            oversize: self.named("oversize", Oversize::from_name, "truncate, reject")?,
            emit_bom: self.boolean("msg_bom")?,
            retry_min,
            retry_max,
        })
    }
}

/// Configuration that has been checked.
#[derive(Debug, Clone)]
pub struct Settings {
    pub identity: SinkIdentity,
    pub facility: Facility,
    pub spool_dir: String,
    pub spool: SpoolLimits,
    pub queue_capacity: usize,
    pub queue_policy: QueuePolicy,
    pub collector: CollectorSettings,
    pub max_message_bytes: usize,
    pub oversize: Oversize,
    pub emit_bom: bool,
    pub retry_min: Duration,
    pub retry_max: Duration,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn minimal() -> ConfigBuilder {
        let mut builder = ConfigBuilder::new();
        builder.set("spool_dir", "/tmp/rk-syslog-test").unwrap();
        builder
    }

    #[test]
    fn defaults_are_enough_once_the_spool_directory_is_known() {
        let settings = minimal().build().unwrap();
        assert_eq!(settings.facility, Facility::Local0);
        assert_eq!(settings.collector.scheme, Scheme::None);
        assert_eq!(settings.spool.policy, SpoolPolicy::DropOldest);
        assert_eq!(settings.queue_policy, QueuePolicy::Reject);
        assert_eq!(settings.max_message_bytes, 8192);
        assert!(settings.emit_bom);
    }

    #[test]
    fn a_new_installation_opens_nothing_outward() {
        // Closed by default, and the default has a test so it stays that way.
        assert_eq!(minimal().build().unwrap().collector.scheme, Scheme::None);
    }

    #[test]
    fn a_missing_key_with_no_default_is_reported() {
        let failure = ConfigBuilder::new().build().unwrap_err();
        assert_eq!(failure.status, Status::MissingConfigKey);
        assert!(failure.detail.contains("spool_dir"));
    }

    #[test]
    fn a_misspelled_key_is_refused_with_a_suggestion() {
        let mut builder = ConfigBuilder::new();
        let failure = builder.set("spool_max_byte", "1000").unwrap_err();
        assert_eq!(failure.status, Status::UnknownConfigKey);
        assert!(
            failure.detail.contains("spool_max_bytes"),
            "{}",
            failure.detail
        );
    }

    #[test]
    fn a_value_of_the_wrong_shape_is_refused_with_the_key_named() {
        let mut builder = minimal();
        builder.set("spool_max_bytes", "lots").unwrap();
        let failure = builder.build().unwrap_err();
        assert_eq!(failure.status, Status::InvalidConfigValue);
        assert!(failure.detail.contains("spool_max_bytes"));

        let mut builder = minimal();
        builder.set("spool_policy", "delete_everything").unwrap();
        let failure = builder.build().unwrap_err();
        assert_eq!(failure.status, Status::InvalidConfigValue);
        assert!(failure.detail.contains("drop_oldest, reject"));

        let mut builder = minimal();
        builder.set("msg_bom", "yes").unwrap();
        assert_eq!(
            builder.build().unwrap_err().status,
            Status::InvalidConfigValue
        );
    }

    #[test]
    fn an_unusable_header_field_stops_the_sink_at_open() {
        let mut builder = minimal();
        builder.set("app_name", "tele pos").unwrap();
        let failure = builder.build().unwrap_err();
        assert_eq!(failure.status, Status::InvalidHeaderField);
    }

    #[test]
    fn an_unknown_facility_is_refused_by_name() {
        let mut builder = minimal();
        builder.set("facility", "local9").unwrap();
        assert_eq!(builder.build().unwrap_err().status, Status::UnknownFacility);
    }

    #[test]
    fn a_message_limit_too_small_to_be_meant_is_refused() {
        let mut builder = minimal();
        builder.set("max_message_bytes", "64").unwrap();
        let failure = builder.build().unwrap_err();
        assert_eq!(failure.status, Status::InvalidConfigValue);
    }

    #[test]
    fn backoff_bounds_must_make_sense() {
        let mut builder = minimal();
        builder.set("retry_min_ms", "5000").unwrap();
        builder.set("retry_max_ms", "1000").unwrap();
        assert_eq!(
            builder.build().unwrap_err().status,
            Status::InvalidConfigValue
        );
    }

    #[test]
    fn every_key_has_an_entry_and_no_key_appears_twice() {
        let mut names: Vec<&str> = KEYS.iter().map(|(k, _)| *k).collect();
        names.sort_unstable();
        let before = names.len();
        names.dedup();
        assert_eq!(before, names.len(), "a configuration key is listed twice");
    }

    #[test]
    fn every_default_in_the_table_is_actually_accepted() {
        // A default that does not parse is a trap that only springs for the
        // caller who leaves the key alone.
        minimal()
            .build()
            .expect("the table's own defaults must build");
    }
}
