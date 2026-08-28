import 'package:telepos/domain/usecases/product/reserved_barcode_use_case.dart';

class ReservedBarcodeUseCaseImpl implements ReservedBarcodeUseCase {
  @override
  bool isReserved(String barcode) {
    return getReservedType(barcode) != null;
  }

  @override
  bool isReservedNumeric(int barcode) {
    return isReserved(barcode.toString());
  }

  @override
  ReservedBarcodeType? getReservedType(String barcode) {
    if (ReservedBarcodePatterns.coupon.hasMatch(barcode)) {
      return ReservedBarcodeType.coupon;
    }

    if (ReservedBarcodePatterns.weighted.hasMatch(barcode)) {
      return ReservedBarcodeType.weighted;
    }

    if (ReservedBarcodePatterns.internal.hasMatch(barcode)) {
      return ReservedBarcodeType.internal;
    }

    if (ReservedBarcodePatterns.markedGtin14.hasMatch(barcode)) {
      return ReservedBarcodeType.marked;
    }

    if (ReservedBarcodePatterns.markedGtin13.hasMatch(barcode)) {
      return ReservedBarcodeType.marked;
    }

    return null;
  }
}
