# The stale Zenoh ID after a session is recreated

This is the one failure the package is shaped around.

**The symptom, as reported from the field.** A till restarted, its session got a
new Zenoh ID, and a neighbour kept sending to the old one. The messages
**disappear silently**: the send returns success, there is no error, and there
is no delivery.

For us this is not an edge case. A till restarts on every update, crashes,
changes its binding. "Every time a session is opened" means every day.

## What was measured

The tests are in `rust/tests/stale_zid.rs`. Two nodes on one machine over TCP on
loopback, with multicast and gossip disabled so that what is measured is
reconnection and not neighbour discovery. To run them:

```
cd rust && cargo test --test stale_zid -- --nocapture --test-threads=1
```

The numbers below are Windows 11, debug build, three runs.

### 1. Unpinned ID: the failure reproduces

| What | Value |
| --- | --- |
| ID after recreation | **different**, every time |
| Sending to the old ID | **succeeds**, not one delivery in 3 s |
| Dead ID gone from the server's view | ≈ 51 ms |
| Till reachable again by its durable name | **195–337 ms** after the restart |

Three seconds of sending to the stale ID — well after the till had become
reachable by name — produced not one message and not one error. That is the
silent loss: the sender is confident everything is fine.

### 2. Pinned ID: routes survive the restart

| What | Value |
| --- | --- |
| ID after recreation | **the same** |
| Sending to the remembered ID | delivered |
| Till reachable again | **196–303 ms** after the restart |

**There is no difference in convergence time between the two approaches.**
196–303 ms against 195–337 ms is the same number: the cost of a restart is
re-establishing TCP and propagating declarations, not changing identity. Pinning
does not speed recovery up; all it does is spare the sender from having to
update an address.

### 3. Why pinning is **not enough**

Two tests about the same thing, in two orders.

**The duplicate arrives second.** A second session opens with the same pinned ID
without any obstacle — Zenoh does not stop you from creating it — but **it does
not get into the fabric**: the server rejects the second connection with that
ID. The real till keeps working.

**The duplicate arrives first.** The same failure in reverse: the impostor is
already connected, the till boots with its ordinary configuration and **does not
get into its own fabric at all**. No messages, no routes. Verified by
`whoever_claims_a_pinned_zid_first_keeps_it`.

Exactly one thing follows from this: **whoever claims the ID first keeps it**. A
pinned ID is a claim, not a credential. A machine that knows the till's name —
and that name is printed on the receipt — computes the same ID and cuts the till
off the network simply by booting earlier. Only a certificate can tell a restart
from an impostor.

That is why `RkzSession::open` **refuses** a pinned ID without TLS, and
`ZenohConfig.refusalReason` says the same thing before the isolate is even
started. The tests that measure the behaviour of the ID itself call
`open_unchecked`: on loopback there is nothing to authenticate.

## What to do about it

**Do not pin, by default.** The Zenoh ID stays an ephemeral handle and
addressing goes through a durable name in the key:

```
telepos/till/till-17/cmd          not  telepos/direct/<zid>/cmd
telepos/alive/till-17             the liveliness token, also by name
```

Convergence is a few hundred milliseconds and there is nothing for the sender to
update.

**Pin only together with mTLS**, and then a pinned ID stops being a claim: the
certificate has already established who this is, and the ID merely saves an
address update. The gain is small (see the table), so pinning is justified where
the address ended up in somebody else's configuration and updating it is
expensive.

**Never store somebody else's Zenoh ID as an address.**
`ZenohSession.peerZids()` is a snapshot of who is connected right now; it is not
a directory. The directory is `watchLiveliness` plus your own terminal names.

## What the measurement does not cover

- Everything is on loopback and in one process. A real network with loss,
  address changes and a Wi-Fi → cellular handover was not tested.
- The impostor was tested without TLS. What Zenoh does with a pinned ID **and**
  mutual TLS when the certificates differ was not measured; the expectation that
  the connection is rejected at the handshake remains an expectation.
- Debug build. Release numbers will be no worse, but they were not taken.
- One pair of nodes. Behaviour with a hundred tills all restarting at once after
  an update was not measured at all.
