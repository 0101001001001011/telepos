# rk_nats

NATS and JetStream for Dart over a native client: durable streams, durable
consumers, and **a contract about what an acknowledgement means**.

## Why this package exists

There is no live Dart NATS client whose JetStream surface is not marked
experimental. And JetStream — durable streams and consumers — is exactly what
people take NATS for.

The second reason matters more than the first.

**JetStream acknowledges a write to the client immediately and flushes it to
disk on a timer.** The Jepsen analysis of NATS 2.12.1 (published 2025-12-08)
lost **131,418 of 930,005 acknowledged messages — about 14 %** in a coordinated
power-cut experiment. That is `nats-server#7564`, and it is still open.

Measured on 2026-07-31 against live servers, not read off a release note:

| Server | `sync_interval` | `sync_always` |
| --- | --- | --- |
| 2.11.0, default settings | 2 minutes | field absent |
| **2.14.4, default settings** | **2 minutes** | field absent |
| 2.14.4, `sync_interval: "always"` | 2 minutes | `true` |

The latest release, seven months after the Jepsen publication, still arrives
with a two-minute window. So durability settings are part of this package's
contract, not something you remember to think about in operations.

## What "acknowledged" means here

By default — **flushed to disk**. The `fsyncOnAck` policy is on without your
having to say anything, and under it publishing is **refused** until the library
has proof that the server fsyncs before acknowledging.

```dart
final result = await RkNatsClient.connect(
  RkNatsConnectOptions(
    servers: ['nats://till-1:4222'],
    // durability: RkNatsDurability.fsyncOnAck — already the case
    evidence: RkNatsVarzEvidence(await fetchVarz('http://till-1:8222/varz')),
  ),
  libraryPath: libraryPath,
);

final client = result.value!;
print(client.ackMeaning);       // RkNatsAckMeaning.fsyncedToDisk

final ack = await client.publish(
  stream: 'sales',
  subject: 'sales.till17',
  payload: utf8.encode(receiptJson),
  messageId: 'receipt-000017',  // a repeat inside the window is the same receipt
);
print(ack.value!.ackMeaning);   // here too, on every acknowledgement
```

There are three policies, and the weak ones have to be said out loud:

| Policy | An acknowledgement means | Speed (measured below) |
| --- | --- | --- |
| `fsyncOnAck` — **the default** | on disk, fsync done | 158 msg/s |
| `flushOnAck` | written, fsync later; **you have to name the loss window** | 2,902 msg/s |
| `ackIsMemoryOnly` | somewhere in the server's memory | not measured separately |

The measurement: one machine, loopback, one replica, publishing sequentially and
awaiting every acknowledgement. **The safe setting is 18 times slower** — and
still four times faster than a payment terminal.

`ackIsMemoryOnly` was never benchmarked on its own; the fast figures in
`doc/durability.md` (4,137 and 4,198 msg/s) are for the `async` persist mode,
which is a different thing entirely — see the second trap below.

## The three traps this whole codebase exists for

**The first.** `sync_interval` **does not change** when fsync-on-every-write is
turned on. A server with `sync_interval: "always"` goes on reporting two
minutes. The `sync_always` field is what settles it, and a probe that reads only
`sync_interval` will call unsafe precisely the server that is safe.

**The second.** A stream in `persist_mode: "async"` acknowledges **before** the
write — and does so on a server configured to fsync every write. Measured: 4,198
msg/s in `async` mode against 158 msg/s in the ordinary mode on the same server.
It does not wait for the disk, and its acknowledgement looks exactly like the
acknowledgement of one that does. The package refuses to create such a stream
under the `fsyncOnAck` policy.

**The third.** nats-server 2.11.0 accepts a stream with `persist_mode: "async"`
and returns the field **absent**, with no error. So support is detected
empirically rather than by comparing versions, and `RkNatsStreamInfo` reports
`requestedPersistMode` and `effectivePersistMode` separately.

And separately: **more replicas are not a substitute for fsync.** Jepsen found
file corruption propagating through Raft, and split brain after a single node
failed with three replicas. Replication protects you from a machine dying, not
from every machine having acknowledged what none of them wrote.

## When to reach for this package, and when for `rk_zenoh`

They are not rivals, and the choice stops being hard the moment you say it out
loud.

**`rk_nats`** — when a message has to survive everything: a sale leaving a till
for the shop server; a stock movement; anything that can be replayed and must
not be delivered twice. JetStream stores messages, remembers how far each
consumer got, and a leaf node keeps accepting writes while the shop's link is
down.

**`rk_zenoh`** — the tunnel and live state: reaching a till behind somebody
else's router, health and presence, a screen watching a value. A pub/sub fabric
is the right shape for "what is true now" and the wrong shape for "what
happened, in order, exactly once".

Wanting both is normal. Using one instead of the other is a mistake.

## How it is built

- `rust/` — the native library over `async-nats`, built as a `cdylib` and a
  `staticlib` with a C ABI.
- `lib/` — the Dart binding.

The boundary: one JSON string in, one JSON string out. Everything else follows
from that — enums cross the boundary **by name**, adding a field is not an ABI
change, and there is exactly one memory-freeing rule. More in
`doc/architecture.md` and `doc/durability.md`.

## Building the native side

The package is a **Flutter FFI plugin**: `flutter build` invokes cargo itself
and puts the library into the application on Windows, Linux and Android. The
mechanism, the three different routes to cargo, and the order to check things in
on a Mac are in [`doc/native-build.md`](doc/native-build.md). There is no
`hook/` directory here and there never will be: its mere presence breaks `dart
run`, `dart test` and `flutter build`.

By hand:

```bash
cd rust && cargo build --release
cd .. && dart test                     # 49 checks, 22 of them across the C ABI
dart test --tags live --run-skipped    # needs running nats-server instances
```

**Where the library actually arrives:**

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrives | `rk_nats.dll` next to the runner of the built application |
| Linux | arrives | `librk_nats.so` in the application's `bundle/lib/` |
| Android | arrives | found **inside the unpacked APK** for `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| macOS, iOS | **built and linked** | verified 2026-08-03 on Apple M4 / macOS 26.2 / Xcode 26.2: the archive builds for arm64 and x86_64 on macOS, arm64 on device and both on the simulator; a C probe links against it with `-force_load` in Release and Debug, and the macOS binaries run through the C ABI. Gated by CI from that day. |

## What has not been verified

Power loss. The package verifies the **setting** under which the server promises
to fsync before acknowledging, and the cost of that promise has been measured. A
real power cut on real hardware was not reproduced here — Jepsen did that part,
and their conclusion is the reason this package is shaped the way it is.

## Licence

MIT, by Rob Kim. See `LICENSE`.
