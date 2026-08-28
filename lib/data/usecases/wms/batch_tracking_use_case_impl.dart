import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/wms/batch_entity.dart';
import 'package:telepos/domain/repositories/batch_repository.dart';
import 'package:telepos/domain/usecases/wms/batch_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

class BatchTrackingUseCaseImpl implements BatchTrackingUseCase {
  BatchTrackingUseCaseImpl(this._batchRepo);

  final BatchRepository _batchRepo;

  @override
  Future<WmsResult> createBatch({
    required int ucode,
    required String batchNumber,
    int? expiryDate,
    int? productionDate,
    int? supplierId,
    required Decimal quantity,
    Decimal? unitCost,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final id = await _batchRepo.create(
        BatchEntity(
          ucode: ucode,
          batchNumber: batchNumber,
          expiryDate: expiryDate,
          productionDate: productionDate,
          supplierId: supplierId,
          initialQuantity: quantity,
          currentQuantity: quantity,
          reservedQuantity: Decimal.zero,
          unitCost: unitCost,
          receivedDate: now,
          isActive: true,
          isQuarantined: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка создания партии: $e');
    }
  }

  @override
  Future<WmsResult> adjustBatchQuantity(int batchId, Decimal delta) async {
    try {
      final result = await _batchRepo.adjustQuantity(batchId, delta);
      if (result == 0) {
        return WmsResult.failed('Партия с ID $batchId не найдена');
      }
      return WmsResult.ok(batchId);
    } catch (e) {
      return WmsResult.failed('Ошибка корректировки количества: $e');
    }
  }

  @override
  Future<WmsResult> quarantineBatch(int batchId, {String? reason}) async {
    try {
      final existing = await _batchRepo.findById(batchId);
      if (existing == null) {
        return WmsResult.failed('Партия с ID $batchId не найдена');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _batchRepo.update(
        existing.copyWith(
          isQuarantined: true,
          qualityNotes: reason,
          updatedAt: now,
        ),
      );

      return WmsResult.ok(batchId);
    } catch (e) {
      return WmsResult.failed('Ошибка карантина партии: $e');
    }
  }

  @override
  Future<WmsResult> approveBatch(int batchId) async {
    try {
      final existing = await _batchRepo.findById(batchId);
      if (existing == null) {
        return WmsResult.failed('Партия с ID $batchId не найдена');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _batchRepo.update(
        existing.copyWith(
          isQuarantined: false,
          qualityStatus: 1,
          qualityCheckDate: now,
          updatedAt: now,
        ),
      );

      return WmsResult.ok(batchId);
    } catch (e) {
      return WmsResult.failed('Ошибка одобрения партии: $e');
    }
  }

  @override
  Future<List<BatchEntity>> getExpiringBatches(int daysAhead) async {
    return _batchRepo.findExpiring(daysAhead);
  }

  @override
  Future<List<BatchEntity>> getExpiredBatches() async {
    return _batchRepo.findExpired();
  }

  @override
  Future<BatchEntity?> suggestBatchForPicking(
    int ucode,
    String strategy,
  ) async {
    final batches = await _batchRepo.findActiveByUcode(ucode);
    if (batches.isEmpty) return null;

    final available = batches.where((b) {
      if (b.isQuarantined ?? false) return false;
      final qty =
          (b.currentQuantity ?? Decimal.zero) -
          (b.reservedQuantity ?? Decimal.zero);
      return qty > Decimal.zero;
    }).toList();

    if (available.isEmpty) return null;

    switch (strategy.toUpperCase()) {
      case 'FEFO':
        available.sort((a, b) {
          final aExpiry = a.expiryDate ?? 0x7FFFFFFF;
          final bExpiry = b.expiryDate ?? 0x7FFFFFFF;
          return aExpiry.compareTo(bExpiry);
        });
        break;
      case 'FIFO':
        available.sort((a, b) {
          final aReceived = a.receivedDate ?? 0;
          final bReceived = b.receivedDate ?? 0;
          return aReceived.compareTo(bReceived);
        });
        break;
      case 'LIFO':
        available.sort((a, b) {
          final aReceived = a.receivedDate ?? 0;
          final bReceived = b.receivedDate ?? 0;
          return bReceived.compareTo(aReceived);
        });
        break;
      default:
        available.sort((a, b) {
          final aExpiry = a.expiryDate ?? 0x7FFFFFFF;
          final bExpiry = b.expiryDate ?? 0x7FFFFFFF;
          return aExpiry.compareTo(bExpiry);
        });
    }

    return available.first;
  }
}
