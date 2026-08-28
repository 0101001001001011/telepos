import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class PhoneAuthHandler {
  final TdLibClient _client;
  final TdLibLogger _logger;

  String? _lastPhoneNumber;

  PhoneAuthHandler({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  String? get lastPhoneNumber => _lastPhoneNumber;

  Future<void> sendPhoneNumber(String phoneNumber) async {
    final normalized = _normalizePhoneNumber(phoneNumber);
    _lastPhoneNumber = normalized;

    _logger.logAuthState('Sending phone number');

    await _client.setAuthenticationPhoneNumber(normalized);
  }

  Future<void> submitCode(String code) async {
    _logger.logAuthState('Submitting verification code');

    await _client.checkAuthenticationCode(code.trim());
  }

  Future<void> resendCode() async {
    _logger.logAuthState('Resending verification code');

    await _client.sendSync({'@type': 'resendAuthenticationCode'});
  }

  String _normalizePhoneNumber(String phone) {
    var normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (normalized.startsWith('8') && normalized.length == 11) {
      normalized = '+7${normalized.substring(1)}';
    }

    if (!normalized.startsWith('+')) {
      normalized = '+$normalized';
    }

    return normalized;
  }
}
