import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/serial_entity.dart';
import 'package:telepos/domain/entities/wms/serial_movement_entity.dart';
import 'package:telepos/domain/repositories/serial_repository.dart';

class SerialRepositoryImpl implements SerialRepository {
  SerialRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<SerialEntity?> findById(int id) async {
    final row = await _db.serialDao.findById(id);
    return row != null ? SerialMapper.fromDrift(row) : null;
  }

  @override
  Future<SerialEntity?> findBySerialNumber(String serialNumber) async {
    final row = await _db.serialDao.findBySerialNumber(serialNumber);
    return row != null ? SerialMapper.fromDrift(row) : null;
  }

  @override
  Future<List<SerialEntity>> findByUcode(int ucode) async {
    final rows = await _db.serialDao.findByUcode(ucode);
    return SerialMapper.fromDriftList(rows);
  }

  @override
  Future<List<SerialEntity>> findByStatus(int status) async {
    final rows = await _db.serialDao.findByStatus(status);
    return SerialMapper.fromDriftList(rows);
  }

  @override
  Future<int> create(SerialEntity entity) {
    final companion = SerialMapper.toDrift(entity);
    return _db.serialDao.insertSerial(companion);
  }

  @override
  Future<int> update(SerialEntity entity) {
    final companion = SerialMapper.toDrift(entity);
    return _db.serialDao.updateSerial(entity.id!, companion);
  }

  @override
  Future<int> updateStatus(int id, int status) {
    return _db.serialDao.updateStatus(id, status);
  }

  @override
  Future<int> addMovement(SerialMovementEntity movement) {
    final companion = SerialMovementMapper.toDrift(movement);
    return _db.serialDao.insertMovement(companion);
  }

  @override
  Future<List<SerialMovementEntity>> getMovements(int serialId) async {
    final rows = await _db.serialDao.findMovements(serialId);
    return SerialMovementMapper.fromDriftList(rows);
  }
}
