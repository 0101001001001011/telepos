# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

An answer within a week. If the report is confirmed, the fix ships as its own
release, and the description is published after that release rather than
before.

## What counts as a vulnerability here

The package accepts application data, writes it to disk and sends it over the
network, loading native code to do so. These count:

- **Bypassing verification of the other side.** Accepting a certificate that
  does not match the pinned fingerprint, or does not chain to the roots that
  were supplied.
- **Log injection.** Any way to make one record look like two to the receiver,
  or to forge the priority of the second. This is why control characters in
  structured-data parameters are rejected, and why the framing counts octets
  instead of looking for a newline.
- **Reading or writing outside a buffer** in the native part, memory
  corruption, double free.
- **Loading the library from a path an outsider can control.**
  `RK_SYSLOG_LIB` is trusted input; an application that takes it from an
  untrusted source is handing an outsider code execution inside its own
  process.
- **Escaping the spool bound**, that is, any way to make it grow without limit
  on a machine that takes money.

## What this package does not do

**It does not mask secrets.** The package does not know that a string is a PIN,
a card number or a token, and it does not guess. Whatever went into a record
goes into the log. What must not go in is decided at the call site, and that is
a boundary rather than an implementation gap: the sink sees neither classes,
nor fields, nor what they mean.

It does not decide whom to trust. Roots and fingerprints are set by whoever
runs the system.

It does not verify the integrity of a chain of audit records. Linking records
by fingerprint (architecture section 15) is the job of the audit log's owner,
not of its transport.

## What the package does do for security

- **Closed by default:** `collector_scheme` is `none`; a fresh installation
  opens nothing outward.
- **No built-in root store.** Silently trusting the public certificate
  authorities while talking to an internal collector would mean trusting the
  wrong set of issuers.
- **Panics at the FFI boundary are caught** and returned as a value: a logging
  failure must not take down a process that is taking money.
- **The spool is bounded**, and losing a record is always accompanied by a
  counter and by a record in the log itself.
