enum OfdSyncType {
  all(value: 0, label: 'Все продажи', description: 'Фискализация всех чеков'),

  selective(
    value: 1,
    label: 'Выборочно',
    description: 'Только отмеченные чеки',
  ),

  onlyCredit(
    value: 2,
    label: 'Только безнал',
    description: 'Только оплата картой',
  );

  const OfdSyncType({
    required this.value,
    required this.label,
    required this.description,
  });

  final int value;

  final String label;

  final String description;

  static OfdSyncType fromValue(int value) {
    return OfdSyncType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => OfdSyncType.all,
    );
  }

  bool shouldFiscalize({
    required bool isOfdFlagged,
    required bool hasCardPayment,
  }) {
    switch (this) {
      case OfdSyncType.all:
        return true;
      case OfdSyncType.selective:
        return isOfdFlagged;
      case OfdSyncType.onlyCredit:
        return hasCardPayment;
    }
  }
}

class OfdSyncConfig {
  const OfdSyncConfig({
    required this.syncType,
    required this.isEnabled,
    this.autoRetry = true,
    this.maxRetries = 3,
    this.retryDelaySeconds = 60,
  });

  final OfdSyncType syncType;

  final bool isEnabled;

  final bool autoRetry;

  final int maxRetries;

  final int retryDelaySeconds;

  static const OfdSyncConfig disabled = OfdSyncConfig(
    syncType: OfdSyncType.all,
    isEnabled: false,
  );

  static const OfdSyncConfig allSales = OfdSyncConfig(
    syncType: OfdSyncType.all,
    isEnabled: true,
  );

  static const OfdSyncConfig creditOnly = OfdSyncConfig(
    syncType: OfdSyncType.onlyCredit,
    isEnabled: true,
  );

  OfdSyncConfig copyWith({
    OfdSyncType? syncType,
    bool? isEnabled,
    bool? autoRetry,
    int? maxRetries,
    int? retryDelaySeconds,
  }) {
    return OfdSyncConfig(
      syncType: syncType ?? this.syncType,
      isEnabled: isEnabled ?? this.isEnabled,
      autoRetry: autoRetry ?? this.autoRetry,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelaySeconds: retryDelaySeconds ?? this.retryDelaySeconds,
    );
  }

  @override
  String toString() {
    return 'OfdSyncConfig(syncType: $syncType, isEnabled: $isEnabled)';
  }
}
