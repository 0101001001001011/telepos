/// Multicast DNS and DNS-SD for Dart, over a native library — **both halves**.
///
/// ## Why this exists
///
/// Dart has no answering half of mDNS. `multicast_dns` asks and says so; the
/// platform plugins that answer hand the job to a system daemon — Avahi on
/// Linux, Bonjour on Apple, NSD on Android — and that daemon is present on
/// none of the deployments this was written for. A bare Ubuntu image has no
/// Avahi. A Windows machine has no Bonjour unless somebody installed iTunes.
///
/// So a Dart application that wants to be **found** on a local network has had
/// to write a responder itself. This is that responder, done properly:
/// probing, conflict resolution, announcement, goodbye, and the browsing half
/// beside it.
///
/// ## The two things worth knowing before using it
///
/// **A multicast datagram sent without `IP_MULTICAST_IF` leaves by exactly one
/// interface, chosen by the routing table, silently.** Measured 2026-08-05 on
/// a machine with four: the chosen one was a virtual switch adapter that no
/// device is ever behind. This package therefore sends on **every** interface
/// and has no default-send path at all — an empty interface list is
/// [RkMdnsStatus.noInterface], not a socket that hopes. [MdnsResponder.state]
/// reports what each interface carried, so the claim can be checked rather
/// than believed.
///
/// **UDP 5353 is always shared.** Chrome holds it on Windows whenever it is
/// running, `avahi-daemon` holds it on Linux, `mDNSResponder` holds it on
/// every Mac. The bind asks to share it with `SO_REUSEADDR` and
/// `SO_REUSEPORT`; [RkMdnsStatus.portInUse] means sharing was refused, and it
/// is an ordinary answer rather than a fault.
///
/// ## Announcing
///
/// ```dart
/// final started = await MdnsResponder.start(
///   const ServiceAnnouncement(
///     instanceName: 'till-3',
///     serviceType: '_telepos._tcp.local',
///     port: 8443,
///     txt: ['quic=4433', 'path=/rk', 'scheme=https'],
///   ),
/// );
/// if (!started.isOk) {
///   // The till still sells and is still reachable by address. What is lost
///   // is being *found* without somebody typing one.
///   return;
/// }
/// final responder = started.responder!;
/// if (!await responder.hasRequestedName) {
///   // Another host on this network already answers to `till-3`. That is a
///   // setup mistake with a visible consequence, so it is worth showing.
/// }
/// await responder.stop(); // returns after the goodbye has gone out
/// ```
///
/// ## Finding
///
/// ```dart
/// final browsing = await MdnsBrowser.start(
///   const BrowseRequest(serviceType: '_telepos._tcp.local'),
/// );
/// await for (final event in browsing.browser!.events) {
///   if (event is ServiceResolved) {
///     print('${event.instance} at ${event.addresses.first}:${event.port}');
///     print('quic port: ${event['quic']}');
///   }
/// }
/// ```
///
/// ## Failure is a value, never an exception
///
/// Nothing here throws because the native side is absent, old, or unhappy, and
/// nothing throws because the network said no. [probeNativeLibrary] returns a
/// [NativeProbe] saying which it is; every call returns an [RkMdnsStatus].
///
/// ## In a browser
///
/// Importing this package from code that is also compiled to web is safe:
/// `dart:ffi` is reached through a conditional import and the browser half has
/// none. The answer there is [NativeLoadOutcome.unsupportedPlatform] and
/// [RkMdnsStatus.unsupported], permanently — a browser has no UDP socket and
/// no multicast group to join, so this is a property of the platform rather
/// than a gap to be filled in later.
library;

import 'src/loader.dart' as loader;
import 'src/native_probe.dart';

export 'src/browser.dart'
    show MdnsBrowser, MdnsBrowserStart, mdnsInterfaces, resolveHost;
export 'src/loader.dart' show rkMdnsAbiVersion, rkMdnsLibraryPathVariable;
export 'src/mdns_event.dart'
    show
        Announced,
        Answered,
        BrowserEvent,
        Goodbye,
        MdnsError,
        NameClaimed,
        NameConflict,
        ProbingName,
        Queried,
        ResponderEvent,
        ServiceFound,
        ServiceLost,
        ServiceResolved,
        UnknownMdnsEvent;
export 'src/native_probe.dart' show NativeLoadOutcome, NativeProbe;
export 'src/responder.dart' show MdnsResponder, MdnsResponderStart;
export 'src/service.dart'
    show
        BrowseRequest,
        HostAddresses,
        HostQuery,
        InterfaceReport,
        MdnsInterface,
        ResponderState,
        ServiceAnnouncement,
        TxtEntry,
        mdnsPort;
export 'src/status.dart'
    show RkMdnsStatus, RkMdnsStatusName, statusFromWireName;

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
/// Read out of the library rather than declared here: a Dart constant would go
/// on saying the right thing while the shipped `.so` was a year old. Null is
/// not an error — it is the honest answer on a host with no native part, and
/// in a browser.
String? get rkMdnsVersion => probeNativeLibrary().version;

/// Whether this process can speak mDNS.
///
/// A real probe: it opens the library and checks the ABI generation. `false`
/// means one of absent, wrong generation, or wrong file — call
/// [probeNativeLibrary] when the difference matters.
bool get hasNativeMdns => probeNativeLibrary().isUsable;
