# rk_zenoh

[Zenoh](https://zenoh.io) bindings for Dart: publish, subscribe and liveliness
for a fleet of devices that spends part of its time disconnected.

Underneath the binding is a small Rust crate (`rust/`) over a **stable subset**
of Zenoh 1.9. It is deliberately narrow: about thirty functions instead of eight
hundred, one ownership rule instead of a hundred and twenty-six type
definitions, and every enum crosses the boundary **by name**.

```dart
final session = await ZenohSession.open(ZenohConfig(
  mode: SessionMode.peer,
  connect: ['tcp/127.0.0.1:7447'],
));

final alive = await session.declareLiveliness('telepos/alive/till-17');
final orders = await session.subscribe('telepos/till/till-17/cmd');
orders.samples.listen((s) => print('${s.key}: ${s.text}'));

await session.put('telepos/shop/3/heartbeat', utf8.encode('ok'));

await alive.close();
await session.close();
```

No call runs on the caller's isolate: the package keeps a worker isolate of its
own, and all of the native side lives there.

## What is not here, and why you want to know that up front

**Advanced Pub/Sub is absent.** The publisher cache, history for late
subscribers, gap detection and recovery — all of it sits behind Zenoh's
`unstable` feature, and this package does not enable it. That is exactly the
part people usually turn into "works offline", so it has to be built **on top
of** the package: durable state lives in a database that replicates, and this
fabric carries what is happening now. A subscriber that was not listening
missed nothing — as far as it is concerned, the message never existed.

For the same reason there is no per-message reliability control
(`zenoh::qos::Reliability` is unstable) and no liveliness history.

**Zenoh does not traverse NAT.** It finds neighbours by multicast within a
single network and spreads what it learns by gossip once an entry point is
known, but the addresses it is handed have to be routable. Reaching a till
behind somebody else's router is a relay's job, not the fabric's.

## A Zenoh ID is not an address

A recreated session gets a **new** Zenoh ID. Messages sent to the old one are
accepted successfully and delivered nowhere — with no error. For a till that
restarts on every update, that is an ordinary event, not an edge case.

The package makes you choose explicitly, through `ZenohIdentity`:

| | `ephemeral` | `pinnedTo` / `derivedFrom` |
| --- | --- | --- |
| ID after a restart | new | the same |
| What you address | a durable name in the key | the ID itself |
| Requires TLS | no | **yes**, and the package refuses without it |

The refusal is not a formality: **whoever claims a pinned ID first keeps it** —
measured. Without a certificate, any machine on the network can cut a till out
of the fabric simply by booting earlier.

The numbers, and how they were obtained, are in
[`doc/stale-zid.md`](doc/stale-zid.md). The edges of the stable subset are in
[`doc/stable-subset.md`](doc/stable-subset.md).

## Building the native side

```
cd rust && cargo build --release
```

The package is a **Flutter FFI plugin**: `flutter build` invokes cargo itself
and puts the library into the application on Windows, Linux and Android. There
is no `hook/` directory here and there never will be — its mere presence breaks
`dart run`, `dart test` and `flutter build`. The mechanism, the three different
routes to cargo, and the order to check things in on a Mac are in
[`doc/native-build.md`](doc/native-build.md).

Outside a built application the library is located by an explicit path, by the
`RK_ZENOH_LIBRARY` environment variable, or next to the executable; the crate
is a plain `cdylib`/`staticlib` with a C ABI.

**Where the library actually arrives:**

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrives | `rk_zenoh.dll` next to the runner of the built application |
| Linux | arrives | `librk_zenoh.so` in the application's `bundle/lib/` |
| Android | arrives | found **inside the unpacked APK** for `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| macOS, iOS | **built and linked** | verified 2026-08-03 on Apple M4 / macOS 26.2 / Xcode 26.2: the archive builds for arm64 and x86_64 on macOS, arm64 on device and both on the simulator; a C probe links against it with `-force_load` in Release and Debug, and the macOS binaries run through the C ABI. Gated by CI from that day. |

## Licence

MIT, by Rob Kim. See `LICENSE`. Zenoh itself is Apache-2.0 or EPL-2.0.
