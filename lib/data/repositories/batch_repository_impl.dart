import 'package:decimal/decimal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/batch_entity.dart';
import 'package:telepos/domain/repositories/batch_repository.dart';

class BatchRepositoryImpl implements BatchRepository {
  BatchRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<BatchEntity?> findById(int id) async {
    final row = await _db.batchDao.findById(id);
    return row != null ? BatchMapper.fromDrift(row) : null;
  }

  @override
  Future<List<BatchEntity>> findByUcode(int ucode) async {
    final rows = await _db.batchDao.findByUcode(ucode);
    return BatchMapper.fromDriftList(rows);
  }

  @override
  Future<BatchEntity?> findByBatchNumber(String number) async {
    final row = await _db.batchDao.findByBatchNumber(number);
    return row != null ? BatchMapper.fromDrift(row) : null;
  }

  @override
  Future<List<BatchEntity>> findExpiring(int daysAhead) async {
    final rows = await _db.batchDao.findExpiring(daysAhead);
    return BatchMapper.fromDriftList(rows);
  }

  @override
  Future<List<BatchEntity>> findExpired() async {
    final rows = await _db.batchDao.findExpired();
    return BatchMapper.fromDriftList(rows);
  }

  @override
  Future<List<BatchEntity>> findQuarantined() async {
    final rows = await _db.batchDao.findQuarantined();
    return BatchMapper.fromDriftList(rows);
  }

  @override
  Future<List<BatchEntity>> findActiveByUcode(int ucode) async {
    final rows = await _db.batchDao.findActiveByUcode(ucode);
    return BatchMapper.fromDriftList(rows);
  }

  @override
  Future<int> create(BatchEntity entity) {
    final companion = BatchMapper.toDrift(entity);
    return _db.batchDao.insertBatch(companion);
  }

  @override
  Future<int> update(BatchEntity entity) {
    final companion = BatchMapper.toDrift(entity);
    return _db.batchDao.updateBatch(entity.id!, companion);
  }

  @override
  Future<int> adjustQuantity(int id, Decimal delta) {
    return _db.batchDao.adjustQuantity(id, delta);
  }
}
