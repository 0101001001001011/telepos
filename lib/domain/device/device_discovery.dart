import 'package:meta/meta.dart';

import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';

/// Where a [DeviceCandidate] was found — the physical channel discovery used
/// to notice it exists, not what kind of device it is and not which
/// `DeviceProfile` it should be bound to. Named per
/// docs/system-architecture.md, section 8, "Всё настраивается из
/// интерфейса": "список портов, USB-устройств, найденных сетевых принтеров,
/// спаренных Bluetooth-устройств".
enum DeviceDiscoverySource {
  /// A serial (COM) port the host can see, e.g. via
  /// `SerialPort.availablePorts` (package `flutter_libserialport`).
  serialPort,

  /// A USB-attached device node the host can see without the operator
  /// naming a port — e.g. a raw `/dev/usb/lp*` spooler node.
  usb,

  /// A device reachable over the local network — a printer answering on the
  /// host's own subnet, found by sweeping it rather than by the operator
  /// typing an address.
  network,

  /// A device found through a Bluetooth scan, e.g.
  /// `SysdClient.bluetoothScan()`.
  bluetooth,
}

/// "Something answers at this address" — nothing more.
///
/// A candidate is deliberately **not** a `DeviceBinding`
/// (`lib/domain/terminal/device_binding.dart`): discovery reports that a
/// serial port, USB node, network address or paired Bluetooth device exists;
/// which `DeviceProfile` it actually is remains a human decision. Adding a
/// field here that guesses a profile, or turning a candidate into a binding
/// automatically, is exactly the model-guessing that blocked plan 2's merge
/// — a device bound to the wrong model prints wrong receipts while looking
/// healthy. See docs/system-architecture.md, section 8, "Класс устройства, а
/// не модель".
@immutable
class DeviceCandidate {
  const DeviceCandidate({
    required this.source,
    required this.title,
    this.parameters = const <String, String>{},
  });

  /// Which channel found this candidate.
  final DeviceDiscoverySource source;

  /// Human-readable label for a picker — e.g. a port name, a paired
  /// device's advertised name. Never a profile or model guess.
  ///
  /// **Never empty.** This is the whole of what an operator picks by; a row
  /// with no label is not choosable, so a producer with nothing better to say
  /// falls back to the address or device path rather than to `''` (see
  /// `DeviceDiscoveryLocal`'s USB and Bluetooth branches). `lib/domain/wire/device_wire.dart`
  /// enforces the same on the way in from the wire instead of defaulting.
  final String title;

  /// Connection parameter values this candidate implies, keyed exactly like
  /// `DeviceProfile.connectionParams`' `DeviceConnectionParam.key`
  /// (`lib/domain/device/device_profile.dart`) — so a settings screen can
  /// drop them straight into the matching fields once the operator has
  /// picked which profile this candidate actually is. Empty when nothing
  /// about the candidate maps onto an addressable value — see
  /// `DeviceDiscoveryLocal`'s doc comment for a concrete case where that
  /// happens rather than being faked.
  final Map<String, String> parameters;

  @override
  String toString() =>
      'DeviceCandidate(source: $source, title: $title, '
      'parameters: $parameters)';
}

/// The outcome of one [DeviceDiscovery.find] call: what was found, and which
/// sources — if any — could not even be searched.
///
/// Fix round 1 (task 1): the first version of this contract had no way to
/// say a search had failed — every source swallowed to an empty list, full
/// stop. That is fine for "this COM port has nothing on it", but it is not
/// the same fact as "the till's sysd socket was unreachable", and collapsing
/// the two matters most exactly where this contract stops being trusted on
/// its own: plan task 4 puts it over HTTP, where "no devices attached" and
/// "could not reach the till" must read differently to a browser operator —
/// an unplugged printer and a dead network are not the same problem, and an
/// operator staring at an empty list cannot tell them apart unless the
/// contract itself keeps the two apart.
@immutable
class DeviceDiscoveryResult {
  const DeviceDiscoveryResult({
    this.candidates = const <DeviceCandidate>[],
    this.failedSources = const <DeviceDiscoverySource>{},
  });

  /// Every candidate found, from every source that could actually be
  /// searched — including sources that searched cleanly and found nothing.
  final List<DeviceCandidate> candidates;

  /// Sources that *applied* to the requested [DeviceClass] (at least one of
  /// its profiles declares the connection parameter that source fills) but
  /// could not be searched at all — an unreachable socket, a missing native
  /// library, no usable network interface. Empty means every applicable
  /// source actually ran, even if none of them found anything — that is a
  /// genuine "nothing here", not a gap in the search.
  final Set<DeviceDiscoverySource> failedSources;

  @override
  String toString() =>
      'DeviceDiscoveryResult(candidates: $candidates, '
      'failedSources: $failedSources)';
}

/// Finds candidates for a [DeviceClass] — "something answers here" — without
/// creating bindings and without guessing which profile a candidate is. See
/// [DeviceCandidate]'s doc comment and docs/system-architecture.md, section
/// 8.
///
/// Implementations must degrade honestly per source: a source unavailable on
/// the current platform, or one that simply finds nothing, yields no
/// candidates from that source and never throws for the whole search — but
/// must say so via [DeviceDiscoveryResult.failedSources] rather than making
/// that failure indistinguishable from a clean, empty result. Never a
/// fabricated candidate either way.
///
/// One deliberate exception to "never throws", added in the phase-2 fix
/// wave's second round (2026-08-21, matching [DeviceCheck]'s contract
/// exactly): `WtDeviceDiscovery` (`lib/web/wt_device_discovery.dart`) lets
/// `SessionLost` (`lib/domain/wire/session_lost.dart`) escape rather than
/// folding it into [DeviceDiscoveryResult.failedSources] — an expired
/// session is not "could not search this source", and showing the operator
/// the same "could not search" dialog the till gives for an unreachable
/// device sends them to the wrong screen when the fix is to log back in.
abstract interface class DeviceDiscovery {
  /// Every candidate found for [deviceClass], from every source this
  /// implementation knows how to search, plus which of those sources (if
  /// any) could not be searched. An empty [DeviceDiscoveryResult.candidates]
  /// list with an empty [DeviceDiscoveryResult.failedSources] set is a
  /// normal, successful "nothing found" — not an error.
  Future<DeviceDiscoveryResult> find(DeviceClass deviceClass);
}

/// Which [DeviceDiscoverySource] values could possibly answer for
/// [deviceClass] — derived from which connection-parameter keys [catalog]'s
/// profiles of that class declare (`comPort`/`devicePath` → [serialPort]
/// and/or [usb], `macAddress` → [bluetooth], `ipAddress` → [network]).
///
/// The single, tested definition of that mapping (fix round 1, plan 2b, task
/// 4). `DeviceDiscoveryLocal.find` (`lib/data/device/device_discovery_local.dart`)
/// uses this to decide which of its four concurrent searches to actually
/// run — it still keeps its own finer-grained `comPort`/`devicePath`/`port`
/// booleans alongside this for building each candidate's `parameters` map,
/// which needs the individual keys, not just which source they fall under.
/// `HttpDeviceDiscovery` (`lib/web/http_device_discovery.dart`) calls this
/// same function to say, honestly, which sources it could not even ask the
/// till about when the HTTP call itself fails — see
/// [DeviceDiscoveryResult.failedSources]'s doc comment for why collapsing
/// that to an empty, successful-looking result would rebuild exactly the
/// defect that field exists to prevent. One definition instead of two
/// separately hand-written ones that could silently drift apart on exactly
/// the input `failedSources` was built to protect (task-4 fix round 1,
/// finding 2).
Set<DeviceDiscoverySource> discoverableSourcesFor(
  DeviceClass deviceClass,
  DeviceProfileCatalog catalog,
) {
  final declaredKeys = <String>{
    for (final profile in catalog.forClass(deviceClass))
      for (final param in profile.connectionParams) param.key,
  };

  return {
    if (declaredKeys.contains('comPort') || declaredKeys.contains('devicePath'))
      DeviceDiscoverySource.serialPort,
    if (declaredKeys.contains('devicePath')) DeviceDiscoverySource.usb,
    if (declaredKeys.contains('macAddress')) DeviceDiscoverySource.bluetooth,
    if (declaredKeys.contains('ipAddress')) DeviceDiscoverySource.network,
  };
}
