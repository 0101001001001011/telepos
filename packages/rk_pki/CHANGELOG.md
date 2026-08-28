## 0.4.0

- Certificates can now carry IP addresses: enroll, rotate, signingRequest and the CA calls take ipAddresses alongside dnsNames, and CertificateInfo reports them. A TLS client opening https://192.168.1.50/ reads iPAddress entries only, so an address placed in dnsNames failed the handshake while looking correct. CertificateInfo's constructor gained a required ipAddresses argument.

## 0.3.1

- macOS and iOS actually build now. The pod script phase shipped with CRLF line endings and exited 0 without invoking cargo; the static archive carried 0 of its 7 exported symbols; and aarch64-apple-ios did not link at all. The Dart loader also asked for a dylib that is never produced on macOS. All fixed and verified on a Mac.

## 0.3.0

- serverCredential: the browser-facing leaf and its key, for a TLS server that must terminate the handshake itself

## 0.2.2

- версия, которую сообщает библиотека, совпадает с версией пакета

## 0.2.1

- Documentation is now in English throughout: `CONTRIBUTING.md`,
  `SECURITY.md`, `doc/native-build.md` and the 0.2.0 changelog entry were in
  Russian and are not any more. No code and no API change.
- The pubspec description said the native library is built on `rustls`. It is
  not: `rustls-webpki` is linked, and the full `rustls` crate deliberately is
  not, because this package runs no TLS session of its own. Corrected.
- `SECURITY.md` claimed the package "does not store credentials and does not
  decide whom to trust". That was boilerplate shared with the sibling
  packages and it is the opposite of what `rk_pki` does — it holds private
  keys and it judges peer certificates. Rewritten to describe this package,
  including two failure modes that do belong on that list: private key
  material crossing out of the native library, and a signing request being
  allowed to choose its own subject or `is_ca`.
- `doc/architecture.md` still said the per-platform build wiring was absent.
  It has been present since 0.2.0.

## 0.2.0

- The package is now a Flutter FFI plugin: `flutter build` invokes cargo itself
  and puts the library in the application, on Windows, Linux and Android.
  Before this there was no `flutter.plugin.platforms` block in the pubspec, and
  the native part reached no build at all. macOS and iOS are written, but have
  never been built.

## 0.1.0

First release with content. Everything below is new, so nothing is broken.

- **Machine identity.** An ECDSA P-256 key pair and certificate per machine,
  issued by the installation's own authority. The private key is generated,
  stored and used inside the native library and is not returned by any call.
- **Two profiles from one authority.** `machine` (30 days) for internal mutual
  TLS, `browserFacing` (7 days) for a browser pinning the hash over
  WebTransport, which refuses anything at or over 14 days.
- **Enrolment by one-time invite**, burnt on presentation whatever the outcome.
  **Rotation without an invite and without a human**, authorised by the
  certificate the machine already holds.
- **A single till is its own root**, by the same code path a chain server uses.
- **Verification** of a peer's certificate against the installation's roots,
  with revocation by fingerprint taking effect on the next check.
- **Argon2id** hashing and verification for staff PINs, replacing what was
  being done with an RSA public key and a ciphertext comparison.
- **Failures are values.** `PkiResult` everywhere; a panic inside the native
  library is caught at the boundary and arrives as `NativeFault`.
- **Offline behaviour is part of the contract.** `degradesLikeOffline`,
  `blocksNewSessions`, `tearsDownOpenSessions` and `stopsSelling` say what an
  expired certificate does and does not stop — and it never stops a sale.
- `hasNativeCrypto` is a real probe: it loads the library and checks its ABI
  version instead of returning a constant.

The per-platform build wiring is still absent by design: the crate is a plain
`cdylib`/`staticlib` behind a C ABI, and the mechanism that carries it into a
Flutter build is being decided once for a family of packages.

## 0.0.1

- Name claimed. No content yet: the package proves the publishing
  pipeline, it does not solve the problem.
