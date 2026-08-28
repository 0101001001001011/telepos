# The stable subset: what is in and what is not

The `rust/` crate depends on `zenoh 1.9.0` **without the `unstable` feature**.
That is a decision, not a default, and it has a price — named here in full so
that nobody discovers it on a till.

## How this was checked

`unstable` is an optional crate feature (`cargo info zenoh@1.9.0`), and this
package's `Cargo.toml` does not enable it. In the sources of `zenoh 1.9.0`,
**142 declarations** are marked `#[zenoh_macros::unstable]`, 14 of them right in
`src/lib.rs` — that is, in the list of public modules itself.

This is checked by building, not by reading: using a gated name does not
compile, and the compiler says outright that the item "is gated behind the
`unstable` feature". That is exactly how the absence of `Reliability` came to
light.

## What is in

| Capability | State |
| --- | --- |
| Opening a session, `peer` / `client` / `router` modes | present |
| Pinning the Zenoh ID through configuration | present |
| `put` and `delete` by key expression | present |
| A declared publisher with congestion control and priority | present |
| Subscription with a queue and receive-with-timeout | present |
| Liveliness: declaring a token and subscribing to changes | **present** |
| The list of reachable Zenoh IDs (`peers_zid`, `routers_zid`) | present |
| TLS and QUIC as transports | present |
| `ZenohId` and parsing it | present |

Liveliness turned out to be in the stable part — worth checking separately,
because in 0.x it was gated, and all addressing by durable name rests on it.

## What is not, and what that means in practice

### Advanced Pub/Sub, entirely

The publisher cache, history for a late subscriber, gap detection and recovery.
This is precisely what people usually build "works offline" out of.

**Consequence.** A subscriber that was not there when a message was sent will
not get it and will not learn that anything happened. Durability has to be
provided where it belongs: in a database that replicates. This fabric carries
what is happening **now** — commands, state, presence — and does not pretend to
be a queue.

If a queue with delivery guarantees is needed, that is `rk_nats` and JetStream,
not `unstable` quietly switched on.

### Liveliness history

`.history(true)` on a liveliness subscription is behind the same feature.

**Consequence.** Whoever connects later **will not see tokens that were already
declared** — only subsequent changes. A latecomer has to ask, not listen. Hence
the warning in the documentation of `watchLiveliness`.

### Per-message reliability

`zenoh::qos::Reliability` is gated. What remains is congestion control (`drop` /
`block`) and priority — enough to keep a receipt from being lost behind
telemetry, but you cannot choose "best effort" for an individual message.

### Entity identifiers

`EntityGlobalId` and `EntityId` are gated. Zenoh gives you no way to tell two
declarations from the same node apart; if that is ever needed, the distinction
has to be carried in the key expression.

## Why not `unstable`

The feature is called unstable upstream and it means exactly that: names and
behaviour may change in a minor release. This package is published and promises
semantic versioning; building that promise on something that makes no promises
of its own is a way to ship a major release because of somebody else's
refactoring.

When Advanced Pub/Sub becomes stable, it will arrive in a minor version and add
capability without breaking anything. That is the upside of the refusal.

## Why not `zenoh-c`

An official C API exists (`zenoh-c`, 1.9.0, roughly 8300 lines of header, on the
order of 883 functions, 126 type definitions) and is perfectly serviceable for a
bindings generator. We **do not use it** and do not vendor it. Instead the
`rust/` crate depends on `zenoh` directly and presents a narrow C ABI of **its
own**.

The reasons, in order of importance:

1. **Failure comes back as a returned value.** You can only catch a panic at
   your own boundary. Through `zenoh-c` the boundary is somebody else's, and
   what happens on a panic inside it is not our decision.
2. **Enums cross by name.** In `zenoh-c` enums are integers. Our own boundary
   lets us pass names, and inserting a case in the middle of a list then changes
   the meaning of nothing.
3. **Freeing is deterministic.** The owned/loaned/moved convention across
   126 types would have to be reproduced in Dart by hand. One rule over six
   kinds of handle can be checked by eye; a hundred and twenty-six cannot.
4. **Size.** Of 883 functions we need about thirty. The rest is compatibility
   surface we would have to maintain and get nothing from.
5. **Building.** `zenoh-c` requires CMake. A Rust crate needs only `cargo`.

The price of the decision, stated honestly: we own our ABI, and updating `zenoh`
may require edits in `rust/`. Those are edits across thirty functions that have
tests, rather than across eight hundred that do not.
