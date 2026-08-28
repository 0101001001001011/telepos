# rk_spiffe — what this package is, and why it is this and nothing else

## The decision

The package is a **library of SPIFFE identity names and documents**, and nothing
more. Parsing and validating `spiffe://`, reading X.509-SVID and JWT-SVID. Not a
Workload API client, not a chain verifier, not a certificate issuer.

The fork in the road was named in
`docs/superpowers/specs/2026-08-01-rk_spiffe-design.md`, as three options, and in
the SPIFFE section of `docs/superpowers/2026-08-01-gap-audit.md`. What was
chosen here is not the third of them in the form recorded there, and it is worth
saying why.

**Why not a Workload API client.** It is a consumer of an agent already running
on the machine. Taking it on means committing to a SPIRE daemon on every till
and to a server without which certificate renewal stops within a day. The owner
said it plainly: in this project that will most likely not be needed. A library
is not entitled to make that decision on behalf of whoever depends on it.

**Why a package after all, rather than a file in `lib/domain/`.** The
specification wrote: if you take only the name format, no `rk_*` package is
needed — that is a file inside the application. The argument holds exactly for
the name format. **Three** things are taken here, and two of them — the strict
DER reader and the leaf SVID rules — are not "a string with a grammar": they are
code that anyone talking to SPIRE needs in the same way, and that does not exist
in Dart. Usefulness outside TelePOS is the only ground on which this package
exists, and it is written down here so that it can be argued with.

**Why signature and chain verification are not here.** A certificate has one
representation across the `rk_*` packages, and only `rk_pki` can issue
certificates. Chain verification is the answer to "why should this machine be
believed", and within this set of packages that question already has an owner:
`rk_pki`, with `rustls-webpki` behind an FFI boundary. A second verifier written
in Dart is a second answer to one question — precisely the parallel
implementation this project forbids, and the one the design note warned about
("SPIFFE overlaps `rk_pki` not at the edge but through the middle"). So
`X509Svid.certificate.der` is handed out here, and judging it is not our job.

From which follows what is **not here as a stub**: not one entry point that
would be called "verify" and return `NotImplemented`. The declared surface is
implemented in full; not verifying signatures is a boundary of the contract, not
a hole in it, and a stub in that place would create the impression that a second
verifier is coming one day.

## The rules the native packages hold to, and this one's answer

- **The package is not imported from `lib/presentation/`.** That is an
  application rule, and this package does not get in its way: it is pure Dart
  and builds for web.
- **A failure is returned as a value.** Here that is not about a native
  stack but about the same rule one level up: every entry point returns a
  `SpiffeResult`, and no exception escapes. `DerException` lives inside
  `lib/src/der.dart` and is caught at the certificate-parsing boundary.
- **Nothing native runs on the interface isolate.** There are no calls into a
  native part, so there are no calls on the interface isolate either. Parsing a
  certificate is microseconds and no I/O.
- **Deterministic freeing, enumerations across FFI, one native build
  mechanism** — **empty here, and that is a decision rather than an
  omission.** There is no native part, so there is nothing to free
  deterministically, no enumeration crosses an FFI boundary, and the
  `flutter.plugin.platforms` block is unnecessary: the one build mechanism is
  required only of packages with a native part. Rust will not be added for
  symmetry with the other eight packages — adding a native part for capability
  requires the justification "Dart does not have this", and Dart does have
  grammar parsing.
- **Names instead of numbers, in spirit** — they are kept even without FFI: the
  reason for a refusal is a `SpiffeIdRule`, `X509SvidRule` or `JwtSvidRule`, and
  they are printed via `.name`. Inserting a new value into the middle of an
  enumeration breaks nothing.

## How strict the DER reader is

DER admits exactly one representation of each value. The reader refuses
everything else rather than guessing:

| What | Why a refusal instead of tolerance |
| --- | --- |
| indefinite length (`0x80`) | that is BER; a parser that accepts it is reading the wrong end |
| a length with a leading zero | two spellings of one length |
| the long form where the short form suffices | the same again |
| a high tag number (`0x1f`) | no such tag exists in X.509 |
| a BOOLEAN that is neither `0x00` nor `0xFF` | "true" in three spellings |
| `critical` written as FALSE | that is the default value, and DER requires it to be omitted |
| one extension twice | a certificate saying two things at once |
| `subjectAltName` with no names | an empty assertion in place of an assertion |
| bytes after the certificate | the signature covers something other than what was read |

One caveat to know in advance: some certificate authorities write `critical
FALSE` explicitly, against DER. This package will reject such a certificate.
`rustls-webpki` makes the same choice, and it is deliberate: the package exists
in order to refuse ambiguity.

## The fixtures, and how they were chosen

The trap this project has fallen into six times is a fixture on which the broken
implementation and the fixed one give the same answer. Hence:

- in the good leaf, `subjectAltName` is the **fifth** extension of six, and the
  URI is the **third** name of four (DNS, IP, URI, DNS). "Take the first" and
  "take the last" both fail at both levels;
- the serial number is 64-bit (`0x0A1B2C3D4E5F6071`), so truncation to an `int`
  is noticeable;
- `notBefore` and `notAfter` differ and are each checked separately, not through
  the difference between them;
- one certificate is valid until 2056, so its times are `GeneralizedTime` rather
  than `UTCTime` — a branch nobody would otherwise execute;
- the "this is a certificate authority" rule and the "the name has no path" rule
  have **different** fixtures: a CA certificate violates both at once, so the
  second rule is checked against a leaf with `CA:FALSE` and `digitalSignature`
  that violates only it.

The keys the fixtures were signed with were thrown away along with the temporary
directory. Not one of these certificates is anybody's identity.

The command that generated them (OpenSSL 3.2.1) is an ordinary `openssl
req`/`x509` with an `-addext`-style `extfile`; there is no need to repeat it,
the files are frozen. If another fixture is ever needed, only one thing matters:
it must violate **exactly one** rule, otherwise the test proves something other
than what its name says.

## What is not in this package

- a Workload API client, or a dependency on gRPC;
- verification of a signature, a chain or a trust bundle;
- building or signing certificates, or generating keys;
- JWKS parsing;
- parsing a distinguished name into a string — names are handed out as DER,
  because comparing the printed form of two different names will one day declare
  them the same.
