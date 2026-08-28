//! Handles, and why they are names rather than pointers.
//!
//! A handle here is a `u64` counter, looked up in a table. It is never a
//! pointer cast to an integer, and that is the whole design: a stale handle
//! resolves to `unknownHandle`, a status the caller reads, instead of to a
//! use-after-free that crashes an hour later somewhere else. The counter never
//! repeats within a process, so a handle also cannot be reused for a different
//! object between one call and the next.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

/// A table of live objects of one kind.
pub struct Registry<T> {
    entries: Mutex<HashMap<u64, Arc<T>>>,
    next: AtomicU64,
}

impl<T> Registry<T> {
    fn new() -> Registry<T> {
        Registry {
            entries: Mutex::new(HashMap::new()),
            // Starts at 1 so that zero is never a valid handle: a caller that
            // reads an uninitialised out-parameter gets something this table
            // refuses rather than something it accepts.
            next: AtomicU64::new(1),
        }
    }

    /// Puts an object in and returns its handle.
    pub fn insert(&self, value: T) -> u64 {
        let handle = self.next.fetch_add(1, Ordering::SeqCst);
        let mut entries = self.lock();
        entries.insert(handle, Arc::new(value));
        handle
    }

    /// The object behind a handle, if it is one this table issued and still
    /// holds.
    ///
    /// An `Arc` rather than a borrow so the caller can drop the table's lock
    /// before doing anything slow with it — a poll that held the lock would
    /// block every other call for the length of its timeout.
    pub fn get(&self, handle: u64) -> Option<Arc<T>> {
        self.lock().get(&handle).cloned()
    }

    /// Takes an object out. A second take answers `None`, which the callers
    /// turn into `notRunning` rather than into a failure: during shutdown a
    /// double stop is ordinary.
    pub fn take(&self, handle: u64) -> Option<Arc<T>> {
        self.lock().remove(&handle)
    }

    /// How many are live. For tests, and for proving that a stop really
    /// removed one.
    pub fn len(&self) -> usize {
        self.lock().len()
    }

    /// Whether nothing is live.
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// The map, with a poisoned lock recovered rather than escalated.
    ///
    /// A panic in another thread that happened to be holding this lock must
    /// not turn every later call into a panic of its own — that would be И144
    /// broken in the one place it matters most.
    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<u64, Arc<T>>> {
        match self.entries.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        }
    }
}

/// The process-wide table for one type.
pub fn registry<T: 'static>(slot: &'static OnceLock<Registry<T>>) -> &'static Registry<T> {
    slot.get_or_init(Registry::new)
}

#[cfg(test)]
mod tests {
    use super::*;

    static TEST: OnceLock<Registry<String>> = OnceLock::new();

    #[test]
    fn a_handle_is_never_zero_and_never_repeats() {
        let table = registry(&TEST);
        let first = table.insert("one".into());
        let second = table.insert("two".into());
        assert_ne!(first, 0);
        assert_ne!(first, second);

        // And a handle whose object was taken out does not come back for the
        // next one — which is what makes a stale handle safe to present.
        table.take(first);
        let third = table.insert("three".into());
        assert_ne!(third, first);
    }

    #[test]
    fn a_stale_handle_resolves_to_nothing_rather_than_to_something_else() {
        let table = registry(&TEST);
        let handle = table.insert("gone".into());
        assert!(table.take(handle).is_some());
        assert!(table.get(handle).is_none());
        assert!(
            table.take(handle).is_none(),
            "a second take found something"
        );
    }
}
