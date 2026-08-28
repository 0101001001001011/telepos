import 'package:telepos/domain/usecases/agent/bonus_service.dart';

abstract class LoyaltySmsService {
  Future<SmsCodeResult> sendCode(int phone);

  Future<SmsVerifyResult> verifyCode(int phone, String code);

  Future<SmsCodeResult> resendCode(int phone);

  int get resendDelaySeconds => 60;
}

class SmsCodeResult {
  const SmsCodeResult({
    required this.success,
    this.expiresInSeconds,
    this.errorMessage,
  });

  final bool success;
  final int? expiresInSeconds;
  final String? errorMessage;

  factory SmsCodeResult.sent({int expiresIn = 300}) =>
      SmsCodeResult(success: true, expiresInSeconds: expiresIn);

  factory SmsCodeResult.failed(String message) =>
      SmsCodeResult(success: false, errorMessage: message);
}

class SmsVerifyResult {
  const SmsVerifyResult({
    required this.success,
    this.sessionToken,
    this.errorMessage,
    this.attemptsRemaining,
  });

  final bool success;
  final String? sessionToken;
  final String? errorMessage;
  final int? attemptsRemaining;

  factory SmsVerifyResult.verified(String token) =>
      SmsVerifyResult(success: true, sessionToken: token);

  factory SmsVerifyResult.failed(String message, {int? attemptsRemaining}) =>
      SmsVerifyResult(
        success: false,
        errorMessage: message,
        attemptsRemaining: attemptsRemaining,
      );
}
