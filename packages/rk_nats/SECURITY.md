# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

You get a reply within a week. If the vulnerability is confirmed, the fix ships
as its own version and the write-up is published after that version, not before.

## What counts as a vulnerability here

The package talks to a NATS server over native code and carries the caller's
credentials there, so these qualify:

- **Bypassing verification of the server.** Accepting a certificate that does
  not chain to the roots supplied, or continuing in cleartext where TLS was
  asked for.
- **Credentials leaving by any route other than the connection.** A user and
  password, a bare token, the contents of a `.creds` file, and the
  system-account credentials used to fetch durability evidence all pass through
  this package. None of them belongs in a log line, an error message or a
  `toString`.
- **A durability claim the evidence does not support.** Under the default
  policy, publishing is refused until the library has proof that the server
  fsyncs before acknowledging. Any path that reaches "acknowledged" without
  that proof — a `varz` document accepted without being read, an evidence kind
  that quietly defaults to trusting — is a vulnerability and not merely a bug:
  it is the difference between a message that survives a power cut and one of
  the 131,418 that did not.
- **Reading or writing outside a buffer** on the native side, memory
  corruption, double free, and a handle number that is honoured after it was
  closed.
- **Loading the library from a path an outsider can control.**
  `RK_NATS_LIBRARY` is trusted input; an application that takes it from an
  untrusted source is handing an outsider code execution inside its own
  process.

## What this package does not do

**It does not decide whom to trust.** Roots, accounts and the permissions on a
subject are set by whoever runs the server. All the package owes you is not to
weaken what it was handed.

**It does not store credentials.** They are held for the connection and remain
the caller's to keep or to shred.

**It does not fetch the durability evidence for you.** The `varz` document is
fetched on the Dart side on purpose: it keeps an HTTP stack out of the native
library, and it keeps the evidence something a human can print and attach to a
ticket.

**It is not a substitute for the server's own settings.** A two-minute
`sync_interval` is the server's default and stays the server's. All this
package can do is refuse to pretend otherwise.
