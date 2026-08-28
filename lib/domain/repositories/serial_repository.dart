import 'package:telepos/domain/entities/wms/serial_entity.dart';
import 'package:telepos/domain/entities/wms/serial_movement_entity.dart';

abstract class SerialRepository {
  Future<SerialEntity?> findById(int id);

  Future<SerialEntity?> findBySerialNumber(String serialNumber);

  Future<List<SerialEntity>> findByUcode(int ucode);

  Future<List<SerialEntity>> findByStatus(int status);

  Future<int> create(SerialEntity entity);

  Future<int> update(SerialEntity entity);

  Future<int> updateStatus(int id, int status);

  Future<int> addMovement(SerialMovementEntity movement);

  Future<List<SerialMovementEntity>> getMovements(int serialId);
}
