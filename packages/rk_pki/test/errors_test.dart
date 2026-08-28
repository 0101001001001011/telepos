import 'package:rk_pki/rk_pki.dart';
import 'package:test/test.dart';

void main() {
  group('failures arrive by name', () {
    test('every kind the native side can send has a case here', () {
      const kinds = <String>[
        'inviteInvalid',
        'inviteExpired',
        'caUnreachable',
        'caNotHere',
        'certificateNotFound',
        'certificateExpired',
        'certificateRejected',
        'trustAnchorMissing',
        'keystoreUnavailable',
        'signatureInvalid',
        'badRequest',
        'nativeFault',
        'nativeUnavailable',
      ];
      for (final kind in kinds) {
        final error = PkiError.fromJson(<String, Object?>{'kind': kind});
        expect(
          error,
          isNot(isA<UnknownPkiError>()),
          reason: '$kind fell through to unknown',
        );
        expect(error.kind, kind);
      }
    });

    test('a kind we have not heard of is a refusal, never a success', () {
      final error = PkiError.fromJson(<String, Object?>{
        'kind': 'quantumRefusal',
        'detail': 'from a newer library',
      });
      expect(error, isA<UnknownPkiError>());
      expect(error.blocksNewSessions, isTrue);
      expect(error.degradesLikeOffline, isFalse);
      expect(error.detail, 'from a newer library');
    });

    test('an index instead of a name is not accepted as a kind', () {
      // The whole reason enumerations cross by name: a `1` must mean nothing.
      expect(
        PkiError.fromJson(<String, Object?>{'kind': 1}),
        isA<UnknownPkiError>(),
      );
      expect(
        PkiError.fromJson(<String, Object?>{'kind': '1'}),
        isA<UnknownPkiError>(),
      );
    });
  });

  group('the offline rule', () {
    test('an expired certificate degrades like an absent network', () {
      const error = CertificateExpired(1800000000);
      expect(error.degradesLikeOffline, isTrue);
      expect(error.stopsSelling, isFalse);
      expect(error.blocksNewSessions, isTrue);
      expect(
        error.tearsDownOpenSessions,
        isFalse,
        reason: 'a session already open is not torn down by the wall clock',
      );
      expect(error.isSecurityEvent, isTrue);
    });

    test('so do a missing certificate, a missing anchor and a silent CA', () {
      for (final error in <PkiError>[
        const CertificateNotFound(),
        const TrustAnchorMissing(),
        const CaUnreachable('no route to the shop server'),
      ]) {
        expect(error.degradesLikeOffline, isTrue, reason: error.kind);
        expect(error.stopsSelling, isFalse, reason: error.kind);
      }
    });

    test('a refusal is a decision, not a network condition', () {
      for (final error in <PkiError>[
        const CertificateRejected('UnknownIssuer'),
        const InviteInvalid(),
        const InviteExpired(0),
        const SignatureInvalid(),
        const BadRequest('no such operation'),
        const NativeFault('a panic'),
        const NativeUnavailable('no library'),
        const CaNotHere('not the authority'),
      ]) {
        expect(error.degradesLikeOffline, isFalse, reason: error.kind);
      }
    });

    test('nothing whatsoever stops selling', () {
      for (final error in <PkiError>[
        const CertificateExpired(0),
        const CertificateRejected('revoked'),
        const NativeUnavailable('the library is missing entirely'),
        const KeystoreUnavailable('the disk is read-only'),
      ]) {
        expect(error.stopsSelling, isFalse, reason: error.kind);
      }
    });

    test('only a revocation closes what is already open', () {
      expect(
        const CertificateRejected(
          'certificate abc is revoked',
        ).tearsDownOpenSessions,
        isTrue,
      );
      expect(
        const CertificateRejected('UnknownIssuer').tearsDownOpenSessions,
        isFalse,
      );
      expect(const CertificateExpired(0).tearsDownOpenSessions, isFalse);
    });

    test('an expired certificate keeps the facts the owner needs', () {
      final error =
          PkiError.fromJson(<String, Object?>{
                'kind': 'certificateExpired',
                'expiredAt': 1800000000,
                'info': <String, Object?>{'subjectMachineId': 'till-17'},
              })
              as CertificateExpired;
      expect(error.expiredAt.toIso8601String(), startsWith('2027-01-15'));
      expect(error.info!['subjectMachineId'], 'till-17');
    });
  });

  group('results', () {
    test('fold picks the branch that happened', () {
      const ok = PkiOk<int>(7);
      const err = PkiErr<int>(InviteInvalid());
      expect(ok.fold((int v) => 'v$v', (PkiError e) => 'e'), 'v7');
      expect(
        err.fold((int v) => 'v$v', (PkiError e) => e.kind),
        'inviteInvalid',
      );
    });

    test('map leaves a failure alone', () {
      const err = PkiErr<int>(InviteInvalid());
      final mapped = err.map<String>((int v) => 'never');
      expect(mapped.errorOrNull, isA<InviteInvalid>());
    });
  });
}
