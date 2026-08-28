import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/warranty/claim_entity.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

abstract class ClaimUseCase {
  Future<WmsResult> createClaim({
    required String claimType,
    int? serialId,
    int? ucode,
    int? batchId,
    Decimal? quantity,
    int? customerId,
    int? supplierId,
    required int operatorId,
    required String problemDescription,
    String? defectType,
    String? severity,
  });

  Future<WmsResult> resolveClaim(
    int claimId, {
    required String resolutionType,
    String? notes,
    int? resolvedBy,
    Decimal? refundAmount,
    Decimal? repairCost,
  });

  Future<WmsResult> updateClaimStatus(
    int claimId,
    int newStatus, {
    int? userId,
    String? notes,
  });

  Future<List<ClaimEntity>> getAllClaims();

  Future<List<ClaimEntity>> getOpenClaims();

  Future<List<ClaimEntity>> getClaimsByCustomer(int customerId);
}
