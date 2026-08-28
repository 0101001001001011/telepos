import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/wms/batch_entity.dart';

abstract class BatchRepository {
  Future<BatchEntity?> findById(int id);

  Future<List<BatchEntity>> findByUcode(int ucode);

  Future<BatchEntity?> findByBatchNumber(String number);

  Future<List<BatchEntity>> findExpiring(int daysAhead);

  Future<List<BatchEntity>> findExpired();

  Future<List<BatchEntity>> findQuarantined();

  Future<List<BatchEntity>> findActiveByUcode(int ucode);

  Future<int> create(BatchEntity entity);

  Future<int> update(BatchEntity entity);

  Future<int> adjustQuantity(int id, Decimal delta);
}
