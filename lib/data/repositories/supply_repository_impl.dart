import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/supply_mapper.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';
import 'package:telepos/domain/repositories/supply_repository.dart';

class SupplyRepositoryImpl implements SupplyRepository {
  SupplyRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<SupplyEntity?> findById(int id) async {
    final supply = await _db.supplyDao.findById(id);
    return supply != null ? SupplyMapper.fromDrift(supply) : null;
  }

  @override
  Future<int> create(SupplyEntity entity) {
    final companion = SupplyMapper.toDrift(entity);
    return _db.supplyDao.insertSupply(companion);
  }

  @override
  Future<int> addProduct(SupplyProductEntity product) {
    final companion = SupplyProductMapper.toDrift(product);
    return _db.supplyProductDao.insertProduct(companion);
  }

  @override
  Future<List<SupplyProductEntity>> findProducts(int supplyId) async {
    final products = await _db.supplyProductDao.findBySupplyId(supplyId);
    return SupplyProductMapper.fromDriftList(products);
  }
}
