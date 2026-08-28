import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/auth_service.dart';

class AuthServiceImpl implements AuthService {
  AuthServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<bool> authenticate(String key) async {
    _logger.info('AuthService: authenticating with key (offline mode)');

    if (!_isValidKeyFormat(key)) {
      throw const AuthorizationFailed('Invalid key format');
    }

    final localToken = 'local-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final thisPos = await _db.thisPosDao.get();
      if (thisPos != null) {
        await ((_db.update(
          _db.thisPosEntries,
        ))..where((tp) => tp.rId.equals(true))).write(
          ThisPosEntriesCompanion(key: Value(key), token: Value(localToken)),
        );
      } else {
        await _db
            .into(_db.thisPosEntries)
            .insert(
              ThisPosEntriesCompanion.insert(
                rId: const Value(true),
                key: Value(key),
                token: Value(localToken),
              ),
            );
      }

      _logger.info('AuthService: key and token saved (offline mode)');
      return true;
    } catch (e, st) {
      // Фраза и тип, не сам объект: запрос здесь — `INSERT`/`UPDATE ...
      // SET token = ?`, и `SqliteException.toString()` печатает
      // `parameters: …` — тот самый свежий токен устройства. `.handle(e,
      // ...)` отдавала бы `e` в `Talker` целиком — тот же приём, что уже
      // закрывает `_upgradeStoredPin` ниже, закрывает и это место: только
      // безопасный текст, исключение в `Talker` не передаётся.
      _logger.error(
        'AuthService: failed to save authentication data '
        '(${safeErrorText(e)})',
        null,
        st,
      );
      throw const AuthorizationFailed('Failed to save authentication data');
    }
  }

  bool _isValidKeyFormat(String key) {
    if (key.isEmpty) return false;

    if (key.startsWith('TELEPOS-')) {
      final parts = key.split('-');
      return parts.length >= 3;
    }

    return true;
  }

  @override
  Future<bool> hasKey() async {
    final thisPos = await _db.thisPosDao.get();
    final key = thisPos?.key;
    return key != null && key.isNotEmpty;
  }

  @override
  Future<bool> hasToken() async {
    final thisPos = await _db.thisPosDao.get();
    final token = thisPos?.token;
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> getToken() async {
    final thisPos = await _db.thisPosDao.get();
    return thisPos?.token;
  }

  @override
  Future<String?> getKey() async {
    final thisPos = await _db.thisPosDao.get();
    return thisPos?.key;
  }

  @override
  Future<bool> verifyUserPin(String pin, int userId) async {
    final user = await _db.userDao.findById(userId);
    if (user == null) {
      _logger.warning('AuthService: user $userId not found');
      return false;
    }

    final thisPos = await _db.thisPosDao.get();

    final result = PinCredential.check(
      pin: pin,
      stored: user.passwordEnc,
      // Only used to read a record written before the PBKDF2 scheme. A new
      // installation has no RSA key and does not need one.
      legacyPublicKeyBase64: thisPos?.rsaPublicKey,
    );

    switch (result.outcome) {
      case PinCheckOutcome.ok:
        if (result.needsUpgrade) {
          await _upgradeStoredPin(userId, result.upgradedStorage!);
        }
        return true;
      case PinCheckOutcome.wrong:
        return false;
      case PinCheckOutcome.noPinSet:
        // The branch the superseded implementation hid: it answered `true`
        // here, so this method authenticated a PIN-less user against any
        // string at all. This method's whole job is "prove you are this user
        // by PIN", and a user with no PIN cannot. The login screen is the one
        // place where "no PIN" legitimately means "walk up and in", and it
        // decides that itself, before asking (LoginNotifier.userHasNoPassword).
        _logger.warning(
          'AuthService: user $userId has no PIN set — nothing to verify '
          'against, refusing',
        );
        return false;
      case PinCheckOutcome.unreadable:
        _logger.error(
          'AuthService: stored credential for user $userId cannot be read '
          '(unknown encoding, or a pre-upgrade record and no legacy key). '
          'Re-typing will not help — the PIN has to be set again.',
        );
        return false;
    }
  }

  /// Replaces a proved-correct pre-upgrade record with the current scheme.
  ///
  /// Failing here must not fail the login that just succeeded: the operator
  /// typed the right PIN, and the old record still verifies. The upgrade is
  /// retried on the next login.
  Future<void> _upgradeStoredPin(int userId, String storage) async {
    try {
      await _db.userDao.updateUser(
        userId,
        UsersCompanion(passwordEnc: Value(storage)),
      );
      _logger.info('AuthService: PIN of user $userId upgraded to PBKDF2');
    } catch (e, st) {
      // safeErrorText, не сам объект: запрос здесь —
      // `UPDATE users SET password_enc = ?`, и `SqliteException.toString()`
      // печатает `parameters: …` — тот самый свежий хэш PIN. `.handle()`
      // рендерит первый довод тем же способом, что и `.warning()`
      // (`local_auth_repository.dart`, найдено финальным разбором ветки
      // 2026-08-20-browser-terminal-login) — тот же приём закрывает и это
      // место.
      _logger.warning(
        'AuthService: PIN upgrade for user $userId failed '
        '(${safeErrorText(e)})',
        null,
        st,
      );
    }
  }
}
