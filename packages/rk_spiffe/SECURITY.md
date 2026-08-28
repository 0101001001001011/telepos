# Security

## Reporting a vulnerability

Not through a public issue. Use **Security → Report a vulnerability** in this
repository — that is GitHub's private channel.

A reply within a week. If the vulnerability is confirmed, the fix ships as a
version of its own, and the description is published after that version is
out, not before.

## What counts as a vulnerability here

Pure Dart: no `dart:io`, no `dart:ffi`, no native part, no dependency beyond
the SDK. Nothing here opens a socket, reads a file or reads a clock, so there
is no transport to intercept and no library to preload.

What there is, is a **parser that is fed by an attacker by design**. An
X.509-SVID or a JWT-SVID arrives from a party that has not been authenticated
yet — that is what the document is for — so every byte read here is hostile
input, and these count:

- **Accepting a document the rules reject.** A leaf with two URI subject
  alternative names, `CA:TRUE`, a `keyUsage` carrying `keyCertSign` or
  `cRLSign`, a JOSE header whose `alg` is `none` or absent, a claim set with no
  `exp` or an empty `aud`. Each of those is a rule some caller is relying on.
- **Accepting a near-miss name, or normalising one.** An uppercase trust
  domain, percent-encoding, a port, userinfo, a dot segment, an empty segment.
  If two spellings of one identity both parse, a reader somewhere downstream
  knows only one of them, and that difference becomes an authorization bug in
  somebody else's code.
- **Reading a field from the wrong place.** Taking the first subject
  alternative name rather than the only URI one, or the first extension rather
  than the matching one, is how a certificate says one thing and this package
  reports another.
- **Denial of service on malformed input.** Unbounded memory or superlinear
  time from a crafted DER length, a deeply nested structure or an oversized
  base64 segment. A parser that hangs on a hostile document is a vulnerability
  even when it never returns a wrong answer.

## What this package does not do

**It verifies nothing, and that is not a vulnerability.** No signature is
checked, no chain is walked, no trust bundle is consulted, and no clock is
read — `exp` is required to be present and to parse, not to be in the future;
whether a token has expired is answered against an instant the caller supplies.
Every entry point that reads a document is named `parseUnverified…` so that no
call site can be misread. A report that says signatures are not verified will
be closed as documented, so please do not spend a week on it.

A document that parses here is a claim somebody made, not a fact. Hand
`X509Svid.certificate.der` to whatever owns trust in your system — among this
author's packages that is `rk_pki`, the only one able to issue or to judge —
and hand `JwtSvid.signingInput` and `JwtSvid.signature` to whatever holds the
JWT bundle.

**It is not a Workload API client.** It talks to no agent and holds no socket,
so it cannot be the thing that leaks one.

**It writes no DER, generates no key and signs nothing.** The DER writer in the
test directory exists to build documents that must be rejected, and is never
used to make a positive claim.
