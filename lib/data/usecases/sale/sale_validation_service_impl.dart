import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/sale_validation_service.dart';

class SaleValidationServiceImpl implements SaleValidationService {
  SaleValidationServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static final Decimal _priceWarningThreshold = Decimal.fromInt(1000000);

  static final Decimal _weightWarningThreshold = Decimal.fromInt(2760000);

  static final RegExp _barcodeFormatRegex = RegExp(
    r'^(\d{7,8}|\d{10,14}|\d{16,17})$',
  );

  static const List<String> _weightHeaders = ['276', '277', '278'];

  static const String _innerPrefix = '2';

  static final RegExp _gtinHeaderRegex = RegExp(r'^\d{14}');

  @override
  BarcodeValidation validateBarcode(String barcode) {
    if (barcode.isEmpty || int.tryParse(barcode) == 0) {
      return const BarcodeValidation(isValid: false, error: BarcodeError.empty);
    }

    if (!_barcodeFormatRegex.hasMatch(barcode)) {
      return const BarcodeValidation(
        isValid: false,
        error: BarcodeError.wrongFormat,
      );
    }

    if (barcode.length == 8 || barcode.length == 13 || barcode.length == 14) {
      if (!_validateChecksum(barcode)) {
        return const BarcodeValidation(
          isValid: false,
          error: BarcodeError.wrongChecksum,
        );
      }
    }

    return BarcodeValidation.valid;
  }

  @override
  bool isBarcodeInner(String barcode) {
    return barcode.startsWith(_innerPrefix);
  }

  @override
  bool isBarcodeWeight(String barcode) {
    for (final header in _weightHeaders) {
      if (barcode.startsWith(header)) {
        return true;
      }
    }
    return false;
  }

  @override
  String? isBarcodeReserved(String barcode, List<String> reservedPatterns) {
    for (final pattern in reservedPatterns) {
      try {
        if (RegExp(pattern).hasMatch(barcode)) {
          return pattern;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  PriceValidation validatePrice(Decimal price) {
    if (price == Decimal.zero) {
      return const PriceValidation(isValid: false, error: PriceError.zeroPrice);
    }

    if (price >= _priceWarningThreshold) {
      return const PriceValidation(isValid: true, needsConfirmation: true);
    }

    return PriceValidation.valid;
  }

  @override
  MarkValidation validateMark(String mark) {
    if (mark.isEmpty) {
      return const MarkValidation(isValid: false, error: MarkError.empty);
    }

    if (!_gtinHeaderRegex.hasMatch(mark)) {
      return const MarkValidation(
        isValid: false,
        error: MarkError.wrongGtinFormat,
      );
    }

    return MarkValidation.valid;
  }

  @override
  Future<bool> isCategoryBlocked(int categoryId) async {
    final restrictions = await _db.categoryRestrictionDao.findActiveForCategory(
      categoryId,
    );

    if (restrictions.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    for (final restriction in restrictions) {
      if (_isNowBetween(restriction.beginTime, restriction.endTime, now)) {
        _logger.info(
          'SaleValidation: category $categoryId blocked '
          '${restriction.beginTime}-${restriction.endTime}',
        );
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> isProductDeleted(int ucode) async {
    final product = await _db.productInfoDao.findByIdAndNotDeleted(ucode);
    return product == null;
  }

  @override
  WeightValidation validateWeightQuantity(Decimal quantity) {
    if (quantity >= _weightWarningThreshold) {
      return const WeightValidation(isValid: true, needsConfirmation: true);
    }
    return WeightValidation.valid;
  }

  @override
  SaleValidation validateSale({
    required int productCount,
    required bool hasZeroPriceProduct,
    required Decimal saleAmount,
  }) {
    if (productCount == 0) {
      return const SaleValidation(isValid: false, error: SaleError.emptyCart);
    }

    if (hasZeroPriceProduct) {
      return const SaleValidation(
        isValid: false,
        error: SaleError.hasZeroPrice,
      );
    }

    if (saleAmount >= _priceWarningThreshold) {
      return const SaleValidation(
        isValid: false,
        error: SaleError.exceedsMaxAmount,
      );
    }

    return SaleValidation.valid;
  }

  bool _validateChecksum(String barcode) {
    final digits = barcode.split('').map(int.parse).toList();
    final checkDigit = digits.last;

    var oddSum = 0;
    var evenSum = 0;
    for (var i = 0; i < digits.length - 1; i++) {
      if (i.isEven) {
        oddSum += digits[i];
      } else {
        evenSum += digits[i];
      }
    }

    final total = oddSum + evenSum * 3;
    final calculated = (10 - (total % 10)) % 10;
    return calculated == checkDigit;
  }

  bool _isNowBetween(String? beginTime, String? endTime, DateTime now) {
    if (beginTime == null || endTime == null) {
      return true;
    }

    final beginParts = beginTime.split(':');
    final endParts = endTime.split(':');
    if (beginParts.length < 2 || endParts.length < 2) {
      return true;
    }

    final beginMinutes =
        int.parse(beginParts[0]) * 60 + int.parse(beginParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final nowMinutes = now.hour * 60 + now.minute;

    if (beginMinutes <= endMinutes) {
      return nowMinutes >= beginMinutes && nowMinutes <= endMinutes;
    } else {
      return nowMinutes >= beginMinutes || nowMinutes <= endMinutes;
    }
  }
}
