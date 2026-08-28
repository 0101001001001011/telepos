import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';

abstract class FindByBarcodeUseCase {
  Future<ProductWithPrice?> find(String barcode);

  Future<ProductWithPrice?> findByNumeric(int barcode);
}
