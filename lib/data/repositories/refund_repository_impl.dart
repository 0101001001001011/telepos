import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/refund_mapper.dart';
import 'package:telepos/data/mappers/refund_product_mapper.dart';
import 'package:telepos/domain/entities/refund/refund_entity.dart';
import 'package:telepos/domain/entities/refund/refund_product_entity.dart';
import 'package:telepos/domain/repositories/refund_repository.dart';

class RefundRepositoryImpl implements RefundRepository {
  RefundRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<RefundEntity?> findById(int localId) async {
    final refund = await _db.refundDao.findById(localId);
    return refund != null ? RefundMapper.fromDrift(refund) : null;
  }

  @override
  Future<RefundEntity?> findBySale(int receiptNo, int posId) async {
    final refund = await _db.refundDao.findBySale(receiptNo, posId);
    return refund != null ? RefundMapper.fromDrift(refund) : null;
  }

  @override
  Future<List<RefundEntity>> findByState(int state) async {
    final refunds = await _db.refundDao.findByState(state);
    return RefundMapper.fromDriftList(refunds);
  }

  @override
  Future<int> insert(RefundEntity entity) async {
    final companion = RefundMapper.toDrift(entity);
    return _db.into(_db.refunds).insert(companion);
  }

  @override
  Future<void> updateState(int localId, int state) async {
    await _db.refundDao.setState(state, [localId]);
  }

  @override
  Future<List<RefundProductEntity>> findProducts(int refundLocalId) async {
    final products = await _db.refundDao.findProductsByRefund(refundLocalId);
    return RefundProductMapper.fromDriftList(products);
  }
}
