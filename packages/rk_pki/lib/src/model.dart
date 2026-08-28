/// Names that cross the boundary, and the shapes they arrive in.
///
/// Every enumeration here is carried as its **name**. Dart's `index` is
/// deliberately never used on the wire: inserting a case would silently
/// change what a stored `1` means, and here that decides whether a machine is
/// trusted.
library;

import 'errors.dart';

/// A machine holds more than one leaf certificate at a time.
enum CertProfile {
  /// Internal mutual TLS between till, shop server, chain server and relay.
  machine,

  /// Presented to a browser over WebTransport, where the browser may pin the
  /// hash rather than walk a chain, and the specification caps the lifetime
  /// at 14 days.
  browserFacing;

  /// The name on the wire. Identical to `name`, spelled out so that renaming
  /// the Dart constant cannot silently change the protocol.
  String get wireName => switch (this) {
    CertProfile.machine => 'machine',
    CertProfile.browserFacing => 'browserFacing',
  };

  /// Parses a name, refusing anything else — including an index in string
  /// form, which is exactly the mistake И147 exists to prevent.
  static CertProfile? tryParse(String name) => switch (name) {
    'machine' => CertProfile.machine,
    'browserFacing' => CertProfile.browserFacing,
    _ => null,
  };
}

/// What kind of machine a certificate identifies. A fact about topology, not
/// a permission: rights live elsewhere and a certificate never carries them.
enum MachineKind {
  till,
  shopServer,
  chainServer,
  clusterNode,
  relayClient;

  String get wireName => switch (this) {
    MachineKind.till => 'till',
    MachineKind.shopServer => 'shopServer',
    MachineKind.chainServer => 'chainServer',
    MachineKind.clusterNode => 'clusterNode',
    MachineKind.relayClient => 'relayClient',
  };

  static MachineKind? tryParse(String name) => switch (name) {
    'till' => MachineKind.till,
    'shopServer' => MachineKind.shopServer,
    'chainServer' => MachineKind.chainServer,
    'clusterNode' => MachineKind.clusterNode,
    'relayClient' => MachineKind.relayClient,
    _ => null,
  };
}

/// What a peer is being asked to be during verification.
enum PeerUsage {
  serverAuth,
  clientAuth;

  String get wireName =>
      this == PeerUsage.serverAuth ? 'serverAuth' : 'clientAuth';
}

/// The public description of a certificate. No key material, by construction.
final class CertificateInfo {
  const CertificateInfo({
    required this.subjectMachineId,
    required this.installationId,
    required this.machineKind,
    required this.profile,
    required this.notBefore,
    required this.notAfter,
    required this.fingerprintSha256,
    required this.serial,
    required this.dnsNames,
    required this.ipAddresses,
    required this.isCa,
  });

  final String subjectMachineId;
  final String installationId;

  /// Absent when the certificate is not one of ours — we say so rather than
  /// guess a kind.
  final MachineKind? machineKind;
  final CertProfile? profile;

  final DateTime notBefore;
  final DateTime notAfter;

  /// Lower-case hex SHA-256 of the DER. The same value a browser pins through
  /// `serverCertificateHashes`, and the one shown in the interface.
  final String fingerprintSha256;
  final String serial;
  final List<String> dnsNames;

  /// The `iPAddress` entries, as they are written — dotted quad for v4, colon
  /// form for v6.
  ///
  /// Separate from [dnsNames] because a client matching `https://10.0.0.7/`
  /// consults only this list. A screen showing "which addresses does this till
  /// answer on" has to read it too, and would otherwise show names for a
  /// question that was about addresses.
  final List<String> ipAddresses;

  final bool isCa;

  bool isExpiredAt(DateTime now) => now.isAfter(notAfter);

  Duration remainingAt(DateTime now) => notAfter.difference(now);

  static CertificateInfo fromJson(Map<String, Object?> json) => CertificateInfo(
    subjectMachineId: json['subjectMachineId'] as String? ?? '',
    installationId: json['installationId'] as String? ?? '',
    machineKind: switch (json['machineKind']) {
      final String name => MachineKind.tryParse(name),
      _ => null,
    },
    profile: switch (json['profile']) {
      final String name => CertProfile.tryParse(name),
      _ => null,
    },
    notBefore: _time(json['notBefore']),
    notAfter: _time(json['notAfter']),
    fingerprintSha256: json['fingerprintSha256'] as String? ?? '',
    serial: json['serial'] as String? ?? '',
    dnsNames: switch (json['dnsNames']) {
      final List<Object?> names => names.whereType<String>().toList(),
      _ => const <String>[],
    },
    ipAddresses: switch (json['ipAddresses']) {
      final List<Object?> addresses => addresses.whereType<String>().toList(),
      _ => const <String>[],
    },
    isCa: json['isCa'] == true,
  );

  @override
  String toString() =>
      'CertificateInfo($subjectMachineId@$installationId, '
      '${profile?.wireName}, until ${notAfter.toIso8601String()})';
}

DateTime _time(Object? seconds) => DateTime.fromMillisecondsSinceEpoch(
  (seconds is num ? seconds.toInt() : 0) * 1000,
  isUtc: true,
);

/// What still works, answered without failing.
///
/// The one place the offline rule is stated as data rather than as an error:
/// [stopsSelling] is never true, [tearsDownOpenSessions] is true only for a
/// revocation, and an expired certificate blocks the new sessions that need
/// it and nothing else.
final class CertificateStatus {
  const CertificateStatus({
    required this.profile,
    required this.present,
    required this.expired,
    required this.revoked,
    required this.notYetValid,
    required this.rotationDue,
    required this.rotateAt,
    required this.secondsRemaining,
    required this.blocksNewSessions,
    required this.tearsDownOpenSessions,
    required this.info,
  });

  final CertProfile profile;
  final bool present;
  final bool expired;
  final bool revoked;
  final bool notYetValid;
  final bool rotationDue;
  final DateTime? rotateAt;
  final int secondsRemaining;

  /// A session that needs this certificate cannot be started.
  final bool blocksNewSessions;

  /// A session already established must be closed. Never true for expiry.
  final bool tearsDownOpenSessions;

  final CertificateInfo? info;

  /// Selling never stops for anything in this file. Kept as a getter so the
  /// rule is visible at the call site instead of remembered.
  bool get stopsSelling => false;

  /// Expiry with a reachable network means drifted clocks, an authority out
  /// of reach longer than the rotation window, or broken rotation.
  bool get isSecurityEvent => expired || revoked;

  static CertificateStatus fromJson(Map<String, Object?> json) {
    final rotateAt = json['rotateAt'];
    return CertificateStatus(
      profile:
          CertProfile.tryParse(json['profile'] as String? ?? '') ??
          CertProfile.machine,
      present: json['present'] == true,
      expired: json['expired'] == true,
      revoked: json['revoked'] == true,
      notYetValid: json['notYetValid'] == true,
      rotationDue: json['rotationDue'] == true,
      rotateAt: rotateAt is num ? _time(rotateAt) : null,
      secondsRemaining: switch (json['secondsRemaining']) {
        final num value => value.toInt(),
        _ => 0,
      },
      blocksNewSessions: json['blocksNewSessions'] == true,
      tearsDownOpenSessions: json['tearsDownOpenSessions'] == true,
      info: switch (json['info']) {
        final Map<String, Object?> info => CertificateInfo.fromJson(info),
        _ => null,
      },
    );
  }
}

/// What one machine needs to say about itself before it can hold an identity.
final class PkiConfig {
  const PkiConfig({
    required this.storeDirectory,
    required this.installationId,
    required this.machineId,
    required this.machineKind,
  });

  /// Where keys and certificates live. Private keys are written here with
  /// owner-only permissions where the platform has them.
  final String storeDirectory;
  final String installationId;
  final String machineId;
  final MachineKind machineKind;

  Map<String, Object?> toJson() => <String, Object?>{
    'storeDir': storeDirectory,
    'installationId': installationId,
    'machineId': machineId,
    'machineKind': machineKind.wireName,
  };

  /// The same identifier rule the native side enforces, checked here too so a
  /// caller learns of it without a round trip.
  PkiError? validate() {
    for (final (name, value) in <(String, String)>[
      ('installationId', installationId),
      ('machineId', machineId),
    ]) {
      if (value.isEmpty || value.length > 64) {
        return BadRequest('$name must be 1..64 characters');
      }
      if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value)) {
        return BadRequest(
          "$name accepts only ASCII letters, digits, '-', '_' and '.'",
        );
      }
    }
    if (storeDirectory.isEmpty) {
      return const BadRequest('storeDirectory must not be empty');
    }
    return null;
  }
}

/// An invite, as minted by the authority and shown once.
final class Invite {
  const Invite({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;

  static Invite fromJson(Map<String, Object?> json) => Invite(
    code: json['invite'] as String? ?? '',
    expiresAt: _time(json['expiresAt']),
  );
}

/// A signing request: a public key, proved by its own signature, and the name
/// the machine is asking to be called.
final class SigningRequest {
  const SigningRequest({
    required this.csrPem,
    required this.publicKeyFingerprintSha256,
    required this.profile,
  });

  final String csrPem;
  final String publicKeyFingerprintSha256;
  final CertProfile profile;

  static SigningRequest fromJson(Map<String, Object?> json) => SigningRequest(
    csrPem: json['csrPem'] as String? ?? '',
    publicKeyFingerprintSha256:
        json['publicKeyFingerprintSha256'] as String? ?? '',
    profile:
        CertProfile.tryParse(json['profile'] as String? ?? '') ??
        CertProfile.machine,
  );
}

/// What a TLS server needs to answer a handshake: the chain it presents and
/// the key it proves it with.
///
/// The only shape in this package that carries key material. See
/// `RkPki.serverCredential` for why it exists and why it is limited to
/// [CertProfile.browserFacing].
///
/// [privateKeyPem] is PKCS#8 — the shape `rk_quic`'s `QuicServerConfig` takes,
/// so the value goes straight across without reformatting.
final class ServerCredential {
  const ServerCredential({
    required this.chainPem,
    required this.privateKeyPem,
    required this.info,
  });

  /// Leaf first, the way a TLS server presents it.
  final String chainPem;

  /// PKCS#8 PEM. Hold it no longer than the listener needs it.
  final String privateKeyPem;

  final CertificateInfo info;

  static ServerCredential fromJson(Map<String, Object?> json) =>
      ServerCredential(
        chainPem: json['chainPem'] as String? ?? '',
        privateKeyPem: json['privateKeyPem'] as String? ?? '',
        info: CertificateInfo.fromJson(
          json['info'] as Map<String, Object?>? ?? const <String, Object?>{},
        ),
      );

  /// Never prints the key. A credential that logged itself would undo the
  /// narrowness the export was granted on.
  @override
  String toString() =>
      'ServerCredential(${info.profile?.wireName}, expires ${info.notAfter}, '
      'key withheld)';
}

/// What the authority hands back: the certificate, the chain to its root, and
/// the description of what was signed.
final class IssuedCertificate {
  const IssuedCertificate({
    required this.certPem,
    required this.chainPem,
    required this.info,
  });

  final String certPem;
  final String chainPem;
  final CertificateInfo info;

  static IssuedCertificate fromJson(Map<String, Object?> json) =>
      IssuedCertificate(
        certPem: json['certPem'] as String? ?? '',
        chainPem: json['chainPem'] as String? ?? '',
        info: CertificateInfo.fromJson(
          json['info'] as Map<String, Object?>? ?? const <String, Object?>{},
        ),
      );
}
