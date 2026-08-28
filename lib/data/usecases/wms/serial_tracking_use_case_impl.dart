import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/wms/serial_entity.dart';
import 'package:telepos/domain/entities/wms/serial_movement_entity.dart';
import 'package:telepos/domain/repositories/serial_repository.dart';
import 'package:telepos/domain/usecases/wms/serial_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

class SerialTrackingUseCaseImpl implements SerialTrackingUseCase {
  SerialTrackingUseCaseImpl(this._serialRepo);

  final SerialRepository _serialRepo;

  @override
  Future<WmsResult> registerSerial({
    required int ucode,
    required String serialNumber,
    int? type,
    int? batchId,
    int? supplierId,
    Decimal? purchasePrice,
  }) async {
    try {
      final existing = await _serialRepo.findBySerialNumber(serialNumber);
      if (existing != null) {
        return WmsResult.failed(
          'Серийный номер "$serialNumber" уже зарегистрирован',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final id = await _serialRepo.create(
        SerialEntity(
          ucode: ucode,
          serialNumber: serialNumber,
          type: type,
          batchId: batchId,
          supplierId: supplierId,
          purchasePrice: purchasePrice,
          status: 0,
          receivedAt: now,
          condition: 'new',
          state: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка регистрации серийного номера: $e');
    }
  }

  @override
  Future<WmsResult> markAsSold(
    int serialId, {
    required int saleId,
    required int userId,
    Decimal? salePrice,
    int? customerId,
  }) async {
    try {
      final existing = await _serialRepo.findById(serialId);
      if (existing == null) {
        return WmsResult.failed('Серийный номер с ID $serialId не найден');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _serialRepo.update(
        existing.copyWith(
          status: 1,
          saleId: saleId,
          soldBy: userId,
          soldAt: now,
          salePrice: salePrice,
          customerId: customerId,
          updatedAt: now,
        ),
      );

      await _serialRepo.addMovement(
        SerialMovementEntity(
          serialId: serialId,
          movementType: 'sale',
          documentType: 'sale',
          documentId: saleId,
          userId: userId,
          timestamp: now,
        ),
      );

      return WmsResult.ok(serialId);
    } catch (e) {
      return WmsResult.failed('Ошибка отметки продажи: $e');
    }
  }

  @override
  Future<WmsResult> markAsReturned(int serialId) async {
    try {
      final existing = await _serialRepo.findById(serialId);
      if (existing == null) {
        return WmsResult.failed('Серийный номер с ID $serialId не найден');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _serialRepo.update(existing.copyWith(status: 0, updatedAt: now));

      await _serialRepo.addMovement(
        SerialMovementEntity(
          serialId: serialId,
          movementType: 'return',
          timestamp: now,
        ),
      );

      return WmsResult.ok(serialId);
    } catch (e) {
      return WmsResult.failed('Ошибка отметки возврата: $e');
    }
  }

  @override
  Future<WmsResult> markAsDefective(int serialId, {String? notes}) async {
    try {
      final existing = await _serialRepo.findById(serialId);
      if (existing == null) {
        return WmsResult.failed('Серийный номер с ID $serialId не найден');
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _serialRepo.update(
        existing.copyWith(status: 3, notes: notes, updatedAt: now),
      );

      await _serialRepo.addMovement(
        SerialMovementEntity(
          serialId: serialId,
          movementType: 'defect',
          timestamp: now,
        ),
      );

      return WmsResult.ok(serialId);
    } catch (e) {
      return WmsResult.failed('Ошибка отметки дефекта: $e');
    }
  }

  @override
  Future<WmsResult> recordMovement({
    required int serialId,
    required String movementType,
    int? fromCellId,
    int? toCellId,
    String? documentType,
    int? documentId,
    int? userId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _serialRepo.addMovement(
        SerialMovementEntity(
          serialId: serialId,
          movementType: movementType,
          fromCellId: fromCellId,
          toCellId: toCellId,
          documentType: documentType,
          documentId: documentId,
          userId: userId,
          timestamp: now,
        ),
      );

      return WmsResult.ok(serialId);
    } catch (e) {
      return WmsResult.failed('Ошибка записи движения: $e');
    }
  }
}
