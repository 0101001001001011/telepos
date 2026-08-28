import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/utils/decimal_util.dart';

void main() {
  group('DecimalUtil', () {
    group('constants', () {
      test('zero is Decimal.zero', () {
        expect(DecimalUtil.zero, Decimal.zero);
      });

      test('one is Decimal.one', () {
        expect(DecimalUtil.one, Decimal.one);
      });

      test('hundred is 100', () {
        expect(DecimalUtil.hundred, Decimal.fromInt(100));
      });

      test('thousand is 1000', () {
        expect(DecimalUtil.thousand, Decimal.fromInt(1000));
      });
    });

    group('fromInt', () {
      test('creates Decimal from int', () {
        expect(DecimalUtil.fromInt(42), Decimal.fromInt(42));
        expect(DecimalUtil.fromInt(0), Decimal.zero);
        expect(DecimalUtil.fromInt(-10), Decimal.fromInt(-10));
      });
    });

    group('fromDouble', () {
      test('creates Decimal from double with precision', () {
        final result = DecimalUtil.fromDouble(1.234567);
        expect(result, Decimal.parse('1.235'));
      });

      test('handles whole numbers', () {
        expect(DecimalUtil.fromDouble(100.0), Decimal.fromInt(100));
      });
    });

    group('tryParse', () {
      test('parses valid string', () {
        expect(DecimalUtil.tryParse('123.45'), Decimal.parse('123.45'));
      });

      test('parses comma as decimal separator', () {
        expect(DecimalUtil.tryParse('123,45'), Decimal.parse('123.45'));
      });

      test('returns null for null input', () {
        expect(DecimalUtil.tryParse(null), isNull);
      });

      test('returns null for empty string', () {
        expect(DecimalUtil.tryParse(''), isNull);
      });

      test('returns null for invalid string', () {
        expect(DecimalUtil.tryParse('abc'), isNull);
        expect(DecimalUtil.tryParse('12.34.56'), isNull);
      });
    });

    group('parse', () {
      test('parses valid string', () {
        expect(DecimalUtil.parse('100'), Decimal.fromInt(100));
      });

      test('returns zero for null', () {
        expect(DecimalUtil.parse(null), Decimal.zero);
      });

      test('returns default value for invalid', () {
        expect(
          DecimalUtil.parse('invalid', defaultValue: Decimal.fromInt(42)),
          Decimal.fromInt(42),
        );
      });
    });

    group('rounding', () {
      test('round uses default money scale (3)', () {
        final value = Decimal.parse('1.23456');
        expect(DecimalUtil.round(value), Decimal.parse('1.235'));
      });

      test('round with custom scale', () {
        final value = Decimal.parse('1.23456');
        expect(DecimalUtil.round(value, scale: 2), Decimal.parse('1.23'));
      });

      test('roundPrice uses 2 decimals', () {
        final value = Decimal.parse('1.2367');
        expect(DecimalUtil.roundPrice(value), Decimal.parse('1.24'));
      });

      test('roundQuantity uses 3 decimals', () {
        final value = Decimal.parse('1.23456');
        expect(DecimalUtil.roundQuantity(value), Decimal.parse('1.235'));
      });

      test('roundPercent uses 4 decimals', () {
        final value = Decimal.parse('1.234567');
        expect(DecimalUtil.roundPercent(value), Decimal.parse('1.2346'));
      });

      test('roundMoney uses 3 decimals', () {
        final value = Decimal.parse('1.23456');
        expect(DecimalUtil.roundMoney(value), Decimal.parse('1.235'));
      });
    });

    group('percent calculations', () {
      test('percent calculates correctly', () {
        final amount = Decimal.fromInt(1000);
        final pct = Decimal.fromInt(15);
        expect(DecimalUtil.percent(amount, pct), Decimal.fromInt(150));
      });

      test('percent with decimal values', () {
        final amount = Decimal.parse('100');
        final pct = Decimal.parse('12.5');
        expect(DecimalUtil.percent(amount, pct), Decimal.parse('12.5'));
      });

      test('addPercent adds correctly', () {
        final amount = Decimal.fromInt(1000);
        final pct = Decimal.fromInt(15);
        expect(DecimalUtil.addPercent(amount, pct), Decimal.fromInt(1150));
      });

      test('subtractPercent subtracts correctly', () {
        final amount = Decimal.fromInt(1000);
        final pct = Decimal.fromInt(15);
        expect(DecimalUtil.subtractPercent(amount, pct), Decimal.fromInt(850));
      });
    });

    group('VAT calculations', () {
      test('vatFromSum uses 4/29 formula', () {
        final sum = Decimal.fromInt(2900);
        expect(DecimalUtil.vatFromSum(sum), Decimal.fromInt(400));
      });

      test('vatFromSum with other values', () {
        final sum = Decimal.fromInt(1160);
        expect(DecimalUtil.vatFromSum(sum), Decimal.fromInt(160));
      });

      test('addVat adds 16%', () {
        final sum = Decimal.fromInt(1000);
        expect(DecimalUtil.addVat(sum), Decimal.fromInt(1160));
      });

      test('removeVat removes 16%', () {
        final sum = Decimal.fromInt(1160);
        expect(DecimalUtil.removeVat(sum), Decimal.fromInt(1000));
      });

      test('VAT round trip', () {
        final original = Decimal.fromInt(1000);
        final withVat = DecimalUtil.addVat(original);
        final restored = DecimalUtil.removeVat(withVat);
        expect(restored, original);
      });
    });

    group('formatMoney', () {
      test('formats with thousand separators', () {
        final value = Decimal.parse('1234567.89');
        expect(DecimalUtil.formatMoney(value), '1 234 567.89');
      });

      test('formats small numbers', () {
        final value = Decimal.parse('42.5');
        expect(DecimalUtil.formatMoney(value), '42.50');
      });

      test('formats with custom separator', () {
        final value = Decimal.parse('1234.56');
        expect(DecimalUtil.formatMoney(value, separator: ','), '1,234.56');
      });

      test('formats with custom decimals', () {
        final value = Decimal.parse('123.456');
        expect(DecimalUtil.formatMoney(value, decimals: 3), '123.456');
      });

      test('formats zero correctly', () {
        expect(DecimalUtil.formatMoney(Decimal.zero), '0.00');
      });
    });

    group('formatWithCurrency', () {
      test('adds currency after by default', () {
        final value = Decimal.parse('100');
        expect(DecimalUtil.formatWithCurrency(value), '100.00 тг');
      });

      test('adds custom currency', () {
        final value = Decimal.parse('100');
        expect(
          DecimalUtil.formatWithCurrency(value, currency: 'USD'),
          '100.00 USD',
        );
      });

      test('currency before amount', () {
        final value = Decimal.parse('100');
        expect(
          DecimalUtil.formatWithCurrency(value, currencyAfter: false),
          'тг 100.00',
        );
      });
    });

    group('formatQuantity', () {
      test('formats with 3 decimals', () {
        final value = Decimal.parse('1.5');
        expect(DecimalUtil.formatQuantity(value), '1.500');
      });
    });

    group('formatPercent', () {
      test('formats with percent symbol', () {
        final value = Decimal.fromInt(15);
        expect(DecimalUtil.formatPercent(value), '15%');
      });

      test('formats without symbol', () {
        final value = Decimal.fromInt(15);
        expect(DecimalUtil.formatPercent(value, showSymbol: false), '15');
      });
    });

    group('comparisons', () {
      test('isZero', () {
        expect(DecimalUtil.isZero(Decimal.zero), true);
        expect(DecimalUtil.isZero(Decimal.one), false);
      });

      test('isPositive', () {
        expect(DecimalUtil.isPositive(Decimal.one), true);
        expect(DecimalUtil.isPositive(Decimal.zero), false);
        expect(DecimalUtil.isPositive(Decimal.fromInt(-1)), false);
      });

      test('isNegative', () {
        expect(DecimalUtil.isNegative(Decimal.fromInt(-1)), true);
        expect(DecimalUtil.isNegative(Decimal.zero), false);
        expect(DecimalUtil.isNegative(Decimal.one), false);
      });

      test('min', () {
        expect(
          DecimalUtil.min(Decimal.fromInt(5), Decimal.fromInt(3)),
          Decimal.fromInt(3),
        );
      });

      test('max', () {
        expect(
          DecimalUtil.max(Decimal.fromInt(5), Decimal.fromInt(3)),
          Decimal.fromInt(5),
        );
      });

      test('abs', () {
        expect(DecimalUtil.abs(Decimal.fromInt(-5)), Decimal.fromInt(5));
        expect(DecimalUtil.abs(Decimal.fromInt(5)), Decimal.fromInt(5));
      });
    });

    group('isInRange', () {
      test('returns true when in range', () {
        final value = Decimal.fromInt(5);
        expect(
          DecimalUtil.isInRange(
            value,
            min: Decimal.fromInt(0),
            max: Decimal.fromInt(10),
          ),
          true,
        );
      });

      test('returns false when below min', () {
        final value = Decimal.fromInt(-1);
        expect(DecimalUtil.isInRange(value, min: Decimal.zero), false);
      });

      test('returns false when above max', () {
        final value = Decimal.fromInt(11);
        expect(DecimalUtil.isInRange(value, max: Decimal.fromInt(10)), false);
      });

      test('returns true with no bounds', () {
        expect(DecimalUtil.isInRange(Decimal.fromInt(1000)), true);
      });
    });
  });

  group('DecimalExtension', () {
    test('money rounds to 3 decimals', () {
      expect(Decimal.parse('1.23456').money, Decimal.parse('1.235'));
    });

    test('price rounds to 2 decimals', () {
      expect(Decimal.parse('1.2367').price, Decimal.parse('1.24'));
    });

    test('quantity rounds to 3 decimals', () {
      expect(Decimal.parse('1.23456').quantity, Decimal.parse('1.235'));
    });

    test('formatted returns money format', () {
      expect(Decimal.parse('1234.5').formatted, '1 234.50');
    });

    test('withCurrency adds currency', () {
      expect(Decimal.parse('100').withCurrency, '100.00 тг');
    });

    test('vat calculates VAT', () {
      expect(Decimal.fromInt(2900).vat, Decimal.fromInt(400));
    });

    test('withVat adds VAT', () {
      expect(Decimal.fromInt(1000).withVat, Decimal.fromInt(1160));
    });

    test('withoutVat removes VAT', () {
      expect(Decimal.fromInt(1160).withoutVat, Decimal.fromInt(1000));
    });
  });
}
