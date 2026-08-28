import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/warranty/claim_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_history_entity.dart';
import 'package:telepos/domain/repositories/warranty_repository.dart';
import 'package:telepos/domain/usecases/wms/claim_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

class ClaimUseCaseImpl implements ClaimUseCase {
  ClaimUseCaseImpl(this._warrantyRepo, {AppDatabase? db, Talker? logger})
    : _dbOverride = db,
      _loggerOverride = logger;

  final WarrantyRepository _warrantyRepo;

  final AppDatabase? _dbOverride;
  final Talker? _loggerOverride;

  AppDatabase get _db => _dbOverride ?? GetIt.I<AppDatabase>();
  Talker? get _logger =>
      _loggerOverride ??
      (GetIt.I.isRegistered<Talker>() ? GetIt.I<Talker>() : null);

  @override
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
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final claimNumber = await _warrantyRepo.getNextClaimNumber();

      final id = await _warrantyRepo.createClaim(
        ClaimEntity(
          claimNumber: claimNumber,
          claimType: _claimTypeFromString(claimType),
          serialId: serialId,
          ucode: ucode,
          batchId: batchId,
          quantity: quantity,
          customerId: customerId,
          supplierId: supplierId,
          operatorId: operatorId,
          problemDescription: problemDescription,
          defectType: _defectTypeFromString(defectType),
          severity: _severityFromString(severity),
          status: 0,
          state: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _warrantyRepo.addClaimHistory(
        ClaimHistoryEntity(
          claimId: id,
          action: 'created',
          timestamp: now,
          userId: operatorId,
          notes: 'Рекламация создана',
        ),
      );

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка создания рекламации: $e');
    }
  }

  @override
  Future<WmsResult> resolveClaim(
    int claimId, {
    required String resolutionType,
    String? notes,
    int? resolvedBy,
    Decimal? refundAmount,
    Decimal? repairCost,
  }) async {
    try {
      final existing = await _warrantyRepo.findClaimById(claimId);
      if (existing == null) {
        return WmsResult.failed('Рекламация с ID $claimId не найдена');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final wasAlreadyResolved = existing.status == 2;

      await _warrantyRepo.updateClaim(
        existing.copyWith(
          resolutionType: _resolutionTypeFromString(resolutionType),
          resolutionNotes: notes,
          resolutionDate: now,
          resolvedBy: resolvedBy,
          refundAmount: refundAmount,
          repairCost: repairCost,
          status: 2,
          updatedAt: now,
        ),
      );

      if (!wasAlreadyResolved) {
        await _moveStockOnResolution(
          claim: existing,
          resolutionType: resolutionType,
        );
      }

      await _warrantyRepo.addClaimHistory(
        ClaimHistoryEntity(
          claimId: claimId,
          action: 'resolution_set',
          timestamp: now,
          userId: resolvedBy,
          notes: notes ?? 'Рекламация решена: $resolutionType',
        ),
      );

      return WmsResult.ok(claimId);
    } catch (e) {
      return WmsResult.failed('Ошибка решения рекламации: $e');
    }
  }

  @override
  Future<WmsResult> updateClaimStatus(
    int claimId,
    int newStatus, {
    int? userId,
    String? notes,
  }) async {
    try {
      final existing = await _warrantyRepo.findClaimById(claimId);
      if (existing == null) {
        return WmsResult.failed('Рекламация с ID $claimId не найдена');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _warrantyRepo.updateClaim(
        existing.copyWith(status: newStatus, updatedAt: now),
      );

      await _warrantyRepo.addClaimHistory(
        ClaimHistoryEntity(
          claimId: claimId,
          action: 'status_changed',
          timestamp: now,
          userId: userId,
          newValue: newStatus.toString(),
          notes: notes ?? 'Статус изменён на $newStatus',
        ),
      );

      return WmsResult.ok(claimId);
    } catch (e) {
      return WmsResult.failed('Ошибка обновления статуса: $e');
    }
  }

  @override
  Future<List<ClaimEntity>> getAllClaims() async {
    return _warrantyRepo.findAllClaims();
  }

  @override
  Future<List<ClaimEntity>> getOpenClaims() async {
    return _warrantyRepo.findClaimsByStatus(0);
  }

  @override
  Future<List<ClaimEntity>> getClaimsByCustomer(int customerId) async {
    return _warrantyRepo.findClaimsByCustomerId(customerId);
  }

  Future<void> _moveStockOnResolution({
    required ClaimEntity claim,
    required String resolutionType,
  }) async {
    if (resolutionType != 'write_off' &&
        resolutionType != 'return_to_supplier') {
      return;
    }

    final ucode = claim.ucode;
    final qty = claim.quantity;
    if (ucode == null || qty == null || qty <= Decimal.zero) {
      _logger?.warning(
        'Claim ${claim.id} resolved as $resolutionType but has no '
        'ucode/quantity — stock not moved (ucode=$ucode, qty=$qty)',
      );
      return;
    }

    try {
      await _db.productInfoDao.adjustQuantity(ucode, -qty);
      _logger?.info(
        'Claim ${claim.id} ($resolutionType): stock decremented '
        'ucode=$ucode by $qty (reason: claim ${claim.claimNumber})',
      );
    } catch (e) {
      _logger?.warning('Claim ${claim.id}: failed to move stock: $e');
    }
  }

  int? _claimTypeFromString(String? type) {
    if (type == null) return null;
    switch (type) {
      case 'supplier':
      case 'supplier_defect':
      case 'transport_damage':
        return 1;
      case 'warranty':
      case 'quality':
      case 'customer':
      default:
        return 0;
    }
  }

  int? _defectTypeFromString(String? type) {
    if (type == null) return null;
    switch (type) {
      case 'mechanical':
        return 0;
      case 'electrical':
        return 1;
      case 'cosmetic':
        return 2;
      case 'functional':
        return 3;
      case 'other':
        return 4;
      default:
        return 0;
    }
  }

  int? _severityFromString(String? severity) {
    if (severity == null) return null;
    switch (severity) {
      case 'low':
        return 0;
      case 'medium':
        return 1;
      case 'high':
        return 2;
      case 'critical':
        return 3;
      default:
        return 1;
    }
  }

  int? _resolutionTypeFromString(String? type) {
    if (type == null) return null;
    switch (type) {
      case 'refund':
      case 'return_to_supplier':
        return 0;
      case 'repair':
        return 1;
      case 'replace':
        return 2;
      case 'reject':
      case 'rejected':
        return 3;
      case 'write_off':
        return 4;
      default:
        return 0;
    }
  }
}
