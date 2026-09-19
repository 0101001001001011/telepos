import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/wire_money.dart';

/// Тесты на саму дверь (`wireMoney`) — заведены кругом правки 3 задачи 6:
/// с тех пор как `wireMoney` стала единственным разрешённым путём денег на
/// провод, её собственные края стали краями всего правила денег на проводе
/// (инвариант I159) — сторож (`money_over_wire_test.dart`) проверяет только
/// форму вызова, а не то, что дверь на самом деле делает со значением.
void main() {
  test('ноль', () {
    expect(wireMoney(Decimal.zero), '0');
    expect(Decimal.parse(wireMoney(Decimal.zero)), Decimal.zero);
  });

  test('отрицательное значение', () {
    final value = Decimal.parse('-1500.75');
    expect(wireMoney(value), '-1500.75');
    expect(Decimal.parse(wireMoney(value)), value);
  });

  test('очень большое значение (P18 — 18 значащих цифр)', () {
    // P18,S3: 15 цифр целой части + 3 дробных = 18 значащих цифр.
    final value = Decimal.parse('999999999999999.999');
    expect(wireMoney(value), '999999999999999.999');
    expect(Decimal.parse(wireMoney(value)), value);
  });

  test('очень маленькое ненулевое значение', () {
    final value = Decimal.parse('0.001');
    expect(wireMoney(value), '0.001');
    expect(Decimal.parse(wireMoney(value)), value);
  });

  test(
    'значение с разрядностью больше S3 — дверь не режет и не округляет '
    '(честный выбор круга 3: дверь не проверяет и не обрезает точность)',
    () {
      final value = Decimal.parse('10.12345678');
      expect(wireMoney(value), '10.12345678');
      expect(Decimal.parse(wireMoney(value)), value);
    },
  );

  test('обратный путь через Decimal.parse без потери точности', () {
    // Третий знак после запятой — тот же случай, что и в
    // cart_view_test.dart, но здесь проверяется именно дверь в изоляции,
    // не кодек целиком.
    final value = Decimal.parse('1990.125');
    final wire = wireMoney(value);

    expect(wire, isA<String>());
    expect(Decimal.parse(wire), value);
    // Явно — третий знак не потерян (double потерял бы его молча).
    expect(Decimal.parse(wire).toString(), '1990.125');
  });

  test(
    'сумма нескольких значений, прошедших через дверь и обратно, точна '
    '(double накопил бы ошибку уже на второй-третьей строке)',
    () {
      final a = Decimal.parse('0.1');
      final b = Decimal.parse('0.2');

      final sum =
          Decimal.parse(wireMoney(a)) + Decimal.parse(wireMoney(b));

      expect(sum, Decimal.parse('0.3'));
    },
  );
}
