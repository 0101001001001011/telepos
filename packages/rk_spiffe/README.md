# rk_spiffe

SPIFFE identity documents and names, in pure Dart.

```dart
final id = SpiffeId.parse('spiffe://shop-42.telepos/till/17/terminal/3');
final svid = X509Svid.parseUnverifiedPem(pem);
final jwt = JwtSvid.parseUnverified(token);
```

SPIFFE is three separate things wearing one name:

1. a **name format**, `spiffe://<trust-domain>/<path>`;
2. two **document formats**, X.509-SVID and JWT-SVID;
3. the **Workload API**, a gRPC service on a Unix socket by which a process
   asks the agent running beside it who it is.

This package is the first two, completely. It is not the third, and that is a
decision rather than a to-do — see below.

## What it does

**Names.** `SpiffeId` and `TrustDomain` parse and validate against the
grammar, and refuse every near-miss instead of normalising it: uppercase trust
domains, percent-encoding, ports, userinfo, dot segments, empty segments,
queries, fragments and anything over the length limits. Normalising would mean
two spellings of one identity exist, and some reader somewhere will know only
one of them.

**X.509-SVID.** `ParsedCertificate` reads a certificate from DER or PEM with a
strict DER reader — definite lengths in their shortest form, no high tag
numbers, booleans that are `0x00` or `0xFF`, one instance of each extension —
and exposes the serial, the validity window, the issuer and subject names as
DER, every extension, `basicConstraints`, `keyUsage` by name, and the URI, DNS
and IP subject alternative names. `X509Svid` then applies the leaf rules:
exactly one URI SAN, a well-formed SPIFFE ID with a path, `CA:FALSE`, and a
`keyUsage` that includes `digitalSignature` and neither `keyCertSign` nor
`cRLSign`.

**JWT-SVID.** `JwtSvid` reads the JOSE header and the claim set and checks the
rules the document puts on them: an `alg` that is present and is not `none`, a
`typ` of `JWT` or `JOSE` or nothing, a `sub` that is a SPIFFE ID, a non-empty
`aud`, an `exp`. It hands back the claims whole, plus the signing input and
the signature bytes.

Failures are values, not exceptions: every entry point returns a
`SpiffeResult`, and every failure carries the **name** of the exact clause it
broke — `SpiffeIdRule.trustDomainCharacters`, `X509SvidRule.uriSanNotUnique`,
`JwtSvidRule.algorithmNone` — rather than a number that changes meaning when a
case is inserted.

## What it does not do, deliberately

**It verifies nothing.** No signature is checked, no chain is walked, no trust
bundle is consulted. Every entry point that reads a document is called
`parseUnverified…` so that no call site can be misread. A document that parses
here is a claim somebody made, not a fact.

That is a boundary, not a gap. Verifying an X.509 chain is answering *why
should anyone believe this machine*, and among this author's packages that
question already has an owner: `rk_pki`, which holds the certificate
authority, the key store and `rustls-webpki` behind an FFI boundary. A second
verifier written in Dart would be a second answer to one question, and two
answers is the failure, not the feature. Take `X509Svid.certificate.der` and
hand it to whatever owns trust in your system; take `JwtSvid.signingInput` and
`JwtSvid.signature` and hand those to whatever holds the JWT bundle.

**It is not a Workload API client.** Such a client is a *consumer* of an agent
that must already be running on the machine, so adding one obliges a SPIRE
agent on every host and a server whose absence stops certificate renewal
within a day. That is a deployment decision with real operational weight, and
a library cannot take it on anyone's behalf. If you run SPIRE and want the
Workload API in Dart, this package will read the documents that come out of
it — which is the part that is the same whether or not you run SPIRE.

**It is not a certificate builder.** Nothing here writes DER, generates a key
or signs anything.

## Shape

Pure Dart, no native part, no plugin, no `dart:io`, no `dart:ffi`, no
dependencies beyond the SDK. It runs on a server, on a phone and in a browser
alike, and there is nothing to compile for a platform.

The reason there is no native part is worth stating, since the rest of this
author's `rk_*` packages have one: a native part is justified by a capability
Dart lacks or by code shared with another language, and parsing a grammar is
neither. Rust here would be symmetry, and symmetry is not a reason.

## Testing

The certificates the tests read are real ones from OpenSSL, frozen into
`test/fixtures/certificates.dart`, and they are shaped so that a plausible bug
cannot pass: in the good leaf the `subjectAltName` is the fifth of six
extensions and the URI name is the third of four subject alternative names, so
"take the first" and "take the last" both fail at both levels. One fixture's
validity runs past 2049 so that `GeneralizedTime` is exercised as well as
`UTCTime`. Encodings OpenSSL will not produce on purpose — an extension
written twice, `critical` written as `FALSE`, an indefinite length, a length
padded with a zero — are built by a small DER writer that exists only in the
test directory and is never used to make a positive claim.

## Licence

MIT, Rob Kim. See `LICENSE`.
