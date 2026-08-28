import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/wms/warehouse_entity.dart';
import 'package:telepos/domain/entities/wms/warehouse_zone_entity.dart';
import 'package:telepos/domain/entities/wms/warehouse_cell_entity.dart';
import 'package:telepos/domain/entities/wms/cell_stock_entity.dart';
import 'package:telepos/domain/entities/wms/batch_entity.dart';
import 'package:telepos/domain/entities/wms/serial_entity.dart';
import 'package:telepos/domain/entities/wms/serial_movement_entity.dart';
import 'package:telepos/domain/entities/wms/marking_code_entity.dart';
import 'package:telepos/domain/entities/wms/stock_rule_entity.dart';
import 'package:telepos/domain/entities/wms/wms_config_entity.dart';
import 'package:telepos/domain/entities/warranty/warranty_record_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_entity.dart';
import 'package:telepos/domain/entities/warranty/claim_history_entity.dart';
import 'package:telepos/domain/entities/warranty/product_component_entity.dart';

class WarehouseMapper {
  WarehouseMapper._();

  static WarehouseEntity fromDrift(Warehouse row) {
    return WarehouseEntity(
      id: row.id,
      code: row.code,
      name: row.name,
      address: row.address,
      isActive: row.isActive,
      isDefault: row.isDefault,
      state: row.state,
      editTime: row.editTime,
    );
  }

  static WarehousesCompanion toDrift(WarehouseEntity entity) {
    return WarehousesCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      code: Value(entity.code ?? ''),
      name: Value(entity.name ?? ''),
      address: Value(entity.address),
      isActive: Value(entity.isActive ?? true),
      isDefault: Value(entity.isDefault ?? false),
      state: Value(entity.state),
      editTime: Value(entity.editTime),
    );
  }

  static List<WarehouseEntity> fromDriftList(List<Warehouse> rows) {
    return rows.map(fromDrift).toList();
  }
}

class WarehouseZoneMapper {
  WarehouseZoneMapper._();

  static WarehouseZoneEntity fromDrift(WarehouseZone row) {
    return WarehouseZoneEntity(
      id: row.id,
      warehouseId: row.warehouseId,
      code: row.code,
      name: row.name,
      type: row.type,
      storageType: row.storageType,
      temperatureMin: row.temperatureMin,
      temperatureMax: row.temperatureMax,
      isActive: row.isActive,
    );
  }

  static WarehouseZonesCompanion toDrift(WarehouseZoneEntity entity) {
    return WarehouseZonesCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      warehouseId: Value(entity.warehouseId ?? 0),
      code: Value(entity.code ?? ''),
      name: Value(entity.name ?? ''),
      type: Value(entity.type ?? 0),
      storageType: Value(entity.storageType ?? 0),
      temperatureMin: Value(entity.temperatureMin),
      temperatureMax: Value(entity.temperatureMax),
      isActive: Value(entity.isActive ?? true),
    );
  }

  static List<WarehouseZoneEntity> fromDriftList(List<WarehouseZone> rows) {
    return rows.map(fromDrift).toList();
  }
}

class WarehouseCellMapper {
  WarehouseCellMapper._();

  static WarehouseCellEntity fromDrift(WarehouseCell row) {
    return WarehouseCellEntity(
      id: row.id,
      zoneId: row.zoneId,
      address: row.address,
      rowCode: row.rowCode,
      rackCode: row.rackCode,
      levelCode: row.levelCode,
      binCode: row.binCode,
      barcode: row.barcode,
      maxWeight: row.maxWeight,
      maxVolume: row.maxVolume,
      maxItems: row.maxItems,
      isActive: row.isActive,
      isBlocked: row.isBlocked,
      notes: row.notes,
    );
  }

  static WarehouseCellsCompanion toDrift(WarehouseCellEntity entity) {
    return WarehouseCellsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      zoneId: Value(entity.zoneId ?? 0),
      address: Value(entity.address ?? ''),
      rowCode: Value(entity.rowCode),
      rackCode: Value(entity.rackCode),
      levelCode: Value(entity.levelCode),
      binCode: Value(entity.binCode),
      barcode: Value(entity.barcode),
      maxWeight: Value(entity.maxWeight),
      maxVolume: Value(entity.maxVolume),
      maxItems: Value(entity.maxItems),
      isActive: Value(entity.isActive ?? true),
      isBlocked: Value(entity.isBlocked ?? false),
      notes: Value(entity.notes),
    );
  }

  static List<WarehouseCellEntity> fromDriftList(List<WarehouseCell> rows) {
    return rows.map(fromDrift).toList();
  }
}

class CellStockMapper {
  CellStockMapper._();

  static CellStockEntity fromDrift(CellStock row) {
    return CellStockEntity(
      id: row.id,
      cellId: row.cellId,
      ucode: row.ucode,
      batchId: row.batchId,
      serialId: row.serialId,
      quantity: row.quantity,
      reservedQty: row.reservedQty,
      updatedAt: row.updatedAt,
    );
  }

  static CellStocksCompanion toDrift(CellStockEntity entity) {
    return CellStocksCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      cellId: Value(entity.cellId ?? 0),
      ucode: Value(entity.ucode ?? 0),
      batchId: Value(entity.batchId),
      serialId: Value(entity.serialId),
      quantity: Value(entity.quantity ?? Decimal.zero),
      reservedQty: Value(entity.reservedQty ?? Decimal.zero),
      updatedAt: Value(entity.updatedAt),
    );
  }

  static List<CellStockEntity> fromDriftList(List<CellStock> rows) {
    return rows.map(fromDrift).toList();
  }
}

class BatchMapper {
  BatchMapper._();

  static BatchEntity fromDrift(Batche row) {
    return BatchEntity(
      id: row.id,
      ucode: row.ucode,
      batchNumber: row.batchNumber,
      productionDate: row.productionDate,
      expiryDate: row.expiryDate,
      supplierId: row.supplierId,
      supplierBatchNo: row.supplierBatchNo,
      supplyId: row.supplyId,
      receivedDate: row.receivedDate,
      receivedBy: row.receivedBy,
      initialQuantity: row.initialQuantity,
      currentQuantity: row.currentQuantity,
      reservedQuantity: row.reservedQuantity,
      unitCost: row.unitCost,
      qualityStatus: row.qualityStatus,
      qualityCheckDate: row.qualityCheckDate,
      qualityNotes: row.qualityNotes,
      certificateNumber: row.certificateNumber,
      storageConditions: row.storageConditions,
      cellId: row.cellId,
      markingCodesJson: row.markingCodesJson,
      isActive: row.isActive,
      isQuarantined: row.isQuarantined,
      notes: row.notes,
      state: row.state,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static BatchesCompanion toDrift(BatchEntity entity) {
    return BatchesCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      ucode: Value(entity.ucode ?? 0),
      batchNumber: Value(entity.batchNumber ?? ''),
      productionDate: Value(entity.productionDate),
      expiryDate: Value(entity.expiryDate),
      supplierId: Value(entity.supplierId),
      supplierBatchNo: Value(entity.supplierBatchNo),
      supplyId: Value(entity.supplyId),
      receivedDate: Value(entity.receivedDate),
      receivedBy: Value(entity.receivedBy),
      initialQuantity: Value(entity.initialQuantity ?? Decimal.zero),
      currentQuantity: Value(entity.currentQuantity ?? Decimal.zero),
      reservedQuantity: Value(entity.reservedQuantity ?? Decimal.zero),
      unitCost: Value(entity.unitCost),
      qualityStatus: Value(entity.qualityStatus),
      qualityCheckDate: Value(entity.qualityCheckDate),
      qualityNotes: Value(entity.qualityNotes),
      certificateNumber: Value(entity.certificateNumber),
      storageConditions: Value(entity.storageConditions),
      cellId: Value(entity.cellId),
      markingCodesJson: Value(entity.markingCodesJson),
      isActive: Value(entity.isActive ?? true),
      isQuarantined: Value(entity.isQuarantined ?? false),
      notes: Value(entity.notes),
      state: Value(entity.state),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  static List<BatchEntity> fromDriftList(List<Batche> rows) {
    return rows.map(fromDrift).toList();
  }
}

class SerialMapper {
  SerialMapper._();

  static SerialEntity fromDrift(Serial row) {
    return SerialEntity(
      id: row.id,
      ucode: row.ucode,
      serialNumber: row.serialNumber,
      type: row.type,
      batchId: row.batchId,
      cellId: row.cellId,
      status: row.status,
      receivedAt: row.receivedAt,
      receivedBy: row.receivedBy,
      supplierId: row.supplierId,
      supplyId: row.supplyId,
      purchasePrice: row.purchasePrice,
      soldAt: row.soldAt,
      soldBy: row.soldBy,
      saleId: row.saleId,
      salePrice: row.salePrice,
      customerId: row.customerId,
      warrantyStart: row.warrantyStart,
      warrantyEnd: row.warrantyEnd,
      warrantyMonths: row.warrantyMonths,
      markingCode: row.markingCode,
      condition: row.condition,
      notes: row.notes,
      state: row.state,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static SerialsCompanion toDrift(SerialEntity entity) {
    return SerialsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      ucode: Value(entity.ucode ?? 0),
      serialNumber: Value(entity.serialNumber ?? ''),
      type: Value(entity.type),
      batchId: Value(entity.batchId),
      cellId: Value(entity.cellId),
      status: Value(entity.status ?? 0),
      receivedAt: Value(entity.receivedAt),
      receivedBy: Value(entity.receivedBy),
      supplierId: Value(entity.supplierId),
      supplyId: Value(entity.supplyId),
      purchasePrice: Value(entity.purchasePrice),
      soldAt: Value(entity.soldAt),
      soldBy: Value(entity.soldBy),
      saleId: Value(entity.saleId),
      salePrice: Value(entity.salePrice),
      customerId: Value(entity.customerId),
      warrantyStart: Value(entity.warrantyStart),
      warrantyEnd: Value(entity.warrantyEnd),
      warrantyMonths: Value(entity.warrantyMonths),
      markingCode: Value(entity.markingCode),
      condition: Value(entity.condition?.toString()),
      notes: Value(entity.notes),
      state: Value(entity.state),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  static List<SerialEntity> fromDriftList(List<Serial> rows) {
    return rows.map(fromDrift).toList();
  }
}

class SerialMovementMapper {
  SerialMovementMapper._();

  static SerialMovementEntity fromDrift(SerialMovement row) {
    return SerialMovementEntity(
      id: row.id,
      serialId: row.serialId,
      movementType: row.movementType,
      fromCellId: row.fromCellId,
      toCellId: row.toCellId,
      documentType: row.documentType,
      documentId: row.documentId,
      userId: row.userId,
      deviceId: row.deviceId,
      timestamp: row.timestamp,
      notes: row.notes,
    );
  }

  static SerialMovementsCompanion toDrift(SerialMovementEntity entity) {
    return SerialMovementsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      serialId: Value(entity.serialId ?? 0),
      movementType: Value(entity.movementType?.toString() ?? ''),
      fromCellId: Value(entity.fromCellId),
      toCellId: Value(entity.toCellId),
      documentType: Value(entity.documentType?.toString()),
      documentId: Value(entity.documentId),
      userId: Value(entity.userId),
      deviceId: Value(entity.deviceId),
      timestamp: Value(entity.timestamp ?? 0),
      notes: Value(entity.notes),
    );
  }

  static List<SerialMovementEntity> fromDriftList(List<SerialMovement> rows) {
    return rows.map(fromDrift).toList();
  }
}

class MarkingCodeMapper {
  MarkingCodeMapper._();

  static MarkingCodeEntity fromDrift(MarkingCode row) {
    return MarkingCodeEntity(
      id: row.id,
      ucode: row.ucode,
      code: row.code,
      gtin: row.gtin,
      serial: row.serial,
      batch: row.batch,
      expiry: row.expiry,
      checksum: row.checksum,
      status: row.status,
      parentCodeId: row.parentCodeId,
      aggregationLevel: row.aggregationLevel,
      supplyId: row.supplyId,
      saleId: row.saleId,
      cellId: row.cellId,
      state: row.state,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static MarkingCodesCompanion toDrift(MarkingCodeEntity entity) {
    return MarkingCodesCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      ucode: Value(entity.ucode ?? 0),
      code: Value(entity.code ?? ''),
      gtin: Value(entity.gtin),
      serial: Value(entity.serial),
      batch: Value(entity.batch),
      expiry: Value(entity.expiry),
      checksum: Value(entity.checksum),
      status: Value(entity.status ?? 0),
      parentCodeId: Value(entity.parentCodeId),
      aggregationLevel: Value(entity.aggregationLevel),
      supplyId: Value(entity.supplyId),
      saleId: Value(entity.saleId),
      cellId: Value(entity.cellId),
      state: Value(entity.state),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  static List<MarkingCodeEntity> fromDriftList(List<MarkingCode> rows) {
    return rows.map(fromDrift).toList();
  }
}

class StockRuleMapper {
  StockRuleMapper._();

  static StockRuleEntity fromDrift(StockRule row) {
    return StockRuleEntity(
      id: row.id,
      ucode: row.ucode,
      warehouseId: row.warehouseId,
      minStock: row.minStock,
      maxStock: row.maxStock,
      reorderQty: row.reorderQty,
      safetyStock: row.safetyStock,
      avgDailySales: row.avgDailySales,
      leadTimeDays: row.leadTimeDays,
      defaultSupplierId: row.defaultSupplierId,
      autoReorder: row.autoReorder,
      abcClass: row.abcClass,
      updatedAt: row.updatedAt,
    );
  }

  static StockRulesCompanion toDrift(StockRuleEntity entity) {
    return StockRulesCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      ucode: Value(entity.ucode ?? 0),
      warehouseId: Value(entity.warehouseId),
      minStock: Value(entity.minStock),
      maxStock: Value(entity.maxStock),
      reorderQty: Value(entity.reorderQty),
      safetyStock: Value(entity.safetyStock),
      avgDailySales: Value(entity.avgDailySales),
      leadTimeDays: Value(entity.leadTimeDays),
      defaultSupplierId: Value(entity.defaultSupplierId),
      autoReorder: Value(entity.autoReorder ?? false),
      abcClass: Value(entity.abcClass),
      updatedAt: Value(entity.updatedAt),
    );
  }

  static List<StockRuleEntity> fromDriftList(List<StockRule> rows) {
    return rows.map(fromDrift).toList();
  }
}

class WmsConfigMapper {
  WmsConfigMapper._();

  static WmsConfigEntity fromDrift(WmsConfig row) {
    return WmsConfigEntity(
      id: row.id,
      enableBatches: row.batchTrackingEnabled,
      enableSerials: row.serialTrackingEnabled,
      enableCells: row.cellStorageEnabled,
      enableMarkingCodes: row.markingEnabled,
      enableWarranty: row.warrantyTrackingEnabled,
      enableStockRules: null,
      enableFifo: row.defaultPickingStrategy == 'fifo',
      enableFefo: row.defaultPickingStrategy == 'fefo',
      pickingStrategy: row.defaultPickingStrategy,
      costMethod: row.costMethod,
      expiryWarningDays: row.expiryWarningDays,
      lowStockThreshold: row.abcThresholdA,
      overStockThreshold: row.abcThresholdB,
      defaultWarrantyMonths: null,
      autoAssignCells: null,
      requireBatchOnReceive: null,
      requireSerialOnReceive: null,
      requireCellOnReceive: row.requireCellScan,
      updatedAt: null,
    );
  }

  static WmsConfigsCompanion toDrift(WmsConfigEntity entity) {
    String? pickingStrategy = entity.pickingStrategy?.toLowerCase();
    if (pickingStrategy == null) {
      if (entity.enableFefo == true) {
        pickingStrategy = 'fefo';
      } else if (entity.enableFifo == true) {
        pickingStrategy = 'fifo';
      }
    }

    return WmsConfigsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      cellStorageEnabled: Value(entity.enableCells ?? false),
      serialTrackingEnabled: Value(entity.enableSerials ?? false),
      batchTrackingEnabled: Value(entity.enableBatches ?? false),
      expiryControlEnabled: Value(entity.enableFefo ?? false),
      defaultPickingStrategy: Value(pickingStrategy),
      costMethod: Value(entity.costMethod),
      expiryWarningDays: Value(entity.expiryWarningDays),
      markingEnabled: Value(entity.enableMarkingCodes ?? false),
      warrantyTrackingEnabled: Value(entity.enableWarranty ?? false),
      requireCellScan: Value(entity.requireCellOnReceive ?? false),
      abcThresholdA: Value(entity.lowStockThreshold),
      abcThresholdB: Value(entity.overStockThreshold),
    );
  }

  static List<WmsConfigEntity> fromDriftList(List<WmsConfig> rows) {
    return rows.map(fromDrift).toList();
  }
}

class WarrantyRecordMapper {
  WarrantyRecordMapper._();

  static WarrantyRecordEntity fromDrift(WarrantyRecord row) {
    return WarrantyRecordEntity(
      id: row.id,
      serialId: row.serialId,
      ucode: row.ucode,
      warrantyStart: row.warrantyStart,
      warrantyEnd: row.warrantyEnd,
      warrantyMonths: row.warrantyMonths,
      warrantyType: row.warrantyType != null
          ? int.tryParse(row.warrantyType!)
          : null,
      source: row.source != null ? int.tryParse(row.source!) : null,
      saleId: row.saleId,
      supplyId: row.supplyId,
      customerId: row.customerId,
      supplierId: row.supplierId,
      status: row.status != null ? int.tryParse(row.status!) : null,
      notes: row.notes,
      state: row.state,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static WarrantyRecordsCompanion toDrift(WarrantyRecordEntity entity) {
    return WarrantyRecordsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      serialId: Value(entity.serialId),
      ucode: Value(entity.ucode ?? 0),
      warrantyStart: Value(entity.warrantyStart),
      warrantyEnd: Value(entity.warrantyEnd),
      warrantyMonths: Value(entity.warrantyMonths),
      warrantyType: Value(entity.warrantyType?.toString()),
      source: Value(entity.source?.toString()),
      saleId: Value(entity.saleId),
      supplyId: Value(entity.supplyId),
      customerId: Value(entity.customerId),
      supplierId: Value(entity.supplierId),
      status: Value(entity.status?.toString()),
      notes: Value(entity.notes),
      state: Value(entity.state),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  static List<WarrantyRecordEntity> fromDriftList(List<WarrantyRecord> rows) {
    return rows.map(fromDrift).toList();
  }
}

class ClaimMapper {
  ClaimMapper._();

  static ClaimEntity fromDrift(Claim row) {
    return ClaimEntity(
      id: row.id,
      claimNumber: row.claimNumber,
      claimType: int.tryParse(row.claimType),
      serialId: row.serialId,
      ucode: row.ucode,
      batchId: row.batchId,
      quantity: row.quantity,
      customerId: row.customerId,
      supplierId: row.supplierId,
      operatorId: row.operatorId,
      problemDescription: row.problemDescription,
      defectType: row.defectType != null ? int.tryParse(row.defectType!) : null,
      severity: row.severity != null ? int.tryParse(row.severity!) : null,
      photoIdsJson: row.photoIdsJson,
      resolutionType: row.resolutionType != null
          ? int.tryParse(row.resolutionType!)
          : null,
      resolutionNotes: row.resolutionNotes,
      resolutionDate: row.resolutionDate,
      resolvedBy: row.resolvedBy,
      supplierClaimNumber: row.supplierClaimNumber,
      supplierResponse: row.supplierResponse,
      supplierResponseDate: row.supplierResponseDate,
      refundAmount: row.refundAmount,
      repairCost: row.repairCost,
      createdAt: row.createdAt,
      deadline: row.deadline,
      updatedAt: row.updatedAt,
      status: row.status,
      state: row.state,
    );
  }

  static ClaimsCompanion toDrift(ClaimEntity entity) {
    return ClaimsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      claimNumber: Value(entity.claimNumber ?? ''),
      claimType: Value(entity.claimType?.toString() ?? ''),
      serialId: Value(entity.serialId),
      ucode: Value(entity.ucode),
      batchId: Value(entity.batchId),
      quantity: Value(entity.quantity),
      customerId: Value(entity.customerId),
      supplierId: Value(entity.supplierId),
      operatorId: Value(entity.operatorId),
      problemDescription: Value(entity.problemDescription),
      defectType: Value(entity.defectType?.toString()),
      severity: Value(entity.severity?.toString()),
      photoIdsJson: Value(entity.photoIdsJson),
      resolutionType: Value(entity.resolutionType?.toString()),
      resolutionNotes: Value(entity.resolutionNotes),
      resolutionDate: Value(entity.resolutionDate),
      resolvedBy: Value(entity.resolvedBy),
      supplierClaimNumber: Value(entity.supplierClaimNumber),
      supplierResponse: Value(entity.supplierResponse),
      supplierResponseDate: Value(entity.supplierResponseDate),
      refundAmount: Value(entity.refundAmount),
      repairCost: Value(entity.repairCost),
      createdAt: Value(entity.createdAt),
      deadline: Value(entity.deadline),
      updatedAt: Value(entity.updatedAt),
      status: Value(entity.status ?? 0),
      state: Value(entity.state),
    );
  }

  static List<ClaimEntity> fromDriftList(List<Claim> rows) {
    return rows.map(fromDrift).toList();
  }
}

class ClaimHistoryMapper {
  ClaimHistoryMapper._();

  static ClaimHistoryEntity fromDrift(ClaimHistoryEntry row) {
    return ClaimHistoryEntity(
      id: row.id,
      claimId: row.claimId,
      action: row.action,
      oldValue: row.oldValue,
      newValue: row.newValue,
      userId: row.userId,
      deviceId: row.deviceId,
      timestamp: row.timestamp,
      notes: row.notes,
    );
  }

  static ClaimHistoryEntriesCompanion toDrift(ClaimHistoryEntity entity) {
    return ClaimHistoryEntriesCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      claimId: Value(entity.claimId ?? 0),
      action: Value(entity.action ?? ''),
      oldValue: Value(entity.oldValue),
      newValue: Value(entity.newValue),
      userId: Value(entity.userId),
      deviceId: Value(entity.deviceId),
      timestamp: Value(entity.timestamp ?? 0),
      notes: Value(entity.notes),
    );
  }

  static List<ClaimHistoryEntity> fromDriftList(List<ClaimHistoryEntry> rows) {
    return rows.map(fromDrift).toList();
  }
}

class ProductComponentMapper {
  ProductComponentMapper._();

  static ProductComponentEntity fromDrift(ProductComponent row) {
    return ProductComponentEntity(
      id: row.id,
      parentSerialId: row.parentSerialId,
      componentSerialId: row.componentSerialId,
      componentName: row.componentName,
      componentSn: row.componentSn,
      warrantyMonths: row.warrantyMonths,
      warrantyEnd: row.warrantyEnd,
      notes: row.notes,
    );
  }

  static ProductComponentsCompanion toDrift(ProductComponentEntity entity) {
    return ProductComponentsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      parentSerialId: Value(entity.parentSerialId ?? 0),
      componentSerialId: Value(entity.componentSerialId),
      componentName: Value(entity.componentName ?? ''),
      componentSn: Value(entity.componentSn),
      warrantyMonths: Value(entity.warrantyMonths),
      warrantyEnd: Value(entity.warrantyEnd),
      notes: Value(entity.notes),
    );
  }

  static List<ProductComponentEntity> fromDriftList(
    List<ProductComponent> rows,
  ) {
    return rows.map(fromDrift).toList();
  }
}
