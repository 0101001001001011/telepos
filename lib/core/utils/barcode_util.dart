import 'package:decimal/decimal.dart';

class BarcodeUtil {
  BarcodeUtil._();

  static const weightBarcodeHeaders = ['276', '277', '278'];

  static const innerBarcodePrefix = '211';

  static const zeroWeightSuffix = '00000';

  static final _barcodePattern = RegExp(r'^\d{7,8}$|^\d{10,14}$|^\d{16,17}$');
  static final _weightNoWeightPattern = RegExp(r'^\d{7}$');
  static final _weightWithWeightPattern = RegExp(r'^\d{13}$');
  static final _ucodeWeightPattern = RegExp(r'^27[678]\d{4}00000\d$');

  static BarcodeParseResult parse(String input) {
    if (input.isEmpty) {
      throw const BarcodeFormatException('Штрих-код не может быть пустым');
    }

    var barcode = input.replaceFirst(RegExp(r'^0+'), '');
    if (barcode.isEmpty) {
      throw const BarcodeFormatException('Штрих-код не может быть пустым');
    }

    final isWeight = _isWeightBarcode(barcode);
    final isInner = isWeight || barcode.startsWith(innerBarcodePrefix);

    int value;
    Decimal? weight;

    if (isWeight) {
      if (_weightNoWeightPattern.hasMatch(barcode)) {
        value = int.parse(barcode);
        weight = null;
      } else if (_weightWithWeightPattern.hasMatch(barcode)) {
        if (!hasValidCheckSum(barcode)) {
          throw const BarcodeFormatException(
            'Не верное проверочное значение штрих-кода',
          );
        }
        final weightPart = barcode.substring(7, 12);
        if (weightPart == zeroWeightSuffix) {
          weight = null;
        } else {
          weight = (Decimal.parse(weightPart) / Decimal.fromInt(1000))
              .toDecimal();
        }
        value = int.parse(barcode.substring(0, 7));
      } else {
        throw const BarcodeFormatException(
          'Неверный формат весового штрих-кода',
        );
      }
    } else {
      if (!_barcodePattern.hasMatch(barcode)) {
        throw BarcodeFormatException(
          'Неверная длина штрих-кода: ${barcode.length}',
        );
      }
      if (!hasValidCheckSum(barcode)) {
        throw const BarcodeFormatException(
          'Не верное проверочное значение штрих-кода',
        );
      }
      value = int.parse(barcode);
      weight = null;
    }

    final ucode = barcodeToUcode(value, isWeight);

    return BarcodeParseResult(
      value: value,
      ucode: ucode,
      isWeight: isWeight,
      isInner: isInner,
      weight: weight,
    );
  }

  static bool _isWeightBarcode(String barcode) {
    return weightBarcodeHeaders.any(barcode.startsWith);
  }

  static int calculateCheckSum(String barcode) {
    var barcodeNum = int.parse(barcode);
    var sum = 0;
    var weight = 3;

    while (barcodeNum != 0) {
      sum += weight * (barcodeNum % 10);
      weight = 4 - weight;
      barcodeNum ~/= 10;
    }

    return (10 - (sum % 10)) % 10;
  }

  static bool hasValidCheckSum(String barcode) {
    if (barcode.length < 2) return false;
    final expected = int.parse(barcode[barcode.length - 1]);
    final prefix = barcode.substring(0, barcode.length - 1);
    return calculateCheckSum(prefix) == expected;
  }

  static int barcodeToUcode(int barcode, bool isWeight) {
    final barcodeStr = barcode.toString();
    if (!isWeight || !_isWeightBarcode(barcodeStr)) {
      return barcode;
    }
    final withZeros = '${barcodeStr}00000';
    final checkSum = calculateCheckSum(withZeros);
    return int.parse('$withZeros$checkSum');
  }

  static int ucodeToBarcode(int ucode) {
    final ucodeStr = ucode.toString();
    if (_ucodeWeightPattern.hasMatch(ucodeStr)) {
      return int.parse(ucodeStr.substring(0, 7));
    }
    return ucode;
  }
}

class BarcodeParseResult {
  const BarcodeParseResult({
    required this.value,
    required this.ucode,
    required this.isWeight,
    required this.isInner,
    this.weight,
  });

  final int value;

  final int ucode;

  final bool isWeight;

  final bool isInner;

  final Decimal? weight;
}

class BarcodeFormatException implements Exception {
  const BarcodeFormatException(this.message);
  final String message;

  @override
  String toString() => 'BarcodeFormatException: $message';
}
