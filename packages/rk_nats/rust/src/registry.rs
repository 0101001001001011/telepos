//! Connections live in a registry and are named by integers.
//!
//! Not pointers. A caller that keeps a handle past `close` gets
//! `handleClosed` back as a value (I144); the same mistake with a raw pointer
//! gets a crash in a foreign stack, which is the failure mode the invariant
//! exists to forbid.
//!
//! Integers also survive being sent between Dart isolates, which is what makes
//! it practical to keep every native call off the interface isolate (I145).

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use crate::client::Conn;

static NEXT: AtomicU64 = AtomicU64::new(1);

fn table() -> &'static Mutex<HashMap<u64, Arc<Conn>>> {
    static TABLE: OnceLock<Mutex<HashMap<u64, Arc<Conn>>>> = OnceLock::new();
    TABLE.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Files a connection and returns the handle that names it.
pub fn insert(conn: Conn) -> u64 {
    let handle = NEXT.fetch_add(1, Ordering::Relaxed);
    lock().insert(handle, Arc::new(conn));
    handle
}

/// Looks a connection up. `None` means closed or never opened — the caller
/// turns that into `handleClosed`, not into a panic.
pub fn get(handle: u64) -> Option<Arc<Conn>> {
    lock().get(&handle).cloned()
}

/// Drops a connection. Returns whether there was one, so `close` can tell a
/// double close from a first close instead of pretending both worked.
pub fn remove(handle: u64) -> bool {
    lock().remove(&handle).is_some()
}

/// How many connections are open. For diagnostics and for the leak check in
/// the tests: a handle that is never removed is a leak the GC will not find.
pub fn len() -> usize {
    lock().len()
}

fn lock() -> std::sync::MutexGuard<'static, HashMap<u64, Arc<Conn>>> {
    // A poisoned lock means another thread panicked while holding it. The table
    // itself is a plain map and is not left half-updated by a panic, so
    // recovering is honest here and refusing to would turn one failed call into
    // a permanently dead library.
    match table().lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}
