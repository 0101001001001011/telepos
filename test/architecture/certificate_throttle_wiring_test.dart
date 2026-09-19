/// Замок перебора сертификатов собран в кассе целиком — пункты 4 и 5 A7.
///
/// `main.dart` под тестом не поднимается, и три строки сборки, без которых
/// замок молча не работает, сторожатся здесь чтением исходника:
///
/// 1. Контейнер заводит **один** `CertificateThrottle` с журналом
///    безопасности — иначе `certificate_rate_limited` не оставляет следа
///    (живая приёмка 2026-09-13: не оставлял).
/// 2. `PaymentService` кассы — `ThrottledPaymentService` над этим замком:
///    без него экран оплаты самой кассы перебирает без предела.
/// 3. `main.dart` отдаёт `ApiServer` тот же замок: иначе у провода свой счёт
///    номера, и пять неудач с планшета не запирают номер для кассы.
///
/// Стенд обязан собирать `ApiServer` теми же доводами —
/// `stand_matches_till_test.dart` это уже сторожит.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  test('контейнер заводит замок с журналом и оборачивает им оплату', () {
    final locator = _code('lib/app/di/service_locator.dart');
    expect(
      RegExp(
        r'registerLazySingleton<CertificateThrottle>\([\s\S]{0,400}?'
        r'SecurityJournal',
      ).hasMatch(locator),
      isTrue,
      reason: 'замок без журнала — срабатывание не оставит следа',
    );
    expect(
      RegExp(
        r'registerLazySingleton<PaymentService>\(\s*\(\)\s*=>\s*'
        r'ThrottledPaymentService\(',
      ).hasMatch(locator),
      isTrue,
      reason: 'касса мимо провода проверяла бы сертификаты без замка',
    );
    // Решение заказчика 2026-09-15: счёт на кассе — по вошедшему кассиру.
    expect(
      RegExp(
        r'ThrottledPaymentService\([\s\S]{0,400}?'
        r'cashier:\s*getIt<CashierOnDuty>\(\)',
      ).hasMatch(locator),
      isTrue,
      reason: 'без кассира обёртка вернулась бы к общему счёту места',
    );
    expect(
      RegExp(r'registerLazySingleton<CashierOnDutyHolder>').hasMatch(locator),
      isTrue,
      reason: 'экрану входа некуда было бы вписать кассира',
    );
  });

  test('main.dart отдаёт ApiServer замок из контейнера', () {
    final main = _code('lib/main.dart');
    expect(
      RegExp(
        r'certificateThrottle:\s*GetIt\.I<CertificateThrottle>\(\)',
      ).hasMatch(main),
      isTrue,
    );
  });
}
