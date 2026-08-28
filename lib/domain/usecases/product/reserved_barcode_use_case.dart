abstract class ReservedBarcodeUseCase {
  bool isReserved(String barcode);

  bool isReservedNumeric(int barcode);

  ReservedBarcodeType? getReservedType(String barcode);
}

enum ReservedBarcodeType { internal, weighted, marked, coupon }

class ReservedBarcodePatterns {
  ReservedBarcodePatterns._();

  static final internal = RegExp(r'^2\d{12}$');

  static final weighted = RegExp(r'^2[1-9]\d{11}$');

  static final markedGtin13 = RegExp(r'^[04-9]\d{12}$');

  static final markedGtin14 = RegExp(r'^\d{14}$');

  static final coupon = RegExp(r'^99\d{11}$');
}
