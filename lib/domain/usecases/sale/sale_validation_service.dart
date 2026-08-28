import 'package:decimal/decimal.dart';

abstract class SaleValidationService {
  BarcodeValidation validateBarcode(String barcode);

  bool isBarcodeInner(String barcode);

  bool isBarcodeWeight(String barcode);

  String? isBarcodeReserved(String barcode, List<String> reservedPatterns);

  PriceValidation validatePrice(Decimal price);

  MarkValidation validateMark(String mark);

  Future<bool> isCategoryBlocked(int categoryId);

  Future<bool> isProductDeleted(int ucode);

  WeightValidation validateWeightQuantity(Decimal quantity);

  SaleValidation validateSale({
    required int productCount,
    required bool hasZeroPriceProduct,
    required Decimal saleAmount,
  });
}

class BarcodeValidation {
  const BarcodeValidation({required this.isValid, this.error});

  final bool isValid;
  final BarcodeError? error;

  static const valid = BarcodeValidation(isValid: true);
}

enum BarcodeError { empty, wrongFormat, wrongChecksum }

class PriceValidation {
  const PriceValidation({
    required this.isValid,
    this.needsConfirmation = false,
    this.error,
  });

  final bool isValid;

  final bool needsConfirmation;
  final PriceError? error;

  static const valid = PriceValidation(isValid: true);
}

enum PriceError { zeroPrice, exceedsLimit }

class MarkValidation {
  const MarkValidation({required this.isValid, this.error});

  final bool isValid;
  final MarkError? error;

  static const valid = MarkValidation(isValid: true);
}

enum MarkError { empty, wrongGtinFormat }

class WeightValidation {
  const WeightValidation({
    required this.isValid,
    this.needsConfirmation = false,
  });

  final bool isValid;

  final bool needsConfirmation;

  static const valid = WeightValidation(isValid: true);
}

class SaleValidation {
  const SaleValidation({required this.isValid, this.error});

  final bool isValid;
  final SaleError? error;

  static const valid = SaleValidation(isValid: true);
}

enum SaleError { emptyCart, hasZeroPrice, exceedsMaxAmount }
