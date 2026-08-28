import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Warehouses extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get code => text()();

  TextColumn get name => text()();

  TextColumn get address => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  IntColumn get state => integer().nullable()();

  IntColumn get editTime => integer().nullable()();
}

class WarehouseZones extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get warehouseId => integer()();

  TextColumn get code => text()();

  TextColumn get name => text()();

  IntColumn get type => integer()();

  IntColumn get storageType => integer().withDefault(const Constant(0))();

  RealColumn get temperatureMin =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get temperatureMax =>
      real().nullable().map(const DecimalConverter())();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class WarehouseCells extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get zoneId => integer()();

  TextColumn get address => text()();

  TextColumn get rowCode => text().nullable()();

  TextColumn get rackCode => text().nullable()();

  TextColumn get levelCode => text().nullable()();

  TextColumn get binCode => text().nullable()();

  TextColumn get barcode => text().nullable()();

  RealColumn get maxWeight => real().nullable().map(const DecimalConverter())();

  RealColumn get maxVolume => real().nullable().map(const DecimalConverter())();

  IntColumn get maxItems => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();
}

class CellStocks extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get cellId => integer()();

  IntColumn get ucode => integer()();

  IntColumn get batchId => integer().nullable()();

  IntColumn get serialId => integer().nullable()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get reservedQty =>
      real().withDefault(const Constant(0)).map(const DecimalConverter())();

  IntColumn get updatedAt => integer().nullable()();
}

class Batches extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get ucode => integer()();

  TextColumn get batchNumber => text()();

  IntColumn get productionDate => integer().nullable()();

  IntColumn get expiryDate => integer().nullable()();

  IntColumn get supplierId => integer().nullable()();

  TextColumn get supplierBatchNo => text().nullable()();

  IntColumn get supplyId => integer().nullable()();

  IntColumn get receivedDate => integer().nullable()();

  IntColumn get receivedBy => integer().nullable()();

  RealColumn get initialQuantity => real().map(const DecimalConverter())();

  RealColumn get currentQuantity => real().map(const DecimalConverter())();

  RealColumn get reservedQuantity =>
      real().withDefault(const Constant(0)).map(const DecimalConverter())();

  RealColumn get unitCost => real().nullable().map(const DecimalConverter())();

  IntColumn get qualityStatus => integer().nullable()();

  IntColumn get qualityCheckDate => integer().nullable()();

  TextColumn get qualityNotes => text().nullable()();

  TextColumn get certificateNumber => text().nullable()();

  TextColumn get storageConditions => text().nullable()();

  IntColumn get cellId => integer().nullable()();

  TextColumn get markingCodesJson => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  BoolColumn get isQuarantined =>
      boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();

  IntColumn get state => integer().nullable()();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();
}

class Serials extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get ucode => integer()();

  TextColumn get serialNumber => text()();

  IntColumn get type => integer().nullable()();

  IntColumn get batchId => integer().nullable()();

  IntColumn get cellId => integer().nullable()();

  IntColumn get status => integer().withDefault(const Constant(0))();

  IntColumn get receivedAt => integer().nullable()();

  IntColumn get receivedBy => integer().nullable()();

  IntColumn get supplierId => integer().nullable()();

  IntColumn get supplyId => integer().nullable()();

  RealColumn get purchasePrice =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get soldAt => integer().nullable()();

  IntColumn get soldBy => integer().nullable()();

  IntColumn get saleId => integer().nullable()();

  RealColumn get salePrice => real().nullable().map(const DecimalConverter())();

  IntColumn get customerId => integer().nullable()();

  IntColumn get warrantyStart => integer().nullable()();

  IntColumn get warrantyEnd => integer().nullable()();

  IntColumn get warrantyMonths => integer().nullable()();

  TextColumn get markingCode => text().nullable()();

  TextColumn get condition => text().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get state => integer().nullable()();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();
}

class SerialMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serialId => integer()();

  TextColumn get movementType => text()();

  IntColumn get fromCellId => integer().nullable()();

  IntColumn get toCellId => integer().nullable()();

  TextColumn get documentType => text().nullable()();

  IntColumn get documentId => integer().nullable()();

  IntColumn get userId => integer().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get timestamp => integer()();

  TextColumn get notes => text().nullable()();
}

class MarkingCodes extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get ucode => integer()();

  TextColumn get code => text()();

  TextColumn get gtin => text().nullable()();

  TextColumn get serial => text().nullable()();

  TextColumn get batch => text().nullable()();

  TextColumn get expiry => text().nullable()();

  TextColumn get checksum => text().nullable()();

  IntColumn get status => integer().withDefault(const Constant(0))();

  IntColumn get parentCodeId => integer().nullable()();

  IntColumn get aggregationLevel => integer().nullable()();

  IntColumn get supplyId => integer().nullable()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get cellId => integer().nullable()();

  IntColumn get state => integer().nullable()();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();
}

class StockRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get ucode => integer()();

  IntColumn get warehouseId => integer().nullable()();

  RealColumn get minStock => real().nullable().map(const DecimalConverter())();

  RealColumn get maxStock => real().nullable().map(const DecimalConverter())();

  RealColumn get reorderQty =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get safetyStock =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get avgDailySales =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get leadTimeDays => integer().nullable()();

  IntColumn get defaultSupplierId => integer().nullable()();

  BoolColumn get autoReorder => boolean().withDefault(const Constant(false))();

  TextColumn get abcClass => text().nullable()();

  IntColumn get updatedAt => integer().nullable()();
}

class WarrantyRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serialId => integer().nullable()();

  IntColumn get ucode => integer()();

  IntColumn get warrantyStart => integer().nullable()();

  IntColumn get warrantyEnd => integer().nullable()();

  IntColumn get warrantyMonths => integer().nullable()();

  TextColumn get warrantyType => text().nullable()();

  TextColumn get source => text().nullable()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get supplyId => integer().nullable()();

  IntColumn get customerId => integer().nullable()();

  IntColumn get supplierId => integer().nullable()();

  TextColumn get status => text().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get state => integer().nullable()();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();
}

class Claims extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get claimNumber => text()();

  TextColumn get claimType => text()();

  IntColumn get serialId => integer().nullable()();

  IntColumn get ucode => integer().nullable()();

  IntColumn get batchId => integer().nullable()();

  RealColumn get quantity => real().nullable().map(const DecimalConverter())();

  IntColumn get customerId => integer().nullable()();

  IntColumn get supplierId => integer().nullable()();

  IntColumn get operatorId => integer().nullable()();

  TextColumn get problemDescription => text().nullable()();

  TextColumn get defectType => text().nullable()();

  TextColumn get severity => text().nullable()();

  TextColumn get photoIdsJson => text().nullable()();

  TextColumn get resolutionType => text().nullable()();

  TextColumn get resolutionNotes => text().nullable()();

  IntColumn get resolutionDate => integer().nullable()();

  IntColumn get resolvedBy => integer().nullable()();

  TextColumn get supplierClaimNumber => text().nullable()();

  TextColumn get supplierResponse => text().nullable()();

  IntColumn get supplierResponseDate => integer().nullable()();

  RealColumn get refundAmount =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get repairCost =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get deadline => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();

  IntColumn get status => integer().withDefault(const Constant(0))();

  IntColumn get state => integer().nullable()();
}

class ClaimHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get claimId => integer()();

  TextColumn get action => text()();

  TextColumn get oldValue => text().nullable()();

  TextColumn get newValue => text().nullable()();

  IntColumn get userId => integer().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get timestamp => integer()();

  TextColumn get notes => text().nullable()();
}

class ProductComponents extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get parentSerialId => integer()();

  IntColumn get componentSerialId => integer().nullable()();

  TextColumn get componentName => text()();

  TextColumn get componentSn => text().nullable()();

  IntColumn get warrantyMonths => integer().nullable()();

  IntColumn get warrantyEnd => integer().nullable()();

  TextColumn get notes => text().nullable()();
}

class WmsConfigs extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  BoolColumn get cellStorageEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get cellStorageMode => text().nullable()();

  BoolColumn get requireCellScan =>
      boolean().withDefault(const Constant(false))();

  IntColumn get addressSegments => integer().withDefault(const Constant(4))();

  TextColumn get addressFormat => text().nullable()();

  BoolColumn get serialTrackingEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get batchTrackingEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get expiryControlEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get defaultPickingStrategy => text().nullable()();

  IntColumn get expiryWarningDays => integer().nullable()();

  BoolColumn get markingEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get markingSystem => text().nullable()();

  BoolColumn get warrantyTrackingEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get costMethod => text().nullable()();

  BoolColumn get includeOverhead =>
      boolean().withDefault(const Constant(false))();

  RealColumn get abcThresholdA =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get abcThresholdB =>
      real().nullable().map(const DecimalConverter())();

  TextColumn get abcRecalcFrequency => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
