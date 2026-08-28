# How rk_mdns is put together, and why

## The one-line answer

Rust behind a C ABI, reached from Dart through `dart:ffi`, because the thing
this package exists for — choosing which interface a multicast datagram leaves
by — cannot be said in Dart at all.

## Why not Dart

The responder in this package began as 672 lines of Dart in a point-of-sale
application, and it worked. What it could not do is the list below, and each
entry is the reason a line of Rust exists.

| Wanted | In Dart |
| --- | --- |
| `IP_MULTICAST_IF` — which interface a datagram leaves by | `RawDatagramSocket` has no direct way to set it; the workaround is one socket per address, and the option still has to be set through `setRawOption` with hand-written constants that differ per platform |
| `ff02::fb` over IPv6 | needs a scope id, which `InternetAddress` has no way to carry |
| Answering out of the interface a question arrived on | needs `IP_PKTINFO`, or one socket per interface with per-interface membership — neither is reachable |
| RFC 6762 §6 and §8.1 timing | probe windows are 250 ms; Dart timers jitter more than a conflict resolution can absorb |
| `SO_REUSEPORT` | not exposed at all, and on Linux and Apple `SO_REUSEADDR` alone will not share a wildcard bind |

## Why not a ready-made crate

The rule was set before looking: a crate is usable **only** if it lets the
caller choose the sending interface, because that is the property the package
exists for. The ones on offer either hide the socket entirely or reach the same
routing-table default this package was written to avoid. So RFC 6762 and
RFC 6763 are implemented directly; the Dart version had already shown the scope
is bounded.

Two dependencies remain, and both are for things `std` does not have:

- `socket2` — the socket options themselves.
- `if-addrs` — the interface list with indices.

## The layers

```
Dart  lib/rk_mdns.dart          the surface
      lib/src/*_io.dart         the native half        ─┐ conditional
      lib/src/*_web.dart        the browser half       ─┘ import (И143)
      lib/src/worker_io.dart    two isolates per object (И145)
      lib/src/bindings_io.dart  the FFI signatures
──────────────────────────────────────────────────────────────────
C     src/rk_mdns.h             the authoritative ABI
──────────────────────────────────────────────────────────────────
Rust  rust/src/api.rs           one entry point per thing a caller does
      rust/src/ffi.rs           the ownership rules and the panic wall
      rust/src/responder.rs     probe → claim → announce → answer → goodbye
      rust/src/browser.rs       ask → cache → report arrivals and departures
      rust/src/records.rs       the record set, pure
      rust/src/cache.rs         lifetimes, pure
      rust/src/socket.rs        one socket per interface
      rust/src/interfaces.rs    which interfaces, and the measurement
      rust/src/message.rs       header and sections, total parsing
      rust/src/record.rs        the five record types
      rust/src/name.rs          names, compression pointers, case
```

The bottom four modules are pure — bytes and clocks in, values out, no socket.
That is where most of the tests are, and it is why the responder's behaviour
can be checked byte for byte rather than only observed.

## The three rules at the boundary

**A failure is a returned value (И144).** Every `extern "C"` body runs inside
`catch_unwind`; a panic in Rust becomes the status `panic`. `panic = "abort"`
is therefore forbidden in the release profile — it would make the promise
false.

**An enumeration crosses by name (И147).** A status leaves as
`"portInUse"`, never as an integer. A name the caller does not know reads as
unknown rather than as the wrong branch, and inserting a variant in the middle
of the Rust enum cannot silently re-label anything.

**Freeing is one-sided (И146).** Every pointer out is either into `static`
storage or a buffer the caller returns through `rk_mdns_string_free`. Dart
never calls `free()` on memory that crossed the boundary, and Rust never frees
a pointer Dart owns.

## The handle is a name

A handle is a `u64` counter looked up in a table, never a pointer cast to an
integer. A stale handle is therefore `unknownHandle` — a status the caller
reads — instead of a use-after-free that crashes an hour later somewhere else.
The counter never repeats inside a process.

## Threads and isolates

The native side gives each responder and each browser a thread, because both
spend their lives inside `recv`. The Dart side gives each one **two isolates**:
one that spends its life inside the blocking poll, and one for the short calls.
One isolate would mean every `stop` queues behind the current wait — and on a
responder that is not merely a stall, because `stop` is what sends the goodbye.

## What is decided by the caller, and why

**Which interfaces to announce on.** The cost of a spare address is not
symmetric: in a certificate an `iPAddress` entry is checked and a spare one
costs nothing, while in an announcement an address is *tried* and a spare one
costs the client a connection timeout. A rule over the address cannot separate
a Hyper-V switch from a shop's own `172.16/12` network — only the interface
name can — so `ServiceAnnouncement.interfaces` exists and this package does not
guess. `mdnsInterfaces()` reports name, address, netmask and prefix so the
caller has something to decide with.

**Which addresses to announce.** Same argument; `addresses` overrides the
derived list entirely.

What is **not** decided by the caller: whether to send on every selected
interface. There is no option for that and no fallback path, for the reason in
`interfaces.rs`.
