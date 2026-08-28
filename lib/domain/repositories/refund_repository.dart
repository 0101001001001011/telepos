import 'package:telepos/domain/entities/refund/refund_entity.dart';
import 'package:telepos/domain/entities/refund/refund_product_entity.dart';

abstract class RefundRepository {
  Future<RefundEntity?> findById(int localId);

  Future<RefundEntity?> findBySale(int receiptNo, int posId);

  Future<List<RefundEntity>> findByState(int state);

  Future<int> insert(RefundEntity entity);

  Future<void> updateState(int localId, int state);

  Future<List<RefundProductEntity>> findProducts(int refundLocalId);
}
