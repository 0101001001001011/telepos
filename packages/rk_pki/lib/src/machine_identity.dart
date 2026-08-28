/// The contract the rest of the product sees.
library;

import 'model.dart';
import 'errors.dart';

/// What a machine can do about its own identity.
///
/// Every method answers with a [PkiResult]. Nothing here throws, and nothing
/// here returns key material: an implementation that did either would break
/// the two rules this package exists to keep.
abstract interface class MachineIdentity {
  /// First issue, against a one-time invite.
  ///
  /// The key pair is born inside the native part and never leaves it; what
  /// travels is a signing request. The invite is burnt on presentation,
  /// whatever the outcome.
  ///
  /// [dnsNames] and [ipAddresses] are separate lists because they become
  /// separate kinds of alternative name, and a client matching an address URL
  /// reads only the second. Putting `192.168.1.50` in [dnsNames] issues a
  /// certificate that fails the handshake while looking correct to a reader.
  /// Neither list is guessed when omitted: an absent address list means "no
  /// addresses", never "work out my addresses" — this library sees one
  /// interface list and the machine may be on five networks.
  Future<PkiResult<CertificateInfo>> enroll({
    required String invite,
    required CertProfile profile,
    List<String> dnsNames,
    List<String> ipAddresses,
    DateTime? now,
  });

  /// Rotation, with no human involved: what authorises it is the certificate
  /// this machine already holds. Available directly only where this machine
  /// is also the authority; elsewhere the caller ships [signingRequest] to
  /// the authority and feeds the answer to [installCertificate].
  Future<PkiResult<CertificateInfo>> rotate(
    CertProfile profile, {
    List<String> dnsNames,
    List<String> ipAddresses,
    DateTime? now,
  });

  /// The certificate held for a profile, without touching the network.
  ///
  /// An expired certificate comes back as [CertificateExpired], which the
  /// caller must treat exactly as it treats an absent network — see
  /// [PkiError.degradesLikeOffline].
  Future<PkiResult<CertificateInfo>> current(
    CertProfile profile, {
    DateTime? now,
  });

  /// What still works, answered without failing — including when the
  /// certificate has expired or is missing entirely.
  Future<PkiResult<CertificateStatus>> status(
    CertProfile profile, {
    DateTime? now,
  });

  /// A signing request to send to the authority.
  Future<PkiResult<SigningRequest>> signingRequest(
    CertProfile profile, {
    List<String> dnsNames,
    List<String> ipAddresses,
  });

  /// Stores a certificate the authority issued for this machine. Refused
  /// unless it chains to a root we trust and carries this machine's key.
  Future<PkiResult<CertificateInfo>> installCertificate({
    required CertProfile profile,
    required String certPem,
    String? chainPem,
    DateTime? now,
  });

  /// Judges somebody else's certificate, outside a TLS handshake — the
  /// "is this till still trusted" screen. It does not replace the check
  /// rustls makes on every connection.
  Future<PkiResult<CertificateInfo>> verifyPeer(
    String certPem, {
    String? chainPem,
    PeerUsage usage,
    String? dnsName,
    DateTime? now,
  });

  /// Revokes, with immediate effect on what is checked next. Our own profile's
  /// key is forgotten in the same operation.
  Future<PkiResult<String>> revoke({
    CertProfile? profile,
    String? fingerprintSha256,
    String? reason,
    DateTime? now,
  });
}

/// Salted one-way hashing for staff PINs — the job `rsa_util.dart` was
/// standing in for, kept in this package so the product has one audited
/// implementation of the primitive rather than a second home-made one.
abstract interface class SecretHasher {
  /// Argon2id with a fresh random salt. The salt and parameters travel inside
  /// the returned PHC string.
  Future<PkiResult<String>> hashSecret(String secret);

  /// Constant-time verification against a stored PHC string. A malformed
  /// stored value is a [BadRequest], not a quiet `false`.
  Future<PkiResult<bool>> verifySecret(String secret, String stored);
}
