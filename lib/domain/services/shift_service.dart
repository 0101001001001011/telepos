import 'package:decimal/decimal.dart';

abstract class ShiftService {
  Future<void> onOpenShift(int userId, {Decimal? openingCash});

  Future<void> onCloseShift(Decimal cashInPos);

  Future<dynamic> getOpenedShift();

  Future<bool> isShiftOverAge({Duration maxAge = const Duration(hours: 24)});
}
