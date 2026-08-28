# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

An answer within a week. If the report is confirmed, the fix ships as its own
release, and the description is published after that release rather than
before.

## What counts as a vulnerability here

The package talks to the network and loads native code, so these count:
bypassing certificate verification, accepting data from an unauthenticated
party as trusted, reading or writing outside a buffer in the native part, and
loading the library from a path an outsider can control.

Two more are specific to what this package holds:

- **Private key material leaving the native library** in any encoding, by any
  call, in any answer.
- **A signing request deciding its own terms** — anything that lets the
  requester choose its subject, its alternative names, or `is_ca`, rather than
  the authority choosing them.

## What this package does not do

It does not decide *policy*. Which machines an installation should admit, who
may mint an invite, and when a certificate should be revoked are decisions for
the caller; this package issues, stores and judges according to what it is
told.

It is not a TLS stack. It issues and judges the certificates a QUIC transport
presents, and runs no session of its own, so anything about a live handshake
belongs to that transport and not here.

It is not a key holder of last resort. Keys are files on disk — 0600 on Unix,
the store directory's ACL on Windows. CNG/DPAPI, Keychain and TPM 2.0 are not
integrated, and this document does not pretend they are.
