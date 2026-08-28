/// The closed set of ways a call into the native library can end.
///
/// **И147 — this crosses FFI by name, never by index.** The native side
/// returns a NUL-terminated name (`"portInUse"`), and [statusFromWireName]
/// resolves it. An integer discriminant would be a shared secret no compiler
/// checks: inserting a variant in the middle of the Rust enum would silently
/// re-label every branch here, and the bug would look like a network fault.
///
/// Names are matched against the Dart enum's own `name`, so there is no
/// translation table to drift.
enum RkMdnsStatus {
  /// The call did what it said.
  ok,

  /// A required argument was null, empty, or not the shape the call expects.
  invalidArgument,

  /// The handle is not one the library issued, or has already been stopped.
  unknownHandle,

  /// UDP 5353 is held by something that will not share it.
  ///
  /// An ordinary outcome rather than a fault. Chrome holds 5353 on Windows
  /// whenever it is running, `avahi-daemon` holds it on Linux, and
  /// `mDNSResponder` holds it on every Mac; the bind asks to share, and this
  /// says sharing was refused.
  portInUse,

  /// The socket could not be bound for another reason — no permission, no
  /// such address.
  bindFailed,

  /// There is no network interface to announce on.
  ///
  /// Never survivable by falling back to "send by whatever the routing table
  /// prefers": that was measured to be a virtual switch adapter on a
  /// four-interface machine, so the announcement left by a door no device is
  /// behind, silently.
  noInterface,

  /// Nothing to report right now. Distinct from [ok] so a poll loop can tell
  /// "no event" from "an event, handled".
  wouldBlock,

  /// The responder or browser is not running.
  notRunning,

  /// A panic was caught at the FFI boundary. The process is alive and the call
  /// did nothing. This is a bug in the native library, and the caller is
  /// entitled to be told rather than to be aborted.
  panic,

  /// Multicast DNS is not available on this platform at all — the browser.
  unsupported,

  /// The native library returned a name this build does not know.
  ///
  /// Not a variant of the native enum — a variant of *this* one, so that a
  /// newer library talking to an older Dart side degrades to "unrecognised"
  /// instead of matching the wrong branch. Never sent by the native side.
  unrecognised,
}

/// Resolves a name from the native side.
extension RkMdnsStatusName on RkMdnsStatus {
  /// The name as it crosses the boundary.
  String get wireName => name;
}

/// Looks a status up by the name the native library sent.
///
/// Returns [RkMdnsStatus.unrecognised] for anything unknown, including an
/// empty string — the one thing it must never do is guess.
RkMdnsStatus statusFromWireName(String? wireName) {
  if (wireName == null || wireName.isEmpty) return RkMdnsStatus.unrecognised;
  for (final status in RkMdnsStatus.values) {
    if (status.name == wireName) return status;
  }
  return RkMdnsStatus.unrecognised;
}
