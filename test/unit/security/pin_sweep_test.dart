import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/security/legacy_pin_cipher.dart';
import 'package:telepos/core/security/pin_credential.dart';

/// Task 11 (2026-08-20) moved PIN checking off this screen entirely: it now
/// asks `AuthRepository.login()`, and the till checks the PIN — on the till,
/// `LocalAuthRepository` matches candidates one at a time with
/// `PinCredential.check` inside `Isolate.run`, not with the sweep below.
///
/// `sweepPinCandidates` and the pure-function group under it are kept and
/// still proven here: nothing currently calls the function in production,
/// but deleting a tested, working primitive as a side effect of an unrelated
/// screen refactor was not this task's call to make. What **is** this task's
/// call is the two groups that tested code this same task deleted:
/// `pinSweepRunner` (the screen's own isolate indirection, gone with the
/// screen's local PIN check) and `LoginState.walkUpAllowed`/`walkUpMaxUsers`
/// (the screen no longer decides walk-up at all — the till answers
/// `AuthRejectionReason.walkUpDisabled`, see
/// `lib/data/auth/local_auth_repository.dart` and
/// `test/data/auth/local_auth_repository_login_test.dart`). Both groups are
/// removed below along with the imports they alone needed.
void main() {
  group('sweepPinCandidates', () {
    test('finds the one user the PIN belongs to', () {
      final aigul = PinCredential.create('1111');
      final bekzat = PinCredential.create('2222');
      final dana = PinCredential.create('3333');

      final result = sweepPinCandidates(
        PinSweepRequest(
          pin: '2222',
          candidates: [
            PinCandidate(userId: 1, stored: aigul),
            PinCandidate(userId: 2, stored: bekzat),
            PinCandidate(userId: 3, stored: dana),
          ],
        ),
      );

      expect(result.isMatch, isTrue);
      expect(result.userId, 2);
    });

    test('answers "nobody" rather than picking someone', () {
      final result = sweepPinCandidates(
        PinSweepRequest(
          pin: '9999',
          candidates: [
            PinCandidate(userId: 1, stored: PinCredential.create('1111')),
            PinCandidate(userId: 2, stored: PinCredential.create('2222')),
          ],
        ),
      );

      expect(result.isMatch, isFalse);
      expect(result.userId, isNull);
    });

    test('a user with no PIN stored is skipped, not matched', () {
      // The state is real — the setup wizard creates an owner with
      // `passwordEnc: null`. Matching it here would mean any four digits typed
      // at an unselected keypad log in as that owner, which is precisely the
      // defect the enum in PinCredential exists to stop being inherited
      // silently.
      final result = sweepPinCandidates(
        PinSweepRequest(
          pin: '1234',
          candidates: const [
            PinCandidate(userId: 1, stored: null),
            PinCandidate(userId: 2, stored: ''),
          ],
        ),
      );

      expect(
        result.isMatch,
        isFalse,
        reason: 'an empty credential is nothing to match against',
      );
    });

    test('the first match wins and later candidates are not consulted', () {
      // Two users who chose the same PIN store different values, so a sweep
      // can still only match one — but which one must be defined rather than
      // incidental, because the second would be logged in as the first.
      const pin = '4321';
      final result = sweepPinCandidates(
        PinSweepRequest(
          pin: pin,
          candidates: [
            PinCandidate(userId: 7, stored: PinCredential.create(pin)),
            PinCandidate(userId: 8, stored: PinCredential.create(pin)),
          ],
        ),
      );

      expect(result.userId, 7);
    });

    test('a matched pre-upgrade record comes back with its replacement', () {
      final legacyKey = LegacyPinCipher.generatePublicKeyBase64();
      final legacyStored = LegacyPinCipher.encryptPin('5555', legacyKey)!;

      final result = sweepPinCandidates(
        PinSweepRequest(
          pin: '5555',
          candidates: [
            PinCandidate(userId: 1, stored: PinCredential.create('1111')),
            PinCandidate(userId: 2, stored: legacyStored),
          ],
          legacyPublicKeyBase64: legacyKey,
        ),
      );

      expect(result.userId, 2);
      expect(
        result.upgradedStorage,
        isNotNull,
        reason: 'the sweep must hand the caller the value to write back, '
            'otherwise the walk-up path never upgrades anybody',
      );
      expect(
        PinCredential.isCurrentScheme(result.upgradedStorage!),
        isTrue,
      );
      expect(
        PinCredential.check(pin: '5555', stored: result.upgradedStorage).isOk,
        isTrue,
      );
    });

    test('a match in the current scheme asks for no rewrite', () {
      final result = sweepPinCandidates(
        PinSweepRequest(
          pin: '1111',
          candidates: [
            PinCandidate(userId: 1, stored: PinCredential.create('1111')),
          ],
        ),
      );

      expect(result.isMatch, isTrue);
      expect(
        result.upgradedStorage,
        isNull,
        reason: 'rewriting a record that is already current is a pointless '
            'disk write on every single login',
      );
    });
  });
}
