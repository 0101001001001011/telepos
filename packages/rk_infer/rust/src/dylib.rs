//! A minimal dynamic loader.
//!
//! Deliberately not `libloading`. The whole need is three calls -- open, look
//! up a symbol, close -- and this crate's rule is that it builds on a machine
//! that has never seen the network, because it builds for tills.
//!
//! Failure is a value here too: a runtime that is not installed produces a
//! message naming what was tried, never a crash.

use std::ffi::{CString, OsStr};
use std::os::raw::{c_char, c_int, c_void};
use std::path::Path;

#[cfg(unix)]
mod sys {
    use super::*;

    pub const RTLD_NOW: c_int = 2;
    pub const RTLD_LOCAL: c_int = 0;

    extern "C" {
        pub fn dlopen(filename: *const c_char, flag: c_int) -> *mut c_void;
        pub fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
        pub fn dlclose(handle: *mut c_void) -> c_int;
        pub fn dlerror() -> *mut c_char;
    }

    // Every call below carries its own `unsafe` block rather than leaning on
    // the enclosing `unsafe fn`, which `#![deny(unsafe_op_in_unsafe_fn)]` in
    // lib.rs makes mandatory. The Windows half of this file was already
    // written that way; this half was not, and nothing noticed — `cfg(unix)`
    // is not compiled on Windows, so cargo build, cargo test and clippy were
    // all green on the machine it was written on.
    //
    // Found twice on 2026-08-01, independently: by the first Android build,
    // and by the first clippy run on a Linux runner. Neither route existed
    // before that day, which is the point.
    pub unsafe fn open(path: &str) -> Result<*mut c_void, String> {
        let c = CString::new(path).map_err(|_| "path contains a NUL".to_string())?;
        // Clear any stale error before the call, per dlerror(3).
        unsafe { dlerror() };
        let handle = unsafe { dlopen(c.as_ptr(), RTLD_NOW | RTLD_LOCAL) };
        if handle.is_null() {
            let e = unsafe { dlerror() };
            let msg = if e.is_null() {
                "dlopen returned NULL without an error".to_string()
            } else {
                unsafe { std::ffi::CStr::from_ptr(e) }
                    .to_string_lossy()
                    .into_owned()
            };
            Err(msg)
        } else {
            Ok(handle)
        }
    }

    pub unsafe fn symbol(handle: *mut c_void, name: &str) -> Option<*mut c_void> {
        let c = CString::new(name).ok()?;
        unsafe { dlerror() };
        let p = unsafe { dlsym(handle, c.as_ptr()) };
        if p.is_null() {
            None
        } else {
            Some(p)
        }
    }

    pub unsafe fn close(handle: *mut c_void) {
        unsafe { dlclose(handle) };
    }
}

#[cfg(windows)]
mod sys {
    use super::*;

    extern "system" {
        fn LoadLibraryA(name: *const c_char) -> *mut c_void;
        fn GetProcAddress(module: *mut c_void, name: *const c_char) -> *mut c_void;
        fn FreeLibrary(module: *mut c_void) -> c_int;
        fn GetLastError() -> u32;
    }

    pub unsafe fn open(path: &str) -> Result<*mut c_void, String> {
        let c = CString::new(path).map_err(|_| "path contains a NUL".to_string())?;
        let handle = unsafe { LoadLibraryA(c.as_ptr()) };
        if handle.is_null() {
            Err(format!("LoadLibrary failed, GetLastError = {}", unsafe {
                GetLastError()
            }))
        } else {
            Ok(handle)
        }
    }

    pub unsafe fn symbol(handle: *mut c_void, name: &str) -> Option<*mut c_void> {
        let c = CString::new(name).ok()?;
        let p = unsafe { GetProcAddress(handle, c.as_ptr()) };
        if p.is_null() {
            None
        } else {
            Some(p)
        }
    }

    pub unsafe fn close(handle: *mut c_void) {
        unsafe { FreeLibrary(handle) };
    }
}

/// An open shared library. Closes itself on drop; that is the only place it is
/// closed.
pub struct Library {
    handle: *mut c_void,
    path: String,
}

// The handle is only touched through `&self` for symbol lookup, and the
// platform loaders are thread-safe for that. Sending it to the worker isolate's
// thread is the whole point.
unsafe impl Send for Library {}
unsafe impl Sync for Library {}

impl Library {
    pub fn open(path: &Path) -> Result<Library, String> {
        let as_str = path
            .to_str()
            .ok_or_else(|| format!("path {:?} is not valid UTF-8", path))?;
        let handle = unsafe { sys::open(as_str) }?;
        Ok(Library {
            handle,
            path: as_str.to_string(),
        })
    }

    /// Tries each candidate in order and reports every failure if none works.
    /// One combined message beats "not found" with no way to tell which name,
    /// which directory, or which architecture was wrong.
    pub fn open_first(candidates: &[impl AsRef<OsStr>]) -> Result<Library, String> {
        let mut tried = Vec::new();
        for candidate in candidates {
            let path = Path::new(candidate.as_ref());
            match Library::open(path) {
                Ok(lib) => return Ok(lib),
                Err(e) => tried.push(format!("  {} -- {}", path.display(), e)),
            }
        }
        Err(format!(
            "no inference runtime could be loaded. Tried:\n{}",
            tried.join("\n")
        ))
    }

    pub fn path(&self) -> &str {
        &self.path
    }

    /// # Safety
    /// The caller asserts that `name` in this library really has type `T`.
    /// Getting that wrong is undefined behaviour, which is why every use in
    /// this crate sits next to the C declaration it mirrors.
    pub unsafe fn symbol<T: Copy>(&self, name: &str) -> Option<T> {
        debug_assert_eq!(
            std::mem::size_of::<T>(),
            std::mem::size_of::<*mut c_void>(),
            "a symbol is a pointer-sized value"
        );
        let raw = unsafe { sys::symbol(self.handle, name) }?;
        Some(unsafe { *(&raw as *const *mut c_void as *const T) })
    }
}

impl std::fmt::Debug for Library {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Library").field("path", &self.path).finish()
    }
}

impl Drop for Library {
    fn drop(&mut self) {
        unsafe { sys::close(self.handle) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opening_a_library_that_is_not_there_is_an_error_not_a_crash() {
        let e = Library::open(Path::new("definitely-not-a-real-library-9f3a.so")).unwrap_err();
        assert!(!e.is_empty(), "the failure must say something");
    }

    #[test]
    fn open_first_names_every_candidate_it_tried() {
        let e =
            Library::open_first(&["no-such-a.so", "no-such-b.dll", "no-such-c.dylib"]).unwrap_err();
        for name in ["no-such-a.so", "no-such-b.dll", "no-such-c.dylib"] {
            assert!(
                e.contains(name),
                "the failure must name {}, got:\n{}",
                name,
                e
            );
        }
    }
}
