import 'package:decimal/decimal.dart';

enum FiscalOperatorType {
  none(value: 0, label: 'Без фискализации', id: 'none'),
  webkassa(value: 1, label: 'WebKassa', id: 'webkassa'),
  directOfd(value: 2, label: 'Прямое подключение ОФД', id: 'direct_ofd'),
  kassa24(value: 3, label: 'Kassa24 / Fiscal24', id: 'kassa24');

  const FiscalOperatorType({
    required this.value,
    required this.label,
    required this.id,
  });

  final int value;

  final String label;

  final String id;

  static FiscalOperatorType fromValue(int value) =>
      FiscalOperatorType.values.firstWhere(
        (t) => t.value == value,
        orElse: () => FiscalOperatorType.none,
      );

  static FiscalOperatorType fromId(String? id) => FiscalOperatorType.values
      .firstWhere((t) => t.id == id, orElse: () => FiscalOperatorType.none);
}

class FiscalDefaults {
  FiscalDefaults._();

  static const String localModuleUrl = 'http://localhost:1332';

  static final Decimal vatRatePercent = Decimal.fromInt(16);

  static String? cloudBaseUrl(
    FiscalOperatorType operator, {
    required bool testMode,
  }) {
    switch (operator) {
      case FiscalOperatorType.webkassa:
        return testMode
            ? 'https://devkkm.webkassa.kz'
            : 'https://api.webkassa.kz';
      case FiscalOperatorType.kassa24:
        return testMode
            ? 'https://api.fiscalv2.stage.tech24.kz'
            : 'https://fiscal2.kassa24.kz';
      case FiscalOperatorType.directOfd:
      case FiscalOperatorType.none:
        return null;
    }
  }
}

class FiscalSettings {
  FiscalSettings({
    this.operatorType = FiscalOperatorType.none,
    this.testMode = true,
    this.baseUrl,
    this.localModuleUrl,
    this.login,
    this.password,
    this.apiKey,
    this.cashboxUniqueNumber,
    this.registrationNumber,
    this.directOfdKeyPath,
    this.isVatPayer = false,
    Decimal? vatRatePercent,
    this.printVatOnReceipt = true,
    this.offlineQueueEnabled = true,
    this.tokenTtl = const Duration(hours: 12),
  }) : vatRatePercent = vatRatePercent ?? FiscalDefaults.vatRatePercent;

  final FiscalOperatorType operatorType;

  final bool testMode;

  final String? baseUrl;

  final String? localModuleUrl;

  final String? login;
  final String? password;

  final String? apiKey;

  final String? cashboxUniqueNumber;

  final String? registrationNumber;

  final String? directOfdKeyPath;

  final bool isVatPayer;

  final Decimal vatRatePercent;
  final bool printVatOnReceipt;

  final bool offlineQueueEnabled;

  final Duration tokenTtl;

  String? get resolvedBaseUrl => (baseUrl != null && baseUrl!.isNotEmpty)
      ? baseUrl
      : FiscalDefaults.cloudBaseUrl(operatorType, testMode: testMode);

  bool get isEnabled => operatorType != FiscalOperatorType.none;

  bool get hasLocalModule =>
      localModuleUrl != null && localModuleUrl!.isNotEmpty;

  FiscalSettings copyWith({
    FiscalOperatorType? operatorType,
    bool? testMode,
    String? baseUrl,
    String? localModuleUrl,
    String? login,
    String? password,
    String? apiKey,
    String? cashboxUniqueNumber,
    String? registrationNumber,
    String? directOfdKeyPath,
    bool? isVatPayer,
    Decimal? vatRatePercent,
    bool? printVatOnReceipt,
    bool? offlineQueueEnabled,
    Duration? tokenTtl,
  }) {
    return FiscalSettings(
      operatorType: operatorType ?? this.operatorType,
      testMode: testMode ?? this.testMode,
      baseUrl: baseUrl ?? this.baseUrl,
      localModuleUrl: localModuleUrl ?? this.localModuleUrl,
      login: login ?? this.login,
      password: password ?? this.password,
      apiKey: apiKey ?? this.apiKey,
      cashboxUniqueNumber: cashboxUniqueNumber ?? this.cashboxUniqueNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      directOfdKeyPath: directOfdKeyPath ?? this.directOfdKeyPath,
      isVatPayer: isVatPayer ?? this.isVatPayer,
      vatRatePercent: vatRatePercent ?? this.vatRatePercent,
      printVatOnReceipt: printVatOnReceipt ?? this.printVatOnReceipt,
      offlineQueueEnabled: offlineQueueEnabled ?? this.offlineQueueEnabled,
      tokenTtl: tokenTtl ?? this.tokenTtl,
    );
  }

  Map<String, dynamic> toJson() => {
    'operatorType': operatorType.value,
    'testMode': testMode,
    if (baseUrl != null) 'baseUrl': baseUrl,
    if (localModuleUrl != null) 'localModuleUrl': localModuleUrl,
    if (login != null) 'login': login,
    if (password != null) 'password': password,
    if (apiKey != null) 'apiKey': apiKey,
    if (cashboxUniqueNumber != null) 'cashboxUniqueNumber': cashboxUniqueNumber,
    if (registrationNumber != null) 'registrationNumber': registrationNumber,
    if (directOfdKeyPath != null) 'directOfdKeyPath': directOfdKeyPath,
    'isVatPayer': isVatPayer,
    'vatRatePercent': vatRatePercent.toString(),
    'printVatOnReceipt': printVatOnReceipt,
    'offlineQueueEnabled': offlineQueueEnabled,
    'tokenTtlSeconds': tokenTtl.inSeconds,
  };

  factory FiscalSettings.fromJson(Map<String, dynamic> json) => FiscalSettings(
    operatorType: FiscalOperatorType.fromValue(
      json['operatorType'] as int? ?? 0,
    ),
    testMode: json['testMode'] as bool? ?? true,
    baseUrl: json['baseUrl'] as String?,
    localModuleUrl: json['localModuleUrl'] as String?,
    login: json['login'] as String?,
    password: json['password'] as String?,
    apiKey: json['apiKey'] as String?,
    cashboxUniqueNumber: json['cashboxUniqueNumber'] as String?,
    registrationNumber: json['registrationNumber'] as String?,
    directOfdKeyPath: json['directOfdKeyPath'] as String?,
    isVatPayer: json['isVatPayer'] as bool? ?? false,
    vatRatePercent: json['vatRatePercent'] != null
        ? Decimal.parse(json['vatRatePercent'].toString())
        : null,
    printVatOnReceipt: json['printVatOnReceipt'] as bool? ?? true,
    offlineQueueEnabled: json['offlineQueueEnabled'] as bool? ?? true,
    tokenTtl: json['tokenTtlSeconds'] != null
        ? Duration(seconds: json['tokenTtlSeconds'] as int)
        : const Duration(hours: 12),
  );

  factory FiscalSettings.disabled() =>
      FiscalSettings(operatorType: FiscalOperatorType.none);
}
