/// Motion control commands and telemetry.
///
/// **This release claims the name and nothing more.** There is no
/// implementation yet: it exists so the publishing pipeline, the package layout
/// and the build matrix can be proved on something that cannot break a caller.
///
/// Deliberately dormant. A control loop cannot run in a garbage-collected runtime, so this package carries intent and observation, never the loop. With servo drives the loop is closed inside the drive, which is why this package may never need more than a protocol.
library;

/// The version this package reports about itself.
const String rkRtVersion = '0.0.1';

/// Whether a native implementation is available in this build.
///
/// Always `false` for now, and honest about it: a caller that asks gets a
/// straight answer instead of a method that throws on use.
bool get hasNativeLoop => false;
