//! The embedded engine.
//!
//! # What is embedded and what is not
//!
//! We embed an inference engine, we do not write one. The baseline is ONNX
//! Runtime: MIT, and a C API whose own guidelines say no C++ exception crosses
//! it -- everything becomes an `OrtStatus*` the caller frees. That is already
//! И144's shape, which is why it is the baseline rather than a preference.
//!
//! This crate does not contain ONNX Runtime and does not download it. It opens
//! a shared library that is already on the machine, put there by the same
//! signed apt channel that delivers the models. A missing runtime is
//! `EngineUnavailable` with the tried paths in the detail -- never a crash,
//! never a silent no-op.
//!
//! # What is finished here and what is not
//!
//! Finished: locating and opening the runtime, proving it exports
//! `OrtGetApiBase`, calling it, taking the version string, and asking for an
//! `OrtApi` at the API level this build was written against. All of that runs
//! against a real library and is exercised by a test that builds one.
//!
//! **Not finished: the session and the tensor path.** `Session::run` returns
//! `NotImplemented` with a detail naming the exact ONNX Runtime C entry points
//! still to be bound. It does not return an empty outcome, and it does not
//! return zero detections. A stub that returns a plausible value is the defect
//! this codebase has been bitten by before; a stub that names what is missing
//! is not.
//!
//! # Execution providers
//!
//! CPU is the guaranteed path and the only one this build claims. Accelerators
//! -- OpenVINO on an Intel iGPU, a Hailo HAT on a Raspberry Pi 5 -- are
//! declared where the hardware allows and are never assumed. The floor
//! hardware this product actually ships to includes a thin client whose VIA
//! Chrome9 has no KMS and no `/dev/dri` at all; on that machine there is no
//! acceleration to find, and the honest answer is `Cpu`.

use std::os::raw::c_char;
use std::path::{Path, PathBuf};

use crate::dylib::Library;
use crate::frame::Frame;
use crate::manifest::Manifest;
use crate::status::{Failure, Outcome, Status};

/// The ONNX Runtime C API level this build is written against.
///
/// ORT keeps older levels working, so asking for a level a newer runtime still
/// serves is the supported way to be version-tolerant. A runtime too old to
/// serve it returns null, and that is `EngineIncompatible`.
const ORT_API_VERSION: u32 = 16;

/// The first two members of `OrtApiBase`, which have not moved since the C API
/// was stabilised. Only these two are declared: nothing else is called here,
/// and declaring a struct whose later members we never touch would be a
/// layout promise with nothing behind it.
#[repr(C)]
struct OrtApiBase {
    get_api: Option<unsafe extern "C" fn(version: u32) -> *const std::ffi::c_void>,
    get_version_string: Option<unsafe extern "C" fn() -> *const c_char>,
}

type OrtGetApiBaseFn = unsafe extern "C" fn() -> *const OrtApiBase;

/// The execution provider actually in use. Crosses by name (И147).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Provider {
    /// Always available. The guaranteed path, on every host, including the
    /// ones with no usable GPU at all.
    Cpu,
}

impl Provider {
    pub const fn c_name(self) -> &'static [u8] {
        match self {
            Provider::Cpu => b"Cpu\0",
        }
    }

    pub fn name(self) -> &'static str {
        let b = self.c_name();
        std::str::from_utf8(&b[..b.len() - 1]).expect("provider names are ASCII")
    }
}

/// The default library names, in the order they are tried.
///
/// Bare names first so the platform's own search path (`LD_LIBRARY_PATH`, the
/// DLL search order, `@rpath`) gets its say; then the location the apt package
/// installs to, which is where it will actually be on an appliance.
pub fn default_candidates() -> Vec<PathBuf> {
    let mut names: Vec<PathBuf> = Vec::new();

    #[cfg(target_os = "windows")]
    {
        names.push(PathBuf::from("onnxruntime.dll"));
    }
    #[cfg(target_os = "macos")]
    {
        names.push(PathBuf::from("libonnxruntime.dylib"));
        names.push(PathBuf::from("/usr/local/lib/libonnxruntime.dylib"));
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        names.push(PathBuf::from("libonnxruntime.so"));
        names.push(PathBuf::from("libonnxruntime.so.1"));
        // Where the TelePOS apt package puts it on an appliance.
        names.push(PathBuf::from("/opt/telepos/lib/libonnxruntime.so"));
        names.push(PathBuf::from("/usr/lib/libonnxruntime.so"));
    }

    names
}

pub struct Engine {
    library: Library,
    runtime_version: Option<std::ffi::CString>,
    provider: Provider,
    /// Models handed out from this engine. The engine outlives them, and
    /// closing it while any are alive is refused.
    live_models: std::sync::atomic::AtomicUsize,
}

impl Engine {
    /// Opens the runtime. `explicit` overrides the default search.
    pub fn open(explicit: Option<&Path>) -> Outcome<Engine> {
        let library = match explicit {
            Some(path) => Library::open(path).map_err(|e| {
                Failure::new(
                    Status::EngineUnavailable,
                    format!("{} -- {}", path.display(), e),
                )
            })?,
            None => {
                let candidates = default_candidates();
                Library::open_first(&candidates)
                    .map_err(|e| Failure::new(Status::EngineUnavailable, e))?
            }
        };

        // Opening a library is not proof it is the right one. A library that
        // does not export OrtGetApiBase is something else with the right name,
        // and finding that out here beats finding it out at the first tensor.
        let get_api_base: OrtGetApiBaseFn =
            unsafe { library.symbol("OrtGetApiBase") }.ok_or_else(|| {
                Failure::new(
                    Status::EngineIncompatible,
                    format!(
                        "{} loaded but exports no OrtGetApiBase; it is not an \
                         ONNX Runtime",
                        library.path()
                    ),
                )
            })?;

        let base = unsafe { get_api_base() };
        if base.is_null() {
            return Err(Failure::new(
                Status::EngineIncompatible,
                format!("{}: OrtGetApiBase returned NULL", library.path()),
            ));
        }
        let base = unsafe { &*base };

        let runtime_version = base.get_version_string.and_then(|f| {
            let p = unsafe { f() };
            if p.is_null() {
                None
            } else {
                let bytes = unsafe { std::ffi::CStr::from_ptr(p) }.to_bytes();
                std::ffi::CString::new(bytes).ok()
            }
        });

        let get_api = base.get_api.ok_or_else(|| {
            Failure::new(
                Status::EngineIncompatible,
                format!("{}: OrtApiBase.GetApi is NULL", library.path()),
            )
        })?;
        let api = unsafe { get_api(ORT_API_VERSION) };
        if api.is_null() {
            return Err(Failure::new(
                Status::EngineIncompatible,
                format!(
                    "{} (version {}) does not serve ONNX Runtime C API level {}",
                    library.path(),
                    runtime_version
                        .as_ref()
                        .map(|v| v.to_string_lossy().into_owned())
                        .unwrap_or_else(|| "unknown".to_string()),
                    ORT_API_VERSION
                ),
            ));
        }

        Ok(Engine {
            library,
            runtime_version,
            // CPU is what this build claims. Probing for an accelerator is a
            // later, honest addition; claiming one now would be a promise
            // about hardware nobody has measured on.
            provider: Provider::Cpu,
            live_models: std::sync::atomic::AtomicUsize::new(0),
        })
    }

    pub fn library_path(&self) -> &str {
        self.library.path()
    }

    pub fn runtime_version(&self) -> Option<&std::ffi::CString> {
        self.runtime_version.as_ref()
    }

    pub fn provider(&self) -> Provider {
        self.provider
    }

    pub fn live_models(&self) -> usize {
        self.live_models.load(std::sync::atomic::Ordering::Acquire)
    }

    pub(crate) fn model_opened(&self) {
        self.live_models
            .fetch_add(1, std::sync::atomic::Ordering::AcqRel);
    }

    pub(crate) fn model_closed(&self) {
        self.live_models
            .fetch_sub(1, std::sync::atomic::Ordering::AcqRel);
    }

    /// Refuses to close while models from this engine are alive: their sessions
    /// live inside the runtime this would unload.
    pub fn check_closable(&self) -> Outcome<()> {
        let live = self.live_models();
        if live > 0 {
            return Err(Failure::new(
                Status::EngineBusy,
                format!(
                    "{} model(s) loaded from this engine are still alive; unload \
                     them before closing the runtime they live in",
                    live
                ),
            ));
        }
        Ok(())
    }

    /// Creates a session for a verified model.
    ///
    /// Not implemented, and says so with the list of what is missing rather
    /// than a handle that fails later.
    pub fn open_session(&self, manifest: &Manifest) -> Outcome<Session> {
        let _ = manifest;
        Err(Failure::new(
            Status::NotImplemented,
            format!(
                "the ONNX Runtime session path is not bound yet. Still to bind, \
                 from the OrtApi table served at C API level {}: CreateEnv, \
                 CreateSessionOptions, SetIntraOpNumThreads, CreateSession, \
                 CreateCpuMemoryInfo, CreateTensorWithDataAsOrtValue, Run, \
                 GetTensorMutableData, ReleaseValue, ReleaseSession, \
                 ReleaseSessionOptions, ReleaseEnv, ReleaseStatus. The runtime \
                 at {} loaded and is usable; nothing above it is written.",
                ORT_API_VERSION,
                self.library_path()
            ),
        ))
    }
}

impl std::fmt::Debug for Engine {
    /// Deliberately narrow: the library path, the runtime version, the
    /// provider, the live model count. Nothing here can grow to include a
    /// frame, because nothing in an `Engine` holds one.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Engine")
            .field("library", &self.library.path())
            .field(
                "runtime_version",
                &self.runtime_version.as_ref().map(|v| v.to_string_lossy()),
            )
            .field("provider", &self.provider.name())
            .field("live_models", &self.live_models())
            .finish()
    }
}

/// A loaded model bound to a runtime session.
#[derive(Debug)]
pub struct Session {
    _private: (),
}

impl Session {
    /// Runs one frame.
    ///
    /// Borrows the frame; ownership does not move (И146). Nothing about the
    /// frame's contents can appear in what this returns, in success or in
    /// failure: see the boundary tests.
    pub fn run(&self, frame: &Frame) -> Outcome<Vec<RawDetection>> {
        let _ = frame;
        Err(Failure::new(
            Status::NotImplemented,
            "no session exists to run; see Engine::open_session".to_string(),
        ))
    }
}

/// A detection as the engine produces it, before class indices are resolved to
/// names. Coordinates are normalised so a consumer never needs the frame to
/// read them.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RawDetection {
    pub class_index: usize,
    pub confidence: f64,
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_missing_runtime_is_engine_unavailable_with_the_paths_tried() {
        let e = Engine::open(Some(Path::new("no-such-runtime-4b21.so"))).unwrap_err();
        assert_eq!(e.status, Status::EngineUnavailable);
        assert!(
            e.detail.contains("no-such-runtime-4b21.so"),
            "the detail must name the path: {}",
            e.detail
        );
    }

    #[test]
    fn the_default_search_lists_platform_names() {
        let names: Vec<String> = default_candidates()
            .iter()
            .map(|p| p.display().to_string())
            .collect();
        assert!(!names.is_empty());
        let joined = names.join(" ");
        assert!(
            joined.contains("onnxruntime"),
            "the default search must look for onnxruntime, got {}",
            joined
        );
    }

    #[test]
    fn opening_a_library_that_is_not_onnx_runtime_is_incompatible_not_unavailable() {
        // A real, loadable library that exports no OrtGetApiBase. Which one
        // does not matter; that it loads and lacks the symbol does.
        let candidates: Vec<&str> = if cfg!(windows) {
            vec!["kernel32.dll"]
        } else if cfg!(target_os = "macos") {
            vec!["/usr/lib/libSystem.B.dylib"]
        } else {
            vec!["libc.so.6", "libm.so.6"]
        };

        let Ok(_lib) = crate::dylib::Library::open_first(&candidates) else {
            // No stand-in on this host; the negative case above still holds.
            eprintln!("skipped: none of {:?} was loadable here", candidates);
            return;
        };

        let e = Engine::open(Some(Path::new(candidates[0]))).unwrap_err();
        assert_eq!(
            e.status,
            Status::EngineIncompatible,
            "a loadable non-ORT library must be told apart from a missing one: {:?}",
            e
        );
        assert!(e.detail.contains("OrtGetApiBase"), "{:?}", e);
    }

    #[test]
    fn the_session_path_says_what_is_missing_rather_than_returning_nothing() {
        // The anti-gaps rule: an unfinished path names what is absent. A stub
        // returning Ok(vec![]) here would read as "no detections" forever and
        // would be indistinguishable from a working engine on a quiet camera.
        let session = Session { _private: () };
        let frame = Frame::new(4, 4, crate::manifest::PixelFormat::Rgb8).unwrap();
        let e = session.run(&frame).unwrap_err();
        assert_eq!(e.status, Status::NotImplemented);
        assert!(!e.detail.is_empty());
    }
}
