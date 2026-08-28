/// The closed set of ways a call into the native library can end.
///
/// **И147 — this crosses FFI by name, never by index.** The native side
/// returns a NUL-terminated name (`"portInUse"`), and [RkQuicStatus.byName]
/// resolves it. An integer discriminant would be a shared secret no compiler
/// checks: inserting a variant in the middle of the Rust enum would silently
/// re-label every branch here, and the bug would look like a transport fault.
///
/// Names are matched against the Dart enum's own `name`, so there is no
/// translation table to drift.
enum RkQuicStatus {
  /// The call did what it said.
  ok,

  /// A required argument was null, empty, or not the shape the call expects.
  invalidArgument,

  /// The handle is not one the library issued, or has already been stopped.
  unknownHandle,

  /// The UDP port is already bound by something else.
  portInUse,

  /// The address could not be bound for some reason other than a taken port.
  bindFailed,

  /// The certificate or key could not be read, or does not match.
  badCertificate,

  /// The peer went away mid-session. A fact about the session, not a fault of
  /// ours, and the reason to stop writing to it.
  peerGone,

  /// Nothing to report right now. Distinct from [ok] so a poll loop can tell
  /// "no event" from "an event, handled".
  wouldBlock,

  /// The endpoint is not running.
  notRunning,

  /// A panic was caught at the FFI boundary. The process is alive and the call
  /// did nothing. This is a bug in the native library, and the caller is
  /// entitled to be told rather than to be aborted.
  panic,

  /// The transport is not compiled into this build.
  unsupported,

  /// The native library returned a name this build does not know.
  ///
  /// Not a variant of the native enum — a variant of *this* one, so that a
  /// newer library talking to an older Dart side degrades to "unrecognised"
  /// instead of matching the wrong branch. Never sent by the native side.
  unrecognised,
}

/// Resolves a name from the native side.
extension RkQuicStatusName on RkQuicStatus {
  /// The name as it crosses the boundary.
  String get wireName => name;
}

/// Looks a status up by the name the native library sent.
///
/// Returns [RkQuicStatus.unrecognised] for anything unknown, including an
/// empty string — the one thing it must never do is guess.
RkQuicStatus statusFromWireName(String? wireName) {
  if (wireName == null || wireName.isEmpty) return RkQuicStatus.unrecognised;
  for (final status in RkQuicStatus.values) {
    if (status.name == wireName) return status;
  }
  return RkQuicStatus.unrecognised;
}
