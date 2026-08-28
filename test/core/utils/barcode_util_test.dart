import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/utils/barcode_util.dart';

void main() {
  group('BarcodeUtil', () {
    group('calculateCheckSum', () {
      test('calculates correct checksum for EAN-13', () {
        expect(BarcodeUtil.calculateCheckSum('460702539240'), 8);
      });

      test('calculates correct checksum for EAN-8', () {
        expect(BarcodeUtil.calculateCheckSum('9638507'), 4);
      });

      test('calculates checksum for weight barcode', () {
        expect(BarcodeUtil.calculateCheckSum('276123400000'), 3);
      });

      test('calculates checksum for various codes', () {
        expect(BarcodeUtil.calculateCheckSum('590123412345'), 7);
        expect(BarcodeUtil.calculateCheckSum('400638133393'), 1);
        expect(BarcodeUtil.calculateCheckSum('0'), 0);
      });
    });

    group('hasValidCheckSum', () {
      test('returns true for valid EAN-13', () {
        expect(BarcodeUtil.hasValidCheckSum('4607025392408'), true);
        expect(BarcodeUtil.hasValidCheckSum('5901234123457'), true);
      });

      test('returns true for valid EAN-8', () {
        expect(BarcodeUtil.hasValidCheckSum('96385074'), true);
      });

      test('returns false for invalid checksum', () {
        expect(BarcodeUtil.hasValidCheckSum('4607025392409'), false);
        expect(BarcodeUtil.hasValidCheckSum('4607025392400'), false);
      });

      test('returns false for too short barcode', () {
        expect(BarcodeUtil.hasValidCheckSum('1'), false);
        expect(BarcodeUtil.hasValidCheckSum(''), false);
      });

      test('returns true for weight barcode with valid checksum', () {
        expect(BarcodeUtil.hasValidCheckSum('2761234000003'), true);
      });
    });

    group('parse', () {
      test('throws on empty barcode', () {
        expect(
          () => BarcodeUtil.parse(''),
          throwsA(isA<BarcodeFormatException>()),
        );
      });

      test('throws on all zeros', () {
        expect(
          () => BarcodeUtil.parse('000000'),
          throwsA(isA<BarcodeFormatException>()),
        );
      });

      test('parses valid EAN-13', () {
        final result = BarcodeUtil.parse('4607025392408');
        expect(result.value, 4607025392408);
        expect(result.isWeight, false);
        expect(result.isInner, false);
        expect(result.weight, isNull);
      });

      test('parses weight barcode without weight (7 digits)', () {
        final result = BarcodeUtil.parse('2761234');
        expect(result.value, 2761234);
        expect(result.isWeight, true);
        expect(result.isInner, true);
        expect(result.weight, isNull);
      });

      test('parses weight barcode (7 digit variant)', () {
        final result = BarcodeUtil.parse('2761234');
        expect(result.value, 2761234);
        expect(result.isWeight, true);
        expect(result.isInner, true);
        expect(result.weight, isNull);
      });

      test('parses weight barcode with zero weight suffix', () {
        final result = BarcodeUtil.parse('2761234000003');
        expect(result.value, 2761234);
        expect(result.isWeight, true);
        expect(result.weight, isNull);
      });

      test('parses 277 prefix weight barcode', () {
        final result = BarcodeUtil.parse('2775678');
        expect(result.isWeight, true);
        expect(result.value, 2775678);
      });

      test('parses 278 prefix weight barcode', () {
        final result = BarcodeUtil.parse('2789012');
        expect(result.isWeight, true);
        expect(result.value, 2789012);
      });

      test('parses inner barcode (211 prefix)', () {
        final checksum = BarcodeUtil.calculateCheckSum('211234567890');
        final validBarcode = '211234567890$checksum';
        final result = BarcodeUtil.parse(validBarcode);
        expect(result.isInner, true);
        expect(result.isWeight, false);
      });

      test('strips leading zeros', () {
        final result = BarcodeUtil.parse('0004607025392408');
        expect(result.value, 4607025392408);
      });

      test('throws on invalid checksum', () {
        expect(
          () => BarcodeUtil.parse('4607025392409'),
          throwsA(isA<BarcodeFormatException>()),
        );
      });

      test('throws on invalid weight barcode format', () {
        expect(
          () => BarcodeUtil.parse('27612345'),
          throwsA(isA<BarcodeFormatException>()),
        );
      });

      test('throws on invalid length', () {
        expect(
          () => BarcodeUtil.parse('123'),
          throwsA(isA<BarcodeFormatException>()),
        );
      });
    });

    group('barcodeToUcode', () {
      test('returns barcode as-is for non-weight', () {
        expect(BarcodeUtil.barcodeToUcode(4607025392408, false), 4607025392408);
      });

      test('adds zeros and checksum for weight barcode', () {
        final ucode = BarcodeUtil.barcodeToUcode(2761234, true);
        expect(ucode.toString(), startsWith('2761234'));
        expect(ucode.toString().length, 13);
      });

      test('returns barcode as-is if not weight prefix', () {
        expect(BarcodeUtil.barcodeToUcode(1234567, true), 1234567);
      });
    });

    group('ucodeToBarcode', () {
      test('extracts first 7 digits for weight ucode', () {
        expect(BarcodeUtil.ucodeToBarcode(2761234000005), 2761234);
        expect(BarcodeUtil.ucodeToBarcode(2771234000002), 2771234);
        expect(BarcodeUtil.ucodeToBarcode(2781234000009), 2781234);
      });

      test('returns ucode as-is for non-weight', () {
        expect(BarcodeUtil.ucodeToBarcode(4607025392408), 4607025392408);
        expect(BarcodeUtil.ucodeToBarcode(1234567890), 1234567890);
      });
    });
  });

  group('BarcodeParseResult', () {
    test('has correct properties', () {
      final result = BarcodeParseResult(
        value: 12345,
        ucode: 123450000005,
        isWeight: true,
        isInner: true,
        weight: Decimal.parse('1.5'),
      );

      expect(result.value, 12345);
      expect(result.ucode, 123450000005);
      expect(result.isWeight, true);
      expect(result.isInner, true);
      expect(result.weight, Decimal.parse('1.5'));
    });
  });

  group('BarcodeFormatException', () {
    test('has message', () {
      const exception = BarcodeFormatException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.toString(), contains('Test error'));
    });
  });
}
