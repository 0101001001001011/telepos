import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'legacy_pin_cipher.dart';

/// What a PIN check concluded.
///
/// It is an enum and not a `bool` on purpose. The superseded implementation
/// answered "no PIN is stored" with `true` from *inside* the verification
/// function, so all four call sites inherited "any PIN opens a PIN-less
/// account" without a line of code saying so. "No PIN set" is a real state in
/// this product — the wizard deliberately creates an owner with
/// `passwordEnc: null` when no PIN was collected
/// (`lib/data/setup/setup_repository_local.dart`) — but what it *means* differs
/// per call site, so each call site has to spell it out.
enum PinCheckOutcome {
  /// The PIN matches the stored credential.
  ok,

  /// A credential is stored and the PIN does not match it.
  wrong,

  /// Nothing is stored for this user. Not a match and not a mismatch: there is
  /// nothing to check against. The login screen treats this as "walk-up login
  /// allowed"; every other caller treats it as "cannot prove who you are".
  noPinSet,

  /// Something is stored but it cannot be read: an unknown encoding, or a
  /// pre-upgrade record on a till whose legacy RSA key is gone. Never report
  /// this as a mismatch — the operator did nothing wrong and re-typing will not
  /// help.
  unreadable,
}

/// The result of [PinCredential.check].
class PinCheckResult {
  const PinCheckResult(this.outcome, {this.upgradedStorage});

  final PinCheckOutcome outcome;

  /// Set exactly when [outcome] is [PinCheckOutcome.ok] **and** the value that
  /// was stored used the superseded scheme.
  ///
  /// The caller must write this into `Users.passwordEnc`. That write is the
  /// whole migration: the old record is proved correct once, by the operator
  /// typing the PIN they already know, and is replaced on the spot. Nobody is
  /// asked to choose a new PIN and nobody is locked out.
  final String? upgradedStorage;

  bool get isOk => outcome == PinCheckOutcome.ok;

  bool get needsUpgrade => upgradedStorage != null;
}

/// How a PIN is stored, and the only way to check one.
///
/// Storage format, one line of text in `Users.passwordEnc`:
///
/// ```
/// pbkdf2$sha256$<iterations>$<salt base64>$<derived key base64>
/// ```
///
/// Every parameter travels with the value, so the work factor can be raised
/// later without a migration and without invalidating anything already stored:
/// an old record keeps verifying at its own iteration count.
///
/// **Pure Dart, deliberately.** PIN entry runs in the browser build as well as
/// on a till, and `dart:ffi` does not exist on web, so `rk_pki`'s argon2 — or
/// any native hash — cannot be reached from shared code. `pointycastle`'s
/// PBKDF2 compiles for every platform this product runs on, which keeps
/// verification local. The alternative — asking the till over HTTP through the
/// two-layer seam — was rejected: it would put a network round trip in front of
/// every keypress of every login (`LoginNotifier.addDigit` verifies on each
/// digit), and a till that cannot reach its server would stop being able to
/// open a shift. Section 5б of `docs/system-architecture.md` is explicit that
/// losing the link must not stop trade.
///
/// **What this does and does not buy.** A four-digit PIN has ten thousand
/// values; no hash makes that space large. What changes is that the stored
/// value is not reversible, that two users who chose the same PIN store
/// different values, and that each guess costs a measured derivation instead of
/// a string comparison. An attacker holding the database file can still
/// enumerate a four-digit PIN — see the header of the test file for the
/// measured numbers.
class PinCredential {
  PinCredential._();

  static const String algorithm = 'pbkdf2';
  static const String digest = 'sha256';

  /// Work factor for newly written credentials.
  ///
  /// Measured with `tool/`-style benchmarking on the reference desktop
  /// (2026-08-01): 3.7 µs per iteration, so ~37 ms per derivation here. It is
  /// chosen against the till, not against a datasheet: `LoginNotifier` verifies
  /// on every keypress, and when no user has been picked it verifies against
  /// every user, on the UI thread, on hardware that includes a 1 GHz thin
  /// client (see the HP T510 notes). Ten times this number would multiply that
  /// lag by ten while multiplying the cost of enumerating a ten-thousand-value
  /// space by the same ten — which still leaves it enumerable. The honest
  /// defences against that space are elsewhere: not letting the database file
  /// leave the till (disk encryption, section 16) and raising the alarm on a
  /// run of failed logins.
  ///
  /// Stored per record, so raising it here upgrades each user the next time
  /// they log in and breaks nothing that already exists.
  static const int currentIterations = 10000;

  static const int saltLengthBytes = 16;
  static const int derivedKeyLengthBytes = 32;

  static final Random _secureRandom = Random.secure();

  static const String _prefix = '$algorithm\$$digest\$';

  /// Builds the value to store for [pin], with a fresh random salt.
  ///
  /// Called twice for the same PIN it returns two different strings. That is
  /// the point: it is what stops one precomputation from covering every user.
  static String create(
    String pin, {
    int iterations = currentIterations,
    Random? random,
  }) {
    if (pin.isEmpty) {
      throw ArgumentError.value(pin, 'pin', 'refusing to store an empty PIN');
    }
    if (iterations < 1) {
      throw ArgumentError.value(iterations, 'iterations', 'must be positive');
    }
    final rng = random ?? _secureRandom;
    final salt = Uint8List.fromList(
      List<int>.generate(saltLengthBytes, (_) => rng.nextInt(256)),
    );
    final derived = _derive(pin, salt, iterations);
    return '$_prefix$iterations\$${base64Encode(salt)}\$${base64Encode(derived)}';
  }

  /// Whether [stored] is written in the current scheme rather than the
  /// superseded one.
  static bool isCurrentScheme(String stored) => stored.startsWith(_prefix);

  /// Checks [pin] against what is stored for a user.
  ///
  /// [legacyPublicKeyBase64] is `ThisPos.rsaPublicKey`, and is needed only to
  /// read a record written before this scheme existed. A new installation has
  /// none and does not need one.
  static PinCheckResult check({
    required String pin,
    required String? stored,
    String? legacyPublicKeyBase64,
  }) {
    if (stored == null || stored.isEmpty) {
      return const PinCheckResult(PinCheckOutcome.noPinSet);
    }
    if (pin.isEmpty) {
      // An empty PIN is not a candidate under either scheme. Under the
      // superseded one it encrypts to the all-zero block, which is a value a
      // record could genuinely hold, so this guard is load-bearing, not tidy.
      return const PinCheckResult(PinCheckOutcome.wrong);
    }
    if (isCurrentScheme(stored)) {
      return _checkCurrent(pin, stored);
    }
    return _checkLegacy(pin, stored, legacyPublicKeyBase64);
  }

  static PinCheckResult _checkCurrent(String pin, String stored) {
    final parts = stored.split(r'$');
    // pbkdf2 / sha256 / iterations / salt / key
    if (parts.length != 5) {
      return const PinCheckResult(PinCheckOutcome.unreadable);
    }
    final iterations = int.tryParse(parts[2]);
    if (iterations == null || iterations < 1) {
      return const PinCheckResult(PinCheckOutcome.unreadable);
    }
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Decode(parts[3]);
      expected = base64Decode(parts[4]);
    } catch (_) {
      return const PinCheckResult(PinCheckOutcome.unreadable);
    }
    if (salt.isEmpty || expected.isEmpty) {
      return const PinCheckResult(PinCheckOutcome.unreadable);
    }

    final actual = _derive(pin, salt, iterations, length: expected.length);
    return _equalInConstantTime(actual, expected)
        ? const PinCheckResult(PinCheckOutcome.ok)
        : const PinCheckResult(PinCheckOutcome.wrong);
  }

  static PinCheckResult _checkLegacy(
    String pin,
    String stored,
    String? legacyPublicKeyBase64,
  ) {
    if (legacyPublicKeyBase64 == null || legacyPublicKeyBase64.isEmpty) {
      return const PinCheckResult(PinCheckOutcome.unreadable);
    }
    final reproduced = LegacyPinCipher.encryptPin(pin, legacyPublicKeyBase64);
    if (reproduced == null || reproduced.isEmpty) {
      return const PinCheckResult(PinCheckOutcome.unreadable);
    }
    if (!_equalInConstantTime(
      Uint8List.fromList(utf8.encode(reproduced)),
      Uint8List.fromList(utf8.encode(stored)),
    )) {
      return const PinCheckResult(PinCheckOutcome.wrong);
    }
    return PinCheckResult(PinCheckOutcome.ok, upgradedStorage: create(pin));
  }

  static Uint8List _derive(
    String pin,
    Uint8List salt,
    int iterations, {
    int length = derivedKeyLengthBytes,
  }) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, length));
    return kdf.process(Uint8List.fromList(utf8.encode(pin)));
  }

  /// Compares without an early exit, so the time taken does not say how many
  /// leading bytes were right.
  static bool _equalInConstantTime(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// One stored credential that a walk-up PIN is checked against.
class PinCandidate {
  const PinCandidate({required this.userId, required this.stored});

  final int userId;

  /// `Users.passwordEnc`.
  final String? stored;
}

/// Everything [sweepPinCandidates] needs, in one object because that is what
/// crossing an isolate boundary allows.
class PinSweepRequest {
  const PinSweepRequest({
    required this.pin,
    required this.candidates,
    this.legacyPublicKeyBase64,
  });

  final String pin;

  final List<PinCandidate> candidates;

  final String? legacyPublicKeyBase64;
}

/// Which candidate the PIN belonged to, if any.
class PinSweepResult {
  const PinSweepResult({this.userId, this.upgradedStorage});

  /// The user whose credential matched, or `null` when none did.
  final int? userId;

  /// Set exactly when the matched record used the superseded scheme. The
  /// caller writes it to `Users.passwordEnc` — see [PinCheckResult].
  final String? upgradedStorage;

  bool get isMatch => userId != null;
}

/// Checks [PinSweepRequest.pin] against every candidate and reports the first
/// that matches.
///
/// **Top-level and pure so it can be handed to `compute`.** Each candidate
/// costs a full PBKDF2 derivation — the salts differ per user, so there is no
/// work to share between them and the cost is unavoidably linear in the number
/// of candidates. Measured in the test VM at the shipped work factor: ~206 ms
/// per derivation, so fifteen candidates are three seconds. On the interface
/// isolate that is three seconds of frozen till per keypress, which is why
/// this function exists apart from the caller and why the caller runs it
/// elsewhere. Task 11 (2026-08-20) removed the screen-side cap this doc
/// used to name here (`LoginState.walkUpMaxUsers`) along with the rest of the
/// database-reading login screen; the sweep now runs on the till in
/// `LocalAuthRepository._matchAll`, and its 'count' is simply however many
/// users at this till have a PIN set — there is no separate cap to keep in
/// sync any more.
///
/// Candidates with nothing stored are skipped rather than matched: "no PIN
/// set" is a decision for a call site that knows which user was meant, and a
/// sweep by definition does not.
///
/// **Not fit for login as of 2026-08-20 review of the browser-terminal-login
/// work.** It returns on the *first* match — exactly the defect that work
/// fixed: two cashiers sharing a PIN must be an ambiguous-PIN rejection, not
/// a login as whichever of them happens to sort first. `LocalAuthRepository._matchAll`
/// (`lib/data/auth/local_auth_repository.dart`) is the one login-safe sweep —
/// it collects every match before deciding — and it is the only caller login
/// has, on or off the till. This function is kept, not deleted, because it is
/// still a tested, working primitive with no defect of its own outside the
/// login use it was never meant for; deleting a tested primitive as a side
/// effect of an unrelated review was not this review's call to make either.
/// Reach for [LocalAuthRepository._matchAll]'s pattern instead.
@Deprecated(
  'First-match-wins is unsafe for login: two cashiers sharing a PIN must be '
  'AuthRejectionReason.ambiguousPin, not a login as the first one found. Use '
  'LocalAuthRepository._matchAll (lib/data/auth/local_auth_repository.dart), '
  'which collects every match before deciding.',
)
PinSweepResult sweepPinCandidates(PinSweepRequest request) {
  for (final candidate in request.candidates) {
    final stored = candidate.stored;
    if (stored == null || stored.isEmpty) continue;

    final result = PinCredential.check(
      pin: request.pin,
      stored: stored,
      legacyPublicKeyBase64: request.legacyPublicKeyBase64,
    );

    if (result.isOk) {
      return PinSweepResult(
        userId: candidate.userId,
        upgradedStorage: result.upgradedStorage,
      );
    }
  }
  return const PinSweepResult();
}
