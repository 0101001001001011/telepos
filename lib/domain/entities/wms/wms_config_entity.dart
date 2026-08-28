import 'package:decimal/decimal.dart';

class WmsConfigEntity {
  const WmsConfigEntity({
    this.id,
    this.enableBatches,
    this.enableSerials,
    this.enableCells,
    this.enableMarkingCodes,
    this.enableWarranty,
    this.enableStockRules,
    this.enableFifo,
    this.enableFefo,
    this.pickingStrategy,
    this.costMethod,
    this.expiryWarningDays,
    this.lowStockThreshold,
    this.overStockThreshold,
    this.defaultWarrantyMonths,
    this.autoAssignCells,
    this.requireBatchOnReceive,
    this.requireSerialOnReceive,
    this.requireCellOnReceive,
    this.updatedAt,
  });

  final int? id;

  final bool? enableBatches;

  final bool? enableSerials;

  final bool? enableCells;

  final bool? enableMarkingCodes;

  final bool? enableWarranty;

  final bool? enableStockRules;

  final bool? enableFifo;

  final bool? enableFefo;

  final String? pickingStrategy;

  final String? costMethod;

  final int? expiryWarningDays;

  final Decimal? lowStockThreshold;

  final Decimal? overStockThreshold;

  final int? defaultWarrantyMonths;

  final bool? autoAssignCells;

  final bool? requireBatchOnReceive;

  final bool? requireSerialOnReceive;

  final bool? requireCellOnReceive;

  final int? updatedAt;

  bool get hasAnyFeatureEnabled =>
      (enableBatches ?? false) ||
      (enableSerials ?? false) ||
      (enableCells ?? false) ||
      (enableMarkingCodes ?? false) ||
      (enableWarranty ?? false) ||
      (enableStockRules ?? false);

  WmsConfigEntity copyWith({
    int? id,
    bool? enableBatches,
    bool? enableSerials,
    bool? enableCells,
    bool? enableMarkingCodes,
    bool? enableWarranty,
    bool? enableStockRules,
    bool? enableFifo,
    bool? enableFefo,
    String? pickingStrategy,
    String? costMethod,
    int? expiryWarningDays,
    Decimal? lowStockThreshold,
    Decimal? overStockThreshold,
    int? defaultWarrantyMonths,
    bool? autoAssignCells,
    bool? requireBatchOnReceive,
    bool? requireSerialOnReceive,
    bool? requireCellOnReceive,
    int? updatedAt,
  }) {
    return WmsConfigEntity(
      id: id ?? this.id,
      enableBatches: enableBatches ?? this.enableBatches,
      enableSerials: enableSerials ?? this.enableSerials,
      enableCells: enableCells ?? this.enableCells,
      enableMarkingCodes: enableMarkingCodes ?? this.enableMarkingCodes,
      enableWarranty: enableWarranty ?? this.enableWarranty,
      enableStockRules: enableStockRules ?? this.enableStockRules,
      enableFifo: enableFifo ?? this.enableFifo,
      enableFefo: enableFefo ?? this.enableFefo,
      pickingStrategy: pickingStrategy ?? this.pickingStrategy,
      costMethod: costMethod ?? this.costMethod,
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      overStockThreshold: overStockThreshold ?? this.overStockThreshold,
      defaultWarrantyMonths:
          defaultWarrantyMonths ?? this.defaultWarrantyMonths,
      autoAssignCells: autoAssignCells ?? this.autoAssignCells,
      requireBatchOnReceive:
          requireBatchOnReceive ?? this.requireBatchOnReceive,
      requireSerialOnReceive:
          requireSerialOnReceive ?? this.requireSerialOnReceive,
      requireCellOnReceive: requireCellOnReceive ?? this.requireCellOnReceive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
