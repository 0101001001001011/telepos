//! The model manifest: what a till is allowed to believe about a model.
//!
//! # Why this format
//!
//! `Key: Value`, RFC 822 style, one field per line. Not JSON, and the reason is
//! not taste. Models reach a till as Debian packages through the same signed
//! apt repository that already delivers the software (`doc/models.md`), and
//! `Key: Value` is the format every tool in that chain already reads and
//! writes -- `dpkg-deb`, `apt-cache show`, `debian/control`. Following the
//! precedent the product already ships costs one small parser; inventing a
//! second serialisation costs a second thing to keep right.
//!
//! # What loading guarantees
//!
//! A model that loads has been checked in this order, and the order matters:
//!
//! 1. the manifest exists and every required key is present,
//! 2. the schema and the minimum ABI are ones this build implements,
//! 3. the retention is present, finite and non-zero (И93, И94),
//! 4. the weights file exists and is exactly the declared length,
//! 5. the weights hash to exactly the declared SHA-256,
//! 6. the version is the one this terminal is pinned to, if it is pinned.
//!
//! Weights that do not match are refused rather than loaded. This is not
//! caution for its own sake: weights read in the wrong layout do not fail
//! loudly, they produce a confident wrong answer, and a confident wrong answer
//! from a loss-prevention model is an accusation against a customer.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use crate::sha256;
use crate::status::{Failure, Outcome, Status};

/// The manifest schema versions this build understands.
pub const SUPPORTED_SCHEMA: u32 = 1;

/// The C ABI version this build presents. A manifest may demand a minimum.
pub const ABI_VERSION: u32 = 1;

/// An upper bound on retention that a manifest cannot talk its way past.
/// И94 says the default must be finite; this makes "finite" a number rather
/// than an intention. Ninety days.
pub const RETENTION_CEILING_SECONDS: u32 = 90 * 24 * 60 * 60;

/// The tasks this package is built for. Deliberately two.
///
/// Section 10 of the architecture names six events worth correlating with the
/// till. Four of them are till events with a video link attached and need no
/// model at all; the fifth, the self-checkout weight check, is a number from a
/// scale. Only these two need inference, and they are not equally mature --
/// see the `maturity` note on each.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Task {
    /// Visitors per hour, for conversion against receipts per hour.
    ///
    /// Engineering, not research: person detection on a fixed camera is a
    /// settled problem, and the product needs an hourly trend, not a legally
    /// meaningful count. This is also the *fallback* path -- a camera or NVR
    /// speaking ONVIF Profile M already counts, and then no model runs here at
    /// all.
    VisitorCount,

    /// A hint that something moved from the customer's side to the bagging
    /// side while the till recorded no scan.
    ///
    /// **Open research, not a capability with an accuracy to promise.** It is
    /// a filter that narrows what a person reviews, not a detector of theft,
    /// and nothing in this package should be described as the latter.
    UnscannedItemHint,
}

impl Task {
    pub const fn c_name(self) -> &'static [u8] {
        match self {
            Task::VisitorCount => b"visitorCount\0",
            Task::UnscannedItemHint => b"unscannedItemHint\0",
        }
    }

    pub fn name(self) -> &'static str {
        let b = self.c_name();
        std::str::from_utf8(&b[..b.len() - 1]).expect("task names are ASCII")
    }

    pub fn parse(s: &str) -> Option<Task> {
        match s {
            "visitorCount" => Some(Task::VisitorCount),
            "unscannedItemHint" => Some(Task::UnscannedItemHint),
            _ => None,
        }
    }

    pub const ALL: &'static [Task] = &[Task::VisitorCount, Task::UnscannedItemHint];
}

/// A pixel format, named rather than numbered across the boundary.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PixelFormat {
    Rgb8,
    Bgr8,
    Rgba8,
    Gray8,
}

impl PixelFormat {
    pub const fn c_name(self) -> &'static [u8] {
        match self {
            PixelFormat::Rgb8 => b"rgb8\0",
            PixelFormat::Bgr8 => b"bgr8\0",
            PixelFormat::Rgba8 => b"rgba8\0",
            PixelFormat::Gray8 => b"gray8\0",
        }
    }

    pub fn name(self) -> &'static str {
        let b = self.c_name();
        std::str::from_utf8(&b[..b.len() - 1]).expect("format names are ASCII")
    }

    pub fn parse(s: &str) -> Option<PixelFormat> {
        match s {
            "rgb8" => Some(PixelFormat::Rgb8),
            "bgr8" => Some(PixelFormat::Bgr8),
            "rgba8" => Some(PixelFormat::Rgba8),
            "gray8" => Some(PixelFormat::Gray8),
            _ => None,
        }
    }

    pub const fn bytes_per_pixel(self) -> usize {
        match self {
            PixelFormat::Rgb8 | PixelFormat::Bgr8 => 3,
            PixelFormat::Rgba8 => 4,
            PixelFormat::Gray8 => 1,
        }
    }

    pub const ALL: &'static [PixelFormat] = &[
        PixelFormat::Rgb8,
        PixelFormat::Bgr8,
        PixelFormat::Rgba8,
        PixelFormat::Gray8,
    ];
}

/// A manifest that has been read and checked, but whose weights have not been
/// hashed yet. Splitting the two lets a caller reject an incompatible manifest
/// without reading three hundred megabytes off a slow disk first.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Manifest {
    pub model: String,
    pub version: String,
    pub task: Task,
    pub weights_path: PathBuf,
    pub weights_sha256: String,
    pub weights_bytes: u64,
    pub input_width: u32,
    pub input_height: u32,
    pub input_format: PixelFormat,
    pub schema: u32,
    pub min_abi: u32,
    pub retention_seconds: u32,
    pub classes: Vec<String>,
    pub producer: String,
}

fn parse_fields(text: &str) -> Outcome<BTreeMap<String, String>> {
    let mut fields = BTreeMap::new();
    for (n, raw) in text.lines().enumerate() {
        let line = raw.trim_end_matches('\r');
        if line.trim().is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once(':') else {
            return Err(Failure::new(
                Status::ManifestMalformed,
                format!("line {} is not `Key: Value`: {:?}", n + 1, line),
            ));
        };
        let key = key.trim();
        if key.is_empty() {
            return Err(Failure::new(
                Status::ManifestMalformed,
                format!("line {} has an empty key", n + 1),
            ));
        }
        if fields
            .insert(key.to_string(), value.trim().to_string())
            .is_some()
        {
            return Err(Failure::new(
                Status::ManifestMalformed,
                format!(
                    "key {:?} appears twice; which one wins is not something to guess",
                    key
                ),
            ));
        }
    }
    Ok(fields)
}

fn required<'a>(fields: &'a BTreeMap<String, String>, key: &str) -> Outcome<&'a str> {
    match fields.get(key) {
        Some(v) if !v.is_empty() => Ok(v.as_str()),
        Some(_) => Err(Failure::new(
            Status::ManifestMalformed,
            format!("key {:?} is present but empty", key),
        )),
        None => Err(Failure::new(
            Status::ManifestMalformed,
            format!("required key {:?} is missing", key),
        )),
    }
}

fn required_u32(fields: &BTreeMap<String, String>, key: &str) -> Outcome<u32> {
    let raw = required(fields, key)?;
    raw.parse::<u32>().map_err(|_| {
        Failure::new(
            Status::ManifestMalformed,
            format!("key {:?} is not a whole number: {:?}", key, raw),
        )
    })
}

fn required_u64(fields: &BTreeMap<String, String>, key: &str) -> Outcome<u64> {
    let raw = required(fields, key)?;
    raw.parse::<u64>().map_err(|_| {
        Failure::new(
            Status::ManifestMalformed,
            format!("key {:?} is not a whole number: {:?}", key, raw),
        )
    })
}

impl Manifest {
    /// Reads and checks a manifest. Does not touch the weights.
    pub fn read(manifest_path: &Path) -> Outcome<Manifest> {
        if !manifest_path.exists() {
            return Err(Failure::new(
                Status::ModelNotFound,
                format!("no manifest at {}", manifest_path.display()),
            ));
        }
        let text = std::fs::read_to_string(manifest_path).map_err(|e| {
            Failure::new(
                Status::ManifestUnreadable,
                format!("{}: {}", manifest_path.display(), e),
            )
        })?;
        let mut manifest = Manifest::parse(&text)?;

        // Weights are named relative to the manifest, so a model directory can
        // be moved or staged without rewriting it.
        if manifest.weights_path.is_relative() {
            if let Some(dir) = manifest_path.parent() {
                manifest.weights_path = dir.join(&manifest.weights_path);
            }
        }
        Ok(manifest)
    }

    pub fn parse(text: &str) -> Outcome<Manifest> {
        let fields = parse_fields(text)?;

        let schema = required_u32(&fields, "Schema")?;
        if schema == 0 || schema > SUPPORTED_SCHEMA {
            return Err(Failure::new(
                Status::ModelIncompatible,
                format!(
                    "manifest schema {} is not one this build implements (supported: 1..={})",
                    schema, SUPPORTED_SCHEMA
                ),
            ));
        }

        let min_abi = required_u32(&fields, "Min-Rk-Infer-Abi")?;
        if min_abi > ABI_VERSION {
            return Err(Failure::new(
                Status::ModelIncompatible,
                format!(
                    "model needs rk_infer ABI {} or newer; this build is ABI {}",
                    min_abi, ABI_VERSION
                ),
            ));
        }

        let task_name = required(&fields, "Task")?;
        let task = Task::parse(task_name).ok_or_else(|| {
            Failure::new(
                Status::ManifestMalformed,
                format!(
                    "task {:?} is not one of: {}",
                    task_name,
                    Task::ALL
                        .iter()
                        .map(|t| t.name())
                        .collect::<Vec<_>>()
                        .join(", ")
                ),
            )
        })?;

        let format_name = required(&fields, "Input-Format")?;
        let input_format = PixelFormat::parse(format_name).ok_or_else(|| {
            Failure::new(
                Status::ManifestMalformed,
                format!(
                    "input format {:?} is not one of: {}",
                    format_name,
                    PixelFormat::ALL
                        .iter()
                        .map(|f| f.name())
                        .collect::<Vec<_>>()
                        .join(", ")
                ),
            )
        })?;

        let sha = required(&fields, "Weights-Sha256")?.to_ascii_lowercase();
        if sha.len() != 64 || !sha.bytes().all(|b| b.is_ascii_hexdigit()) {
            return Err(Failure::new(
                Status::ManifestMalformed,
                format!("Weights-Sha256 must be 64 hex digits, got {:?}", sha),
            ));
        }

        let input_width = required_u32(&fields, "Input-Width")?;
        let input_height = required_u32(&fields, "Input-Height")?;
        if input_width == 0 || input_height == 0 {
            return Err(Failure::new(
                Status::ManifestMalformed,
                "Input-Width and Input-Height must both be non-zero".to_string(),
            ));
        }

        // И93 and И94, enforced rather than documented. A missing retention is
        // not "keep forever by default"; it is a manifest that does not load.
        let retention_seconds = required_u32(&fields, "Retention-Seconds")?;
        if retention_seconds == 0 {
            return Err(Failure::new(
                Status::ManifestMalformed,
                "Retention-Seconds must be greater than zero: a result with no \
                 retention is a result kept forever"
                    .to_string(),
            ));
        }
        if retention_seconds > RETENTION_CEILING_SECONDS {
            return Err(Failure::new(
                Status::ManifestMalformed,
                format!(
                    "Retention-Seconds {} exceeds the ceiling of {} ({} days); a \
                     manifest does not get to widen this",
                    retention_seconds,
                    RETENTION_CEILING_SECONDS,
                    RETENTION_CEILING_SECONDS / 86_400
                ),
            ));
        }

        let classes: Vec<String> = required(&fields, "Classes")?
            .split(',')
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty())
            .collect();
        if classes.is_empty() {
            return Err(Failure::new(
                Status::ManifestMalformed,
                "Classes must name at least one class".to_string(),
            ));
        }
        if classes.iter().any(|c| c.contains('\0')) {
            return Err(Failure::new(
                Status::ManifestMalformed,
                "a class name may not contain a NUL: it crosses the ABI as a C string".to_string(),
            ));
        }

        Ok(Manifest {
            model: required(&fields, "Model")?.to_string(),
            version: required(&fields, "Version")?.to_string(),
            task,
            weights_path: PathBuf::from(required(&fields, "Weights")?),
            weights_sha256: sha,
            weights_bytes: required_u64(&fields, "Weights-Bytes")?,
            input_width,
            input_height,
            input_format,
            schema,
            min_abi,
            retention_seconds,
            classes,
            producer: required(&fields, "Producer")?.to_string(),
        })
    }

    /// The exact byte length a frame for this model must have.
    pub fn frame_bytes(&self) -> usize {
        self.input_width as usize * self.input_height as usize * self.input_format.bytes_per_pixel()
    }

    /// Refuses a manifest whose version is not the pinned one.
    ///
    /// A terminal pins a version (И149-in-spirit; see `doc/models.md`). The
    /// repository is allowed to move on; the till is not, until someone says
    /// so. An unattended model change on a till can mean false alarms in front
    /// of customers, which is not the same class of accident as a UI bug.
    pub fn check_pin(&self, pinned: Option<&str>) -> Outcome<()> {
        match pinned {
            None => Ok(()),
            Some(want) if want == self.version => Ok(()),
            Some(want) => Err(Failure::new(
                Status::ModelPinMismatch,
                format!(
                    "terminal is pinned to {} {} but the manifest on disk is {}",
                    self.model, want, self.version
                ),
            )),
        }
    }

    /// Hashes the weights and compares. The length is checked first because it
    /// is free and rules out the common case -- a truncated download -- before
    /// spending the I/O.
    pub fn verify_weights(&self) -> Outcome<()> {
        if !self.weights_path.exists() {
            return Err(Failure::new(
                Status::ModelNotFound,
                format!(
                    "manifest names weights at {} which is not there",
                    self.weights_path.display()
                ),
            ));
        }

        let (digest, len) = sha256::hex_of_file(&self.weights_path).map_err(|e| {
            Failure::new(
                Status::ManifestUnreadable,
                format!("{}: {}", self.weights_path.display(), e),
            )
        })?;

        if len != self.weights_bytes {
            return Err(Failure::new(
                Status::ModelChecksumMismatch,
                format!(
                    "{} is {} bytes, manifest declares {}",
                    self.weights_path.display(),
                    len,
                    self.weights_bytes
                ),
            ));
        }

        if digest != self.weights_sha256 {
            return Err(Failure::new(
                Status::ModelChecksumMismatch,
                format!(
                    "{} hashes to {}, manifest declares {}",
                    self.weights_path.display(),
                    digest,
                    self.weights_sha256
                ),
            ));
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn good_manifest(sha: &str, bytes: u64) -> String {
        format!(
            "# Delivered by telepos-model-visitor-counter\n\
             Model: visitor-counter\n\
             Version: 1.4.0\n\
             Task: visitorCount\n\
             Weights: visitor-counter.onnx\n\
             Weights-Sha256: {sha}\n\
             Weights-Bytes: {bytes}\n\
             Input-Width: 640\n\
             Input-Height: 384\n\
             Input-Format: rgb8\n\
             Schema: 1\n\
             Min-Rk-Infer-Abi: 1\n\
             Retention-Seconds: 604800\n\
             Classes: person\n\
             Producer: telepos-model-visitor-counter 1.4.0\n"
        )
    }

    const ZERO_SHA: &str = "0000000000000000000000000000000000000000000000000000000000000000";

    #[test]
    fn a_complete_manifest_parses() {
        let m = Manifest::parse(&good_manifest(ZERO_SHA, 42)).unwrap();
        assert_eq!(m.model, "visitor-counter");
        assert_eq!(m.version, "1.4.0");
        assert_eq!(m.task, Task::VisitorCount);
        assert_eq!(m.input_format, PixelFormat::Rgb8);
        assert_eq!(m.retention_seconds, 604_800);
        assert_eq!(m.classes, vec!["person".to_string()]);
        assert_eq!(m.frame_bytes(), 640 * 384 * 3);
    }

    #[test]
    fn every_required_key_is_actually_required() {
        // Drop each line in turn and demand a refusal naming that key. Without
        // this, "required" is a word in a doc comment.
        let full = good_manifest(ZERO_SHA, 42);
        let keys = [
            "Model",
            "Version",
            "Task",
            "Weights",
            "Weights-Sha256",
            "Weights-Bytes",
            "Input-Width",
            "Input-Height",
            "Input-Format",
            "Schema",
            "Min-Rk-Infer-Abi",
            "Retention-Seconds",
            "Classes",
            "Producer",
        ];
        for key in keys {
            let without: String = full
                .lines()
                .filter(|l| !l.starts_with(&format!("{}:", key)))
                .collect::<Vec<_>>()
                .join("\n");
            let err = Manifest::parse(&without)
                .unwrap_err_or_panic(&format!("dropping {} must fail", key));
            assert!(
                err.detail.contains(key),
                "dropping {} produced {:?}, which does not name the key",
                key,
                err
            );
        }
    }

    #[test]
    fn retention_may_be_neither_absent_nor_zero_nor_unbounded() {
        let base = good_manifest(ZERO_SHA, 42);

        let zero = base.replace("Retention-Seconds: 604800", "Retention-Seconds: 0");
        let e = Manifest::parse(&zero).unwrap_err();
        assert_eq!(e.status, Status::ManifestMalformed);
        assert!(e.detail.contains("kept forever"), "{:?}", e);

        let huge = base.replace("Retention-Seconds: 604800", "Retention-Seconds: 4294967295");
        let e = Manifest::parse(&huge).unwrap_err();
        assert_eq!(e.status, Status::ManifestMalformed);
        assert!(e.detail.contains("ceiling"), "{:?}", e);

        // Exactly at the ceiling is allowed; one past it is not.
        let at = base.replace(
            "Retention-Seconds: 604800",
            &format!("Retention-Seconds: {}", RETENTION_CEILING_SECONDS),
        );
        assert!(Manifest::parse(&at).is_ok());
        let over = base.replace(
            "Retention-Seconds: 604800",
            &format!("Retention-Seconds: {}", RETENTION_CEILING_SECONDS + 1),
        );
        assert!(Manifest::parse(&over).is_err());
    }

    #[test]
    fn an_unknown_task_is_refused_and_the_known_ones_are_listed() {
        let text = good_manifest(ZERO_SHA, 42).replace("Task: visitorCount", "Task: faceMatch");
        let e = Manifest::parse(&text).unwrap_err();
        assert_eq!(e.status, Status::ManifestMalformed);
        assert!(e.detail.contains("visitorCount"), "{:?}", e);
        assert!(e.detail.contains("unscannedItemHint"), "{:?}", e);
    }

    #[test]
    fn a_newer_schema_or_abi_is_incompatible_not_malformed() {
        let newer_schema = good_manifest(ZERO_SHA, 42).replace("Schema: 1", "Schema: 2");
        assert_eq!(
            Manifest::parse(&newer_schema).unwrap_err().status,
            Status::ModelIncompatible
        );

        let newer_abi =
            good_manifest(ZERO_SHA, 42).replace("Min-Rk-Infer-Abi: 1", "Min-Rk-Infer-Abi: 2");
        assert_eq!(
            Manifest::parse(&newer_abi).unwrap_err().status,
            Status::ModelIncompatible
        );
    }

    #[test]
    fn a_repeated_key_is_refused_rather_than_resolved() {
        let text = format!("{}Version: 9.9.9\n", good_manifest(ZERO_SHA, 42));
        let e = Manifest::parse(&text).unwrap_err();
        assert_eq!(e.status, Status::ManifestMalformed);
        assert!(e.detail.contains("twice"), "{:?}", e);
    }

    #[test]
    fn a_short_or_non_hex_checksum_is_refused() {
        for bad in ["deadbeef", &"z".repeat(64), &"a".repeat(63)] {
            let text = good_manifest(ZERO_SHA, 42).replace(
                &format!("Weights-Sha256: {}", ZERO_SHA),
                &format!("Weights-Sha256: {}", bad),
            );
            assert_eq!(
                Manifest::parse(&text).unwrap_err().status,
                Status::ManifestMalformed,
                "{:?} should not pass as a checksum",
                bad
            );
        }
    }

    #[test]
    fn a_pin_that_does_not_match_refuses_the_load() {
        let m = Manifest::parse(&good_manifest(ZERO_SHA, 42)).unwrap();
        assert!(m.check_pin(None).is_ok());
        assert!(m.check_pin(Some("1.4.0")).is_ok());

        let e = m.check_pin(Some("1.3.0")).unwrap_err();
        assert_eq!(e.status, Status::ModelPinMismatch);
        assert!(
            e.detail.contains("1.3.0") && e.detail.contains("1.4.0"),
            "{:?}",
            e
        );
    }

    #[test]
    fn weights_are_verified_against_their_bytes_not_their_name() {
        let dir = std::env::temp_dir().join("rk_infer_manifest_test");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();

        let weights = dir.join("visitor-counter.onnx");
        let payload = b"not really a model, but exactly these bytes".to_vec();
        std::fs::write(&weights, &payload).unwrap();
        let real_sha = sha256::hex_of(&payload);

        let manifest_path = dir.join("model.manifest");

        // Right hash, right length: loads.
        std::fs::write(
            &manifest_path,
            good_manifest(&real_sha, payload.len() as u64),
        )
        .unwrap();
        let m = Manifest::read(&manifest_path).unwrap();
        assert!(m.verify_weights().is_ok());

        // Right hash, wrong declared length: caught by the cheap check first.
        std::fs::write(&manifest_path, good_manifest(&real_sha, 999)).unwrap();
        let m = Manifest::read(&manifest_path).unwrap();
        let e = m.verify_weights().unwrap_err();
        assert_eq!(e.status, Status::ModelChecksumMismatch);
        assert!(e.detail.contains("999"), "{:?}", e);

        // Right length, wrong hash: caught by the hash.
        std::fs::write(
            &manifest_path,
            good_manifest(ZERO_SHA, payload.len() as u64),
        )
        .unwrap();
        let m = Manifest::read(&manifest_path).unwrap();
        let e = m.verify_weights().unwrap_err();
        assert_eq!(e.status, Status::ModelChecksumMismatch);
        assert!(e.detail.contains(&real_sha), "{:?}", e);

        // One flipped byte, same length: this is the case the length check
        // cannot see and the whole reason the hash is here.
        let mut tampered = payload.clone();
        tampered[0] ^= 0x01;
        std::fs::write(&weights, &tampered).unwrap();
        std::fs::write(
            &manifest_path,
            good_manifest(&real_sha, payload.len() as u64),
        )
        .unwrap();
        let m = Manifest::read(&manifest_path).unwrap();
        assert_eq!(
            m.verify_weights().unwrap_err().status,
            Status::ModelChecksumMismatch,
            "a single flipped byte must not load"
        );

        // Missing weights are ModelNotFound, not a checksum failure: the
        // difference tells an operator whether apt finished.
        std::fs::remove_file(&weights).unwrap();
        let m = Manifest::read(&manifest_path).unwrap();
        assert_eq!(
            m.verify_weights().unwrap_err().status,
            Status::ModelNotFound
        );

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_missing_manifest_is_model_not_found() {
        let path = std::env::temp_dir()
            .join("rk_infer_nope")
            .join("model.manifest");
        assert_eq!(
            Manifest::read(&path).unwrap_err().status,
            Status::ModelNotFound
        );
    }

    #[test]
    fn task_and_format_names_round_trip() {
        for t in Task::ALL {
            assert_eq!(Task::parse(t.name()), Some(*t));
        }
        for f in PixelFormat::ALL {
            assert_eq!(PixelFormat::parse(f.name()), Some(*f));
        }
        assert_eq!(
            Task::parse("VisitorCount"),
            None,
            "names are case sensitive"
        );
        assert_eq!(PixelFormat::parse("RGB8"), None, "names are case sensitive");
    }

    /// Small helper so a failing "must fail" case says which key it was about.
    trait UnwrapErrOrPanic<T> {
        fn unwrap_err_or_panic(self, msg: &str) -> Failure;
    }
    impl<T: std::fmt::Debug> UnwrapErrOrPanic<T> for Outcome<T> {
        fn unwrap_err_or_panic(self, msg: &str) -> Failure {
            match self {
                Ok(v) => panic!("{}, but it parsed to {:?}", msg, v),
                Err(e) => e,
            }
        }
    }
}
