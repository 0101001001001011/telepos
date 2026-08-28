# What "acknowledged" means

This document answers one question: if JetStream replied with an
acknowledgement, where is the message now. The answer depends on three settings,
two of which belong to the server, and none of which belongs to the caller.

## Measured, not paraphrased

Everything below was obtained on 2026-07-31 against live servers. The `varz`
documents are in `rust/fixtures/` and are used by the tests — those very files,
not hand-rewritten likenesses of them.

### What the server says about itself

| Server | `sync_interval` | `sync_always` |
| --- | --- | --- |
| 2.11.0, default | 120,000,000,000 ns | field absent |
| 2.14.4, default | 120,000,000,000 ns | field absent |
| 2.14.4, `sync_interval: "always"` | 120,000,000,000 ns | `true` |

**The third row is the trap.** Turning on fsync-per-write does not change
`sync_interval`. A probe that reads that field and concludes "two minutes,
unsafe" will be wrong on exactly the servers that are safe. `sync_always` is
what settles it; `sync_interval` bounds the loss only when `sync_always` is
false.

### What it costs

One machine, loopback, one replica, 500 sequential publishes each awaiting its
acknowledgement:

| Server setting | Stream `persist_mode` | msg/s | ms per message |
| --- | --- | --- | --- |
| default | `default` | 2,902 | 0.345 |
| default | `async` | 4,137 | 0.242 |
| `sync_interval: always` | `default` | **158** | **6.347** |
| `sync_interval: always` | `async` | 4,198 | 0.238 |

Two things can be read out of this table.

First: the safe setting costs **roughly 18 times** more. That is the price, and
it is a thing to know rather than to discover. For a sale on a till, 6.3 ms
means nothing: the customer is waiting for the receipt to print, not for the
disk.

Second, and this matters more: **`async` on an fsyncing server runs at the speed
of a server that does not fsync.** It does not wait for the disk. And its
acknowledgement is indistinguishable from one that did wait — same reply, same
sequence field, same absence of an error. This is "acknowledged that does not
mean written", in its purest form.

## The ladder of meanings

The package answers the question with one of five values
(`RkNatsAckMeaning`):

| Value | When | What it survives |
| --- | --- | --- |
| `fsyncedToDisk` | file stream, `sync_always`, `default` mode | power loss |
| `writtenNotFsynced` | file stream, no `sync_always` | a process crash, but not a power cut |
| `ackedBeforeStore` | stream mode `async` | nothing in particular |
| `memoryOnly` | memory as the storage | a server restart |
| `unknown` | the server was not asked, or the answer was not read | unknown |

The order of the checks is part of the meaning. A stream that acknowledges
before storing says nothing about disks no matter how the server is configured,
so that check comes before the `sync_always` check: you cannot get safety back
by fixing only the server.

`unknown` satisfies nothing except the policy that promises nothing. Absence of
proof is a refusal, not a permission.

## How proof is obtained

`varz` is not part of the NATS protocol, so the route has to be named
explicitly.

**`RkNatsVarzEvidence`** — the caller fetches the document itself (usually from
the monitoring port) and passes it in. This keeps an HTTP stack out of the
native library, and leaves the proof as something a person can print and attach
to a ticket.

**`RkNatsSystemAccountEvidence`** — the library asks the server itself, with a
`$SYS.REQ.SERVER.PING.VARZ` request from an account that can see `$SYS`. This is
the route for installations where the monitoring port is closed — and on an
appliance it ought to be closed.

Both forms yield the same object under `jetstream.config`, so they share one
parser. Both routes have been verified live.

**`RkNatsNoEvidence`** — legitimate, and it means `unknown`. There is no fourth
form meaning "assume it is fine", and its absence is a decision.

## Three replicas do not replace fsync

In 2.12.1 Jepsen found not only loss of acknowledged data on power failure, but
also file corruption propagating through Raft, and split brain after **one**
node failed with three replicas.

Hence the rule: `replicas: 3` protects you from a machine dying and does not
protect you from all three machines having acknowledged what none of them wrote.
The package does not let one stand in for the other — the replica count plays no
part in computing the meaning of an acknowledgement at all.

## What the package has not verified

**Real power loss.** What has been verified is that the server is configured the
way it promises, and what has been measured is what that promise costs. A
power-cut experiment on live hardware was not run here. Jepsen ran it, and their
result is the reason everything is arranged this way.
