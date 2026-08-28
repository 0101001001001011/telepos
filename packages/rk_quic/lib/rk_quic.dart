/// QUIC and WebTransport for Dart, over a native library.
///
/// Dart has no QUIC of its own — both SDK issues were closed as not planned —
/// so the implementation is Rust behind a C ABI, reached through `dart:ffi`.
/// The point of it is that **the server can speak first**: a print job
/// changing state, a device appearing or failing, reaches a browser client the
/// moment it happens instead of when something next asks.
///
/// ## What this version does
///
/// It loads. [rkQuicVersion] is read out of the native library rather than
/// declared here, and [hasNativeTransport] opens the library to find out. That
/// is deliberately the whole of it: an empty library has no reasons of its own
/// to fail, so a red build means the build pipeline is wrong and nothing else.
///
/// ## Failure is a value, never an exception
///
/// Nothing here throws because the native side is absent, old, or unhappy.
/// [probeNativeLibrary] returns a [NativeProbe] saying which of those it is.
/// Ask before you call:
///
/// ```dart
/// final probe = probeNativeLibrary();
/// if (!probe.isUsable) {
///   // the till still sells; the browser goes on polling
///   return;
/// }
/// ```
///
/// ## In a browser
///
/// Importing this package from code that is also compiled to web is safe:
/// `dart:ffi` is reached through a conditional import and the browser half has
/// none. The answer there is [NativeLoadOutcome.unsupportedPlatform], and it is
/// the correct answer permanently — a browser is the *client* of this
/// endpoint, never its host.
library;

import 'src/loader.dart' as loader;
import 'src/native_probe.dart';

export 'src/loader.dart' show rkQuicAbiVersion, rkQuicLibraryPathVariable;
export 'src/native_probe.dart' show NativeLoadOutcome, NativeProbe;
export 'src/quic_event.dart'
    show
        DatagramReceived,
        EndpointError,
        QuicEvent,
        SessionClosed,
        SessionOpened,
        StreamClosed,
        StreamData,
        StreamMessageReceived,
        StreamOpened,
        UnknownQuicEvent;
export 'src/server.dart' show QuicServer, QuicServerConfig, QuicServerStart;
export 'src/status.dart'
    show RkQuicStatus, RkQuicStatusName, statusFromWireName;

/// Asks the native library which version it is and which ABI it speaks.
///
/// Never throws. Opens the library on every call rather than caching, because
/// caching a failure is how a build that has been fixed goes on reporting
/// broken; after the first call the file is already mapped.
///
/// [expectedAbiVersion] and [candidatePaths] exist for tests and for an
/// operator with an unusual install; leave them alone in ordinary code.
NativeProbe probeNativeLibrary({
  int? expectedAbiVersion,
  List<String>? candidatePaths,
}) => loader.probeNativeLibrary(
  expectedAbiVersion: expectedAbiVersion,
  candidatePaths: candidatePaths,
);

/// The version **the loaded native library reports about itself**, or `null`
/// when there is none to ask.
///
/// It was a `const String` in 0.0.1 and is a nullable getter now, and the
/// change is the point: a constant would have gone on saying the right thing
/// while the shipped `.so` was a year old. Null is not an error — it is the
/// honest answer on a host with no native part, and in a browser.
String? get rkQuicVersion => probeNativeLibrary().version;

/// Whether a native transport is available in this process.
///
/// A real probe: it opens the library and checks the ABI generation. `false`
/// means one of absent, wrong generation, or wrong file — call
/// [probeNativeLibrary] when the difference matters.
bool get hasNativeTransport => probeNativeLibrary().isUsable;
