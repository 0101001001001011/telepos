//! `rk_infer` -- the native side.
//!
//! On-device inference for a product moving towards self-checkout, robotised
//! points, and video correlated with receipts. Inference engines are written
//! in C++; we embed one, we do not write one.
//!
//! The C ABI is declared in `include/rk_infer.h` and implemented here. Read
//! that header first: it states the three rules -- failure as a value, enums
//! by name, one owner per allocation -- next to the declarations they govern.
//!
//! # Scope
//!
//! Section 10 of the architecture names six events worth correlating with the
//! till. Four are till events with a video link attached and need no model.
//! The fifth, the self-checkout weight check, is a number from a scale. That
//! leaves two, and they are not equally mature:
//!
//! * a **fallback visitor counter** -- engineering, and only needed at all
//!   where the camera or NVR does not already count via ONVIF Profile M;
//! * **"item placed but not scanned"** -- open research, a filter that narrows
//!   what a person reviews, not a detector with an accuracy to promise.
//!
//! Barcodes from a camera are already solved elsewhere and are not touched
//! here.

#![deny(unsafe_op_in_unsafe_fn)]

pub mod dylib;
pub mod engine;
pub mod frame;
pub mod manifest;
pub mod sha256;
pub mod status;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::AssertUnwindSafe;
use std::path::{Path, PathBuf};
use std::ptr;

use engine::{Engine, Provider, Session};
use frame::Frame;
use manifest::{Manifest, PixelFormat, Task};
use status::{Failure, Outcome, Status};

/// See `RK_INFER_ABI_VERSION` in the header. Changing anything below changes
/// this, and changing this is a major version of the package.
pub const ABI_VERSION: u32 = 1;

// ---------------------------------------------------------------------------
// Boundary helpers
// ---------------------------------------------------------------------------

/// Runs `body` and converts everything -- a returned failure, or a panic -- to
/// a status name and an owned detail string (И144).
///
/// Nothing unwinds past this point. A panic in this library is a bug in this
/// library, and it becomes `NativeFault` with the payload as the detail rather
/// than an abort inside a Dart isolate holding a sale open.
fn boundary<F>(detail_out: *mut *mut c_char, body: F) -> *const c_char
where
    F: FnOnce() -> Outcome<()>,
{
    if !detail_out.is_null() {
        unsafe { *detail_out = ptr::null_mut() };
    }

    let caught = std::panic::catch_unwind(AssertUnwindSafe(body));

    let failure = match caught {
        Ok(Ok(())) => return ptr::null(),
        Ok(Err(f)) => f,
        Err(payload) => {
            let what = if let Some(s) = payload.downcast_ref::<&str>() {
                (*s).to_string()
            } else if let Some(s) = payload.downcast_ref::<String>() {
                s.clone()
            } else {
                "panic with a payload of an unknown type".to_string()
            };
            Failure::new(
                Status::NativeFault,
                format!("panic caught at the ABI boundary: {}", what),
            )
        }
    };

    if !detail_out.is_null() {
        // A detail that cannot become a C string is still better reported than
        // dropped, so the NUL is replaced rather than the message lost.
        let cleaned = failure.detail.replace('\0', "\\0");
        if let Ok(c) = CString::new(cleaned) {
            unsafe { *detail_out = c.into_raw() };
        }
    }
    failure.status.as_ptr()
}

/// Reads a required C string argument.
fn required_str<'a>(p: *const c_char, what: &str) -> Outcome<&'a str> {
    if p.is_null() {
        return Err(Failure::new(
            Status::InvalidArgument,
            format!("{} must not be NULL", what),
        ));
    }
    unsafe { CStr::from_ptr(p) }.to_str().map_err(|_| {
        Failure::new(
            Status::InvalidArgument,
            format!("{} is not valid UTF-8", what),
        )
    })
}

/// Reads an optional C string argument.
fn optional_str<'a>(p: *const c_char, what: &str) -> Outcome<Option<&'a str>> {
    if p.is_null() {
        Ok(None)
    } else {
        required_str(p, what).map(Some)
    }
}

fn out_ptr_ok<T>(p: *mut *mut T, what: &str) -> Outcome<()> {
    if p.is_null() {
        Err(Failure::new(
            Status::InvalidArgument,
            format!("{} must not be NULL", what),
        ))
    } else {
        Ok(())
    }
}

/// Joins names into one comma-separated static-lifetime string, built once.
fn joined(names: impl Iterator<Item = &'static str>) -> &'static CStr {
    use std::sync::OnceLock;
    static CACHE: OnceLock<std::sync::Mutex<Vec<&'static CStr>>> = OnceLock::new();
    let joined = names.collect::<Vec<_>>().join(",");
    let c = CString::new(joined).expect("names are ASCII without NUL");
    let leaked: &'static CStr = Box::leak(c.into_boxed_c_str());
    // Kept so the leak is bounded and visible rather than unbounded: each
    // distinct list is built at most once per process.
    CACHE
        .get_or_init(|| std::sync::Mutex::new(Vec::new()))
        .lock()
        .expect("names cache")
        .push(leaked);
    leaked
}

// ---------------------------------------------------------------------------
// Version and names
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn rk_infer_abi_version() -> u32 {
    ABI_VERSION
}

/// Frees a detail string. Owner: the caller. See the header.
///
/// # Safety
/// `s` must be a pointer this library handed out through a `char**`
/// out-parameter, and must be freed at most once.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(unsafe { CString::from_raw(s) });
    }
}

#[no_mangle]
pub extern "C" fn rk_infer_status_names() -> *const c_char {
    use std::sync::OnceLock;
    static NAMES: OnceLock<&'static CStr> = OnceLock::new();
    NAMES
        .get_or_init(|| joined(Status::ALL.iter().map(|s| s.name())))
        .as_ptr()
}

#[no_mangle]
pub extern "C" fn rk_infer_pixel_format_names() -> *const c_char {
    use std::sync::OnceLock;
    static NAMES: OnceLock<&'static CStr> = OnceLock::new();
    NAMES
        .get_or_init(|| joined(PixelFormat::ALL.iter().map(|f| f.name())))
        .as_ptr()
}

#[no_mangle]
pub extern "C" fn rk_infer_task_names() -> *const c_char {
    use std::sync::OnceLock;
    static NAMES: OnceLock<&'static CStr> = OnceLock::new();
    NAMES
        .get_or_init(|| joined(Task::ALL.iter().map(|t| t.name())))
        .as_ptr()
}

// ---------------------------------------------------------------------------
// Frames
// ---------------------------------------------------------------------------

/// # Safety
/// `out`, `write_out` and `bytes_out` must be valid writable pointers.
/// `pixel_format_name` must be a NUL-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_frame_new(
    width: u32,
    height: u32,
    pixel_format_name: *const c_char,
    out: *mut *mut Frame,
    write_out: *mut *mut u8,
    bytes_out: *mut usize,
    detail_out: *mut *mut c_char,
) -> *const c_char {
    boundary(detail_out, || {
        out_ptr_ok(out, "out")?;
        if write_out.is_null() || bytes_out.is_null() {
            return Err(Failure::new(
                Status::InvalidArgument,
                "write_out and bytes_out must not be NULL".to_string(),
            ));
        }

        let name = required_str(pixel_format_name, "pixel_format_name")?;
        let format = PixelFormat::parse(name).ok_or_else(|| {
            Failure::new(
                Status::UnsupportedPixelFormat,
                format!(
                    "{:?} is not one of: {}",
                    name,
                    PixelFormat::ALL
                        .iter()
                        .map(|f| f.name())
                        .collect::<Vec<_>>()
                        .join(", ")
                ),
            )
        })?;

        let mut frame = Box::new(Frame::new(width, height, format)?);
        let bytes = frame.len();
        let write = frame.write_ptr();

        unsafe {
            *bytes_out = bytes;
            *write_out = write;
            *out = Box::into_raw(frame);
        }
        Ok(())
    })
}

/// # Safety
/// `frame` must be a live handle from `rk_infer_frame_new`, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_frame_bytes(frame: *const Frame) -> usize {
    if frame.is_null() {
        return 0;
    }
    unsafe { &*frame }.len()
}

/// # Safety
/// `frame` must be a handle from `rk_infer_frame_new` that has not been freed,
/// or NULL. After this returns NULL (success) the handle is dangling.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_frame_free(frame: *mut Frame) -> *const c_char {
    if frame.is_null() {
        return ptr::null();
    }
    let owned = unsafe { Box::from_raw(frame) };
    match owned.into_freed() {
        Ok(()) => ptr::null(),
        Err((returned, failure)) => {
            // Refused: hand the allocation back to its box so the handle the
            // caller still holds stays valid. Freeing here would be exactly
            // the use-after-free the refusal exists to prevent.
            let _ = Box::into_raw(Box::new(returned));
            failure.status.as_ptr()
        }
    }
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

/// # Safety
/// `out` must be a valid writable pointer. `library_path` is NUL-terminated or
/// NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_engine_open(
    library_path: *const c_char,
    out: *mut *mut Engine,
    detail_out: *mut *mut c_char,
) -> *const c_char {
    boundary(detail_out, || {
        out_ptr_ok(out, "out")?;
        let explicit = optional_str(library_path, "library_path")?.map(PathBuf::from);
        let engine = Engine::open(explicit.as_deref().map(Path::new))?;
        unsafe { *out = Box::into_raw(Box::new(engine)) };
        Ok(())
    })
}

/// # Safety
/// `engine` must be a live handle from `rk_infer_engine_open`, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_engine_close(engine: *mut Engine) -> *const c_char {
    if engine.is_null() {
        return ptr::null();
    }
    let owned = unsafe { Box::from_raw(engine) };
    match owned.check_closable() {
        Ok(()) => {
            drop(owned);
            ptr::null()
        }
        Err(failure) => {
            let _ = Box::into_raw(owned);
            failure.status.as_ptr()
        }
    }
}

/// # Safety
/// `engine` must be a live handle, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_engine_runtime_version(engine: *const Engine) -> *const c_char {
    if engine.is_null() {
        return ptr::null();
    }
    match unsafe { &*engine }.runtime_version() {
        Some(v) => v.as_ptr(),
        None => ptr::null(),
    }
}

/// # Safety
/// `engine` must be a live handle, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_engine_provider(engine: *const Engine) -> *const c_char {
    if engine.is_null() {
        return Provider::Cpu.c_name().as_ptr() as *const c_char;
    }
    unsafe { &*engine }.provider().c_name().as_ptr() as *const c_char
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// A verified model and its session. The class-name table is owned here so the
/// `const char*` a detection carries stays valid exactly as long as the model.
pub struct Model {
    engine: *const Engine,
    manifest: Manifest,
    session: Option<Session>,
    name: CString,
    version: CString,
    task: &'static [u8],
    input_format: &'static [u8],
    class_names: Vec<CString>,
}

impl Drop for Model {
    fn drop(&mut self) {
        if !self.engine.is_null() {
            unsafe { &*self.engine }.model_closed();
        }
    }
}

/// # Safety
/// `engine` must be a live handle, `manifest_path` a NUL-terminated C string,
/// and `out` a valid writable pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_model_load(
    engine: *mut Engine,
    manifest_path: *const c_char,
    pinned_version: *const c_char,
    out: *mut *mut Model,
    detail_out: *mut *mut c_char,
) -> *const c_char {
    boundary(detail_out, || {
        out_ptr_ok(out, "out")?;
        if engine.is_null() {
            return Err(Failure::new(
                Status::InvalidArgument,
                "engine must not be NULL".to_string(),
            ));
        }
        let engine_ref = unsafe { &*engine };

        let path = required_str(manifest_path, "manifest_path")?;
        let pinned = optional_str(pinned_version, "pinned_version")?;

        // The order is the point, and it is documented in manifest.rs: cheap
        // and decisive checks before hundreds of megabytes of I/O.
        let manifest = Manifest::read(Path::new(path))?;
        manifest.check_pin(pinned)?;
        manifest.verify_weights()?;

        let session = engine_ref.open_session(&manifest)?;

        let class_names = manifest
            .classes
            .iter()
            .map(|c| CString::new(c.as_str()).expect("manifest rejects NUL in a class name"))
            .collect();

        engine_ref.model_opened();

        let model = Model {
            engine,
            name: CString::new(manifest.model.as_str()).map_err(|_| {
                Failure::new(
                    Status::ManifestMalformed,
                    "Model contains a NUL".to_string(),
                )
            })?,
            version: CString::new(manifest.version.as_str()).map_err(|_| {
                Failure::new(
                    Status::ManifestMalformed,
                    "Version contains a NUL".to_string(),
                )
            })?,
            task: manifest.task.c_name(),
            input_format: manifest.input_format.c_name(),
            class_names,
            session: Some(session),
            manifest,
        };

        unsafe { *out = Box::into_raw(Box::new(model)) };
        Ok(())
    })
}

/// # Safety
/// `model` must be a live handle from `rk_infer_model_load`, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_model_unload(model: *mut Model) {
    if !model.is_null() {
        drop(unsafe { Box::from_raw(model) });
    }
}

macro_rules! model_accessor {
    ($name:ident, $ret:ty, $body:expr) => {
        /// # Safety
        /// `model` must be a live handle, or NULL.
        #[no_mangle]
        pub unsafe extern "C" fn $name(model: *const Model) -> $ret {
            if model.is_null() {
                return Default::default();
            }
            let m: &Model = unsafe { &*model };
            #[allow(clippy::redundant_closure_call)]
            ($body)(m)
        }
    };
}

model_accessor!(rk_infer_model_input_width, u32, |m: &Model| m
    .manifest
    .input_width);
model_accessor!(rk_infer_model_input_height, u32, |m: &Model| m
    .manifest
    .input_height);
model_accessor!(rk_infer_model_retention_seconds, u32, |m: &Model| m
    .manifest
    .retention_seconds);

/// # Safety
/// `model` must be a live handle, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_model_name(model: *const Model) -> *const c_char {
    if model.is_null() {
        return ptr::null();
    }
    unsafe { &*model }.name.as_ptr()
}

/// # Safety
/// `model` must be a live handle, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_model_version(model: *const Model) -> *const c_char {
    if model.is_null() {
        return ptr::null();
    }
    unsafe { &*model }.version.as_ptr()
}

/// # Safety
/// `model` must be a live handle, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_model_task(model: *const Model) -> *const c_char {
    if model.is_null() {
        return ptr::null();
    }
    unsafe { &*model }.task.as_ptr() as *const c_char
}

/// # Safety
/// `model` must be a live handle, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_model_input_format(model: *const Model) -> *const c_char {
    if model.is_null() {
        return ptr::null();
    }
    unsafe { &*model }.input_format.as_ptr() as *const c_char
}

// ---------------------------------------------------------------------------
// Running
// ---------------------------------------------------------------------------

#[repr(C)]
pub struct RkInferDetection {
    pub class_name: *const c_char,
    pub confidence: f64,
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
}

pub struct Outcome_ {
    detections: Vec<RkInferDetection>,
    retain_until: u64,
}

/// # Safety
/// `model` and `frame` must be live handles; `out` a valid writable pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_run(
    model: *mut Model,
    frame: *mut Frame,
    out: *mut *mut Outcome_,
    detail_out: *mut *mut c_char,
) -> *const c_char {
    boundary(detail_out, || {
        out_ptr_ok(out, "out")?;
        if model.is_null() || frame.is_null() {
            return Err(Failure::new(
                Status::InvalidArgument,
                "model and frame must not be NULL".to_string(),
            ));
        }
        let model_ref = unsafe { &*model };
        let frame_ref = unsafe { &*frame };

        // The frame must be exactly the shape the manifest declares. A frame
        // of the wrong shape does not fail inside the engine, it produces a
        // confident wrong answer, which for this product means an accusation
        // against a customer.
        if frame_ref.width() != model_ref.manifest.input_width
            || frame_ref.height() != model_ref.manifest.input_height
            || frame_ref.format() != model_ref.manifest.input_format
        {
            return Err(Failure::new(
                Status::FrameShapeMismatch,
                format!(
                    "model {} {} expects {}x{} {}, frame is {}x{} {}",
                    model_ref.manifest.model,
                    model_ref.manifest.version,
                    model_ref.manifest.input_width,
                    model_ref.manifest.input_height,
                    model_ref.manifest.input_format.name(),
                    frame_ref.width(),
                    frame_ref.height(),
                    frame_ref.format().name(),
                ),
            ));
        }

        // Borrow for the duration. Released on drop, including on the panic
        // path, so a caught panic cannot leave a frame unfreeable.
        let borrow = frame_ref.borrow_for_run().ok_or_else(|| {
            Failure::new(
                Status::FrameInUse,
                "another run already holds this frame".to_string(),
            )
        })?;

        let session = model_ref.session.as_ref().ok_or_else(|| {
            Failure::new(
                Status::NotImplemented,
                "this model has no session".to_string(),
            )
        })?;

        let raw = session.run(borrow_frame(&borrow, frame_ref))?;

        let detections = raw
            .into_iter()
            .map(|d| {
                let class_name = model_ref
                    .class_names
                    .get(d.class_index)
                    .map(|c| c.as_ptr())
                    .unwrap_or(ptr::null());
                RkInferDetection {
                    class_name,
                    confidence: d.confidence,
                    x: d.x,
                    y: d.y,
                    w: d.w,
                    h: d.h,
                }
            })
            .collect();

        let retain_until = now_unix().saturating_add(model_ref.manifest.retention_seconds as u64);

        unsafe {
            *out = Box::into_raw(Box::new(Outcome_ {
                detections,
                retain_until,
            }))
        };
        Ok(())
    })
}

/// The borrow proves exclusivity; the session still wants the frame itself.
/// Kept as one named function so the lifetime relationship is stated once.
fn borrow_frame<'a>(_borrow: &'a frame::RunBorrow<'a>, frame: &'a Frame) -> &'a Frame {
    frame
}

fn now_unix() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// # Safety
/// `outcome` must be a live handle from `rk_infer_run`, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_outcome_len(outcome: *const Outcome_) -> usize {
    if outcome.is_null() {
        return 0;
    }
    unsafe { &*outcome }.detections.len()
}

/// # Safety
/// `outcome` must be a live handle, or NULL. The returned pointer is borrowed
/// and valid until `rk_infer_outcome_free`.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_outcome_at(
    outcome: *const Outcome_,
    index: usize,
) -> *const RkInferDetection {
    if outcome.is_null() {
        return ptr::null();
    }
    match unsafe { &*outcome }.detections.get(index) {
        Some(d) => d as *const RkInferDetection,
        None => ptr::null(),
    }
}

/// # Safety
/// `outcome` must be a live handle, or NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_outcome_retain_until(outcome: *const Outcome_) -> u64 {
    if outcome.is_null() {
        return 0;
    }
    unsafe { &*outcome }.retain_until
}

/// # Safety
/// `outcome` must be a handle from `rk_infer_run` that has not been freed, or
/// NULL.
#[no_mangle]
pub unsafe extern "C" fn rk_infer_outcome_free(outcome: *mut Outcome_) {
    if !outcome.is_null() {
        drop(unsafe { Box::from_raw(outcome) });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn name_of(p: *const c_char) -> String {
        assert!(!p.is_null(), "expected a status name, got NULL (success)");
        unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned()
    }

    fn take_detail(p: *mut c_char) -> String {
        if p.is_null() {
            return String::new();
        }
        let s = unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
        unsafe { rk_infer_string_free(p) };
        s
    }

    #[test]
    fn every_exported_function_is_declared_in_the_header() {
        // A hand-written header is a document, and a document drifts. Nothing
        // stopped it here: rk_infer_task_names was exported and absent from
        // the header, and it took a build on a machine nobody had to notice.
        // This reads the sources and the header and compares them, so the next
        // gap is a red test rather than a discovery.
        //
        // Walks src/ rather than naming files: a scan that names its inputs
        // stops covering a file added later, which is the same failure the
        // header had.
        let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
        let header = std::fs::read_to_string(root.join("include/rk_infer.h"))
            .expect("include/rk_infer.h must be readable");

        let mut sources = String::new();
        for entry in std::fs::read_dir(root.join("src")).expect("src/ must be readable") {
            let path = entry.expect("a readable directory entry").path();
            if path.extension().and_then(|e| e.to_str()) == Some("rs") {
                sources.push_str(&std::fs::read_to_string(&path).expect("a readable source"));
                sources.push_str("
");
            }
        }

        let mut exported = 0usize;
        let mut missing: Vec<String> = Vec::new();
        for line in sources.lines() {
            let trimmed = line.trim_start();
            // Both forms occur in this crate, and missing the second is how
            // the first version of this test found only 4 of 23.
            let rest = trimmed
                .strip_prefix("pub extern \"C\" fn ")
                .or_else(|| trimmed.strip_prefix("pub unsafe extern \"C\" fn "));
            let Some(rest) = rest else { continue };
            let Some(name) = rest.split('(').next().map(str::trim) else {
                continue;
            };
            if !name.starts_with("rk_infer_") {
                continue;
            }
            exported += 1;
            if !header.contains(name) {
                missing.push(name.to_string());
            }
        }

        // Without this the test passes on an empty or partial scan, which is
        // exactly the shape of a check that quietly stopped checking. The
        // figure is the count measured on 2026-08-03; it may only grow.
        assert!(
            exported >= 23,
            "scanned only {exported} exported functions, expected at least 23:              the scan is broken, not the header"
        );
        assert!(
            missing.is_empty(),
            "exported from src/ but not declared in include/rk_infer.h: {missing:?}"
        );
    }

    #[test]
    fn abi_version_matches_the_header() {
        assert_eq!(rk_infer_abi_version(), 1, "keep include/rk_infer.h in step");
    }

    #[test]
    fn the_name_lists_are_complete_and_comma_separated() {
        let statuses = unsafe { CStr::from_ptr(rk_infer_status_names()) }
            .to_str()
            .unwrap();
        for s in Status::ALL {
            assert!(
                statuses.split(',').any(|n| n == s.name()),
                "{} missing from rk_infer_status_names",
                s.name()
            );
        }

        let formats = unsafe { CStr::from_ptr(rk_infer_pixel_format_names()) }
            .to_str()
            .unwrap();
        assert_eq!(formats.split(',').count(), PixelFormat::ALL.len());

        let tasks = unsafe { CStr::from_ptr(rk_infer_task_names()) }
            .to_str()
            .unwrap();
        assert_eq!(tasks, "visitorCount,unscannedItemHint");
    }

    #[test]
    fn a_frame_round_trips_through_the_abi_and_frees() {
        let mut frame: *mut Frame = ptr::null_mut();
        let mut write: *mut u8 = ptr::null_mut();
        let mut bytes: usize = 0;
        let mut detail: *mut c_char = ptr::null_mut();

        let fmt = CString::new("rgb8").unwrap();
        let status = unsafe {
            rk_infer_frame_new(
                640,
                384,
                fmt.as_ptr(),
                &mut frame,
                &mut write,
                &mut bytes,
                &mut detail,
            )
        };
        assert!(status.is_null(), "{}", name_of(status));
        assert!(detail.is_null(), "success must not set a detail");
        assert!(!frame.is_null() && !write.is_null());
        assert_eq!(bytes, 640 * 384 * 3);
        assert_eq!(unsafe { rk_infer_frame_bytes(frame) }, bytes);

        // Fill it the way the Dart binding does.
        unsafe { std::ptr::write_bytes(write, 0xAB, bytes) };

        assert!(unsafe { rk_infer_frame_free(frame) }.is_null());
        // Freeing NULL is allowed and does nothing.
        assert!(unsafe { rk_infer_frame_free(ptr::null_mut()) }.is_null());
    }

    #[test]
    fn an_unknown_pixel_format_is_named_not_numbered() {
        let mut frame: *mut Frame = ptr::null_mut();
        let mut write: *mut u8 = ptr::null_mut();
        let mut bytes: usize = 0;
        let mut detail: *mut c_char = ptr::null_mut();

        let fmt = CString::new("yuv420p").unwrap();
        let status = unsafe {
            rk_infer_frame_new(
                8,
                8,
                fmt.as_ptr(),
                &mut frame,
                &mut write,
                &mut bytes,
                &mut detail,
            )
        };
        assert_eq!(name_of(status), "UnsupportedPixelFormat");
        let detail = take_detail(detail);
        assert!(
            detail.contains("rgb8"),
            "the detail must list what is accepted: {}",
            detail
        );
        assert!(frame.is_null(), "a failed call must not hand out a handle");
    }

    #[test]
    fn null_arguments_are_invalid_argument_rather_than_a_crash() {
        let mut detail: *mut c_char = ptr::null_mut();
        let mut frame: *mut Frame = ptr::null_mut();
        let mut write: *mut u8 = ptr::null_mut();
        let mut bytes: usize = 0;

        let status = unsafe {
            rk_infer_frame_new(
                8,
                8,
                ptr::null(),
                &mut frame,
                &mut write,
                &mut bytes,
                &mut detail,
            )
        };
        assert_eq!(name_of(status), "InvalidArgument");
        assert!(take_detail(detail).contains("pixel_format_name"));

        let mut engine: *mut Engine = ptr::null_mut();
        let mut detail2: *mut c_char = ptr::null_mut();
        let status = unsafe {
            rk_infer_model_load(
                ptr::null_mut(),
                ptr::null(),
                ptr::null(),
                &mut engine as *mut _ as *mut *mut Model,
                &mut detail2,
            )
        };
        assert_eq!(name_of(status), "InvalidArgument");
        take_detail(detail2);
    }

    #[test]
    fn accessors_on_null_return_a_default_rather_than_dereferencing() {
        assert!(unsafe { rk_infer_model_name(ptr::null()) }.is_null());
        assert!(unsafe { rk_infer_model_version(ptr::null()) }.is_null());
        assert!(unsafe { rk_infer_model_task(ptr::null()) }.is_null());
        assert_eq!(unsafe { rk_infer_model_input_width(ptr::null()) }, 0);
        assert_eq!(unsafe { rk_infer_model_retention_seconds(ptr::null()) }, 0);
        assert_eq!(unsafe { rk_infer_outcome_len(ptr::null()) }, 0);
        assert!(unsafe { rk_infer_outcome_at(ptr::null(), 0) }.is_null());
        assert_eq!(unsafe { rk_infer_outcome_retain_until(ptr::null()) }, 0);
        assert_eq!(unsafe { rk_infer_frame_bytes(ptr::null()) }, 0);
        unsafe { rk_infer_outcome_free(ptr::null_mut()) };
        unsafe { rk_infer_model_unload(ptr::null_mut()) };
        assert!(unsafe { rk_infer_engine_close(ptr::null_mut()) }.is_null());
    }

    #[test]
    fn a_missing_runtime_crosses_as_engine_unavailable_with_a_detail() {
        let path = CString::new("no-such-runtime-8de2.so").unwrap();
        let mut engine: *mut Engine = ptr::null_mut();
        let mut detail: *mut c_char = ptr::null_mut();

        let status = unsafe { rk_infer_engine_open(path.as_ptr(), &mut engine, &mut detail) };
        assert_eq!(name_of(status), "EngineUnavailable");
        assert!(engine.is_null());
        assert!(take_detail(detail).contains("no-such-runtime-8de2.so"));
    }

    #[test]
    fn a_panic_inside_the_boundary_becomes_a_status_not_an_unwind() {
        // И144 in its hardest form: this library's own bug must not leave the
        // foreign stack. Exercised through the same helper every entry point
        // uses, so the guarantee is about the mechanism, not one function.
        let mut detail: *mut c_char = ptr::null_mut();
        let status = boundary(&mut detail, || {
            panic!("a bug in rk_infer");
        });
        assert_eq!(name_of(status), "NativeFault");
        let detail = take_detail(detail);
        assert!(detail.contains("a bug in rk_infer"), "{}", detail);
        assert!(detail.contains("panic caught"), "{}", detail);
    }

    #[test]
    fn boundary_clears_the_detail_on_success() {
        // Poison the out-parameter first: a caller reusing a variable must not
        // read a stale detail as if it belonged to this call.
        let stale: *mut c_char = CString::new("stale").unwrap().into_raw();
        let mut detail: *mut c_char = stale;
        let status = boundary(&mut detail, || Ok(()));
        assert!(status.is_null());
        assert!(detail.is_null(), "success writes NULL, not a leftover");
        // The ABI overwrites rather than frees; the caller owned it, so the
        // caller -- here, the test -- still has to let it go.
        unsafe { rk_infer_string_free(stale) };
    }

    #[test]
    fn a_detail_containing_a_nul_is_escaped_rather_than_truncated_away() {
        let mut detail: *mut c_char = ptr::null_mut();
        let status = boundary(&mut detail, || {
            Err(Failure::new(
                Status::InvalidArgument,
                "before\0after".to_string(),
            ))
        });
        assert_eq!(name_of(status), "InvalidArgument");
        let detail = take_detail(detail);
        assert!(
            detail.contains("before") && detail.contains("after"),
            "{}",
            detail
        );
    }
}
