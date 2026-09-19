import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_rejection.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/shift/shift_status.dart';

void main() {
  group('AuthUser', () {
    test('в видимой структуре AuthUser ровно четыре поля', () {
      const user = AuthUser(id: 7, name: 'Айгуль', role: 'cashier', hasPin: true);

      // Равенство целиком, а не `contains` по кускам: `contains` проверяет
      // только наличие, и пятое поле, дописанное в `toString()`, проскользнуло
      // бы мимо всех четырёх проверок. Равенство ловит любое добавление в
      // видимую форму.
      //
      // Тест сторожит видимую снаружи форму `AuthUser` — поле, дописанное в
      // `toString()`, покраснеет здесь. Поле, дописанное в класс, но не
      // попавшее в `toString()`, этот тест не увидит: структурная проверка
      // типа в Dart без зеркал невыразима, а зеркала запрещены сборкой под
      // браузер. Настоящая ловля любого поля приезжает задачей 8, где кадр
      // `auth.users` сверяется по множеству ключей.
      expect(
        user.toString(),
        'AuthUser(id: 7, name: Айгуль, role: cashier, hasPin: true)',
      );
    });
  });

  group('AuthOutcome', () {
    test('исход входа разбирается по ветвям, а не по null', () {
      final AuthOutcome ok = AuthSession(
        token: 'abc',
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'cashier',
        shift: ShiftStatus.open,
        issuedAt: DateTime.utc(2026, 8, 20, 10),
        expiresAt: DateTime.utc(2026, 8, 20, 10, 30),
        terminalId: 1,
      );
      final AuthOutcome no = const AuthRejection(AuthRejectionReason.wrongPin);

      expect(switch (ok) { AuthSession() => 'сеанс', AuthRejection() => 'отказ' }, 'сеанс');
      expect(switch (no) { AuthSession() => 'сеанс', AuthRejection() => 'отказ' }, 'отказ');
    });

    test('у отказа всегда есть названная причина', () {
      for (final reason in AuthRejectionReason.values) {
        expect(AuthRejection(reason).reason, reason);
      }
    });
  });
}
