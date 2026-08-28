import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/warranty/warranty_record_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_history_entity.dart';
import 'package:telepos/domain/entities/warranty/product_component_entity.dart';
import 'package:telepos/domain/repositories/warranty_repository.dart';

class WarrantyRepositoryImpl implements WarrantyRepository {
  WarrantyRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<WarrantyRecordEntity>> findBySerialId(int serialId) async {
    final rows = await _db.warrantyDao.findWarrantyBySerialId(serialId);
    return WarrantyRecordMapper.fromDriftList(rows);
  }

  @override
  Future<List<WarrantyRecordEntity>> findByUcode(int ucode) async {
    final rows = await _db.warrantyDao.findWarrantyByUcode(ucode);
    return WarrantyRecordMapper.fromDriftList(rows);
  }

  @override
  Future<List<WarrantyRecordEntity>> findExpiring(int daysAhead) async {
    final rows = await _db.warrantyDao.findExpiringWarranties(daysAhead);
    return WarrantyRecordMapper.fromDriftList(rows);
  }

  @override
  Future<int> create(WarrantyRecordEntity entity) {
    final companion = WarrantyRecordMapper.toDrift(entity);
    return _db.warrantyDao.insertWarranty(companion);
  }

  @override
  Future<int> update(WarrantyRecordEntity entity) {
    final companion = WarrantyRecordMapper.toDrift(entity);
    return _db.warrantyDao.updateWarranty(entity.id!, companion);
  }

  @override
  Future<List<ClaimEntity>> findAllClaims() async {
    final rows = await _db.warrantyDao.findAllClaims();
    return ClaimMapper.fromDriftList(rows);
  }

  @override
  Future<ClaimEntity?> findClaimById(int id) async {
    final row = await _db.warrantyDao.findClaimById(id);
    return row != null ? ClaimMapper.fromDrift(row) : null;
  }

  @override
  Future<List<ClaimEntity>> findClaimsByStatus(int status) async {
    final rows = await _db.warrantyDao.findClaimsByStatus(status);
    return ClaimMapper.fromDriftList(rows);
  }

  @override
  Future<List<ClaimEntity>> findClaimsByCustomerId(int customerId) async {
    final rows = await _db.warrantyDao.findClaimsByCustomerId(customerId);
    return ClaimMapper.fromDriftList(rows);
  }

  @override
  Future<int> createClaim(ClaimEntity entity) {
    final companion = ClaimMapper.toDrift(entity);
    return _db.warrantyDao.insertClaim(companion);
  }

  @override
  Future<int> updateClaim(ClaimEntity entity) {
    final companion = ClaimMapper.toDrift(entity);
    return _db.warrantyDao.updateClaim(entity.id!, companion);
  }

  @override
  Future<String> getNextClaimNumber() {
    return _db.warrantyDao.getNextClaimNumber();
  }

  @override
  Future<int> addClaimHistory(ClaimHistoryEntity entry) {
    final companion = ClaimHistoryMapper.toDrift(entry);
    return _db.warrantyDao.insertClaimHistory(companion);
  }

  @override
  Future<List<ClaimHistoryEntity>> findClaimHistory(int claimId) async {
    final rows = await _db.warrantyDao.findClaimHistory(claimId);
    return ClaimHistoryMapper.fromDriftList(rows);
  }

  @override
  Future<List<ProductComponentEntity>> findComponentsBySerialId(
    int parentSerialId,
  ) async {
    final rows = await _db.warrantyDao.findComponentsBySerialId(parentSerialId);
    return ProductComponentMapper.fromDriftList(rows);
  }

  @override
  Future<int> addComponent(ProductComponentEntity component) {
    final companion = ProductComponentMapper.toDrift(component);
    return _db.warrantyDao.insertComponent(companion);
  }
}
