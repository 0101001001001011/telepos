import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class TwoFactorHandler {
  final TdLibClient _client;
  final TdLibLogger _logger;

  TwoFactorHandler({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  Future<void> submitPassword(String password) async {
    _logger.logAuthState('Submitting 2FA password');

    await _client.checkAuthenticationPassword(password);
  }

  Future<void> requestPasswordRecovery() async {
    _logger.logAuthState('Requesting password recovery');

    await _client.send({'@type': 'requestAuthenticationPasswordRecovery'});
  }

  Future<void> submitRecoveryCode(String code) async {
    _logger.logAuthState('Submitting recovery code');

    await _client.send({
      '@type': 'checkAuthenticationPasswordRecoveryCode',
      'recovery_code': code,
    });
  }

  Future<void> recoverPassword({
    required String recoveryCode,
    String? newPassword,
    String? newHint,
  }) async {
    _logger.logAuthState('Recovering password');

    await _client.send({
      '@type': 'recoverAuthenticationPassword',
      'recovery_code': recoveryCode,
      'new_password': newPassword ?? '',
      'new_hint': newHint ?? '',
    });
  }
}
