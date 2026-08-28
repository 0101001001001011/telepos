import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';

abstract class SupplyRepository {
  Future<SupplyEntity?> findById(int id);

  Future<int> create(SupplyEntity entity);

  Future<int> addProduct(SupplyProductEntity product);

  Future<List<SupplyProductEntity>> findProducts(int supplyId);
}
