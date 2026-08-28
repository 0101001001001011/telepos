//! Opaque handles, and the single rule about who frees them.
//!
//! **The caller frees.** Every constructor in this crate returns a pointer
//! obtained from `Box::into_raw`; the library keeps no second copy and will
//! never free it on its own. Exactly one call to the matching `…_drop`
//! releases it.
//!
//! The tag catches a pointer of the *wrong kind* — a subscriber passed where a
//! session was expected — before anything is dereferenced. It does **not**
//! catch a second drop of the same pointer: after the free, reading the tag is
//! already a use-after-free. Single drop is the Dart side's obligation, and it
//! discharges it by nulling its own pointer inside a finaliser-free wrapper.
//!
//! Handles are not thread-safe to *drop* concurrently with use; they are safe
//! to *use* from several threads, which is what the Dart side does when a
//! worker isolate receives while another publishes.

use crate::status::{ErrorKind, RkzError, RkzResult};

/// A type that can live behind an opaque pointer.
///
/// `TAG` distinguishes handle types from one another so that passing a
/// subscriber where a session was expected is caught instead of dereferenced.
pub trait Tagged: Sized {
    const TAG: u64;
    const NAME: &'static str;
}

/// The value actually placed on the heap: a tag followed by the payload.
#[repr(C)]
pub struct Boxed<T: Tagged> {
    tag: u64,
    value: T,
}

/// Hand a value to the caller as an opaque pointer.
pub fn into_raw<T: Tagged>(value: T) -> *mut Boxed<T> {
    Box::into_raw(Box::new(Boxed { tag: T::TAG, value }))
}

/// Borrow a handle the caller passed in.
///
/// # Safety
/// `ptr` must be either null or a pointer previously returned by
/// [`into_raw`] for the same `T` and not yet dropped.
pub unsafe fn as_ref<'a, T: Tagged>(ptr: *const Boxed<T>) -> RkzResult<&'a T> {
    if ptr.is_null() {
        return Err(RkzError::new(
            ErrorKind::NullArgument,
            format!("a {} handle was null", T::NAME),
        ));
    }
    // SAFETY: non-null and, by the contract above, from `into_raw`.
    let boxed = unsafe { &*ptr };
    if boxed.tag != T::TAG {
        return Err(RkzError::new(
            ErrorKind::NullArgument,
            format!("the pointer given as a {} handle is not one", T::NAME),
        ));
    }
    Ok(&boxed.value)
}

/// Take a handle back from the caller and free it.
///
/// # Safety
/// Same contract as [`as_ref`], and additionally: this must be called at most
/// once per pointer. After it returns the allocation is gone, and passing the
/// pointer anywhere again — including here — is undefined.
pub unsafe fn from_raw<T: Tagged>(ptr: *mut Boxed<T>) -> RkzResult<T> {
    if ptr.is_null() {
        return Err(RkzError::new(
            ErrorKind::NullArgument,
            format!("a {} handle was null", T::NAME),
        ));
    }
    // SAFETY: non-null; the tag check below rejects anything not ours before
    // we take ownership of the allocation.
    let tag = unsafe { (*ptr).tag };
    if tag != T::TAG {
        return Err(RkzError::new(
            ErrorKind::NullArgument,
            format!("the pointer given as a {} handle is not one", T::NAME),
        ));
    }
    // SAFETY: tag matched, so this allocation came from `into_raw::<T>`;
    // ownership moves here and the caller must not reuse the pointer.
    let boxed = unsafe { Box::from_raw(ptr) };
    Ok(boxed.value)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug)]
    struct A(u32);
    impl Tagged for A {
        const TAG: u64 = 0xAAAA_0001;
        const NAME: &'static str = "a";
    }

    #[derive(Debug)]
    struct B;
    impl Tagged for B {
        const TAG: u64 = 0xBBBB_0001;
        const NAME: &'static str = "b";
    }

    #[test]
    fn a_handle_round_trips() {
        let raw = into_raw(A(7));
        // SAFETY: `raw` came from `into_raw::<A>` and is still live.
        assert_eq!(unsafe { as_ref::<A>(raw) }.unwrap().0, 7);
        // SAFETY: as above, and this is the single drop.
        assert_eq!(unsafe { from_raw(raw) }.unwrap().0, 7);
    }

    #[test]
    fn null_is_reported_not_dereferenced() {
        // SAFETY: null is explicitly allowed, and is what is under test.
        let err = unsafe { as_ref::<A>(std::ptr::null()) }.unwrap_err();
        assert_eq!(err.kind, ErrorKind::NullArgument);
    }

    #[test]
    fn the_wrong_handle_type_is_rejected() {
        let raw = into_raw(A(1));
        // SAFETY: the pointer is live; only the type is wrong, which is what
        // the tag exists to catch before anything is dereferenced.
        let err = unsafe { as_ref::<B>(raw.cast()) }.unwrap_err();
        assert_eq!(err.kind, ErrorKind::NullArgument);
        // SAFETY: `raw` came from `into_raw::<A>`; this is the single drop.
        unsafe { from_raw(raw) }.unwrap();
    }
}
