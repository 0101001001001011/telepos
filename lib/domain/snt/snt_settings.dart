enum SntProviderType {
  none(value: 0, label: 'Выключено', id: 'none'),

  webkassa(value: 3, label: 'WebKassa (СНТ)', id: 'webkassa');

  const SntProviderType({
    required this.value,
    required this.label,
    required this.id,
  });

  final int value;
  final String label;
  final String id;

  static SntProviderType fromValue(int value) => SntProviderType.values
      .firstWhere((t) => t.value == value, orElse: () => SntProviderType.none);

  static SntProviderType fromId(String? id) => SntProviderType.values
      .firstWhere((t) => t.id == id, orElse: () => SntProviderType.none);
}

class SntSettings {
  const SntSettings({
    this.providerType = SntProviderType.none,
    this.enabled = false,
    this.ownBin,
    this.ownWarehouseCode,
    this.offlineOutboxEnabled = true,
  });

  final SntProviderType providerType;

  final bool enabled;

  final String? ownBin;

  final String? ownWarehouseCode;

  final bool offlineOutboxEnabled;

  bool get isActive => enabled && providerType != SntProviderType.none;

  SntSettings copyWith({
    SntProviderType? providerType,
    bool? enabled,
    String? ownBin,
    String? ownWarehouseCode,
    bool? offlineOutboxEnabled,
  }) {
    return SntSettings(
      providerType: providerType ?? this.providerType,
      enabled: enabled ?? this.enabled,
      ownBin: ownBin ?? this.ownBin,
      ownWarehouseCode: ownWarehouseCode ?? this.ownWarehouseCode,
      offlineOutboxEnabled: offlineOutboxEnabled ?? this.offlineOutboxEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'providerType': providerType.value,
    'enabled': enabled,
    if (ownBin != null) 'ownBin': ownBin,
    if (ownWarehouseCode != null) 'ownWarehouseCode': ownWarehouseCode,
    'offlineOutboxEnabled': offlineOutboxEnabled,
  };

  factory SntSettings.fromJson(Map<String, dynamic> json) => SntSettings(
    providerType: SntProviderType.fromValue(json['providerType'] as int? ?? 0),
    enabled: json['enabled'] as bool? ?? false,
    ownBin: json['ownBin'] as String?,
    ownWarehouseCode: json['ownWarehouseCode'] as String?,
    offlineOutboxEnabled: json['offlineOutboxEnabled'] as bool? ?? true,
  );

  factory SntSettings.disabled() => const SntSettings();
}
