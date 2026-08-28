import 'package:telepos/domain/usecases/product/is_category_blocked_use_case.dart';

abstract class IsProductInfoBlockedUseCase {
  Future<CategoryBlockResult> isBlocked(int ucode);

  Future<CategoryBlockResult> isBlockedByBarcode(int barcode);

  Future<CategoryBlockResult> isBlockedAt(int ucode, DateTime checkTime);
}
