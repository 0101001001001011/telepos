# rk_pki

Machine identity, mutual TLS and a per-installation certificate authority for
Dart, over a native library built on `rustls-webpki`, `rcgen` and `aws-lc-rs`.

A machine proves which machine it is with an X.509 certificate signed by the
installation's own authority. Two machines that each hold one can raise a
mutually authenticated connection. Dart can do neither half of that: no Dart
library builds and signs a certificate — `pointycastle` and `cryptography` both
stop short — and Dart cannot hold a private key outside memory its collector
may copy. So the work lives in a native library and this package is the
contract over it.

## What it replaces

Hand-written ASN.1/DER. Nothing here writes DER by hand; encoding belongs to
`rcgen` and `rustls-webpki`, and this package is the policy above them. The
same library also carries Argon2id, which is what a PIN check needs — and what
the code being replaced was reaching for when it "encrypted" a PIN with an RSA
public key and compared the ciphertexts.

## What it is built on, and what it is not

| | |
| --- | --- |
| verification | `rustls-webpki` over `aws-lc-rs` — the verifier rustls itself uses, on `rustls_pki_types::CertificateDer` |
| issuance | `rcgen`, same organisation, same crypto provider |
| secrets | `argon2` (RustCrypto) |
| **not** `ring` | unmaintained; [RUSTSEC-2025-0007](https://rustsec.org/advisories/RUSTSEC-2025-0007.html) |
| **not** an `openssl` binding | a C build dependency on six platforms, for nothing this needs |

One stack, shared with the QUIC transport that presents these certificates, so
a certificate has one representation and not two.

## The rules it keeps

- **A failure is a value.** Every call answers with `PkiResult`. A panic inside
  the native library is caught at the boundary and returns as `NativeFault`;
  nothing unwinds out of a foreign stack and nothing aborts the process.
- **Native memory is freed when you say so.** Every string the library returns
  is released on the line that reads it; the key store handle is released by
  `RkPki.close()`. A `NativeFinalizer` is attached as a net, never as the
  mechanism — it is guaranteed to run, but never at a moment you can name.
- **Enumerations cross by name.** Profiles, machine kinds, failure kinds and
  operations are names on the wire. An index would change meaning the moment a
  case is inserted, and here that decides whether a machine is trusted.
- **The machine's private key does not cross.** The identity every mutual-TLS
  decision rests on stays inside the library, in any encoding, on every call.
  The store lives inside a worker isolate that shares nothing, and a test walks
  the operations asserting that no answer carries a private-key PEM header.

  **There is exactly one exception, and it is not the machine identity.**
  `serverCredential(CertProfile.browserFacing)` returns the browser-facing leaf
  together with its PKCS#8 key. It exists because a QUIC server has to
  terminate TLS, which means holding the key, and `rk_quic` will not mint a
  certificate of its own — so between the two packages a WebTransport server
  could not be stood up at all. Ask for `CertProfile.machine` and the call is
  refused with `badRequest`; the same test that walks the other operations
  walks this one too, for that profile.

  What makes the exception narrow rather than a hole: the browser-facing leaf
  lives seven days, faces the loopback, and authenticates a *session* rather
  than a machine — a browser pinning `serverCertificateHashes` never walks the
  chain, so a stolen copy carries no standing anywhere else. The authority is
  still one and still here: this hands out a leaf already issued, it does not
  let anyone else issue.

## Offline

An expired certificate degrades exactly like an absent network and never
harder. Selling continues, outgoing work queues, only the new sessions that
need that certificate fail, and a session already open is not torn down by the
wall clock — TLS checks a certificate when a session is established, not
continuously.

```dart
final status = (await pki.status(CertProfile.machine)).valueOrNull!;
status.stopsSelling;           // always false
status.blocksNewSessions;      // true once expired
status.tearsDownOpenSessions;  // true only for a revocation
```

and on the failure side:

```dart
switch (await pki.current(CertProfile.machine)) {
  case PkiOk(value: final info):    // use it
  case PkiErr(error: final e) when e.degradesLikeOffline:
                                    // carry on selling, queue, retry later
  case PkiErr(error: final e):      // a decision: this peer is not ours
}
```

## Two profiles, one authority

| profile | lifetime | why |
| --- | --- | --- |
| `machine` | 30 days | internal mutual TLS: till to shop server to chain server to relay |
| `browserFacing` | 7 days | a browser pinning the hash through WebTransport's `serverCertificateHashes` refuses anything at or over 14 days, so this sits at half of it rather than on the line |

Both are ECDSA P-256 from the same authority. Rotation falls due with a third
of the lifetime left — one rule, so a third profile cannot arrive without a
rotation policy.

## Enrolment and rotation

Enrolment uses a one-time invite: the owner mints it, the new machine presents
it with a signing request, the authority burns it and signs. The invite is
burnt **on presentation**, whatever the outcome — an invite that has been shown
is spent.

Rotation uses no invite, because it must happen with no human involved: what
authorises the reissue is the certificate the machine already holds. If that
certificate has expired, renewal is refused and the machine is back to
enrolment — an expired certificate could not open the session a renewal would
travel over either.

A single till with no server is its own root, by the same code path a chain
server uses. There is no "simple case" implementation.

A signing request contributes exactly one thing that is trusted: the public
key, whose possession it proves by signing itself. Subject, alternative names,
key usage, basic constraints and validity are all decided by the authority —
`rcgen` would happily sign the requester's own parameters, `is_ca` included.

## Names and addresses are two lists, not one

`enroll`, `rotate`, `signingRequest` and the CA calls take `dnsNames` and
`ipAddresses` separately, because they become separate kinds of alternative
name and a TLS client matching `https://192.168.1.50/` consults the second and
**only** the second. An address placed in `dnsNames` yields a certificate that
fails the handshake while looking entirely correct to a person reading it.

That is not a nicety for a shop. A till is reached by name over mDNS, mDNS is
blocked on a noticeable share of guest networks, and the address is the
fallback that keeps the terminal working there — a fallback that breaks the
handshake is not one.

Neither list is guessed when omitted: an absent address list means "no
addresses", never "work out my addresses". This library sees one interface list
and the machine may be on five networks. An address that is not one is refused
by name rather than dropped in silence — a certificate quietly issued without
it would surface days later, on a terminal, as a handshake nobody can explain.

`CertificateInfo.ipAddresses` reports what a certificate carries, written the
way it is stored: dotted quad for v4, colon form for v6.

## Using it

```dart
final opened = await RkPki.open(
  config: PkiConfig(
    storeDirectory: '/var/lib/telepos/pki',
    installationId: 'inst-1',
    machineId: 'till-17',
    machineKind: MachineKind.till,
  ),
);
if (opened case PkiOk(value: final pki)) {
  await pki.initialiseAuthority();            // if this machine is the root
  final invite = await pki.createInvite();
  await pki.enroll(
    invite: invite.valueOrNull!.code,
    profile: CertProfile.machine,
    dnsNames: <String>['till-17.local'],
    ipAddresses: <String>['192.168.1.50'],   // a name here would not match
  );
  await pki.close();
}
```

`hasNativeCrypto` is a real probe: it loads the library, asks for its ABI
version, and answers `false` for every reason a caller might care about
without throwing.

## Building the native part

```
cargo build --manifest-path rust/Cargo.toml
cargo test  --manifest-path rust/Cargo.toml
```

The crate is a plain `cdylib`/`staticlib` behind a C ABI
(`rust/include/rk_pki.h`, seven symbols).

This package is a **Flutter FFI plugin**: `flutter build` runs cargo and puts
the library in the application, on Windows, Linux and Android. Nothing has to
be pointed anywhere — `libraryPath` remains for a library you built by hand.
The mechanism, the three separate routes to cargo, and what to check first on
a Mac are in [`doc/native-build.md`](doc/native-build.md).

**Where it has been proved to arrive:**

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrives | `rk_pki.dll` next to the runner of a built application |
| Linux | arrives | `librk_pki.so` in the application's `bundle/lib/` |
| Android | arrives | found **inside the unpacked APK** for `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| macOS, iOS | **built and linked** | verified 2026-08-03 on Apple M4 / macOS 26.2 / Xcode 26.2: the archive builds for arm64 and x86_64 on macOS, arm64 on device and both on the simulator; a C probe links against it with `-force_load` in Release and Debug, and the macOS binaries run through the C ABI. Gated by CI from that day. |

Bindings are generated, not written:

```
dart run ffigen --config ffigen.yaml     # needs LLVM
```

The generated file is committed, so a consumer never needs LLVM.

## What it is not

Not a general certificate authority. No ACME, no OCSP responder, no HSM
integration, no subjects outside the till / server / relay-client model. An
installation that wants a full authority of its own points this at one: the
authority is an address, not a compiled-in choice.

Not a TLS stack. It issues and judges the certificates a QUIC transport
presents; it runs no session of its own.

## Known gaps

- On Windows a key file inherits the store directory's ACL. On Unix it is
  created 0600. Platform key holders — CNG/DPAPI, Keychain, TPM 2.0 — are the
  next step and are not pretended to exist here.
- Revocation is a local list of fingerprints, consulted on every check. There
  is no CRL distribution and no OCSP: a short lifetime is the passive
  mechanism, this list is the active one.

## License

MIT, Rob Kim. See `LICENSE`.
