//! A stand-in for the ONNX Runtime shared library.
//!
//! It exports `OrtGetApiBase` and the two members of `OrtApiBase` this crate
//! reads, and nothing else. It exists so the loader's **success** path is
//! proved by a test that opens a real shared library, rather than asserted in
//! a comment because the real runtime is not installed on the build machine.
//!
//! It is an `[[example]]`, not a dependency: nothing links it, and it is not
//! part of the published package's build. It is not a fake engine -- it
//! deliberately cannot run a model, and the test that uses it asserts exactly
//! that boundary.

use std::os::raw::{c_char, c_void};

#[repr(C)]
pub struct OrtApiBase {
    get_api: Option<unsafe extern "C" fn(u32) -> *const c_void>,
    get_version_string: Option<unsafe extern "C" fn() -> *const c_char>,
}

// The API level rk_infer asks for. Serving it, and refusing anything newer, is
// what a real runtime does.
const SERVED_API_VERSION: u32 = 16;

static VERSION: &[u8] = b"1.99.0-stub\0";

/// Not a real OrtApi table -- just a non-null address, which is all the loader
/// checks. Anything that tried to call through it would be a bug in the test,
/// not in the library.
static FAKE_API_TABLE: u8 = 0;

unsafe extern "C" fn get_api(version: u32) -> *const c_void {
    if version <= SERVED_API_VERSION {
        &FAKE_API_TABLE as *const u8 as *const c_void
    } else {
        std::ptr::null()
    }
}

unsafe extern "C" fn get_version_string() -> *const c_char {
    VERSION.as_ptr() as *const c_char
}

static BASE: OrtApiBase = OrtApiBase {
    get_api: Some(get_api),
    get_version_string: Some(get_version_string),
};

/// # Safety
/// Mirrors the real ONNX Runtime entry point.
#[no_mangle]
pub extern "C" fn OrtGetApiBase() -> *const OrtApiBase {
    &BASE
}

// An example must have a main; this one is never run.
#[allow(dead_code)]
fn main() {}
