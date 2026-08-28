# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

You get a reply within a week. If the vulnerability is confirmed, the fix ships
as its own version and the write-up is published after that version, not before.

## What counts as a vulnerability here

The package joins a Zenoh fabric over native code — finding neighbours by
multicast on the local segment and spreading what it learns by gossip once an
entry point is known — so these qualify:

- **Bypassing verification of a peer.** Accepting a certificate that does not
  chain to the roots supplied, or opening a link in cleartext where TLS was
  required.
- **Reaching a pinned identity without TLS.** `pinnedTo` and `derivedFrom` are
  refused without a certificate, and the refusal is not a formality: whoever
  claims a pinned Zenoh ID first keeps it — measured — so on an open network
  any machine can cut a till out of the fabric by booting earlier. Any path
  that lets a pinned identity be used unauthenticated is a vulnerability.
- **A publication delivered to a subscriber whose key expression does not
  match**, or a subscription that matches more than it declared. Key
  expressions are the only thing separating one till's traffic from another's.
- **Reading or writing outside a buffer** on the native side, memory
  corruption, double free, and a use-after-free from getting the
  owned/loaned/moved convention wrong on our side of the boundary.
- **Loading the library from a path an outsider can control.**
  `RK_ZENOH_LIBRARY` is trusted input; an application that takes it from an
  untrusted source is handing an outsider code execution inside its own
  process.

## What this package does not do

**It does not decide whom to trust.** Roots and certificates are set by whoever
runs the installation. Scouting will find every peer on the segment; which of
them may speak is a configuration question and not one this package answers.

**It stores nothing.** The fabric carries what is happening now. A subscriber
that was not listening missed nothing — as far as it is concerned the message
never existed — so there is no store here to read out of and none to fill up.
Durable state belongs in a database that replicates.

**It does not traverse NAT.** The addresses it is handed have to be routable.
Exposing a Zenoh endpoint to the internet to work around that is a deployment
decision whose consequences this package cannot contain.
