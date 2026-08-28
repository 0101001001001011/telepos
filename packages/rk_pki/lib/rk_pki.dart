/// Certificates, mutual TLS and a per-installation certificate authority.
///
/// A machine proves which machine it is with an X.509 certificate signed by
/// the installation's own authority, and two machines that both hold one can
/// raise a mutually authenticated connection. Dart cannot build or sign such
/// a certificate — neither `pointycastle` nor `cryptography` will — and it
/// cannot hold a private key outside memory the collector may copy. So the
/// work lives in a native library, reached through `dart:ffi`, and this
/// package is the contract over it.
///
/// ## What it replaces
///
/// Hand-written ASN.1/DER over `pointycastle`. Nothing here writes DER: the
/// encoding belongs to `rcgen` and `rustls-webpki`, and this package is the
/// policy above them. The same native library also carries Argon2id, which is
/// what the old code was really reaching for when it "encrypted" a PIN with an
/// RSA public key and compared ciphertexts.
///
/// ## The rules it keeps
///
/// * **A failure is a value.** Every call answers with a `PkiResult`. A panic
///   inside the native library is caught at the boundary and comes back as
///   `NativeFault`; nothing unwinds out of a foreign stack, and nothing
///   aborts the process.
/// * **Native memory is freed when you say so.** Every string the library
///   returns is released on the line that reads it, and the key store handle
///   is released by `RkPki.close`. A finalizer exists as a net, never as the
///   mechanism.
/// * **Enumerations cross by name.** Profiles, machine kinds, failure kinds
///   and operations are all names on the wire. An index would change meaning
///   the moment a case is inserted, and here that decides whether a machine
///   is trusted.
/// * **The private key does not cross.** No call in this package returns key
///   material in any encoding, and the store lives inside a worker isolate
///   that shares nothing.
///
/// ## Offline
///
/// An expired certificate degrades exactly like an absent network and never
/// harder: selling continues, outgoing work queues, only the new sessions that
/// need that certificate fail, and a session already open is not torn down by
/// the wall clock. `PkiError.degradesLikeOffline` and `CertificateStatus` say
/// which is which so the caller does not have to remember.
///
/// ## Where it may be used
///
/// Below the application's contract, never from presentation code: this
/// library imports `dart:ffi` and `dart:io`, so a web build that reaches it
/// does not compile. That is the intended shape, not a limitation to work
/// around.
///
/// ```dart
/// final opened = await RkPki.open(
///   config: PkiConfig(
///     storeDirectory: '/var/lib/telepos/pki',
///     installationId: 'inst-1',
///     machineId: 'till-17',
///     machineKind: MachineKind.till,
///   ),
/// );
/// if (opened case PkiOk(value: final pki)) {
///   final status = await pki.status(CertProfile.machine);
///   // ... and selling carries on whatever it says
///   await pki.close();
/// }
/// ```
library;

export 'src/envelope.dart' show decodeEnvelope, decodeEnvelopeAs;
export 'src/errors.dart';
export 'src/machine_identity.dart';
export 'src/model.dart';
export 'src/native/library.dart' show rkPkiAbiVersion;
export 'src/rk_pki_base.dart'
    show RkPki, hasNativeCrypto, secretHash, secretVerify;

/// The version this package reports about itself.
const String rkPkiVersion = '0.4.0';
