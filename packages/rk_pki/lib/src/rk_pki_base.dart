/// The implementation over the native library.
library;

import 'dart:convert';
import 'dart:isolate';

import 'envelope.dart';
import 'errors.dart';
import 'machine_identity.dart';
import 'model.dart';
import 'native/library.dart';
import 'native/worker.dart';

/// Whether a usable native library is present in this build.
///
/// A real probe, not a constant: it loads the library and asks for its ABI
/// version. It answers `false` for every reason a caller might care about —
/// no library, wrong ABI, an unreadable file — and never throws.
///
/// This is the one call that runs on whichever isolate asks. It is a symbol
/// lookup and an integer return, with no I/O and nothing that can block, so
/// it does not fall under the rule that keeps work off the interface isolate.
bool get hasNativeCrypto => RkPki.probe().isOk;

/// One machine's PKI, over the native library.
final class RkPki implements MachineIdentity, SecretHasher {
  RkPki._(this._worker, this.config);

  final PkiWorker _worker;
  final PkiConfig config;
  bool _closed = false;

  /// Loads the library and reports what it found. Cheap, synchronous, and
  /// safe to call before deciding whether anything else is possible.
  static PkiResult<String> probe({String? libraryPath}) {
    final library = RkPkiLibrary.open(path: libraryPath);
    return switch (library) {
      PkiOk<RkPkiLibrary>(:final value) => _versionOf(value),
      PkiErr<RkPkiLibrary>(:final error) => PkiErr<String>(error),
    };
  }

  static PkiResult<String> _versionOf(RkPkiLibrary library) {
    try {
      return PkiOk<String>(library.version);
    } catch (e) {
      return PkiErr<String>(
        NativeUnavailable('the library loaded but would not answer: $e'),
      );
    }
  }

  /// Opens a machine's key store on a background isolate.
  ///
  /// The store, the engine handle and every private key stay inside that
  /// isolate for its whole life. Nothing about them is sendable, which is the
  /// mechanical reason they cannot leak into the interface isolate.
  static Future<PkiResult<RkPki>> open({
    required PkiConfig config,
    String? libraryPath,
  }) async {
    final invalid = config.validate();
    if (invalid != null) return PkiErr<RkPki>(invalid);

    final worker = await PkiWorker.spawn(
      configJson: jsonEncode(config.toJson()),
      libraryPath: libraryPath,
    );
    return switch (worker) {
      PkiOk<PkiWorker>(:final value) => PkiOk<RkPki>(RkPki._(value, config)),
      PkiErr<PkiWorker>(:final error) => PkiErr<RkPki>(error),
    };
  }

  /// Closes the store now. The native handle is released deterministically
  /// inside the worker; the collector is not involved.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _worker.close();
  }

  Future<PkiResult<T>> _call<T>(
    String op,
    Map<String, Object?> request,
    T Function(Map<String, Object?> value) read,
  ) async {
    if (_closed) {
      return PkiErr<T>(const NativeFault('this RkPki has been closed'));
    }
    request.removeWhere((_, Object? value) => value == null);
    final answer = await _worker.call(op, jsonEncode(request));
    return decodeEnvelopeAs<T>(answer, read);
  }

  static int? _unix(DateTime? moment) =>
      moment == null ? null : moment.toUtc().millisecondsSinceEpoch ~/ 1000;

  // --- the authority -------------------------------------------------------

  /// Makes this machine the installation's authority. Idempotent: a second
  /// call returns the root that already exists rather than replacing every
  /// machine's trust anchor.
  Future<PkiResult<CertificateInfo>> initialiseAuthority({DateTime? now}) =>
      _call<CertificateInfo>(
        'ca.init',
        <String, Object?>{'nowUnix': _unix(now)},
        (Map<String, Object?> value) =>
            CertificateInfo.fromJson(value['info']! as Map<String, Object?>),
      );

  /// The authority's own certificate, for showing or shipping.
  Future<PkiResult<String>> authorityRootPem() => _call<String>(
    'ca.info',
    <String, Object?>{},
    (Map<String, Object?> value) => value['rootPem']! as String,
  );

  /// Accepts somebody else's root as this machine's trust anchor.
  Future<PkiResult<CertificateInfo>> trustAuthority(String rootPem) =>
      _call<CertificateInfo>(
        'ca.trust',
        <String, Object?>{'rootPem': rootPem},
        (Map<String, Object?> value) =>
            CertificateInfo.fromJson(value['info']! as Map<String, Object?>),
      );

  /// Mints a one-time invite, shown once as a string and as a QR code.
  Future<PkiResult<Invite>> createInvite({Duration? lifetime, DateTime? now}) =>
      _call<Invite>('ca.invite.create', <String, Object?>{
        'ttlSeconds': lifetime?.inSeconds,
        'nowUnix': _unix(now),
      }, Invite.fromJson);

  /// Signs another machine's request against an invite. The authority decides
  /// the certificate's contents; the request contributes only its public key.
  Future<PkiResult<IssuedCertificate>> issue({
    required String invite,
    required String csrPem,
    required String machineId,
    required MachineKind machineKind,
    required CertProfile profile,
    List<String> dnsNames = const <String>[],
    List<String> ipAddresses = const <String>[],
    DateTime? now,
  }) => _call<IssuedCertificate>('ca.issue', <String, Object?>{
    'invite': invite,
    'csrPem': csrPem,
    'machineId': machineId,
    'machineKind': machineKind.wireName,
    'profile': profile.wireName,
    'dnsNames': dnsNames,
    'ipAddresses': ipAddresses,
    'nowUnix': _unix(now),
  }, IssuedCertificate.fromJson);

  /// Reissues for another machine that already holds a valid certificate from
  /// this authority — the rotation path, with no invite and no human.
  Future<PkiResult<IssuedCertificate>> renew({
    required String csrPem,
    required String currentCertPem,
    required String machineId,
    required MachineKind machineKind,
    required CertProfile profile,
    List<String> dnsNames = const <String>[],
    List<String> ipAddresses = const <String>[],
    DateTime? now,
  }) => _call<IssuedCertificate>('ca.renew', <String, Object?>{
    'csrPem': csrPem,
    'currentCertPem': currentCertPem,
    'machineId': machineId,
    'machineKind': machineKind.wireName,
    'profile': profile.wireName,
    'dnsNames': dnsNames,
    'ipAddresses': ipAddresses,
    'nowUnix': _unix(now),
  }, IssuedCertificate.fromJson);

  // --- this machine's identity --------------------------------------------

  @override
  Future<PkiResult<CertificateInfo>> enroll({
    required String invite,
    required CertProfile profile,
    List<String> dnsNames = const <String>[],
    List<String> ipAddresses = const <String>[],
    DateTime? now,
  }) => _call<CertificateInfo>(
    'identity.enroll',
    <String, Object?>{
      'invite': invite,
      'profile': profile.wireName,
      'dnsNames': dnsNames,
      'ipAddresses': ipAddresses,
      'nowUnix': _unix(now),
    },
    (Map<String, Object?> value) =>
        CertificateInfo.fromJson(value['info']! as Map<String, Object?>),
  );

  @override
  Future<PkiResult<CertificateInfo>> rotate(
    CertProfile profile, {
    List<String> dnsNames = const <String>[],
    List<String> ipAddresses = const <String>[],
    DateTime? now,
  }) => _call<CertificateInfo>(
    'identity.renew',
    <String, Object?>{
      'profile': profile.wireName,
      'dnsNames': dnsNames,
      'ipAddresses': ipAddresses,
      'nowUnix': _unix(now),
    },
    (Map<String, Object?> value) =>
        CertificateInfo.fromJson(value['info']! as Map<String, Object?>),
  );

  @override
  Future<PkiResult<CertificateInfo>> current(
    CertProfile profile, {
    DateTime? now,
  }) => _call<CertificateInfo>(
    'certificate.current',
    <String, Object?>{'profile': profile.wireName, 'nowUnix': _unix(now)},
    (Map<String, Object?> value) =>
        CertificateInfo.fromJson(value['info']! as Map<String, Object?>),
  );

  @override
  Future<PkiResult<CertificateStatus>> status(
    CertProfile profile, {
    DateTime? now,
  }) => _call<CertificateStatus>('certificate.status', <String, Object?>{
    'profile': profile.wireName,
    'nowUnix': _unix(now),
  }, CertificateStatus.fromJson);

  /// This machine's certificate as it would be presented to a peer. Public by
  /// definition, and readable even after it has expired — the health screen
  /// still has to show it.
  Future<PkiResult<String>> exportCertificate(CertProfile profile) =>
      _call<String>('certificate.export', <String, Object?>{
        'profile': profile.wireName,
      }, (Map<String, Object?> value) => value['certPem']! as String);

  /// The certificate **and its private key**, for a server that has to
  /// terminate TLS itself.
  ///
  /// This is the only call in the package that returns key material, and it
  /// returns it for [CertProfile.browserFacing] and nothing else — ask for
  /// [CertProfile.machine] and the native side answers `badRequest`. The
  /// machine identity is what mutual TLS between till, shop server and relay
  /// rests on, and it still never crosses.
  ///
  /// The exception exists because there was otherwise no way to stand up a
  /// WebTransport server at all: `rk_quic` needs `privateKeyPem` to terminate
  /// TLS and refuses to mint certificates of its own (one installation, one
  /// authority), while this package refused to hand any key over. Two sound
  /// rules with no path between them.
  ///
  /// What makes giving here narrower than giving anywhere: the browser-facing
  /// leaf lives seven days, faces the loopback, and authenticates a *session*
  /// rather than a machine — a browser pinning `serverCertificateHashes` never
  /// walks the chain, so this certificate buys its holder no standing
  /// anywhere else.
  Future<PkiResult<ServerCredential>> serverCredential(
    CertProfile profile,
  ) => _call<ServerCredential>('certificate.serverCredential', <String, Object?>{
    'profile': profile.wireName,
  }, ServerCredential.fromJson);

  @override
  Future<PkiResult<SigningRequest>> signingRequest(
    CertProfile profile, {
    List<String> dnsNames = const <String>[],
    List<String> ipAddresses = const <String>[],
  }) => _call<SigningRequest>('identity.csr', <String, Object?>{
    'profile': profile.wireName,
    'dnsNames': dnsNames,
    'ipAddresses': ipAddresses,
  }, SigningRequest.fromJson);

  @override
  Future<PkiResult<CertificateInfo>> installCertificate({
    required CertProfile profile,
    required String certPem,
    String? chainPem,
    DateTime? now,
  }) => _call<CertificateInfo>(
    'certificate.install',
    <String, Object?>{
      'profile': profile.wireName,
      'certPem': certPem,
      'chainPem': chainPem,
      'nowUnix': _unix(now),
    },
    (Map<String, Object?> value) =>
        CertificateInfo.fromJson(value['info']! as Map<String, Object?>),
  );

  @override
  Future<PkiResult<CertificateInfo>> verifyPeer(
    String certPem, {
    String? chainPem,
    PeerUsage usage = PeerUsage.clientAuth,
    String? dnsName,
    DateTime? now,
  }) => _call<CertificateInfo>(
    'peer.verify',
    <String, Object?>{
      'certPem': certPem,
      'chainPem': chainPem,
      'usage': usage.wireName,
      'dnsName': dnsName,
      'nowUnix': _unix(now),
    },
    (Map<String, Object?> value) =>
        CertificateInfo.fromJson(value['info']! as Map<String, Object?>),
  );

  @override
  Future<PkiResult<String>> revoke({
    CertProfile? profile,
    String? fingerprintSha256,
    String? reason,
    DateTime? now,
  }) => _call<String>(
    'certificate.revoke',
    <String, Object?>{
      'profile': profile?.wireName,
      'fingerprintSha256': fingerprintSha256,
      'reason': reason,
      'nowUnix': _unix(now),
    },
    (Map<String, Object?> value) => value['fingerprintSha256']! as String,
  );

  /// Forgets a profile's key and certificate.
  Future<PkiResult<void>> forget(CertProfile profile) => _call<void>(
    'identity.forget',
    <String, Object?>{'profile': profile.wireName},
    (Map<String, Object?> _) {},
  );

  // --- secrets -------------------------------------------------------------

  @override
  Future<PkiResult<String>> hashSecret(String secret) =>
      secretHash(secret, libraryPath: null);

  @override
  Future<PkiResult<bool>> verifySecret(String secret, String stored) =>
      secretVerify(secret, stored, libraryPath: null);
}

/// Argon2id hashing, which needs no key store and so needs no engine.
///
/// Each call runs on its own short-lived isolate: Argon2 is deliberately slow,
/// and slow work on the interface isolate is exactly what И145 forbids. A
/// long-lived worker would be the wrong shape here — there is no state to
/// keep between calls, and a PIN is hashed at login, not in a loop.
Future<PkiResult<String>> secretHash(String secret, {String? libraryPath}) =>
    _stateless<String>(
      'secret.hash',
      <String, Object?>{'secret': secret},
      libraryPath,
      (Map<String, Object?> value) => value['encoded']! as String,
    );

/// Verifies a secret against a stored PHC string.
Future<PkiResult<bool>> secretVerify(
  String secret,
  String stored, {
  String? libraryPath,
}) => _stateless<bool>(
  'secret.verify',
  <String, Object?>{'secret': secret, 'stored': stored},
  libraryPath,
  (Map<String, Object?> value) => value['matches']! as bool,
);

Future<PkiResult<T>> _stateless<T>(
  String op,
  Map<String, Object?> request,
  String? libraryPath,
  T Function(Map<String, Object?> value) read,
) async {
  final requestJson = jsonEncode(request);
  final String answer;
  try {
    answer = await Isolate.run<String>(() {
      final library = RkPkiLibrary.open(path: libraryPath);
      return switch (library) {
        PkiOk<RkPkiLibrary>(:final value) => value.callStateless(
          op,
          requestJson,
        ),
        PkiErr<RkPkiLibrary>(:final error) =>
          '{"ok":false,"error":{"kind":"nativeUnavailable",'
              '"detail":${jsonEncode(error.detail ?? '')}}}',
      };
    });
  } catch (e) {
    return PkiErr<T>(NativeFault('the hashing isolate failed: $e'));
  }
  return decodeEnvelopeAs<T>(answer, read);
}
