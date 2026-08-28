import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

abstract class SerialTrackingUseCase {
  Future<WmsResult> registerSerial({
    required int ucode,
    required String serialNumber,
    int? type,
    int? batchId,
    int? supplierId,
    Decimal? purchasePrice,
  });

  Future<WmsResult> markAsSold(
    int serialId, {
    required int saleId,
    required int userId,
    Decimal? salePrice,
    int? customerId,
  });

  Future<WmsResult> markAsReturned(int serialId);

  Future<WmsResult> markAsDefective(int serialId, {String? notes});

  Future<WmsResult> recordMovement({
    required int serialId,
    required String movementType,
    int? fromCellId,
    int? toCellId,
    String? documentType,
    int? documentId,
    int? userId,
  });
}
