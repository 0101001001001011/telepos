# rk_mdns

Multicast DNS (RFC 6762) and DNS-SD (RFC 6763) for Dart, over a native
library — **both halves**. An application can announce itself on a local
network and be found by anything that speaks mDNS, with no system daemon
installed and nothing typed by an operator.

## Why this exists

**Dart has no answering half of mDNS.** `multicast_dns` asks, and says so. The
platform plugins that answer hand the job to a system daemon — Avahi on Linux,
Bonjour on Apple, NSD on Android — and that daemon is present on none of the
deployments this was written for: a bare Ubuntu appliance image has no Avahi,
and a Windows machine has no Bonjour unless somebody installed iTunes.

So an application that wants to be *found* has had to write a responder itself.
This is that responder, written out properly, plus the browsing half beside it.

## What it does

**Responder**

- Announces a service: `PTR`, `SRV`, `TXT`, `A`, `AAAA`, and the
  `_services._dns-sd._udp.local` pointer that `avahi-browse -a` looks for.
- **Resolves a name conflict** (§8.1): probes three times, tie-breaks against a
  simultaneous prober (§8.2), and renames itself to `<name>-2` if another host
  holds the name. The new name is reported, because two hosts named alike is a
  setup mistake and it has to be visible.
- Announces more than once, a second apart (§8.3).
- **Says goodbye** on a clean stop (§10.1) — the same records with a lifetime of
  zero, so nobody holds a dead service in cache for minutes.
- Answers a question about the instance and about the host separately, with
  known-answer suppression (§7.1) and a unicast reply when the `QU` bit asks
  for one (§5.4).

**Browser**

- Resolves `<name>.local` to addresses.
- Browses a service type, with arrivals **and departures**.
- Splits `TXT` into key/value pairs, keeping "present with no value" distinct
  from "absent" (§6.4).
- Caches with real lifetimes and sends known answers, so an idle browse costs
  the segment almost nothing.

**Both** — IPv4 and IPv6, every failure returned as a value, and no panic
crosses the FFI boundary.

## The two things worth knowing before using it

### A multicast send goes out one interface unless you make it not

Measured 2026-08-05 on a workstation with four IPv4 interfaces. A datagram sent
to `224.0.0.251` **without** `IP_MULTICAST_IF` left by exactly one of them,
chosen by the routing table — and the chosen one was a virtual switch adapter
no device is ever behind. Nothing was wrong with the packet. The host was
invisible, silently.

So this package sends on **every** interface and **has no default-send path at
all**: an empty interface list is `RkMdnsStatus.noInterface`, not a socket that
hopes. `MdnsResponder.state()` reports what each interface carried, so the
claim can be checked rather than believed.

```dart
final state = await responder.state();
for (final i in state!.interfaces) {
  print('${i.name} ${i.address}: sent ${i.sent}, failed ${i.failed}');
}
```

### UDP 5353 is always shared

Chrome holds it on Windows whenever it is running. `avahi-daemon` holds it on
Linux. `mDNSResponder` holds it on every Mac. Sharing is the normal condition
of an mDNS responder, and the bind asks for it with `SO_REUSEADDR` and
`SO_REUSEPORT`. `RkMdnsStatus.portInUse` means sharing was refused — an
ordinary answer with a cause an operator can act on, not a fault.

## Announcing

```dart
import 'package:rk_mdns/rk_mdns.dart';

final started = await MdnsResponder.start(
  const ServiceAnnouncement(
    instanceName: 'till-3',
    serviceType: '_telepos._tcp.local',
    port: 8443,
    txt: ['quic=4433', 'path=/rk', 'scheme=https'],
  ),
);

if (!started.isOk) {
  // Nothing here throws. The application still works and is still reachable
  // by address; what is lost is being *found* without somebody typing one.
  print('not announcing: ${started.status.name} — ${started.detail}');
  return;
}

final responder = started.responder!;

if (!await responder.hasRequestedName) {
  final state = await responder.state();
  print('another host already answers to till-3; using ${state!.instance}');
}

// Returns after the goodbye datagram has gone out.
await responder.stop();
```

## Finding

```dart
final browsing = await MdnsBrowser.start(
  const BrowseRequest(serviceType: '_telepos._tcp.local'),
);

await for (final event in browsing.browser!.events) {
  switch (event) {
    case ServiceResolved(:final instance, :final addresses, :final port):
      print('$instance at ${addresses.first}:$port, quic=${event['quic']}');
    case ServiceLost(:final instance):
      print('$instance is gone');
    default:
  }
}
```

And one name, once:

```dart
final found = await resolveHost(const HostQuery(hostName: 'till-3.local'));
// `found.addresses` empty means asked and nobody replied — which on a network
// that filters multicast is the expected answer, not an error.
```

## Diagnosing "it cannot be found"

Two causes look identical from another machine: a network that filters
multicast, and a host announcing out of the wrong door. Only one call tells
them apart.

```dart
for (final i in await mdnsInterfaces() ?? const []) {
  print('${i.name} ${i.address} #${i.index}');
}
```

If the list is right and the interface counters are non-zero, the datagrams are
leaving. What happens after that is the network's.

## Platforms

Each row says what was actually done, because "supported" on its own has meant
four different things in this project's history.

| Platform | Evidence |
| --- | --- |
| Linux | `librk_mdns.so` built through the plugin's CMake, 13 of 13 entry points exported; the whole Rust suite run on the target; **and the protocol checked against `avahi-browse`, `avahi-resolve` and `avahi-publish`** — transcripts in `doc/interop.md` |
| Windows | `rk_mdns.dll` built through the plugin's CMake, 13 of 13 entry points exported (`dumpbin /exports`); the whole Rust and Dart suites run. Note that Chrome holds 5353 whenever it is running |
| Android | `librk_mdns.so` built for `armeabi-v7a`, `arm64-v8a` and `x86_64` with the NDK toolchain the Gradle task uses, 13 of 13 exported each. **A consuming app must hold a `MulticastLock`** — see below |
| macOS | `librk_mdns.a` built through `apple/build_rust.sh`, `x86_64 arm64`, 13 symbols surviving into the archive |
| iOS | the same for `arm64`, and `x86_64 arm64` for the simulator, 13 symbols each |
| Web | permanently unsupported, and that is a property of the platform: a browser has no UDP socket and no multicast group to join. Importing this package from code compiled to web is safe — `dart:ffi` is behind a conditional import, and a test asserts the browser-side files never reach it |

**Not yet done, and named rather than implied:** `dns-sd -B` and `dns-sd -L`
have not been run against this responder, so Apple is a build and not a
protocol proof; and every interoperability check above ran on one host, because
the segment between the two machines available does not carry multicast
(measured with `tcpdump`).

### Android needs a MulticastLock

Android drops multicast at the Wi-Fi driver unless an application holds one.
That is the application's call rather than the plugin's, so it is written here
rather than done silently:

```xml
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
```

```kotlin
val wifi = getSystemService(Context.WIFI_SERVICE) as WifiManager
val lock = wifi.createMulticastLock("rk_mdns").apply { setReferenceCounted(true); acquire() }
```

Release it when you stop announcing: the lock costs battery.

## Building the native part

The Rust crate ships with the package and is built by the plugin's own build
files — CMake on Windows and Linux, Gradle on Android, a podspec script phase
on Apple. A Rust toolchain is required on the machine that builds the
application. `doc/native-build.md` has the details and the per-platform proofs.

## Interoperability

A responder and a browser from the same source agree with each other whether or
not either agrees with the RFC. The proof that carries weight is the other
direction, and `doc/interop.md` holds the transcripts: `avahi-browse` and
`avahi-resolve` seeing this responder, and this browser seeing a service Avahi
published.

## Licence

MIT.
