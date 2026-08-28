import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/warranty/claim_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_history_entity.dart';
import 'package:telepos/domain/repositories/warranty_repository.dart';
import 'package:telepos/domain/usecases/wms/claim_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

@immutable
class ClaimState {
  const ClaimState({
    this.claims = const [],
    this.selectedClaim,
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ClaimEntity> claims;

  final ClaimEntity? selectedClaim;

  final List<ClaimHistoryEntity> history;

  final bool isLoading;

  final String? error;

  int get claimCount => claims.length;

  int get openCount => claims.where((c) => c.isOpen).length;

  int get overdueCount => claims.where((c) => c.isOverdue).length;

  ClaimState copyWith({
    List<ClaimEntity>? claims,
    ClaimEntity? selectedClaim,
    List<ClaimHistoryEntity>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSelectedClaim = false,
  }) => ClaimState(
    claims: claims ?? this.claims,
    selectedClaim: clearSelectedClaim
        ? null
        : (selectedClaim ?? this.selectedClaim),
    history: history ?? this.history,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class ClaimNotifier extends Notifier<ClaimState> {
  @override
  ClaimState build() => const ClaimState();

  Future<void> loadAllClaims() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ClaimUseCase>();
      final claims = await useCase.getAllClaims();

      state = state.copyWith(claims: claims, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> loadOpenClaims() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ClaimUseCase>();
      final claims = await useCase.getOpenClaims();

      state = state.copyWith(claims: claims, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> loadClaimsByCustomer(int customerId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ClaimUseCase>();
      final claims = await useCase.getClaimsByCustomer(customerId);

      state = state.copyWith(claims: claims, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> selectClaim(int id) async {
    final claim = state.claims.where((c) => c.id == id).firstOrNull;
    if (claim == null) return;

    state = state.copyWith(selectedClaim: claim, history: const []);

    await loadHistory(id);
  }

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
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ClaimUseCase>();
      final result = await useCase.createClaim(
        claimType: claimType,
        serialId: serialId,
        ucode: ucode,
        batchId: batchId,
        quantity: quantity,
        customerId: customerId,
        supplierId: supplierId,
        operatorId: operatorId,
        problemDescription: problemDescription,
        defectType: defectType,
        severity: severity,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadAllClaims();
      } else {
        state = state.copyWith(error: result.errorMessage);
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<WmsResult> resolveClaim(
    int id, {
    required String resolutionType,
    String? notes,
    int? resolvedBy,
    Decimal? refundAmount,
    Decimal? repairCost,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ClaimUseCase>();
      final result = await useCase.resolveClaim(
        id,
        resolutionType: resolutionType,
        notes: notes,
        resolvedBy: resolvedBy,
        refundAmount: refundAmount,
        repairCost: repairCost,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadAllClaims();
        if (state.selectedClaim?.id == id) {
          state = state.copyWith(clearSelectedClaim: true);
        }
      } else {
        state = state.copyWith(error: result.errorMessage);
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<void> loadHistory(int claimId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final warrantyRepo = GetIt.I<WarrantyRepository>();
      final history = await warrantyRepo.findClaimHistory(claimId);

      state = state.copyWith(history: history, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }
}

final claimControllerProvider = NotifierProvider<ClaimNotifier, ClaimState>(
  ClaimNotifier.new,
);
