import 'package:telepos/domain/entities/warranty/warranty_record_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_history_entity.dart';
import 'package:telepos/domain/entities/warranty/product_component_entity.dart';

abstract class WarrantyRepository {
  Future<List<WarrantyRecordEntity>> findBySerialId(int serialId);

  Future<List<WarrantyRecordEntity>> findByUcode(int ucode);

  Future<List<WarrantyRecordEntity>> findExpiring(int daysAhead);

  Future<int> create(WarrantyRecordEntity entity);

  Future<int> update(WarrantyRecordEntity entity);

  Future<ClaimEntity?> findClaimById(int id);

  Future<List<ClaimEntity>> findAllClaims();

  Future<List<ClaimEntity>> findClaimsByStatus(int status);

  Future<List<ClaimEntity>> findClaimsByCustomerId(int customerId);

  Future<int> createClaim(ClaimEntity entity);

  Future<int> updateClaim(ClaimEntity entity);

  Future<String> getNextClaimNumber();

  Future<int> addClaimHistory(ClaimHistoryEntity entry);

  Future<List<ClaimHistoryEntity>> findClaimHistory(int claimId);

  Future<List<ProductComponentEntity>> findComponentsBySerialId(
    int parentSerialId,
  );

  Future<int> addComponent(ProductComponentEntity component);
}
