# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

A reply within a week. If the vulnerability is confirmed, the fix ships as a
version of its own, and the description is published after that version is
out, not before.

## The shape of the exposure, stated plainly

This package opens a UDP socket on port 5353 and **reads whatever the local
segment sends it**. There is no handshake, no authentication and no session:
anything on the link can put a datagram in front of the parser, and mDNS is
designed that way. That is the threat model, and everything below follows from
it.

It also *publishes*: the service name, the host name, the port and the `TXT`
record go out unencrypted to every device on the link, repeatedly. Nothing here
is confidential and nothing here should be made to carry something that is.

## What counts as a vulnerability

- **Any crash, hang or unbounded allocation reachable from a datagram.** A
  compression pointer that loops, a header claiming 65535 records with nothing
  behind it, a name longer than 255 octets, a `TXT` clipped mid-string. The
  parser is total by design, and any input that makes it panic, spin or grow
  without bound is a bug of the first rank — the sender does not have to be
  authorised to be anything.
- **Reading or writing outside a buffer** in the native part, memory
  corruption, or a double free.
- **A panic crossing the FFI boundary.** Every entry point catches; one that
  does not is undefined behaviour in the caller's process.
- **Answering for a name this host has not claimed.** A responder that replies
  to other people's questions can redirect a connection meant for another
  machine, which is the strongest attack this protocol has.
- **Claiming a name without probing, or ignoring a conflict.** The probe is
  what stops two hosts answering one name; skipping it turns a naming mistake
  into a silent redirection.
- **Loading the library from a path an outsider can control.**

## What does not count

- **Anybody on the link can see what is announced.** That is what announcing
  is. Put nothing in the `TXT` record that would matter to a stranger; a
  certificate fingerprint is fine, a token is not.
- **Anybody on the link can announce the same service.** mDNS has no
  authority. This package makes the collision *visible* — the conflict is
  reported and the name moves — and it cannot make the collision impossible.
  Deciding that the host you found is the host you meant is TLS's job, and it
  is the reason a fingerprint belongs in the `TXT` record.
- **A network that filters multicast makes the service unfindable.** Many guest
  networks do. It is a fact about the network; the answer is an address typed
  by hand, and it is why `resolveHost` reports "asked, nobody replied" as a
  value rather than as an error.
- **Announcing an address the operator configured.** `addresses` is taken as
  given.

## Where the trust boundary is

Inside `rust/src/`: `message.rs`, `name.rs` and `record.rs` parse hostile
input, and they are written to be total — every error is a returned value, and
the fuzz-shaped test at the bottom of `message.rs` exists to keep it that way.
Everything above them acts only on names this host owns.

The Dart side never parses a datagram. It reads JSON that this library wrote.
