import 'package:telepos/domain/usecases/wms/wms_result.dart';

abstract class ManageCellsUseCase {
  Future<WmsResult> createZone({
    required int warehouseId,
    required String code,
    required String name,
    required int type,
    int storageType = 0,
  });

  Future<WmsResult> createCell({
    required int zoneId,
    required String address,
    String? barcode,
  });

  Future<WmsResult> generateCells({
    required int zoneId,
    required CellGenerationParams params,
  });

  Future<WmsResult> blockCell(int cellId, {required bool blocked});
}

class CellGenerationParams {
  const CellGenerationParams({
    required this.rows,
    required this.racks,
    required this.levels,
    required this.bins,
    this.prefix,
  });

  final int rows;

  final int racks;

  final int levels;

  final int bins;

  final String? prefix;

  int get totalCells => rows * racks * levels * bins;
}
