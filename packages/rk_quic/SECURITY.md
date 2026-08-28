# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

A reply within a week. If the vulnerability is confirmed, the fix ships as a
version of its own, and the description is published after that version is
out, not before.

## What counts as a vulnerability here

The package is a **server**. It terminates QUIC and WebTransport from browser
clients over native code, and it holds a private key in the process while it
does. So these count:

- **A session accepted without a sound TLS 1.3 handshake**, or any path that
  weakens the handshake the transport performs.
- **Private key material leaving the process** in any encoding, by any call, in
  any log line or error message. The chain and the key are handed in as PEM and
  must go no further.
- **Treating data from an unauthenticated session as trusted.** A browser that
  completed a handshake has proved that it reached the right server and nothing
  else; who it is remains the application's question.
- **Reading or writing outside a buffer** in the native part, memory
  corruption, double free, and any way to make the server allocate without
  bound — streams, sessions or datagrams — from an address that has not been
  validated.
- **Loading the library from a path an outsider can control.**
  `RK_QUIC_LIBRARY` is trusted input; an application that takes it from an
  untrusted source is handing an outsider code execution inside its own
  process.

## What this package does not do

**It does not issue certificates and it does not decide whom to admit.** The
chain and the key are issued elsewhere — among this author's packages by
`rk_pki`, which is the only one able to sign, because two packages able to sign
would be an installation with two certificate authorities nobody chose between.
Expiry, revocation and renewal belong to whoever issued them.

**It is not an authorization layer.** There is no notion of a user here. A
session identifier names a connection, not a principal.

**It is not a general HTTP/3 stack.** It serves WebTransport sessions; request
semantics belong above it.
