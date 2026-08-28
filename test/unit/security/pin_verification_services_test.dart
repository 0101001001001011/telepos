import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/security/legacy_pin_cipher.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/auth_service_impl.dart';
import 'package:telepos/data/services/role_identification_service_impl.dart';
import 'package:telepos/domain/entities/auth/identification_attribute.dart';
import 'package:telepos/domain/entities/auth/identification_result.dart';

/// The two services that used to inherit `verifyPin`'s hidden "no stored value
/// means yes", over a real database rather than a fake, so that the upgrade
/// write is proved by reading the row back.
///
/// Seed (qa-depth, rule of zero — more than one user, records that must **not**
/// match, national characters across the five languages):
///
/// | id | name           | role  | stored                          |
/// | -- | -------------- | ----- | ------------------------------- |
/// | 1  | Айгүл Қасымова | owner | PBKDF2 of `1234`                |
/// | 2  | Бекзат Дүйсен  | admin | PBKDF2 of `1234` — same PIN     |
/// | 3  | Ысык-Көл Асан  | admin | pre-upgrade record of `1234`    |
/// | 4  | Toshkent Sardor| admin | nothing (`null`)                |
/// | 5  | Гүлнара Жапар  | cash. | PBKDF2 of `123456`              |
/// | 6  | Дүкен №2 Оператор| cash.| empty string                   |
void main() {
  const pinShared = '1234';
  const pinLong = '123456';

  late String legacyKey;

  setUpAll(() {
    // One 2048-bit key for the file: a real installation has exactly one, and
    // generating it is the slowest thing here.
    legacyKey = LegacyPinCipher.generatePublicKeyBase64();
  });

  late AppDatabase db;
  late AuthServiceImpl auth;
  late RoleIdentificationServiceImpl roles;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.thisPosDao.insertInitialConfig(
      companyName: 'ТОО ТестПОС',
      iinbin: '123456789012',
      cashBoxName: 'Касса-1',
      countryCode: 0,
      currencyCode: 0,
      currencySymbol: '₸',
      currencyNameShort: 'KZT',
      paperWidth: 48,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      // An installation that predates PBKDF2 still holds its RSA key, and
      // that is the only thing it is still read for.
      rsaPublicKey: legacyKey,
    );

    await _seedUser(db, 1, 'Айгүл Қасымова', 0, PinCredential.create(pinShared));
    await _seedUser(db, 2, 'Бекзат Дүйсен', 1, PinCredential.create(pinShared));
    await _seedUser(
      db,
      3,
      'Ысык-Көл Асан',
      1,
      LegacyPinCipher.encryptPin(pinShared, legacyKey),
    );
    await _seedUser(db, 4, 'Toshkent Sardor', 1, null);
    await _seedUser(db, 5, 'Гүлнара Жапар', 3, PinCredential.create(pinLong));
    await _seedUser(db, 6, 'Дүкен №2 Оператор', 3, '');

    final logger = Talker();
    auth = AuthServiceImpl(db: db, logger: logger);
    roles = RoleIdentificationServiceImpl(db: db, logger: logger);
  });

  group('the seed itself', () {
    test('two users with the same PIN do not share a stored value', () async {
      final one = (await db.userDao.findById(1))!.passwordEnc;
      final two = (await db.userDao.findById(2))!.passwordEnc;

      expect(one, isNotNull);
      expect(
        one,
        isNot(two),
        reason:
            'both chose 1234; under the superseded scheme these two rows were '
            'byte-identical, and one precomputation covered every user at once',
      );
      expect(one, isNot(contains(pinShared)));
    });

    test('the pre-upgrade row really is in the old scheme', () async {
      // Without this the upgrade tests below could be passing because the
      // fixture was quietly built by the new code — the shape that has caught
      // this project before.
      final legacy = (await db.userDao.findById(3))!.passwordEnc!;
      expect(PinCredential.isCurrentScheme(legacy), isFalse);
      expect(legacy, LegacyPinCipher.encryptPin(pinShared, legacyKey));
    });
  });

  group('AuthService.verifyUserPin', () {
    test('accepts the right PIN', () async {
      expect(await auth.verifyUserPin(pinShared, 1), isTrue);
    });

    test('rejects a wrong PIN', () async {
      expect(await auth.verifyUserPin('9999', 1), isFalse);
      expect(await auth.verifyUserPin('123', 1), isFalse);
      expect(await auth.verifyUserPin('', 1), isFalse);
    });

    test("rejects another user's PIN", () async {
      expect(
        await auth.verifyUserPin(pinLong, 1),
        isFalse,
        reason: 'user 5 chose 123456; it must not open user 1',
      );
      expect(
        await auth.verifyUserPin(pinShared, 5),
        isFalse,
        reason: 'user 1 chose 1234; it must not open user 5',
      );
    });

    test('rejects an unknown user', () async {
      expect(await auth.verifyUserPin(pinShared, 999), isFalse);
    });

    test('refuses a user who has no PIN stored — the branch that used to be '
        'hidden', () async {
      // The superseded `RSAUtil.verifyPin` returned `true` when the stored
      // value was null or empty, from inside the verification function, so
      // this method authenticated user 4 against literally any string.
      expect(
        await auth.verifyUserPin('0000', 4),
        isFalse,
        reason: 'null passwordEnc: nothing to verify against',
      );
      expect(
        await auth.verifyUserPin('anything at all', 4),
        isFalse,
        reason: 'and it must not depend on what was typed',
      );
      expect(
        await auth.verifyUserPin('0000', 6),
        isFalse,
        reason: 'empty passwordEnc is the same state as null',
      );
    });

    test('a pre-upgrade record verifies once and is re-stored, then verifies '
        'under the new scheme', () async {
      final before = (await db.userDao.findById(3))!.passwordEnc!;
      expect(PinCredential.isCurrentScheme(before), isFalse);

      expect(
        await auth.verifyUserPin(pinShared, 3),
        isTrue,
        reason: 'nobody re-enters a PIN: the old record still proves itself',
      );

      final after = (await db.userDao.findById(3))!.passwordEnc!;
      expect(
        PinCredential.isCurrentScheme(after),
        isTrue,
        reason: 'a successful check rewrites the row in the current scheme',
      );
      expect(after, isNot(before));

      // Prove the row no longer depends on the legacy key: take it away
      // entirely and check again.
      await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
          .write(const ThisPosEntriesCompanion(rsaPublicKey: Value(null)));
      expect((await db.thisPosDao.get())!.rsaPublicKey, isNull);

      expect(
        await auth.verifyUserPin(pinShared, 3),
        isTrue,
        reason: 'upgraded for good, with the old key gone',
      );
      expect(
        await auth.verifyUserPin('9999', 3),
        isFalse,
        reason: 'and still rejecting',
      );
      expect(
        (await db.userDao.findById(3))!.passwordEnc,
        after,
        reason: 'a user upgrades once — the second login rewrites nothing',
      );
    });

    test('a wrong PIN against a pre-upgrade record changes nothing', () async {
      final before = (await db.userDao.findById(3))!.passwordEnc;
      expect(await auth.verifyUserPin('9999', 3), isFalse);
      expect((await db.userDao.findById(3))!.passwordEnc, before);
    });

    test('the upgrade touches only the PIN of only that user', () async {
      final othersBefore = {
        for (final id in [1, 2, 4, 5, 6])
          id: (await db.userDao.findById(id))!.passwordEnc,
      };
      final row3Before = (await db.userDao.findById(3))!;

      expect(await auth.verifyUserPin(pinShared, 3), isTrue);

      for (final entry in othersBefore.entries) {
        expect(
          (await db.userDao.findById(entry.key))!.passwordEnc,
          entry.value,
          reason: 'user ${entry.key} was not being logged in',
        );
      }
      final row3After = (await db.userDao.findById(3))!;
      expect(row3After.name, row3Before.name);
      expect(row3After.role, row3Before.role);
      expect(row3After.status, row3Before.status);
    });
  });

  group('RoleIdentificationService.identify', () {
    test('identifies an administrator by the right code', () async {
      expect(await roles.identify(_code(pinShared, 2)), IdentificationResult.ok);
    });

    test('does not identify on a wrong PIN', () async {
      expect(
        await roles.identify(_code('9999', 2)),
        IdentificationResult.notIdentified,
      );
    });

    test('a cashier is identified but has no permission', () async {
      expect(
        await roles.identify(_code(pinLong.substring(0, 4), 5)),
        IdentificationResult.notIdentified,
        reason: 'user 5 chose 123456, so 1234 is simply the wrong PIN',
      );
      // And with the right PIN the answer is about the role, not the PIN.
      await db.userDao.updateUser(
        5,
        UsersCompanion(passwordEnc: Value(PinCredential.create(pinShared))),
      );
      expect(
        await roles.identify(_code(pinShared, 5)),
        IdentificationResult.hasNoPermission,
      );
    });

    test('refuses a user with no PIN stored, whatever code is presented',
        () async {
      // Previously this returned `ok`: `verifyPin` answered `true` for a null
      // stored value, so anyone who knew user 4's id could authorise an
      // override with four arbitrary digits.
      expect(
        await roles.identify(_code('0000', 4)),
        IdentificationResult.notIdentified,
      );
      expect(
        await roles.identify(_code('9999', 4)),
        IdentificationResult.notIdentified,
      );
      expect(
        await roles.identify(_code('0000', 6)),
        IdentificationResult.notIdentified,
        reason: 'empty stored value is the same state',
      );
    });

    test('a pre-upgrade record identifies once and is re-stored', () async {
      expect(await roles.identify(_code(pinShared, 3)), IdentificationResult.ok);

      final after = (await db.userDao.findById(3))!.passwordEnc!;
      expect(PinCredential.isCurrentScheme(after), isTrue);

      expect(
        await roles.identify(_code(pinShared, 3)),
        IdentificationResult.ok,
        reason: 'and keeps working afterwards',
      );
    });

    test('a malformed code is refused', () async {
      expect(await roles.identify('abc'), IdentificationResult.notIdentified);
      expect(await roles.identify('12'), IdentificationResult.notIdentified);
    });

    test('an unknown user is refused', () async {
      expect(
        await roles.identify(_code(pinShared, 999)),
        IdentificationResult.notIdentified,
      );
    });
  });
}

Future<void> _seedUser(
  AppDatabase db,
  int id,
  String name,
  int role,
  String? passwordEnc,
) {
  return db.userDao.insertUser(
    UsersCompanion(
      id: Value(id),
      name: Value(name),
      role: Value(role),
      status: const Value('active'),
      editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      passwordEnc: Value(passwordEnc),
    ),
  );
}

/// Builds the identification code `IdentificationAttribute` expects: four
/// scrambled digits followed by the user id.
///
/// The scrambling is derived by asking [IdentificationAttribute] itself which
/// input character yields which digit, rather than re-deriving its arithmetic
/// here — a second copy of that formula would agree with a broken original.
String _code(String pin, int userId) {
  assert(pin.length == 4);
  final buffer = StringBuffer();
  for (final digit in pin.split('')) {
    buffer.write(_scramble(digit));
  }
  return '$buffer$userId';
}

String _scramble(String digit) {
  for (var c = 0; c <= 9; c++) {
    final candidate = '$c';
    final probe = IdentificationAttribute('${candidate * 4}1');
    if (probe.password[0] == digit) return candidate;
  }
  throw StateError('no input character maps to "$digit"');
}
