import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';

abstract class FindProductByMarkUseCase {
  Future<ProductWithPrice?> find(String mark);

  String? extractGtin(String mark);

  bool isValidMark(String mark);
}
