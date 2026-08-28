class SyncConfig {
  const SyncConfig._();

  static const int quickProductBatchSize = 200;

  static const int agentBatchSize = 1000;

  static const int productBatchSize = 400;

  static const int priceBatchSize = 600;

  static const int saleBatchSize = 500;

  static const int refundBatchSize = 500;

  static const int aliasBatchSize = 500;

  static const int packageBatchSize = 500;

  static const int categoryBatchSize = 100;

  static const int userBatchSize = 50;

  static const int cashOperationBatchSize = 100;

  static const int shiftBatchSize = 50;

  static const int fullSyncThreshold = 15;

  static const int maxIncrementalCycles = 20;

  static const int syncIntervalMinutes = 5;

  static const int minSyncIntervalSeconds = 30;

  static const int requestTimeoutSeconds = 30;

  static const int fullSyncTimeoutMinutes = 30;

  static const int incrementalSyncTimeoutMinutes = 5;

  static const int maxRetryAttempts = 3;

  static const int retryDelaySeconds = 5;

  static int getBatchSize(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.quickProduct:
        return quickProductBatchSize;
      case SyncEntityType.product:
        return productBatchSize;
      case SyncEntityType.agent:
        return agentBatchSize;
      case SyncEntityType.price:
        return priceBatchSize;
      case SyncEntityType.sale:
        return saleBatchSize;
      case SyncEntityType.refund:
        return refundBatchSize;
      case SyncEntityType.alias:
        return aliasBatchSize;
      case SyncEntityType.package:
        return packageBatchSize;
      case SyncEntityType.category:
        return categoryBatchSize;
      case SyncEntityType.user:
        return userBatchSize;
      case SyncEntityType.cashOperation:
        return cashOperationBatchSize;
      case SyncEntityType.shift:
        return shiftBatchSize;
    }
  }
}

enum SyncType { full, incremental, quick, uploadOnly }

enum SyncEntityType {
  quickProduct,

  product,

  agent,

  price,

  sale,

  refund,

  alias,

  package,

  category,

  user,

  cashOperation,

  shift,
}

enum SyncStep {
  downloadCategories,
  downloadProducts,
  downloadPrices,
  downloadAgents,
  downloadUsers,
  downloadAliases,
  downloadPackages,

  uploadShifts,
  uploadSales,
  uploadRefunds,
  uploadCashOperations,

  finalize,
}

enum SyncDirection { download, upload, bidirectional }

class SyncStepInfo {
  const SyncStepInfo({
    required this.step,
    required this.direction,
    required this.entityType,
    required this.displayName,
    required this.order,
  });

  final SyncStep step;
  final SyncDirection direction;
  final SyncEntityType entityType;
  final String displayName;
  final int order;

  static const List<SyncStepInfo> allSteps = [
    SyncStepInfo(
      step: SyncStep.downloadCategories,
      direction: SyncDirection.download,
      entityType: SyncEntityType.category,
      displayName: 'Категории',
      order: 1,
    ),
    SyncStepInfo(
      step: SyncStep.downloadProducts,
      direction: SyncDirection.download,
      entityType: SyncEntityType.product,
      displayName: 'Товары',
      order: 2,
    ),
    SyncStepInfo(
      step: SyncStep.downloadPrices,
      direction: SyncDirection.download,
      entityType: SyncEntityType.price,
      displayName: 'Цены',
      order: 3,
    ),
    SyncStepInfo(
      step: SyncStep.downloadAgents,
      direction: SyncDirection.download,
      entityType: SyncEntityType.agent,
      displayName: 'Контрагенты',
      order: 4,
    ),
    SyncStepInfo(
      step: SyncStep.downloadUsers,
      direction: SyncDirection.download,
      entityType: SyncEntityType.user,
      displayName: 'Пользователи',
      order: 5,
    ),
    SyncStepInfo(
      step: SyncStep.downloadAliases,
      direction: SyncDirection.download,
      entityType: SyncEntityType.alias,
      displayName: 'Штрихкоды',
      order: 6,
    ),
    SyncStepInfo(
      step: SyncStep.downloadPackages,
      direction: SyncDirection.download,
      entityType: SyncEntityType.package,
      displayName: 'Упаковки',
      order: 7,
    ),

    SyncStepInfo(
      step: SyncStep.uploadShifts,
      direction: SyncDirection.upload,
      entityType: SyncEntityType.shift,
      displayName: 'Смены',
      order: 8,
    ),
    SyncStepInfo(
      step: SyncStep.uploadSales,
      direction: SyncDirection.upload,
      entityType: SyncEntityType.sale,
      displayName: 'Продажи',
      order: 9,
    ),
    SyncStepInfo(
      step: SyncStep.uploadRefunds,
      direction: SyncDirection.upload,
      entityType: SyncEntityType.refund,
      displayName: 'Возвраты',
      order: 10,
    ),
    SyncStepInfo(
      step: SyncStep.uploadCashOperations,
      direction: SyncDirection.upload,
      entityType: SyncEntityType.cashOperation,
      displayName: 'Касса',
      order: 11,
    ),

    SyncStepInfo(
      step: SyncStep.finalize,
      direction: SyncDirection.bidirectional,
      entityType: SyncEntityType.product,
      displayName: 'Завершение',
      order: 12,
    ),
  ];

  static SyncStepInfo? getInfo(SyncStep step) {
    return allSteps.where((s) => s.step == step).firstOrNull;
  }

  static List<SyncStepInfo> get downloadSteps {
    return allSteps
        .where((s) => s.direction == SyncDirection.download)
        .toList();
  }

  static List<SyncStepInfo> get uploadSteps {
    return allSteps.where((s) => s.direction == SyncDirection.upload).toList();
  }
}
