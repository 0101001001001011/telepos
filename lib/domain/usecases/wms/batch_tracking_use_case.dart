import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/wms/batch_entity.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

abstract class BatchTrackingUseCase {
  Future<WmsResult> createBatch({
    required int ucode,
    required String batchNumber,
    int? expiryDate,
    int? productionDate,
    int? supplierId,
    required Decimal quantity,
    Decimal? unitCost,
  });

  Future<WmsResult> adjustBatchQuantity(int batchId, Decimal delta);

  Future<WmsResult> quarantineBatch(int batchId, {String? reason});

  Future<WmsResult> approveBatch(int batchId);

  Future<List<BatchEntity>> getExpiringBatches(int daysAhead);

  Future<List<BatchEntity>> getExpiredBatches();

  Future<BatchEntity?> suggestBatchForPicking(int ucode, String strategy);
}
