import 'package:telepos/domain/usecases/agent/bonus_service.dart';
import 'package:telepos/domain/usecases/agent/loyalty_sms_service.dart';

class LoyaltySmsServiceImpl implements LoyaltySmsService {
  @override
  int get resendDelaySeconds => 60;

  @override
  Future<SmsCodeResult> sendCode(int phone) async {
    throw const NoInternetConnectionException(
      'Отправка SMS требует подключения к интернету',
    );
  }

  @override
  Future<SmsVerifyResult> verifyCode(int phone, String code) async {
    throw const NoInternetConnectionException(
      'Проверка SMS-кода требует подключения к интернету',
    );
  }

  @override
  Future<SmsCodeResult> resendCode(int phone) async {
    throw const NoInternetConnectionException(
      'Повторная отправка SMS требует подключения к интернету',
    );
  }
}
