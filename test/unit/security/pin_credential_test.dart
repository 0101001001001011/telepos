import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/security/legacy_pin_cipher.dart';
import 'package:telepos/core/security/pin_credential.dart';

/// What this file proves, and what it deliberately does not.
///
/// The scheme it replaced was deterministic, unpadded RSA under a public key
/// stored in the same database as the value it protected. Two facts followed:
/// the same PIN always produced the same string, so one table covered every
/// user at once; and the key needed to build that table sat in
/// `ThisPos.rsaPublicKey`, in the file the attacker already has.
///
/// After this change the stored value is a PBKDF2-HMAC-SHA256 derivation over a
/// per-user random salt. What that buys, exactly:
///
/// - the stored value is not reversible;
/// - two users who picked the same PIN store different values, so a table built
///   for one is worthless against the other;
/// - each guess costs a derivation instead of a string comparison.
///
/// What it does **not** buy, and no scheme could: a four-digit PIN has ten
/// thousand values. Measured on the reference desktop at the shipped work
/// factor (10 000 iterations, 37 ms per derivation), enumerating one user's
/// four-digit PIN on one CPU core takes about six minutes, and a GPU shortens
/// that to seconds. An attacker holding the database file still gets the PIN.
/// The defences that actually matter for that threat are elsewhere: keeping the
/// file off the attacker's disk (section 16, disk encryption on the appliance
/// image) and raising the alarm on a run of failed logins (И76).
void main() {
  group('PinCredential — storage shape', () {
    test('the same PIN stored for two users produces two different values', () {
      const pin = '1234';

      final aigul = PinCredential.create(pin);
      final bekzat = PinCredential.create(pin);

      expect(
        aigul,
        isNot(bekzat),
        reason:
            'a per-user salt is the whole point: identical PINs must not share '
            'a stored value, or one precomputation covers both users',
      );
      expect(
        PinCredential.check(pin: pin, stored: aigul).isOk,
        isTrue,
        reason: 'both must still verify — different, not broken',
      );
      expect(PinCredential.check(pin: pin, stored: bekzat).isOk, isTrue);
    });

    test('the stored value carries no trace of the PIN itself', () {
      const pin = '4821';
      final stored = PinCredential.create(pin);

      expect(stored, isNot(pin));
      expect(
        stored.contains(pin),
        isFalse,
        reason: 'a stored value containing the PIN is not a hash',
      );
      expect(
        stored.startsWith('pbkdf2\$sha256\$10000\$'),
        isTrue,
        reason:
            'algorithm, digest and work factor travel with the value so the '
            'factor can be raised later without invalidating what exists',
      );
    });

    test('an empty PIN is refused at write time, not silently stored', () {
      expect(() => PinCredential.create(''), throwsArgumentError);
    });
  });

  group('PinCredential — checking', () {
    late String stored;

    setUp(() => stored = PinCredential.create('1234'));

    test('the right PIN is accepted', () {
      expect(PinCredential.check(pin: '1234', stored: stored).outcome,
          PinCheckOutcome.ok);
    });

    test('a wrong PIN is rejected', () {
      expect(PinCredential.check(pin: '9999', stored: stored).outcome,
          PinCheckOutcome.wrong);
    });

    test('a PIN that is a prefix of the right one is rejected', () {
      expect(PinCredential.check(pin: '123', stored: stored).outcome,
          PinCheckOutcome.wrong);
      expect(PinCredential.check(pin: '12345', stored: stored).outcome,
          PinCheckOutcome.wrong);
    });

    test('an empty PIN never matches a real credential', () {
      expect(PinCredential.check(pin: '', stored: stored).outcome,
          PinCheckOutcome.wrong);
    });

    test('a six-digit PIN round-trips and rejects its own four-digit prefix',
        () {
      final six = PinCredential.create('123456');
      expect(PinCredential.check(pin: '123456', stored: six).isOk, isTrue);
      expect(PinCredential.check(pin: '1234', stored: six).outcome,
          PinCheckOutcome.wrong);
    });

    test('a credential written at another work factor still verifies', () {
      // Raising `currentIterations` must not lock anyone out: the factor is
      // stored per record, so an older record verifies at its own count.
      final old = PinCredential.create('1234', iterations: 1000);
      expect(old.startsWith('pbkdf2\$sha256\$1000\$'), isTrue);
      expect(PinCredential.check(pin: '1234', stored: old).isOk, isTrue);
      expect(PinCredential.check(pin: '4321', stored: old).outcome,
          PinCheckOutcome.wrong);
    });
  });

  group('PinCredential — the empty stored value', () {
    // The superseded implementation answered `true` here, from inside the
    // verification function, so all four call sites inherited "any PIN opens a
    // PIN-less account" without a line of code saying so. "No PIN set" is a
    // real state in this product — `LocalSetupRepository` creates an owner with
    // `passwordEnc: null` when the wizard collected no PIN — so it is reported,
    // not silently decided, and each call site branches on it itself.
    test('null is reported as noPinSet, never as a match', () {
      final result = PinCredential.check(pin: '1234', stored: null);
      expect(result.outcome, PinCheckOutcome.noPinSet);
      expect(
        result.isOk,
        isFalse,
        reason:
            'this is the defect: the old code returned true here, so any PIN '
            'authenticated a PIN-less user everywhere except the login screen',
      );
    });

    test('an empty string is reported as noPinSet, never as a match', () {
      final result = PinCredential.check(pin: '0000', stored: '');
      expect(result.outcome, PinCheckOutcome.noPinSet);
      expect(result.isOk, isFalse);
    });

    test('noPinSet is distinguishable from a wrong PIN', () {
      expect(
        PinCredential.check(pin: '1234', stored: null).outcome,
        isNot(
          PinCredential.check(
            pin: '1234',
            stored: PinCredential.create('5555'),
          ).outcome,
        ),
        reason:
            'a caller that wants to allow a PIN-less user in must be able to '
            'tell that case from a mistyped PIN',
      );
    });
  });

  group('PinCredential — unreadable values', () {
    test('a value in no known scheme, with no legacy key, is unreadable', () {
      expect(
        PinCredential.check(pin: '1234', stored: 'not-a-credential').outcome,
        PinCheckOutcome.unreadable,
        reason:
            'reporting this as a wrong PIN sends the operator to re-type '
            'something that can never match',
      );
    });

    test('a truncated current-scheme value is unreadable, not a match', () {
      expect(
        PinCredential.check(pin: '1234', stored: 'pbkdf2\$sha256\$10000\$AAAA')
            .outcome,
        PinCheckOutcome.unreadable,
      );
    });

    test('a non-numeric work factor is unreadable, not a match', () {
      expect(
        PinCredential.check(
          pin: '1234',
          stored: 'pbkdf2\$sha256\$many\$AAAAAAAAAAAAAAAAAAAAAA==\$AAAA',
        ).outcome,
        PinCheckOutcome.unreadable,
      );
    });
  });

  group('PinCredential — upgrading a pre-PBKDF2 record', () {
    // 2048-bit RSA keygen is slow; one key for the whole group, as a real
    // installation has exactly one.
    late String legacyKey;

    setUpAll(() => legacyKey = LegacyPinCipher.generatePublicKeyBase64());

    test('the fixture really is the old scheme: same PIN, same stored value',
        () {
      // Guards against the trap that has caught this project before — a
      // fixture built with the new code, so that the broken and the fixed
      // implementation agree by coincidence and the upgrade test proves
      // nothing. If these two are ever unequal, the fixture stopped being a
      // legacy record and every assertion below is empty.
      final one = LegacyPinCipher.encryptPin('1234', legacyKey);
      final two = LegacyPinCipher.encryptPin('1234', legacyKey);
      expect(one, isNotNull);
      expect(
        one,
        two,
        reason:
            'the superseded transform is deterministic — that is the defect, '
            'and it is what makes this a valid pre-upgrade fixture',
      );
      expect(PinCredential.isCurrentScheme(one!), isFalse);
    });

    test('a correct PIN verifies against an old record and returns its '
        'replacement', () {
      final old = LegacyPinCipher.encryptPin('1234', legacyKey)!;

      final result = PinCredential.check(
        pin: '1234',
        stored: old,
        legacyPublicKeyBase64: legacyKey,
      );

      expect(result.isOk, isTrue, reason: 'nobody may be locked out');
      expect(
        result.needsUpgrade,
        isTrue,
        reason: 'the caller is told to re-store, which is the whole migration',
      );
      expect(PinCredential.isCurrentScheme(result.upgradedStorage!), isTrue);
    });

    test('the replacement verifies afterwards with no legacy key at all', () {
      final old = LegacyPinCipher.encryptPin('1234', legacyKey)!;
      final upgraded = PinCredential.check(
        pin: '1234',
        stored: old,
        legacyPublicKeyBase64: legacyKey,
      ).upgradedStorage!;

      final after = PinCredential.check(pin: '1234', stored: upgraded);
      expect(after.isOk, isTrue);
      expect(
        after.needsUpgrade,
        isFalse,
        reason: 'a user upgrades once, not on every login',
      );
      expect(
        PinCredential.check(pin: '9999', stored: upgraded).outcome,
        PinCheckOutcome.wrong,
        reason: 'the upgraded record must still reject a wrong PIN',
      );
    });

    test('two users with the same PIN diverge the moment they are upgraded',
        () {
      final sharedOld = LegacyPinCipher.encryptPin('1234', legacyKey)!;

      final first = PinCredential.check(
        pin: '1234',
        stored: sharedOld,
        legacyPublicKeyBase64: legacyKey,
      ).upgradedStorage!;
      final second = PinCredential.check(
        pin: '1234',
        stored: sharedOld,
        legacyPublicKeyBase64: legacyKey,
      ).upgradedStorage!;

      expect(
        first,
        isNot(second),
        reason:
            'the old records were byte-identical; the upgrade is what stops '
            'them being so',
      );
    });

    test('a wrong PIN against an old record is a mismatch and upgrades nothing',
        () {
      final old = LegacyPinCipher.encryptPin('1234', legacyKey)!;

      final result = PinCredential.check(
        pin: '9999',
        stored: old,
        legacyPublicKeyBase64: legacyKey,
      );

      expect(result.outcome, PinCheckOutcome.wrong);
      expect(result.upgradedStorage, isNull);
    });

    test('an old record with no legacy key is unreadable, not a mismatch', () {
      final old = LegacyPinCipher.encryptPin('1234', legacyKey)!;

      expect(
        PinCredential.check(pin: '1234', stored: old).outcome,
        PinCheckOutcome.unreadable,
      );
      expect(
        PinCredential.check(
          pin: '1234',
          stored: old,
          legacyPublicKeyBase64: 'garbage',
        ).outcome,
        PinCheckOutcome.unreadable,
      );
    });
  });
}
