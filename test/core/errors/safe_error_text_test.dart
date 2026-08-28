library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:telepos/core/errors/safe_error_text.dart';

import '../../fixtures/pin_hash_fixture.dart';

void main() {
  test(
    'SqliteException с хэшем PIN в параметрах: хэш не попадает наружу, '
    'осмысленная часть сообщения — попадает',
    () {
      // Форма записи повторяет ту, что реально уходит с
      // `UPDATE users SET password_enc = ?` (см. auth_service_impl.dart) —
      // сама PBKDF2-строка из PinCredential.
      final error = SqliteException(
        2067, // SQLITE_CONSTRAINT_UNIQUE
        'UNIQUE constraint failed: users.password_enc',
        'columns password_enc are not unique',
        'UPDATE users SET password_enc = ? WHERE id = ?',
        [testPbkdf2PinHash, 1],
        'executing a prepared statement',
      );

      final text = safeErrorText(error);

      expect(
        text,
        isNot(contains(testPbkdf2PinHash)),
        reason: 'хэш PIN не должен покидать кассу ни в каком виде',
      );
      expect(
        text,
        contains('UNIQUE constraint failed: users.password_enc'),
        reason: 'message — осмысленная часть, её видно',
      );
    },
  );

  test('SqliteException без параметров: сообщение проходит целиком', () {
    final error = SqliteException(1, 'no such table: ghost');

    final text = safeErrorText(error);

    expect(text, contains('no such table: ghost'));
    expect(text, contains('SqliteException'));
  });

  test('произвольное исключение: наружу — только имя типа', () {
    final error = FormatException('bad input: pbkdf2\$sha256\$10000\$secret');

    final text = safeErrorText(error);

    expect(text, contains('FormatException'));
    expect(
      text,
      isNot(contains('secret')),
      reason:
          'toString() произвольного исключения не гарантированно безопасен — '
          'для "остального" правило говорит: только имя типа',
    );
  });
}
