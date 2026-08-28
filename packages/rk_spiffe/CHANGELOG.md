## 0.1.0

The first working version. The package has stopped being a claimed name and
become a library of SPIFFE identity names and documents.

**Breaking.** `hasWorkloadApi` is gone: there will be no Workload API client in
this package, so a probe answering "no" was misleading by the very fact of
existing. Under pub's rules for versions below 1.0 a minor bump *is* a breaking
bump — a `^0.0.1` dependency will not take 0.1.0.

**The package description is corrected.** The old one promised "X.509 and JWT
SVIDs, and a client for the Workload API that fetches and renews them"; that is
the line visible in pub.dev search, and it was untrue.

What has arrived:

- `SpiffeId` and `TrustDomain` — parsing and validation of `spiffe://` against
  the grammar. Everything in the neighbourhood is refused: uppercase in the
  trust domain, percent-encoding, a port, userinfo, empty segments, `.` and
  `..`, a query and a fragment, and anything over 255 and 2048 bytes.
- `ParsedCertificate` — reading X.509 from DER or PEM with a strict DER reader:
  serial number, validity window, issuer and subject names as DER, every
  extension, `basicConstraints`, `keyUsage` by name, and the URI, DNS and IP
  names.
- `X509Svid` — the leaf X.509-SVID rules: exactly one URI name, a parsed SPIFFE
  ID with a path, `CA:FALSE`, and a `keyUsage` with `digitalSignature` and
  without `keyCertSign`/`cRLSign`.
- `JwtSvid` — reading a JWT-SVID: `alg` present and not `none`, `typ` one of
  `JWT`/`JOSE` or absent, `sub` a SPIFFE ID, a non-empty `aud`, a mandatory
  `exp`. The signing input and the signature bytes are handed out.
- `SpiffeResult` — a failure is returned as a value, and every failure carries
  the **name** of the rule it broke, not a number.

What the package does not do and will not do: it does not verify signatures,
chains or trust bundles (that is the answer to "why should this machine be
believed", and that question already has an owner — `rk_pki`); it is not a
Workload API client; and it neither builds nor signs certificates. The entry
points are named `parseUnverified…` so that this is visible at the call site
rather than only in the documentation.

The package is pure Dart: no native part, no `dart:io`, no `dart:ffi`, and no
dependencies beyond the SDK.

## 0.0.1

- Name claimed. No content yet: the package proves the publishing pipeline,
  it does not solve the problem.
- Recorded so that nobody waits for the wrong thing: the package would be a
  consumer of the Workload API rather than a source of identity, and its fate
  depends on the decision about `rk_pki` — see
  `docs/superpowers/specs/2026-08-01-rk_spiffe-design.md`.
