import 'package:decimal/decimal.dart';

abstract class MarkUpUseCase {
  Future<Decimal?> getMarkUp(int categoryId);

  Future<Decimal?> getMarkUpForProduct(int ucode);

  Decimal applyMarkUp(Decimal basePrice, Decimal markUpPercent);
}
