import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/auth/identification_attribute.dart';
import 'package:telepos/domain/entities/auth/identification_result.dart';
import 'package:telepos/domain/services/role_identification_service.dart';

class RoleIdentificationServiceImpl implements RoleIdentificationService {
  RoleIdentificationServiceImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<IdentificationResult> identify(String code) async {
    if (!IdentificationAttribute.isValid(code)) {
      _logger.warning('RoleIdentification: invalid code format');
      return IdentificationResult.notIdentified;
    }

    final attr = IdentificationAttribute(code);

    final user = await _db.userDao.findById(attr.userId);
    if (user == null) {
      _logger.warning('RoleIdentification: user ${attr.userId} not found');
      return IdentificationResult.notIdentified;
    }

    final thisPos = await _db.thisPosDao.get();

    final result = PinCredential.check(
      pin: attr.password,
      stored: user.passwordEnc,
      // Only used to read a record written before the PBKDF2 scheme.
      legacyPublicKeyBase64: thisPos?.rsaPublicKey,
    );

    switch (result.outcome) {
      case PinCheckOutcome.ok:
        if (result.needsUpgrade) {
          await _upgradeStoredPin(attr.userId, result.upgradedStorage!);
        }
      case PinCheckOutcome.wrong:
        _logger.info(
          'RoleIdentification: PIN mismatch for user ${attr.userId}',
        );
        return IdentificationResult.notIdentified;
      case PinCheckOutcome.noPinSet:
        // This is a supervisor proving an override with a scanned or typed
        // code. A user with no PIN stored proves nothing by it — under the
        // superseded implementation this branch returned "identified" for any
        // code at all, which handed the override to whoever knew the user id.
        // Someone who has to authorise operations needs a PIN; the fix for
        // this state is to set one, not to be let through.
        _logger.warning(
          'RoleIdentification: user ${attr.userId} has no PIN set — cannot '
          'authorise anything until one is set',
        );
        return IdentificationResult.notIdentified;
      case PinCheckOutcome.unreadable:
        _logger.error(
          'RoleIdentification: stored credential for user ${attr.userId} '
          'cannot be read — the PIN has to be set again',
        );
        return IdentificationResult.notIdentified;
    }

    final roleIndex = user.role;
    if (roleIndex == null ||
        roleIndex < 0 ||
        roleIndex >= UserRole.values.length) {
      _logger.warning(
        'RoleIdentification: invalid role for user ${attr.userId}',
      );
      return IdentificationResult.hasNoPermission;
    }
    final role = UserRole.values[roleIndex];
    if (role.index <= UserRole.administrator.index) {
      _logger.info(
        'RoleIdentification: user ${attr.userId} identified as $role',
      );
      return IdentificationResult.ok;
    }

    _logger.info(
      'RoleIdentification: user ${attr.userId} has no permission (role: $role)',
    );
    return IdentificationResult.hasNoPermission;
  }

  /// Replaces a proved-correct pre-upgrade record with the current scheme.
  ///
  /// A failure here does not fail the identification that just succeeded — the
  /// old record still verifies, and the upgrade is retried next time.
  Future<void> _upgradeStoredPin(int userId, String storage) async {
    try {
      await _db.userDao.updateUser(
        userId,
        UsersCompanion(passwordEnc: Value(storage)),
      );
      _logger.info(
        'RoleIdentification: PIN of user $userId upgraded to PBKDF2',
      );
    } catch (e, st) {
      // safeErrorText, не сам объект — тот же риск и тот же приём, что у
      // `AuthServiceImpl._upgradeStoredPin` и `LocalAuthRepository.login`
      // (найдено финальным разбором ветки
      // 2026-08-20-browser-terminal-login): запрос здесь пишет
      // `password_enc`, и `SqliteException.toString()` печатает параметры.
      _logger.warning(
        'RoleIdentification: PIN upgrade for user $userId failed '
        '(${safeErrorText(e)})',
        null,
        st,
      );
    }
  }
}
