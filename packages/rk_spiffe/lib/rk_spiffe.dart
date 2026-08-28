/// SPIFFE identity documents and names, in pure Dart.
///
/// SPIFFE is three separate things wearing one name: a **name format**
/// (`spiffe://trust-domain/path`), a pair of **document formats** (X.509-SVID
/// and JWT-SVID) and the **Workload API**, a gRPC service on a Unix socket
/// that hands a process its own identity. This package is the first two. It
/// is deliberately, permanently not the third.
///
/// ## What it does
///
/// * Parses and validates SPIFFE IDs and trust domains against the grammar,
///   refusing every near-miss instead of normalising it.
/// * Reads an X.509 certificate from DER or PEM with a strict reader, and
///   says whether it is shaped like an X.509-SVID leaf.
/// * Reads a JWT-SVID's header and claims, checks the rules the document puts
///   on them, and hands back the signing input and signature so that whoever
///   holds the trust bundle can check the signature.
///
/// ## What it does not do, and will not
///
/// **It does not verify anything.** No signature is checked, no chain is
/// walked, no trust bundle is consulted, and the entry points are named
/// `parseUnverified` so that no call site can be read as though they did. A
/// document that parses here is a claim, not a fact.
///
/// That is a boundary, not a gap. Verifying an X.509 chain is answering "why
/// should anyone believe this machine", and in this author's packages that
/// question already has an owner: `rk_pki`, which holds the certificate
/// authority, the key store and `rustls-webpki` behind an FFI boundary. A
/// second verifier in Dart would be a second answer to the same question, and
/// two answers is the failure mode, not the feature. Hand
/// `X509Svid.certificate.der` to whatever owns trust in your system.
///
/// **It is not a Workload API client.** Such a client would be a *consumer* of
/// an agent that has to be running on the machine already; adding one obliges
/// a SPIRE agent on every host and a server whose absence stops renewal within
/// a day. That is a deployment decision, and a library cannot make it on
/// anyone's behalf, so this package does not pretend to.
///
/// ## Shape
///
/// Pure Dart. No native part, no `dart:io`, no `dart:ffi`, no dependencies
/// beyond the SDK — so it runs on a server, on a phone and in a browser
/// alike. Failures come back as values: every entry point returns a
/// `SpiffeResult`, and every failure carries the **name** of the exact clause
/// it broke rather than a number.
///
/// ```dart
/// import 'package:rk_spiffe/rk_spiffe.dart';
///
/// final id = SpiffeId.parse('spiffe://shop-42.telepos/till/17/terminal/3');
/// switch (id) {
///   case SpiffeOk(value: final id):
///     print(id.trustDomain);     // shop-42.telepos
///     print(id.segments);        // [till, 17, terminal, 3]
///   case SpiffeErr(error: final e):
///     print(e);                  // malformedSpiffeId(<clause>): <why>
/// }
/// ```
library;

export 'src/errors.dart';
export 'src/jwt_svid.dart';
export 'src/spiffe_id.dart';
export 'src/x509_svid.dart';

/// The version this package reports about itself.
const String rkSpiffeVersion = '0.1.0';
