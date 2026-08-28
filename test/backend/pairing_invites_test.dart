/// Формат кода привязки, пригодный для набора руками.
///
/// # Что было не так
///
/// `PairingInvites.mint()` до этой правки кодировала 12 случайных байт
/// `base64Url` — шестнадцать регистрозависимых знаков, включая пары,
/// неразличимые на экране (`l`/`I`/`1`, `O`/`0`). Весь сценарий работы —
/// оператор читает код с экрана кассы, человек **набирает** его руками на
/// планшете, — а такой алфавит для набора руками непригоден.
///
/// # Что стало
///
/// Алфавит Crockford Base32 (32 знака, без `I`/`L`/`O`/`U`), 10 знаков,
/// показывается двумя группами по пять через дефис. Энтропия — ровно
/// 10 × 5 = 50 бит (32 = 2⁵, без потери на округление). Обоснование, почему
/// 50 бит достаточно коду без замка попыток, живущему 15 минут и
/// тратящемуся один раз, — в докстринге `PairingInvites.mint`.
///
/// Этот файл проверяет то, что предыдущая правка не проверяла никак: что
/// новый формат действительно эргономичен (регистр не важен, разделители не
/// обязательны, двусмысленных знаков в алфавите нет) и что заявленная
/// энтропия — не голое слово в докстринге, а измеримое свойство того, что
/// возвращает `mint()`.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/pairing_invites.dart';

void main() {
  group('PairingInvites — формат кода', () {
    test('код — две группы по пять знаков, разделённые дефисом', () {
      final invites = PairingInvites();
      final invite = invites.mint();

      expect(
        invite.code,
        matches(RegExp(r'^[0-9A-Z]{5}-[0-9A-Z]{5}$')),
        reason: 'формат обязан быть предсказуемым — его показывает экран '
            'кассы и его же набирают руками',
      );
    });

    test('в алфавите нет ни одного из I, L, O, U — двусмысленных или '
        'случайно складывающихся в слово', () {
      // Random.secure() — тот же генератор, что и боевой; 400 кодов × 10
      // знаков = 4000 испытаний на выборку, достаточно, чтобы сломанная
      // реализация (например, вернувшая полный латинский алфавит) себя
      // выдала почти наверняка при первом же прогоне.
      final invites = PairingInvites();
      final forbidden = {'I', 'L', 'O', 'U'};

      for (var i = 0; i < 400; i++) {
        final chars = invites.mint().code.replaceAll('-', '').split('');
        for (final ch in chars) {
          expect(
            forbidden.contains(ch),
            isFalse,
            reason: 'знак "$ch" двусмыслен или зарезервирован Crockford — '
                'ему не место в коде, который диктуют вслух',
          );
        }
      }
    });

    test('пространство кода — 32 равновероятных знака на позицию, то есть '
        'ровно 2⁵⁰ кодов (50 бит), не меньше', () {
      // Тем же приёмом, что и выше: если бы реализация тайком сузила
      // алфавит (скажем, до 26 латинских букв без цифр), часть из 32
      // ожидаемых знаков ни разу не появилась бы в достаточно большой
      // выборке. 6000 кодов × 10 знаков = 60000 испытаний на 32 знака —
      // шанс ни разу не увидеть один конкретный знак при равной
      // вероятности исчезающе мал: (31/32)^60000 ≈ 0.
      const expectedAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final invites = PairingInvites();
      final seen = <String>{};

      for (var i = 0; i < 6000; i++) {
        seen.addAll(invites.mint().code.replaceAll('-', '').split(''));
      }

      expect(
        seen,
        equals(expectedAlphabet.split('').toSet()),
        reason: 'весь 32-знаковый алфавит обязан быть достижим — иначе '
            'заявленные 50 бит энтропии (log2(32) × 10) были бы враньём',
      );
    });
  });

  group('PairingInvites — redeem/revoke принимают любой начертанный вид', () {
    // Детерминированный генератор: код всегда "01234-ABCDE" — позволяет
    // проверять нормализацию (регистр, разделители, O/I/L) на известном
    // тексте, а не гоняться за случайным кодом, где нужные цифры могут не
    // выпасть.
    PairingInvites fixed() =>
        PairingInvites(random: _SequenceRandom([0, 1, 2, 3, 4, 10, 11, 12, 13, 14]));

    test('mint() с зафиксированной последовательностью даёт ожидаемый код', () {
      final invite = fixed().mint();
      expect(invite.code, '01234-ABCDE');
    });

    test('redeem принимает код в нижнем регистре', () {
      final invites = fixed();
      final invite = invites.mint();
      expect(invites.redeem(invite.code.toLowerCase()), isTrue);
    });

    test('redeem принимает код без разделителя', () {
      final invites = fixed();
      invites.mint();
      expect(invites.redeem('01234ABCDE'), isTrue);
    });

    test('redeem принимает разделитель-пробел вместо дефиса', () {
      final invites = fixed();
      invites.mint();
      expect(invites.redeem('01234 ABCDE'), isTrue);
    });

    test('redeem прощает O вместо 0 и I/L вместо 1 — та же цифра, другой '
        'знак того же смысла по Crockford', () {
      final invites = fixed();
      invites.mint();
      // '0'→'O', '1'→'I': "01234" набрано как "OI234".
      expect(invites.redeem('OI234-ABCDE'), isTrue);
    });

    test('redeem с "L" вместо "1" — тот же случай, другая буква', () {
      final invites = fixed();
      invites.mint();
      expect(invites.redeem('0L234-ABCDE'), isTrue);
    });

    test('redeem отказывает неверному коду', () {
      final invites = fixed();
      invites.mint();
      expect(invites.redeem('99999-99999'), isFalse);
    });

    test('redeem одноразов — после успеха тот же нормализованный код больше '
        'не работает', () {
      final invites = fixed();
      final invite = invites.mint();
      expect(invites.redeem(invite.code.toLowerCase()), isTrue);
      expect(invites.redeem(invite.code), isFalse);
      expect(invites.redeem('01234ABCDE'), isFalse);
    });

    test('revoke нормализует так же, как redeem', () {
      final invites = fixed();
      final invite = invites.mint();
      expect(invites.revoke(invite.code.toLowerCase().replaceAll('-', ' ')),
          isTrue);
      // Код снят — redeem его больше не находит.
      expect(invites.redeem(invite.code), isFalse);
    });

    test('redeem(null) и redeem("") отказывают, как и раньше', () {
      final invites = fixed();
      invites.mint();
      expect(invites.redeem(null), isFalse);
      expect(invites.redeem(''), isFalse);
      expect(invites.redeem('   '), isFalse);
    });
  });
}

/// `Random`, чей `nextInt` идёт по заранее заданному списку индексов
/// по кругу — тем же приёмом, что `_FixedByte` в
/// `test/unit/domain/terminal_secret_test.dart`.
class _SequenceRandom implements Random {
  _SequenceRandom(this._values);

  final List<int> _values;
  var _i = 0;

  @override
  int nextInt(int max) => _values[_i++ % _values.length];

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}
